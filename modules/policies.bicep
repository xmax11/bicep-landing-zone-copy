targetScope = 'subscription'

param location string
param projectName string
param tagName string = 'environment'

// 1. TLS Policy
resource tlsPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: '${projectName}-enforce-tls-12'
  properties: {
    displayName: 'Enforce TLS 1.2'
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

// 2. HTTPS Policy
resource httpsPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: '${projectName}-enforce-https'
  properties: {
    displayName: 'Enforce HTTPS'
    policyType: 'Custom'
    mode: 'All'
    policyRule: {
      if: {
        allOf: [
          { field: 'type', equals: 'Microsoft.Storage/storageAccounts' }
          { field: 'Microsoft.Storage/storageAccounts/supportsHttpsTrafficOnly', notEquals: 'true' }
        ]
      }
      then: { effect: 'Deny' }
    }
  }
}

// 3. KV Audit Policy
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

// 4. Tag Policy (Unique Parameter Name: def_tagName)
resource tagPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: '${projectName}-require-tags'
  properties: {
    displayName: 'Require resource tags'
    policyType: 'Custom'
    mode: 'All'
    parameters: {
      def_tagName: {
        type: 'String'
        defaultValue: tagName
      }
    }
    policyRule: {
      if: {
        field: 'tags[parameters(\'def_tagName\')]'
        exists: false
      }
      then: { effect: 'Deny' }
    }
  }
}

// 5. Initiative (Unique Parameter Name: set_tagName)
resource baselineInitiative 'Microsoft.Authorization/policySetDefinitions@2021-06-01' = {
  name: '${projectName}-baseline-initiative'
  properties: {
    displayName: '${projectName} Baseline Initiative'
    policyType: 'Custom'
    parameters: {
      set_tagName: {
        type: 'String'
        defaultValue: tagName
      }
    }
    policyDefinitions: [
      { policyDefinitionId: tlsPolicy.id }
      { policyDefinitionId: httpsPolicy.id }
      { policyDefinitionId: kvEncryptionPolicy.id }
      {
        policyDefinitionId: tagPolicy.id
        parameters: {
          def_tagName: {
            value: '[parameters(\'set_tagName\')]'
          }
        }
      }
    ]
  }
}

// 6. Assignment
resource baselineAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: take('${projectName}-asgn', 24)
  location: location
  properties: {
    displayName: '${projectName} Assignment'
    policyDefinitionId: baselineInitiative.id
    parameters: {
      set_tagName: {
        value: tagName
      }
    }
  }
  identity: { type: 'SystemAssigned' }
}
