@echo off
rem Grade a query against a tier's reference: same columns (name, type, order)
rem and the same multiset of rows.
rem   scripts\check.bat <dataset> <tier> <candidate.sql>
rem Prints any column differences, up to 20 differing rows, and a final
rem EQUAL / DIFFERENT line; exits 0 only on EQUAL.
rem Needs: duckdb.exe on PATH; datasets\<dataset>\setup.bat run once.
setlocal
cd /d "%~dp0.."
set db=datasets\%1\warehouse.duckdb
set reference=exercises\%1\%2\reference.sql
if not exist "%db%" (echo no %db% - run datasets\%1\setup.bat first 1>&2 & exit /b 1)
if not exist "%reference%" (echo no such tier: %reference% 1>&2 & exit /b 1)
if not exist "%3" (echo no such file: %3 1>&2 & exit /b 1)

set tmp=%TEMP%\fcq-check-%RANDOM%.txt
(
  echo create temp table expected as
  type "%reference%"
  echo ;
  echo create temp table actual as
  type "%3"
  echo ;
  type scripts\check.sql
) | duckdb -readonly "%db%" > "%tmp%"
type "%tmp%"
findstr /b /c:"EQUAL" "%tmp%" >nul
set rc=%errorlevel%
del "%tmp%"
exit /b %rc%
