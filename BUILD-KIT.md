# ContosoUniversity Dev VM — Build Kit

## Overview
Automated Windows 11 VM build for the ContosoUniversity .NET migration sample + Azure Arc demo environment.

**Repo:** https://github.com/rwake24/packer-contoso-vm
**VM Specs:** 4 vCPU, 8 GB RAM, 60 GB disk (thin), Win11 Enterprise 26H1, EFI/NVMe

---

## Phase 1: Packer — Build the VM

```powershell
cd C:\Users\rowake\packer-contoso-vm
git pull
packer build windows-vm.pkr.hcl
```

Packer creates the VM in VMware Workstation, mounts the ISO, and installs Windows 11 unattended. Wait for the desktop to appear (~15 min).

---

## Phase 2: Windows Update

Once at the desktop, open **Settings → Windows Update** and install all updates. Restart as needed. Repeat until "You're up to date."

---

## Phase 3: Install Dev Tools

Open **Command Prompt as Administrator** and run each block in order.

### 3a. Install Chocolatey
```cmd
@"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -InputFormat None -ExecutionPolicy Bypass -Command "[System.Net.ServicePointManager]::SecurityProtocol = 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))" && SET "PATH=%PATH%;%ALLUSERSPROFILE%\chocolatey\bin"
```

Close and reopen Command Prompt as Admin after this.

### 3b. Install Git
```cmd
choco install git -y
```

### 3c. Install Visual Studio 2022 Community
```cmd
choco install visualstudio2022community -y --package-parameters "--add Microsoft.VisualStudio.Workload.NetWeb --add Microsoft.VisualStudio.Workload.ManagedDesktop --add Microsoft.Net.Component.4.8.SDK --add Microsoft.Net.Component.4.8.TargetingPack --includeRecommended --passive --wait"
```
⏱️ This takes 20-30 minutes.

### 3d. Install .NET 8 SDK
```cmd
choco install dotnet-8.0-sdk -y
```

### 3e. Install SQL Server 2022 Developer Edition
```cmd
choco install sql-server-2022 -y --package-parameters="/INSTANCENAME=MSSQLSERVER /SECURITYMODE=SQL /SAPWD=DevP@ss2026! /TCPENABLED=1"
```

### 3f. Install SSMS
```cmd
choco install sql-server-management-studio -y
```

### 3g. Install VS Code
```cmd
choco install vscode -y
```

### 3h. Install Azure CLI
```cmd
choco install azure-cli -y
```

### 3i. Install Azure Connected Machine Agent (Arc)
```powershell
powershell -Command "Invoke-WebRequest -Uri 'https://aka.ms/AzureConnectedMachineAgent' -OutFile '$env:TEMP\AzureConnectedMachineAgent.msi'; Start-Process msiexec.exe -ArgumentList '/i $env:TEMP\AzureConnectedMachineAgent.msi /qn /norestart' -Wait"
```

### 3j. Enable MSMQ
```powershell
powershell -Command "Enable-WindowsOptionalFeature -Online -FeatureName MSMQ-Server -All -NoRestart"
```

---

## Phase 4: GitHub Copilot

1. Open VS Code
2. Install extension: `GitHub.copilot`
3. Sign in with GitHub account
4. Also install in Visual Studio 2022: **Extensions → Manage Extensions → Search "GitHub Copilot" → Install**

---

## Phase 5: Clone the Project

```cmd
mkdir C:\Projects
cd C:\Projects
git clone https://github.com/Azure-Samples/dotnet-migration-copilot-samples.git
```

Project location: `C:\Projects\dotnet-migration-copilot-samples\ContosoUniversity`

---

## Phase 6: Onboard Azure Arc

```powershell
azcmagent connect --resource-group "your-rg" --tenant-id "your-tenant" --location "centralus" --subscription-id "your-sub"
```

---

## Phase 7: Snapshot! 📸

In VMware Workstation: **VM → Snapshot → Take Snapshot** — name it "Clean Build" so you can always roll back.

---

## Credentials
| Item | Value |
|------|-------|
| Windows User | `developer` |
| Windows Password | `P@ssw0rd123!` |
| SQL Server SA | `DevP@ss2026!` |
| Computer Name | `CONTOSO-DEV` |

---

## What's Installed
- Windows 11 Enterprise 26H1
- Visual Studio 2022 Community (ASP.NET + .NET Desktop)
- .NET Framework 4.8.2 SDK + .NET 8 SDK
- SQL Server 2022 Developer + SSMS
- Git, VS Code, Azure CLI
- Azure Connected Machine Agent (Arc)
- MSMQ
- GitHub Copilot (VS Code + VS 2022)
- ContosoUniversity sample repo
