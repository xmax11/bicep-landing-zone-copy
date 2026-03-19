/*
  Azure Landing Zone - Hub and Spoke Topology
  Deployment: Networking + DNS + Private Endpoints Only (No VMs, SQL, App Services)
*/

targetScope = 'subscription'

@description('Azure region for deployment')
param location string = 'eastus'

@description('Environment name (production, staging, development)')
param environment string = 'production'

@description('Project name used for resource naming')
param projectName string = 'sinet-hub-spoke'

@description('Hub VNet address space (CIDR)')
param hubVnetAddressSpace string = '10.100.0.0/16'

@description('Spoke VNet address space (CIDR)')
param spokeVnetAddressSpace string = '10.200.0.0/16'

@description('Private IP of NVA in spoke AppSubnet (leave empty for dynamic assignment)')
param nvaPrivateIp string = ''

@description('Deploy Log Analytics Workspace')
param deployLogAnalytics bool = true

@description('Deploy Azure Policies')
param deployAzurePolicies bool = true

@description('Alert email address for action group')
param alertEmailAddress string = 'alerts@contoso.com'

@description('Deploy Azure Firewall')
param deployFirewall bool = false

// Generate unique suffix for naming
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
    managedBy: 'Bicep'
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
    nvaPrivateIp: nvaPrivateIp
    deployFirewall: deployFirewall
  }
}

// Deploy Monitoring
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

// Deploy Security (Key Vault only - DNS Zones are now centralized)
module security 'modules/security.bicep' = {
  name: 'securityDeployment'
  scope: resourceGroup
  params: {
    location: location
    keyVaultName: keyVaultName
    projectName: projectName
    environment: environment
    logAnalyticsWorkspaceId: deployLogAnalytics ? monitoring.outputs.logAnalyticsWorkspaceId : ''
    hubVnetId: networking.outputs.hubVnetId
    spokeVnetId: networking.outputs.spokeVnetId
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
    logAnalyticsWorkspaceId: deployLogAnalytics && !empty(monitoring.outputs.logAnalyticsWorkspaceId) ? monitoring.outputs.logAnalyticsWorkspaceId : ''
  }
}

// Deploy Private DNS Zones (Centralized in Hub)
// These zones are created in the Hub resource group and linked to both Hub and Spoke VNets
module privateDnsZones 'modules/private-dns-zones.bicep' = {
  name: 'privateDnsZonesDeployment'
  scope: resourceGroup
  params: {
    location: location
    projectName: projectName
    environment: environment
    hubVnetId: networking.outputs.hubVnetId
    spokeVnetId: networking.outputs.spokeVnetId
  }
}

// Deploy Private Endpoints for Storage and Key Vault (no VMs/SQL/App Services)
// Uses centralized DNS Zone IDs from private-dns-zones module
module privateEndpoints 'modules/private-endpoints.bicep' = {
  name: 'privateEndpointsDeployment'
  scope: resourceGroup
  params: {
    location: location
    projectName: projectName
    environment: environment
    storageAccountId: storage.outputs.storageAccountId
    keyVaultId: security.outputs.keyVaultId
    sqlServerId: ''
    cosmosDbAccountId: ''
    appServiceId: ''
    paasSubnetId: networking.outputs.paasSubnetId
    storagePrivateDnsZoneId: privateDnsZones.outputs.storagePrivateDnsZoneId
    keyVaultPrivateDnsZoneId: privateDnsZones.outputs.keyVaultPrivateDnsZoneId
    sqlPrivateDnsZoneId: privateDnsZones.outputs.sqlPrivateDnsZoneId
    appServicePrivateDnsZoneId: privateDnsZones.outputs.appServicePrivateDnsZoneId
    cosmosDbPrivateDnsZoneId: privateDnsZones.outputs.cosmosDbPrivateDnsZoneId
  }
}

// Deploy Azure Policies at the Subscription Level
module policies 'modules/policies.bicep' = if(deployAzurePolicies) {
  name: 'policiesDeployment-${uniqueSuffix}'
  scope: subscription() 
  params: {
    projectName: projectName
    environment: environment
    // We removed projectName and tagName because they aren't in the new policies.bicep
  }
}

// Outputs
output hubVnetId string = networking.outputs.hubVnetId
output spokeVnetId string = networking.outputs.spokeVnetId
output firewallPrivateIpAddress string = deployFirewall ? networking.outputs.firewallPrivateIpAddress : ''
output logAnalyticsWorkspaceId string = deployLogAnalytics ? monitoring.outputs.logAnalyticsWorkspaceId : ''
output keyVaultId string = security.outputs.keyVaultId
output keyVaultName string = security.outputs.keyVaultName
output storageAccountId string = storage.outputs.storageAccountId
output resourceGroupName string = resourceGroup.name
output resourceGroupId string = resourceGroup.id

// Private DNS Zone IDs (from centralized private-dns-zones module)
output storagePrivateDnsZoneId string = privateDnsZones.outputs.storagePrivateDnsZoneId
output keyVaultPrivateDnsZoneId string = privateDnsZones.outputs.keyVaultPrivateDnsZoneId
output sqlPrivateDnsZoneId string = privateDnsZones.outputs.sqlPrivateDnsZoneId
output cosmosDbPrivateDnsZoneId string = privateDnsZones.outputs.cosmosDbPrivateDnsZoneId
output appServicePrivateDnsZoneId string = privateDnsZones.outputs.appServicePrivateDnsZoneId
output filePrivateDnsZoneId string = privateDnsZones.outputs.filePrivateDnsZoneId
output webPrivateDnsZoneId string = privateDnsZones.outputs.webPrivateDnsZoneId

// Private Endpoint IDs
output storagePrivateEndpointId string = privateEndpoints.outputs.storagePrivateEndpointId
output keyVaultPrivateEndpointId string = privateEndpoints.outputs.keyVaultPrivateEndpointId
output sqlPrivateEndpointId string = privateEndpoints.outputs.sqlPrivateEndpointId
output cosmosDbPrivateEndpointId string = privateEndpoints.outputs.cosmosDbPrivateEndpointId
output appServicePrivateEndpointId string = privateEndpoints.outputs.appServicePrivateEndpointId

output paasSubnetId string = networking.outputs.paasSubnetId
output appSubnetId string = networking.outputs.appSubnetId
