/*
  Azure Landing Zone - Hub and Dual-Spoke Topology
  Deployment: Networking + Security + Private DNS/Endpoints + IaaS VMs + App Service
*/

targetScope = 'subscription'

@description('Azure region for deployment')
param location string = 'eastus'

@description('Environment name (production, staging, development)')
param environment string = 'production'

@description('Project name used for resource naming')
param projectName string = 'sinet-hub-spoke'

@description('Hub VNet address space (CIDR)')
param hubVnetAddressSpace string = '10.100.0.0/16'

@description('Primary spoke VNet address space (CIDR)')
param spokeVnetAddressSpace string = '10.200.0.0/16'

@description('Secondary spoke VNet address space (CIDR)')
param spoke2VnetAddressSpace string = '10.210.0.0/16'

@description('Private IP of NVA in hub (leave empty for dynamic assignment from firewall subnet)')
param nvaPrivateIp string = ''

@description('Deploy Log Analytics Workspace')
param deployLogAnalytics bool = true

@description('Deploy Azure Policies')
param deployAzurePolicies bool = true

@description('Alert email address for action group')
param alertEmailAddress string = 'alerts@contoso.com'

@description('Deploy Azure Firewall')
param deployFirewall bool = false

@description('Deploy Azure Bastion host in hub')
param deployBastion bool = true

@description('Force all outbound spoke traffic (0.0.0.0/0) through the hub firewall')
param enableFirewallDefaultRoute bool = false

@description('Bypass firewall for ManagementSubnet to keep management and private link access direct')
param bypassFirewallForManagement bool = true

@allowed([
  'Alert'
  'Deny'
  'Off'
])
@description('Threat intelligence mode for the Azure Firewall Policy')
param firewallThreatIntelMode string = 'Deny'

@description('Explicit destination CIDRs allowed through firewall for outbound egress when default routing to firewall is enabled')
param allowedFirewallEgressCidrs array = []

@description('Deploy App Service in spoke1')
param deploySpokeAppService bool = true

@description('App Service Plan SKU name for spoke app service (for example: B1, S1, P1v3)')
param appServicePlanSkuName string = 'B1'

@description('App Service Plan SKU tier for spoke app service (for example: Basic, Standard, PremiumV3)')
param appServicePlanSkuTier string = 'Basic'

@minValue(1)
@description('Number of worker instances for the spoke App Service Plan')
param appServicePlanCapacity int = 1

@description('Deploy one VM in each spoke')
param deployWorkloadVms bool = true

@description('Deploy a temporary test VM in the Hub ManagementSubnet for connectivity validation')
param deployHubTestVm bool = false

@description('Admin username for spoke VMs')
param vmAdminUsername string = 'azureuser'

@secure()
@description('Admin password for spoke VMs')
param vmAdminPassword string

@description('VM size for spoke VMs and optional Hub test VM')
param vmSku string = 'Standard_D2s_v3'

// Generate unique suffix for naming
var uniqueSuffix = take(uniqueString(subscription().id, location), 8)
var normalizedProjectName = toLower(replace(replace(projectName, '-', ''), '_', ''))
var resourceGroupName = '${projectName}-rg-${location}'
var logAnalyticsName = take('${projectName}-hub-law-${location}-${uniqueSuffix}', 63)
var keyVaultName = take('${normalizedProjectName}spokekv${uniqueSuffix}', 24)
var storageAccountName = take('${normalizedProjectName}spokest${uniqueSuffix}', 24)
var logAnalyticsWorkspaceId = deployLogAnalytics ? monitoring!.outputs.logAnalyticsWorkspaceId : ''

// Create Resource Group
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
  tags: {
    environment: environment
    project: projectName
    managedBy: 'Bicep'
  }
}

