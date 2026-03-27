/*
  Networking Module - Hub and Dual-Spoke Topology
*/

param location string
param projectName string
param environment string
param hubVnetAddressSpace string = '10.100.0.0/16'
param spokeVnetAddressSpace string = '10.200.0.0/16'
param spoke2VnetAddressSpace string = '10.210.0.0/16'
@description('Private IP of NVA in hub (leave empty to use Azure Firewall private IP)')
param nvaPrivateIp string = ''
@description('Log Analytics Workspace ID for network diagnostics (leave empty to skip diagnostics)')
param logAnalyticsWorkspaceId string = ''
@description('Deploy Azure Firewall')
param deployFirewall bool = false
@description('Deploy Azure Bastion host in the hub VNet')
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

var commonTags = {
  environment: environment
  project: projectName
}

// Hub subnet CIDRs
var hubFirewallSubnetPrefix = cidrSubnet(hubVnetAddressSpace, 24, 0)
var hubBastionSubnetPrefix = cidrSubnet(hubVnetAddressSpace, 26, 8)
var hubIdentitySubnetPrefix = cidrSubnet(hubVnetAddressSpace, 26, 10)
var hubManagementSubnetPrefix = cidrSubnet(hubVnetAddressSpace, 24, 3)

// Spoke 1 subnet CIDRs
var spoke1InfraSubnetPrefix = cidrSubnet(spokeVnetAddressSpace, 24, 0)
var spoke1AppSubnetPrefix = cidrSubnet(spokeVnetAddressSpace, 24, 1)
var spoke1DataSubnetPrefix = cidrSubnet(spokeVnetAddressSpace, 24, 2)
var spoke1PaasSubnetPrefix = cidrSubnet(spokeVnetAddressSpace, 24, 3)

// Spoke 2 subnet CIDRs
var spoke2InfraSubnetPrefix = cidrSubnet(spoke2VnetAddressSpace, 24, 0)
var spoke2AppSubnetPrefix = cidrSubnet(spoke2VnetAddressSpace, 24, 1)
var spoke2DataSubnetPrefix = cidrSubnet(spoke2VnetAddressSpace, 24, 2)
var spoke2PaasSubnetPrefix = cidrSubnet(spoke2VnetAddressSpace, 24, 3)

var calculatedFirewallIp = cidrHost(hubFirewallSubnetPrefix, 4)
var nextHopIpAddress = !empty(nvaPrivateIp) ? nvaPrivateIp : calculatedFirewallIp
var trustedSourcePrefixes = [
  hubVnetAddressSpace
  spokeVnetAddressSpace
  spoke2VnetAddressSpace
]
var internalTransitPrefixes = [
  hubVnetAddressSpace
  spokeVnetAddressSpace
  spoke2VnetAddressSpace
]

// ====== Application Security Groups (Spoke 1) ======
resource infraAsg 'Microsoft.Network/applicationSecurityGroups@2023-02-01' = {
  name: '${projectName}-spoke1-infra-asg'
  location: location
  tags: commonTags
}

resource appAsg 'Microsoft.Network/applicationSecurityGroups@2023-02-01' = {
  name: '${projectName}-spoke1-app-asg'
  location: location
  tags: commonTags
}

resource dataAsg 'Microsoft.Network/applicationSecurityGroups@2023-02-01' = {
  name: '${projectName}-spoke1-data-asg'
  location: location
  tags: commonTags
}

resource paasAsg 'Microsoft.Network/applicationSecurityGroups@2023-02-01' = {
  name: '${projectName}-spoke1-paas-asg'
  location: location
  tags: commonTags
}

// ====== Hub NSGs ======
resource identityNsg 'Microsoft.Network/networkSecurityGroups@2023-02-01' = {
  name: '${projectName}-hub-nsg-identity'
  location: location
  tags: commonTags
}

resource hubManagementNsg 'Microsoft.Network/networkSecurityGroups@2023-02-01' = {
  name: '${projectName}-hub-nsg-management'
  location: location
  tags: commonTags
}

