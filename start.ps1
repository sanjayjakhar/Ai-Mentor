# ============================================================
#  AI-Mentor - One-click startup script
#  Usage: Right-click -> Run with PowerShell
# ============================================================

$ROOT = "C:\Users\BIT\Desktop\Skills\Ai-Mentor"

# ---- Helpers ------------------------------------------------
function Write-Step($msg) { Write-Host "`n$msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Wait($msg) { Write-Host "  [..] $msg" -ForegroundColor Yellow }

# ---- Step 1: Kill existing services ------------------------
Write-Step "Step 1/4 - Stopping any running services..."
Get-Process -Name "node"    -ErrorAction SilentlyContinue | Stop-Process -Force
Get-Process -Name "uvicorn" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 1
Write-Ok "All cleared"

# ---- Step 2: Start backends --------------------------------
Write-Step "Step 2/4 - Starting backends..."
Start-Process powershell -ArgumentList "-NoExit", "-Command", "Set-Location '$ROOT\backend'; npm run dev" -WindowStyle Normal
Start-Process powershell -ArgumentList "-NoExit", "-Command", "Set-Location '$ROOT\backendAdmin'; npm run dev" -WindowStyle Normal
Write-Ok "User Backend  (5000) - launched"
Write-Ok "Admin Backend (5001) - launched"

# ---- Step 3: Wait for both backends to be healthy ----------
Write-Step "Step 3/4 - Waiting for backends (Neon DB sync takes ~30-60s)..."

$ports = @(5000, 5001)
$ready = @{}

while ($ready.Count -lt 2) {
    foreach ($port in $ports) {
        if (-not $ready.ContainsKey($port)) {
            try {
                Invoke-WebRequest -Uri "http://localhost:$port" -TimeoutSec 2 -UseBasicParsing -ErrorAction Stop | Out-Null
                # 2xx response — server is up
                $ready[$port] = $true
                Write-Ok "Backend port $port is UP"
            } catch [System.Net.WebException] {
                if ($_.Exception.Response -ne $null) {
                    # Got a response (e.g. 404) — server IS up, just no root route
                    $ready[$port] = $true
                    Write-Ok "Backend port $port is UP"
                } else {
                    # Connection refused — server not ready yet
                    Write-Wait "Port $port not ready yet..."
                }
            } catch {
                Write-Wait "Port $port not ready yet..."
            }
        }
    }
    if ($ready.Count -lt 2) { Start-Sleep -Seconds 2 }
}

Write-Ok "Both backends are healthy!"

# ---- Step 4: Start frontends + AI service ------------------
Write-Step "Step 4/4 - Starting frontends and AI service..."
Start-Process powershell -ArgumentList "-NoExit", "-Command", "Set-Location '$ROOT\frontend'; npm run dev" -WindowStyle Normal
Start-Process powershell -ArgumentList "-NoExit", "-Command", "Set-Location '$ROOT\frontendAdmin'; npm run dev" -WindowStyle Normal
Start-Process powershell -ArgumentList "-NoExit", "-Command", "Set-Location '$ROOT\ai_service\backend'; uvicorn api:app --reload --port 8000" -WindowStyle Normal
Write-Ok "User Frontend  (5173) - launched"
Write-Ok "Admin Frontend (5174) - launched"
Write-Ok "AI Service     (8000) - launched"

# ---- Wait for Vite to compile, then open browser -----------
Write-Wait "Waiting for frontend to compile..."
Start-Sleep -Seconds 4

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  All services are up!" -ForegroundColor Green
Write-Host "  App   -> http://localhost:5173"           -ForegroundColor Green
Write-Host "  Admin -> http://localhost:5174"           -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green

Start-Process "http://localhost:5173"
