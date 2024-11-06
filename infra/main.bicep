targetScope = 'subscription'

// The main bicep module to provision Azure resources.
// For a more complete walkthrough to understand how this file works with azd,
// see https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/make-azd-compatible?pivots=azd-create

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

// Optional parameters to override the default azd resource naming conventions.
// Add the following to main.parameters.json to provide values:
// "resourceGroupName": {
//      "value": "myGroupName"
// }
param resourceGroupName string = ''

@minLength(3)
param githubOrganisation string
@minLength(3)
param githubRepository string

@minLength(4)
param vmUsername string

@minLength(8)
@secure()
param vmPassword string

var abbrs = loadJsonContent('./abbreviations.json')

// tags that should be applied to all resources.
var tags = {
  // Tag all resources with the environment name.
  'azd-env-name': environmentName
}

// Generate a unique token to be used in naming resources.
// Remove linter suppression after using.
#disable-next-line no-unused-vars
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))

// Name of the service defined in azure.yaml
// A tag named azd-service-name with this value should be applied to the service host resource, such as:
//   Microsoft.Web/sites for appservice, function
// Example usage:
//   tags: union(tags, { 'azd-service-name': apiServiceName })

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

// Add resources to be provisioned below.
// A full example that leverages azd bicep modules can be seen in the todo-python-mongo template:
// https://github.com/Azure-Samples/todo-python-mongo/tree/main/infra
module foundation 'platform/foundation.bicep' = {
  name: '${deployment().name}-foundation'
  scope: rg
  params: {
    location: location
    logAnalyticsName: '${resourceToken}-loganalytics'
  }
}

module network 'platform/vnet.bicep' = {
  name: '${deployment().name}-network'
  scope: rg
  params: {
    vnetName: '${resourceToken}-vnet'
    location: location
    vnetCidr: '10.0.0.0/16'
  }
}

var routeTableName = '${abbrs.networkRouteTables}internetviafwall'

module fwall 'platform/firewall.bicep' = {
  name: '${deployment().name}-firewall'
  scope: rg
  params: {
    firewallPipName: '${resourceToken}-fwall-pip'
    firewallMgmtPipName: '${resourceToken}-fwall-mgmt-pip'
    firewallName: '${resourceToken}-fwall'
    firewallPolicyName: '${resourceToken}-fwall-policy'
    firewallRouteTableName: routeTableName
    location: location
    firewallSubnetId: network.outputs.firewallSubnetId
    firewallManagementSubnetId: network.outputs.firewallManagementSubnetId
    logAnalyticsId: foundation.outputs.logAnalyticsId
    vnetName: network.outputs.vnetName
  }
}

module aca 'platform/aca.bicep' = {
  name: '${deployment().name}-aca'
  scope: rg
  params: {
    resourceToken: resourceToken
    location: location
    githubEnvironment: environmentName
    githubOrganisation: githubOrganisation
    githubRepository: githubRepository
    acaSubnetId: fwall.outputs.acaSubnetId
    logAnalyticsId: foundation.outputs.logAnalyticsId
    privateEndpointSubnetId: network.outputs.privateEndpointSubnetId
    acrPrivateDnsZoneId: network.outputs.acrPrivateDnsZoneId
  }
}

module acaDns 'platform/aca-dns.bicep' = {
  name: '${deployment().name}-aca-dns'
  scope: rg
  params: {
    vnetName: network.outputs.vnetName
    acaEnvName: aca.outputs.acaEnvName
    acaEnvDefaultHostName: aca.outputs.acaEnvDefaultHostName
  }
}

//deploy a vm so we can peek inside and see what's going on
module developerVm './Platform/developerVm.bicep' = {
  name: '${deployment().name}-developerVm'
  scope: rg
  params: {
    location: location
    bastionName: '${replace(resourceToken, '-', '')}bastion'
    vmName: 'developervm'
    vmSize: 'Standard_D2s_v4'
    vmImage: '2022-datacenter-azure-edition'
    vnetId: network.outputs.vnetId
    vnetSubnetId: network.outputs.vmSubnetId
    bastionSubnetId: network.outputs.bastionSubnetId
    vmUser: vmUsername
    vmPassword: vmPassword
  }
}


// Add outputs from the deployment here, if needed.
//
// This allows the outputs to be referenced by other bicep deployments in the deployment pipeline,
// or by the local machine as a way to reference created resources in Azure for local development.
// Secrets should not be added here.
//
// Outputs are automatically saved in the local azd environment .env file.
// To see these outputs, run `azd env get-values`,  or `azd env get-values --output json` for json output.
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_DEPLOYMENT_PRINCIPAL_CLIENT_ID string = aca.outputs.deploymentIdentityClientId
