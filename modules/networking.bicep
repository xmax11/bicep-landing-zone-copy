/*
  Networking Module - Hub and Spoke Topology
  Deploys:
  - Hub VNet with subnets (Firewall, Gateway, Management)
  - Spoke VNets (Infrastructure, Application, Data, PaaS)
  - VNet Peering
  - Network Security Groups
  - User Defined Routes
  - Azure Firewall
*/

param location string
param projectName string
param environment string
param hubVnetAddressSpace string = '10.100.0.0/16'
param spokeVnetAddressSpace string = '10.200.0.0/16'
@description('Private IP of NVA in spoke AppSubnet (leave empty for dynamic assignment)')
param nvaPrivateIp string = ''

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
    nsgName: '${projectName}-nsg-bastion'
    routeTableName: ''
  }
  {
    name: 'PrivateDnsResolverSubnet'
    addressPrefix: cidrSubnet(hubVnetAddressSpace, 26, 9)
    nsgName: '${projectName}-nsg-dnsresolver'
    routeTableName: ''
  }
  {
    name: 'IdentitySubnet'
    addressPrefix: cidrSubnet(hubVnetAddressSpace, 26, 10)
    nsgName: '${projectName}-nsg-identity'
    routeTableName: '${projectName}-udr-identity'
  }
  {
    name: 'ManagementSubnet'
    addressPrefix: cidrSubnet(hubVnetAddressSpace, 24, 3)
    nsgName: '${projectName}-nsg-management'
    routeTableName: '${projectName}-udr-management'
  }
]

// ====== Spoke Subnet Configuration ======
var spokeSubnets = [
  {
    name: 'InfraSubnet'
    addressPrefix: cidrSubnet(spokeVnetAddressSpace, 24, 0)
    nsgName: '${projectName}-nsg-infra'
    routeTableName: '${projectName}-udr-infra'
  }
  {
    name: 'AppSubnet'
    addressPrefix: cidrSubnet(spokeVnetAddressSpace, 24, 1)
    nsgName: '${projectName}-nsg-app'
    routeTableName: '${projectName}-udr-app'
    nvaIp: !empty(nvaPrivateIp) ? nvaPrivateIp : cidrHost(spokeVnetAddressSpace, 4)
  }
  {
    name: 'DataSubnet'
    addressPrefix: cidrSubnet(spokeVnetAddressSpace, 24, 2)
    nsgName: '${projectName}-nsg-data'
    routeTableName: '${projectName}-udr-data'
  }
  {
    name: 'PaaSSvcSubnet'
    addressPrefix: cidrSubnet(spokeVnetAddressSpace, 24, 3)
    nsgName: '${projectName}-nsg-paas'
    routeTableName: '${projectName}-udr-paas'
  }
]

// Common tags for all resources
var commonTags = {
  environment: environment
  project: projectName
}

// ====== Compute NVA/Firewall IP - Use provided value or calculate default ======
// When dynamic (empty), we calculate a default from the firewall subnet for UDR purposes
// The actual firewall IP will be assigned by Azure and can be retrieved from outputs
// ====== Dynamic IP Calculation ======
// Azure reserves the first 3 IPs in a subnet. The 4th IP (.4) is the first available.
// This calculates the IP based on whatever the user enters for hubVnetAddressSpace.
var calculatedFirewallIp = cidrHost(cidrSubnet(hubVnetAddressSpace, 24, 0), 4)

// Use the override if provided, otherwise use the calculated dynamic IP
var nvaIpAddress = !empty(nvaPrivateIp) ? nvaPrivateIp : calculatedFirewallIp
// ====== Application Security Groups ======
resource infraAsg 'Microsoft.Network/applicationSecurityGroups@2023-02-01' = {
  name: '${projectName}-asg-infra'
  location: location
  tags: commonTags
}

resource appAsg 'Microsoft.Network/applicationSecurityGroups@2023-02-01' = {
  name: '${projectName}-asg-app'
  location: location
  tags: commonTags
}

resource dataAsg 'Microsoft.Network/applicationSecurityGroups@2023-02-01' = {
  name: '${projectName}-asg-data'
  location: location
  tags: commonTags
}

