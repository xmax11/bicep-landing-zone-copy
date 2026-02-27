/*
  Monitoring Module - Log Analytics Workspace and Action Group
*/

param location string
param logAnalyticsName string
param projectName string
param environment string
param alertEmailAddress string

// Log Analytics Workspace
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: logAnalyticsName
  location: location
  tags: {
    environment: environment
    project: projectName
  }
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// Action Group for alerts
resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: '${projectName}-ag-${location}'
  location: 'global'
  tags: {
    environment: environment
    project: projectName
  }
  properties: {
    groupShortName: 'alerts'
    enabled: true
    emailReceivers: [
      {
        name: 'ServiceDisruptionAlert'
        emailAddress: alertEmailAddress
        useCommonAlertSchema: true
      }
    ]
  }
}

// Diagnostic settings for Log Analytics (optional, can be added later)

output logAnalyticsWorkspaceId string = logAnalytics.id
output logAnalyticsWorkspaceName string = logAnalytics.name
output actionGroupId string = actionGroup.id
