@echo off
rem Download the saas-billing warehouse (a DuckDB file) into this directory.
rem Needs: curl, certutil (both ship with Windows 10+).
setlocal
cd /d "%~dp0"

set TAG=saas-billing-v1
set ASSET=saas-billing.duckdb
set SHA256=8f0df8b86cbcb65a8a920657286b17f32a1fffc37875050db97cbe8a5a4a7fef
set URL=https://github.com/leogodin217/fabulexa_complex_queries/releases/download/%TAG%/%ASSET%
set OUT=warehouse.duckdb

if exist "%OUT%" (
  call :verify "%OUT%" && (echo %OUT% already present and verified & exit /b 0)
)

echo downloading %URL%
curl -L --fail --progress-bar -o "%OUT%.part" "%URL%" || exit /b 1
call :verify "%OUT%.part" || (
  del "%OUT%.part"
  echo sha256 mismatch - download discarded 1>&2
  exit /b 1
)
move /y "%OUT%.part" "%OUT%" >nul
echo ok: %OUT%
exit /b 0

:verify
for /f "skip=1 tokens=* delims=" %%h in ('certutil -hashfile "%~1" SHA256') do (
  if /i "%%h"=="%SHA256%" exit /b 0
  goto :verify_fail
)
:verify_fail
exit /b 1
