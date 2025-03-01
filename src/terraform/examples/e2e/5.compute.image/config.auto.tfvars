resourceGroupName = "ArtistAnywhere.Image"

# Compute Gallery (https://docs.microsoft.com/azure/virtual-machines/shared-image-galleries)
imageGalleryName = "Gallery"
imageDefinitions = [
  {
    name       = "Linux"
    type       = "Linux"
    generation = "V2"
    publisher  = "AlmaLinux"
    offer      = "AlmaLinux"
    sku        = "9-Gen2"
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

# Image Builder (https://docs.microsoft.com/azure/virtual-machines/image-builder-overview)
imageTemplates = [
  {
    name  = "LnxScheduler"
    image = {
      definitionName   = "Linux"
      customizeScript  = "customize.sh"
      terminateScript1 = "terminate.sh"
      terminateScript2 = "onTerminate.sh"
      inputVersion     = "Latest"
    }
    build = {
      machineType    = "Scheduler"
      machineSize    = "Standard_D8s_v5" // https://docs.microsoft.com/azure/virtual-machines/sizes
      osDiskSizeGB   = 0                 // https://docs.microsoft.com/azure/virtual-machines/linux/image-builder-json#osdisksizegb
      timeoutMinutes = 120               // https://docs.microsoft.com/azure/virtual-machines/linux/image-builder-json#properties-buildtimeoutinminutes
      outputVersion  = "0.0.0"
      runElevated    = false
      renderEngines  = []
    }
  },
  {
    name  = "LnxFarm"
    image = {
      definitionName   = "Linux"
      customizeScript  = "customize.sh"
      terminateScript1 = "terminate.sh"
      terminateScript2 = "onTerminate.sh"
      inputVersion     = "Latest"
    }
    build = {
      machineType    = "Farm"
      machineSize    = "Standard_HB120rs_v2" // https://docs.microsoft.com/azure/virtual-machines/sizes
      osDiskSizeGB   = 512                   // https://docs.microsoft.com/azure/virtual-machines/linux/image-builder-json#osdisksizegb
      timeoutMinutes = 240                   // https://docs.microsoft.com/azure/virtual-machines/linux/image-builder-json#properties-buildtimeoutinminutes
      outputVersion  = "1.0.0"
      runElevated    = false
      renderEngines  = [
        "Blender",
        "PBRT",
        "Unity",
        "Unreal",
        # "Maya",
        # "Houdini"
      ]
    }
  },
  {
    name  = "LnxArtist"
    image = {
      definitionName   = "Linux"
      customizeScript  = "customize.sh"
      terminateScript1 = "terminate.sh"
      terminateScript2 = "onTerminate.sh"
      inputVersion     = "Latest"
    }
    build = {
      machineType    = "Workstation"
      machineSize    = "Standard_NV36ads_A10_v5" // https://docs.microsoft.com/azure/virtual-machines/sizes
      osDiskSizeGB   = 512                       // https://docs.microsoft.com/azure/virtual-machines/linux/image-builder-json#osdisksizegb
      timeoutMinutes = 240                       // https://docs.microsoft.com/azure/virtual-machines/linux/image-builder-json#properties-buildtimeoutinminutes
      outputVersion  = "2.0.0"
      runElevated    = false
      renderEngines  = [
        "Blender",
        "PBRT",
        "Unity",
        "Unreal",
        # "Maya",
        # "Houdini"
      ]
    }
  },
  {
    name  = "WinScheduler"
    image = {
      definitionName   = "WinScheduler"
      customizeScript  = "customize.ps1"
      terminateScript1 = "terminate.ps1"
      terminateScript2 = "onTerminate.ps1"
      inputVersion     = "Latest"
    }
    build = {
      machineType    = "Scheduler"
      machineSize    = "Standard_D8s_v5" // https://docs.microsoft.com/azure/virtual-machines/sizes
      osDiskSizeGB   = 0                 // https://docs.microsoft.com/azure/virtual-machines/linux/image-builder-json#osdisksizegb
      timeoutMinutes = 180               // https://docs.microsoft.com/azure/virtual-machines/linux/image-builder-json#properties-buildtimeoutinminutes
      outputVersion  = "0.0.0"
      runElevated    = true
      renderEngines  = []
    }
  },
  {
    name  = "WinFarm"
    image = {
      definitionName   = "WinFarm"
      customizeScript  = "customize.ps1"
      terminateScript1 = "terminate.ps1"
      terminateScript2 = "onTerminate.ps1"
      inputVersion     = "Latest"
    }
    build = {
      machineType    = "Farm"
      machineSize    = "Standard_HB120rs_v2" // https://docs.microsoft.com/azure/virtual-machines/sizes
      osDiskSizeGB   = 512                   // https://docs.microsoft.com/azure/virtual-machines/linux/image-builder-json#osdisksizegb
      timeoutMinutes = 480                   // https://docs.microsoft.com/azure/virtual-machines/linux/image-builder-json#properties-buildtimeoutinminutes
      outputVersion  = "1.0.0"
      runElevated    = false
      renderEngines  = [
        "Blender",
        "PBRT",
        "Unity",
        "Unreal",
        # "Maya",
        # "3DSMax",
        # "Houdini"
      ]
    }
  },
  {
    name  = "WinArtist"
    image = {
      definitionName   = "WinArtist"
      customizeScript  = "customize.ps1"
      terminateScript1 = "terminate.ps1"
      terminateScript2 = "onTerminate.ps1"
      inputVersion     = "Latest"
    }
    build = {
      machineType    = "Workstation"
      machineSize    = "Standard_NV36ads_A10_v5" // https://docs.microsoft.com/azure/virtual-machines/sizes
      osDiskSizeGB   = 512                       // https://docs.microsoft.com/azure/virtual-machines/linux/image-builder-json#osdisksizegb
      timeoutMinutes = 480                       // https://docs.microsoft.com/azure/virtual-machines/linux/image-builder-json#properties-buildtimeoutinminutes
      outputVersion  = "2.0.0"
      runElevated    = false
      renderEngines  = [
        "Blender",
        "PBRT",
        "Unity",
        "Unreal",
        # "Maya",
        # "3DSMax",
        # "Houdini"
      ]
    }
  }
]

####################################################################################
# Optional override configuration when not using Terraform remote state management #
####################################################################################

computeNetwork = {
  name              = ""
  resourceGroupName = ""
}
