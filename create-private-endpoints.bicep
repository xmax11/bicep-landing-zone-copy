/*
  Private Endpoints for SQL, Cosmos DB, and App Service
  Fully dynamic - all values come from parameters
  
  Deployment:
  az deployment group create \
    --resource-group <rg-name> \
    --template-file create-private-endpoints.bicep \
    --parameters @parameters.json
*/

targetScope = 'resourceGroup'

// ====== CORE PARAMETERS ======
@description('Azure region')
param location string

@description('Project name for naming conventions')
param projectName string

@description('Environment (production, staging, development)')
param environment string = 'production'

// ====== SUBSCRIPTION & RESOURCE GROUP ======
@description('Azure subscription ID')
param subscriptionId string

@description('Resource group name where VNets and DNS zones exist')
param vnetResourceGroupName string

// ====== VNET CONFIGURATION ======
@description('Spoke VNet name')
param spokeVnetName string

@description('Subnet name for private endpoints')
param paasSubnetName string = 'PaaSSvcSubnet'

// ====== EXISTING RESOURCE IDS ======
@description('Existing SQL Server resource ID (full resource ID)')
param sqlServerResourceId string = ''

@description('Existing Cosmos DB Account resource ID (full resource ID)')
param cosmosDbResourceId string = ''

@description('Existing App Service resource ID (full resource ID)')
param appServiceResourceId string = ''

@description('Existing Key Vault resource ID (full resource ID)')
param keyVaultResourceId string = ''

@description('Existing Storage Account resource ID (full resource ID)')
param storageAccountResourceId string = ''

// Common tags
var commonTags = {
  environment: environment
  project: projectName
}

// Check which services to deploy
var deploySql = !empty(sqlServerResourceId)
var deployCosmos = !empty(cosmosDbResourceId)
var deployAppService = !empty(appServiceResourceId)
var deployKeyVault = !empty(keyVaultResourceId)
var deployStorage = !empty(storageAccountResourceId)

// ====== EXISTING VNET REFERENCES ======
resource spokeVnet 'Microsoft.Network/virtualNetworks@2023-02-01' existing = {
  name: spokeVnetName
  scope: resourceGroup(subscriptionId, vnetResourceGroupName)
}

// ====== EXISTING DNS ZONES ======
resource sqlDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = if(deploySql) {
  name: 'privatelink.database.windows.net'
  scope: resourceGroup(subscriptionId, vnetResourceGroupName)
}

resource cosmosDbDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = if(deployCosmos) {
  name: 'privatelink.documents.azure.com'
  scope: resourceGroup(subscriptionId, vnetResourceGroupName)
}

resource appServiceDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = if(deployAppService) {
  name: 'privatelink.azurewebsites.net'
  scope: resourceGroup(subscriptionId, vnetResourceGroupName)
}

resource keyVaultDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = if(deployKeyVault) {
  name: 'privatelink.vaultcore.azure.net'
  scope: resourceGroup(subscriptionId, vnetResourceGroupName)
}

resource storageDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = if(deployStorage) {
  name: 'privatelink.blob.core.windows.net'
  scope: resourceGroup(subscriptionId, vnetResourceGroupName)
}

// ====== KEY VAULT PRIVATE ENDPOINT ======
resource keyVaultPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-02-01' = if(deployKeyVault) {
  name: '${projectName}-kv-pe'
  location: location
  tags: commonTags
  properties: {
    subnet: {
      id: '${spokeVnet.id}/subnets/${paasSubnetName}'
    }
    privateLinkServiceConnections: [
      {
        name: 'keyvault-private-link'
        properties: {
          privateLinkServiceId: keyVaultResourceId
          groupIds: [ 'vault' ]
          privateLinkServiceConnectionState: {
            status: 'Approved'
            description: 'Auto-approved'
          }
        }
      }
    ]
  }
}

resource keyVaultDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-02-01' = if(deployKeyVault) {
  parent: keyVaultPrivateEndpoint
  name: 'keyvault-dns-group'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'keyvault-dns-config'
        properties: {
          privateDnsZoneId: keyVaultDnsZone.id
        }
      }
    ]
  }
}

// ====== STORAGE PRIVATE ENDPOINT ======
resource storagePrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-02-01' = if(deployStorage) {
  name: '${projectName}-st-pe'
  location: location
  tags: commonTags
  properties: {
    subnet: {
      id: '${spokeVnet.id}/subnets/${paasSubnetName}'
    }
    privateLinkServiceConnections: [
      {
        name: 'storage-private-link'
        properties: {
          privateLinkServiceId: storageAccountResourceId
          groupIds: [ 'blob' ]
          privateLinkServiceConnectionState: {
            status: 'Approved'
            description: 'Auto-approved'
          }
        }
      }
    ]
  }
}

resource storageDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-02-01' = if(deployStorage) {
  parent: storagePrivateEndpoint
  name: 'storage-dns-group'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'storage-dns-config'
        properties: {
          privateDnsZoneId: storageDnsZone.id
        }
      }
    ]
  }
}

