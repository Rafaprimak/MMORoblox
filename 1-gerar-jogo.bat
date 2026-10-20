@echo off
cd /d "%~dp0"
set ROJO=tools\rojo.exe
if not exist "%ROJO%" (
  where rojo >nul 2>nul && set ROJO=rojo
)
if "%ROJO%"=="tools\rojo.exe" if not exist "tools\rojo.exe" goto semrojo

echo Gerando MMOTESTE.rbxlx a partir da pasta src...
%ROJO% build default.project.json -o MMOTESTE.rbxlx
if errorlevel 1 (
  echo.
  echo ERRO ao gerar o arquivo. Veja a mensagem acima.
) else (
  echo.
  echo Pronto! Abra MMOTESTE.rbxlx no Roblox Studio e aperte Play ^(F5^).
)
pause
exit /b

:semrojo
echo Rojo nao encontrado.
echo Baixe em https://github.com/rojo-rbx/rojo/releases
echo (arquivo rojo-VERSAO-windows-x86_64.zip) e coloque o rojo.exe na pasta tools.
pause
