import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

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
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const { institution_id, institution_name, redirect_url } = await req.json();
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

    const requisitionRes = await fetch(
      'https://bankaccountdata.gocardless.com/api/v2/requisitions/',
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          redirect: redirect_url,
          institution_id,
          reference: user.id,
        }),
      },
    );
    const requisition = await requisitionRes.json();

    await supabase.from('bank_connections').insert({
      user_id: user.id,
      provider: 'gocardless',
      institution_id,
      institution_name,
      requisition_id: requisition.id,
      status: 'pending',
      expires_at: new Date(Date.now() + 90 * 24 * 60 * 60 * 1000).toISOString(),
    });

    return new Response(
      JSON.stringify({ link: requisition.link, requisition_id: requisition.id }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (error) {
    return new Response(JSON.stringify({ error: String(error) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
