@echo OFF

::This script merges input files. 
::Author: A.E.Veltstra for Mamiye Brothers, Inc.
::Original: 2019-09-19T10:29:00EST
::Version: 2019-09-19T10:46:00EST

::Set to 1 to enable verbose logging. Set to 0 to disable. 
set /A isDebugging=1

::DOS Extensions need to be enabled for the For /F command. Tends to be default.
::Delayed Expansion needs to be enabled for parsing the text files.
setlocal enableextensions enabledelayedexpansion

::The file name of this very script. 
set thisScript=%~nx0

::The name (without extension) of this very script. Is used in logging. 
set myScriptName=%~n0

::The folder where this script lives.
set myScriptFolder=%~dp0

::Error levels. Success = 0. Error levels come in powers of 2.
set /A SUCCESS=0
set /A MY_ERRORLEVEL=%SUCCESS%
set /A FAIL_FOLDER_NOT_FOUND=1
set /A FAIL_FILE_NOT_FOUND=2
set /A FAIL_CURRENT_DATETIME_NOT_FOUND=4
set /A FAIL_CURRENT_DATETIME_FORMAT_YIELDED_EMPTY=8

::The format for retrieving the current date and time.
set myDateTimeRetrievalFormat=yyyyMMdd'T'HHmmss

:getNow
::Retrieves the current date-time stamp from the system.
::Returns a variable "myNow": a string with format: "yyyyMMdd-HHmmss".
set myNow=[]
for /F "tokens=1 delims=" %%q in ('Powershell -Command "& {Get-Date -format "%myDateTimeRetrievalFormat%"}"') do (
  set myNow=%%q
)

::FAIL_CURRENT_DATETIME_NOT_FOUND
if []==[%myNow%] (
  echo "%date%-%time% Error %FAIL_CURRENT_DATETIME_NOT_FOUND% in %myScriptName%: Failed to find current date-time."
  if "%isDebugging%" NEQ 0 echo "%date%-%time% Debug info for %FAIL_CURRENT_DATETIME_NOT_FOUND% for %myScriptName%: Found date-time '%myNow%'."
  set /A "MY_ERRORLEVEL|=%FAIL_CURRENT_DATETIME_NOT_FOUND%"
  exit /B %MY_ERRORLEVEL%
)

::FAIL_CURRENT_DATETIME_FORMAT_YIELDED_EMPTY
if " "=="%myNow%" (
  echo "%date%-%time% Error %FAIL_CURRENT_DATETIME_FORMAT_YIELDED_EMPTY% in %myScriptName%: Current date-time format ('%myDateTimeRetrievalFormat%') yielded empty."
  if "%isDebugging%" NEQ 0 echo "%date%-%time% Debug info for %FAIL_CURRENT_DATETIME_FORMAT_YIELDED_EMPTY% for %myScriptName%: Found date-time '%myNow%'."
  set /A "MY_ERRORLEVEL|=%FAIL_CURRENT_DATETIME_FORMAT_YIELDED_EMPTY%"
  exit /B %MY_ERRORLEVEL%
)

::The name of the standard log for the merge processor.
set mergerStdOut=\\server\share\logs\bci\shipping-status\merging\test\merger-info.log


::Writing the current date/time to the merger-info log. These time stamps are used during audits.
echo.
echo %myNow%
echo Writing the current date/time to the merger-info log.
@echo ON
echo. >>"%mergerStdOut%"
echo %myNow% >>"%mergerStdOut%"
echo. >>"%mergerStdOut%"
@echo OFF

::FAIL_FILE_NOT_FOUND
if %errorlevel% NEQ 0 ( if %errorlevel% NEQ 9009 (
  echo.
  echo "%myNow% Error %errorlevel% in %myScriptName%: Failed to add current date/time to standard log file this merger: %mergerStdOut%."
  exit /B %errorlevel%
))


::The name of the error log for the merge processor.
set mergerStdErr=\\server\share\logs\bci\shipping-status\merging\test\merger-err.log

::Writing the current date/time to the merger-error log. These time stamps are used during audits.
echo.
echo %myNow%
echo Writing the current date/time to the merger-error log.
@echo ON
echo. >>"%mergerStdErr%"
echo %myNow% >>"%mergerStdErr%"
echo. >>"%mergerStdErr%"
@echo OFF

::FAIL_FILE_NOT_FOUND
if %errorlevel% NEQ 0 ( if %errorlevel% NEQ 9009 (
  echo.
  echo "%myNow% Error %errorlevel% in %myScriptName%: Failed to add current date/time to error log file this merger: %mergerStdErr%."
  exit /B %errorlevel%
))

