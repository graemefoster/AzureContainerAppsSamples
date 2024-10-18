param resourceToken string
param location string = resourceGroup().location
param githubOrganisation string
param githubRepository string
param githubEnvironment string

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

resource cappenv 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: '${resourceToken}-cappenv'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'azure-monitor'
    }
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
  }

  resource aspireDashboard 'dotNetComponents@2024-02-02-preview' = {
    name: '${cappenv.name}-asp-dash'
    properties: {
      componentType: 'AspireDashboard'
    }
  }
}

resource frontEnd 'Microsoft.App/containerApps@2024-02-02-preview' = {
  name: 'frontend'
  location: location
  properties: {
    configuration: {
      activeRevisionsMode: 'Multiple'
      ingress: {
        allowInsecure: false
        transport: 'auto'
        external: true
      }
      runtime: {
        dotnet: {
          autoConfigureDataProtection: true
        }
      }
    }
    environmentId: cappenv.id
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
        minReplicas: 0
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
  properties: {
    configuration: {
      activeRevisionsMode: 'Multiple'
      ingress: {
        allowInsecure: false
        transport: 'auto'
        external: false
      }
      runtime: {
        java: {
          enableMetrics: true
        }
      }
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
        minReplicas: 0
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

output deploymentIdentityClientId string = deploymentIdentity.properties.clientId

