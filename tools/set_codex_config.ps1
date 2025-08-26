Param()
$ErrorActionPreference = 'Stop'
$cfg = Join-Path $env:USERPROFILE '.codex\config.toml'
$dir = Split-Path -Parent $cfg
if (!(Test-Path -LiteralPath $dir)) {
  New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

$existing = ''
if (Test-Path -LiteralPath $cfg) {
  $existing = Get-Content -Raw -LiteralPath $cfg -Encoding UTF8
} else {
  New-Item -ItemType File -Path $cfg -Force | Out-Null
}

$newLines = @()
if ($existing) {
  $sanitized = $existing
  $sanitized = $sanitized -replace 'include_apply_patch_tool\s*=\s*[^\r\n]+',''
  $sanitized = $sanitized -replace 'model_reasoning_effort\s*=\s*[^\r\n]+',''
  $existingLines = $sanitized -split "\r?\n"
  $existingLines = $existingLines | ForEach-Object { $_.TrimEnd() } | Where-Object { $_ -and ($_.Trim() -ne '') }
  $newLines += $existingLines
}
$newLines += 'include_apply_patch_tool = false'
$newLines += 'model_reasoning_effort = "high"'

Set-Content -LiteralPath $cfg -Value $newLines -Encoding UTF8
Write-Host "Updated: $cfg"
Get-Content -LiteralPath $cfg -Encoding UTF8 | Write-Output
