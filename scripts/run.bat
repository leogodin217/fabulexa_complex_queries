@echo off
rem Run one query file against a dataset's warehouse and print the result.
rem   scripts\run.bat <dataset> <query.sql>            table on stdout
rem   scripts\run.bat <dataset> <query.sql> out.csv    CSV to a file
rem Needs: duckdb.exe on PATH; datasets\<dataset>\setup.bat run once.
setlocal
cd /d "%~dp0.."
set db=datasets\%1\warehouse.duckdb
if not exist "%db%" (echo no %db% - run datasets\%1\setup.bat first 1>&2 & exit /b 1)
if "%~3"=="" (
  duckdb -readonly "%db%" < "%2"
) else (
  duckdb -readonly -csv "%db%" < "%2" > "%3"
  echo wrote %3
)
