# =====================================================================
# ShieldNet - Script de Lancement de l'Environnement de Développement
# =====================================================================
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "         SHIELDNET - DEMARRAGE DU SERVEUR DE DEV         " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

$rootPath = $PSScriptRoot
$backendPath = Join-Path $rootPath "shieldnet_backend"

# 1. Migrations Django
Write-Host "1. Application des migrations Django..." -ForegroundColor Yellow
Start-Process python -ArgumentList "manage.py migrate" -WorkingDirectory $backendPath -NoNewWindow -Wait

# 2. Configuration automatique du tunnel USB Android (adb reverse)
Write-Host ""
Write-Host "2. Detection et liaison des appareils Android (USB)..." -ForegroundColor Yellow
try {
    $adbCheck = adb devices 2>$null
    if ($adbCheck -match "\bdevice\b") {
        adb reverse tcp:8000 tcp:8000 2>$null
        Write-Host "   [OK] Appareil Android connecte : Port 8000 relie en direct par USB (adb reverse) !" -ForegroundColor Green
    } else {
        Write-Host "   [INFO] Aucun appareil Android detecte via USB. Connexions Wi-Fi / Simulateur actives." -ForegroundColor Gray
    }
} catch {
    Write-Host "   [INFO] ADB non detecte dans le PATH." -ForegroundColor Gray
}

# 3. Lancement du serveur Django
Write-Host ""
Write-Host "3. Demarrage du serveur de developpement Django..." -ForegroundColor Yellow
Write-Host "   - API REST:   http://127.0.0.1:8000/api/v1/" -ForegroundColor Green
Write-Host "   - Swagger UI: http://127.0.0.1:8000/api/v1/docs/" -ForegroundColor Green
Write-Host "   - Admin:      http://127.0.0.1:8000/admin/" -ForegroundColor Green
Write-Host ""
Write-Host "Appuyez sur Ctrl+C pour arreter le serveur." -ForegroundColor DarkGray

Start-Process python -ArgumentList "manage.py runserver 0.0.0.0:8000" -WorkingDirectory $backendPath -NoNewWindow -Wait
