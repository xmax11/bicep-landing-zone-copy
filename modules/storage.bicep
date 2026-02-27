/*
  Storage Module - Storage Account
  Deploys:
  - Storage Account (LRS)
  - Blob Container
*/

param location string
param storageAccountName string
param projectName string
param environment string
param logAnalyticsWorkspaceId string = ''

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: {
    environment: environment
    project: projectName
  }
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'  // Locally Redundant Storage as per requirement
  }
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      virtualNetworkRules: []
      ipRules: []
    }
    supportsHttpsTrafficOnly: true
  }
}

// Create blob service
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  name: 'default'
  parent: storageAccount
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

// Create container
resource landingZoneContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: 'landing-zone'
  parent: blobService
  properties: {
    publicAccess: 'None'
  }
}

// Create diagnostics container
resource diagnosticsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: 'diagnostics'
  parent: blobService
  properties: {
    publicAccess: 'None'
  }
}

// Diagnostic settings
resource storageDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if(logAnalyticsWorkspaceId != '') {
  name: '${projectName}-st-diag'
  scope: blobService
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'StorageRead'
        enabled: true
      }
      {
        category: 'StorageWrite'
        enabled: true
      }
      {
        category: 'StorageDelete'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'Transaction'
        enabled: true
      }
    ]
  }
}

// Outputs
output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
output containerName string = landingZoneContainer.name
output primaryBlobEndpoint string = storageAccount.properties.primaryEndpoints.blob
