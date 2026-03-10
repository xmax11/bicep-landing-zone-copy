targetScope = 'subscription'

param projectName string
param environment string

// Define the IDs as variables for clarity
var inheritTagId = '/providers/Microsoft.Authorization/policyDefinitions/cd3aa116-8875-446f-a212-051a4c79a6b0'
var storageTlsId = '/providers/Microsoft.Authorization/policyDefinitions/a8a5e003-8820-432a-bc93-a97920199d25'

// 1. Inherit Tag: Project
resource inheritProjectTag 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: 'inherit-project-tag'
  location: 'eastus'
  identity: { type: 'SystemAssigned' }
  properties: {
    displayName: 'Inherit Project Tag from Resource Group'
    policyDefinitionId: inheritTagId
    parameters: {
      tagName: { value: 'project' }
    }
  }
}

// 2. Inherit Tag: Environment
resource inheritEnvTag 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: 'inherit-env-tag'
  location: 'eastus'
  identity: { type: 'SystemAssigned' }
  properties: {
    displayName: 'Inherit Environment Tag from Resource Group'
    policyDefinitionId: inheritTagId
    parameters: {
      tagName: { value: 'environment' }
    }
  }
}

// 3. Enforce TLS 1.2 on Storage
resource storageTlsPolicy 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: 'enforce-storage-tls-12'
  location: 'eastus'
  properties: {
    displayName: 'Storage accounts should have minimum TLS version set to 1.2'
    policyDefinitionId: storageTlsId
  }
}
