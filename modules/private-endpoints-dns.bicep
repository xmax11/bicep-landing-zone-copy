/*
  Private Endpoints with DNS Configuration Module
  
  Naming Convention: {projectName}-spoke-pe-{service}
  - Includes 'spoke' to indicate deployment in Spoke VNet
  - Includes target service name
  - Environment managed through tags, not naming
  
  IMPORTANT: This module consumes existing Private DNS Zones as parameters.
  Private DNS Zones are created centrally in the Hub using the private-dns-zones module.
*/

targetScope = 'resourceGroup'

// ============================================
// PARAMETERS
// ============================================

@description('Azure region for deployment')
param location string = 'eastus'

@description('Project name used for resource naming')
param projectName string = 'sinet-hub-spoke'

@description('Environment name')
param environment string = 'production'

@description('Hub VNet name')
param hubVnetName string = 'sinet-hub-spoke-hub-vnet'

@description('Spoke VNet names array')
param spokeVnetNames array = [
  'sinet-hub-spoke-spoke-infra-vnet'
]

@description('Subscription ID for VNet references')
param subscriptionId string = subscription().id

// ============================================
// DNS ZONE IDs (Existing - from centralized private-dns-zones module)
// ============================================

@description('Existing Storage Private DNS Zone ID')
param storageDnsZoneId string

@description('Existing Key Vault Private DNS Zone ID')
param keyVaultDnsZoneId string

@description('Existing SQL Private DNS Zone ID')
param sqlDnsZoneId string = ''

@description('Existing App Service Private DNS Zone ID')
param appServiceDnsZoneId string = ''

@description('Existing Cosmos DB Private DNS Zone ID')
param cosmosDbDnsZoneId string = ''

// ============================================
// SERVICE CONFIGURATION
// ============================================

var serviceConfigs = {
  keyVault: {
    dnsZoneName: 'privatelink.vaultcore.azure.net'
    groupId: 'vault'
    resourceType: 'Microsoft.KeyVault/vaults'
  }
  storage: {
    dnsZoneName: 'privatelink.blob.core.windows.net'
    groupId: 'blob'
    resourceType: 'Microsoft.Storage/storageAccounts'
  }
  sql: {
    dnsZoneName: 'privatelink.database.windows.net'
    groupId: 'sqlServer'
    resourceType: 'Microsoft.Sql/servers'
  }
  appService: {
    dnsZoneName: 'privatelink.azurewebsites.net'
    groupId: 'sites'
    resourceType: 'Microsoft.Web/sites'
  }
  cosmosDb: {
    dnsZoneName: 'privatelink.documents.azure.com'
    groupId: 'Sql'
    resourceType: 'Microsoft.DocumentDB/databaseAccounts'
  }
}

// ============================================
// PRIVATE ENDPOINTS DEFINITION
// ============================================

param privateEndpoints array = [
  {
    name: 'kv-pe'
    serviceKey: 'keyVault'
    resourceId: '/subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.KeyVault/vaults/{kv-name}'
    subnetName: 'PaaSSvcSubnet'
  }
  {
    name: 'st-pe'
    serviceKey: 'storage'
    resourceId: '/subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.Storage/storageAccounts/{storage-name}'
    subnetName: 'PaaSSvcSubnet'
  }
  {
    name: 'sql-pe'
    serviceKey: 'sql'
    resourceId: '/subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.Sql/servers/{sql-server-name}'
    subnetName: 'PaaSSvcSubnet'
  }
  {
    name: 'appservice-pe'
    serviceKey: 'appService'
    resourceId: '/subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.Web/sites/{app-service-name}'
    subnetName: 'PaaSSvcSubnet'
  }
]

// ============================================
// GET VNET REFERENCES
// ============================================

resource hubVnet 'Microsoft.Network/virtualNetworks@2023-02-01' existing = {
  name: hubVnetName
  scope: resourceGroup(subscriptionId, split(resourceGroup().id, '/')[4])
}

resource spokeVnet1 'Microsoft.Network/virtualNetworks@2023-02-01' existing = if(length(spokeVnetNames) > 0) {
  name: spokeVnetNames[0]
  scope: resourceGroup(subscriptionId, split(resourceGroup().id, '/')[4])
}

// ============================================
// PRIVATE ENDPOINTS CREATION
// Naming: {projectName}-spoke-pe-{service}
// ============================================

// Key Vault Private Endpoint
// Naming: {projectName}-spoke-pe-keyvault
resource keyVaultPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-02-01' = {
  name: '${projectName}-spoke-pe-keyvault'
  location: location
  tags: { environment: environment, project: projectName }
  properties: {
    subnet: { id: '${hubVnet.id}/subnets/PaaSSvcSubnet' }
    privateLinkServiceConnections: [
      {
        name: 'keyvault-connection'
        properties: {
          privateLinkServiceId: privateEndpoints[0].resourceId
          groupIds: [ serviceConfigs.keyVault.groupId ]
        }
      }
    ]
  }
}

