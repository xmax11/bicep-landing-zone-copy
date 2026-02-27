/*
  Private Endpoints Module - Creates private endpoints for Storage and Key Vault
*/

param location string
param projectName string
param environment string
param storageAccountId string
param keyVaultId string
param hubVnetId string
param paasSubnetId string
param storagePrivateDnsZoneId string
param keyVaultPrivateDnsZoneId string

// Storage Account Private Endpoint
resource storagePrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-02-01' = {
  name: '${projectName}-st-pe'
  location: location
  tags: {
    environment: environment
    project: projectName
  }
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
  name: 'storage-dns-zone-group'
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

// Key Vault Private Endpoint
resource keyVaultPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-02-01' = {
  name: '${projectName}-kv-pe'
  location: location
  tags: {
    environment: environment
    project: projectName
  }
  properties: {
    subnet: {
      id: paasSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'kv-connection'
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
  name: 'kv-dns-zone-group'
  parent: keyVaultPrivateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'kv-dns-config'
        properties: {
          privateDnsZoneId: keyVaultPrivateDnsZoneId
        }
      }
    ]
  }
}

output storagePrivateEndpointId string = storagePrivateEndpoint.id
output keyVaultPrivateEndpointId string = keyVaultPrivateEndpoint.id
