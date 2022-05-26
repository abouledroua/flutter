@echo off
rem This file was created by pub v2.17.0-67.0.dev.
rem Package: devtools
rem Version: 2.9.3
rem Executable: devtools
rem Script: devtools
if exist "C:\flutter\.pub-cache\global_packages\devtools\bin\devtools.dart-2.17.0-67.0.dev.snapshot" (
  call dart "C:\flutter\.pub-cache\global_packages\devtools\bin\devtools.dart-2.17.0-67.0.dev.snapshot" %*
  rem The VM exits with code 253 if the snapshot version is out-of-date.
  rem If it is, we need to delete it and run "pub global" manually.
  if not errorlevel 253 (
    goto error
  )
  dart pub global run devtools:devtools %*
) else (
  dart pub global run devtools:devtools %*
)
goto eof
:error
exit /b %errorlevel%
:eof

