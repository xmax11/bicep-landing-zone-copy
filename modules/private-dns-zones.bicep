/*
  Centralized Private DNS Zones Module (Hub-only links)

  Naming Convention: {projectName}-hub-dns-{service}
  - All DNS zones are created centrally in the Hub resource group
  - Each zone is linked only to the Hub VNet
  - Environment managed through tags, not naming
*/

targetScope = 'resourceGroup'

@description('Azure region for deployment')
param location string = 'eastus'

@description('Project name used for resource naming')
param projectName string = 'sinet-hub-spoke'

@description('Environment name')
param environment string = 'production'

@description('Hub VNet Resource ID')
param hubVnetId string

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
// ============================================

resource storageDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.blob.${storageDnsSuffix}'
  location: 'global'
  tags: commonTags
}

resource keyVaultDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'
  tags: commonTags
}

resource sqlDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.${sqlDnsSuffix}'
  location: 'global'
  tags: commonTags
}

resource appServiceDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (deployAppService) {
  name: 'privatelink.azurewebsites.net'
  location: 'global'
  tags: commonTags
}

resource cosmosDbDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.documents.azure.com'
  location: 'global'
  tags: commonTags
}

resource fileDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.file.${storageDnsSuffix}'
  location: 'global'
  tags: commonTags
}

resource queueDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.queue.${storageDnsSuffix}'
  location: 'global'
  tags: commonTags
}

resource tableDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.table.${storageDnsSuffix}'
  location: 'global'
  tags: commonTags
}

resource webDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (deployAppService) {
  name: 'privatelink.web.azurewebsites.net'
  location: 'global'
  tags: commonTags
}

// ============================================
// HUB VNET LINKS (Hub-only)
// ============================================

resource storageDnsHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: storageDnsZone
  name: '${projectName}-hub-dns-storage-link-hub-vnet'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: hubVnetId
    }
  }
}

resource keyVaultDnsHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: keyVaultDnsZone
  name: '${projectName}-hub-dns-keyvault-link-hub-vnet'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: hubVnetId
    }
  }
}

resource sqlDnsHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: sqlDnsZone
  name: '${projectName}-hub-dns-sql-link-hub-vnet'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: hubVnetId
    }
  }
}

resource appServiceDnsHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (deployAppService) {
  parent: appServiceDnsZone
  name: '${projectName}-hub-dns-appservice-link-hub-vnet'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: hubVnetId
    }
  }
}

resource cosmosDbDnsHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: cosmosDbDnsZone
  name: '${projectName}-hub-dns-cosmosdb-link-hub-vnet'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: hubVnetId
    }
  }
}

resource fileDnsHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: fileDnsZone
  name: '${projectName}-hub-dns-file-link-hub-vnet'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: hubVnetId
    }
  }
}

resource queueDnsHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: queueDnsZone
  name: '${projectName}-hub-dns-queue-link-hub-vnet'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: hubVnetId
    }
  }
}

resource tableDnsHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: tableDnsZone
  name: '${projectName}-hub-dns-table-link-hub-vnet'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: hubVnetId
    }
  }
}

resource webDnsHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (deployAppService) {
  parent: webDnsZone
  name: '${projectName}-hub-dns-web-link-hub-vnet'
  location: 'global'
  tags: commonTags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: hubVnetId
    }
  }
}

// ============================================
// OUTPUTS
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
    spokeLinkId: ''
    spoke2LinkId: ''
  }
  {
    dnsZoneName: keyVaultDnsZone.name
    dnsZoneId: keyVaultDnsZone.id
    placement: 'hub-vnet'
    hubVnetId: hubVnetId
    hubLinkId: keyVaultDnsHubLink.id
    spokeLinkId: ''
    spoke2LinkId: ''
  }
  {
    dnsZoneName: sqlDnsZone.name
    dnsZoneId: sqlDnsZone.id
    placement: 'hub-vnet'
    hubVnetId: hubVnetId
    hubLinkId: sqlDnsHubLink.id
    spokeLinkId: ''
    spoke2LinkId: ''
  }
], deployAppService ? [
  {
    dnsZoneName: appServiceDnsZone.name
    dnsZoneId: appServiceDnsZone.id
    placement: 'hub-vnet'
    hubVnetId: hubVnetId
    hubLinkId: appServiceDnsHubLink!.id
    spokeLinkId: ''
    spoke2LinkId: ''
  }
] : [], [
  {
    dnsZoneName: cosmosDbDnsZone.name
    dnsZoneId: cosmosDbDnsZone.id
    placement: 'hub-vnet'
    hubVnetId: hubVnetId
    hubLinkId: cosmosDbDnsHubLink.id
    spokeLinkId: ''
    spoke2LinkId: ''
  }
])
