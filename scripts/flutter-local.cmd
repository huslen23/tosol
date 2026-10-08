@echo off
setlocal
rem Use the workspace SDK and keep telemetry state within the workspace.
set "FLUTTER_ROOT=%~dp0..\.tools\flutter"
set "APPDATA=%~dp0..\.tools\appdata"
set "CI=true"
set "ANDROID_USER_HOME=%~dp0..\.tools\android"
if not exist "%FLUTTER_ROOT%\bin\cache\flutter_tools.snapshot" (
  echo Workspace Flutter SDK missing. Copy your installed SDK to .tools\flutter first.
  exit /b 1
)
"%FLUTTER_ROOT%\bin\cache\dart-sdk\bin\dart.exe" "%FLUTTER_ROOT%\bin\cache\flutter_tools.snapshot" --no-version-check %*
exit /b %errorlevel%
