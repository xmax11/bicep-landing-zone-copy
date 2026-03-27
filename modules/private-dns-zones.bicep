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
@description('Second Spoke VNet Resource ID (optional)')
param secondarySpokeVnetId string = ''
@description('Deploy App Service private DNS zones and links')
param deployAppService bool = true

// Common tags (environment in tags, not names)
var commonTags = {
  environment: environment
  project: projectName
  managedBy: 'Bicep'
  role: 'hub-dns-zone'
  placement: 'hub-vnet'
  scope: 'private-dns'
  deploymentLocation: location
}
var storageDnsSuffix = az.environment().suffixes.storage
var sqlServerHostname = az.environment().suffixes.sqlServerHostname
var sqlDnsSuffix = startsWith(sqlServerHostname, '.') ? substring(sqlServerHostname, 1) : sqlServerHostname

// ============================================
// PRIVATE DNS ZONES (Hub-centralized)
// Naming: {projectName}-hub-dns-{service}
// ============================================

// Storage Account DNS Zone
resource storageDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.blob.${storageDnsSuffix}'
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
  name: 'privatelink.${sqlDnsSuffix}'
  location: 'global'
  tags: commonTags
}

// App Service DNS Zone
resource appServiceDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if(deployAppService) {
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
  name: 'privatelink.file.${storageDnsSuffix}'
  location: 'global'
  tags: commonTags
}

// Queue Services DNS Zone
resource queueDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.queue.${storageDnsSuffix}'
  location: 'global'
  tags: commonTags
}

// Table Services DNS Zone
resource tableDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.table.${storageDnsSuffix}'
  location: 'global'
  tags: commonTags
}

// Web DNS Zone (for App Service)
resource webDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if(deployAppService) {
  name: 'privatelink.web.azurewebsites.net'
  location: 'global'
  tags: commonTags
}

// ============================================
// VIRTUAL NETWORK LINKS
// Naming: {projectName}-hub-dns-{service}-link-{hub-vnet|spoke-vnet|spoke2-vnet}
// Links Hub-hosted DNS zones to Hub and both Spoke VNets
// ============================================

// -------- Storage DNS Zone Links --------

resource storageDnsHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: storageDnsZone
  name: '${projectName}-hub-dns-storage-link-hub-vnet'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: hubVnetId }
  }
}

resource storageDnsSpokeLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: storageDnsZone
  name: '${projectName}-hub-dns-storage-link-spoke-vnet'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: spokeVnetId }
  }
}

resource storageDnsSpoke2Link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if(!empty(secondarySpokeVnetId)) {
  parent: storageDnsZone
  name: '${projectName}-hub-dns-storage-link-spoke2-vnet'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: secondarySpokeVnetId }
  }
}

// -------- Key Vault DNS Zone Links --------

resource keyVaultDnsHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: keyVaultDnsZone
  name: '${projectName}-hub-dns-keyvault-link-hub-vnet'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: hubVnetId }
  }
}

resource keyVaultDnsSpokeLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: keyVaultDnsZone
  name: '${projectName}-hub-dns-keyvault-link-spoke-vnet'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: spokeVnetId }
  }
}

resource keyVaultDnsSpoke2Link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if(!empty(secondarySpokeVnetId)) {
  parent: keyVaultDnsZone
  name: '${projectName}-hub-dns-keyvault-link-spoke2-vnet'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: secondarySpokeVnetId }
  }
}

// -------- SQL DNS Zone Links --------

resource sqlDnsHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: sqlDnsZone
  name: '${projectName}-hub-dns-sql-link-hub-vnet'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: hubVnetId }
  }
}

resource sqlDnsSpokeLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: sqlDnsZone
  name: '${projectName}-hub-dns-sql-link-spoke-vnet'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: spokeVnetId }
  }
}

resource sqlDnsSpoke2Link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if(!empty(secondarySpokeVnetId)) {
  parent: sqlDnsZone
  name: '${projectName}-hub-dns-sql-link-spoke2-vnet'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: secondarySpokeVnetId }
  }
}

// -------- App Service DNS Zone Links --------

resource appServiceDnsHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if(deployAppService) {
  parent: appServiceDnsZone
  name: '${projectName}-hub-dns-appservice-link-hub-vnet'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: hubVnetId }
  }
}

resource appServiceDnsSpokeLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if(deployAppService) {
  parent: appServiceDnsZone
  name: '${projectName}-hub-dns-appservice-link-spoke-vnet'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: spokeVnetId }
  }
}

resource appServiceDnsSpoke2Link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if(deployAppService && !empty(secondarySpokeVnetId)) {
  parent: appServiceDnsZone
  name: '${projectName}-hub-dns-appservice-link-spoke2-vnet'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: secondarySpokeVnetId }
  }
}

// -------- Cosmos DB DNS Zone Links --------

resource cosmosDbDnsHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: cosmosDbDnsZone
  name: '${projectName}-hub-dns-cosmosdb-link-hub-vnet'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: hubVnetId }
  }
}

resource cosmosDbDnsSpokeLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: cosmosDbDnsZone
  name: '${projectName}-hub-dns-cosmosdb-link-spoke-vnet'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: spokeVnetId }
  }
}

resource cosmosDbDnsSpoke2Link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if(!empty(secondarySpokeVnetId)) {
  parent: cosmosDbDnsZone
  name: '${projectName}-hub-dns-cosmosdb-link-spoke2-vnet'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: secondarySpokeVnetId }
  }
}

// -------- File DNS Zone Links --------

