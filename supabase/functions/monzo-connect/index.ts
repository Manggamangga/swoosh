import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import {
  buildMonzoAuthUrl,
  corsHeaders,
  exchangeMonzoCode,
  getMonzoConfig,
  jsonResponse,
} from '../_shared/monzo.ts';

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

    const config = getMonzoConfig();
    if (!config) {
      return jsonResponse({ error: 'Monzo secrets not configured' }, 500);
    }

    const body = await req.json();
    const action = body.action as string;

    if (action === 'start') {
      const redirectUrl = body.redirect_url as string;
      if (!redirectUrl) {
        return jsonResponse({ error: 'redirect_url is required' }, 400);
      }

      const { data: connection, error: insertError } = await supabase
        .from('bank_connections')
        .insert({
          user_id: user.id,
          provider: 'monzo',
          institution_id: 'monzo',
          institution_name: 'Monzo',
          status: 'pending',
        })
        .select()
        .single();

      if (insertError || !connection) {
        return jsonResponse({ error: insertError?.message ?? 'Failed to create connection' }, 500);
      }

      const url = buildMonzoAuthUrl(config.clientId, redirectUrl, connection.id);
      return jsonResponse({ url, connection_id: connection.id });
    }

    if (action === 'complete') {
      const code = body.code as string;
      const state = body.state as string;
      const redirectUrl = body.redirect_url as string;
      if (!code || !state || !redirectUrl) {
        return jsonResponse({ error: 'code, state, and redirect_url are required' }, 400);
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

      const tokenData = await exchangeMonzoCode(
        code,
        redirectUrl,
        config.clientId,
        config.clientSecret,
      );

      const expiresAt = new Date(Date.now() + tokenData.expires_in * 1000).toISOString();
      const { error: updateError } = await supabase
        .from('bank_connections')
        .update({
          access_token: tokenData.access_token,
          refresh_token: tokenData.refresh_token ?? connection.refresh_token,
          token_expires_at: expiresAt,
          requisition_id: tokenData.user_id,
          status: 'active',
        })
        .eq('id', state)
        .eq('user_id', user.id);

      if (updateError) {
        return jsonResponse({ error: updateError.message }, 500);
      }

      return jsonResponse({
        connection_id: state,
        user_id: tokenData.user_id,
        approve_in_app: true,
      });
    }

    return jsonResponse({ error: 'Unknown action' }, 400);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return jsonResponse({ error: message }, 500);
  }
});
