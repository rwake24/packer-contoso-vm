# ContosoUniversity Dev VM — Build Kit

## Overview
Windows 11 VM for the ContosoUniversity .NET Framework → .NET 8 migration demo + Azure Arc.

**Repo:** https://github.com/rwake24/packer-contoso-vm
**VM Specs:** 4 vCPU, 8 GB RAM, 60 GB disk (thin), Win11 Enterprise 26H1, EFI/NVMe, Bridged network

---

## ⚠️ Known Constraint: aka.ms Blocked

`aka.ms` (IP `6.6.0.43`) is unreachable on port 443 from CLI tools (PowerShell, WinHTTP). Browser can reach it but VS Installer engine and CLI tools cannot. This blocks:
- Visual Studio 2022 (all editions)
- Visual Studio Build Tools 2022
- SSMS 22 (uses VS Installer engine)

**Workaround:** Use `dotnet msbuild` from .NET SDK 8.0 instead of Visual Studio. Use SSMS 20.2.1 (standalone installer).

---

## Phase 1: Create the VM

### Option A: Packer (automated Windows install)
```powershell
cd C:\Users\rowake\packer-contoso-vm
git pull
packer build windows-vm.pkr.hcl
```
Packer creates the VM and installs Windows unattended (~15 min). Note: `communicator = "none"` so Packer exits immediately after boot — watch for the desktop before proceeding.

### Option B: Manual (recommended)
1. VMware Workstation → File → New Virtual Machine → Custom
2. ISO: `C:\Users\rowake\Downloads\en-us_windows_11_business_editions_version_26h1_x64_dvd_18ddd107.iso`
3. Guest OS: Windows 11 x64, EFI firmware
4. 4 CPUs, 8192 MB RAM, NVMe 60 GB thin
5. Network: Bridged
6. Install → pick **Windows 11 Enterprise**

---

## Phase 2: Windows Update

Settings → Windows Update → install all. Restart until "You're up to date."

---

## Phase 3: Install Software

Open **Command Prompt as Administrator** (PowerShell 5.1 may crash on fresh Win11 26H1).

### 3a. Chocolatey
```cmd
@"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -InputFormat None -ExecutionPolicy Bypass -Command "[System.Net.ServicePointManager]::SecurityProtocol = 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))" && SET "PATH=%PATH%;%ALLUSERSPROFILE%\chocolatey\bin"
```
Close and reopen Command Prompt as Admin.

### 3b. Core Tools (Chocolatey)
```cmd
choco install git -y
choco install dotnet-8.0-sdk -y
choco install netfx-4.8-devpack -y
choco install netfx-4.8.1-devpack -y
choco install vscode -y
choco install azure-cli -y
```

### 3c. SQL Server 2022 Developer
If blocked by "pending reboot," clear the registry key first:
```powershell
Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name "PendingFileRenameOperations" -Force
```
Then:
```cmd
choco install sql-server-2022 -y --package-parameters="/INSTANCENAME=MSSQLSERVER /SECURITYMODE=SQL /SAPWD=DevP@ss2026! /TCPENABLED=1"
```

### 3d. SSMS 20.2.1 (via winget — NOT SSMS 22)
```cmd
winget install Microsoft.SQLServerManagementStudio --version 20.2.1 --source winget
```
> SSMS 22 uses VS Installer engine (aka.ms blocker). SSMS 20.2.1 uses standalone installer.

### 3e. Node.js & Python (via winget)
```cmd
winget install OpenJS.NodeJS.LTS --source winget
winget install Python.Python.3.12 --source winget
```
> Use `--source winget` — Microsoft Store source has TLS errors.

### 3f. NuGet CLI (direct download)
```powershell
Invoke-WebRequest -Uri "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe" -OutFile "C:\ProgramData\chocolatey\bin\nuget.exe"
```

### 3g. Azure Connected Machine Agent (Arc)
```powershell
# aka.ms URL is blocked — use direct download
$script = Invoke-WebRequest -Uri "https://gbl.his.arc.azure.com/azcmagent-windows" -UseBasicParsing
# Extract MSI URL from script, or download directly:
Invoke-WebRequest -Uri "https://gbl.his.arc.azure.com/azcmagent/latest/AzureConnectedMachineAgent.msi" -OutFile "$env:TEMP\AzureConnectedMachineAgent.msi"
Start-Process msiexec.exe -ArgumentList "/i $env:TEMP\AzureConnectedMachineAgent.msi /qn /norestart" -Wait
```

