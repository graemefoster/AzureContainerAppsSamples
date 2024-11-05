param vnetName string
param routeTableName string
param location string = resourceGroup().location
param vnetCidr string

resource routeTable 'Microsoft.Network/routeTables@2022-11-01' = {
  name: routeTableName
  location: location
}

resource vnet 'Microsoft.Network/virtualNetworks@2022-11-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [vnetCidr]
    }
    subnets: [
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: cidrSubnet(vnetCidr, 24, 1)
        }
      }
      {
        name: 'AcaDelegated'
        properties: {
          addressPrefix: '10.0.0.0/24'
          delegations: [
            {
              name: 'aca'
              properties: {
                serviceName: 'Microsoft.App/environments'
              }
            }
          ]
          routeTable: routeTable
        }
      }
      {
        name: 'PrivateEndpoints'
        properties: {
          addressPrefix: cidrSubnet(vnetCidr, 24, 2)
          privateEndpointNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'AzureFirewallManagementSubnet'
        properties: {
          addressPrefix: cidrSubnet(vnetCidr, 24, 3)
        }
      }
    ]
  }
}

output firewallSubnetId string = filter(vnet.properties.subnets, subnet => subnet.name == 'AzureFirewallSubnet')[0].id
output firewallManagementSubnetId string = filter(vnet.properties.subnets, subnet => subnet.name == 'AzureFirewallManagementSubnet')[0].id
output privateEndpointSubnetId string = filter(vnet.properties.subnets, subnet => subnet.name == 'PrivateEndpoints')[0].id
output acaSubnetId string = filter(vnet.properties.subnets, subnet => subnet.name == 'AcaDelegated')[0].id
