/*
  Networking Module - Hub and Spoke Topology
  Deploys:
  - Hub VNet with subnets (Firewall, Gateway, Management)
  - Spoke VNets (Infrastructure, Application, Data, PaaS)
  - VNet Peering
  - Network Security Groups
  - User Defined Routes
*/

param location string
param projectName string
param environment string
param hubVnetAddressSpace string = '10.100.0.0/16'
param spokeVnetAddressSpace string = '10.200.0.0/16'
param firewallPrivateIp string = '10.100.0.4'
@description('Private IP of NVA in spoke AppSubnet for data/inter-subnet routing (reserved for future use)')
param nvaPrivateIp string = '10.200.1.4'

// Hub Subnet Configuration
var hubSubnets = [
  {
    name: 'AzureFirewallSubnet'
    addressPrefix: '10.100.0.0/24'
    nsgName: ''  // No NSG for Azure Firewall subnet - Azure doesn't allow
    routeTableName: ''
  }
  {
    name: 'GatewaySubnet'
    addressPrefix: '10.100.1.0/24'
    nsgName: ''  // No NSG for Gateway subnet - Azure doesn't allow
    routeTableName: ''  // Gateway subnet doesn't use UDRs
  }
  {
    name: 'BastionSubnet'
    addressPrefix: '10.100.2.0/26'
    nsgName: '${projectName}-nsg-bastion'
    routeTableName: ''
  }
  {
    name: 'PrivateDnsResolverSubnet'
    addressPrefix: '10.100.2.64/26'
    nsgName: '${projectName}-nsg-dnsresolver'
    routeTableName: ''
  }
  {
    name: 'IdentitySubnet'
    addressPrefix: '10.100.2.128/26'
    nsgName: '${projectName}-nsg-identity'
    routeTableName: '${projectName}-udr-identity'
  }
  {
    name: 'ManagementSubnet'
    addressPrefix: '10.100.3.0/24'
    nsgName: '${projectName}-nsg-management'
    routeTableName: '${projectName}-udr-management'
  }
]

// Spoke Subnet Configuration
var spokeSubnets = [
  {
    name: 'InfraSubnet'
    addressPrefix: '10.200.0.0/24'
    nsgName: '${projectName}-nsg-infra'
    routeTableName: '${projectName}-udr-infra'
  }
  {
    name: 'AppSubnet'
    addressPrefix: '10.200.1.0/24'
    nsgName: '${projectName}-nsg-app'
    routeTableName: '${projectName}-udr-app'
  }
  {
    name: 'DataSubnet'
    addressPrefix: '10.200.2.0/24'
    nsgName: '${projectName}-nsg-data'
    routeTableName: '${projectName}-udr-data'
  }
  {
    name: 'PaaSSvcSubnet'
    addressPrefix: '10.200.3.0/24'
    nsgName: '${projectName}-nsg-paas'
    routeTableName: '${projectName}-udr-paas'
  }
]