::The file path to map to a local drive letter for use during this session.
::Must not end in \.
set remoteSourceFolder=\\server\share\docs\bci\shipping-status

::Mapping a local drive letter (W) for the operations.
echo.
echo %myNow%
echo Temporarily mapping local drive W to %remoteSourceFolder%.
@echo ON
net use W: "%remoteSourceFolder%" /PERSISTENT:NO 1>>"%mergerStdOut%" 2>>"%mergerStdErr%"
@echo OFF

::The file path of the folder that contains inputs for this merge. Requires a suffix \.
set inputFolder=W:\yet-to-merge\test\

::How to recognize the input files.
set inputFilePattern=shipping-status-*.xml

::The amount of files that fit the pattern.
set count=0

::Find the amount of files that matches the pattern.
echo.
echo %myNow%
echo Finding the amount of files that matches the pattern.
for /f %%i in ('dir /b /a-d "%inputFolder%%inputFilePattern%" ^| find /c /v ""') do (set /a count=%%i)
echo Amount of files found: %count%.

::Check the amount: if zero, quit.
if %count% EQU 0 (
  goto:log_warning_no_files_then_unmap_and_exit
)

::The name of the folder where this original files get archived to prevent repeats.
set archiveFolder=W:\yet-to-merge\test\archive

::The name of the folder where this merge needs to write merged file. Requires a suffix \.
set outputFolder=W:\merged\test\

::What to name the merged output file. Must not contain date/time, as the 
::parser of that file does not know GLOB pattern recognition.
set outputFileName=merged-shipping-statuses.xml


::Creating the output file with root element start tag.
echo.
echo Creating output file with root element start tag.
@echo ON
echo ^<start^> >> "%outputFolder%%outputFileName%" 2>>"%mergerStdErr%"
@echo OFF

if %errorlevel% NEQ 0 (
  goto:log_error_fail_create_file_with_start_tag_then_unmap_and_exit
)

::Read the input files, select the lines to output, then output those lines.
::Note: this requires enabledelayedexpansion.
echo.
echo %myNow%
echo Parsing input files, and write out wanted lines.
for /F "tokens=* delims=" %%a in ('type "%inputFolder%%inputFilePattern%"') do (
  set line=%%a
  if "!line:~0,2!" NEQ "<?" (
    if "!line!" NEQ "</start>" (
      if "!line!" NEQ "<start>" (
        echo !line! >> "%outputFolder%%outputFileName%"
      )
    )
  )
)


::Creating the file with root element end tag.
echo.
echo Writing root element end tag to output file.
@echo ON
echo ^</start^> >> "%outputFolder%%outputFileName%" 2>>"%mergerStdErr%"
@echo OFF

if %errorlevel% NEQ 0 (
  goto:log_error_fail_write_end_tag_file_then_unmap_and_exit
)

::Archiving
echo.
echo %myNow%
echo Archiving.
@echo ON
MOVE /Y "%inputFolder%%inputFilePattern%" "%archiveFolder%" 1>>"%mergerStdOut%" 2>>"%mergerStdErr%"
@echo OFF

::Unmapping a local drive letter (W) used for the operations.
:unmap_then_exit
echo.
echo %myNow%
echo Unmapping local drive W.
@echo ON
net use W: /DELETE /Y 2>>"%mergerStdErr%"
@echo OFF
goto:exit

:log_warning_no_files_then_unmap_and_exit
echo.
echo "%myNow% Info from %myScriptName%: no files found in input folder '%remoteSourceFolder%' that match pattern '%inputFilePattern%'."
set /A "MY_ERRORLEVEL|=%FAIL_FILE_NOT_FOUND%"
goto:unmap_then_exit

:log_error_fail_create_file_with_start_tag_then_unmap_and_exit
echo.
echo "%myNow% Error %errorlevel% in %myScriptName%: Failed to create new output file with the root start tag: %outputFileName%."
set /A "MY_ERRORLEVEL|=%errorlevel%"
goto:unmap_then_exit

:log_error_fail_write_end_tag_file_then_unmap_and_exit
echo.
echo "%myNow% Error %errorlevel% in %myScriptName%: Failed to write the root end tag to output file: %outputFileName%."
set /A "MY_ERRORLEVEL|=%errorlevel%"
goto:unmap_then_exit

:exit
echo.
echo %myNow%
echo Done

exit /B %MY_ERRORLEVEL%
