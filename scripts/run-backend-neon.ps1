$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $projectRoot 'backend\.env'
$connectionLine = Get-Content -LiteralPath $envFile | Where-Object { $_.Trim().StartsWith('DATABASE_URL=') } | Select-Object -First 1
if (-not $connectionLine) { throw 'DATABASE_URL missing from backend/.env' }
$env:DATABASE_URL = $connectionLine.Trim().Substring('DATABASE_URL='.Length).Trim().Trim('"').Trim("'")
& (Join-Path $projectRoot 'backend\venv\Scripts\python.exe') (Join-Path $projectRoot 'backend\manage.py') runserver
