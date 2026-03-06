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

  # No WinRM — provision manually after Windows installs
  communicator = "none"

  # Network
  network              = "bridged"
  network_adapter_type = "e1000e"

  # Boot — catch "Press any key to boot from CD/DVD"
  boot_wait    = "3s"
  boot_command = ["<spacebar>"]

  # Keep VM running after build
  shutdown_timeout = "60m"
}

build {
  sources = ["source.vmware-iso.windows"]
}
