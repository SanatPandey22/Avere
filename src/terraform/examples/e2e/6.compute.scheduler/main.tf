terraform {
  required_version = ">= 1.2.8"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.21.1"
    }
  }
  backend "azurerm" {
    key = "6.compute.scheduler"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
    virtual_machine {
      delete_os_disk_on_deletion     = true
      graceful_shutdown              = false
      skip_shutdown_and_force_delete = false
    }
  }
}

module "global" {
  source = "../0.global"
}

variable "resourceGroupName" {
  type = string
}

variable "virtualMachines" {
  type = list(object(
    {
      name        = string
      imageId     = string
      machineSize = string
      operatingSystem = object(
        {
          type = string
          disk = object(
            {
              storageType = string
              cachingType = string
            }
          )
        }
      )
      adminLogin = object(
        {
          userName            = string
          sshPublicKey        = string
          disablePasswordAuth = bool
        }
      )
      customExtension = object(
        {
          enabled  = bool
          fileName = string
          parameters = object(
            {
              fileSystemMounts = list(string)
              autoScale = object(
                {
                  enabled                  = bool
                  fileName                 = string
                  scaleSetName             = string
                  resourceGroupName        = string
                  detectionIntervalSeconds = number
                  jobWaitThresholdSeconds  = number
                  workerIdleDeleteSeconds  = number
                }
              )
              cycleCloud = object(
                {
                  enabled = bool
                  storageAccount = object(
                    {
                      name       = string
                      type       = string
                      tier       = string
                      redundancy = string
                    }
                  )
                }
              )
            }
          )
        }
      )
      monitorExtension = object(
        {
          enabled = bool
        }
      )
    }
  ))
}

variable "computeNetwork" {
  type = object(
    {
      name               = string
      subnetName         = string
      resourceGroupName  = string
      privateDnsZoneName = string
    }
  )
}

variable "computeFarmImage" {
  type = object(
    {
      id                = string
      imageGalleryName  = string
      resourceGroupName = string
    }
  )
}

data "azurerm_client_config" "current" {}

data "azurerm_user_assigned_identity" "identity" {
  name                = module.global.managedIdentityName
  resource_group_name = module.global.securityResourceGroupName
}

data "azurerm_key_vault" "vault" {
  name                = module.global.keyVaultName
  resource_group_name = module.global.securityResourceGroupName
}

data "azurerm_key_vault_secret" "admin_password" {
  name         = module.global.keyVaultSecretNameAdminPassword
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_log_analytics_workspace" "monitor" {
  name                = module.global.monitorWorkspaceName
  resource_group_name = module.global.securityResourceGroupName
}

data "terraform_remote_state" "network" {
  count   = local.useOverrideConfig ? 0 : 1
  backend = "azurerm"
  config = {
    resource_group_name  = module.global.securityResourceGroupName
    storage_account_name = module.global.securityStorageAccountName
    container_name       = module.global.terraformStorageContainerName
    key                  = "2.network"
  }
}

data "terraform_remote_state" "image" {
  count   = var.computeFarmImage.id != "" ? 0 : 1
  backend = "azurerm"
  config = {
    resource_group_name  = module.global.securityResourceGroupName
    storage_account_name = module.global.securityStorageAccountName
    container_name       = module.global.terraformStorageContainerName
    key                  = "5.compute.image"
  }
}

data "azurerm_virtual_network" "compute" {
  name                 = local.useOverrideConfig ? var.computeNetwork.name : data.terraform_remote_state.network[0].outputs.computeNetwork.name
  resource_group_name  = local.useOverrideConfig ? var.computeNetwork.resourceGroupName : data.terraform_remote_state.network[0].outputs.resourceGroupName
}

data "azurerm_subnet" "farm" {
  name                 = local.useOverrideConfig ? var.computeNetwork.subnetName : data.terraform_remote_state.network[0].outputs.computeNetwork.subnets[data.terraform_remote_state.network[0].outputs.computeNetworkSubnetIndex.farm].name
  resource_group_name  = data.azurerm_virtual_network.compute.resource_group_name
  virtual_network_name = data.azurerm_virtual_network.compute.name
}

data "azurerm_private_dns_zone" "network" {
  name                 = local.useOverrideConfig ? var.computeNetwork.privateDnsZoneName : data.terraform_remote_state.network[0].outputs.privateDns.zoneName
  resource_group_name  = data.azurerm_virtual_network.compute.resource_group_name
}

locals {
  useOverrideConfig      = var.computeNetwork.name != ""
  imageIdFarm            = var.computeFarmImage.id != "" ? var.computeFarmImage.id : "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${local.imageResourceGroupName}/providers/Microsoft.Compute/galleries/${local.imageGalleryName}/images/Linux/versions/0.0.0"
  imageGalleryName       = var.computeFarmImage.id != "" ? var.computeFarmImage.imageGalleryName : data.terraform_remote_state.image[0].outputs.imageGalleryName
  imageResourceGroupName = var.computeFarmImage.id != "" ? var.computeFarmImage.resourceGroupName : data.terraform_remote_state.image[0].outputs.resourceGroupName
  schedulerMachineNames = [
    for virtualMachine in var.virtualMachines : virtualMachine.name if virtualMachine.name != ""
  ]
}

