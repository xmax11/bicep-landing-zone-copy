/*
  Private Endpoints Module - Creates private endpoints for Storage, Key Vault, SQL, Cosmos DB, and App Service
  
  Naming Convention: {projectName}-spoke-pe-{service}
  - Includes 'spoke' to indicate deployment in Spoke VNet
  - Includes target service name (storage, keyvault, sql, cosmosdb, appservice)
  - Environment managed through tags, not naming
  
  Note: SQL, Cosmos DB, and App Service private endpoints are conditional - they only deploy if valid resource IDs are provided
*/

param location string
param projectName string
param environment string

// Resource IDs for existing endpoints
param storageAccountId string
param keyVaultId string
param sqlServerId string = ''
param cosmosDbAccountId string = ''
param appServiceId string = ''

// Subnet ID for private endpoints
param paasSubnetId string

// DNS Zone IDs
param storagePrivateDnsZoneId string
param keyVaultPrivateDnsZoneId string
param sqlPrivateDnsZoneId string = ''
param appServicePrivateDnsZoneId string = ''
param cosmosDbPrivateDnsZoneId string = ''

// Common tags (environment in tags, not names)
var commonTags = {
  environment: environment
  project: projectName
}

// Check if SQL/CosmosDB/AppService IDs are provided
var sqlEnabled = !empty(sqlServerId)
var cosmosEnabled = !empty(cosmosDbAccountId)
var appServiceEnabled = !empty(appServiceId)

// ====== Storage Account Private Endpoint ======
// Naming: {projectName}-spoke-pe-storage
resource storagePrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-02-01' = {
  name: '${projectName}-spoke-pe-storage'
  location: location
  tags: commonTags
  properties: {
    subnet: {
      id: paasSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'storage-connection'
        properties: {
          privateLinkServiceId: storageAccountId
          groupIds: [ 'blob' ]
        }
      }
    ]
  }
}

// DNS Zone Group for Storage
resource storageDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-02-01' = {
  name: 'spoke-storage-dns-group'
  parent: storagePrivateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'storage-dns-config'
        properties: {
          privateDnsZoneId: storagePrivateDnsZoneId
        }
      }
    ]
  }
}

// ====== Key Vault Private Endpoint ======
// Naming: {projectName}-spoke-pe-keyvault
resource keyVaultPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-02-01' = {
  name: '${projectName}-spoke-pe-keyvault'
  location: location
  tags: commonTags
  properties: {
    subnet: {
      id: paasSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'keyvault-connection'
        properties: {
          privateLinkServiceId: keyVaultId
          groupIds: [ 'vault' ]
        }
      }
    ]
  }
}

// DNS Zone Group for Key Vault
resource keyVaultDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-02-01' = {
  name: 'spoke-keyvault-dns-group'
  parent: keyVaultPrivateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'keyvault-dns-config'
        properties: {
          privateDnsZoneId: keyVaultPrivateDnsZoneId
        }
      }
    ]
  }
}

// ====== SQL Server Private Endpoint (Conditional) ======
// Naming: {projectName}-spoke-pe-sql
resource sqlPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-02-01' = if(sqlEnabled) {
  name: '${projectName}-spoke-pe-sql'
  location: location
  tags: commonTags
  properties: {
    subnet: {
      id: paasSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'sql-connection'
        properties: {
          privateLinkServiceId: sqlServerId
          groupIds: [ 'sqlServer' ]
        }
      }
    ]
  }
}

// DNS Zone Group for SQL
resource sqlDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-02-01' = if(sqlEnabled) {
  name: 'spoke-sql-dns-group'
  parent: sqlPrivateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'sql-dns-config'
        properties: {
          privateDnsZoneId: sqlPrivateDnsZoneId
        }
      }
    ]
  }
}

// ====== Cosmos DB Private Endpoint (Conditional) ======
// Naming: {projectName}-spoke-pe-cosmosdb
resource cosmosDbPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-02-01' = if(cosmosEnabled) {
  name: '${projectName}-spoke-pe-cosmosdb'
  location: location
  tags: commonTags
  properties: {
    subnet: {
      id: paasSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'cosmosdb-connection'
        properties: {
          privateLinkServiceId: cosmosDbAccountId
          groupIds: [ 'Sql' ]
        }
      }
    ]
  }
}

// DNS Zone Group for Cosmos DB
resource cosmosDbDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-02-01' = if(cosmosEnabled) {
  name: 'spoke-cosmosdb-dns-group'
  parent: cosmosDbPrivateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'cosmosdb-dns-config'
        properties: {
          privateDnsZoneId: cosmosDbPrivateDnsZoneId
        }
      }
    ]
  }
}

// ====== App Service Private Endpoint (Conditional) ======
// Naming: {projectName}-spoke-pe-appservice
resource appServicePrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-02-01' = if(appServiceEnabled) {
  name: '${projectName}-spoke-pe-appservice'
  location: location
  tags: commonTags
  properties: {
    subnet: {
      id: paasSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'appservice-connection'
        properties: {
          privateLinkServiceId: appServiceId
          groupIds: [ 'sites' ]
        }
      }
    ]
  }
}

// DNS Zone Group for App Service
resource appServiceDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-02-01' = if(appServiceEnabled) {
  name: 'spoke-appservice-dns-group'
  parent: appServicePrivateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'appservice-dns-config'
        properties: {
          privateDnsZoneId: appServicePrivateDnsZoneId
        }
      }
    ]
  }
}

// ====== Outputs ======
output storagePrivateEndpointId string = storagePrivateEndpoint.id
output keyVaultPrivateEndpointId string = keyVaultPrivateEndpoint.id
output sqlPrivateEndpointId string = sqlEnabled ? sqlPrivateEndpoint.id : ''
output cosmosDbPrivateEndpointId string = cosmosEnabled ? cosmosDbPrivateEndpoint.id : ''
output appServicePrivateEndpointId string = appServiceEnabled ? appServicePrivateEndpoint.id : ''
