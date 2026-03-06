packer {
  required_plugins {
    vmware = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/vmware"
    }
  }
}

variable "iso_path" {
  type        = string
  default     = "C:/Users/rowake/Downloads/en-us_windows_11_business_editions_version_26h1_x64_dvd_18ddd107.iso"
  description = "Path to Windows 10/11 ISO file"
}

variable "iso_checksum" {
  type        = string
  default     = "none"
  description = "ISO checksum (set to 'none' to skip verification)"
}

variable "vm_name" {
  type    = string
  default = "ContosoUniversity-Dev"
}

variable "username" {
  type    = string
  default = "developer"
}

variable "password" {
  type    = string
  default = "P@ssw0rd123!"
  sensitive = true
}

source "vmware-iso" "windows" {
  vm_name          = var.vm_name
  guest_os_type    = "windows9-64"    # Windows 10/11 x64
  headless         = false

  # Hardware
  cpus             = 4
  memory           = 8192
  disk_size        = 61440            # 60 GB
  disk_type_id     = "0"              # Growable virtual disk

  # UEFI firmware (required for Win11)
  firmware         = "efi"
  disk_adapter_type = "nvme"

  # ISO
  iso_url          = var.iso_path
  iso_checksum     = var.iso_checksum

  # Floppy with autounattend.xml for unattended install
  floppy_files = [
    "autounattend.xml",
    "scripts/setup.ps1",
    "scripts/install-software.ps1"
  ]

  # WinRM connection (Packer communicates over WinRM after OS install)
  communicator     = "winrm"
  winrm_username   = var.username
  winrm_password   = var.password
  winrm_timeout    = "60m"
  winrm_use_ssl    = false

  # Network — Bridged so it gets a LAN IP and can use host VPN
  network           = "bridged"
  network_adapter_type = "e1000e"

  # Shutdown
  shutdown_command  = "shutdown /s /t 30 /f"
  shutdown_timeout  = "10m"

  # Boot command — select SATA CDROM (2nd entry after "Boot normally")
  boot_wait    = "5s"
  boot_command = ["<down><down><enter>"]

  # VMware settings
  vmx_data = {
    "firmware" = "efi"
  }
}

build {
  sources = ["source.vmware-iso.windows"]

  # Wait for WinRM to become available
  provisioner "powershell" {
    inline = ["Write-Host 'Connected to VM via WinRM'"]
  }

  # Enable MSMQ
  provisioner "powershell" {
    inline = [
      "Write-Host 'Enabling MSMQ...'",
      "Enable-WindowsOptionalFeature -Online -FeatureName MSMQ-Server -All -NoRestart",
      "Write-Host 'MSMQ enabled.'"
    ]
  }

  # Run software installation script
  provisioner "powershell" {
    script = "scripts/install-software.ps1"
  }

  # Clone repo and restore packages
  provisioner "powershell" {
    inline = [
      "Write-Host 'Cloning ContosoUniversity repo...'",
      "cd C:\\Projects",
      "git clone https://github.com/Azure-Samples/dotnet-migration-copilot-samples.git",
      "Write-Host 'Done. Project at C:\\Projects\\dotnet-migration-copilot-samples\\ContosoUniversity'"
    ]
  }

  # Take a snapshot-ready clean state
  provisioner "powershell" {
    inline = [
      "Write-Host 'Cleaning up...'",
      "Cleanmgr /sagerun:1",
      "Write-Host 'Build complete! VM ready for .NET migration work.'"
    ]
  }
}
