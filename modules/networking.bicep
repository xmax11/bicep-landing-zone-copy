/*
  Networking Module - Hub and Spoke Topology
  
  Naming Convention:
  - Hub resources: {projectName}-hub-{resourceType}-{purpose}
  - Spoke resources: {projectName}-spoke-{role}-{resourceType}
  - Roles: infra, app, data, paas
  - Environment managed through tags, not naming
*/

param location string
param projectName string
param environment string
param hubVnetAddressSpace string = '10.100.0.0/16'
param spokeVnetAddressSpace string = '10.200.0.0/16'
@description('Private IP of NVA in spoke AppSubnet (leave empty for dynamic assignment)')
param nvaPrivateIp string = ''
@description('Deploy Azure Firewall')
param deployFirewall bool = false

// ====== Hub Subnet Configuration ======
var hubSubnets = [
  {
    name: 'AzureFirewallSubnet'
    addressPrefix: cidrSubnet(hubVnetAddressSpace, 24, 0)
    nsgName: ''
    routeTableName: ''
  }
  {
    name: 'GatewaySubnet'
    addressPrefix: cidrSubnet(hubVnetAddressSpace, 24, 1)
    nsgName: ''
    routeTableName: ''
  }
  {
    name: 'BastionSubnet'
    addressPrefix: cidrSubnet(hubVnetAddressSpace, 26, 8)
    nsgName: '${projectName}-hub-nsg-bastion'
    routeTableName: ''
  }
  {
    name: 'PrivateDnsResolverSubnet'
    addressPrefix: cidrSubnet(hubVnetAddressSpace, 26, 9)
    nsgName: '${projectName}-hub-nsg-dnsresolver'
    routeTableName: ''
  }
  {
    name: 'IdentitySubnet'
    addressPrefix: cidrSubnet(hubVnetAddressSpace, 26, 10)
    nsgName: '${projectName}-hub-nsg-identity'
    routeTableName: '${projectName}-hub-udr-identity'
  }
  {
    name: 'ManagementSubnet'
    addressPrefix: cidrSubnet(hubVnetAddressSpace, 24, 3)
    nsgName: '${projectName}-hub-nsg-management'
    routeTableName: '${projectName}-hub-udr-management'
  }
]

// ====== Spoke Subnet Configuration ======
var spokeSubnets = [
  {
    name: 'InfraSubnet'
    addressPrefix: cidrSubnet(spokeVnetAddressSpace, 24, 0)
    nsgName: '${projectName}-spoke-infra-nsg'
    routeTableName: '${projectName}-spoke-infra-udr'
  }
  {
    name: 'AppSubnet'
    addressPrefix: cidrSubnet(spokeVnetAddressSpace, 24, 1)
    nsgName: '${projectName}-spoke-app-nsg'
    routeTableName: '${projectName}-spoke-app-udr'
    nvaIp: !empty(nvaPrivateIp) ? nvaPrivateIp : cidrHost(spokeVnetAddressSpace, 4)
  }
  {
    name: 'DataSubnet'
    addressPrefix: cidrSubnet(spokeVnetAddressSpace, 24, 2)
    nsgName: '${projectName}-spoke-data-nsg'
    routeTableName: '${projectName}-spoke-data-udr'
  }
  {
    name: 'PaaSSvcSubnet'
    addressPrefix: cidrSubnet(spokeVnetAddressSpace, 24, 3)
    nsgName: '${projectName}-spoke-paas-nsg'
    routeTableName: '${projectName}-spoke-paas-udr'
  }
]

// Common tags for all resources (environment in tags, not names)
var commonTags = {
  environment: environment
  project: projectName
}

// ====== Dynamic IP Calculation ======
var calculatedFirewallIp = cidrHost(cidrSubnet(hubVnetAddressSpace, 24, 0), 4)
var nvaIpAddress = !empty(nvaPrivateIp) ? nvaPrivateIp : calculatedFirewallIp

// ====== Application Security Groups ======
resource infraAsg 'Microsoft.Network/applicationSecurityGroups@2023-02-01' = {
  name: '${projectName}-spoke-infra-asg'
  location: location
  tags: commonTags
}

resource appAsg 'Microsoft.Network/applicationSecurityGroups@2023-02-01' = {
  name: '${projectName}-spoke-app-asg'
  location: location
  tags: commonTags
}

resource dataAsg 'Microsoft.Network/applicationSecurityGroups@2023-02-01' = {
  name: '${projectName}-spoke-data-asg'
  location: location
  tags: commonTags
}

resource paasAsg 'Microsoft.Network/applicationSecurityGroups@2023-02-01' = {
  name: '${projectName}-spoke-paas-asg'
  location: location
  tags: commonTags
}