// Deploy Networking
module networking 'modules/networking.bicep' = {
  name: 'hub-spoke-networking-deployment'
  scope: resourceGroup
  params: {
    location: location
    projectName: projectName
    environment: environment
    hubVnetAddressSpace: hubVnetAddressSpace
    spokeVnetAddressSpace: spokeVnetAddressSpace
    spoke2VnetAddressSpace: spoke2VnetAddressSpace
    nvaPrivateIp: nvaPrivateIp
    deployFirewall: deployFirewall
    deployBastion: deployBastion
    enableFirewallDefaultRoute: enableFirewallDefaultRoute
    bypassFirewallForManagement: bypassFirewallForManagement
    firewallThreatIntelMode: firewallThreatIntelMode
    allowedFirewallEgressCidrs: allowedFirewallEgressCidrs
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

// Deploy Monitoring
module monitoring 'modules/monitoring.bicep' = if (deployLogAnalytics) {
  name: 'hub-monitoring-deployment'
  scope: resourceGroup
  params: {
    location: location
    logAnalyticsName: logAnalyticsName
    projectName: projectName
    environment: environment
    alertEmailAddress: alertEmailAddress
  }
}

// Deploy Security (Key Vault)
module security 'modules/security.bicep' = {
  name: 'spoke-security-deployment'
  scope: resourceGroup
  params: {
    location: location
    keyVaultName: keyVaultName
    projectName: projectName
    environment: environment
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

// Deploy Storage Account
module storage 'modules/storage.bicep' = {
  name: 'spoke-storage-deployment'
  scope: resourceGroup
  params: {
    location: location
    storageAccountName: storageAccountName
    projectName: projectName
    environment: environment
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

// Deploy App Service in Spoke1
module appService 'modules/app-service.bicep' = if (deploySpokeAppService) {
  name: 'spoke1-appservice-deployment'
  scope: resourceGroup
  params: {
    location: location
    projectName: projectName
    environment: environment
    appSubnetId: networking.outputs.spoke1AppSubnetId
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    appServicePlanSkuName: appServicePlanSkuName
    appServicePlanSkuTier: appServicePlanSkuTier
    appServicePlanCapacity: appServicePlanCapacity
  }
}

// Deploy one VM in each spoke
module compute 'modules/compute.bicep' = if (deployWorkloadVms) {
  name: 'spoke-compute-deployment'
  scope: resourceGroup
  params: {
    location: location
    projectName: projectName
    environment: environment
    spoke1InfraSubnetId: networking.outputs.spoke1InfraSubnetId
    spoke2InfraSubnetId: networking.outputs.spoke2InfraSubnetId
    adminUsername: vmAdminUsername
    adminPassword: vmAdminPassword
    vmSize: vmSku
  }
}

// Deploy a Hub test VM for hub-to-spoke connectivity checks
module hubTestVm 'modules/hub-test-vm.bicep' = if (deployHubTestVm) {
  name: 'hub-test-vm-deployment'
  scope: resourceGroup
  params: {
    location: location
    projectName: projectName
    environment: environment
    hubManagementSubnetId: '${networking.outputs.hubVnetId}/subnets/ManagementSubnet'
    adminUsername: vmAdminUsername
    adminPassword: vmAdminPassword
    vmSize: vmSku
  }
}

// Deploy Private DNS Zones (Centralized in Hub)
module privateDnsZones 'modules/private-dns-zones.bicep' = {
  name: 'hub-private-dns-zones-deployment'
  scope: resourceGroup
  params: {
    location: location
    projectName: projectName
    environment: environment
    hubVnetId: networking.outputs.hubVnetId
    spokeVnetId: networking.outputs.spoke1VnetId
    secondarySpokeVnetId: networking.outputs.spoke2VnetId
    deployAppService: deploySpokeAppService
  }
}

// Deploy Private Endpoints for Storage, Key Vault, and App Service
module privateEndpoints 'modules/private-endpoints.bicep' = {
  name: 'spoke-private-endpoints-deployment'
  scope: resourceGroup
  params: {
    location: location
    projectName: projectName
    environment: environment
    storageAccountId: storage.outputs.storageAccountId
    keyVaultId: security.outputs.keyVaultId
    sqlServerId: ''
    cosmosDbAccountId: ''
    appServiceId: deploySpokeAppService ? appService!.outputs.appServiceId : ''
    paasSubnetId: networking.outputs.spoke1PaasSubnetId
    storagePrivateDnsZoneId: privateDnsZones.outputs.storagePrivateDnsZoneId
    keyVaultPrivateDnsZoneId: privateDnsZones.outputs.keyVaultPrivateDnsZoneId
    sqlPrivateDnsZoneId: privateDnsZones.outputs.sqlPrivateDnsZoneId
    appServicePrivateDnsZoneId: privateDnsZones.outputs.appServicePrivateDnsZoneId
    cosmosDbPrivateDnsZoneId: privateDnsZones.outputs.cosmosDbPrivateDnsZoneId
  }
}

// Deploy Azure Policies at the Subscription Level
module policies 'modules/policies.bicep' = if (deployAzurePolicies) {
  name: 'policiesDeployment-${uniqueSuffix}'
  scope: subscription()
}

// Outputs
output hubVnetId string = networking.outputs.hubVnetId
output spokeVnetId string = networking.outputs.spokeVnetId
output spoke1VnetId string = networking.outputs.spoke1VnetId
output spoke2VnetId string = networking.outputs.spoke2VnetId
output firewallPrivateIpAddress string = deployFirewall ? networking.outputs.firewallPrivateIpAddress : ''
output bastionHostId string = deployBastion ? networking.outputs.bastionHostId : ''
output logAnalyticsWorkspaceId string = logAnalyticsWorkspaceId
output keyVaultId string = security.outputs.keyVaultId
output keyVaultName string = security.outputs.keyVaultName
output storageAccountId string = storage.outputs.storageAccountId
output resourceGroupName string = resourceGroup.name
output resourceGroupId string = resourceGroup.id

output appServiceId string = deploySpokeAppService ? appService!.outputs.appServiceId : ''
output appServiceName string = deploySpokeAppService ? appService!.outputs.appServiceName : ''
output appServiceDefaultHostname string = deploySpokeAppService ? appService!.outputs.appServiceDefaultHostname : ''
output vmIds array = deployWorkloadVms ? compute!.outputs.vmIds : []
output vmNames array = deployWorkloadVms ? compute!.outputs.vmNames : []
output vmPrivateIps array = deployWorkloadVms ? compute!.outputs.vmPrivateIps : []
output hubTestVmId string = deployHubTestVm ? hubTestVm!.outputs.vmId : ''
output hubTestVmName string = deployHubTestVm ? hubTestVm!.outputs.vmName : ''
output hubTestVmPrivateIp string = deployHubTestVm ? hubTestVm!.outputs.vmPrivateIp : ''

// Private DNS Zone IDs (from centralized private-dns-zones module)
output storagePrivateDnsZoneId string = privateDnsZones.outputs.storagePrivateDnsZoneId
output keyVaultPrivateDnsZoneId string = privateDnsZones.outputs.keyVaultPrivateDnsZoneId
output sqlPrivateDnsZoneId string = privateDnsZones.outputs.sqlPrivateDnsZoneId
output cosmosDbPrivateDnsZoneId string = privateDnsZones.outputs.cosmosDbPrivateDnsZoneId
output appServicePrivateDnsZoneId string = privateDnsZones.outputs.appServicePrivateDnsZoneId
output filePrivateDnsZoneId string = privateDnsZones.outputs.filePrivateDnsZoneId
output webPrivateDnsZoneId string = privateDnsZones.outputs.webPrivateDnsZoneId

// Private Endpoint IDs
output storagePrivateEndpointId string = privateEndpoints.outputs.storagePrivateEndpointId
output keyVaultPrivateEndpointId string = privateEndpoints.outputs.keyVaultPrivateEndpointId
output sqlPrivateEndpointId string = privateEndpoints.outputs.sqlPrivateEndpointId
output cosmosDbPrivateEndpointId string = privateEndpoints.outputs.cosmosDbPrivateEndpointId
output appServicePrivateEndpointId string = privateEndpoints.outputs.appServicePrivateEndpointId

// Subnet IDs
output spoke1InfraSubnetId string = networking.outputs.spoke1InfraSubnetId
output spoke2InfraSubnetId string = networking.outputs.spoke2InfraSubnetId
output spoke1PaaSSubnetId string = networking.outputs.spoke1PaasSubnetId
output spoke2PaaSSubnetId string = networking.outputs.spoke2PaasSubnetId
output spoke1AppSubnetId string = networking.outputs.spoke1AppSubnetId
output spoke2AppSubnetId string = networking.outputs.spoke2AppSubnetId

// Backward-compatible aliases
output paasSubnetId string = networking.outputs.paasSubnetId
output appSubnetId string = networking.outputs.appSubnetId
