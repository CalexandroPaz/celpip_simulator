@echo off
title CELPIP Simulator - Setup
color 0A

echo.
echo  ============================================
echo   CELPIP Simulator - Configuracion Android
echo  ============================================
echo.

REM ── Paso 1: Flutter ──────────────────────────────────────────────────────
echo [1/4] Verificando Flutter...
flutter --version >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo       Flutter ya esta instalado. OK
    goto :android_studio_check
)

echo       Flutter no encontrado. Instalando via winget...
winget install Google.Flutter --accept-package-agreements --accept-source-agreements
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo  ERROR: winget no pudo instalar Flutter.
    echo  Descargalo manualmente desde: https://docs.flutter.dev/get-started/install/windows
    echo  Extrae el zip en C:\flutter y agrega C:\flutter\bin al PATH.
    echo.
    pause
    exit /b 1
)

echo.
echo  Flutter instalado. IMPORTANTE: cierra esta ventana,
echo  abre una NUEVA terminal y vuelve a ejecutar este script.
echo.
pause
exit /b 0

REM ── Paso 2: Android Studio ───────────────────────────────────────────────
:android_studio_check
echo.
echo [2/4] Verificando Android Studio...
if exist "%LOCALAPPDATA%\Programs\Android Studio\bin\studio64.exe" (
    echo       Android Studio encontrado. OK
) else if exist "%ProgramFiles%\Android\Android Studio\bin\studio64.exe" (
    echo       Android Studio encontrado. OK
) else (
    echo       Android Studio NO encontrado.
    echo       Descargalo desde: https://developer.android.com/studio
    echo       Instalalo y vuelve a ejecutar este script.
    echo.
    start https://developer.android.com/studio
    pause
    exit /b 1
)

REM ── Paso 3: Generar archivos Android que faltan ───────────────────────────
echo.
echo [3/4] Completando estructura del proyecto Android...
cd /d "%~dp0"
flutter create --platforms=android . 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo  ADVERTENCIA: flutter create retorno un error. Continuando...
)

REM ── Paso 4: Dependencias ──────────────────────────────────────────────────
echo.
echo [4/4] Instalando dependencias (flutter pub get)...
flutter pub get
if %ERRORLEVEL% NEQ 0 (
    echo  ERROR en flutter pub get. Revisa el pubspec.yaml.
    pause
    exit /b 1
)

REM ── Resultado ─────────────────────────────────────────────────────────────
echo.
echo  ============================================
echo   Setup completado con exito!
echo  ============================================
echo.
echo   Proximos pasos:
echo.
echo   1. Abre Android Studio
echo   2. Ve a: More Actions - Virtual Device Manager
echo   3. Crea un AVD: Pixel 7 con API 34 (Android 14)
echo   4. Inicia el emulador
echo   5. Vuelve aqui y ejecuta:  flutter run
echo.
echo   Para diagnosticar problemas:  flutter doctor
echo.
pause
