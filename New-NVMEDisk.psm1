<#
	.SYNOPSIS
		Adds a new NVME Disk to an existing NVME Controller
	
	.DESCRIPTION
		Adds a new NVME Disk to an existing NVME Controller
	
	.PARAMETER Name
		A description of the Name parameter.
	
	.PARAMETER DiskSizeInGB
		Size in GB of the new disk
	
	.PARAMETER EagerlyScrub
		Specified if the hard disk should get zeroed. 
		Default: $false
	
	.PARAMETER ThinProvisioned
		Specified if the the hard disk should get thin or thick provisioned (default) 
	
	.PARAMETER DiskMode
		Specifies the Diskmode 
	
	.PARAMETER VM
		The VM to add the new disk to.
	
	.EXAMPLE
		PS C:\> New-NVMEDisk -VM 'si40v001' -DiskSizeInGB 20
	
	.NOTES
		Based on the work of @ThepHuck
		https://github.com/ThepHuck/ThepHuck/blob/master/New-NVMeDisk/New-NVMeDisk.ps1
#>
function New-NVMEDisk
{
	[CmdletBinding()]
	[OutputType([VMware.VimAutomation.ViCore.Types.V1.VirtualDevice.HardDisk])]
	param
	(
		[Parameter(Mandatory = $true,
				   ValueFromPipelineByPropertyName = $true)]
		[string]$Name,
		[Parameter(Mandatory = $true)]
		[int]$DiskSizeInGB,
		[bool]$EagerlyScrub = $false,
		[bool]$ThinProvisioned = $false,
		[ValidateSet('persistent', 'IndependentNonPersistent')]
		[string]$DiskMode = 'persistent'
	)
	
	process
	{
		if (!$global:DefaultVIServers)
		{
			throw "You are not connected to any VIServer. Use 'Connect-VIServer' to connect. "
			exit;
		}
		
		try
		{
			$node = get-vm $Name
		}
		catch
		{
			throw "Cannot find the vm $($Name)"
			exit
		}
		$vmView = $node | Get-View
		if (($vmView.config.hardware.device | ? { $_.deviceinfo.Label -match "NVME" }).count -eq 0)
		{
			throw "No NVMe controller present!"
			exit
		}
		
		#Get the NVMe controller's key
		$controllerKey = ($vmView.config.hardware.Device | where-object { $_.DeviceInfo.Label -like "*NVME*" }).Key
		
		Write-Verbose "Found NVME Controller $($controllerKey)"
		
		$usedUnits = @()
		foreach ($dev in $vmView.Config.Hardware.Device)
		{
			if ($dev -is [VMware.Vim.VirtualDisk] -and $dev.ControllerKey -eq $controllerKey)
			{
				$usedUnits += $dev.UnitNumber
			}
		}
		
		
		$freeUnit = (0 .. 15 | Where-Object { $_ -notin $usedUnits } | Select-Object -First 1)
		if ($null -eq $freeUnit)
		{
			throw "No free number for NVMe-Controller Key=$($controllerKey) available."
		}
		
		
		$DiskID = $freeUnit
		$DiskSizeKB = $DiskSizeInGB * 1024 * 1024
		$DiskSizeB = $DiskSizeKB * 1024
		Write-Verbose -Message "Adding NVMe disk $($DiskID) to controller $($controllerKey)"
		Write-Verbose -Message "Task properties: `r`n
								DiskSizeInKB: $($DiskSizeKB)
								DiskSizeInB: $($DiskSizeB)
								EagerlyScrub: $($DiskSizeB)
								ThinProvisioned: $($DiskSizeB)
								DiskMode: $($DiskMode)
								ControllerKey: $($controllerKey)
								DiskID: $($DiskID)"
		$diskTask = $null
		$vDiskSpec = $null
		$vDiskSpec = New-Object VMware.Vim.VirtualMachineConfigSpec
		$vDiskSpec.DeviceChange = New-Object VMware.Vim.VirtualDeviceConfigSpec[] (1)
		$vDiskSpec.DeviceChange[0] = New-Object VMware.Vim.VirtualDeviceConfigSpec
		$vDiskSpec.DeviceChange[0].FileOperation = 'create'
		$vDiskSpec.DeviceChange[0].Device = New-Object VMware.Vim.VirtualDisk
		$vDiskSpec.DeviceChange[0].Device.CapacityInBytes = $DiskSizeB
		$vDiskSpec.DeviceChange[0].Device.Backing = New-Object VMware.Vim.VirtualDiskFlatVer2BackingInfo
		$vDiskSpec.DeviceChange[0].Device.Backing.FileName = ''
		$vDiskSpec.DeviceChange[0].Device.Backing.EagerlyScrub = $EagerlyScrub
		$vDiskSpec.DeviceChange[0].Device.Backing.ThinProvisioned = $ThinProvisioned
		$vDiskSpec.DeviceChange[0].Device.Backing.DiskMode = $DiskMode
		$vDiskSpec.DeviceChange[0].Device.ControllerKey = $controllerKey
		$vDiskSpec.DeviceChange[0].Device.UnitNumber = $DiskID
		$vDiskSpec.DeviceChange[0].Device.CapacityInKB = $DiskSizeKB
		$vDiskSpec.DeviceChange[0].Operation = 'add'
		$diskTask = $vmView.ReconfigVM_Task($vDiskSpec)
		sleep 1
		$task = (Get-Task -Id $diskTask)
		$result = Wait-Task -Task $task
		
		if ((Get-Task -Id $diskTask).State -notmatch "Success")
		{
			write-error -Message "Check the host client UI, task was not successful"
		}
		else
		{
			write-information -MessageData "Disk added successfully!"
		}
		$disks = Get-HardDisk -VM $node
		return $disks[-1]
	}
}
Export-ModuleMember -Function New-NVMEDisk



