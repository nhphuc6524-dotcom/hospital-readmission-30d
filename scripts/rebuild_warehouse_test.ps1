# rebuild_warehouse_test.ps1
# De tai 5 - Kiem tra tai lap PostgreSQL Star Schema va OLAP
# Su dung SQL CHINH tai D:\Readmission_Project\sql (khong dung review_package\sql).
# CANH BAO: Xoa va tao lai bang staging/dw trong database THU NGHIEM.

[CmdletBinding()]
param(
    [string]$Root = "D:\Readmission_Project",
    [string]$TestDb = "dm_course_rebuild_test",
    [string]$DbUser = "postgres",
    [string]$DbHost = "127.0.0.1",
    [int]$DbPort = 5432
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Khong bao gio chay tren database chinh / database he thong.
if ($TestDb.ToLowerInvariant() -in @("dm_course", "postgres", "template0", "template1")) {
    throw "Database '$TestDb' khong duoc phep. Hay dung database thu nghiem dm_course_rebuild_test."
}

$SqlDir = Join-Path $Root "sql"
$Csv = Join-Path $Root "data\processed\step3_cleaned.csv"
$ReportDir = Join-Path $Root "reports\warehouse"

Write-Host "PROJECT ROOT : $Root" -ForegroundColor Cyan
Write-Host "SQL DIRECTORY: $SqlDir" -ForegroundColor Cyan
Write-Host "TEST DATABASE: $TestDb" -ForegroundColor Cyan

if (-not (Test-Path -LiteralPath $SqlDir -PathType Container)) {
    throw "Khong tim thay thu muc SQL chinh: $SqlDir"
}
if (-not (Test-Path -LiteralPath $Csv -PathType Leaf)) {
    throw "Khong tim thay $Csv. Hay chay 03_preprocessing.ipynb truoc."
}

$RequiredSql = @(
    "01-staging.sql",
    "02-star-schema.sql",
    "03-transform.sql",
    "04-olap.sql"
)
$MissingSql = @($RequiredSql | Where-Object {
    -not (Test-Path -LiteralPath (Join-Path $SqlDir $_) -PathType Leaf)
})
if ($MissingSql.Count -gt 0) {
    Write-Host "Cac file hien co:" -ForegroundColor Yellow
    Get-ChildItem -LiteralPath $SqlDir -Filter "*.sql" -File |
        Select-Object -ExpandProperty Name | Out-Host
    throw "Thieu file trong ${SqlDir}: $($MissingSql -join ', ')"
}

# Tim psql.exe tren PATH; neu khong co, tim tai thu muc cai PostgreSQL.
$PsqlCmd = Get-Command "psql.exe" -ErrorAction SilentlyContinue
if ($null -ne $PsqlCmd) {
    $Psql = $PsqlCmd.Source
} else {
    $PsqlCandidates = @(Get-ChildItem `
        -Path "C:\Program Files\PostgreSQL\*\bin\psql.exe" `
        -File -ErrorAction SilentlyContinue |
        Sort-Object -Property FullName -Descending)
    if ($PsqlCandidates.Count -eq 0) {
        throw "Khong tim thay psql.exe. Kiem tra PostgreSQL hoac them bin vao PATH."
    }
    $Psql = $PsqlCandidates[0].FullName
}

$env:PGCLIENTENCODING = "UTF8"
New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null

Write-Host ""
Write-Host "CANH BAO: Script se DROP/CREATE cac bang staging va dw trong '$TestDb'." -ForegroundColor Yellow
Write-Host "KHONG thuc hien tren database dm_course dang su dung cho Superset." -ForegroundColor Yellow
$Answer = Read-Host "Nhap REBUILD de tiep tuc"
if ($Answer -cne "REBUILD") {
    throw "Da huy theo yeu cau. Du lieu khong bi thay doi."
}

Write-Host "Kiem tra ket noi PostgreSQL..." -ForegroundColor Cyan
& $Psql -X -v ON_ERROR_STOP=1 -h $DbHost -p $DbPort `
    -U $DbUser -d $TestDb -A -t -c "SELECT current_database();" | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "Khong ket noi duoc '$TestDb'. Hay tao DB thu nghiem trong pgAdmin truoc."
}

function Invoke-SqlFile {
    param([string]$Filename)
    $FilePath = Join-Path $SqlDir $Filename
    Write-Host ">> Dang chay $Filename" -ForegroundColor Cyan
    & $Psql -X -v ON_ERROR_STOP=1 -h $DbHost -p $DbPort `
        -U $DbUser -d $TestDb -f $FilePath | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "Loi khi chay SQL: $Filename"
    }
}

