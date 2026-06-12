import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { enableBankingFetch } from '../_shared/enable_banking.ts';
import {
  corsHeaders,
  jsonResponse,
  refreshMonzoToken,
  revokeMonzoToken,
} from '../_shared/monzo.ts';

type ConnectionRow = {
  id: string;
  user_id: string;
  provider: string;
  institution_name: string | null;
  requisition_id: string | null;
  access_token: string | null;
  refresh_token: string | null;
  token_expires_at: string | null;
};

function institutionForConnection(connection: ConnectionRow) {
  if (connection.provider === 'monzo') return 'Monzo';
  return connection.institution_name;
}

async function ensureMonzoAccessToken(
  supabase: ReturnType<typeof createClient>,
  connection: ConnectionRow,
) {
  const config = {
    clientId: Deno.env.get('MONZO_CLIENT_ID')!,
    clientSecret: Deno.env.get('MONZO_CLIENT_SECRET')!,
  };

  const expiresAt = connection.token_expires_at
    ? new Date(connection.token_expires_at).getTime()
    : 0;
  if (connection.access_token && expiresAt > Date.now() + 60_000) {
    return connection.access_token;
  }

  if (!connection.refresh_token) {
    throw new Error('Connection has no refresh token');
  }

  const refreshed = await refreshMonzoToken(
    connection.refresh_token,
    config.clientId,
    config.clientSecret,
  );

  await supabase
    .from('bank_connections')
    .update({
      access_token: refreshed.access_token,
      refresh_token: refreshed.refresh_token ?? connection.refresh_token,
      token_expires_at: new Date(Date.now() + refreshed.expires_in * 1000).toISOString(),
    })
    .eq('id', connection.id);

  return refreshed.access_token;
}

async function deleteSyncedAccounts(
  supabase: ReturnType<typeof createClient>,
  userId: string,
  connection: ConnectionRow,
) {
  const institution = institutionForConnection(connection);
  if (!institution) return 0;

  const { data: accounts } = await supabase
    .from('accounts')
    .select('id')
    .eq('user_id', userId)
    .eq('source', 'openbanking')
    .eq('institution', institution);

  const accountIds = (accounts ?? []).map((row) => row.id as string);
  if (accountIds.length === 0) return 0;

  await supabase.from('account_balance_snapshots').delete().in('account_id', accountIds);
  await supabase.from('goals').update({ account_id: null }).in('account_id', accountIds);
  await supabase
    .from('recurring_payments')
    .update({ account_id: null })
    .in('account_id', accountIds);
  await supabase.from('transactions').delete().in('account_id', accountIds);
  await supabase.from('accounts').delete().in('id', accountIds);

  return accountIds.length;
}

async function revokeProviderAccess(
  supabase: ReturnType<typeof createClient>,
  connection: ConnectionRow,
) {
  if (connection.provider === 'monzo') {
    try {
      const accessToken = await ensureMonzoAccessToken(supabase, connection);
      await revokeMonzoToken(accessToken);
    } catch (_) {
      // Token may already be invalid; continue with local disconnect.
    }
    return;
  }

  if (connection.provider === 'enable_banking' && connection.requisition_id) {
    try {
      await enableBankingFetch(`/sessions/${connection.requisition_id}`, 'DELETE');
    } catch (_) {
      // Session may already be expired; continue with local disconnect.
    }
  }
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

    const body = await req.json();
    const connectionId = body.connection_id as string;
    const deleteSyncedAccountsFlag = body.delete_synced_accounts === true;

    if (!connectionId) {
      return jsonResponse({ error: 'connection_id is required' }, 400);
    }

    const { data: connection } = await supabase
      .from('bank_connections')
      .select('*')
      .eq('id', connectionId)
      .eq('user_id', user.id)
      .single();

    if (!connection) {
      return jsonResponse({ error: 'Connection not found' }, 404);
    }

    await revokeProviderAccess(supabase, connection as ConnectionRow);

    let accountsDeleted = 0;
    if (deleteSyncedAccountsFlag) {
      accountsDeleted = await deleteSyncedAccounts(
        supabase,
        user.id,
        connection as ConnectionRow,
      );
    }

    await supabase.from('bank_connections').delete().eq('id', connectionId);

    return jsonResponse({
      disconnected: true,
      accounts_deleted: accountsDeleted,
    });
  } catch (error) {
    return jsonResponse({ error: String(error) }, 500);
  }
});
