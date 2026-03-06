# Packer - ContosoUniversity Dev VM

Automated VMware Workstation VM build for the [ContosoUniversity .NET migration sample](https://github.com/Azure-Samples/dotnet-migration-copilot-samples/tree/main/ContosoUniversity).

## What You Get

- Windows 10/11 VM (4 vCPU, 8 GB RAM, 60 GB disk)
- Visual Studio 2022 Community (ASP.NET + .NET Desktop workloads)
- .NET Framework 4.8.2 SDK + .NET 8 SDK (migration target)
- SQL Server LocalDB
- MSMQ enabled
- Git, VS Code, Azure CLI
- ContosoUniversity repo cloned to `C:\Projects\`

## Prerequisites

1. [Packer](https://developer.hashicorp.com/packer/install) installed
2. [VMware Workstation Pro](https://www.vmware.com/products/desktop-hypervisor/workstation-and-fusion) installed
3. A Windows 10 or 11 ISO file

## Usage

```bash
# Init plugins
packer init windows-vm.pkr.hcl

# Build (point to your Windows ISO)
packer build -var "iso_path=C:/ISOs/Win11_23H2_English_x64.iso" windows-vm.pkr.hcl
```

## Files

| File | Purpose |
|---|---|
| `windows-vm.pkr.hcl` | Packer template (VM specs, provisioners) |
| `autounattend.xml` | Unattended Windows install (skips all prompts) |
| `scripts/setup.ps1` | First-logon bootstrap (WinRM, directories) |
| `scripts/install-software.ps1` | Chocolatey + all dev tools |

## Customization

- **Change VM size:** Edit `cpus`, `memory`, `disk_size` in `windows-vm.pkr.hcl`
- **Change password:** Update the `password` variable (also in `autounattend.xml`)
- **Add more software:** Edit `scripts/install-software.ps1`
- **Windows Server instead:** Change `guest_os_type` to `windows2022srvnext-64`

## Build Time

Expect ~45-60 minutes (mostly Visual Studio install). Once built, snapshot it and clone as needed.
