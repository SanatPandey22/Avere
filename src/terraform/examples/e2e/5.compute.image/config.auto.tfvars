resourceGroupName = "AzureRender.Image"

# Compute Gallery (https://docs.microsoft.com/en-us/azure/virtual-machines/shared-image-galleries)
imageGalleryName = "Gallery"
imageDefinitions = [
  {
    name       = "Linux"
    type       = "Linux"
    generation = "V2"
    publisher  = "OpenLogic"
    offer      = "CentOS"
    sku        = "7_9-Gen2"
  },
  {
    name       = "WinScheduler"
    type       = "Windows"
    generation = "V2"
    publisher  = "MicrosoftWindowsServer"
    offer      = "WindowsServer"
    sku        = "2022-Datacenter-G2"
  },
  {
    name       = "WinFarm"
    type       = "Windows"
    generation = "V2"
    publisher  = "MicrosoftWindowsDesktop"
    offer      = "Windows-10"
    sku        = "Win10-21H2-Pro-G2"
  },
  {
    name       = "WinArtist"
    type       = "Windows"
    generation = "V2"
    publisher  = "MicrosoftWindowsDesktop"
    offer      = "Windows-11"
    sku        = "Win11-21H2-Pro"
  }
]

# Image Builder (https://docs.microsoft.com/en-us/azure/virtual-machines/image-builder-overview)
imageTemplates = [
  {
    name = "LnxScheduler"
    image = {
      definitionName = "Linux"
      sourceType     = "PlatformImage"
      customScript   = "customize.sh"
      inputVersion   = "Latest"
    }
    build = {
      runElevated    = false
      subnetName     = "Scheduler"
      machineSize    = "Standard_D16s_v5" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
      osDiskSizeGB   = 0                  // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#osdisksizegb
      timeoutMinutes = 120                // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#properties-buildtimeoutinminutes
      renderEngines  = ""
      outputVersion  = "10.0.0"
    }
  },
  {
    name = "LnxFarm"
    image = {
      definitionName = "Linux"
      sourceType     = "PlatformImage"
      customScript   = "customize.sh"
      inputVersion   = "Latest"
    }
    build = {
      runElevated    = false
      subnetName     = "Farm"
      machineSize    = "Standard_HB120rs_v2" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
      osDiskSizeGB   = 100                   // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#osdisksizegb
      timeoutMinutes = 120                   // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#properties-buildtimeoutinminutes
      renderEngines  = "Blender"
      outputVersion  = "1.0.0"
    }
  },
  {
    name = "LnxArtistV3"
    image = {
      definitionName = "Linux"
      sourceType     = "PlatformImage"
      customScript   = "customize.sh"
      inputVersion   = "Latest"
    }
    build = {
      runElevated    = false
      subnetName     = "Workstation"
      machineSize    = "Standard_NV48s_v3" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
      osDiskSizeGB   = 100                 // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#osdisksizegb
      timeoutMinutes = 120                 // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#properties-buildtimeoutinminutes
      renderEngines  = "Blender"
      outputVersion  = "3.0.0"
    }
  },
  {
    name = "LnxArtistV4"
    image = {
      definitionName = "Linux"
      sourceType     = "PlatformImage"
      customScript   = "customize.sh"
      inputVersion   = "Latest"
    }
    build = {
      runElevated    = false
      subnetName     = "Workstation"
      machineSize    = "Standard_NV32as_v4" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
      osDiskSizeGB   = 100                  // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#osdisksizegb
      timeoutMinutes = 120                  // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#properties-buildtimeoutinminutes
      renderEngines  = "Blender"
      outputVersion  = "4.0.0"
    }
  },
  # {
  #   name = "LnxArtistV5"
  #   image = {
  #     definitionName = "Linux"
  #     sourceType     = "PlatformImage"
  #     customScript   = "customize.sh"
  #     inputVersion   = "Latest"
  #   }
  #   build = {
  #     runElevated    = false
  #     subnetName     = "Workstation"
  #     machineSize    = "Standard_NV36ads_A10_v5" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
  #     osDiskSizeGB   = 100                       // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#osdisksizegb
  #     timeoutMinutes = 120                       // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#properties-buildtimeoutinminutes
  #     renderEngines  = "Blender"
  #     outputVersion  = "5.0.0"
  #   }
  # },
  {
    name = "WinScheduler"
    image = {
      definitionName = "WinScheduler"
      sourceType     = "PlatformImage"
      customScript   = "customize.ps1"
      inputVersion   = "Latest"
    }
    build = {
      runElevated    = true
      subnetName     = "Scheduler"
      machineSize    = "Standard_D16s_v5" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
      osDiskSizeGB   = 0                  // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#osdisksizegb
      timeoutMinutes = 240                // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#properties-buildtimeoutinminutes
      renderEngines  = ""
      outputVersion  = "10.0.0"
    }
  },
  {
    name = "WinFarm"
    image = {
      definitionName = "WinFarm"
      sourceType     = "PlatformImage"
      customScript   = "customize.ps1"
      inputVersion   = "Latest"
    }
    build = {
      runElevated    = false
      subnetName     = "Farm"
      machineSize    = "Standard_HB120rs_v2" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
      osDiskSizeGB   = 0                     // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#osdisksizegb
      timeoutMinutes = 240                   // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#properties-buildtimeoutinminutes
      renderEngines  = "Blender"
      outputVersion  = "1.0.0"
    }
  },
  {
    name = "WinArtistV3"
    image = {
      definitionName = "WinArtist"
      sourceType     = "PlatformImage"
      customScript   = "customize.ps1"
      inputVersion   = "Latest"
    }
    build = {
      runElevated    = false
      subnetName     = "Workstation"
      machineSize    = "Standard_NV48s_v3"   // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
      osDiskSizeGB   = 0                     // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#osdisksizegb
      timeoutMinutes = 240                   // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#properties-buildtimeoutinminutes
      renderEngines  = "Blender"
      outputVersion  = "3.0.0"
    }
  },
  {
    name = "WinArtistV4"
    image = {
      definitionName = "WinArtist"
      sourceType     = "PlatformImage"
      customScript   = "customize.ps1"
      inputVersion   = "Latest"
    }
    build = {
      runElevated    = false
      subnetName     = "Workstation"
      machineSize    = "Standard_NV32as_v4" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
      osDiskSizeGB   = 0                    // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#osdisksizegb
      timeoutMinutes = 240                  // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#properties-buildtimeoutinminutes
      renderEngines  = "Blender"
      outputVersion  = "4.0.0"
    }
  },
  # {
  #   name = "WinArtistV5"
  #   image = {
  #     definitionName = "WinArtist"
  #     sourceType     = "PlatformImage"
  #     customScript   = "customize.ps1"
  #     inputVersion   = "Latest"
  #   }
  #   build = {
  #     runElevated    = false
  #     subnetName     = "Workstation"
  #     machineSize    = "Standard_NV36ads_A10_v5" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
  #     osDiskSizeGB   = 0                         // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#osdisksizegb
  #     timeoutMinutes = 240                       // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#properties-buildtimeoutinminutes
  #     renderEngines  = "Blender"
  #     outputVersion  = "4.0.0"
  #   }
  # }
]

# Virtual Network (https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview)
virtualNetwork = {
  name              = ""
  resourceGroupName = ""
}