resource fileDnsHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: fileDnsZone
  name: '${projectName}-hub-dns-file-link-hub-vnet'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: hubVnetId }
  }
}

resource fileDnsSpokeLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: fileDnsZone
  name: '${projectName}-hub-dns-file-link-spoke-vnet'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: spokeVnetId }
  }
}

resource fileDnsSpoke2Link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if(!empty(secondarySpokeVnetId)) {
  parent: fileDnsZone
  name: '${projectName}-hub-dns-file-link-spoke2-vnet'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: secondarySpokeVnetId }
  }
}

// -------- Queue DNS Zone Links --------

resource queueDnsHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: queueDnsZone
  name: '${projectName}-hub-dns-queue-link-hub-vnet'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: hubVnetId }
  }
}

resource queueDnsSpokeLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: queueDnsZone
  name: '${projectName}-hub-dns-queue-link-spoke-vnet'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: spokeVnetId }
  }
}

resource queueDnsSpoke2Link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if(!empty(secondarySpokeVnetId)) {
  parent: queueDnsZone
  name: '${projectName}-hub-dns-queue-link-spoke2-vnet'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: secondarySpokeVnetId }
  }
}

// -------- Table DNS Zone Links --------

resource tableDnsHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: tableDnsZone
  name: '${projectName}-hub-dns-table-link-hub-vnet'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: hubVnetId }
  }
}

resource tableDnsSpokeLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: tableDnsZone
  name: '${projectName}-hub-dns-table-link-spoke-vnet'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: spokeVnetId }
  }
}

resource tableDnsSpoke2Link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if(!empty(secondarySpokeVnetId)) {
  parent: tableDnsZone
  name: '${projectName}-hub-dns-table-link-spoke2-vnet'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: secondarySpokeVnetId }
  }
}

// -------- Web DNS Zone Links --------

resource webDnsHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if(deployAppService) {
  parent: webDnsZone
  name: '${projectName}-hub-dns-web-link-hub-vnet'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: hubVnetId }
  }
}

resource webDnsSpokeLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if(deployAppService) {
  parent: webDnsZone
  name: '${projectName}-hub-dns-web-link-spoke-vnet'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: spokeVnetId }
  }
}

resource webDnsSpoke2Link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if(deployAppService && !empty(secondarySpokeVnetId)) {
  parent: webDnsZone
  name: '${projectName}-hub-dns-web-link-spoke2-vnet'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: secondarySpokeVnetId }
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
  appService: deployAppService ? appServiceDnsZone!.id : ''
  web: deployAppService ? webDnsZone!.id : ''
  cosmosDb: cosmosDbDnsZone.id
}

// Individual outputs for easy reference
output storagePrivateDnsZoneId string = storageDnsZone.id
output filePrivateDnsZoneId string = fileDnsZone.id
output queuePrivateDnsZoneId string = queueDnsZone.id
output tablePrivateDnsZoneId string = tableDnsZone.id
output keyVaultPrivateDnsZoneId string = keyVaultDnsZone.id
output sqlPrivateDnsZoneId string = sqlDnsZone.id
output appServicePrivateDnsZoneId string = deployAppService ? appServiceDnsZone!.id : ''
output webPrivateDnsZoneId string = deployAppService ? webDnsZone!.id : ''
output cosmosDbPrivateDnsZoneId string = cosmosDbDnsZone.id

output dnsZoneSummary array = concat([
  {
    dnsZoneName: storageDnsZone.name
    dnsZoneId: storageDnsZone.id
    placement: 'hub-vnet'
    hubVnetId: hubVnetId
    hubLinkId: storageDnsHubLink.id
    spokeLinkId: storageDnsSpokeLink.id
    spoke2LinkId: !empty(secondarySpokeVnetId) ? storageDnsSpoke2Link.id : ''
  }
  {
    dnsZoneName: keyVaultDnsZone.name
    dnsZoneId: keyVaultDnsZone.id
    placement: 'hub-vnet'
    hubVnetId: hubVnetId
    hubLinkId: keyVaultDnsHubLink.id
    spokeLinkId: keyVaultDnsSpokeLink.id
    spoke2LinkId: !empty(secondarySpokeVnetId) ? keyVaultDnsSpoke2Link.id : ''
  }
  {
    dnsZoneName: sqlDnsZone.name
    dnsZoneId: sqlDnsZone.id
    placement: 'hub-vnet'
    hubVnetId: hubVnetId
    hubLinkId: sqlDnsHubLink.id
    spokeLinkId: sqlDnsSpokeLink.id
    spoke2LinkId: !empty(secondarySpokeVnetId) ? sqlDnsSpoke2Link.id : ''
  }
], deployAppService ? [
  {
    dnsZoneName: appServiceDnsZone.name
    dnsZoneId: appServiceDnsZone.id
    placement: 'hub-vnet'
    hubVnetId: hubVnetId
    hubLinkId: appServiceDnsHubLink.id
    spokeLinkId: appServiceDnsSpokeLink.id
    spoke2LinkId: !empty(secondarySpokeVnetId) ? appServiceDnsSpoke2Link!.id : ''
  }
  ] : [], [
  {
    dnsZoneName: cosmosDbDnsZone.name
    dnsZoneId: cosmosDbDnsZone.id
    placement: 'hub-vnet'
    hubVnetId: hubVnetId
    hubLinkId: cosmosDbDnsHubLink.id
    spokeLinkId: cosmosDbDnsSpokeLink.id
    spoke2LinkId: !empty(secondarySpokeVnetId) ? cosmosDbDnsSpoke2Link.id : ''
  }
])