resource "azurerm_resource_group" "scheduler" {
  name     = var.resourceGroupName
  location = module.global.regionName
}

resource "azurerm_network_interface" "scheduler" {
  for_each = {
    for virtualMachine in var.virtualMachines : virtualMachine.name => virtualMachine if virtualMachine.name != ""
  }
  name                = each.value.name
  resource_group_name = azurerm_resource_group.scheduler.name
  location            = azurerm_resource_group.scheduler.location
  ip_configuration {
    name                          = "ipConfig"
    subnet_id                     = data.azurerm_subnet.farm.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "scheduler" {
  for_each = {
    for virtualMachine in var.virtualMachines : virtualMachine.name => virtualMachine if virtualMachine.name != "" && virtualMachine.operatingSystem.type == "Linux"
  }
  name                            = each.value.name
  resource_group_name             = azurerm_resource_group.scheduler.name
  location                        = azurerm_resource_group.scheduler.location
  source_image_id                 = each.value.imageId
  size                            = each.value.machineSize
  admin_username                  = each.value.adminLogin.userName
  admin_password                  = data.azurerm_key_vault_secret.admin_password.value
  disable_password_authentication = each.value.adminLogin.disablePasswordAuth
  custom_data = base64encode(
    templatefile(each.value.customExtension.parameters.autoScale.fileName, each.value.customExtension.parameters)
  )
  network_interface_ids = [
    "${azurerm_resource_group.scheduler.id}/providers/Microsoft.Network/networkInterfaces/${each.value.name}"
  ]
  os_disk {
    storage_account_type = each.value.operatingSystem.disk.storageType
    caching              = each.value.operatingSystem.disk.cachingType
  }
  identity {
    type         = "UserAssigned"
    identity_ids = [data.azurerm_user_assigned_identity.identity.id]
  }
  boot_diagnostics {
    storage_account_uri = null
  }
  dynamic "admin_ssh_key" {
    for_each = each.value.adminLogin.sshPublicKey == "" ? [] : [1]
    content {
      username   = each.value.adminLogin.userName
      public_key = each.value.adminLogin.sshPublicKey
    }
  }
  depends_on = [
    azurerm_network_interface.scheduler
  ]
}

resource "azurerm_virtual_machine_extension" "custom_linux" {
  for_each = {
    for virtualMachine in var.virtualMachines : virtualMachine.name => virtualMachine if virtualMachine.name != "" && virtualMachine.customExtension.enabled && virtualMachine.operatingSystem.type == "Linux"
  }
  name                       = "Custom"
  type                       = "CustomScript"
  publisher                  = "Microsoft.Azure.Extensions"
  type_handler_version       = "2.1"
  auto_upgrade_minor_version = true
  virtual_machine_id         = "${azurerm_resource_group.scheduler.id}/providers/Microsoft.Compute/virtualMachines/${each.value.name}"
  settings = jsonencode({
    "script": "${base64encode(
      templatefile(each.value.customExtension.fileName,
        merge(
          each.value.customExtension.parameters,
          { tenantId = data.azurerm_client_config.current.tenant_id },
          { subscriptionId = data.azurerm_client_config.current.subscription_id },
          { regionName = module.global.regionName },
          { networkResourceGroupName = data.azurerm_virtual_network.compute.resource_group_name },
          { networkName = data.azurerm_virtual_network.compute.name },
          { networkSubnetName = data.azurerm_subnet.farm.name },
          { imageIdFarm = local.imageIdFarm },
          { imageGalleryName = local.imageGalleryName },
          { imageResourceGroupName = local.imageResourceGroupName },
          { adminPassword = data.azurerm_key_vault_secret.admin_password.value }
        )
      )
    )}"
  })
  depends_on = [
    azurerm_linux_virtual_machine.scheduler
  ]
}

resource "azurerm_virtual_machine_extension" "monitor_linux" {
  for_each = {
    for virtualMachine in var.virtualMachines : virtualMachine.name => virtualMachine if virtualMachine.name != "" && virtualMachine.monitorExtension.enabled && virtualMachine.operatingSystem.type == "Linux"
  }
  name                       = "Monitor"
  type                       = "OmsAgentForLinux"
  publisher                  = "Microsoft.EnterpriseCloud.Monitoring"
  type_handler_version       = "1.13"
  auto_upgrade_minor_version = true
  virtual_machine_id         = "${azurerm_resource_group.scheduler.id}/providers/Microsoft.Compute/virtualMachines/${each.value.name}"
  settings = jsonencode({
    "workspaceId": data.azurerm_log_analytics_workspace.monitor.workspace_id
  })
  protected_settings = jsonencode({
    "workspaceKey": data.azurerm_log_analytics_workspace.monitor.primary_shared_key
  })
  depends_on = [
    azurerm_linux_virtual_machine.scheduler
  ]
}