### 3h. Enable IIS with ASP.NET 4.8
```powershell
Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole,IIS-WebServer,IIS-CommonHttpFeatures,IIS-DefaultDocument,IIS-StaticContent,IIS-HttpErrors,IIS-ApplicationDevelopment,IIS-NetFxExtensibility45,IIS-ASPNET45,IIS-ISAPIExtensions,IIS-ISAPIFilter,IIS-WebServerManagementTools,IIS-ManagementConsole,IIS-RequestFiltering,IIS-HttpLogging -All -NoRestart
```

### 3i. Enable MSMQ
```powershell
Enable-WindowsOptionalFeature -Online -FeatureName MSMQ-Server -All -NoRestart
```

---

## Phase 4: GitHub Copilot

1. Open VS Code
2. Install extension: `GitHub.copilot`
3. Sign in with GitHub account

> Visual Studio 2022 cannot be installed (aka.ms blocker).

---

## Phase 5: Clone & Build ContosoUniversity

### Clone
```powershell
cd C:\Users\ContosoUniversity-De
git clone https://github.com/Azure-Samples/dotnet-migration-copilot-samples.git
cd dotnet-migration-copilot-samples\ContosoUniversity
```

### Restore NuGet packages
```powershell
nuget restore ContosoUniversity.sln
nuget install MSBuild.Microsoft.VisualStudio.Web.targets -Version 14.0.0.3 -OutputDirectory packages
```

### Build (using dotnet msbuild — NOT MSBuild 4.x)
```powershell
$vsToolsPath = "C:\Users\ContosoUniversity-De\dotnet-migration-copilot-samples\ContosoUniversity\packages\MSBuild.Microsoft.VisualStudio.Web.targets.14.0.0.3\tools\VSToolsPath"
dotnet msbuild ContosoUniversity.csproj /p:Configuration=Debug "/p:VSToolsPath=$vsToolsPath" /verbosity:minimal
```

> **Why dotnet msbuild?** MSBuild 4.x (built into Windows) only supports C# 5 and can't resolve NuGet PackageReference chains. `dotnet msbuild` from .NET SDK 8.0 includes MSBuild 17.x with proper NuGet resolution and Roslyn compiler.

### Copy runtime DLLs to bin
```powershell
Copy-Item "packages\Microsoft.Bcl.HashCode.1.1.1\lib\net461\Microsoft.Bcl.HashCode.dll" bin\ -Force
Copy-Item "packages\System.Buffers.4.5.1\lib\net461\System.Buffers.dll" bin\ -Force
Copy-Item "packages\System.Memory.4.5.4\lib\net461\System.Memory.dll" bin\ -Force
Copy-Item "packages\System.Numerics.Vectors.4.5.0\lib\net46\System.Numerics.Vectors.dll" bin\ -Force
Copy-Item "packages\System.Runtime.CompilerServices.Unsafe.4.5.3\lib\net461\System.Runtime.CompilerServices.Unsafe.dll" bin\ -Force
Copy-Item "packages\Microsoft.CodeDom.Providers.DotNetCompilerPlatform.2.0.1\tools\RoslynLatest" bin\roslyn -Recurse
```

### Fix Web.config binding redirect
Change `System.Runtime.CompilerServices.Unsafe` redirect:
```xml
<!-- Change newVersion from 4.0.6.0 to 4.0.4.1 -->
<bindingRedirect oldVersion="0.0.0.0-4.0.6.0" newVersion="4.0.4.1" />
```

### Update connection string in Web.config
```xml
<add name="DefaultConnection" connectionString="Data Source=localhost;Initial Catalog=ContosoUniversityNoAuthEFCore;User ID=sa;Password=DevP@ss2026!;MultipleActiveResultSets=True;TrustServerCertificate=True" />
```

