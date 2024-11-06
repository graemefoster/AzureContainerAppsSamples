param vnetName string
param acaEnvName string
param acaEnvDefaultHostName string

resource cappEnv 'Microsoft.App/managedEnvironments@2024-02-02-preview' existing = {
  name: acaEnvName
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-01-01' existing = {
  name: vnetName
}

resource cappEnvDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: acaEnvDefaultHostName
  location: 'global'

  resource aRecord 'A' = {
    name: '*'
    properties: {
      ttl: 3600
      aRecords: [
        {
          ipv4Address: cappEnv.properties.staticIp
        }
      ]
    }
  }

  resource aRecordExt 'A' = {
    name: '*.ext'
    properties: {
      ttl: 3600
      aRecords: [
        {
          ipv4Address: cappEnv.properties.staticIp
        }
      ]
    }
  }

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

