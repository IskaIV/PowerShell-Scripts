
# RestartAfterProcess.ps1
# Waits for a user-selected process to exit before restarting the computer.

# Get user-facing processes (with window titles)
$processes = Get-Process | Where-Object { $_.MainWindowTitle -ne "" } | Sort-Object ProcessName

if (-not $processes)
{
    Write-Host "No active user-facing tasks found." -ForegroundColor Yellow
    exit 1
}

# Prepare display table with index
$i = 0
$indexedList = foreach ($process in $processes)
{
    [PSCustomObject]@{
        Index = ++$i
        Name  = $process.ProcessName
        PID   = $process.Id
        Title = $process.MainWindowTitle
    }
}

# Display as formatted table
Write-Host "`nSelect a process to wait for before restarting the system:`n"
$indexedList | Format-Table -AutoSize -Property @{
    Name       = 'Index';
    Expression = { $_.'Index' };
    Alignment  = 'Left'
}, Name, PID, Title

# Prompt for user input
$choice = Read-Host "`nEnter the index number of the process to wait for"
if (-not ($choice -as [int]) -or $choice -lt 1 -or $choice -gt $indexedList.Count)
{
    Write-Host "Invalid selection." -ForegroundColor Red
    exit 1
}

$selected = $indexedList[$choice - 1]
Write-Host "`nWaiting for '$($selected.Name)' (PID: $($selected.PID)) to exit..."

try
{
    Wait-Process -Id $selected.PID
    Write-Host "`nProcess has exited."

    # Countdown before reboot
    $countdown = 10
    Write-Host "`nSystem will restart in $countdown seconds. Press Ctrl+C to abort." -ForegroundColor Red
    for ($j = $countdown; $j -gt 0; $j--)
    {
        Write-Host "$j..." -ForegroundColor Green -NoNewline
        Start-Sleep -Seconds 1.5
        Write-Host " `b`b`b`b`b`b" -NoNewline
    }

    Write-Host "`nRestarting now."
    Restart-Computer

}
catch
{
    Write-Host "Error: Could not wait on process or restart failed." -ForegroundColor Red
    Write-Host $_.Exception.Message
    exit 1
}