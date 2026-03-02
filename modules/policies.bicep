/*
  Policies Module - Custom Azure Policy Definitions and Initiative
  Target Scope: subscription
*/

targetScope = 'subscription'

param location string
param projectName string
param tagName string = 'environment'

// 1. Policy: Enforce TLS 1.2 for Storage Accounts
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

// 2. Policy: Enforce HTTPS only for Storage Accounts
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

// 3. Policy: Audit Key Vault Encryption
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

// 4. Policy: Require resource tags (FIXED QUOTES AND ESCAPING)
// Policy: Require resource tags
resource tagPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: '${projectName}-require-tags'
  properties: {
    displayName: 'Require resource tags'
    policyType: 'Custom'
    mode: 'All'
    parameters: {
      tagName: { // <--- This name must match exactly below
        type: 'String'
        defaultValue: tagName
      }
    }
    policyRule: {
      if: {
        field: 'tags[parameters(\'tagName\')]'
        exists: false
      }
      then: {
        effect: 'Deny'
      }
    }
  }
}

// 5. Policy Initiative (Set)

resource baselineInitiative 'Microsoft.Authorization/policySetDefinitions@2021-06-01' = {
  name: '${projectName}-baseline-initiative'
  properties: {
    displayName: '${projectName} Baseline Policy Initiative'
    description: 'Baseline policies for landing zone'
    policyType: 'Custom'
    // 1. You must declare the parameter at the Initiative level
    parameters: {
      tagName: {
        type: 'String'
        defaultValue: tagName
      }
    }
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
        // 2. You must MAP the Initiative's parameter to the Definition's parameter
        parameters: {
          tagName: {
            value: '[parameters(\'tagName\')]'
          }
        }
      }
    ]
  }
}

// Policy Assignment (at subscription scope)
resource baselineAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: take('${projectName}-baseline-asgn', 24) // Kept short to avoid 64-char limit
  location: location
  properties: {
    displayName: '${projectName} Baseline Policy Assignment'
    description: 'Assignment of baseline policy initiative'
    policyDefinitionId: baselineInitiative.id
    // 3. Finally, provide the value during the assignment
    parameters: {
      tagName: {
        value: tagName
      }
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

output policyInitiativeId string = baselineInitiative.id
output policyAssignmentId string = baselineAssignment.id