// ====== NSGs - Hub ======
// Note: Creating NSGs but not attaching to AzureFirewallSubnet and GatewaySubnet (Azure limitation)
resource hubFirewallNsg 'Microsoft.Network/networkSecurityGroups@2023-02-01' = if(hubSubnets[0].nsgName != '') {
  name: hubSubnets[0].nsgName
  location: location
  tags: {
    environment: environment
    project: projectName
  }
  properties: {
    securityRules: [
      {
        name: 'AllowInboundFromSpoke'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: spokeVnetAddressSpace
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4096
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource hubGatewayNsg 'Microsoft.Network/networkSecurityGroups@2023-02-01' = if(hubSubnets[1].nsgName != '') {
  name: hubSubnets[1].nsgName
  location: location
  tags: {
    environment: environment
    project: projectName
  }
  properties: {
    securityRules: [
      {
        name: 'AllowVpnTraffic'
        properties: {
          protocol: 'Udp'
          sourcePortRange: '*'
          destinationPortRange: '500'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowIkeTraffic'
        properties: {
          protocol: 'Udp'
          sourcePortRange: '*'
          destinationPortRange: '4500'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
    ]
  }
}

// NSG for Bastion Subnet
resource bastionNsg 'Microsoft.Network/networkSecurityGroups@2023-02-01' = {
  name: hubSubnets[2].nsgName
  location: location
  tags: {
    environment: environment
    project: projectName
  }
  properties: {
    securityRules: [
      {
        name: 'AllowHttpsInbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowGatewayManagerInbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'GatewayManager'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowLoadBalancerInbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowBastionHostCommunicationInbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 130
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowBastionHostCommunicationOutbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowHttpsOutbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
          access: 'Allow'
          priority: 110
          direction: 'Outbound'
        }
      }
    ]
  }
}

// NSG for Private DNS Resolver Subnet
resource dnsResolverNsg 'Microsoft.Network/networkSecurityGroups@2023-02-01' = {
  name: hubSubnets[3].nsgName
  location: location
  tags: {
    environment: environment
    project: projectName
  }
  properties: {
    securityRules: [
      {
        name: 'AllowDnsTraffic'
        properties: {
          protocol: 'Udp'
          sourcePortRange: '*'
          destinationPortRange: '53'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowDnsTcpTraffic'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '53'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
    ]
  }
}

// NSG for Identity Subnet
resource identityNsg 'Microsoft.Network/networkSecurityGroups@2023-02-01' = {
  name: hubSubnets[4].nsgName
  location: location
  tags: {
    environment: environment
    project: projectName
  }
  properties: {
    securityRules: [
      {
        name: 'AllowFromSpokes'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: spokeVnetAddressSpace
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowFromHub'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: hubVnetAddressSpace
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyAllOther'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4096
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource hubManagementNsg 'Microsoft.Network/networkSecurityGroups@2023-02-01' = {
  name: hubSubnets[5].nsgName
  location: location
  tags: {
    environment: environment
    project: projectName
  }
  properties: {
    securityRules: [
      {
        name: 'AllowRDP'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: hubVnetAddressSpace
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowSSH'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: hubVnetAddressSpace
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowFromSpokes'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: spokeVnetAddressSpace
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
    ]
  }
}

// ====== NSGs - Spoke ======
resource infraNsg 'Microsoft.Network/networkSecurityGroups@2023-02-01' = {
  name: spokeSubnets[0].nsgName
  location: location
  tags: {
    environment: environment
    project: projectName
  }
  properties: {
    securityRules: [
      {
        name: 'AllowFromAppSubnet'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceApplicationSecurityGroups: [
            {
              id: appAsg.id
            }
          ]
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowFromDataSubnet'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceApplicationSecurityGroups: [
            {
              id: dataAsg.id
            }
          ]
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowFromHub'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: hubVnetAddressSpace
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyAll'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4096
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource appNsg 'Microsoft.Network/networkSecurityGroups@2023-02-01' = {
  name: spokeSubnets[1].nsgName
  location: location
  tags: {
    environment: environment
    project: projectName
  }
  properties: {
    securityRules: [
      {
        name: 'AllowHTTP'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowHTTPS'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowFromDataSubnet'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceApplicationSecurityGroups: [
            {
              id: dataAsg.id
            }
          ]
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowToDataSubnet'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationApplicationSecurityGroups: [
            {
              id: dataAsg.id
            }
          ]
          access: 'Allow'
          priority: 120
          direction: 'Outbound'
        }
      }
    ]
  }
}

resource dataNsg 'Microsoft.Network/networkSecurityGroups@2023-02-01' = {
  name: spokeSubnets[2].nsgName
  location: location
  tags: {
    environment: environment
    project: projectName
  }
  properties: {
    securityRules: [
      {
        name: 'AllowFromAppSubnet'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceApplicationSecurityGroups: [
            {
              id: appAsg.id
            }
          ]
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowFromInfra'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceApplicationSecurityGroups: [
            {
              id: infraAsg.id
            }
          ]
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyAll'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4096
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource paasNsg 'Microsoft.Network/networkSecurityGroups@2023-02-01' = {
  name: spokeSubnets[3].nsgName
  location: location
  tags: {
    environment: environment
    project: projectName
  }
  properties: {
    securityRules: [
      {
        name: 'AllowVnetTraffic'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
    ]
  }
}

// ====== User Defined Routes ======
// Application Security Groups for spoke workloads
resource infraAsg 'Microsoft.Network/applicationSecurityGroups@2023-02-01' = {
  name: '${projectName}-asg-infra'
  location: location
  tags: {
    environment: environment
    project: projectName
  }
}

resource appAsg 'Microsoft.Network/applicationSecurityGroups@2023-02-01' = {
  name: '${projectName}-asg-app'
  location: location
  tags: {
    environment: environment
    project: projectName
  }
}

resource dataAsg 'Microsoft.Network/applicationSecurityGroups@2023-02-01' = {
  name: '${projectName}-asg-data'
  location: location
  tags: {
    environment: environment
    project: projectName
  }
}

resource paasAsg 'Microsoft.Network/applicationSecurityGroups@2023-02-01' = {
  name: '${projectName}-asg-paas'
  location: location
  tags: {
    environment: environment
    project: projectName
  }
}
// UDR for Identity Subnet
resource identityUdr 'Microsoft.Network/routeTables@2023-02-01' = if(hubSubnets[4].routeTableName != '') {
  name: hubSubnets[4].routeTableName
  location: location
  tags: {
    environment: environment
    project: projectName
  }
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: 'ToSpoke'
        properties: {
          addressPrefix: spokeVnetAddressSpace
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewallPrivateIp
        }
      }
    ]
  }
}

// UDR for Management Subnet
resource managementUdr 'Microsoft.Network/routeTables@2023-02-01' = if(hubSubnets[5].routeTableName != '') {
  name: hubSubnets[5].routeTableName
  location: location
  tags: {
    environment: environment
    project: projectName
  }
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: 'ToSpoke'
        properties: {
          addressPrefix: spokeVnetAddressSpace
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewallPrivateIp
        }
      }
    ]
  }
}

resource infraUdr 'Microsoft.Network/routeTables@2023-02-01' = if(spokeSubnets[0].routeTableName != '') {
  name: spokeSubnets[0].routeTableName
  location: location
  tags: {
    environment: environment
    project: projectName
  }
  properties: {
    disableBgpRoutePropagation: true
    routes: [
      {
        name: 'DefaultRouteToFirewall'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewallPrivateIp
        }
      }
      {
        name: 'ToHub'
        properties: {
          addressPrefix: hubVnetAddressSpace
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewallPrivateIp
        }
      }
    ]
  }
}

resource appUdr 'Microsoft.Network/routeTables@2023-02-01' = if(spokeSubnets[1].routeTableName != '') {
  name: spokeSubnets[1].routeTableName
  location: location
  tags: {
    environment: environment
    project: projectName
  }
  properties: {
    disableBgpRoutePropagation: true
    routes: [
      {
        name: 'DefaultRouteToFirewall'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewallPrivateIp
        }
      }
      {
        name: 'ToHub'
        properties: {
          addressPrefix: hubVnetAddressSpace
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewallPrivateIp
        }
      }
    ]
  }
}

resource dataUdr 'Microsoft.Network/routeTables@2023-02-01' = if(spokeSubnets[2].routeTableName != '') {
  name: spokeSubnets[2].routeTableName
  location: location
  tags: {
    environment: environment
    project: projectName
  }
  properties: {
    disableBgpRoutePropagation: true
    routes: [
      {
        name: 'DefaultRouteToFirewall'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewallPrivateIp
        }
      }
      {
        name: 'ToHub'
        properties: {
          addressPrefix: hubVnetAddressSpace
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewallPrivateIp
        }
      }
    ]
  }
}

resource paasUdr 'Microsoft.Network/routeTables@2023-02-01' = if(spokeSubnets[3].routeTableName != '') {
  name: spokeSubnets[3].routeTableName
  location: location
  tags: {
    environment: environment
    project: projectName
  }
  properties: {
    disableBgpRoutePropagation: true
    routes: [
      {
        name: 'DefaultRouteToFirewall'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewallPrivateIp
        }
      }
      {
        name: 'ToHub'
        properties: {
          addressPrefix: hubVnetAddressSpace
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewallPrivateIp
        }
      }
    ]
  }
}

// ====== Hub VNet ======
resource hubVnet 'Microsoft.Network/virtualNetworks@2023-02-01' = {
  name: '${projectName}-hub-vnet'
  location: location
  tags: {
    environment: environment
    project: projectName
    role: 'hub'
  }
  properties: {
    addressSpace: {
      addressPrefixes: [
        hubVnetAddressSpace
      ]
    }
    subnets: [
      {
        name: hubSubnets[0].name
        properties: {
          addressPrefix: hubSubnets[0].addressPrefix
          // No NSG for AzureFirewallSubnet - Azure doesn't allow NSGs on firewall subnets
        }
      }
      {
        name: hubSubnets[1].name
        properties: {
          addressPrefix: hubSubnets[1].addressPrefix
          // No NSG for GatewaySubnet - Azure doesn't allow
        }
      }
      {
        name: hubSubnets[2].name
        properties: {
          addressPrefix: hubSubnets[2].addressPrefix
          networkSecurityGroup: {
            id: bastionNsg.id
          }
        }
      }
      {
        name: hubSubnets[3].name
        properties: {
          addressPrefix: hubSubnets[3].addressPrefix
          networkSecurityGroup: {
            id: dnsResolverNsg.id
          }
        }
      }
      {
        name: hubSubnets[4].name
        properties: {
          addressPrefix: hubSubnets[4].addressPrefix
          networkSecurityGroup: {
            id: identityNsg.id
          }
          routeTable: (hubSubnets[4].routeTableName != '') ? {
            id: identityUdr.id
          } : null
        }
      }
      {
        name: hubSubnets[5].name
        properties: {
          addressPrefix: hubSubnets[5].addressPrefix
          networkSecurityGroup: {
            id: hubManagementNsg.id
          }
          routeTable: (hubSubnets[5].routeTableName != '') ? {
            id: managementUdr.id
          } : null
        }
      }
    ]
  }
}

// ====== Spoke VNet ======
resource spokeVnet 'Microsoft.Network/virtualNetworks@2023-02-01' = {
  name: '${projectName}-spoke-vnet'
  location: location
  tags: {
    environment: environment
    project: projectName
    role: 'spoke'
  }
  properties: {
    addressSpace: {
      addressPrefixes: [
        spokeVnetAddressSpace
      ]
    }
    subnets: [
      {
        name: spokeSubnets[0].name
        properties: {
          addressPrefix: spokeSubnets[0].addressPrefix
          networkSecurityGroup: {
            id: infraNsg.id
          }
          routeTable: (spokeSubnets[0].routeTableName != '') ? {
            id: infraUdr.id
          } : null
        }
      }
      {
        name: spokeSubnets[1].name
        properties: {
          addressPrefix: spokeSubnets[1].addressPrefix
          networkSecurityGroup: {
            id: appNsg.id
          }
          routeTable: (spokeSubnets[1].routeTableName != '') ? {
            id: appUdr.id
          } : null
        }
      }
      {
        name: spokeSubnets[2].name
        properties: {
          addressPrefix: spokeSubnets[2].addressPrefix
          networkSecurityGroup: {
            id: dataNsg.id
          }
          routeTable: (spokeSubnets[2].routeTableName != '') ? {
            id: dataUdr.id
          } : null
        }
      }
      {
        name: spokeSubnets[3].name
        properties: {
          addressPrefix: spokeSubnets[3].addressPrefix
          networkSecurityGroup: {
            id: paasNsg.id
          }
          routeTable: (spokeSubnets[3].routeTableName != '') ? {
            id: paasUdr.id
          } : null
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
            }
            {
              service: 'Microsoft.KeyVault'
            }
          ]
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
    remoteVirtualNetwork: {
      id: spokeVnet.id
    }
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
    remoteVirtualNetwork: {
      id: hubVnet.id
    }
  }
}

// Outputs
output hubVnetId string = hubVnet.id
output spokeVnetId string = spokeVnet.id
output hubVnetName string = hubVnet.name
output spokeVnetName string = spokeVnet.name
// Hub Subnet Outputs
output firewallSubnetId string = '${hubVnet.id}/subnets/${hubSubnets[0].name}'
output gatewaySubnetId string = '${hubVnet.id}/subnets/${hubSubnets[1].name}'
output bastionSubnetId string = '${hubVnet.id}/subnets/${hubSubnets[2].name}'
output dnsResolverSubnetId string = '${hubVnet.id}/subnets/${hubSubnets[3].name}'
output identitySubnetId string = '${hubVnet.id}/subnets/${hubSubnets[4].name}'
output managementSubnetId string = '${hubVnet.id}/subnets/${hubSubnets[5].name}'
// Spoke Subnet Outputs
output infraSubnetId string = '${spokeVnet.id}/subnets/${spokeSubnets[0].name}'
output appSubnetId string = '${spokeVnet.id}/subnets/${spokeSubnets[1].name}'
output dataSubnetId string = '${spokeVnet.id}/subnets/${spokeSubnets[2].name}'
output paasSubnetId string = '${spokeVnet.id}/subnets/${spokeSubnets[3].name}'
// ASG Outputs
output infraAsgId string = infraAsg.id
output appAsgId string = appAsg.id
output dataAsgId string = dataAsg.id
output paasAsgId string = paasAsg.id