function Get-WarehouseSummary {
    $Sql = @"
SELECT COUNT(*)::text || '|' ||
       COUNT(DISTINCT encounter_id)::text || '|' ||
       COALESCE(SUM(readmitted_30d), 0)::text || '|' ||
       (SELECT COUNT(DISTINCT patient_nbr)::text FROM dw.dim_patient)
FROM dw.fact_admission;
"@
    $Result = (& $Psql -X -v ON_ERROR_STOP=1 -A -t -h $DbHost -p $DbPort `
        -U $DbUser -d $TestDb -c $Sql | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) {
        throw "Khong truy van duoc thong ke DW."
    }
    return $Result
}

function Invoke-Rebuild {
    param([string]$ReportFilename)

    Invoke-SqlFile "01-staging.sql"

    # Client-side \copy: duong dan CSV la duong dan may local.
    $CsvSqlPath = $Csv.Replace("\", "/").Replace("'", "''")
    $CopySql = "\copy staging.admissions_raw FROM '$CsvSqlPath' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')"
    Write-Host ">> Dang nap CSV (local)..." -ForegroundColor Cyan
    & $Psql -X -v ON_ERROR_STOP=1 -h $DbHost -p $DbPort `
        -U $DbUser -d $TestDb -c $CopySql | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "Nap CSV that bai. Kiem tra file, thu tu 55 cot va thong bao PostgreSQL."
    }

    Invoke-SqlFile "02-star-schema.sql"
    Invoke-SqlFile "03-transform.sql"

    $Summary = Get-WarehouseSummary
    $Expected = "101766|101766|11357|71518"
    Write-Host "DW Summary: $Summary"
    if ($Summary -ne $Expected) {
        throw "Sai so lieu. Expected: $Expected. Actual: $Summary"
    }

    $OutputFile = Join-Path $ReportDir $ReportFilename
    Write-Host ">> Dang chay OLAP: 04-olap.sql" -ForegroundColor Cyan
    & $Psql -X -v ON_ERROR_STOP=1 -A -F "," -t `
        -h $DbHost -p $DbPort -U $DbUser -d $TestDb `
        -f (Join-Path $SqlDir "04-olap.sql") -o $OutputFile | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "OLAP that bai. Kiem tra file 04-olap.sql."
    }

    return [PSCustomObject]@{
        Summary = $Summary
        OutputFile = $OutputFile
    }
}

Write-Host "===== REBUILD LAN 1 =====" -ForegroundColor Green
$First = Invoke-Rebuild "olap_run_1.txt"

Write-Host "===== REBUILD LAN 2 =====" -ForegroundColor Green
$Second = Invoke-Rebuild "olap_run_2.txt"

if ($First.Summary -ne $Second.Summary) {
    throw "Hai lan rebuild co thong ke khac nhau."
}

$Hash1 = (Get-FileHash -LiteralPath $First.OutputFile -Algorithm SHA256).Hash
$Hash2 = (Get-FileHash -LiteralPath $Second.OutputFile -Algorithm SHA256).Hash

if ($Hash1 -ne $Hash2) {
    throw "Hai lan rebuild cho ket qua OLAP khac nhau. Can xem xet ORDER BY va tinh on dinh cua truy van."
}

Write-Host ""
Write-Host "REBUILD PASS" -ForegroundColor Green
Write-Host "Hai lan nap DW va chay OLAP co ket qua trung nhau." -ForegroundColor Green
Write-Host "Bao cao: $ReportDir"