### Configure IIS site
```powershell
Import-Module WebAdministration
New-WebAppPool -Name "ContosoUniversity"
New-Website -Name "ContosoUniversity" -PhysicalPath "C:\Users\ContosoUniversity-De\dotnet-migration-copilot-samples\ContosoUniversity" -ApplicationPool "ContosoUniversity" -Port 8080 -Force
& "$env:windir\system32\inetsrv\appcmd.exe" set apppool "ContosoUniversity" /managedRuntimeVersion:v4.0 /managedPipelineMode:Integrated

# Grant IIS permissions (including parent user directory!)
icacls "C:\Users\ContosoUniversity-De" /grant "IIS_IUSRS:(OI)(CI)RX" /Q
icacls "C:\Users\ContosoUniversity-De" /grant "IUSR:(OI)(CI)RX" /Q
icacls "C:\Users\ContosoUniversity-De" /grant "IIS APPPOOL\ContosoUniversity:(OI)(CI)RX" /Q
icacls "C:\Users\ContosoUniversity-De\dotnet-migration-copilot-samples\ContosoUniversity" /grant "IIS_IUSRS:(OI)(CI)RX" /Q
icacls "C:\Users\ContosoUniversity-De\dotnet-migration-copilot-samples\ContosoUniversity" /grant "IIS APPPOOL\ContosoUniversity:(OI)(CI)RX" /T /Q
```

### Verify
| URL | Expected |
|-----|----------|
| `http://localhost:8080/` | Home Page |
| `http://localhost:8080/Students` | Students list |
| `http://localhost:8080/Courses` | Courses list |
| `http://localhost:8080/Instructors` | Instructors list |
| `http://localhost:8080/Departments` | Departments list |

---

## Phase 6: Azure Arc Onboard

```powershell
azcmagent connect --resource-group "your-rg" --tenant-id "your-tenant" --location "centralus" --subscription-id "your-sub"
```

---

## Phase 7: Snapshot! 📸

VM → Snapshot → Take Snapshot → Name: **"Clean Build — Pre-Arc"**
After Arc onboard, take another: **"Clean Build — Arc Connected"**

---

## Credentials

| Item | Value |
|------|-------|
| Windows User | `developer` (or `ContosoUniversity-De`) |
| Windows Password | `P@ssw0rd123!` |
| SQL Server SA | `DevP@ss2026!` |
| IIS Site | `http://localhost:8080/` |
| SSMS | `C:\Program Files (x86)\Microsoft SQL Server Management Studio 20\Common7\IDE\Ssms.exe` |

---

## Installed Software Summary

| Software | Version | Install Method |
|----------|---------|---------------|
| Windows 11 Enterprise | 26H1 | ISO |
| Git | 2.53.0 | Pre-installed |
| .NET SDK | 8.0.418 | Pre-installed |
| .NET Framework 4.8 Dev Pack | — | Chocolatey |
| .NET Framework 4.8.1 Dev Pack | — | Chocolatey |
| SQL Server 2022 Developer | 16.0.1000.6 | Chocolatey |
| SSMS | 20.2.1 | Winget |
| VS Code | — | Chocolatey |
| Azure CLI | — | Chocolatey |
| Node.js LTS | v24.14.0 | Winget |
| Python | 3.12.10 | Winget |
| NuGet CLI | 7.3.0 | Direct download |
| Azure Arc Agent | v1.61 | Direct MSI |
| IIS + ASP.NET 4.8 | — | Windows Feature |
| MSMQ | — | Windows Feature |
| GitHub Copilot | — | VS Code extension |

---

## Rebuild After Changes

```powershell
cd C:\Users\ContosoUniversity-De\dotnet-migration-copilot-samples\ContosoUniversity
$vsToolsPath = "C:\Users\ContosoUniversity-De\dotnet-migration-copilot-samples\ContosoUniversity\packages\MSBuild.Microsoft.VisualStudio.Web.targets.14.0.0.3\tools\VSToolsPath"
dotnet msbuild ContosoUniversity.csproj /p:Configuration=Debug "/p:VSToolsPath=$vsToolsPath" /verbosity:minimal
Copy-Item "packages\Microsoft.CodeDom.Providers.DotNetCompilerPlatform.2.0.1\tools\RoslynLatest" bin\roslyn -Recurse -Force
```
