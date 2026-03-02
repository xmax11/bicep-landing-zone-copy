/*
  Policies Module - Custom Azure Policy Definitions and Initiative
  Target Scope: subscription
*/

targetScope = 'subscription'

param location string
param projectName string
param tagName string = 'environment'

// 1. Policy: Enforce TLS 1.2
resource tlsPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: '${projectName}-enforce-tls-12'
  properties: {
    displayName: 'Enforce TLS 1.2 for Storage Accounts'
    policyType: 'Custom'
    mode: 'Indexed' // Use Indexed for resource-specific properties
    policyRule: {
      if: {
        allOf: [
          { field: 'type', equals: 'Microsoft.Storage/storageAccounts' }
          { field: 'Microsoft.Storage/storageAccounts/minimumTlsVersion', notEquals: 'TLS1_2' }
        ]
      }
      then: { effect: 'Deny' }
    }
  }
}

// 2. Policy: Enforce HTTPS (FIXED ALIAS)
resource httpsPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: '${projectName}-enforce-https'
  properties: {
    displayName: 'Enforce HTTPS only for Storage Accounts'
    policyType: 'Custom'
    mode: 'Indexed'
    policyRule: {
      if: {
        allOf: [
          { field: 'type', equals: 'Microsoft.Storage/storageAccounts' }
          // Fixed the alias path here
          { field: 'Microsoft.Storage/storageAccounts/supportsHttpsTrafficOnly', notEquals: 'true' }
        ]
      }
      then: { effect: 'Deny' }
    }
  }
}

// 3. Policy: Audit Key Vault
resource kvEncryptionPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: '${projectName}-audit-kv-encryption'
  properties: {
    displayName: 'Audit Key Vault Encryption'
    policyType: 'Custom'
    mode: 'Indexed'
    policyRule: {
      if: { allOf: [ { field: 'type', equals: 'Microsoft.KeyVault/vaults' } ] }
      then: { effect: 'Audit' }
    }
  }
}

// 4. Policy: Require resource tags (v2)
resource tagPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: '${projectName}-require-tags-v2' 
  properties: {
    displayName: 'Require resource tags'
    policyType: 'Custom'
    mode: 'All' // Mode 'All' is required for tag checks
    policyRule: {
      if: {
        field: 'tags[\'${tagName}\']'
        exists: false
      }
      then: {
        effect: 'Deny'
      }
    }
  }
}

// 5. Policy Initiative
resource baselineInitiative 'Microsoft.Authorization/policySetDefinitions@2021-06-01' = {
  name: '${projectName}-baseline-initiative-v2'
  properties: {
    displayName: '${projectName} Baseline Policy Initiative'
    policyType: 'Custom'
    policyDefinitions: [
      { policyDefinitionId: tlsPolicy.id }
      { policyDefinitionId: httpsPolicy.id }
      { policyDefinitionId: kvEncryptionPolicy.id }
      { policyDefinitionId: tagPolicy.id }
    ]
  }
}

// 6. Policy Assignment
resource baselineAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: take('${projectName}-asgn-v2', 24)
  location: location
  properties: {
    displayName: '${projectName} Baseline Assignment'
    policyDefinitionId: baselineInitiative.id
  }
  identity: { type: 'SystemAssigned' }
}

output policyInitiativeId string = baselineInitiative.id
output policyAssignmentId string = baselineAssignment.id
