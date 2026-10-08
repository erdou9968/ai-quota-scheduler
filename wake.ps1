# Public wake-up ping for Claude Code and Codex. Sign in with subscription accounts before use.
# Sends one tiny prompt to each, in a temp folder (no project files loaded), no session saved where possible.
param([ValidateSet('Claude','Codex','Both')][string]$Target = 'Both')
$ErrorActionPreference = 'Continue'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$log  = Join-Path $here 'ai-quota-wake.log'
$workRoot = Join-Path $env:TEMP 'ai-wake'
$work = Join-Path $workRoot ('run-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $work | Out-Null
Set-Location $work
function Log($m) { Add-Content -Path $log -Value ("{0}  {1}" -f ([DateTime]::UtcNow.AddHours(8).ToString('yyyy-MM-dd HH:mm:ss') + ' BJT'), $m) -Encoding UTF8 }

function Find-Exe($name, $extra) {
  $c = Get-Command $name -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($c) { return $c.Source }
  foreach ($p in $extra) { if (Test-Path $p) { return $p } }
  return $null
}

function Tail($t, $n) { $t = ($t.Trim() -replace '\s+',' '); if ($t.Length -gt $n) { '...' + $t.Substring($t.Length-$n) } else { $t } }

function Short($t, $n) { $t = ($t.Trim() -replace '\s+',' '); if ($t.Length -gt $n) { $t.Substring(0,$n) } else { $t } }

function Q($x) { if ($x -match '[\s"]') { '"' + ($x -replace '"','\"') + '"' } else { $x } }

function Run-Try($exe, $argSets, $label) {
  $o = Join-Path $work "$label.out.txt"; $e = Join-Path $work "$label.err.txt"; $i = Join-Path $work 'empty.txt'
  Set-Content -Path $i -Value '' -NoNewline
  foreach ($a in $argSets) {
    $argStr = ($a | ForEach-Object { Q $_ }) -join ' '
    try {
      $pr = Start-Process -FilePath $exe -ArgumentList $argStr -NoNewWindow -Wait -PassThru `
            -RedirectStandardOutput $o -RedirectStandardError $e -RedirectStandardInput $i
      $code = $pr.ExitCode
    } catch { $code = -1; Set-Content -Path $e -Value $_.Exception.Message }
    $out = (Get-Content $o -Raw -ErrorAction SilentlyContinue) + ''
    $err = ((Get-Content $e -ErrorAction SilentlyContinue) | Where-Object { $_ -notmatch ' WARN ' }) -join ' '
    if ($code -eq 0 -and $out -match '\bOK\b') { Log ("{0} OK: {1}" -f $label, (Short $out 80)); return }
    Log ("{0} try failed, exit {1} ({2}): {3} | {4}" -f $label, $code, $argStr, (Tail $err 400), (Tail $out 150))
  }
  Log ("{0} FAILED" -f $label)
}

function Find-GitBash {
  $c = @("$env:ProgramFiles\Git\bin\bash.exe", "${env:ProgramFiles(x86)}\Git\bin\bash.exe", "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe", "$env:USERPROFILE\scoop\apps\git\current\bin\bash.exe")
  foreach ($x in $c) { if ($x -and (Test-Path $x)) { return $x } }
  foreach ($k in @('HKLM:\SOFTWARE\GitForWindows','HKCU:\SOFTWARE\GitForWindows','HKLM:\SOFTWARE\WOW6432Node\GitForWindows')) {
    $ip = (Get-ItemProperty -Path $k -ErrorAction SilentlyContinue).InstallPath
    if ($ip -and (Test-Path (Join-Path $ip 'bin\bash.exe'))) { return (Join-Path $ip 'bin\bash.exe') }
  }
  $g = Get-Command git -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($g) { $b = Join-Path (Split-Path (Split-Path $g.Source)) 'bin\bash.exe'; if (Test-Path $b) { return $b } }
  foreach ($root in @("$env:LOCALAPPDATA", "$env:ProgramFiles")) {
    $f = Get-ChildItem -Path $root -Filter bash.exe -Recurse -Depth 5 -ErrorAction SilentlyContinue | Where-Object { $_.FullName -match 'Git|git|Claude|claude' } | Select-Object -First 1
    if ($f) { return $f.FullName }
  }
  return $null
}
if (-not $env:CLAUDE_CODE_GIT_BASH_PATH) { $gb = Find-GitBash; if ($gb) { $env:CLAUDE_CODE_GIT_BASH_PATH = $gb; Log "git-bash: $gb" } else { Log 'git-bash: not found (Claude Code needs Git for Windows)' } }

$p = 'Reply with only: OK'

# --- Claude Code (must be logged in with your Claude subscription, NOT an API key) ---
if ($Target -ne 'Codex') {
$claude = Find-Exe 'claude' @("$env:USERPROFILE\.local\bin\claude.exe", "$env:APPDATA\npm\claude.cmd")
if ($claude) {
  Run-Try $claude @(,@(
    @('-p', $p, '--model', 'haiku', '--max-turns', '1', '--no-session-persistence')
  )) 'Claude'
} else { Log 'Claude: claude CLI not found' }
}

# --- Codex (must be logged in with your ChatGPT account) ---
if ($Target -ne 'Claude') {
$cache = Join-Path $here 'codex-path.txt'
$codex = $null
$cmd = Get-Command codex -ErrorAction SilentlyContinue | Select-Object -First 1
if ($cmd) { $codex = $cmd.Source; Set-Content -Path $cache -Value $codex -Encoding UTF8 }
if (-not $codex -and (Test-Path $cache)) { $c = (Get-Content $cache -Raw).Trim(); if ($c -and (Test-Path $c)) { $codex = $c } }
if (-not $codex) {
  foreach ($x in @("$env:APPDATA\npm\codex.cmd", "$env:LOCALAPPDATA\Microsoft\WindowsApps\codex.exe", "$env:LOCALAPPDATA\Programs\codex\codex.exe", "$env:USERPROFILE\.codex\bin\codex.exe", "$env:USERPROFILE\.local\bin\codex.exe")) { if (Test-Path $x) { $codex = $x; break } }
}
if (-not $codex) {
  foreach ($root in @("$env:LOCALAPPDATA\OpenAI\Codex\bin", "$env:ProgramFiles\WindowsApps", "$env:LOCALAPPDATA\Programs", "$env:LOCALAPPDATA\OpenAI", "$env:APPDATA", "$env:USERPROFILE\.codex")) {
    if (Test-Path $root) { $f = Get-ChildItem -Path $root -Filter 'codex*.exe' -Recurse -Depth 6 -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^codex(\.exe)?$' } | Select-Object -First 1; if ($f) { $codex = $f.FullName; break } }
  }
}
if ($codex) {
  Run-Try $codex @(,@(
    @('exec', '--skip-git-repo-check', '--ephemeral', '-c', 'model_reasoning_effort=low', $p)
  )) 'Codex'
} else { Log ('Codex: codex CLI not found. PATH has: ' + (Short $env:Path 300)) }
}


