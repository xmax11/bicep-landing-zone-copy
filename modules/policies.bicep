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
    mode: 'All'
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

// 2. Policy: Enforce HTTPS
resource httpsPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: '${projectName}-enforce-https'
  properties: {
    displayName: 'Enforce HTTPS only for Storage Accounts'
    policyType: 'Custom'
    mode: 'All'
    policyRule: {
      if: {
        allOf: [
          { field: 'type', equals: 'Microsoft.Storage/storageAccounts' }
          { field: 'Microsoft.Storage/supportsHttpsTrafficOnly', notEquals: 'true' }
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
    mode: 'All'
    policyRule: {
      if: { allOf: [ { field: 'type', equals: 'Microsoft.KeyVault/vaults' } ] }
      then: { effect: 'Audit' }
    }
  }
}

// 4. Policy: Require resource tags (FIXED: No parameters = No error)
// RENAMED to -v2 to force a fresh deployment
resource tagPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: '${projectName}-require-tags-v2' 
  properties: {
    displayName: 'Require resource tags'
    policyType: 'Custom'
    mode: 'All'
    // We removed the 'parameters' block entirely
    policyRule: {
      if: {
        // We inject the tag name directly into the rule
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
  name: '${projectName}-baseline-initiative-v2' // Renamed for fresh deployment
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
