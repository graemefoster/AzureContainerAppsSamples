param resourceToken string
param location string = resourceGroup().location
param githubOrganisation string
param githubRepository string
param acaSubnetId string
param privateEndpointSubnetId string
param acrPrivateDnsZoneId string
param githubEnvironment string
param logAnalyticsId string

resource deploymentIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' = {
  name: '${resourceToken}-deployer'
  location: location
  resource githubFederation 'federatedIdentityCredentials' = {
    name: 'github'
    properties: {
      issuer: 'https://token.actions.githubusercontent.com'
      subject: 'repo:${githubOrganisation}/${githubRepository}:environment:${githubEnvironment}'
      audiences: ['api://AzureADTokenExchange']
    }
  }
}

resource contributorRoleAssignment 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' existing = {
  scope: subscription()
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
}

resource deploymentContributorOnRg 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(deploymentIdentity.id, resourceGroup().name, contributorRoleAssignment.id)
  scope: resourceGroup()
  properties: {
    principalId: deploymentIdentity.properties.principalId
    roleDefinitionId: contributorRoleAssignment.id
    principalType: 'ServicePrincipal'
  }
}

resource cappenvacr 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: '${resourceToken}cappacr'
  location: location
  sku: { name: 'Premium' }
  properties: {
    adminUserEnabled: true
    publicNetworkAccess: 'Enabled'
    dataEndpointEnabled: true
  }
}

resource cappacrprivateendpoint 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  name: '${resourceToken}-cappenv-pe'
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'cappacrprivateendpoint'
        properties: {
          privateLinkServiceId: cappenvacr.id
          groupIds: ['registry']
        }
      }
    ]
  }

  resource dns 'privateDnsZoneGroups' = {
    name: 'cappacrprivateendpoint'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'cappacrprivateendpoint'
          properties: {
            privateDnsZoneId: acrPrivateDnsZoneId
          }
        }
      ]
    }
  }
}

resource cappenvacrdiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: cappenvacr
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

resource cappenv 'Microsoft.App/managedEnvironments@2024-02-02-preview' = {
  name: '${resourceToken}-cappenv'
  location: location
  properties: {
    // openTelemetryConfiguration: {
    //   destinationsConfiguration: {
    //     otlpConfigurations: [
    //       {
    //         endpoint: 'https://otlp.nr-data.net:4317'
    //         insecure: false
    //         name: 'GraemesNewRelicOLTPEndpoint'
    //         headers: [
    //           {
    //             key: 'api-key'
    //             value: '<license-here>'
    //           }
    //         ]
    //       }
    //     ]
    //   }
    //   logsConfiguration: {
    //     destinations: ['GraemesNewRelicOLTPEndpoint']
    //   }
    //   metricsConfiguration: {
    //     destinations: ['GraemesNewRelicOLTPEndpoint']
    //   }
    //   tracesConfiguration: {
    //     destinations: ['GraemesNewRelicOLTPEndpoint']
    //   }
    // }
    peerAuthentication: {
      mtls: {
        enabled: true
      }
    }
    peerTrafficConfiguration: {
      encryption: {
        enabled: true
      }
    }
    zoneRedundant: false
    vnetConfiguration: {
      internal: true
      infrastructureSubnetId: acaSubnetId
    }
    workloadProfiles: [
      {
        name: 'test'
        workloadProfileType: 'D4'
        minimumCount: 1
        maximumCount: 1
      }
    ]
    publicNetworkAccess: 'Disabled'
  }
}

resource frontEnd 'Microsoft.App/containerApps@2024-02-02-preview' = {
  name: 'frontend'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    configuration: {
      activeRevisionsMode: 'Multiple'
      ingress: {
        allowInsecure: false
        transport: 'auto'
        external: true
      }
      secrets: [
        {
          name: 'acr-secret'
          value: cappenvacr.listCredentials().passwords[0].value
        }
      ]
      runtime: {
        dotnet: {
          autoConfigureDataProtection: true
        }
      }
      registries: [
        {
          server: cappenvacr.properties.loginServer
          username: cappenvacr.listCredentials().username
          passwordSecretRef: 'acr-secret'
        }
      ]
    }
    environmentId: cappenv.id
    workloadProfileName: 'test'
    template: {
      containers: [
        {
          name: 'bootstrap-container-pre-artifact-upload'
          image: 'mcr.microsoft.com/k8se/quickstart:latest'
          resources: {
            cpu: any('0.5')
            memory: '1Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
        rules: [
          {
            name: 'http-scaler'
            http: {
              metadata: {
                concurrentRequests: '10'
              }
            }
          }
        ]
      }
    }
  }
}

resource backEnd 'Microsoft.App/containerApps@2024-02-02-preview' = {
  name: 'backend'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    configuration: {
      activeRevisionsMode: 'Multiple'
      ingress: {
        allowInsecure: false
        transport: 'auto'
        external: false
      }
      secrets: [
        {
          name: 'acr-secret'
          value: cappenvacr.listCredentials().passwords[0].value
        }
      ]
      runtime: {
        java: {
          enableMetrics: true
        }
      }
      registries: [
        {
          server: cappenvacr.properties.loginServer
          username: cappenvacr.listCredentials().username
          passwordSecretRef: 'acr-secret'
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'bootstrap-container-pre-artifact-upload'
          image: 'mcr.microsoft.com/k8se/quickstart:latest'
          resources: {
            cpu: any('0.5')
            memory: '1Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
        rules: [
          {
            name: 'http-scaler'
            http: {
              metadata: {
                concurrentRequests: '10'
              }
            }
          }
        ]
      }
    }
    environmentId: cappenv.id
  }
}

resource aspireDashboard 'Microsoft.App/managedEnvironments/dotNetComponents@2024-02-02-preview' = {
  parent: cappenv
  name: 'aspire-dashboard' //Same name used as the portal when you create it there.
  properties: {
    componentType: 'AspireDashboard'
  }
  //fails sometimes with 'cannot modify DotNetComponent ... because another modification is in progress'
  //try explicitly waiting...
  dependsOn: [
    frontEnd
    backEnd
  ]
}


// resource acaEnvBuilder 'Microsoft.App/builders@2024-02-02-preview' = {
//   name: '${resourceToken}-cappenv-builder'
//   location: location
//   identity: {
//     type: 'UserAssigned'
//     userAssignedIdentities: {
//       '${deploymentIdentity.id}': {}
//     }
//   }
//   properties: {
//     environmentId: cappenv.id
//   }
// }

output deploymentIdentityClientId string = deploymentIdentity.properties.clientId
// output builderAcr string = acaEnvBuilder.properties.containerRegistries[0].containerRegistryServer
output acaEnvDefaultHostName string = cappenv.properties.defaultDomain
output acaEnvName string = cappenv.name
