@echo off
rem Grade one pack query against another: the same multiset of rows, each row
rem compared as the text of its struct (so column names/types/order matter).
rem   scripts\check-pack.bat <dataset> <expected.sql> <candidate.sql>
rem Both .sql files are bare SELECTs (no semicolon); they are wrapped as temp
rem views and diffed with the pack_diff macro (exercises\<dataset>\check.sql).
rem Prints up to 20 differing rows and a final EQUAL / DIFFERENT line; exits 0
rem only on EQUAL.
rem Needs: the duckdb CLI on PATH; datasets\<dataset>\setup.bat run once.
setlocal enabledelayedexpansion
cd /d "%~dp0.."
set dataset=%1
set expected=%2
set candidate=%3
set db=datasets\%dataset%\warehouse.duckdb
set macro=exercises\%dataset%\check.sql
if not exist "%db%" (echo no %db% - run datasets\%dataset%\setup.bat first 1>&2 & exit /b 1)
if not exist "%macro%" (echo no %macro% 1>&2 & exit /b 1)
if not exist "%expected%" (echo no such file: %expected% 1>&2 & exit /b 1)
if not exist "%candidate%" (echo no such file: %candidate% 1>&2 & exit /b 1)

set tmpsql=%TEMP%\check-pack-%RANDOM%.sql
set tmpout=%TEMP%\check-pack-%RANDOM%.out
(
  type "%macro%"
  echo ;
  echo create temp view expected as
  type "%expected%"
  echo ;
  echo create temp view actual as
  type "%candidate%"
  echo ;
  echo .mode list
  echo .headers off
  echo .separator '  '
  echo create temp table pack_row_diff as select * from pack_diff('expected', 'actual'^);
  echo select '-- rows differ (first 20; missing = in the expected pack only, unexpected = in the candidate only^):' where exists (from pack_row_diff^);
  echo select side, row from pack_row_diff order by side desc, row limit 20;
  echo select case when (select count(*^) from pack_row_diff^) = 0 then 'EQUAL' else 'DIFFERENT: ' ^|^| (select count(*^) from pack_row_diff where side = 'missing'^) ^|^| ' row(s^) missing, ' ^|^| (select count(*^) from pack_row_diff where side = 'unexpected'^) ^|^| ' row(s^) unexpected' end;
) > "%tmpsql%"

duckdb -readonly "%db%" < "%tmpsql%" > "%tmpout%"
type "%tmpout%"
findstr /b "EQUAL" "%tmpout%" >nul
set verdict=%errorlevel%
del "%tmpsql%" "%tmpout%" 2>nul
exit /b %verdict%
