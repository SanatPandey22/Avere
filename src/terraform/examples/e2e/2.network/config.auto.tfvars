resourceGroupName = "ArtistAnywhere.Network"

################################################################################################
# Virtual Network (https://docs.microsoft.com/azure/virtual-network/virtual-networks-overview) #
################################################################################################

computeNetwork = {
  name               = "Compute"
  regionName         = "WestUS2"
  addressSpace       = ["10.1.0.0/16"]
  dnsServerAddresses = []
  subnets = [
    {
      name              = "Farm"
      addressSpace      = ["10.1.0.0/17"]
      serviceEndpoints  = [],
      serviceDelegation = ""
    },
    {
      name              = "Workstation"
      addressSpace      = ["10.1.128.0/18"]
      serviceEndpoints  = []
      serviceDelegation = ""
    },
    {
      name              = "Cache"
      addressSpace      = ["10.1.192.0/24"]
      serviceEndpoints  = ["Microsoft.Storage"]
      serviceDelegation = ""
    },
    {
      name              = "GatewaySubnet"
      addressSpace      = ["10.1.255.0/24"]
      serviceEndpoints  = []
      serviceDelegation = ""
    }
  ]
}

computeNetworkSubnetIndex = {
  farm        = 0
  workstation = 1
  cache       = 2
}

storageNetwork = {
  name               = "Storage"
  regionName         = "WestCentralUS"
  addressSpace       = ["10.0.0.0/16"]
  dnsServerAddresses = []
  subnets = [
    {
      name              = "Storage1"
      addressSpace      = ["10.0.0.0/24"]
      serviceEndpoints  = ["Microsoft.Storage"]
      serviceDelegation = ""
    },
    {
      name              = "Storage2"
      addressSpace      = ["10.0.1.0/24"]
      serviceEndpoints  = []
      serviceDelegation = ""
    },
    {
      name              = "StorageNetApp"
      addressSpace      = ["10.0.2.0/24"]
      serviceEndpoints  = []
      serviceDelegation = "Microsoft.Netapp/volumes"
    },
    {
      name              = "GatewaySubnet"
      addressSpace      = ["10.0.255.0/24"]
      serviceEndpoints  = []
      serviceDelegation = ""
    }
  ]
}

storageNetworkSubnetIndex = {
  storage1      = 0
  storage2      = 1
  storageNetApp = 2
}

###########################################################################
# Private DNS (https://docs.microsoft.com/azure/dns/private-dns-overview) #
###########################################################################

privateDns = {
  zoneName               = "artist.studio"
  enableAutoRegistration = true
}

########################################
# Hybrid Network (VPN or ExpressRoute) #
########################################

hybridNetwork = {
  type = ""
  //type = "Vpn"          // https://docs.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpngateways
  //type = "ExpressRoute" // https://docs.microsoft.com/azure/expressroute/expressroute-about-virtual-network-gateways
  address = {
    type             = "Standard"
    allocationMethod = "Static"
  }
}

##############################################################################################################
# Virtual Network Gateway (VPN) (https://docs.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpngateways) #
##############################################################################################################

vpnGateway = {
  sku                = "VpnGw2"
  type               = "RouteBased"
  generation         = "Generation2"
  enableBgp          = false
  enableActiveActive = false
}

# Site-to-Site Local Network Gateway (https://docs.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpn-gateway-settings#lng)
vpnGatewayLocal = {
  fqdn              = "" // Set the fully-qualified domain name (FQDN) of your on-premises VPN gateway device
  address           = "" // OR set the public IP address of your on-prem VPN gateway device. Do not set both.
  addressSpace      = []
  bgpAsn            = 0
  bgpPeeringAddress = ""
  bgpPeerWeight     = 0
}

# Point-to-Site Client (https://docs.microsoft.com/azure/vpn-gateway/vpn-gateway-howto-point-to-site-rm-ps)
vpnGatewayClient = {
  addressSpace    = []
  certificateName = ""
  certificateData = ""
}

######################################################################################################################################
# Virtual Network Gateway (ExpressRoute) (https://docs.microsoft.com/azure/expressroute/expressroute-about-virtual-network-gateways) #
######################################################################################################################################

expressRoute = {
  circuitId          = ""         // Expected format is "/subscriptions/[subscription_id]/resourceGroups/[resource_group_name]/providers/Microsoft.Network/expressRouteCircuits/[circuit_name]"
  gatewaySku         = "Standard" // https://docs.microsoft.com/azure/expressroute/expressroute-about-virtual-network-gateways#gwsku
  connectionFastPath = false      // https://docs.microsoft.com/azure/expressroute/about-fastpath
  connectionAuthKey  = ""
}
