@echo off
cd /d "%~dp0"
echo Gerando MMOTESTE.rbxlx a partir da pasta src...
tools\rojo.exe build default.project.json -o MMOTESTE.rbxlx
if errorlevel 1 (
  echo.
  echo ERRO ao gerar o arquivo. Veja a mensagem acima.
) else (
  echo.
  echo Pronto! Abra MMOTESTE.rbxlx no Roblox Studio e aperte Play ^(F5^).
)
pause
