/*
  Azure Landing Zone - Hub and Spoke Topology
*/

targetScope = 'subscription'

@description('Azure region for deployment')
param location string = 'eastus'

@description('Environment name (production, staging, development)')
param environment string = 'production'

@description('Project name used for resource naming')
param projectName string = 'my-landing-zone'

@description('Hub VNet address space (CIDR)')
param hubVnetAddressSpace string = '10.100.0.0/16'

@description('Spoke VNet address space (CIDR)')
param spokeVnetAddressSpace string = '10.200.0.0/16'

@description('Private IP of Azure Firewall or NVA in hub')
param firewallPrivateIp string = '10.100.0.4'

@description('Private IP of NVA in spoke AppSubnet (if used)')
param nvaPrivateIp string = '10.200.1.4'

@description('Deploy Log Analytics Workspace')
param deployLogAnalytics bool = true

@description('Deploy Private DNS Zones')
param deployPrivateDns bool = true

@description('Deploy Azure Policies')
param deployAzurePolicies bool = true

@description('Alert email address for action group')
param alertEmailAddress string

@description('Azure AD Object ID for Key Vault access policy')
param keyVaultAccessObjectId string

// Generate unique suffix for storage and key vault names
var uniqueSuffix = take(uniqueString(subscription().id, location), 8)
var resourceGroupName = '${projectName}-rg-${location}'
var logAnalyticsName = '${projectName}law${location}${uniqueSuffix}'
var keyVaultName = take('${projectName}kv${uniqueSuffix}', 24)
var storageAccountName = take(replace('${projectName}st${uniqueSuffix}', '-', ''), 24)

// Create Resource Group
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
  tags: {
    environment: environment
    project: projectName
  }
}

// Deploy Networking
module networking 'modules/networking.bicep' = {
  name: 'networkingDeployment'
  scope: resourceGroup
  params: {
    location: location
    projectName: projectName
    environment: environment
    hubVnetAddressSpace: hubVnetAddressSpace
    spokeVnetAddressSpace: spokeVnetAddressSpace
    firewallPrivateIp: firewallPrivateIp
    nvaPrivateIp: nvaPrivateIp
  }
}

// Deploy Monitoring (Log Analytics)
module monitoring 'modules/monitoring.bicep' = if(deployLogAnalytics) {
  name: 'monitoringDeployment'
  scope: resourceGroup
  params: {
    location: location
    logAnalyticsName: logAnalyticsName
    projectName: projectName
    environment: environment
    alertEmailAddress: alertEmailAddress
  }
}

// Deploy Security (Key Vault, Private DNS Zones)
module security 'modules/security.bicep' = {
  name: 'securityDeployment'
  scope: resourceGroup
  params: {
    location: location
    keyVaultName: keyVaultName
    projectName: projectName
    environment: environment
    deployPrivateDns: deployPrivateDns
    logAnalyticsWorkspaceId: deployLogAnalytics ? monitoring.outputs.logAnalyticsWorkspaceId : ''
    hubVnetId: networking.outputs.hubVnetId
    spokeVnetId: networking.outputs.spokeVnetId
    keyVaultAccessObjectId: keyVaultAccessObjectId
  }
}

// Deploy Storage Account
module storage 'modules/storage.bicep' = {
  name: 'storageDeployment'
  scope: resourceGroup
  params: {
    location: location
    storageAccountName: storageAccountName
    projectName: projectName
    environment: environment
    logAnalyticsWorkspaceId: deployLogAnalytics ? monitoring.outputs.logAnalyticsWorkspaceId : ''
  }
}

// Deploy Private Endpoints (for Storage and Key Vault)
module privateEndpoints 'modules/private-endpoints.bicep' = {
  name: 'privateEndpointsDeployment'
  scope: resourceGroup
  params: {
    location: location
    projectName: projectName
    environment: environment
    storageAccountId: storage.outputs.storageAccountId
    keyVaultId: security.outputs.keyVaultId
    hubVnetId: networking.outputs.hubVnetId
    paasSubnetId: networking.outputs.paasSubnetId
    storagePrivateDnsZoneId: security.outputs.storagePrivateDnsZoneId
    keyVaultPrivateDnsZoneId: security.outputs.keyVaultPrivateDnsZoneId
  }
}

// Deploy Azure Policies
// Deploy Azure Policies
module policies 'modules/policies.bicep' = if(deployAzurePolicies) {
  name: 'policiesDeployment'
  // Since main is subscription scope, the module defaults to subscription, 
  // but being explicit helps prevent deployment mapping errors.
  scope: subscription() 
  params: {
    location: location
    projectName: projectName
    tagName: 'environment' // This matches the defaultValue in your policy
  }
}

// Outputs
output hubVnetId string = networking.outputs.hubVnetId
output spokeVnetId string = networking.outputs.spokeVnetId
output logAnalyticsWorkspaceId string = deployLogAnalytics ? monitoring.outputs.logAnalyticsWorkspaceId : ''
output keyVaultId string = security.outputs.keyVaultId
output storageAccountId string = storage.outputs.storageAccountId
output resourceGroupName string = resourceGroup.name
output resourceGroupId string = resourceGroup.id
output storagePrivateEndpointId string = privateEndpoints.outputs.storagePrivateEndpointId
output keyVaultPrivateEndpointId string = privateEndpoints.outputs.keyVaultPrivateEndpointId
