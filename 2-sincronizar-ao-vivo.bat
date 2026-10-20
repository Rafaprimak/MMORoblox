@echo off
cd /d "%~dp0"
set ROJO=tools\rojo.exe
if not exist "%ROJO%" (
  where rojo >nul 2>nul && set ROJO=rojo
)
if "%ROJO%"=="tools\rojo.exe" if not exist "tools\rojo.exe" goto semrojo

echo Servidor Rojo ligado. Deixe esta janela aberta.
echo No Roblox Studio: aba Plugins, botao Rojo, depois Connect.
echo Qualquer arquivo alterado em src aparece no Studio na hora.
echo.
%ROJO% serve default.project.json
pause
exit /b

:semrojo
echo Rojo nao encontrado.
echo Baixe em https://github.com/rojo-rbx/rojo/releases e coloque o rojo.exe na pasta tools.
pause
