# setup.ps1 — First logon bootstrap (runs from floppy via autounattend.xml)
# Ensures WinRM is configured and basic tools are ready for Packer provisioning

Write-Host "=== Initial VM Setup ===" -ForegroundColor Cyan

# Ensure WinRM is running
Write-Host "Configuring WinRM..."
winrm quickconfig -force
Set-Item WSMan:\localhost\Service\AllowUnencrypted -Value True
Set-Item WSMan:\localhost\Service\Auth\Basic -Value True
Restart-Service WinRM

# Disable Windows Update during build (speeds things up)
Write-Host "Pausing Windows Update..."
Set-Service wuauserv -StartupType Disabled -ErrorAction SilentlyContinue
Stop-Service wuauserv -Force -ErrorAction SilentlyContinue

# Create project directory
Write-Host "Creating C:\Projects..."
New-Item -ItemType Directory -Path "C:\Projects" -Force | Out-Null

# Disable Server Manager popup (if Windows Server)
Get-ScheduledTask -TaskName ServerManager -ErrorAction SilentlyContinue | Disable-ScheduledTask -ErrorAction SilentlyContinue

Write-Host "=== Setup complete. Packer can now connect via WinRM. ===" -ForegroundColor Green