// ====== Spoke 1 NSGs ======
resource spoke1InfraNsg 'Microsoft.Network/networkSecurityGroups@2023-02-01' = {
  name: '${projectName}-spoke1-infra-nsg'
  location: location
  tags: commonTags
  properties: {
    securityRules: [
      {
        name: 'AllowRdpFromHub'
        properties: {
          description: 'Allow RDP from Hub VNet including Bastion subnet'
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
    ]
  }
}

resource spoke1AppNsg 'Microsoft.Network/networkSecurityGroups@2023-02-01' = {
  name: '${projectName}-spoke1-app-nsg'
  location: location
  tags: commonTags
  properties: {
    securityRules: [
      {
        name: 'AllowHttpFromHubAndSpokes'
        properties: {
          description: 'Allow HTTP from Hub VNet and Spoke2 for App Service access'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: hubVnetAddressSpace
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowHttpsFromHubAndSpokes'
        properties: {
          description: 'Allow HTTPS from Hub VNet and Spoke2 for App Service access'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: hubVnetAddressSpace
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowHttpFromSpoke2'
        properties: {
          description: 'Allow HTTP from Spoke2 VNet for cross-spoke App Service access'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: spoke2VnetAddressSpace
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowHttpsFromSpoke2'
        properties: {
          description: 'Allow HTTPS from Spoke2 VNet for cross-spoke App Service access'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: spoke2VnetAddressSpace
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 130
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource spoke1DataNsg 'Microsoft.Network/networkSecurityGroups@2023-02-01' = {
  name: '${projectName}-spoke1-data-nsg'
  location: location
  tags: commonTags
  properties: {
    securityRules: [
      {
        name: 'AllowMssqlFromHubAndSpokes'
        properties: {
          description: 'Allow MSSQL from Hub VNet and Spoke2 for data access'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '1433'
          sourceAddressPrefix: hubVnetAddressSpace
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowMssqlFromSpoke2'
        properties: {
          description: 'Allow MSSQL from Spoke2 VNet for cross-spoke data access'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '1433'
          sourceAddressPrefix: spoke2VnetAddressSpace
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource spoke1PaasNsg 'Microsoft.Network/networkSecurityGroups@2023-02-01' = {
  name: '${projectName}-spoke1-paas-nsg'
  location: location
  tags: commonTags
  properties: {
    securityRules: [
      {
        name: 'AllowHttpsFromHubAndSpokes'
        properties: {
          description: 'Allow HTTPS from Hub VNet and Spoke2 for Private Endpoint access'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: hubVnetAddressSpace
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowHttpsFromSpoke2'
        properties: {
          description: 'Allow HTTPS from Spoke2 VNet for cross-spoke Private Endpoint access'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: spoke2VnetAddressSpace
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
    ]
  }
}

// ====== Spoke 2 NSGs ======
resource spoke2InfraNsg 'Microsoft.Network/networkSecurityGroups@2023-02-01' = {
  name: '${projectName}-spoke2-infra-nsg'
  location: location
  tags: commonTags
  properties: {
    securityRules: [
      {
        name: 'AllowRdpFromHub'
        properties: {
          description: 'Allow RDP from Hub VNet including Bastion subnet'
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
    ]
  }
}

resource spoke2AppNsg 'Microsoft.Network/networkSecurityGroups@2023-02-01' = {
  name: '${projectName}-spoke2-app-nsg'
  location: location
  tags: commonTags
  properties: {
    securityRules: [
      {
        name: 'AllowHttpFromHubAndSpoke1'
        properties: {
          description: 'Allow HTTP from Hub VNet and Spoke1 for App Service access'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: hubVnetAddressSpace
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowHttpsFromHubAndSpoke1'
        properties: {
          description: 'Allow HTTPS from Hub VNet and Spoke1 for App Service access'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: hubVnetAddressSpace
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowHttpFromSpoke1'
        properties: {
          description: 'Allow HTTP from Spoke1 VNet for cross-spoke App Service access'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: spokeVnetAddressSpace
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowHttpsFromSpoke1'
        properties: {
          description: 'Allow HTTPS from Spoke1 VNet for cross-spoke App Service access'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: spokeVnetAddressSpace
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 130
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource spoke2DataNsg 'Microsoft.Network/networkSecurityGroups@2023-02-01' = {
  name: '${projectName}-spoke2-data-nsg'
  location: location
  tags: commonTags
  properties: {
    securityRules: [
      {
        name: 'AllowMssqlFromHubAndSpokes'
        properties: {
          description: 'Allow MSSQL from Hub VNet and Spoke1 for data access'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '1433'
          sourceAddressPrefix: hubVnetAddressSpace
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowMssqlFromSpoke1'
        properties: {
          description: 'Allow MSSQL from Spoke1 VNet for cross-spoke data access'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '1433'
          sourceAddressPrefix: spokeVnetAddressSpace
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource spoke2PaasNsg 'Microsoft.Network/networkSecurityGroups@2023-02-01' = {
  name: '${projectName}-spoke2-paas-nsg'
  location: location
  tags: commonTags
  properties: {
    securityRules: [
      {
        name: 'AllowHttpsFromHubAndSpokes'
        properties: {
          description: 'Allow HTTPS from Hub VNet and Spoke1 for Private Endpoint access'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: hubVnetAddressSpace
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowHttpsFromSpoke1'
        properties: {
          description: 'Allow HTTPS from Spoke1 VNet for cross-spoke Private Endpoint access'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: spokeVnetAddressSpace
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
    ]
  }
}

// ====== Hub UDRs ======
resource identityUdr 'Microsoft.Network/routeTables@2023-02-01' = {
  name: '${projectName}-hub-udr-identity'
  location: location
  tags: commonTags
  properties: {
    routes: deployFirewall ? [
      {
        name: 'ToSpoke1ViaHubFirewall'
        properties: {
          addressPrefix: spokeVnetAddressSpace
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: nextHopIpAddress
        }
      }
      {
        name: 'ToSpoke2ViaHubFirewall'
        properties: {
          addressPrefix: spoke2VnetAddressSpace
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: nextHopIpAddress
        }
      }
    ] : []
  }
}

resource managementUdr 'Microsoft.Network/routeTables@2023-02-01' = {
  name: '${projectName}-hub-udr-management'
  location: location
  tags: commonTags
  properties: {
    routes: deployFirewall ? [
      {
        name: 'ToSpoke1ViaHubFirewall'
        properties: {
          addressPrefix: spokeVnetAddressSpace
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: nextHopIpAddress
        }
      }
      {
        name: 'ToSpoke2ViaHubFirewall'
        properties: {
          addressPrefix: spoke2VnetAddressSpace
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: nextHopIpAddress
        }
      }
    ] : []
  }
}

// ====== Spoke 1 UDRs ======
resource spoke1InfraUdr 'Microsoft.Network/routeTables@2023-02-01' = {
  name: '${projectName}-spoke1-infra-udr'
  location: location
  tags: commonTags
  properties: {
    disableBgpRoutePropagation: true
    routes: deployFirewall ? concat(
      [
        {
          name: 'ToSpoke2ViaHubFirewall'
          properties: {
            addressPrefix: spoke2VnetAddressSpace
            nextHopType: 'VirtualAppliance'
            nextHopIpAddress: nextHopIpAddress
          }
        }
      ],
      enableFirewallDefaultRoute ? [
        {
          name: 'DefaultRouteToFirewall'
          properties: {
            addressPrefix: '0.0.0.0/0'
            nextHopType: 'VirtualAppliance'
            nextHopIpAddress: nextHopIpAddress
          }
        }
      ] : []
    ) : []
  }
}

resource spoke1AppUdr 'Microsoft.Network/routeTables@2023-02-01' = {
  name: '${projectName}-spoke1-app-udr'
  location: location
  tags: commonTags
  properties: {
    disableBgpRoutePropagation: true
    routes: deployFirewall ? concat(
      [
        {
          name: 'ToSpoke2ViaHubFirewall'
          properties: {
            addressPrefix: spoke2VnetAddressSpace
            nextHopType: 'VirtualAppliance'
            nextHopIpAddress: nextHopIpAddress
          }
        }
      ],
      enableFirewallDefaultRoute ? [
        {
          name: 'DefaultRouteToFirewall'
          properties: {
            addressPrefix: '0.0.0.0/0'
            nextHopType: 'VirtualAppliance'
            nextHopIpAddress: nextHopIpAddress
          }
        }
      ] : []
    ) : []
  }
}

resource spoke1DataUdr 'Microsoft.Network/routeTables@2023-02-01' = {
  name: '${projectName}-spoke1-data-udr'
  location: location
  tags: commonTags
  properties: {
    disableBgpRoutePropagation: true
    routes: deployFirewall ? concat(
      [
        {
          name: 'ToSpoke2ViaHubFirewall'
          properties: {
            addressPrefix: spoke2VnetAddressSpace
            nextHopType: 'VirtualAppliance'
            nextHopIpAddress: nextHopIpAddress
          }
        }
      ],
      enableFirewallDefaultRoute ? [
        {
          name: 'DefaultRouteToFirewall'
          properties: {
            addressPrefix: '0.0.0.0/0'
            nextHopType: 'VirtualAppliance'
            nextHopIpAddress: nextHopIpAddress
          }
        }
      ] : []
    ) : []
  }
}

resource spoke1PaasUdr 'Microsoft.Network/routeTables@2023-02-01' = {
  name: '${projectName}-spoke1-paas-udr'
  location: location
  tags: commonTags
  properties: {
    disableBgpRoutePropagation: true
    routes: deployFirewall ? concat(
      [
        {
          name: 'ToSpoke2ViaHubFirewall'
          properties: {
            addressPrefix: spoke2VnetAddressSpace
            nextHopType: 'VirtualAppliance'
            nextHopIpAddress: nextHopIpAddress
          }
        }
      ],
      enableFirewallDefaultRoute ? [
        {
          name: 'DefaultRouteToFirewall'
          properties: {
            addressPrefix: '0.0.0.0/0'
            nextHopType: 'VirtualAppliance'
            nextHopIpAddress: nextHopIpAddress
          }
        }
      ] : []
    ) : []
  }
}

// ====== Spoke 2 UDRs ======
resource spoke2InfraUdr 'Microsoft.Network/routeTables@2023-02-01' = {
  name: '${projectName}-spoke2-infra-udr'
  location: location
  tags: commonTags
  properties: {
    disableBgpRoutePropagation: true
    routes: deployFirewall ? concat(
      [
        {
          name: 'ToSpoke1ViaHubFirewall'
          properties: {
            addressPrefix: spokeVnetAddressSpace
            nextHopType: 'VirtualAppliance'
            nextHopIpAddress: nextHopIpAddress
          }
        }
      ],
      enableFirewallDefaultRoute ? [
        {
          name: 'DefaultRouteToFirewall'
          properties: {
            addressPrefix: '0.0.0.0/0'
            nextHopType: 'VirtualAppliance'
            nextHopIpAddress: nextHopIpAddress
          }
        }
      ] : []
    ) : []
  }
}

resource spoke2AppUdr 'Microsoft.Network/routeTables@2023-02-01' = {
  name: '${projectName}-spoke2-app-udr'
  location: location
  tags: commonTags
  properties: {
    disableBgpRoutePropagation: true
    routes: deployFirewall ? concat(
      [
        {
          name: 'ToSpoke1ViaHubFirewall'
          properties: {
            addressPrefix: spokeVnetAddressSpace
            nextHopType: 'VirtualAppliance'
            nextHopIpAddress: nextHopIpAddress
          }
        }
      ],
      enableFirewallDefaultRoute ? [
        {
          name: 'DefaultRouteToFirewall'
          properties: {
            addressPrefix: '0.0.0.0/0'
            nextHopType: 'VirtualAppliance'
            nextHopIpAddress: nextHopIpAddress
          }
        }
      ] : []
    ) : []
  }
}

resource spoke2DataUdr 'Microsoft.Network/routeTables@2023-02-01' = {
  name: '${projectName}-spoke2-data-udr'
  location: location
  tags: commonTags
  properties: {
    disableBgpRoutePropagation: true
    routes: deployFirewall ? concat(
      [
        {
          name: 'ToSpoke1ViaHubFirewall'
          properties: {
            addressPrefix: spokeVnetAddressSpace
            nextHopType: 'VirtualAppliance'
            nextHopIpAddress: nextHopIpAddress
          }
        }
      ],
      enableFirewallDefaultRoute ? [
        {
          name: 'DefaultRouteToFirewall'
          properties: {
            addressPrefix: '0.0.0.0/0'
            nextHopType: 'VirtualAppliance'
            nextHopIpAddress: nextHopIpAddress
          }
        }
      ] : []
    ) : []
  }
}

resource spoke2PaasUdr 'Microsoft.Network/routeTables@2023-02-01' = {
  name: '${projectName}-spoke2-paas-udr'
  location: location
  tags: commonTags
  properties: {
    disableBgpRoutePropagation: true
    routes: deployFirewall ? concat(
      [
        {
          name: 'ToSpoke1ViaHubFirewall'
          properties: {
            addressPrefix: spokeVnetAddressSpace
            nextHopType: 'VirtualAppliance'
            nextHopIpAddress: nextHopIpAddress
          }
        }
      ],
      enableFirewallDefaultRoute ? [
        {
          name: 'DefaultRouteToFirewall'
          properties: {
            addressPrefix: '0.0.0.0/0'
            nextHopType: 'VirtualAppliance'
            nextHopIpAddress: nextHopIpAddress
          }
        }
      ] : []
    ) : []
  }
}

// ====== Hub VNet ======
resource hubVnet 'Microsoft.Network/virtualNetworks@2023-02-01' = {
  name: '${projectName}-hub-vnet'
  location: location
  tags: union(commonTags, { role: 'hub' })
  properties: {
    addressSpace: {
      addressPrefixes: [
        hubVnetAddressSpace
      ]
    }
    subnets: [
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: hubFirewallSubnetPrefix
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: hubBastionSubnetPrefix
        }
      }
      {
        name: 'IdentitySubnet'
        properties: {
          addressPrefix: hubIdentitySubnetPrefix
          networkSecurityGroup: {
            id: identityNsg.id
          }
          routeTable: deployFirewall ? {
            id: identityUdr.id
          } : null
        }
      }
      {
        name: 'ManagementSubnet'
        properties: {
          addressPrefix: hubManagementSubnetPrefix
          networkSecurityGroup: {
            id: hubManagementNsg.id
          }
          routeTable: deployFirewall && !bypassFirewallForManagement ? {
            id: managementUdr.id
          } : null
        }
      }
    ]
  }
}

// ====== Azure Bastion ======
resource bastionPip 'Microsoft.Network/publicIPAddresses@2023-02-01' = if (deployBastion) {
  name: '${projectName}-hub-bastion-pip'
  location: location
  tags: commonTags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}

resource bastionHost 'Microsoft.Network/bastionHosts@2023-09-01' = if (deployBastion) {
  name: '${projectName}-hub-bastion'
  location: location
  tags: commonTags
  sku: {
    name: 'Basic'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'bastion-ipconfig'
        properties: {
          subnet: {
            id: '${hubVnet.id}/subnets/AzureBastionSubnet'
          }
          publicIPAddress: {
            id: bastionPip.id
          }
        }
      }
    ]
  }
}

// ====== Azure Firewall ======
resource firewallPip 'Microsoft.Network/publicIPAddresses@2023-02-01' = if (deployFirewall) {
  name: '${projectName}-hub-fw-pip'
  location: location
  tags: commonTags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}

resource firewallPolicy 'Microsoft.Network/firewallPolicies@2023-02-01' = if (deployFirewall) {
  name: '${projectName}-hub-fw-policy'
  location: location
  tags: commonTags
  properties: {
    threatIntelMode: firewallThreatIntelMode
    dnsSettings: {
      enableProxy: true
    }
  }
}

resource firewallPolicyRules 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-02-01' = if (deployFirewall) {
  parent: firewallPolicy
  name: 'default-secure-rules'
  properties: {
    priority: 100
    ruleCollections: concat(
      [
        {
          name: 'allow-internal-hub-spoke'
          priority: 100
          ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
          action: {
            type: 'Allow'
          }
          rules: [
            {
              ruleType: 'NetworkRule'
              name: 'allow-internal-hub-spoke-any'
              ipProtocols: [
                'Any'
              ]
              sourceAddresses: trustedSourcePrefixes
              destinationAddresses: internalTransitPrefixes
              destinationPorts: [
                '*'
              ]
            }
          ]
        }
        {
          name: 'allow-azure-dns'
          priority: 200
          ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
          action: {
            type: 'Allow'
          }
          rules: [
            {
              ruleType: 'NetworkRule'
              name: 'allow-azure-dns'
              ipProtocols: [
                'TCP'
                'UDP'
              ]
              sourceAddresses: trustedSourcePrefixes
              destinationAddresses: [
                '168.63.129.16'
              ]
              destinationPorts: [
                '53'
              ]
            }
          ]
        }
        {
          name: 'demo-owasp-style-app-rules'
          priority: 250
          ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
          action: {
            type: 'Allow'
          }
          rules: [
            {
              ruleType: 'ApplicationRule'
              name: 'allow-owasp-threat-protection'
              description: 'OWASP-style rule for common web threat categories (demo)'
              sourceAddresses: [
                spokeVnetAddressSpace
                spoke2VnetAddressSpace
              ]
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              targetFqdns: [
                'owasp.org'
                '*.owasp.org'
              ]
            }
            {
              ruleType: 'ApplicationRule'
              name: 'allow-azure-update-endpoints'
              description: 'OWASP-style rule for Azure update/management endpoints (demo)'
              sourceAddresses: [
                spokeVnetAddressSpace
                spoke2VnetAddressSpace
              ]
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              targetFqdns: [
                '*.update.microsoft.com'
                '*.download.windowsupdate.com'
              ]
            }
          ]
        }
      ],
      length(allowedFirewallEgressCidrs) > 0 ? [
        {
          name: 'allow-approved-egress-cidrs'
          priority: 300
          ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
          action: {
            type: 'Allow'
          }
          rules: [
            {
              ruleType: 'NetworkRule'
              name: 'allow-approved-egress'
              ipProtocols: [
                'Any'
              ]
              sourceAddresses: [
                spokeVnetAddressSpace
                spoke2VnetAddressSpace
              ]
              destinationAddresses: allowedFirewallEgressCidrs
              destinationPorts: [
                '*'
              ]
            }
          ]
        }
      ] : []
    )
  }
}

resource azureFirewall 'Microsoft.Network/azureFirewalls@2023-02-01' = if (deployFirewall) {
  name: '${projectName}-hub-azure-fw'
  location: location
  tags: commonTags
  properties: {
    firewallPolicy: {
      id: firewallPolicy.id
    }
    sku: {
      name: 'AZFW_VNet'
      tier: 'Standard'
    }
    ipConfigurations: [
      {
        name: 'azureFirewallIpConfiguration'
        properties: {
          subnet: {
            id: '${hubVnet.id}/subnets/AzureFirewallSubnet'
          }
          publicIPAddress: {
            id: firewallPip.id
          }
        }
      }
    ]
  }
}

resource firewallDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (deployFirewall && logAnalyticsWorkspaceId != '') {
  name: '${projectName}-hub-fw-diag'
  scope: azureFirewall
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

// ====== Spoke 1 VNet ======
resource spoke1Vnet 'Microsoft.Network/virtualNetworks@2023-02-01' = {
  name: '${projectName}-spoke1-vnet'
  location: location
  tags: union(commonTags, {
    role: 'spoke'
    spoke: '1'
  })
  properties: {
    addressSpace: {
      addressPrefixes: [
        spokeVnetAddressSpace
      ]
    }
    subnets: [
      {
        name: 'InfraSubnet'
        properties: {
          addressPrefix: spoke1InfraSubnetPrefix
          networkSecurityGroup: {
            id: spoke1InfraNsg.id
          }
          routeTable: deployFirewall ? {
            id: spoke1InfraUdr.id
          } : null
        }
      }
      {
        name: 'AppSubnet'
        properties: {
          addressPrefix: spoke1AppSubnetPrefix
          networkSecurityGroup: {
            id: spoke1AppNsg.id
          }
          routeTable: deployFirewall ? {
            id: spoke1AppUdr.id
          } : null
          delegations: [
            {
              name: 'appsvc-delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
      {
        name: 'DataSubnet'
        properties: {
          addressPrefix: spoke1DataSubnetPrefix
          networkSecurityGroup: {
            id: spoke1DataNsg.id
          }
          routeTable: deployFirewall ? {
            id: spoke1DataUdr.id
          } : null
        }
      }
      {
        name: 'PaaSSvcSubnet'
        properties: {
          addressPrefix: spoke1PaasSubnetPrefix
          networkSecurityGroup: {
            id: spoke1PaasNsg.id
          }
          routeTable: deployFirewall ? {
            id: spoke1PaasUdr.id
          } : null
        }
      }
    ]
  }
}

// ====== Spoke 2 VNet ======
resource spoke2Vnet 'Microsoft.Network/virtualNetworks@2023-02-01' = {
  name: '${projectName}-spoke2-vnet'
  location: location
  tags: union(commonTags, {
    role: 'spoke'
    spoke: '2'
  })
  properties: {
    addressSpace: {
      addressPrefixes: [
        spoke2VnetAddressSpace
      ]
    }
    subnets: [
      {
        name: 'InfraSubnet'
        properties: {
          addressPrefix: spoke2InfraSubnetPrefix
          networkSecurityGroup: {
            id: spoke2InfraNsg.id
          }
          routeTable: deployFirewall ? {
            id: spoke2InfraUdr.id
          } : null
        }
      }
      {
        name: 'AppSubnet'
        properties: {
          addressPrefix: spoke2AppSubnetPrefix
          networkSecurityGroup: {
            id: spoke2AppNsg.id
          }
          routeTable: deployFirewall ? {
            id: spoke2AppUdr.id
          } : null
        }
      }
      {
        name: 'DataSubnet'
        properties: {
          addressPrefix: spoke2DataSubnetPrefix
          networkSecurityGroup: {
            id: spoke2DataNsg.id
          }
          routeTable: deployFirewall ? {
            id: spoke2DataUdr.id
          } : null
        }
      }
      {
        name: 'PaaSSvcSubnet'
        properties: {
          addressPrefix: spoke2PaasSubnetPrefix
          networkSecurityGroup: {
            id: spoke2PaasNsg.id
          }
          routeTable: deployFirewall ? {
            id: spoke2PaasUdr.id
          } : null
        }
      }
    ]
  }
}

// ====== Hub <-> Spoke 1 Peering ======
resource hubToSpoke1Peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-02-01' = {
  parent: hubVnet
  name: '${projectName}-hub-to-spoke1'
  properties: {
    allowForwardedTraffic: true
    allowGatewayTransit: false
    allowVirtualNetworkAccess: true
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: spoke1Vnet.id
    }
  }
}

resource spoke1ToHubPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-02-01' = {
  parent: spoke1Vnet
  name: '${projectName}-spoke1-to-hub'
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

// ====== Hub <-> Spoke 2 Peering ======
resource hubToSpoke2Peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-02-01' = {
  parent: hubVnet
  name: '${projectName}-hub-to-spoke2'
  properties: {
    allowForwardedTraffic: true
    allowGatewayTransit: false
    allowVirtualNetworkAccess: true
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: spoke2Vnet.id
    }
  }
}

resource spoke2ToHubPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-02-01' = {
  parent: spoke2Vnet
  name: '${projectName}-spoke2-to-hub'
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

// ====== Outputs ======
output hubVnetId string = hubVnet.id
output spokeVnetId string = spoke1Vnet.id
output spoke1VnetId string = spoke1Vnet.id
output spoke2VnetId string = spoke2Vnet.id
output firewallId string = deployFirewall ? azureFirewall.id : ''
output firewallPrivateIpAddress string = deployFirewall ? azureFirewall!.properties.ipConfigurations[0].properties.privateIPAddress : ''
output bastionHostId string = deployBastion ? bastionHost!.id : ''

output infraAsgId string = infraAsg.id
output appAsgId string = appAsg.id
output dataAsgId string = dataAsg.id
output paasAsgId string = paasAsg.id

output spoke1InfraSubnetId string = '${spoke1Vnet.id}/subnets/InfraSubnet'
output spoke1AppSubnetId string = '${spoke1Vnet.id}/subnets/AppSubnet'
output spoke1PaasSubnetId string = '${spoke1Vnet.id}/subnets/PaaSSvcSubnet'
output spoke2InfraSubnetId string = '${spoke2Vnet.id}/subnets/InfraSubnet'
output spoke2AppSubnetId string = '${spoke2Vnet.id}/subnets/AppSubnet'
output spoke2PaasSubnetId string = '${spoke2Vnet.id}/subnets/PaaSSvcSubnet'

// Backward-compatible aliases
output paasSubnetId string = '${spoke1Vnet.id}/subnets/PaaSSvcSubnet'
output appSubnetId string = '${spoke1Vnet.id}/subnets/AppSubnet'
