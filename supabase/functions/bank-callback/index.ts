const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const ANDROID_PACKAGE = 'com.swoosh.swoosh';

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
    return htmlRedirect(deepLink, 'Bank connection failed. Return to Swoosh to try again.', url.search);
  }

  if (!code || !state) {
    return new Response('Missing code or state', { status: 400, headers: corsHeaders });
  }

  const deepLink = `swoosh://bank-callback?code=${encodeURIComponent(code)}&state=${encodeURIComponent(state)}`;
  return htmlRedirect(deepLink, 'Bank connected. Opening Swoosh...', url.search);
});

function htmlRedirect(deepLink: string, message: string, query: string) {
  const intentLink =
    `intent://bank-callback${query}#Intent;scheme=swoosh;package=${ANDROID_PACKAGE};end`;
  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Swoosh</title>
  <style>
    body { font-family: system-ui, sans-serif; background: #0f0d1e; color: #f5f5f7; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; padding: 24px; text-align: center; }
    a { color: #a78bfa; font-size: 18px; font-weight: 600; }
    p { margin: 0 0 16px; }
  </style>
</head>
<body>
  <div>
    <p>${message}</p>
    <p><a href="${deepLink}">Open Swoosh</a></p>
    <p><a href="${intentLink}">Open Swoosh (Android)</a></p>
  </div>
  <script>
    const deepLink = ${JSON.stringify(deepLink)};
    const intentLink = ${JSON.stringify(intentLink)};
    const isAndroid = /Android/i.test(navigator.userAgent);
    window.location.replace(isAndroid ? intentLink : deepLink);
  </script>
</body>
</html>`;

  return new Response(html, {
    status: 200,
    headers: { ...corsHeaders, 'Content-Type': 'text/html; charset=utf-8' },
  });
}
