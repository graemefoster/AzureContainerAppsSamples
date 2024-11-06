param vnetName string
param location string = resourceGroup().location
param vnetCidr string

resource vnet 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [vnetCidr]
    }
  }
}

resource azFirewallSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' = {
  name: 'AzureFirewallSubnet'
  parent: vnet
  properties: {
    addressPrefix: cidrSubnet(vnetCidr, 24, 1)
  }
}

resource peSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' = {
  name: 'PrivateEndpoints'
  parent: vnet
  properties: {
    addressPrefix: cidrSubnet(vnetCidr, 24, 2)
    privateEndpointNetworkPolicies: 'Enabled'
  }
  dependsOn: [
    azFirewallSubnet
  ]
}

resource azFwallManagementSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' = {
  parent: vnet
  name: 'AzureFirewallManagementSubnet'
  properties: {
    addressPrefix: cidrSubnet(vnetCidr, 24, 3)
    privateEndpointNetworkPolicies: 'Enabled'
  }
  dependsOn: [
    peSubnet
  ]
}

resource vmSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' = {
  name: 'VMSubnet'
  parent: vnet
  properties: {
    addressPrefix: cidrSubnet(vnetCidr, 24, 4)
    privateEndpointNetworkPolicies: 'Enabled'
  }
  dependsOn: [
    azFwallManagementSubnet
  ]
}

resource bastionSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' = {
  name: 'AzureBastionSubnet'
  parent: vnet
  properties: {
    addressPrefix: cidrSubnet(vnetCidr, 24, 5)
    privateEndpointNetworkPolicies: 'Enabled'
  }
  dependsOn: [
    vmSubnet
  ]
}

resource acrPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.azurecr.io'
  location: 'global'

  resource vnetLink 'virtualNetworkLinks@2020-06-01' = {
    name: 'privatelink.azurecr.io-link'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: vnet.id
      }
    }
  }
}

output vnetName string = vnetName
output vnetId string = vnet.id
output firewallSubnetId string = azFirewallSubnet.id
output firewallManagementSubnetId string = azFwallManagementSubnet.id
output privateEndpointSubnetId string = peSubnet.id
output acrPrivateDnsZoneId string = acrPrivateDnsZone.id
output vmSubnetId string = vmSubnet.id
output bastionSubnetId string = bastionSubnet.id
