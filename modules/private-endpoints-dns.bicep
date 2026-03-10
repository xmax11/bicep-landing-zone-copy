/*
  Dynamic Private Endpoints and DNS Configuration Module
  
  This module creates/manages Private DNS Zones and links them to existing VNets,
  then configures private endpoints with automatic DNS registration.
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
  'sinet-hub-spoke-spoke-vnet'
]

@description('Subscription ID for VNet references')
param subscriptionId string = subscription().id

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
// GET VNET IDS
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
// PRIVATE DNS ZONES
// ============================================

resource keyVaultDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: serviceConfigs.keyVault.dnsZoneName
  location: 'global'
  tags: { environment: environment, project: projectName }
}

resource storageDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: serviceConfigs.storage.dnsZoneName
  location: 'global'
  tags: { environment: environment, project: projectName }
}

resource sqlDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: serviceConfigs.sql.dnsZoneName
  location: 'global'
  tags: { environment: environment, project: projectName }
}

resource appServiceDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: serviceConfigs.appService.dnsZoneName
  location: 'global'
  tags: { environment: environment, project: projectName }
}

resource cosmosDbDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: serviceConfigs.cosmosDb.dnsZoneName
  location: 'global'
  tags: { environment: environment, project: projectName }
}

// ============================================
// VNET LINKS FOR DNS ZONES
// ============================================

// Key Vault Links
resource keyVaultDnsHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: keyVaultDnsZone
  name: '${projectName}-keyvault-hub-link'
  location: 'global'
  properties: { registrationEnabled: false, virtualNetwork: { id: hubVnet.id } }
}

resource keyVaultDnsSpoke1Link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if(length(spokeVnetNames) > 0) {
  parent: keyVaultDnsZone
  name: '${projectName}-keyvault-spoke1-link'
  location: 'global'
  properties: { registrationEnabled: false, virtualNetwork: { id: spokeVnet1.id } }
}

// Storage Links
resource storageDnsHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: storageDnsZone
  name: '${projectName}-storage-hub-link'
  location: 'global'
  properties: { registrationEnabled: false, virtualNetwork: { id: hubVnet.id } }
}

resource storageDnsSpoke1Link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if(length(spokeVnetNames) > 0) {
  parent: storageDnsZone
  name: '${projectName}-storage-spoke1-link'
  location: 'global'
  properties: { registrationEnabled: false, virtualNetwork: { id: spokeVnet1.id } }
}

// SQL Links
resource sqlDnsHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: sqlDnsZone
  name: '${projectName}-sql-hub-link'
  location: 'global'
  properties: { registrationEnabled: false, virtualNetwork: { id: hubVnet.id } }
}

resource sqlDnsSpoke1Link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if(length(spokeVnetNames) > 0) {
  parent: sqlDnsZone
  name: '${projectName}-sql-spoke1-link'
  location: 'global'
  properties: { registrationEnabled: false, virtualNetwork: { id: spokeVnet1.id } }
}

// App Service Links
resource appServiceDnsHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: appServiceDnsZone
  name: '${projectName}-appservice-hub-link'
  location: 'global'
  properties: { registrationEnabled: false, virtualNetwork: { id: hubVnet.id } }
}

resource appServiceDnsSpoke1Link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if(length(spokeVnetNames) > 0) {
  parent: appServiceDnsZone
  name: '${projectName}-appservice-spoke1-link'
  location: 'global'
  properties: { registrationEnabled: false, virtualNetwork: { id: spokeVnet1.id } }
}

// ============================================
// PRIVATE ENDPOINTS CREATION
// ============================================

// Key Vault
resource keyVaultPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-02-01' = {
  name: 'pe-${projectName}-keyvault'
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

resource keyVaultDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-02-01' = {
  parent: keyVaultPrivateEndpoint
  name: 'keyvault-dns-zone-group'
  properties: {
    privateDnsZoneConfigs: [
      { name: 'keyvault-dns-config', properties: { privateDnsZoneId: keyVaultDnsZone.id } }
    ]
  }
}

// Storage
resource storagePrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-02-01' = {
  name: 'pe-${projectName}-storage'
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

resource storageDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-02-01' = {
  parent: storagePrivateEndpoint
  name: 'storage-dns-zone-group'
  properties: {
    privateDnsZoneConfigs: [
      { name: 'storage-dns-config', properties: { privateDnsZoneId: storageDnsZone.id } }
    ]
  }
}

// SQL
resource sqlPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-02-01' = {
  name: 'pe-${projectName}-sql'
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

resource sqlDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-02-01' = {
  parent: sqlPrivateEndpoint
  name: 'sql-dns-zone-group'
  properties: {
    privateDnsZoneConfigs: [
      { name: 'sql-dns-config', properties: { privateDnsZoneId: sqlDnsZone.id } }
    ]
  }
}

// App Service
resource appServicePrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-02-01' = {
  name: 'pe-${projectName}-appservice'
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

resource appServiceDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-02-01' = {
  parent: appServicePrivateEndpoint
  name: 'appservice-dns-zone-group'
  properties: {
    privateDnsZoneConfigs: [
      { name: 'appservice-dns-config', properties: { privateDnsZoneId: appServiceDnsZone.id } }
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
    dnsZoneId: keyVaultDnsZone.id
    hubVnetLinkId: keyVaultDnsHubLink.id
    spokeVnetLinkId: length(spokeVnetNames) > 0 ? keyVaultDnsSpoke1Link.id : ''
  }
  {
    serviceName: 'Storage'
    privateEndpointName: storagePrivateEndpoint.name
    privateEndpointId: storagePrivateEndpoint.id
    dnsZoneName: serviceConfigs.storage.dnsZoneName
    dnsZoneId: storageDnsZone.id
    hubVnetLinkId: storageDnsHubLink.id
    spokeVnetLinkId: length(spokeVnetNames) > 0 ? storageDnsSpoke1Link.id : ''
  }
  {
    serviceName: 'SQL Server'
    privateEndpointName: sqlPrivateEndpoint.name
    privateEndpointId: sqlPrivateEndpoint.id
    dnsZoneName: serviceConfigs.sql.dnsZoneName
    dnsZoneId: sqlDnsZone.id
    hubVnetLinkId: sqlDnsHubLink.id
    spokeVnetLinkId: length(spokeVnetNames) > 0 ? sqlDnsSpoke1Link.id : ''
  }
  {
    serviceName: 'App Service'
    privateEndpointName: appServicePrivateEndpoint.name
    privateEndpointId: appServicePrivateEndpoint.id
    dnsZoneName: serviceConfigs.appService.dnsZoneName
    dnsZoneId: appServiceDnsZone.id
    hubVnetLinkId: appServiceDnsHubLink.id
    spokeVnetLinkId: length(spokeVnetNames) > 0 ? appServiceDnsSpoke1Link.id : ''
  }
]

output hubVnetId string = hubVnet.id
output dnsZoneIds object = {
  keyVault: keyVaultDnsZone.id
  storage: storageDnsZone.id
  sql: sqlDnsZone.id
  appService: appServiceDnsZone.id
  cosmosDb: cosmosDbDnsZone.id
}
