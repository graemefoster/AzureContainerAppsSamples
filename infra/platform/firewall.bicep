param firewallPipName string
param firewallMgmtPipName string
param firewallName string
param firewallPolicyName string
param firewallRouteTableName string
param location string = resourceGroup().location
param firewallSubnetId string
param firewallManagementSubnetId string
param logAnalyticsId string
param vnetName string

resource firewallPip 'Microsoft.Network/publicIPAddresses@2022-11-01' = {
  name: firewallPipName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
  zones: pickZones('Microsoft.Network', 'publicIPAddresses', location, 3)
}

resource firewallManagementPip 'Microsoft.Network/publicIPAddresses@2022-11-01' = {
  name: firewallMgmtPipName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
  zones: pickZones('Microsoft.Network', 'publicIPAddresses', location, 3)
}

resource fwallPolicy 'Microsoft.Network/firewallPolicies@2022-11-01' = {
  name: firewallPolicyName
  location: location
  properties: {
    sku: {
      tier: 'Basic'
    }
  }

  resource acaRuleGroup 'ruleCollectionGroups' = {
    name: 'aca-rule-group'
    properties: {
      priority: 1000
      ruleCollections: [
        {
          ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
          action: {
            type: 'Allow'
          }
          name: 'aca-rules'
          priority: 1001
          rules: [
            {
              ruleType: 'ApplicationRule'
              name: 'mcr'
              sourceAddresses: ['*']
              protocols: [{ protocolType: 'Https', port: 443 }]
              targetFqdns: [
                'mcr.microsoft.com'
                '*.data.mcr.microsoft.com' //justify by customers cannot do anything on this domain
                'acs-mirror.azureedge.net' //https://github.com/MicrosoftDocs/azure-docs/issues/38451
              ]
            }
            {
              ruleType: 'ApplicationRule'
              name: 'generalwindows'
              sourceAddresses: ['*']
              protocols: [{ protocolType: 'Https', port: 443 }]
              targetFqdns: [
                'crl.microsoft.com'
              ]
            }
            {
              ruleType: 'ApplicationRule'
              name: 'managed-identity'
              sourceAddresses: ['*']
              protocols: [{ protocolType: 'Https', port: 443 }]
              targetFqdns: [
                '*.identity.azure.net'
                'login.microsoftonline.com'
                '*.login.microsoftonline.com'
                '*.login.microsoft.com'
              ]
            }
            {
              ruleType: 'ApplicationRule'
              name: 'AzureMonitor'
              sourceAddresses: ['*']
              protocols: [{ protocolType: 'Https', port: 443 }]
              targetFqdns: [
                'dc.services.visualstudio.com'
                'gcs.prod.monitoring.core.windows.net'
              ]
            }
            {
              ruleType: 'ApplicationRule'
              name: 'AzureManagement'
              sourceAddresses: ['*']
              protocols: [{ protocolType: 'Https', port: 443 }]
              targetFqdns: [
                'management.azure.com'
              ]
            }
            {
              ruleType: 'ApplicationRule'
              name: 'AspireDashboard'
              sourceAddresses: ['*']
              protocols: [{ protocolType: 'Https', port: 443 }]
              targetFqdns: [
                'australiaeast.ext.azurecontainerapps.dev'
              ]
            }
          ]
        }
      ]
    }
  }
}

resource firewall 'Microsoft.Network/azureFirewalls@2024-01-01' = {
  name: firewallName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          subnet: {
            id: firewallSubnetId
          }
          publicIPAddress: {
            id: firewallPip.id
          }
        }
      }
    ]
    sku: {
      name: 'AZFW_VNet'
      tier: 'Basic'
    }
    managementIpConfiguration: {
      name: 'mgmntipconfig'
      properties: {
        publicIPAddress: {
          id: firewallManagementPip.id
        }
        subnet: {
          id: firewallManagementSubnetId
        }
      }
    }
    firewallPolicy: {
      id: fwallPolicy.id
    }
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: firewall
  name: 'diagnostics'
  properties: {
    workspaceId: logAnalyticsId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

resource routeTable 'Microsoft.Network/routeTables@2022-11-01' = {
  name: firewallRouteTableName
  location: location
  properties: {
    routes: [
      {
        name: 'InternetViaFirewall'
        properties: {
          nextHopType: 'VirtualAppliance'
          addressPrefix: '0.0.0.0/0'
          nextHopIpAddress: firewall.properties.ipConfigurations[0].properties.privateIPAddress
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-01-01' existing = {
  name: vnetName
  resource acaSubnet 'subnets' = {
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
      routeTable: {
        id: routeTable.id
      }
    }
  }
}

output publicIpV4 string = firewallPip.properties.ipAddress
output acaSubnetId string = filter(vnet.properties.subnets, subnet => subnet.name == 'AcaDelegated')[0].id
