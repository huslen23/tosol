param([Parameter(ValueFromRemainingArguments = $true)][string[]]$ManageArgs)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
foreach ($line in Get-Content -LiteralPath (Join-Path $projectRoot 'backend\.env')) {
    $entry = $line.Trim()
    if (-not $entry -or $entry.StartsWith('#')) { continue }
    $pair = $entry.Split('=', 2)
    if ($pair.Count -ne 2 -or $pair[0] -notmatch '^[A-Z][A-Z0-9_]*$') { throw 'Invalid .env entry' }
    [Environment]::SetEnvironmentVariable($pair[0], $pair[1].Trim().Trim('"').Trim("'"), 'Process')
}
if (-not $ManageArgs) { $ManageArgs = @('check') }
& (Join-Path $projectRoot 'backend\venv\Scripts\python.exe') (Join-Path $projectRoot 'backend\manage.py') @ManageArgs
exit $LASTEXITCODE
