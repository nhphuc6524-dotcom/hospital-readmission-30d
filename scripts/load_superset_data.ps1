# Run from D:\Readmission_Project. Imports ONLY locked Test scores into dm_course.
# Never drops / modifies Star Schema or staging. Requires PostgreSQL psql.
[CmdletBinding()]
param(
    [string]$Root = 'D:\Readmission_Project',
    [string]$Database = 'dm_course',
    [string]$DbUser = 'postgres',
    [string]$DbHost = '127.0.0.1',
    [int]$DbPort = 5432
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$SqlDir = Join-Path $Root 'sql'
$Csv = Join-Path $Root 'reports\superset\test_predictions_local_only.csv'
foreach ($path in @($Csv,
    (Join-Path $SqlDir '05-dashboard-setup.sql'),
    (Join-Path $SqlDir '06-dashboard-views.sql'),
    (Join-Path $SqlDir '07-dashboard-check.sql'))) {
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Thieu file: $path" }
}
$cmd = Get-Command 'psql.exe' -ErrorAction SilentlyContinue
if ($cmd) { $Psql = $cmd.Source }
else {
    $Psql = 'C:\Program Files\PostgreSQL\17\bin\psql.exe'
    if (!(Test-Path $Psql)) { throw 'Khong tim thay psql.exe' }
}
Write-Host "Database: $Database" -ForegroundColor Cyan
Write-Host "SQL: $SqlDir" -ForegroundColor Cyan
Write-Host 'Chi tao dashboard.* va nap 15219 dong TEST. Khong xoa dw.*.' -ForegroundColor Yellow
$answer = Read-Host 'Nhap DASHBOARD de xac nhan'
if ($answer -cne 'DASHBOARD') { throw 'Da huy.' }

$env:PGCLIENTENCODING = 'UTF8'
$hadPassword = Test-Path Env:\PGPASSWORD
if (-not $hadPassword) {
    $secret = Read-Host 'Nhap mat khau PostgreSQL' -AsSecureString
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
    try { $env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
}
try {
    function Invoke-File([string]$f) {
        Write-Host "Chay $f" -ForegroundColor Cyan
        & $Psql -X -v ON_ERROR_STOP=1 -h $DbHost -p $DbPort `
            -U $DbUser -d $Database -f (Join-Path $SqlDir $f) | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "SQL that bai: $f" }
    }
    Invoke-File '05-dashboard-setup.sql'

    # Atomic refresh: TRUNCATE and \copy in ONE transaction.
    # In case of COPY failure, transaction is rolled back.
    $csvPath = $Csv.Replace('\','/').Replace("'", "''")
    $tmp = Join-Path $env:TEMP ('dashboard_import_' + [guid]::NewGuid().ToString('N') + '.sql')
    $sqlTemplate = @'
BEGIN;
TRUNCATE dashboard.test_predictions;
\copy dashboard.test_predictions (encounter_id, dt_score, rf_score, dt_top10, rf_top10, dt_decile, rf_decile) FROM '__CSV_PATH__' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
DO $$ BEGIN
  IF (SELECT COUNT(*) FROM dashboard.test_predictions) <> 15219 THEN
    RAISE EXCEPTION 'Expected 15219 locked Test rows';
  END IF;
END $$;
COMMIT;
'@
    $sqlImport = $sqlTemplate.Replace('__CSV_PATH__', $csvPath)
    [System.IO.File]::WriteAllText($tmp, $sqlImport, (New-Object System.Text.UTF8Encoding($false)))
    try {
        Write-Host 'Nap 15219 diem du doan Test vao dashboard.test_predictions...' -ForegroundColor Cyan
        & $Psql -X -v ON_ERROR_STOP=1 -h $DbHost -p $DbPort `
            -U $DbUser -d $Database -f $tmp | Out-Host
        if ($LASTEXITCODE -ne 0) { throw 'Nap CSV that bai; transaction rollback.' }
    } finally {
        Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue
    }

    Invoke-File '06-dashboard-views.sql'
    Invoke-File '07-dashboard-check.sql'
    Write-Host ''
    Write-Host 'DASHBOARD DATA PASS' -ForegroundColor Green
    Write-Host 'Superset Datasets: dashboard.v_full_overview, dashboard.v_test_eval, dashboard.v_model_scorecard'
} finally {
    if (-not $hadPassword) { Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue }
}
