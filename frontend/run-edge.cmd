@echo off
setlocal
pushd "%~dp0"
call flutter run -d edge --web-hostname localhost --web-port 7357 --dart-define=GOOGLE_WEB_CLIENT_ID=351918317441-pi5k99jf1coli2mfie4hqn7v7v48dlh1.apps.googleusercontent.com %*
set "flutter_exit=%errorlevel%"
popd
exit /b %flutter_exit%
