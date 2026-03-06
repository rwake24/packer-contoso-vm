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
  description = "Path to Windows 11 ISO file"
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
  guest_os_type    = "windows9-64"
  headless         = false

  # Hardware
  cpus             = 4
  memory           = 8192
  disk_size        = 61440
  disk_type_id     = "0"

  # EFI + NVMe for Win11
  firmware          = "efi"
  disk_adapter_type = "nvme"

  # ISO
  iso_url          = var.iso_path
  iso_checksum     = var.iso_checksum

  # Floppy with autounattend.xml
  floppy_files = [
    "autounattend.xml",
    "scripts/setup.ps1",
    "scripts/install-software.ps1"
  ]

  # WinRM
  communicator     = "winrm"
  winrm_username   = var.username
  winrm_password   = var.password
  winrm_timeout    = "90m"
  winrm_use_ssl    = false

  # Network
  network              = "bridged"
  network_adapter_type = "e1000e"

  # Boot — catch first "Press any key to boot from CD/DVD"
  # Second reboot will timeout and boot from NVMe automatically
  boot_wait    = "3s"
  boot_command = ["<spacebar>"]

  # Shutdown
  shutdown_command  = "shutdown /s /t 30 /f"
  shutdown_timeout  = "10m"
}

build {
  sources = ["source.vmware-iso.windows"]

  provisioner "powershell" {
    inline = ["Write-Host 'Connected to VM via WinRM'"]
  }

  provisioner "powershell" {
    inline = [
      "Write-Host 'Enabling MSMQ...'",
      "Enable-WindowsOptionalFeature -Online -FeatureName MSMQ-Server -All -NoRestart",
      "Write-Host 'MSMQ enabled.'"
    ]
  }

  provisioner "powershell" {
    script = "scripts/install-software.ps1"
  }

  provisioner "powershell" {
    inline = [
      "Write-Host 'Cloning ContosoUniversity repo...'",
      "cd C:\\Projects",
      "git clone https://github.com/Azure-Samples/dotnet-migration-copilot-samples.git",
      "Write-Host 'Done. Project at C:\\Projects\\dotnet-migration-copilot-samples\\ContosoUniversity'"
    ]
  }

  provisioner "powershell" {
    inline = [
      "Write-Host 'Cleaning up...'",
      "Cleanmgr /sagerun:1",
      "Write-Host 'Build complete! VM ready for .NET migration work.'"
    ]
  }
}
