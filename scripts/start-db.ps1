# start-db.ps1 - start the Tahanan PostgreSQL 18 cluster safely on Windows.
#
# Why this exists: this machine has 8 GB RAM, two antivirus products, and a lot of
# processes. PostgreSQL on Windows must create one child process per connection and
# map a shared-memory section into it at a fixed address. Under memory pressure that
# fails with 0xC0000142 (DLL init failed) or error 487 (cannot reserve address), and
# the postmaster then restarts. If the postmaster is killed while a child survives,
# that orphan keeps the shared-memory section alive and every later start fails with
# "pre-existing shared memory block is still in use". This script clears that state
# and starts the cluster with the low-memory profile.

$ErrorActionPreference = 'SilentlyContinue'

$bin  = 'C:\Program Files\PostgreSQL\18\bin'
$data = 'C:\Users\caloy\AppData\Local\Tahanan\pgdata'
$log  = 'C:\Users\caloy\AppData\Local\Tahanan\pg-run.log'

function Test-PgListening {
    return [bool](Get-NetTCPConnection -LocalPort 5432 -State Listen -ErrorAction SilentlyContinue |
        Select-Object -First 1)
}

if (Test-PgListening) {
    Write-Host 'PostgreSQL is already listening on 5432.'
    exit 0
}

# Kill any survivor (pg_ctl, postmaster or an io_worker orphan). An orphaned child
# inherits the shared-memory handle, which is what blocks the next start.
Get-CimInstance Win32_Process -Filter "Name='postgres.exe'" -ErrorAction SilentlyContinue |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Get-Process pg_ctl -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3

Remove-Item "$data\postmaster.pid" -Force -ErrorAction SilentlyContinue

Start-Process -FilePath "$bin\pg_ctl.exe" `
    -ArgumentList @('start', '-D', $data, '-l', $log) `
    -NoNewWindow `
    -RedirectStandardOutput "$env:TEMP\pg-start.out" `
    -RedirectStandardError  "$env:TEMP\pg-start.err" | Out-Null

for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Seconds 1
    if (Test-PgListening) { break }
}

if (Test-PgListening) {
    Write-Host 'PostgreSQL started on 5432.'
    exit 0
}

Write-Host 'PostgreSQL did not start. Last log lines:'
Get-Content $log -Tail 15 -ErrorAction SilentlyContinue
exit 1
