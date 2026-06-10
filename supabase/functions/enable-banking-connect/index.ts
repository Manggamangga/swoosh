import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import {
  corsHeaders,
  enableBankingFetch,
  getEnableBankingConfig,
  jsonResponse,
} from '../_shared/enable_banking.ts';

type StartAuthResponse = {
  url: string;
  authorization_id: string;
};

type AuthorizeSessionResponse = {
  session_id: string;
  access?: { valid_until?: string };
  aspsp?: { name?: string; country?: string };
  accounts?: unknown[];
};

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
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      return jsonResponse({ error: 'Unauthorized' }, 401);
    }

    if (!getEnableBankingConfig()) {
      return jsonResponse({ error: 'Enable Banking secrets not configured' }, 500);
    }

    const body = await req.json();
    const action = body.action as string;

    if (action === 'aspsps') {
      const country = (body.country as string) ?? 'GB';
      const data = await enableBankingFetch<{ aspsps: Array<{ name: string; country: string }> }>(
        `/aspsps?country=${country}`,
        'GET',
      );
      return jsonResponse({ aspsps: data.aspsps ?? [] });
    }

    if (action === 'start') {
      const institutionName = body.institution_name as string;
      const redirectUrl = body.redirect_url as string;
      if (!institutionName || !redirectUrl) {
        return jsonResponse({ error: 'institution_name and redirect_url are required' }, 400);
      }

      const validUntil = new Date(Date.now() + 90 * 24 * 60 * 60 * 1000).toISOString();
      const { data: connection, error: insertError } = await supabase
        .from('bank_connections')
        .insert({
          user_id: user.id,
          provider: 'enable_banking',
          institution_id: institutionName,
          institution_name: institutionName,
          status: 'pending',
          expires_at: validUntil,
        })
        .select()
        .single();

      if (insertError || !connection) {
        return jsonResponse({ error: insertError?.message ?? 'Failed to create connection' }, 500);
      }

      const authData = await enableBankingFetch<StartAuthResponse>('/auth', 'POST', {
        access: { valid_until: validUntil },
        aspsp: { name: institutionName, country: 'GB' },
        state: connection.id,
        redirect_url: redirectUrl,
        psu_type: 'personal',
      });

      return jsonResponse({
        url: authData.url,
        connection_id: connection.id,
        authorization_id: authData.authorization_id,
      });
    }

    if (action === 'complete') {
      const code = body.code as string;
      const state = body.state as string;
      if (!code || !state) {
        return jsonResponse({ error: 'code and state are required' }, 400);
      }

      const { data: connection } = await supabase
        .from('bank_connections')
        .select('*')
        .eq('id', state)
        .eq('user_id', user.id)
        .single();

      if (!connection) {
        return jsonResponse({ error: 'Connection not found' }, 404);
      }

      const sessionData = await enableBankingFetch<AuthorizeSessionResponse>('/sessions', 'POST', {
        code,
      });

      const expiresAt = sessionData.access?.valid_until ?? connection.expires_at;
      const { error: updateError } = await supabase
        .from('bank_connections')
        .update({
          requisition_id: sessionData.session_id,
          status: 'active',
          expires_at: expiresAt,
          institution_name: sessionData.aspsp?.name ?? connection.institution_name,
        })
        .eq('id', state)
        .eq('user_id', user.id);

      if (updateError) {
        return jsonResponse({ error: updateError.message }, 500);
      }

      return jsonResponse({
        connection_id: state,
        session_id: sessionData.session_id,
        accounts: sessionData.accounts?.length ?? 0,
      });
    }

    return jsonResponse({ error: 'Unknown action' }, 400);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    const status = (error as { status?: number }).status ?? 500;
    return jsonResponse({ error: message }, status);
  }
});
