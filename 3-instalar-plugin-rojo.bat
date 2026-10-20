@echo off
cd /d "%~dp0"
echo Instalando o plugin do Rojo no Roblox Studio...
echo (o Roblox Studio precisa ter sido aberto pelo menos uma vez)
tools\rojo.exe plugin install
echo.
echo Feche e abra o Roblox Studio de novo para o plugin aparecer.
pause
