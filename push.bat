@echo off
chcp 65001 >nul
echo ==========================================
echo 🚀 Kodlar Lokalden GitHub'a Firlatiliyor...
echo ==========================================

:: 1. Butun degisiklikleri sahneye al
git add .

:: 2. Commit mesaji kontrolu ve Tirnak Temizligi
if "%~1"=="" (
    set "COMMIT_MSG=Auto-update: %DATE% %TIME%"
    echo [!] Commit mesaji girilmedi, otomatik muhur vuruluyor: %DATE% %TIME%
) else (
    :: Girdideki tum tirnaklari (") silip temizliyoruz
    set "COMMIT_MSG=%*"
    setlocal EnableDelayedExpansion
    set "COMMIT_MSG=!COMMIT_MSG:"=!"
    echo [i] Commit mesajin: !COMMIT_MSG!
)

:: 3. Muhurle ve Gonder (Delayed Expansion ile degiskeni guvenli al)
git commit -m "!COMMIT_MSG!"
git push origin main
endlocal

echo ==========================================
echo ✅ ISLEM TAMAM! Yeni kodlar jilet gibi GitHub'da.
echo ==========================================