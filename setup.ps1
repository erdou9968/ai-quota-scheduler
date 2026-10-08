# One-time setup: register two daily scheduled tasks (Claude and Codex at staggered times).
param(
  [string[]]$ClaudeTimes = @('05:00','10:05','15:10','20:15'),
  [string[]]$CodexTimes  = @('07:30','12:35','17:40')
)
# Times are BEIJING time (UTC+8). Triggers carry a +08:00 offset (= 'Synchronize across time zones'),
# so they fire at the same Beijing time whatever the Windows time zone or daylight saving is.
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$wake = Join-Path $here 'wake.ps1'
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -WakeToRun -AllowStartIfOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 10)

function Reg($name, $target, $times) {
  $action  = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ("-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"{0}`" -Target {1}" -f $wake, $target)
  $trigger = @($times | ForEach-Object {
    $t = New-ScheduledTaskTrigger -Daily -At $_
    $t.StartBoundary = ('{0}T{1}:00+08:00' -f ([DateTime]::UtcNow.AddHours(8).ToString('yyyy-MM-dd')), $_)
    $t
  })
  Register-ScheduledTask -TaskName $name -Action $action -Trigger $trigger -Settings $settings -Description "Ping $target so its 5-hour usage window resets mid-work" -Force | Out-Null
  Write-Host ("Registered {0}: daily at {1} Beijing time" -f $name, ($times -join ', '))
}
Reg 'AI-Quota-Wake-Claude' 'Claude' $ClaudeTimes
Reg 'AI-Quota-Wake-Codex' 'Codex'  $CodexTimes
Get-ScheduledTask -TaskName 'AI-Quota-Wake-*' | ForEach-Object { $n=$_.TaskName; $_.Triggers | ForEach-Object { Write-Host ('  {0} next local start boundary: {1}' -f $n, $_.StartBoundary) } }
Write-Host 'Installed. To test once, run wake.ps1 -Target Both (this uses a little quota and changes the current window).'


