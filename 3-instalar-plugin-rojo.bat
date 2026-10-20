@echo off
cd /d "%~dp0"
set ROJO=tools\rojo.exe
if not exist "%ROJO%" (
  where rojo >nul 2>nul && set ROJO=rojo
)
if "%ROJO%"=="tools\rojo.exe" if not exist "tools\rojo.exe" goto semrojo

echo Instalando o plugin do Rojo no Roblox Studio...
echo (o Roblox Studio precisa ter sido aberto pelo menos uma vez)
%ROJO% plugin install
echo.
echo Feche e abra o Roblox Studio de novo para o plugin aparecer.
pause
exit /b

:semrojo
echo Rojo nao encontrado.
echo Baixe em https://github.com/rojo-rbx/rojo/releases e coloque o rojo.exe na pasta tools.
pause
