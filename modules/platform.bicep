/*
  Platform Module - Deploys PaaS services (SQL, Cosmos DB, App Service)
*/

param location string
param projectName string
param environment string

// Generate unique suffix
var uniqueSuffix = take(uniqueString(subscription().id, location), 8)

// PaaS Service Names
var sqlServerName = '${projectName}-sql-${uniqueSuffix}'
var cosmosDbAccountName = '${projectName}-cosmos-${uniqueSuffix}'
var appServicePlanName = '${projectName}-asp-${uniqueSuffix}'
var appServiceName = '${projectName}-app-${uniqueSuffix}'

// Common tags
var commonTags = {
  environment: environment
  project: projectName
}

// Deploy SQL Server
resource sqlServer 'Microsoft.Sql/servers@2022-11-01' = {
  name: sqlServerName
  location: location
  tags: commonTags
  properties: {
    administratorLogin: 'sqladmin'
    administratorLoginPassword: 'ChangeMe@123456789'  // Parameterize in production
  }
}

// Deploy Azure SQL Database
resource sqlDatabase 'Microsoft.Sql/servers/databases@2022-11-01' = {
  parent: sqlServer
  name: '${sqlServerName}-db'
  location: location
  tags: commonTags
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
}

// Deploy Cosmos DB Account
resource cosmosDb 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: cosmosDbAccountName
  location: location
  tags: commonTags
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
  }
}

// Deploy App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: appServicePlanName
  location: location
  tags: commonTags
  sku: {
    name: 'B1'
    tier: 'Basic'
    capacity: 1
  }
  kind: 'app'
}

// Deploy App Service (Web App)
resource appService 'Microsoft.Web/sites@2022-09-01' = {
  name: appServiceName
  location: location
  tags: commonTags
  kind: 'app'
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
  }
}

// Outputs
output sqlServerId string = sqlServer.id
output sqlServerName string = sqlServer.name
output sqlDatabaseId string = sqlDatabase.id
output cosmosDbAccountId string = cosmosDb.id
output cosmosDbAccountName string = cosmosDb.name
output appServiceId string = appService.id
output appServiceName string = appService.name
output appServicePlanId string = appServicePlan.id
output appServicePlanName string = appServicePlan.name