// ====== Network Security Groups (Hub) ======
resource bastionNsg 'Microsoft.Network/networkSecurityGroups@2023-02-01' = {
  name: hubSubnets[2].nsgName
  location: location
  tags: commonTags
}

resource dnsResolverNsg 'Microsoft.Network/networkSecurityGroups@2023-02-01' = {
  name: hubSubnets[3].nsgName
  location: location
  tags: commonTags
}

resource identityNsg 'Microsoft.Network/networkSecurityGroups@2023-02-01' = {
  name: hubSubnets[4].nsgName
  location: location
  tags: commonTags
}

resource hubManagementNsg 'Microsoft.Network/networkSecurityGroups@2023-02-01' = {
  name: hubSubnets[5].nsgName
  location: location
  tags: commonTags
}

// ====== Network Security Groups (Spoke) ======
resource infraNsg 'Microsoft.Network/networkSecurityGroups@2023-02-01' = {
  name: spokeSubnets[0].nsgName
  location: location
  tags: commonTags
}

resource appNsg 'Microsoft.Network/networkSecurityGroups@2023-02-01' = {
  name: spokeSubnets[1].nsgName
  location: location
  tags: commonTags
}

resource dataNsg 'Microsoft.Network/networkSecurityGroups@2023-02-01' = {
  name: spokeSubnets[2].nsgName
  location: location
  tags: commonTags
}

resource paasNsg 'Microsoft.Network/networkSecurityGroups@2023-02-01' = {
  name: spokeSubnets[3].nsgName
  location: location
  tags: commonTags
}

// ====== Hub VNet ======
resource hubVnet 'Microsoft.Network/virtualNetworks@2023-02-01' = {
  name: '${projectName}-hub-vnet'
  location: location
  tags: union(commonTags, { role: 'hub' })
  properties: {
    addressSpace: { addressPrefixes: [ hubVnetAddressSpace ] }
    subnets: [
      { name: hubSubnets[0].name, properties: { addressPrefix: hubSubnets[0].addressPrefix } }
      { name: hubSubnets[1].name, properties: { addressPrefix: hubSubnets[1].addressPrefix } }
      { name: hubSubnets[2].name, properties: { addressPrefix: hubSubnets[2].addressPrefix, networkSecurityGroup: { id: bastionNsg.id } } }
      { name: hubSubnets[3].name, properties: { addressPrefix: hubSubnets[3].addressPrefix, networkSecurityGroup: { id: dnsResolverNsg.id } } }
      { name: hubSubnets[4].name, properties: { addressPrefix: hubSubnets[4].addressPrefix, networkSecurityGroup: { id: identityNsg.id }, routeTable: deployFirewall ? { id: identityUdr.id } : null } }
      { name: hubSubnets[5].name, properties: { addressPrefix: hubSubnets[5].addressPrefix, networkSecurityGroup: { id: hubManagementNsg.id }, routeTable: deployFirewall ? { id: managementUdr.id } : null } }
    ]
  }
}

// ====== Azure Firewall Public IP ======
resource firewallPip 'Microsoft.Network/publicIPAddresses@2023-02-01' = if(deployFirewall) {
  name: '${projectName}-hub-fw-pip'
  location: location
  tags: commonTags
  sku: { name: 'Standard' }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}

// ====== Azure Firewall ======
resource azureFirewall 'Microsoft.Network/azureFirewalls@2023-02-01' = if(deployFirewall) {
  name: '${projectName}-hub-azure-fw'
  location: location
  tags: commonTags
  properties: {
    sku: { name: 'AZFW_VNet', tier: 'Standard' }
    ipConfigurations: [
      {
        name: 'azureFirewallIpConfiguration'
        properties: {
          subnet: { id: '${hubVnet.id}/subnets/AzureFirewallSubnet' }
          publicIPAddress: { id: firewallPip.id }
        }
      }
    ]
  }
}

// ====== User Defined Routes (Hub) ======
resource identityUdr 'Microsoft.Network/routeTables@2023-02-01' = {
  name: hubSubnets[4].routeTableName
  location: location
  tags: commonTags
  properties: {
    routes: [
      {
        name: 'ToSpoke'
        properties: {
          addressPrefix: spokeVnetAddressSpace
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: nvaIpAddress
        }
      }
    ]
  }
}

resource managementUdr 'Microsoft.Network/routeTables@2023-02-01' = {
  name: hubSubnets[5].routeTableName
  location: location
  tags: commonTags
  properties: {
    routes: [
      {
        name: 'ToSpoke'
        properties: {
          addressPrefix: spokeVnetAddressSpace
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: nvaIpAddress
        }
      }
    ]
  }
}

