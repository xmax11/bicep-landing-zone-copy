/*
  Security Module - Key Vault
  
  Naming Convention: {projectName}-spoke-kv
  - Key Vault is accessed via Private Endpoints in Spoke VNet
  - Includes 'spoke' to indicate deployment in Spoke network
  - Environment managed through tags, not naming
  
  Note: Private DNS Zones are now centralized in the Hub (private-dns-zones module)
  and are no longer created here.
*/

param location string
param keyVaultName string
param projectName string
param environment string
param logAnalyticsWorkspaceId string = ''
param hubVnetId string
param spokeVnetId string

// Common tags (environment in tags, not names)
var commonTags = {
  environment: environment
  project: projectName
}

// Key Vault - RBAC enabled, deployer needs Key Vault Contributor role
// Naming: {projectName}-spoke-kv (Key Vault accessed via Private Endpoint in Spoke)
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: keyVaultName
  location: location
  tags: commonTags
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    accessPolicies: []
    enabledForDeployment: true
    enabledForDiskEncryption: true
    enabledForTemplateDeployment: true
    enablePurgeProtection: true
    enableRbacAuthorization: true
    softDeleteRetentionInDays: 7
  }
}

// Diagnostic settings for Key Vault
resource keyVaultDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if(logAnalyticsWorkspaceId != '') {
  name: '${projectName}-spoke-kv-diag'
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
