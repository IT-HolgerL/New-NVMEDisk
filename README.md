# New-NVMEDisk
Powershell-Module to add an exisitng Vmware vm

# Description

The PowerShell module New-NVMEDisk adds a new NVMe disk to an existing VMware VM.

The disk is attached to an already existing NVMe controller of the VM.

The module supports Thin and Thick Provisioning as well as optional Eager Zeroing.

# Installation (Windows)
## Requirements

The module requires PowerCLI.

It can be installed using the following command:

Install-Module -Name VCF.PowerCLI
Installation for the Current User (No Admin Rights Required)

Copy the entire Modules folder to the following path:

C:\Users\<username>\Documents\WindowsPowerShell\Modules
##System-Wide Installation

Copy the entire Modules folder to the following path:

C:\Windows\System32\WindowsPowerShell\v1.0\Modules
Availability Check

Open PowerShell and run the following commands:

Import-Module New-NVMEDisk
Get-Command -Module New-NVMEDisk

Expected output:

CommandType Name Version Source

---

Function New-NVMEDisk 1.0 New-NVMEDisk
Example Usage

Open PowerShell:

Import-Module New-NVMEDisk
New-NVMEDisk -VM 'vmname' -DiskSizeInGB 20

