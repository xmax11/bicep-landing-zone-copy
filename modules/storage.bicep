/*
  Storage Module - Storage Account
  
  Naming Convention: {projectName}-spoke-st
  - Storage Account is accessed via Private Endpoints in Spoke VNet
  - Includes 'spoke' to indicate deployment in Spoke network
  - Environment managed through tags, not naming
  
  Deploys:
  - Storage Account (LRS)
  - Blob Container
*/

param location string
param storageAccountName string
param projectName string
param environment string
param logAnalyticsWorkspaceId string = ''

// Common tags (environment in tags, not names)
var commonTags = {
  environment: environment
  project: projectName
}

// Storage Account
// Naming: {projectName}-spoke-st
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: commonTags
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
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
// Naming: {projectName}-spoke-st-diag
resource storageDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if(logAnalyticsWorkspaceId != '') {
  name: '${projectName}-spoke-st-diag'
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
