/*
  Monitoring Module - Log Analytics Workspace and Action Group
  
  Naming Convention:
  - Log Analytics: {projectName}-hub-law
  - Action Group: {projectName}-hub-ag
  
  - Includes 'hub' to indicate centralized deployment in Hub network
  - Environment managed through tags, not naming
*/

param location string
param logAnalyticsName string
param projectName string
param environment string
@description('Alert email address for action group (leave empty to skip action group creation)')
param alertEmailAddress string = ''

// Common tags (environment in tags, not names)
var commonTags = {
  environment: environment
  project: projectName
}

// Log Analytics Workspace
// Naming: {projectName}-hub-law
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: logAnalyticsName
  location: location
  tags: commonTags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// Action Group for alerts (only create if email provided)
// Naming: {projectName}-hub-ag
resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = if(!empty(alertEmailAddress)) {
  name: '${projectName}-hub-ag'
  location: 'global'
  tags: commonTags
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
output actionGroupId string = !empty(alertEmailAddress) ? actionGroup.id : ''
