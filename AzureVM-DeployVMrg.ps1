<#
	.How to Use: Update the variables and then run the script
	.Made By: Ghufran Khan
	.Written By: Ghufran Khan		
	.More Scripts by Me: https://github.com/ghkhan89?tab=repositories
	.Find me on Facebook: https://www.facebook.com/GhufranKhan89
#>

login-AzureRMAccount

Clear-Host

## VM Credentials
$username = "xsql"
$password = "P-assword@123"

## Add VM to Availability Set - 0(No) & 1(Yes)
$AVFlag = 0 
$AVName = "NAvSet"

## Resource Loaction
$Location = "southindia"
$ResourceGroupName = "TempShare"

## Storage
$StorageName = "tempsharedisks"

## Network
$VNetName = "TempShare-vnet"
$TCPIPAllocationMethod = "Dynamic"

## VM Info
$VMNames = "SQLRepro"
$VMSize = "Standard_DS3_v2"

## Image
$PublisherName = "MicrosoftSQLServer"
$OfferName = "SQL2017-WS2016"
$Sku = "SQLDEV"
$Version = "latest"

# Additional Disk on SQL VM
$DiskNum = 0
$DiskSizeGB = 1024

# License Type = 1 AHUB | 0 PayasGo
$AHUB = 1

If($AVFlag -eq 1)
{
	$AVSet = New-AzureRmAvailabilitySet -Name $AVName -Location $Location -ResourceGroupName $ResourceGroupName -Verbose
}

# Save Credential
$password = $password | ConvertTo-SecureString -AsPlainText -Force 
$Credential = New-Object System.Management.Automation.PSCredential -ArgumentList $username,$password

# Storage
$StorageAccount = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageName -Verbose

# Network
$VNet = Get-AzureRmVirtualNetwork -Name $VNetName -ResourceGroupName $ResourceGroupName -Verbose

foreach ($VMName in $VMNames)
{
# VM Interface Config
$PublicIp = New-AzureRmPublicIpAddress -Name "$VMName-PubIP" -ResourceGroupName $ResourceGroupName -Location $Location -AllocationMethod $TCPIPAllocationMethod -Verbose
$Interface = New-AzureRmNetworkInterface -Name "$VMName-In" -ResourceGroupName $ResourceGroupName -Location $Location -SubnetId $VNet.Subnets[0].Id -PublicIpAddressId $PublicIp.Id -Verbose

# VM Config
$OSDiskName = $VMName + "OSDisk"
If($AVFlag -eq 1)
{
	$VirtualMachine = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize -AvailabilitySetId $AVSet.Id -Verbose
}
else
{
	$VirtualMachine = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize -Verbose
}

$VirtualMachine = Set-AzureRmVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $VMName -Credential $Credential -ProvisionVMAgent -EnableAutoUpdate -Verbose
$VirtualMachine = Add-AzureRmVMNetworkInterface -VM $VirtualMachine -Id $Interface.Id -Verbose
$OSDiskUri = $StorageAccount.PrimaryEndpoints.Blob.ToString() + "vhds/" + $OSDiskName + ".vhd"
$VirtualMachine = Set-AzureRmVMOSDisk -VM $VirtualMachine -Name $OSDiskName -VhdUri $OSDiskUri -Caching ReadOnly -CreateOption FromImage -Verbose

if($DiskNum -gt 0)
{
	for($idsk = 1; $idsk -le $DiskNum; $idsk++)
	{
		$Disk = $VMName + "-Disk" + ($idsk)
		$DiskUri = $StorageAccount.PrimaryEndpoints.Blob.ToString() + "vhds/" + $Disk + ".vhd"
		$DiskLun = $idsk - 1
		$VirtualMachine = Add-AzureRmVMDataDisk -VM $VirtualMachine -Name $Disk -Caching ReadOnly -DiskSizeInGB $DiskSizeGB -Lun $DiskLun -VhdUri $DiskUri -CreateOption Empty
	}
}

# VM Image Config
$VirtualMachine = Set-AzureRmVMSourceImage -VM $VirtualMachine -PublisherName $PublisherName -Offer $OfferName -Skus $Sku -Version $Version -Verbose

## Disable VM Boot Diagnostics
$VirtualMachine = Set-AzureRmVMBootDiagnostics -VM $VirtualMachine -disable

## Create the VM in Azure
if($AHUB -eq 1)
{
	New-AzureRmVM -ResourceGroupName $ResourceGroupName -Location $Location -VM $VirtualMachine -DisableBginfoExtension -LicenseType "Windows_Server" -Verbose
}
else
{
	New-AzureRmVM -ResourceGroupName $ResourceGroupName -Location $Location -VM $VirtualMachine -DisableBginfoExtension -Verbose
}

}