resource paasAsg 'Microsoft.Network/applicationSecurityGroups@2023-02-01' = {
  name: '${projectName}-asg-paas'
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
      { name: hubSubnets[4].name, properties: { addressPrefix: hubSubnets[4].addressPrefix, networkSecurityGroup: { id: identityNsg.id } } }
      { name: hubSubnets[5].name, properties: { addressPrefix: hubSubnets[5].addressPrefix, networkSecurityGroup: { id: hubManagementNsg.id } } }
    ]
  }
}

// ====== Azure Firewall Public IP ======
resource firewallPip 'Microsoft.Network/publicIPAddresses@2023-02-01' = {
  name: '${projectName}-azure-fw-pip'
  location: location
  tags: commonTags
  sku: { name: 'Standard' }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}

// ====== Azure Firewall (Dynamic IP) ======
resource azureFirewall 'Microsoft.Network/azureFirewalls@2023-02-01' = {
  name: '${projectName}-azure-fw'
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
          // privateIPAddress is dynamically assigned by Azure when not specified
        }
      }
    ]
  }
}

// ====== User Defined Routes (Hub & Spoke) ======
// Note: Using Azure Firewall's dynamically assigned IP will be retrieved after deployment
// For UDRs, we'll use a placeholder that gets updated or reference the firewall resource
resource identityUdr 'Microsoft.Network/routeTables@2023-02-01' = {
  name: hubSubnets[4].routeTableName
  location: location
  tags: commonTags
  dependsOn: [ hubVnet ]
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
  dependsOn: [ hubVnet ]
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
          // This pulls the IP dynamically from the firewall we just created
          nextHopIpAddress: azureFirewall.properties.ipConfigurations[0].properties.privateIPAddress
        }
      }
    ]
  }
}


resource appUdr 'Microsoft.Network/routeTables@2023-02-01' = {
  name: spokeSubnets[1].routeTableName
  location: location
  tags: commonTags
  dependsOn: [ hubVnet ]
  properties: {
    disableBgpRoutePropagation: true
    routes: [
      {
        name: 'ToFirewall'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: nvaIpAddress
        }
      }
    ]
  }
}

resource dataUdr 'Microsoft.Network/routeTables@2023-02-01' = {
  name: spokeSubnets[2].routeTableName
  location: location
  tags: commonTags
  dependsOn: [ hubVnet ]
  properties: {
    disableBgpRoutePropagation: true
    routes: [
      {
        name: 'ToFirewall'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: nvaIpAddress
        }
      }
    ]
  }
}

resource paasUdr 'Microsoft.Network/routeTables@2023-02-01' = {
  name: spokeSubnets[3].routeTableName
  location: location
  tags: commonTags
  dependsOn: [ hubVnet ]
  properties: {
    disableBgpRoutePropagation: true
    routes: [
      {
        name: 'ToFirewall'
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
  name: '${projectName}-spoke-vnet'
  location: location
  tags: union(commonTags, { role: 'spoke' })
  properties: {
    addressSpace: { addressPrefixes: [ spokeVnetAddressSpace ] }
    subnets: [
      {
        name: spokeSubnets[0].name
        properties: {
          addressPrefix: spokeSubnets[0].addressPrefix
          networkSecurityGroup: { id: infraNsg.id }
          routeTable: { id: infraUdr.id }
        }
      }
      {
        name: spokeSubnets[1].name
        properties: {
          addressPrefix: spokeSubnets[1].addressPrefix
          networkSecurityGroup: { id: appNsg.id }
          routeTable: { id: appUdr.id }
        }
      }
      {
        name: spokeSubnets[2].name
        properties: {
          addressPrefix: spokeSubnets[2].addressPrefix
          networkSecurityGroup: { id: dataNsg.id }
          routeTable: { id: dataUdr.id }
        }
      }
      {
        name: spokeSubnets[3].name
        properties: {
          addressPrefix: spokeSubnets[3].addressPrefix
          networkSecurityGroup: { id: paasNsg.id }
          routeTable: { id: paasUdr.id }
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
output firewallId string = azureFirewall.id
output firewallPrivateIpAddress string = azureFirewall.properties.ipConfigurations[0].properties.privateIPAddress
output infraAsgId string = infraAsg.id
output appAsgId string = appAsg.id
output dataAsgId string = dataAsg.id
output paasAsgId string = paasAsg.id
output paasSubnetId string = '${spokeVnet.id}/subnets/PaaSSvcSubnet'
output appSubnetId string = '${spokeVnet.id}/subnets/AppSubnet'
