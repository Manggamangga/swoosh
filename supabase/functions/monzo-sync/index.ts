import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { createHash } from 'node:crypto';
import {
  corsHeaders,
  getMonzoConfig,
  jsonResponse,
  monzoFetch,
  refreshMonzoToken,
} from '../_shared/monzo.ts';

type MonzoAccount = {
  id: string;
  description: string;
  currency: string;
  account_type?: string;
};

type MonzoTransaction = {
  id: string;
  amount: number;
  currency: string;
  description: string;
  created: string;
  merchant?: { name?: string };
  decline_reason?: string;
};

function dedupeHash(accountId: string, date: string, amount: number, description: string) {
  const normalized = description.toLowerCase().trim().replace(/\s+/g, ' ');
  const payload = `${accountId}|${date}|${amount}|${normalized}`;
  return createHash('sha256').update(payload).digest('hex');
}

function mapAccountType(accountType?: string) {
  if (accountType?.includes('savings') || accountType === 'uk_monzo_flex') return 'savings';
  return 'everyday';
}

function transactionDate(created: string) {
  return created.split('T')[0];
}

function isDuplicateKeyError(error: { code?: string } | null) {
  return error?.code === '23505';
}

async function ensureAccessToken(
  supabase: ReturnType<typeof createClient>,
  connection: Record<string, unknown>,
  connectionId: string,
) {
  const config = getMonzoConfig();
  if (!config) throw new Error('Monzo secrets not configured');

  const expiresAt = connection.token_expires_at
    ? new Date(connection.token_expires_at as string).getTime()
    : 0;
  const needsRefresh = Date.now() > expiresAt - 60_000;

  if (!needsRefresh && connection.access_token) {
    return connection.access_token as string;
  }

  const refreshToken = connection.refresh_token as string | undefined;
  if (!refreshToken) {
    throw new Error('No refresh token — reconnect Monzo');
  }

  const tokenData = await refreshMonzoToken(
    refreshToken,
    config.clientId,
    config.clientSecret,
  );

  const newExpiresAt = new Date(Date.now() + tokenData.expires_in * 1000).toISOString();
  await supabase.from('bank_connections').update({
    access_token: tokenData.access_token,
    refresh_token: tokenData.refresh_token ?? refreshToken,
    token_expires_at: newExpiresAt,
  }).eq('id', connectionId);

  return tokenData.access_token;
}

async function fetchAllTransactions(accessToken: string, accountId: string, since?: string) {
  const transactions: MonzoTransaction[] = [];
  let path = `/transactions?account_id=${accountId}&expand[]=merchant`;
  if (since) path += `&since=${since}`;

  while (path) {
    const page = await monzoFetch<{
      transactions: MonzoTransaction[];
    }>(path, accessToken);
    transactions.push(...(page.transactions ?? []));
    break;
  }

  return transactions;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return jsonResponse({ error: 'Unauthorized' }, 401);
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const anonClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: { user } } = await anonClient.auth.getUser();
    if (!user) {
      return jsonResponse({ error: 'Unauthorized' }, 401);
    }

    const { connection_id } = await req.json();
    const { data: connection } = await supabase
      .from('bank_connections')
      .select('*')
      .eq('id', connection_id)
      .eq('user_id', user.id)
      .single();

    if (!connection) {
      return jsonResponse({ error: 'Connection not found' }, 404);
    }

    if (!connection.access_token && !connection.refresh_token) {
      return jsonResponse({ error: 'Connection has no tokens — reconnect Monzo' }, 400);
    }

    let accessToken: string;
    try {
      accessToken = await ensureAccessToken(supabase, connection, connection_id);
    } catch (error) {
      const status = (error as { status?: number }).status;
      if (status === 401 || status === 403) {
        await supabase.from('bank_connections').update({ status: 'expired' }).eq('id', connection_id);
        return jsonResponse({ error: 'Session expired — reconnect Monzo' }, 401);
      }
      throw error;
    }

    const accountsData = await monzoFetch<{ accounts: MonzoAccount[] }>('/accounts', accessToken);
    let accountsSynced = 0;
    let transactionsSynced = 0;

    for (const monzoAccount of accountsData.accounts ?? []) {
      if (monzoAccount.account_type && !['uk_retail', 'uk_retail_joint'].includes(monzoAccount.account_type)) {
        continue;
      }

      const { data: account, error: accountError } = await supabase
        .from('accounts')
        .upsert({
          user_id: user.id,
          name: monzoAccount.description || 'Monzo',
          account_type: mapAccountType(monzoAccount.account_type),
          balance_pence: 0,
          currency: monzoAccount.currency ?? 'GBP',
          institution: 'Monzo',
          source: 'openbanking',
          external_ref: monzoAccount.id,
        }, { onConflict: 'user_id,external_ref' })
        .select()
        .single();

      if (accountError || !account) {
        throw new Error(accountError?.message ?? 'Failed to upsert account');
      }
      accountsSynced++;

      const balanceData = await monzoFetch<{ balance: number; currency: string }>(
        `/balance?account_id=${monzoAccount.id}`,
        accessToken,
      );
      const balancePence = balanceData.balance ?? 0;
      const { error: balanceError } = await supabase
        .from('accounts')
        .update({ balance_pence: balancePence })
        .eq('id', account.id);
      if (balanceError) {
        throw new Error(balanceError.message);
      }

      const { error: snapshotError } = await supabase.from('account_balance_snapshots').upsert({
        user_id: user.id,
        account_id: account.id,
        snapshot_date: new Date().toISOString().split('T')[0],
        balance_pence: balancePence,
      }, { onConflict: 'account_id,snapshot_date' });
      if (snapshotError) {
        throw new Error(snapshotError.message);
      }

      const { data: lastTx } = await supabase
        .from('transactions')
        .select('transaction_date')
        .eq('account_id', account.id)
        .order('transaction_date', { ascending: false })
        .limit(1)
        .maybeSingle();

      const since = lastTx?.transaction_date
        ? `${lastTx.transaction_date}T00:00:00Z`
        : undefined;

      const transactions = await fetchAllTransactions(accessToken, monzoAccount.id, since);
      for (const tx of transactions) {
        if (tx.decline_reason) continue;

        const date = transactionDate(tx.created);
        const description = tx.merchant?.name ?? tx.description;
        const hash = dedupeHash(account.id, date, tx.amount, description);

        const { error: txError } = await supabase.from('transactions').insert({
          user_id: user.id,
          account_id: account.id,
          transaction_date: date,
          amount_pence: tx.amount,
          currency: tx.currency ?? 'GBP',
          description,
          merchant: tx.merchant?.name ?? description,
          source: 'openbanking',
          external_ref: tx.id,
          dedupe_hash: hash,
          exclude_from_analytics: false,
        });
        if (txError) {
          if (isDuplicateKeyError(txError)) continue;
          throw new Error(txError.message);
        }
        transactionsSynced++;
      }
    }

    await supabase.from('bank_connections').update({ status: 'active' }).eq('id', connection_id);

    return jsonResponse({ accounts_synced: accountsSynced, transactions_synced: transactionsSynced });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    const status = (error as { status?: number }).status ?? 500;
    return jsonResponse({ error: message }, status);
  }
});
