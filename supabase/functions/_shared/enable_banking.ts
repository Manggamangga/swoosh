import { SignJWT, importPKCS8 } from 'https://esm.sh/jose@5';

const API_BASE = 'https://api.enablebanking.com';

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

export function getEnableBankingConfig() {
  const appId = Deno.env.get('ENABLE_BANKING_APP_ID');
  const privateKey = Deno.env.get('ENABLE_BANKING_PRIVATE_KEY');
  if (!appId || !privateKey) {
    return null;
  }
  return { appId, privateKey: privateKey.replace(/\\n/g, '\n') };
}

export async function createEnableBankingJwt(appId: string, privateKeyPem: string) {
  const key = await importPKCS8(privateKeyPem, 'RS256');
  const now = Math.floor(Date.now() / 1000);
  return new SignJWT({})
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT', kid: appId })
    .setIssuer('enablebanking.com')
    .setAudience('api.enablebanking.com')
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(key);
}

export async function enableBankingFetch<T>(
  path: string,
  method: 'GET' | 'POST' | 'DELETE',
  body?: unknown,
): Promise<T> {
  const config = getEnableBankingConfig();
  if (!config) {
    throw new Error('Enable Banking secrets not configured');
  }

  const jwt = await createEnableBankingJwt(config.appId, config.privateKey);
  const response = await fetch(`${API_BASE}${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${jwt}`,
      Accept: 'application/json',
      ...(body ? { 'Content-Type': 'application/json' } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });

  const data = await response.json();
  if (!response.ok) {
    const message = data?.message ?? data?.error ?? JSON.stringify(data);
    const error = new Error(message) as Error & { status?: number };
    error.status = response.status;
    throw error;
  }

  return data as T;
}

export function amountToPence(amount: string, indicator?: string) {
  const value = Math.round(parseFloat(amount) * 100);
  if (indicator === 'DBIT') return -Math.abs(value);
  if (indicator === 'CRDT') return Math.abs(value);
  return value;
}

export function transactionDescription(tx: {
  remittance_information?: string[];
  creditor?: { name?: string };
  debtor?: { name?: string };
}) {
  const remittance = tx.remittance_information?.filter(Boolean).join(' ');
  if (remittance) return remittance;
  return tx.creditor?.name ?? tx.debtor?.name ?? 'Transaction';
}
