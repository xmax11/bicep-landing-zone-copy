/*
  Security Module - Key Vault and Private DNS Zones
*/

param location string
param keyVaultName string
param projectName string
param environment string
param deployPrivateDns bool = true
param logAnalyticsWorkspaceId string = ''
param hubVnetId string
param spokeVnetId string
param keyVaultAccessObjectId string

// Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: keyVaultName
  location: location
  tags: {
    environment: environment
    project: projectName
  }
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: keyVaultAccessObjectId
        permissions: {
          keys: [
            'get'
            'list'
            'create'
            'update'
          ]
          secrets: [
            'get'
            'list'
            'set'
            'delete'
          ]
          certificates: [
            'get'
            'list'
            'create'
            'update'
          ]
        }
      }
    ]
    enabledForDeployment: true
    enabledForDiskEncryption: true
    enabledForTemplateDeployment: true
    enablePurgeProtection: true
    enableRbacAuthorization: false
    softDeleteRetentionInDays: 7
  }
}

// Private DNS Zones
resource storagePrivateDns 'Microsoft.Network/privateDnsZones@2020-06-01' = if(deployPrivateDns) {
  name: 'privatelink.blob.core.windows.net'
  location: 'global'
  tags: {
    environment: environment
    project: projectName
  }
}

resource keyVaultPrivateDns 'Microsoft.Network/privateDnsZones@2020-06-01' = if(deployPrivateDns) {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'
  tags: {
    environment: environment
    project: projectName
  }
}

resource sqlPrivateDns 'Microsoft.Network/privateDnsZones@2020-06-01' = if(deployPrivateDns) {
  name: 'privatelink.database.windows.net'
  location: 'global'
  tags: {
    environment: environment
    project: projectName
  }
}

resource appServicePrivateDns 'Microsoft.Network/privateDnsZones@2020-06-01' = if(deployPrivateDns) {
  name: 'privatelink.azurewebsites.net'
  location: 'global'
  tags: {
    environment: environment
    project: projectName
  }
}

resource cosmosDbPrivateDns 'Microsoft.Network/privateDnsZones@2020-06-01' = if(deployPrivateDns) {
  name: 'privatelink.documents.azure.com'
  location: 'global'
  tags: {
    environment: environment
    project: projectName
  }
}

// VNet links for Storage DNS zone
resource storagePrivateDnsHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if(deployPrivateDns) {
  parent: storagePrivateDns
  name: '${projectName}-storage-hub-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: hubVnetId }
  }
}

resource storagePrivateDnsSpokeLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if(deployPrivateDns) {
  parent: storagePrivateDns
  name: '${projectName}-storage-spoke-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: spokeVnetId }
  }
}

// VNet links for Key Vault DNS zone
resource keyVaultPrivateDnsHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if(deployPrivateDns) {
  parent: keyVaultPrivateDns
  name: '${projectName}-keyvault-hub-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: hubVnetId }
  }
}

resource keyVaultPrivateDnsSpokeLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if(deployPrivateDns) {
  parent: keyVaultPrivateDns
  name: '${projectName}-keyvault-spoke-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: spokeVnetId }
  }
}

// VNet links for SQL DNS zone
resource sqlPrivateDnsHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if(deployPrivateDns) {
  parent: sqlPrivateDns
  name: '${projectName}-sql-hub-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: hubVnetId }
  }
}

resource sqlPrivateDnsSpokeLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if(deployPrivateDns) {
  parent: sqlPrivateDns
  name: '${projectName}-sql-spoke-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: spokeVnetId }
  }
}

// VNet links for App Service DNS zone
resource appServicePrivateDnsHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if(deployPrivateDns) {
  parent: appServicePrivateDns
  name: '${projectName}-appservice-hub-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: hubVnetId }
  }
}

resource appServicePrivateDnsSpokeLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if(deployPrivateDns) {
  parent: appServicePrivateDns
  name: '${projectName}-appservice-spoke-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: spokeVnetId }
  }
}

// VNet links for Cosmos DB DNS zone
resource cosmosDbPrivateDnsHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if(deployPrivateDns) {
  parent: cosmosDbPrivateDns
  name: '${projectName}-cosmosdb-hub-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: hubVnetId }
  }
}

resource cosmosDbPrivateDnsSpokeLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if(deployPrivateDns) {
  parent: cosmosDbPrivateDns
  name: '${projectName}-cosmosdb-spoke-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: spokeVnetId }
  }
}

// Diagnostic settings for Key Vault
resource keyVaultDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if(logAnalyticsWorkspaceId != '') {
  name: '${projectName}-kv-diag'
  scope: keyVault
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'AuditEvent'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// Outputs
output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
output storagePrivateDnsZoneId string = deployPrivateDns ? storagePrivateDns.id : ''
output keyVaultPrivateDnsZoneId string = deployPrivateDns ? keyVaultPrivateDns.id : ''
output sqlPrivateDnsZoneId string = deployPrivateDns ? sqlPrivateDns.id : ''
output appServicePrivateDnsZoneId string = deployPrivateDns ? appServicePrivateDns.id : ''
output cosmosDbPrivateDnsZoneId string = deployPrivateDns ? cosmosDbPrivateDns.id : ''
