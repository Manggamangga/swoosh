export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

export function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

export function getMonzoConfig() {
  const clientId = Deno.env.get('MONZO_CLIENT_ID');
  const clientSecret = Deno.env.get('MONZO_CLIENT_SECRET');
  if (!clientId || !clientSecret) return null;
  return { clientId, clientSecret };
}

export function buildMonzoAuthUrl(clientId: string, redirectUri: string, state: string) {
  const params = new URLSearchParams({
    client_id: clientId,
    redirect_uri: redirectUri,
    response_type: 'code',
    state,
  });
  return `https://auth.monzo.com/?${params}`;
}

type TokenResponse = {
  access_token: string;
  refresh_token?: string;
  expires_in: number;
  user_id: string;
};

export async function exchangeMonzoCode(
  code: string,
  redirectUri: string,
  clientId: string,
  clientSecret: string,
) {
  const body = new URLSearchParams({
    grant_type: 'authorization_code',
    client_id: clientId,
    client_secret: clientSecret,
    redirect_uri: redirectUri,
    code,
  });

  const response = await fetch('https://api.monzo.com/oauth2/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body,
  });

  const data = await response.json();
  if (!response.ok) {
    throw new Error(data?.error ?? data?.message ?? JSON.stringify(data));
  }
  return data as TokenResponse;
}

export async function refreshMonzoToken(
  refreshToken: string,
  clientId: string,
  clientSecret: string,
) {
  const body = new URLSearchParams({
    grant_type: 'refresh_token',
    client_id: clientId,
    client_secret: clientSecret,
    refresh_token: refreshToken,
  });

  const response = await fetch('https://api.monzo.com/oauth2/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body,
  });

  const data = await response.json();
  if (!response.ok) {
    const error = new Error(data?.error ?? data?.message ?? JSON.stringify(data)) as Error & {
      status?: number;
    };
    error.status = response.status;
    throw error;
  }
  return data as TokenResponse;
}

export async function monzoFetch<T>(path: string, accessToken: string): Promise<T> {
  const response = await fetch(`https://api.monzo.com${path}`, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });

  const data = await response.json();
  if (!response.ok) {
    const error = new Error(data?.error ?? data?.message ?? JSON.stringify(data)) as Error & {
      status?: number;
    };
    error.status = response.status;
    throw error;
  }
  return data as T;
}