resource keyVaultDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-02-01' = if(!empty(keyVaultDnsZoneId)) {
  parent: keyVaultPrivateEndpoint
  name: 'spoke-keyvault-dns-group'
  properties: {
    privateDnsZoneConfigs: [
      { name: 'keyvault-dns-config', properties: { privateDnsZoneId: keyVaultDnsZoneId } }
    ]
  }
}

// Storage Private Endpoint
// Naming: {projectName}-spoke-pe-storage
resource storagePrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-02-01' = {
  name: '${projectName}-spoke-pe-storage'
  location: location
  tags: { environment: environment, project: projectName }
  properties: {
    subnet: { id: '${hubVnet.id}/subnets/PaaSSvcSubnet' }
    privateLinkServiceConnections: [
      {
        name: 'storage-connection'
        properties: {
          privateLinkServiceId: privateEndpoints[1].resourceId
          groupIds: [ serviceConfigs.storage.groupId ]
        }
      }
    ]
  }
}

resource storageDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-02-01' = if(!empty(storageDnsZoneId)) {
  parent: storagePrivateEndpoint
  name: 'spoke-storage-dns-group'
  properties: {
    privateDnsZoneConfigs: [
      { name: 'storage-dns-config', properties: { privateDnsZoneId: storageDnsZoneId } }
    ]
  }
}

// SQL Private Endpoint (Conditional)
// Naming: {projectName}-spoke-pe-sql
var sqlEnabled = !empty(sqlDnsZoneId)

resource sqlPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-02-01' = if(sqlEnabled) {
  name: '${projectName}-spoke-pe-sql'
  location: location
  tags: { environment: environment, project: projectName }
  properties: {
    subnet: { id: '${hubVnet.id}/subnets/PaaSSvcSubnet' }
    privateLinkServiceConnections: [
      {
        name: 'sql-connection'
        properties: {
          privateLinkServiceId: privateEndpoints[2].resourceId
          groupIds: [ serviceConfigs.sql.groupId ]
        }
      }
    ]
  }
}

resource sqlDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-02-01' = if(sqlEnabled) {
  parent: sqlPrivateEndpoint
  name: 'spoke-sql-dns-group'
  properties: {
    privateDnsZoneConfigs: [
      { name: 'sql-dns-config', properties: { privateDnsZoneId: sqlDnsZoneId } }
    ]
  }
}

// App Service Private Endpoint (Conditional)
// Naming: {projectName}-spoke-pe-appservice
var appServiceEnabled = !empty(appServiceDnsZoneId)

resource appServicePrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-02-01' = if(appServiceEnabled) {
  name: '${projectName}-spoke-pe-appservice'
  location: location
  tags: { environment: environment, project: projectName }
  properties: {
    subnet: { id: '${hubVnet.id}/subnets/PaaSSvcSubnet' }
    privateLinkServiceConnections: [
      {
        name: 'appservice-connection'
        properties: {
          privateLinkServiceId: privateEndpoints[3].resourceId
          groupIds: [ serviceConfigs.appService.groupId ]
        }
      }
    ]
  }
}

resource appServiceDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-02-01' = if(appServiceEnabled) {
  parent: appServicePrivateEndpoint
  name: 'spoke-appservice-dns-group'
  properties: {
    privateDnsZoneConfigs: [
      { name: 'appservice-dns-config', properties: { privateDnsZoneId: appServiceDnsZoneId } }
    ]
  }
}

// ============================================
// OUTPUTS
// ============================================

output privateEndpointSummary array = [
  {
    serviceName: 'Key Vault'
    privateEndpointName: keyVaultPrivateEndpoint.name
    privateEndpointId: keyVaultPrivateEndpoint.id
    dnsZoneName: serviceConfigs.keyVault.dnsZoneName
    dnsZoneId: keyVaultDnsZoneId
  }
  {
    serviceName: 'Storage'
    privateEndpointName: storagePrivateEndpoint.name
    privateEndpointId: storagePrivateEndpoint.id
    dnsZoneName: serviceConfigs.storage.dnsZoneName
    dnsZoneId: storageDnsZoneId
  }
  {
    serviceName: 'SQL Server'
    privateEndpointName: sqlEnabled ? sqlPrivateEndpoint.name : ''
    privateEndpointId: sqlEnabled ? sqlPrivateEndpoint.id : ''
    dnsZoneName: serviceConfigs.sql.dnsZoneName
    dnsZoneId: sqlDnsZoneId
  }
  {
    serviceName: 'App Service'
    privateEndpointName: appServiceEnabled ? appServicePrivateEndpoint.name : ''
    privateEndpointId: appServiceEnabled ? appServicePrivateEndpoint.id : ''
    dnsZoneName: serviceConfigs.appService.dnsZoneName
    dnsZoneId: appServiceDnsZoneId
  }
]

output hubVnetId string = hubVnet.id
output dnsZoneIds object = {
  keyVault: keyVaultDnsZoneId
  storage: storageDnsZoneId
  sql: sqlDnsZoneId
  appService: appServiceDnsZoneId
  cosmosDb: cosmosDbDnsZoneId
}
