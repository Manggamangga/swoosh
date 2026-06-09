import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { createHash } from 'node:crypto';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function dedupeHash(accountId: string, date: string, amount: number, description: string) {
  const normalized = description.toLowerCase().trim().replace(/\s+/g, ' ');
  const payload = `${accountId}|${date}|${amount}|${normalized}`;
  return createHash('sha256').update(payload).digest('hex');
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
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
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const { connection_id } = await req.json();
    const { data: connection } = await supabase
      .from('bank_connections')
      .select('*')
      .eq('id', connection_id)
      .eq('user_id', user.id)
      .single();

    if (!connection) {
      return new Response(JSON.stringify({ error: 'Connection not found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const secretId = Deno.env.get('GOCARDLESS_SECRET_ID');
    const secretKey = Deno.env.get('GOCARDLESS_SECRET_KEY');
    if (!secretId || !secretKey) {
      return new Response(
        JSON.stringify({ error: 'GoCardless secrets not configured' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const tokenRes = await fetch('https://bankaccountdata.gocardless.com/api/v2/token/new/', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ secret_id: secretId, secret_key: secretKey }),
    });
    const tokenData = await tokenRes.json();
    const accessToken = tokenData.access;

    const reqRes = await fetch(
      `https://bankaccountdata.gocardless.com/api/v2/requisitions/${connection.requisition_id}/`,
      { headers: { Authorization: `Bearer ${accessToken}` } },
    );
    const requisition = await reqRes.json();

    let accountsSynced = 0;
    let transactionsSynced = 0;

    for (const accountRef of requisition.accounts ?? []) {
      const accRes = await fetch(
        `https://bankaccountdata.gocardless.com/api/v2/accounts/${accountRef}/details/`,
        { headers: { Authorization: `Bearer ${accessToken}` } },
      );
      const accDetails = await accRes.json();

      const { data: account } = await supabase
        .from('accounts')
        .upsert({
          user_id: user.id,
          name: accDetails.account?.name ?? 'Bank account',
          account_type: 'everyday',
          balance_pence: 0,
          currency: accDetails.account?.currency ?? 'GBP',
          institution: connection.institution_name,
          source: 'openbanking',
          external_ref: accountRef,
        }, { onConflict: 'user_id,external_ref' })
        .select()
        .single();

      if (account) accountsSynced++;

      const balRes = await fetch(
        `https://bankaccountdata.gocardless.com/api/v2/accounts/${accountRef}/balances/`,
        { headers: { Authorization: `Bearer ${accessToken}` } },
      );
      const balData = await balRes.json();
      const balance = balData.balances?.[0];
      if (balance && account) {
        const pence = Math.round(parseFloat(balance.balanceAmount?.amount ?? '0') * 100);
        await supabase.from('accounts').update({ balance_pence: pence }).eq('id', account.id);
        await supabase.from('account_balance_snapshots').upsert({
          user_id: user.id,
          account_id: account.id,
          snapshot_date: new Date().toISOString().split('T')[0],
          balance_pence: pence,
        }, { onConflict: 'account_id,snapshot_date' });
      }

      const txRes = await fetch(
        `https://bankaccountdata.gocardless.com/api/v2/accounts/${accountRef}/transactions/`,
        { headers: { Authorization: `Bearer ${accessToken}` } },
      );
      const txData = await txRes.json();

      for (const booked of txData.transactions?.booked ?? []) {
        const amount = Math.round(parseFloat(booked.transactionAmount?.amount ?? '0') * 100);
        const date = booked.bookingDate ?? booked.valueDate;
        const description = booked.remittanceInformationUnstructured ?? booked.creditorName ?? 'Transaction';
        const hash = dedupeHash(account.id, date, amount, description);

        try {
          await supabase.from('transactions').insert({
            user_id: user.id,
            account_id: account.id,
            transaction_date: date,
            amount_pence: amount,
            currency: booked.transactionAmount?.currency ?? 'GBP',
            description,
            merchant: booked.creditorName ?? description,
            source: 'openbanking',
            external_ref: booked.transactionId ?? booked.internalTransactionId,
            dedupe_hash: hash,
            exclude_from_analytics: false,
          });
          transactionsSynced++;
        } catch (_) {}
      }
    }

    await supabase.from('bank_connections').update({ status: 'active' }).eq('id', connection_id);

    return new Response(
      JSON.stringify({ accounts_synced: accountsSynced, transactions_synced: transactionsSynced }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (error) {
    return new Response(JSON.stringify({ error: String(error) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
