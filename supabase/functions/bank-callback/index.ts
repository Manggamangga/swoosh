const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve((req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const url = new URL(req.url);
  const code = url.searchParams.get('code');
  const state = url.searchParams.get('state');
  const error = url.searchParams.get('error');

  if (error) {
    const deepLink = `swoosh://bank-callback?error=${encodeURIComponent(error)}`;
    return redirectResponse(deepLink, 'Bank connection failed. Return to Swoosh to try again.', url.search);
  }

  if (!code || !state) {
    return new Response('Missing code or state', { status: 400, headers: corsHeaders });
  }

  const deepLink = `swoosh://bank-callback?code=${encodeURIComponent(code)}&state=${encodeURIComponent(state)}`;
  return redirectResponse(deepLink, 'Bank connected. Opening Swoosh...', url.search);
});

function redirectResponse(deepLink: string, _message: string, _query: string) {
  return new Response(null, {
    status: 302,
    headers: {
      ...corsHeaders,
      Location: deepLink,
    },
  });
}