// ====== User Defined Routes (Spoke - Infra) ======
resource infraUdr 'Microsoft.Network/routeTables@2023-02-01' = {
  name: spokeSubnets[0].routeTableName
  location: location
  tags: commonTags
  properties: {
    disableBgpRoutePropagation: true
    routes: [
      {
        name: 'DefaultRouteToFirewall'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: nvaIpAddress
        }
      }
    ]
  }
}

// ====== User Defined Routes (Spoke - App) ======
resource appUdr 'Microsoft.Network/routeTables@2023-02-01' = {
  name: spokeSubnets[1].routeTableName
  location: location
  tags: commonTags
  dependsOn: [ hubVnet ]
  properties: {
    disableBgpRoutePropagation: true
    routes: [
      {
        name: 'DefaultRouteToFirewall'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: nvaIpAddress
        }
      }
    ]
  }
}

// ====== User Defined Routes (Spoke - Data) ======
resource dataUdr 'Microsoft.Network/routeTables@2023-02-01' = {
  name: spokeSubnets[2].routeTableName
  location: location
  tags: commonTags
  dependsOn: [ hubVnet ]
  properties: {
    disableBgpRoutePropagation: true
    routes: [
      {
        name: 'DefaultRouteToFirewall'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: nvaIpAddress
        }
      }
    ]
  }
}

// ====== User Defined Routes (Spoke - PaaS) ======
resource paasUdr 'Microsoft.Network/routeTables@2023-02-01' = {
  name: spokeSubnets[3].routeTableName
  location: location
  tags: commonTags
  dependsOn: [ hubVnet ]
  properties: {
    disableBgpRoutePropagation: true
    routes: [
      {
        name: 'DefaultRouteToFirewall'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: nvaIpAddress
        }
      }
    ]
  }
}

// ====== Spoke VNet ======
resource spokeVnet 'Microsoft.Network/virtualNetworks@2023-02-01' = {
  name: '${projectName}-spoke-infra-vnet'
  location: location
  tags: union(commonTags, { role: 'spoke', function: 'infrastructure' })
  properties: {
    addressSpace: { addressPrefixes: [ spokeVnetAddressSpace ] }
    subnets: [
      {
        name: spokeSubnets[0].name
        properties: {
          addressPrefix: spokeSubnets[0].addressPrefix
          networkSecurityGroup: { id: infraNsg.id }
          routeTable: deployFirewall ? { id: infraUdr.id } : null
        }
      }
      {
        name: spokeSubnets[1].name
        properties: {
          addressPrefix: spokeSubnets[1].addressPrefix
          networkSecurityGroup: { id: appNsg.id }
          routeTable: deployFirewall ? { id: appUdr.id } : null
        }
      }
      {
        name: spokeSubnets[2].name
        properties: {
          addressPrefix: spokeSubnets[2].addressPrefix
          networkSecurityGroup: { id: dataNsg.id }
          routeTable: deployFirewall ? { id: dataUdr.id } : null
        }
      }
      {
        name: spokeSubnets[3].name
        properties: {
          addressPrefix: spokeSubnets[3].addressPrefix
          networkSecurityGroup: { id: paasNsg.id }
          routeTable: deployFirewall ? { id: paasUdr.id } : null
        }
      }
    ]
  }
}

// ====== VNet Peering ======
resource hubToSpokePeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-02-01' = {
  parent: hubVnet
  name: '${projectName}-hub-to-spoke'
  properties: {
    allowForwardedTraffic: true
    allowGatewayTransit: true
    allowVirtualNetworkAccess: true
    useRemoteGateways: false
    remoteVirtualNetwork: { id: spokeVnet.id }
  }
}

resource spokeToHubPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-02-01' = {
  parent: spokeVnet
  name: '${projectName}-spoke-to-hub'
  properties: {
    allowForwardedTraffic: true
    allowGatewayTransit: false
    allowVirtualNetworkAccess: true
    useRemoteGateways: false
    remoteVirtualNetwork: { id: hubVnet.id }
  }
}

// ====== Outputs ======
output hubVnetId string = hubVnet.id
output spokeVnetId string = spokeVnet.id
output firewallId string = deployFirewall ? azureFirewall.id : ''
output firewallPrivateIpAddress string = deployFirewall ? azureFirewall.properties.ipConfigurations[0].properties.privateIPAddress : ''
output infraAsgId string = infraAsg.id
output appAsgId string = appAsg.id
output dataAsgId string = dataAsg.id
output paasAsgId string = paasAsg.id
output paasSubnetId string = '${spokeVnet.id}/subnets/PaaSSvcSubnet'
output appSubnetId string = '${spokeVnet.id}/subnets/AppSubnet'
