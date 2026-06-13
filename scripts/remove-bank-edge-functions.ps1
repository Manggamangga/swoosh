# Removes legacy bank-integration Edge Functions from the Swoosh Supabase project.
# Requires: npx supabase login  OR  $env:SUPABASE_ACCESS_TOKEN set

$ErrorActionPreference = 'Stop'
$ProjectRef = 'segpgjvfwlwfqkverhso'

$functions = @(
  'bank-callback',
  'bank-disconnect',
  'enable-banking-connect',
  'enable-banking-sync',
  'gocardless-connect',
  'gocardless-sync',
  'monzo-connect',
  'monzo-sync'
)

foreach ($name in $functions) {
  Write-Host "Deleting $name..."
  npx supabase@latest functions delete $name --project-ref $ProjectRef --yes
}

Write-Host 'Done. Verify in Dashboard → Edge Functions or run: npx supabase functions list --project-ref' $ProjectRef