// ====== SQL PRIVATE ENDPOINT ======
resource sqlPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-02-01' = if(deploySql) {
  name: '${projectName}-sql-pe'
  location: location
  tags: commonTags
  properties: {
    subnet: {
      id: '${spokeVnet.id}/subnets/${paasSubnetName}'
    }
    privateLinkServiceConnections: [
      {
        name: 'sql-private-link'
        properties: {
          privateLinkServiceId: sqlServerResourceId
          groupIds: [ 'sqlServer' ]
          privateLinkServiceConnectionState: {
            status: 'Approved'
            description: 'Auto-approved'
          }
        }
      }
    ]
  }
}

resource sqlDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-02-01' = if(deploySql) {
  parent: sqlPrivateEndpoint
  name: 'sql-dns-group'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'sql-dns-config'
        properties: {
          privateDnsZoneId: sqlDnsZone.id
        }
      }
    ]
  }
}

// ====== COSMOS DB PRIVATE ENDPOINT ======
resource cosmosDbPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-02-01' = if(deployCosmos) {
  name: '${projectName}-cosmosdb-pe'
  location: location
  tags: commonTags
  properties: {
    subnet: {
      id: '${spokeVnet.id}/subnets/${paasSubnetName}'
    }
    privateLinkServiceConnections: [
      {
        name: 'cosmosdb-private-link'
        properties: {
          privateLinkServiceId: cosmosDbResourceId
          groupIds: [ 'Sql' ]
          privateLinkServiceConnectionState: {
            status: 'Approved'
            description: 'Auto-approved'
          }
        }
      }
    ]
  }
}

resource cosmosDbDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-02-01' = if(deployCosmos) {
  parent: cosmosDbPrivateEndpoint
  name: 'cosmosdb-dns-group'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'cosmosdb-dns-config'
        properties: {
          privateDnsZoneId: cosmosDbDnsZone.id
        }
      }
    ]
  }
}

// ====== APP SERVICE PRIVATE ENDPOINT ======
resource appServicePrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-02-01' = if(deployAppService) {
  name: '${projectName}-appservice-pe'
  location: location
  tags: commonTags
  properties: {
    subnet: {
      id: '${spokeVnet.id}/subnets/${paasSubnetName}'
    }
    privateLinkServiceConnections: [
      {
        name: 'appservice-private-link'
        properties: {
          privateLinkServiceId: appServiceResourceId
          groupIds: [ 'sites' ]
          privateLinkServiceConnectionState: {
            status: 'Approved'
            description: 'Auto-approved'
          }
        }
      }
    ]
  }
}

resource appServiceDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-02-01' = if(deployAppService) {
  parent: appServicePrivateEndpoint
  name: 'appservice-dns-group'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'appservice-dns-config'
        properties: {
          privateDnsZoneId: appServiceDnsZone.id
        }
      }
    ]
  }
}

// ====== OUTPUTS ======
output keyVaultPrivateEndpointId string = deployKeyVault ? keyVaultPrivateEndpoint.id : ''
output storagePrivateEndpointId string = deployStorage ? storagePrivateEndpoint.id : ''
output sqlPrivateEndpointId string = deploySql ? sqlPrivateEndpoint.id : ''
output cosmosDbPrivateEndpointId string = deployCosmos ? cosmosDbPrivateEndpoint.id : ''
output appServicePrivateEndpointId string = deployAppService ? appServicePrivateEndpoint.id : ''
output vnetId string = spokeVnet.id

output privateEndpointsSummary array = filter([
  ...(deployKeyVault ? [{
    serviceName: 'Key Vault'
    privateEndpointName: keyVaultPrivateEndpoint.name
    privateEndpointId: keyVaultPrivateEndpoint.id
    linkedResourceId: keyVaultResourceId
    dnsZoneName: 'privatelink.vaultcore.azure.net'
    subnetId: '${spokeVnet.id}/subnets/${paasSubnetName}'
  }] : [])
  ...(deployStorage ? [{
    serviceName: 'Storage'
    privateEndpointName: storagePrivateEndpoint.name
    privateEndpointId: storagePrivateEndpoint.id
    linkedResourceId: storageAccountResourceId
    dnsZoneName: 'privatelink.blob.core.windows.net'
    subnetId: '${spokeVnet.id}/subnets/${paasSubnetName}'
  }] : [])
  ...(deploySql ? [{
    serviceName: 'Azure SQL'
    privateEndpointName: sqlPrivateEndpoint.name
    privateEndpointId: sqlPrivateEndpoint.id
    linkedResourceId: sqlServerResourceId
    dnsZoneName: 'privatelink.database.windows.net'
    subnetId: '${spokeVnet.id}/subnets/${paasSubnetName}'
  }] : [])
  ...(deployCosmos ? [{
    serviceName: 'Azure Cosmos DB'
    privateEndpointName: cosmosDbPrivateEndpoint.name
    privateEndpointId: cosmosDbPrivateEndpoint.id
    linkedResourceId: cosmosDbResourceId
    dnsZoneName: 'privatelink.documents.azure.com'
    subnetId: '${spokeVnet.id}/subnets/${paasSubnetName}'
  }] : [])
  ...(deployAppService ? [{
    serviceName: 'Azure App Service'
    privateEndpointName: appServicePrivateEndpoint.name
    privateEndpointId: appServicePrivateEndpoint.id
    linkedResourceId: appServiceResourceId
    dnsZoneName: 'privatelink.azurewebsites.net'
    subnetId: '${spokeVnet.id}/subnets/${paasSubnetName}'
  }] : [])
], item => item.privateEndpointId != '')
