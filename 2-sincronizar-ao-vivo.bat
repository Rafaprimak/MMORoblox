@echo off
cd /d "%~dp0"
echo Servidor Rojo ligado. Deixe esta janela aberta.
echo No Roblox Studio: aba Plugins, botao Rojo, depois Connect.
echo Qualquer arquivo alterado em src aparece no Studio na hora.
echo.
tools\rojo.exe serve default.project.json
pause
