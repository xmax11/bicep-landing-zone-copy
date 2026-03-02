/*
  Policies Module - Custom Azure Policy Definitions and Initiative
  Target Scope: subscription
*/

targetScope = 'subscription'

param location string
param projectName string
param tagName string = 'environment'

// Policy: Enforce TLS 1.2 for Storage Accounts
resource tlsPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: '${projectName}-enforce-tls-12'
  properties: {
    displayName: 'Enforce TLS 1.2 for Storage Accounts'
    description: 'Ensures all storage accounts use TLS 1.2 or higher'
    policyType: 'Custom'
    mode: 'All'
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type'
            equals: 'Microsoft.Storage/storageAccounts'
          }
          {
            field: 'Microsoft.Storage/storageAccounts/minimumTlsVersion'
            notEquals: 'TLS1_2'
          }
        ]
      }
      then: {
        effect: 'Deny'
      }
    }
  }
}

// Policy: Enforce HTTPS only for Storage Accounts
resource httpsPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: '${projectName}-enforce-https'
  properties: {
    displayName: 'Enforce HTTPS only for Storage Accounts'
    description: 'Ensures all storage accounts enforce HTTPS only'
    policyType: 'Custom'
    mode: 'All'
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type'
            equals: 'Microsoft.Storage/storageAccounts'
          }
          {
            field: 'Microsoft.Storage/storageAccounts/supportsHttpsTrafficOnly'
            notEquals: 'true'
          }
        ]
      }
      then: {
        effect: 'Deny'
      }
    }
  }
}

// Policy: Audit Key Vault Encryption
resource kvEncryptionPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: '${projectName}-audit-kv-encryption'
  properties: {
    displayName: 'Audit Key Vault Encryption'
    description: 'Ensures Key Vaults have encryption enabled'
    policyType: 'Custom'
    mode: 'All'
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type'
            equals: 'Microsoft.KeyVault/vaults'
          }
        ]
      }
      then: {
        effect: 'Audit'
      }
    }
  }
}

// Policy: Require resource tags – CORRECTED with boolean exists
// Policy: Require resource tags – CORRECTED
resource tagPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: '${projectName}-require-tags'
  properties: {
    displayName: 'Require resource tags'
    description: 'Ensures all resources have required tags'
    policyType: 'Custom'
    mode: 'All'
    metadata: { category: 'Tags' }
    parameters: {
      tagName: {
        type: 'String'
        metadata: { description: 'Name of the tag', displayName: 'Tag Name' }
        defaultValue: tagName
      }
    }
    policyRule: {
      if: {
        // Use single quotes and escape the inner single quotes with \
        field: 'tags[parameters(\'tagName\')]' 
        exists: false
      }
      then: {
        effect: 'Deny'
      }
    }
  }
}
// Policy Initiative (Set)
resource baselineInitiative 'Microsoft.Authorization/policySetDefinitions@2021-06-01' = {
  name: '${projectName}-baseline-initiative'
  properties: {
    displayName: '${projectName} Baseline Policy Initiative'
    description: 'Baseline policies for landing zone'
    policyType: 'Custom'
    policyDefinitions: [
      {
        policyDefinitionId: tlsPolicy.id
      }
      {
        policyDefinitionId: httpsPolicy.id
      }
      {
        policyDefinitionId: kvEncryptionPolicy.id
      }
      {
        policyDefinitionId: tagPolicy.id
      }
    ]
  }
}

// Policy Assignment (at subscription scope)
resource baselineAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: '${projectName}-baseline-assignment'
  location: location
  properties: {
    displayName: '${projectName} Baseline Policy Assignment'
    description: 'Assignment of baseline policy initiative'
    policyDefinitionId: baselineInitiative.id
  }
  identity: {
    type: 'SystemAssigned'
  }
}

output policyInitiativeId string = baselineInitiative.id
output policyAssignmentId string = baselineAssignment.id