resource "azurerm_windows_virtual_machine" "scheduler" {
  for_each = {
    for virtualMachine in var.virtualMachines : virtualMachine.name => virtualMachine if virtualMachine.name != "" && virtualMachine.operatingSystem.type == "Windows"
  }
  name                = each.value.name
  resource_group_name = azurerm_resource_group.scheduler.name
  location            = azurerm_resource_group.scheduler.location
  source_image_id     = each.value.imageId
  size                = each.value.machineSize
  admin_username      = each.value.adminLogin.userName
  admin_password      = data.azurerm_key_vault_secret.admin_password.value
  custom_data = base64encode(
    templatefile(each.value.customExtension.parameters.autoScale.fileName, each.value.customExtension.parameters)
  )
  network_interface_ids = [
    "${azurerm_resource_group.scheduler.id}/providers/Microsoft.Network/networkInterfaces/${each.value.name}"
  ]
  os_disk {
    storage_account_type = each.value.operatingSystem.disk.storageType
    caching              = each.value.operatingSystem.disk.cachingType
  }
  identity {
    type         = "UserAssigned"
    identity_ids = [data.azurerm_user_assigned_identity.identity.id]
  }
  boot_diagnostics {
    storage_account_uri = null
  }
  depends_on = [
    azurerm_network_interface.scheduler
  ]
}

resource "azurerm_virtual_machine_extension" "custom_windows" {
  for_each = {
    for virtualMachine in var.virtualMachines : virtualMachine.name => virtualMachine if virtualMachine.name != "" && virtualMachine.customExtension.enabled && virtualMachine.operatingSystem.type == "Windows"
  }
  name                       = "Custom"
  type                       = "CustomScriptExtension"
  publisher                  = "Microsoft.Compute"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true
  virtual_machine_id         = "${azurerm_resource_group.scheduler.id}/providers/Microsoft.Compute/virtualMachines/${each.value.name}"
  settings = jsonencode({
    "commandToExecute": "PowerShell -ExecutionPolicy Unrestricted -EncodedCommand ${textencodebase64(
      templatefile(each.value.customExtension.fileName, each.value.customExtension.parameters), "UTF-16LE"
    )}"
  })
  depends_on = [
    azurerm_windows_virtual_machine.scheduler
  ]
}

resource "azurerm_virtual_machine_extension" "monitor_windows" {
  for_each = {
    for virtualMachine in var.virtualMachines : virtualMachine.name => virtualMachine if virtualMachine.name != "" && virtualMachine.monitorExtension.enabled && virtualMachine.operatingSystem.type == "Windows"
  }
  name                       = "Monitor"
  type                       = "MicrosoftMonitoringAgent"
  publisher                  = "Microsoft.EnterpriseCloud.Monitoring"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
  virtual_machine_id         = "${azurerm_resource_group.scheduler.id}/providers/Microsoft.Compute/virtualMachines/${each.value.name}"
  settings = jsonencode({
    "workspaceId": data.azurerm_log_analytics_workspace.monitor.workspace_id
  })
  protected_settings = jsonencode({
    "workspaceKey": data.azurerm_log_analytics_workspace.monitor.primary_shared_key
  })
  depends_on = [
    azurerm_windows_virtual_machine.scheduler
  ]
}

resource "azurerm_private_dns_a_record" "scheduler" {
  count               = length(azurerm_network_interface.scheduler) == 0 ? 0 : 1
  name                = "scheduler"
  resource_group_name = data.azurerm_private_dns_zone.network.resource_group_name
  zone_name           = data.azurerm_private_dns_zone.network.name
  records             = [azurerm_network_interface.scheduler[local.schedulerMachineNames[0]].private_ip_address]
  ttl                 = 300
}

resource "azurerm_storage_account" "cycle_cloud" {
  for_each = {
    for virtualMachine in var.virtualMachines : virtualMachine.name => virtualMachine if virtualMachine.customExtension.parameters.cycleCloud.enabled
  }
  name                            = each.value.customExtension.parameters.cycleCloud.storageAccount.name
  resource_group_name             = azurerm_resource_group.scheduler.name
  location                        = azurerm_resource_group.scheduler.location
  account_kind                    = each.value.customExtension.parameters.cycleCloud.storageAccount.type
  account_tier                    = each.value.customExtension.parameters.cycleCloud.storageAccount.tier
  account_replication_type        = each.value.customExtension.parameters.cycleCloud.storageAccount.redundancy
  allow_nested_items_to_be_public = false
}

resource "azurerm_role_assignment" "cycle_cloud" {
  for_each = {
    for virtualMachine in var.virtualMachines : virtualMachine.name => virtualMachine if virtualMachine.customExtension.parameters.cycleCloud.enabled
  }
  role_definition_name = "Contributor"
  principal_id         = data.azurerm_user_assigned_identity.identity.principal_id
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
}

output "resourceGroupName" {
  value = var.resourceGroupName
}

output "virtualMachines" {
  value = var.virtualMachines
}

output "privateDnsRecord" {
  value = azurerm_private_dns_a_record.scheduler
}
