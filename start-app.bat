@echo off
cd /d "%~dp0"

if not exist node_modules (
    echo Installation des dependances, premiere fois seulement...
    call npm install
    if errorlevel 1 (
        echo.
        echo L'installation a echoue. Regarde les erreurs ci-dessus.
        pause
        exit /b 1
    )
)

echo.
echo Demarrage de l'application...
echo Une fois "Ready" affiche, ouvre http://localhost:3000 dans ton navigateur.
echo Laisse cette fenetre ouverte tant que tu utilises l'app.
echo.

call npm run dev

echo.
echo Le serveur s'est arrete.
pause
