param location string = resourceGroup().location
param logAnalyticsName string

resource lanalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

output logAnalyticsId string = lanalytics.id
