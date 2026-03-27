/*
  App Service Module - Single spoke-hosted web app with VNet integration
*/

param location string
param projectName string
param environment string
param appSubnetId string
param logAnalyticsWorkspaceId string = ''
@description('App Service Plan SKU name (for example: B1, S1, P1v3)')
param appServicePlanSkuName string
@description('App Service Plan SKU tier (for example: Basic, Standard, PremiumV3)')
param appServicePlanSkuTier string
@minValue(1)
@description('Number of worker instances for the App Service Plan')
param appServicePlanCapacity int

var uniqueSuffix = take(uniqueString(subscription().id, location, projectName), 8)
var appServicePlanName = take('${projectName}-spoke1-asp-${uniqueSuffix}', 40)
var appServiceName = take('${projectName}-spoke1-app-${uniqueSuffix}', 60)

var commonTags = {
  environment: environment
  project: projectName
}

resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: appServicePlanName
  location: location
  tags: commonTags
  sku: {
    name: appServicePlanSkuName
    tier: appServicePlanSkuTier
    capacity: appServicePlanCapacity
  }
  kind: 'app'
}

resource appService 'Microsoft.Web/sites@2022-09-01' = {
  name: appServiceName
  location: location
  tags: commonTags
  kind: 'app'
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    publicNetworkAccess: 'Disabled'
    virtualNetworkSubnetId: appSubnetId
    siteConfig: {
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      alwaysOn: true
    }
  }
}

resource appServiceDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (logAnalyticsWorkspaceId != '') {
  name: '${projectName}-spoke1-appsvc-diag'
  scope: appService
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
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

output appServicePlanId string = appServicePlan.id
output appServicePlanName string = appServicePlan.name
output appServiceId string = appService.id
output appServiceName string = appService.name
output appServiceDefaultHostname string = appService.properties.defaultHostName
