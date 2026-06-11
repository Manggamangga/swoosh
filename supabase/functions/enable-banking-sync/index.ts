import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { createHash } from 'node:crypto';
import {
  amountToPence,
  corsHeaders,
  enableBankingFetch,
  getEnableBankingConfig,
  jsonResponse,
  transactionDescription,
} from '../_shared/enable_banking.ts';

type SessionAccount = {
  uid: string;
  name?: string;
  currency?: string;
  cash_account_type?: string;
};

type SessionResponse = {
  session_id: string;
  accounts?: SessionAccount[];
  access?: { valid_until?: string };
};

type BalanceEntry = {
  balance_amount?: { amount?: string; currency?: string };
  balance_type?: string;
};

type TransactionEntry = {
  transaction_id?: string;
  entry_reference?: string;
  transaction_amount?: { amount?: string; currency?: string };
  credit_debit_indicator?: string;
  booking_date?: string;
  value_date?: string;
  remittance_information?: string[];
  creditor?: { name?: string };
  debtor?: { name?: string };
};

function dedupeHash(accountId: string, date: string, amount: number, description: string) {
  const normalized = description.toLowerCase().trim().replace(/\s+/g, ' ');
  const payload = `${accountId}|${date}|${amount}|${normalized}`;
  return createHash('sha256').update(payload).digest('hex');
}

function mapAccountType(cashAccountType?: string) {
  if (cashAccountType === 'SVGS') return 'savings';
  if (cashAccountType === 'TRAS') return 'savings';
  return 'everyday';
}

function pickBalancePence(balances: BalanceEntry[]) {
  const preferred = balances.find((b) =>
    b.balance_type === 'CLAV' || b.balance_type === 'ITAV' || b.balance_type === 'interimAvailable'
  ) ?? balances[0];
  if (!preferred?.balance_amount?.amount) return null;
  return Math.round(parseFloat(preferred.balance_amount.amount) * 100);
}

async function fetchAllTransactions(accountUid: string) {
  const transactions: TransactionEntry[] = [];
  let continuationKey: string | undefined;

  do {
    const query = new URLSearchParams();
    if (continuationKey) query.set('continuation_key', continuationKey);
    const path = `/accounts/${accountUid}/transactions${query.size ? `?${query}` : ''}`;
    const page = await enableBankingFetch<{
      transactions?: TransactionEntry[];
      continuation_key?: string;
    }>(path, 'GET');
    transactions.push(...(page.transactions ?? []));
    continuationKey = page.continuation_key;
  } while (continuationKey);

  return transactions;
}

function normalizeMatcher(value: string) {
  return value.toLowerCase().trim();
}

function resolveCategoryId(
  categoriesByName: Map<string, string>,
  rules: Array<{ matcher: string; matcher_type: string; category_id: string }>,
  merchant: string,
) {
  const merchantKey = normalizeMatcher(merchant);
  for (const rule of rules) {
    if (rule.matcher_type !== 'merchant' && rule.matcher_type !== 'keyword') continue;
    const matcher = normalizeMatcher(rule.matcher);
    if (merchantKey.includes(matcher) || matcher.includes(merchantKey)) {
      return rule.category_id;
    }
  }
  return categoriesByName.get('general') ?? null;
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

    if (!getEnableBankingConfig()) {
      return jsonResponse({ error: 'Enable Banking secrets not configured' }, 500);
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

    if (!connection.requisition_id) {
      return jsonResponse({ error: 'Connection has no active session' }, 400);
    }

    let sessionData: SessionResponse;
    try {
      sessionData = await enableBankingFetch<SessionResponse>(
        `/sessions/${connection.requisition_id}`,
        'GET',
      );
    } catch (error) {
      const status = (error as { status?: number }).status;
      if (status === 401 || status === 403 || status === 404) {
        await supabase.from('bank_connections').update({ status: 'expired' }).eq('id', connection_id);
        return jsonResponse({ error: 'Session expired — reconnect your bank' }, 401);
      }
      throw error;
    }

    let accountsSynced = 0;
    let transactionsSynced = 0;

    const { data: categories } = await supabase
      .from('categories')
      .select('id, name')
      .eq('user_id', user.id);
    const categoriesByName = new Map<string, string>(
      (categories ?? []).map((c: { id: string; name: string }) => [
        c.name.toLowerCase(),
        c.id,
      ]),
    );

    const { data: rules } = await supabase
      .from('category_rules')
      .select('matcher, matcher_type, category_id')
      .eq('user_id', user.id);

    for (const sessionAccount of sessionData.accounts ?? []) {
      const accountUid = sessionAccount.uid;
      if (!accountUid) continue;

      const { data: account } = await supabase
        .from('accounts')
        .upsert({
          user_id: user.id,
          name: sessionAccount.name ?? 'Bank account',
          account_type: mapAccountType(sessionAccount.cash_account_type),
          balance_pence: 0,
          currency: sessionAccount.currency ?? 'GBP',
          institution: connection.institution_name,
          source: 'openbanking',
          external_ref: accountUid,
        }, { onConflict: 'user_id,external_ref' })
        .select()
        .single();

      if (!account) continue;
      accountsSynced++;

      const balanceData = await enableBankingFetch<{ balances?: BalanceEntry[] }>(
        `/accounts/${accountUid}/balances`,
        'GET',
      );
      const balancePence = pickBalancePence(balanceData.balances ?? []);
      if (balancePence != null) {
        await supabase.from('accounts').update({ balance_pence: balancePence }).eq('id', account.id);
        await supabase.from('account_balance_snapshots').upsert({
          user_id: user.id,
          account_id: account.id,
          snapshot_date: new Date().toISOString().split('T')[0],
          balance_pence: balancePence,
        }, { onConflict: 'account_id,snapshot_date' });
      }

      const transactions = await fetchAllTransactions(accountUid);
      for (const tx of transactions) {
        const amount = amountToPence(
          tx.transaction_amount?.amount ?? '0',
          tx.credit_debit_indicator,
        );
        const date = tx.booking_date ?? tx.value_date;
        if (!date) continue;

        const description = transactionDescription(tx);
        const merchant = tx.creditor?.name ?? description;
        const hash = dedupeHash(account.id, date, amount, description);
        const categoryId = resolveCategoryId(
          categoriesByName,
          rules ?? [],
          merchant,
        );

        try {
          await supabase.from('transactions').insert({
            user_id: user.id,
            account_id: account.id,
            transaction_date: date,
            amount_pence: amount,
            currency: tx.transaction_amount?.currency ?? 'GBP',
            description,
            merchant,
            category_id: categoryId,
            source: 'openbanking',
            external_ref: tx.transaction_id ?? tx.entry_reference,
            dedupe_hash: hash,
            exclude_from_analytics: false,
          });
          transactionsSynced++;
        } catch (_) {}
      }
    }

    const expiresAt = sessionData.access?.valid_until ?? connection.expires_at;
    await supabase.from('bank_connections').update({
      status: 'active',
      expires_at: expiresAt,
    }).eq('id', connection_id);

    return jsonResponse({ accounts_synced: accountsSynced, transactions_synced: transactionsSynced });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    const status = (error as { status?: number }).status ?? 500;
    return jsonResponse({ error: message }, status);
  }
});
