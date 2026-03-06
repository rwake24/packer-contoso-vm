# install-software.ps1 — Install all dependencies for ContosoUniversity dev environment
# Called by Packer provisioner after WinRM connection

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Installing Development Environment"
Write-Host "========================================" -ForegroundColor Cyan

# --- Install Chocolatey ---
Write-Host "`n[1/6] Installing Chocolatey..." -ForegroundColor Yellow
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
refreshenv

# --- Install Git ---
Write-Host "`n[2/6] Installing Git..." -ForegroundColor Yellow
choco install git -y --no-progress
refreshenv

# --- Install Visual Studio 2022 Community ---
Write-Host "`n[3/6] Installing Visual Studio 2022 Community..." -ForegroundColor Yellow
# Workloads: ASP.NET/web, .NET desktop, .NET Framework 4.8 targeting pack
choco install visualstudio2022community -y --no-progress --package-parameters "--add Microsoft.VisualStudio.Workload.NetWeb --add Microsoft.VisualStudio.Workload.ManagedDesktop --add Microsoft.Net.Component.4.8.SDK --add Microsoft.Net.Component.4.8.TargetingPack --add Microsoft.Net.ComponentGroup.DevelopmentPrerequisites --includeRecommended --passive --wait"

# --- Install .NET 8 SDK (for migration target) ---
Write-Host "`n[4/6] Installing .NET 8 SDK..." -ForegroundColor Yellow
choco install dotnet-8.0-sdk -y --no-progress

# --- Install SQL Server Developer Edition ---
Write-Host "`n[5/8] Installing SQL Server 2022 Developer Edition..." -ForegroundColor Yellow
choco install sql-server-2022 -y --no-progress --package-parameters="/INSTANCENAME=MSSQLSERVER /SECURITYMODE=SQL /SAPWD=DevP@ss2026! /TCPENABLED=1"

# --- Install SQL Server Management Studio ---
Write-Host "`n[6/8] Installing SSMS..." -ForegroundColor Yellow
choco install sql-server-management-studio -y --no-progress

# --- Install Azure Arc Agent ---
Write-Host "`n[7/8] Installing Azure Connected Machine Agent..." -ForegroundColor Yellow
# Downloads and installs the agent — you'll onboard it post-build with your subscription details
$arcMsi = "$env:TEMP\AzureConnectedMachineAgent.msi"
Invoke-WebRequest -Uri "https://aka.ms/AzureConnectedMachineAgent" -OutFile $arcMsi
Start-Process msiexec.exe -ArgumentList "/i $arcMsi /qn /norestart" -Wait
Remove-Item $arcMsi -Force
Write-Host "  Arc agent installed. Run 'azcmagent connect' post-build to onboard." -ForegroundColor Cyan

# --- Install useful extras ---
Write-Host "`n[8/8] Installing extras (VS Code, Azure CLI)..." -ForegroundColor Yellow
choco install vscode -y --no-progress
choco install azure-cli -y --no-progress

# --- Refresh environment ---
refreshenv

# --- Verify installs ---
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  Verifying installations..."
Write-Host "========================================" -ForegroundColor Green

$checks = @(
    @{ Name = "Git";       Cmd = "git --version" },
    @{ Name = ".NET 8 SDK"; Cmd = "dotnet --version" },
    @{ Name = "Azure CLI"; Cmd = "az --version" }
)

foreach ($check in $checks) {
    try {
        $result = Invoke-Expression $check.Cmd 2>&1 | Select-Object -First 1
        Write-Host "  ✓ $($check.Name): $result" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ $($check.Name): NOT FOUND" -ForegroundColor Red
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Environment ready!"
Write-Host "  VS 2022 + .NET 8 SDK + Git + LocalDB"
Write-Host "========================================" -ForegroundColor Cyan
