/*
  Centralized Private DNS Zones Module
  
  Naming Convention: {projectName}-hub-dns-{service}
  - All DNS zones are created centrally in the Hub
  - Includes 'hub' in all resource names to reflect centralized deployment
  - Environment managed through tags, not naming
  
  This module creates Private DNS Zones in the Hub resource group.
  It does NOT create Private Endpoints - those are handled by the private-endpoints module.
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

@description('Hub VNet Resource ID')
param hubVnetId string

@description('Spoke VNet Resource ID')
param spokeVnetId string

// Common tags (environment in tags, not names)
var commonTags = {
  environment: environment
  project: projectName
  managedBy: 'Bicep'
  role: 'hub-dns-zone'
}

// ============================================
// PRIVATE DNS ZONES (Hub-centralized)
// Naming: {projectName}-hub-dns-{service}
// ============================================

// Storage Account DNS Zone
resource storageDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.blob.core.windows.net'
  location: 'global'
  tags: commonTags
}

// Key Vault DNS Zone
resource keyVaultDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'
  tags: commonTags
}

// SQL Server DNS Zone
resource sqlDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.database.windows.net'
  location: 'global'
  tags: commonTags
}

// App Service DNS Zone
resource appServiceDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.azurewebsites.net'
  location: 'global'
  tags: commonTags
}

// Cosmos DB DNS Zone
resource cosmosDbDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.documents.azure.com'
  location: 'global'
  tags: commonTags
}

// File Services DNS Zone
resource fileDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.file.core.windows.net'
  location: 'global'
  tags: commonTags
}

// Queue Services DNS Zone
resource queueDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.queue.core.windows.net'
  location: 'global'
  tags: commonTags
}

// Table Services DNS Zone
resource tableDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.table.core.windows.net'
  location: 'global'
  tags: commonTags
}

// Web DNS Zone (for App Service)
resource webDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.web.azurewebsites.net'
  location: 'global'
  tags: commonTags
}

// ============================================
// VIRTUAL NETWORK LINKS
// Naming: {projectName}-hub-dns-{service}-link-{hub|spoke}
// Links Hub-hosted DNS zones to both Hub and Spoke VNets
// ============================================

// -------- Storage DNS Zone Links --------

resource storageDnsHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: storageDnsZone
  name: '${projectName}-hub-dns-storage-link-hub'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: hubVnetId }
  }
}

resource storageDnsSpokeLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: storageDnsZone
  name: '${projectName}-hub-dns-storage-link-spoke'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: spokeVnetId }
  }
}

// -------- Key Vault DNS Zone Links --------

resource keyVaultDnsHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: keyVaultDnsZone
  name: '${projectName}-hub-dns-keyvault-link-hub'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: hubVnetId }
  }
}

resource keyVaultDnsSpokeLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: keyVaultDnsZone
  name: '${projectName}-hub-dns-keyvault-link-spoke'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: spokeVnetId }
  }
}

// -------- SQL DNS Zone Links --------

resource sqlDnsHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: sqlDnsZone
  name: '${projectName}-hub-dns-sql-link-hub'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: hubVnetId }
  }
}

resource sqlDnsSpokeLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: sqlDnsZone
  name: '${projectName}-hub-dns-sql-link-spoke'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: spokeVnetId }
  }
}

// -------- App Service DNS Zone Links --------

resource appServiceDnsHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: appServiceDnsZone
  name: '${projectName}-hub-dns-appservice-link-hub'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: hubVnetId }
  }
}

resource appServiceDnsSpokeLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: appServiceDnsZone
  name: '${projectName}-hub-dns-appservice-link-spoke'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: spokeVnetId }
  }
}

// -------- Cosmos DB DNS Zone Links --------

resource cosmosDbDnsHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: cosmosDbDnsZone
  name: '${projectName}-hub-dns-cosmosdb-link-hub'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: hubVnetId }
  }
}

resource cosmosDbDnsSpokeLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: cosmosDbDnsZone
  name: '${projectName}-hub-dns-cosmosdb-link-spoke'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: spokeVnetId }
  }
}

// -------- File DNS Zone Links --------

resource fileDnsHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: fileDnsZone
  name: '${projectName}-hub-dns-file-link-hub'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: hubVnetId }
  }
}

resource fileDnsSpokeLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: fileDnsZone
  name: '${projectName}-hub-dns-file-link-spoke'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: spokeVnetId }
  }
}

// -------- Queue DNS Zone Links --------

resource queueDnsHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: queueDnsZone
  name: '${projectName}-hub-dns-queue-link-hub'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: hubVnetId }
  }
}

resource queueDnsSpokeLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: queueDnsZone
  name: '${projectName}-hub-dns-queue-link-spoke'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: spokeVnetId }
  }
}

// -------- Table DNS Zone Links --------

resource tableDnsHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: tableDnsZone
  name: '${projectName}-hub-dns-table-link-hub'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: hubVnetId }
  }
}

resource tableDnsSpokeLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: tableDnsZone
  name: '${projectName}-hub-dns-table-link-spoke'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: spokeVnetId }
  }
}

// -------- Web DNS Zone Links --------

resource webDnsHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: webDnsZone
  name: '${projectName}-hub-dns-web-link-hub'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: hubVnetId }
  }
}

resource webDnsSpokeLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: webDnsZone
  name: '${projectName}-hub-dns-web-link-spoke'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: spokeVnetId }
  }
}

// ============================================
// OUTPUTS
// DNS Zone IDs to be consumed by Private Endpoint modules
// ============================================

output dnsZoneIds object = {
  storage: {
    blob: storageDnsZone.id
    file: fileDnsZone.id
    queue: queueDnsZone.id
    table: tableDnsZone.id
  }
  keyVault: keyVaultDnsZone.id
  sql: sqlDnsZone.id
  appService: appServiceDnsZone.id
  web: webDnsZone.id
  cosmosDb: cosmosDbDnsZone.id
}

// Individual outputs for easy reference
output storagePrivateDnsZoneId string = storageDnsZone.id
output filePrivateDnsZoneId string = fileDnsZone.id
output queuePrivateDnsZoneId string = queueDnsZone.id
output tablePrivateDnsZoneId string = tableDnsZone.id
output keyVaultPrivateDnsZoneId string = keyVaultDnsZone.id
output sqlPrivateDnsZoneId string = sqlDnsZone.id
output appServicePrivateDnsZoneId string = appServiceDnsZone.id
output webPrivateDnsZoneId string = webDnsZone.id
output cosmosDbPrivateDnsZoneId string = cosmosDbDnsZone.id

output dnsZoneSummary array = [
  {
    dnsZoneName: storageDnsZone.name
    dnsZoneId: storageDnsZone.id
    hubLinkId: storageDnsHubLink.id
    spokeLinkId: storageDnsSpokeLink.id
  }
  {
    dnsZoneName: keyVaultDnsZone.name
    dnsZoneId: keyVaultDnsZone.id
    hubLinkId: keyVaultDnsHubLink.id
    spokeLinkId: keyVaultDnsSpokeLink.id
  }
  {
    dnsZoneName: sqlDnsZone.name
    dnsZoneId: sqlDnsZone.id
    hubLinkId: sqlDnsHubLink.id
    spokeLinkId: sqlDnsSpokeLink.id
  }
  {
    dnsZoneName: appServiceDnsZone.name
    dnsZoneId: appServiceDnsZone.id
    hubLinkId: appServiceDnsHubLink.id
    spokeLinkId: appServiceDnsSpokeLink.id
  }
  {
    dnsZoneName: cosmosDbDnsZone.name
    dnsZoneId: cosmosDbDnsZone.id
    hubLinkId: cosmosDbDnsHubLink.id
    spokeLinkId: cosmosDbDnsSpokeLink.id
  }
]
