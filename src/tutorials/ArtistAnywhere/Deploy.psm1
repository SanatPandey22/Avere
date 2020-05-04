﻿function New-TraceMessage ($moduleName, $moduleEnd, $regionName) {
	$traceMessage = [System.DateTime]::Now.ToLongTimeString()
	if ($regionName) {
		$traceMessage += " @ " + $regionName
	}
	$traceMessage += " ($moduleName "
	if ($moduleName.Substring(0, 1) -ne "*") {
		$traceMessage += "Deployment "
	}
	if ($moduleEnd) {
		$traceMessage += "End)"
	} else {
		$traceMessage += "Start)"
	}
	Write-Host $traceMessage
}

function New-NetworkPeering ([string[]] $computeRegionNames, [object[]] $computeNetworks, $storageNetwork, $moduleName) {
	$moduleName += " Network Peering"
	New-TraceMessage $moduleName $false
	$storageNetwork = (az network vnet show --resource-group $storageNetwork.resourceGroupName --name $storageNetwork.name)  | ConvertFrom-Json
	foreach ($storageNetworkPeering in $storageNetwork.virtualNetworkPeerings) {
		if ($storageNetworkPeering.peeringState -eq "Disconnected") {
			az network vnet peering delete --resource-group $storageNetwork.resourceGroup --vnet-name $storageNetwork.name --name $storageNetworkPeering.name
		}
	}
	for ($computeNetworkIndex = 0; $computeNetworkIndex -lt $computeNetworks.length; $computeNetworkIndex++) {
		New-TraceMessage $moduleName $false $computeRegionNames[$computeNetworkIndex]
		$computeNetworkResourceGroupName = $computeNetworks[$computeNetworkIndex].resourceGroupName
		$computeNetworkName = $computeNetworks[$computeNetworkIndex].name
		$computeNetwork = (az network vnet show --resource-group $computeNetworkResourceGroupName --name $computeNetworkName)  | ConvertFrom-Json
		$networkPeering = az network vnet peering create --resource-group $computeNetworkResourceGroupName --vnet-name $computeNetwork.name --name $storageNetwork.name --remote-vnet $storageNetwork.id --allow-vnet-access
		if (!$networkPeering) { return }
		$networkPeering = az network vnet peering create --resource-group $storageNetwork.resourceGroup --vnet-name $storageNetwork.name --name $computeNetwork.name --remote-vnet $computeNetwork.id --allow-vnet-access
		if (!$networkPeering) { return }
		New-TraceMessage $moduleName $true $computeRegionNames[$computeNetworkIndex]
	}
	New-TraceMessage $moduleName $true
	return $networkPeering
}

function New-SharedServices ($resourceGroupNamePrefix, $templateDirectory, $networkOnly, $computeRegionNames, $computeNetworks) {
	if (!$networkOnly) {
		# * - Image Gallery Job
		$moduleName = "* - Image Gallery Job"
		New-TraceMessage $moduleName $false
		$imageGalleryJob = Start-Job -FilePath "$templateDirectory/Deploy.ImageGallery.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionNames
	}

	if (!$computeNetworks -or $computeNetworks.length -eq 0) {
		# 00 - Network
		$computeNetworks = @()
		$moduleName = "00 - Network"
		New-TraceMessage $moduleName $false
		for ($computeRegionIndex = 0; $computeRegionIndex -lt $computeRegionNames.length; $computeRegionIndex++) {
			$computeRegionName = $computeRegionNames[$computeRegionIndex]
			New-TraceMessage $moduleName $false $computeRegionName
			$resourceGroupName = Get-ResourceGroupName $computeRegionIndex $resourceGroupNamePrefix "Network"
			$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionName
			if (!$resourceGroup) { return }

			$templateResources = "$templateDirectory/00-Network.json"
			$templateParameters = "$templateDirectory/00-Network.Parameters.$computeRegionName.json"
			$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateResources --parameters $templateParameters) | ConvertFrom-Json
			if (!$groupDeployment) { return }

			$computeNetwork = $groupDeployment.properties.outputs.virtualNetwork.value
			$computeNetwork | Add-Member -MemberType NoteProperty -Name "resourceGroupName" -Value $resourceGroupName
			$computeNetworks += $computeNetwork
			New-TraceMessage $moduleName $true $computeRegionName
		}
		New-TraceMessage $moduleName $true
	}

	if (!$networkOnly) {
		# 02 - Security
		$computeRegionIndex = 0
		$moduleName = "02 - Security"
		New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]
		$resourceGroupName = Get-ResourceGroupName $computeRegionIndex $resourceGroupNamePrefix "Security"
		$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionNames[$computeRegionIndex]
		if (!$resourceGroup) { return }

		$templateResources = "$templateDirectory/02-Security.json"
		$templateParameters = (Get-Content "$templateDirectory/02-Security.Parameters.json" -Raw | ConvertFrom-Json).parameters
		if ($templateParameters.virtualNetwork.value.name -eq "") {
			$templateParameters.virtualNetwork.value.name = $computeNetworks[$computeRegionIndex].name
		}
		if ($templateParameters.virtualNetwork.value.resourceGroupName -eq "") {
			$templateParameters.virtualNetwork.value.resourceGroupName = $computeNetworks[$computeRegionIndex].resourceGroupName
		}
		$templateParameters = '"{0}"' -f ($templateParameters | ConvertTo-Json -Compress).Replace('"', '\"')
		$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateResources --parameters $templateParameters) | ConvertFrom-Json
		if (!$groupDeployment) { return }

		$logAnalyticsWorkspaceId = $groupDeployment.properties.outputs.logAnalyticsWorkspaceId.value
		$logAnalyticsWorkspaceKey = $groupDeployment.properties.outputs.logAnalyticsWorkspaceKey.value
		New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]

		# * - Image Gallery Job
		$moduleName = "* - Image Gallery Job"
		$imageGallery = Receive-Job -InstanceId $imageGalleryJob.InstanceId -Wait
		New-TraceMessage $moduleName $true
	}

	$logAnalytics = New-Object PSObject
	$logAnalytics | Add-Member -MemberType NoteProperty -Name "workspaceId" -Value $logAnalyticsWorkspaceId
	$logAnalytics | Add-Member -MemberType NoteProperty -Name "workspaceKey" -Value $logAnalyticsWorkspaceKey

	$sharedServices = New-Object PSObject
	$sharedServices | Add-Member -MemberType NoteProperty -Name "computeNetworks" -Value $computeNetworks
	$sharedServices | Add-Member -MemberType NoteProperty -Name "imageGallery" -Value $imageGallery
	$sharedServices | Add-Member -MemberType NoteProperty -Name "logAnalytics" -Value $logAnalytics

	return $sharedServices
}

function Get-RegionNames ([string[]] $regionDisplayNames) {
	$regionNames = @()
	$regionLocations = (az account list-locations) | ConvertFrom-Json
	foreach ($regionDisplayName in $regionDisplayNames) {
		foreach ($regionLocation in $regionLocations) {
			if ($regionLocation.displayName -eq $regionDisplayName) {
				$regionNames += $regionLocation.name
			}
		}
	}
	return $regionNames
}

function Get-ResourceGroupName ($regionIndex, $resourceGroupNamePrefix, $resourceGroupNameSuffix) {
	$regionId = $regionIndex + 1
	$resourceGroupName = "$resourceGroupNamePrefix$regionId"
	return "$resourceGroupName-$resourceGroupNameSuffix"
}

function Get-ImageDefinition ($imageGallery, $imageDefinitionName) {
	foreach ($imageDefinition in $imageGallery.imageDefinitions) {
		if ($imageDefinition.name -eq $imageDefinitionName) {
			return $imageDefinition
		}
	}
}

function Get-ImageVersionId ($imageGalleryResourceGroupName, $imageGalleryName, $imageDefinitionName, $imageTemplateName) {
	$imageVersions = (az sig image-version list --resource-group $imageGalleryResourceGroupName --gallery-name $imageGalleryName --gallery-image-definition $imageDefinitionName) | ConvertFrom-Json
	foreach ($imageVersion in $imageVersions) {
		if ($imageVersion.tags.imageTemplate -eq $imageTemplateName) {
			return $imageVersion.id
		}
	}
}

function Get-FileSystemMounts ($storageCache) {
	$fsMounts = ""
	foreach ($fileSystem in $storageCache) {
		if ($fsMounts -ne "") {
			$fsMounts += "|"
		}
		$fsMount = $fileSystem.exportHost + ":" + $fileSystem.exportPath
		$fsMount += " " + $fileSystem.directory
		$fsMount += " " + $fileSystem.options
		$fsMounts += $fsMount
	}
	$memoryStream = New-Object System.IO.MemoryStream
	$streamWriter = New-Object System.IO.StreamWriter($memoryStream)
	$streamWriter.Write($fsMounts)
	$streamWriter.Close();
	return [System.Convert]::ToBase64String($memoryStream.ToArray())	
}

function Get-ScriptCommands ($scriptFile, $scriptParameters) {
	$script = Get-Content $scriptFile -Raw
	if ($scriptParameters) { # Windows PowerShell
		$script = "& {" + $script + "} " + $scriptParameters
		$scriptCommands = [System.Text.Encoding]::Unicode.GetBytes($script)
	} else { # Linux Bash
		$memoryStream = New-Object System.IO.MemoryStream
		$compressionStream = New-Object System.IO.Compression.GZipStream($memoryStream, [System.IO.Compression.CompressionMode]::Compress)
		$streamWriter = New-Object System.IO.StreamWriter($compressionStream)
		$streamWriter.Write($script)
		$streamWriter.Close();
		$scriptCommands = $memoryStream.ToArray()	
	}
	return [Convert]::ToBase64String($scriptCommands)
}
