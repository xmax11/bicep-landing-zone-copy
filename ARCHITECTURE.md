# Landing Zone Architecture - Visual Diagrams

## 1. High-Level Subscription Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          AZURE SUBSCRIPTION                                  │
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │        Resource Group: client-lz-005-rg-eastus2                     │   │
│  │                                                                      │   │
│  │  ┌──────────────────────────────────────────────────────────────┐  │   │
│  │  │                    HUB VNET                                   │  │   │
│  │  │              10.100.0.0/16 (eastus2)                          │  │   │
│  │  │                                                                │  │   │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌──────────────────────┐ │  │   │
│  │  │  │   AzFW      │  │   Bastion   │  │   DNS Resolver       │ │  │   │
│  │  │  │   Subnet    │  │   Subnet    │  │   Inbound Endpoint   │ │  │   │
│  │  │  │10.100.0/24  │  │10.100.2/26  │  │  10.100.1.4          │ │  │   │
│  │  │  └─────────────┘  └─────────────┘  └──────────────────────┘ │  │   │
│  │  │                                                                │  │   │
│  │  │  ┌─────────────┐        ┌───────────────────────────────┐    │  │   │
│  │  │  │  Identity   │        │  Management Subnet            │    │  │   │
│  │  │  │  Subnet     │        │  10.100.3.0/24 (Hub Test VM) │    │  │   │
│  │  │  │10.100.2/26  │        │                               │    │  │   │
│  │  │  └─────────────┘        └───────────────────────────────┘    │  │   │
│  │  │                                                                │  │   │
│  │  │  ╔════════════════════════════════════════════════════════╗  │  │   │
│  │  │  ║  AZURE FIREWALL (Standard)                             ║  │  │   │
│  │  │  ║  Private IP: 10.100.0.4                                ║  │  │   │
│  │  │  ║  • Allow internal hub/spoke                            ║  │  │   │
│  │  │  ║  • Allow Azure DNS (168.63.129.16:53)                 ║  │  │   │
│  │  │  ║  • Threat Intel: Deny Mode                             ║  │  │   │
│  │  │  ╚════════════════════════════════════════════════════════╝  │  │   │
│  │  └──────────────────────────────────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                           ↕ Peering ↕ Peering                                │
│  ┌─────────────────────────────┐  ┌──────────────────────────────┐         │
│  │   SPOKE 1 VNET              │  │   SPOKE 2 VNET               │         │
│  │   10.200.0.0/16             │  │   10.210.0.0/16              │         │
│  │                             │  │                              │         │
│  │ ┌───────────────────────┐   │  │ ┌──────────────────────┐    │         │
│  │ │ Infra: 10.200.0/24    │   │  │ │Infra: 10.210.0/24   │    │         │
│  │ │ • Spoke1-VM           │   │  │ │• Spoke2-VM          │    │         │
│  │ └───────────────────────┘   │  │ └──────────────────────┘    │         │
│  │                             │  │                              │         │
│  │ ┌───────────────────────┐   │  │ ┌──────────────────────┐    │         │
│  │ │ App: 10.200.1/24      │   │  │ │App: 10.210.1/24     │    │         │
│  │ │ (VNet Integrated)     │   │  │ │(Delegated Sub)      │    │         │
│  │ └───────────────────────┘   │  │ └──────────────────────┘    │         │
│  │                             │  │                              │         │
│  │ ┌───────────────────────┐   │  │ ┌──────────────────────┐    │         │
│  │ │ Data: 10.200.2/24     │   │  │ │Data: 10.210.2/24    │    │         │
│  │ └───────────────────────┘   │  │ └──────────────────────┘    │         │
│  │                             │  │                              │         │
│  │ ┌───────────────────────┐   │  │ ┌──────────────────────┐    │         │
│  │ │ PaaS: 10.200.3/24     │   │  │ │PaaS: 10.210.3/24    │    │         │
│  │ │ • Storage PE          │   │  │ │                      │    │         │
│  │ │ • Key Vault PE        │   │  │ │                      │    │         │
│  │ │ • (App Service PE)    │   │  │ │                      │    │         │
│  │ └───────────────────────┘   │  │ └──────────────────────┘    │         │
│  └─────────────────────────────┘  └──────────────────────────────┘         │
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  CENTRALIZED SERVICES (Hub Resource Group)                          │   │
│  │                                                                      │   │
│  │  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐ │   │
│  │  │ Log Analytics    │  │ Action Group     │  │ Private DNS      │ │   │
│  │  │ 30-day retention │  │ alerts@contoso   │  │ Zones (Hub-link) │ │   │
│  │  └──────────────────┘  └──────────────────┘  └──────────────────┘ │   │
│  │                                                                      │   │
│  │  ┌──────────────────┐  ┌──────────────────┐                        │   │
│  │  │ Key Vault        │  │ Storage Account  │                        │   │
│  │  │ (Spoke-placed)   │  │ (Spoke-placed)   │                        │   │
│  │  └──────────────────┘  └──────────────────┘                        │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ SUBSCRIPTION-LEVEL POLICIES (Disabled)                              │   │
│  │ • Inherit Project Tag                                               │   │
│  │ • Inherit Environment Tag                                           │   │
│  │ • Storage TLS 1.2 Enforcement                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                               │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Hub VNet Detailed Layout

```
┌──────────────────────────────────────────────────────────────────────────┐
│                     HUB VNET: 10.100.0.0/16                              │
│                                                                            │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │ AzureFirewallSubnet (10.100.0.0/24)                               │ │
│  │ • Azure Firewall deployed here                                     │ │
│  │ • Firewall Private IP: 10.100.0.4                                 │ │
│  │ • Public IP: {Dynamic - Standard SKU}                             │ │
│  │ • NSG: None (not applicable)                                      │ │
│  │ ┌────────────────────────────────────────────────────────────┐   │ │
│  │ │ FIREWALL POLICY - Rule Collection Groups (Priority order) │   │ │
│  │ │                                                             │   │ │
│  │ │ Priority 100: allow-internal-hub-spoke (NetworkRule)      │   │ │
│  │ │ ├─ Sources: Hub + Both Spokes                             │   │ │
│  │ │ ├─ Destinations: Hub + Both Spokes                        │   │ │
│  │ │ ├─ Protocols: Any                                         │   │ │
│  │ │ └─ Action: Allow                                          │   │ │
│  │ │                                                             │   │ │
│  │ │ Priority 200: allow-azure-dns (NetworkRule)               │   │ │
│  │ │ ├─ Sources: Hub + Both Spokes                             │   │ │
│  │ │ ├─ Destination: 168.63.129.16                             │   │ │
│  │ │ ├─ Port: 53 (TCP/UDP)                                     │   │ │
│  │ │ └─ Action: Allow                                          │   │ │
│  │ │                                                             │   │ │
│  │ │ Priority 250: demo-owasp-style-app-rules (AppRule)        │   │ │
│  │ │ ├─ OWASP rule: *.owasp.org                                │   │ │
│  │ │ ├─ Azure Updates: *.update.microsoft.com                  │   │ │
│  │ │ └─ Action: Allow                                          │   │ │
│  │ │                                                             │   │ │
│  │ │ Priority 300: allow-approved-egress (Conditional)         │   │ │
│  │ │ ├─ Only if allowedFirewallEgressCidrs is populated        │   │ │
│  │ │ └─ Action: Allow                                          │   │ │
│  │ │                                                             │   │ │
│  │ │ DEFAULT: Deny All                                         │   │ │
│  │ └────────────────────────────────────────────────────────────┘   │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                            │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │ AzureBastionSubnet (10.100.2.0/26)                                │ │
│  │ • Azure Bastion Host deployed here                                │ │
│  │ • Bastion Public IP: {Dynamic - Standard SKU}                     │ │
│  │ • NSG: None (required for Bastion)                                │ │
│  │ • Used for RDP/SSH access to VMs without public IPs              │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                            │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │ IdentitySubnet (10.100.2.128/26)                                  │ │
│  │ • Reserved for identity workloads (AD, AAD DS, etc.)              │ │
│  │ • NSG: hub-nsg-identity (Deny all by default)                     │ │
│  │ • UDR: hub-udr-identity (when firewall enabled)                   │ │
│  │ │  └─ Routes to spokes via firewall (10.100.0.4)                 │ │
│  │ • Currently unused in this deployment                             │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                            │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │ ManagementSubnet (10.100.3.0/24)                                  │ │
│  │ • Hub Test VM deployed here (when enabled)                        │ │
│  │ • NSG: hub-nsg-management (Deny all by default)                   │ │
│  │ • UDR: Skipped (bypassFirewallForManagement = true)               │ │
│  │ │  └─ Direct routing (no firewall) for faster mgmt access        │ │
│  │ • No route back through firewall (management bypass active)       │ │
│  │ ┌──────────────────────────────────────────────────────────────┐ │ │
│  │ │ Hub Test VM: client-lz-005-hub-test-vm                      │ │ │
│  │ │ • Image: Windows Server 2022 Datacenter G2                  │ │ │
│  │ │ • Size: D2s_v3 (2 vCPU, 8 GB RAM)                          │ │ │
│  │ │ • NIC: Dynamic private IP                                   │ │ │
│  │ │ • ManagedIdentity: SystemAssigned                           │ │ │
│  │ │ • Access: Bastion only (no public IP)                       │ │ │
│  │ │ • Role: Connectivity testing, temporary validation          │ │ │
│  │ └──────────────────────────────────────────────────────────────┘ │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                            │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │ PrivateDnsResolverSubnet (10.100.1.0/28)                          │ │
│  │ • DNS Private Resolver Inbound Endpoint deployed here             │ │
│  │ • Inbound Endpoint IP: 10.100.1.4 (derived from subnet)           │ │
│  │ • NSG: None (required for resolver)                               │ │
│  │ • Linked VNets: Hub only (spokes query via this IP)               │ │
│  │ • Outbound Endpoint: Not required (DNS forwarding optional)       │ │
│  │ • Purpose: Centralized DNS resolution for hub + spokes           │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                            │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Spoke 1 & 2 Detailed Layout (Identical Structure)

```
┌──────────────────────────────────────────────────────────────────────────┐
│           SPOKE 1: 10.200.0.0/16  |  SPOKE 2: 10.210.0.0/16             │
│                                                                            │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │ InfraSubnet (10.200.0.0/24 | 10.210.0.0/24)                      │ │
│  │ • Workload VMs (infrastructure tier)                              │ │
│  │ • NSG: spoke{N}-nsg-infra (Allow RDP 3389 from Hub)              │ │
│  │ • UDR: spoke{N}-udr-infra → Firewall for cross-spoke traffic    │ │
│  │ ┌──────────────────────────────────────────────────────────────┐ │ │
│  │ │ Workload VM: client-lz-005-spoke{N}-vm                       │ │ │
│  │ │ • Image: Windows Server 2022 Datacenter G2                   │ │ │
│  │ │ • Size: D2s_v3                                               │ │ │
│  │ │ • NIC: Dynamic private IP (e.g., 10.200.0.x)                │ │ │
│  │ │ • ManagedIdentity: SystemAssigned                            │ │ │
│  │ │ • Admin: azureuser (password provided at deploy time)        │ │ │
│  │ │ • Tags: environment, project, spoke, workloadType             │ │ │
│  │ └──────────────────────────────────────────────────────────────┘ │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                            │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │ AppSubnet (10.200.1.0/24 | 10.210.1.0/24)                        │ │
│  │ • Application servers tier                                        │ │
│  │ • Delegation: Microsoft.Web/serverFarms (Spoke 1 only)           │ │
│  │ • NSG: spoke{N}-nsg-app                                          │ │
│  │ │  └─ Allow HTTP (80), HTTPS (443) from Hub + other spoke      │ │
│  │ • UDR: spoke{N}-udr-app → Firewall for cross-spoke traffic     │ │
│  │ • Spoke 1: App Service Plan + Web App (if deploySpokeAppService)│ │
│  │ ┌──────────────────────────────────────────────────────────────┐ │ │
│  │ │ [OPTIONAL] App Service: client-lz-005-spoke1-app-{suffix}   │ │ │
│  │ │ • Plan: B1 Basic (1 instance) - configurable                │ │ │
│  │ │ • VNet Integration: Spoke1-AppSubnet                        │ │ │
│  │ │ • Public Access: Disabled                                   │ │ │
│  │ │ • HTTPS Only: True                                          │ │ │
│  │ │ • Architecture: .NET 6+ / Node.js / Python                 │ │ │
│  │ └──────────────────────────────────────────────────────────────┘ │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                            │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │ DataSubnet (10.200.2.0/24 | 10.210.2.0/24)                       │ │
│  │ • Database and data services tier                                │ │
│  │ • NSG: spoke{N}-nsg-data                                         │ │
│  │ │  └─ Allow MSSQL (1433), MySQL (3306) from App + other spoke  │ │
│  │ • UDR: spoke{N}-udr-data → Firewall for cross-spoke traffic    │ │
│  │ • Currently: No data resources deployed                         │ │
│  │ • Private Endpoint: Can add SQL Database/Cosmos to this subnet │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                            │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │ PaaSSvcSubnet (10.200.3.0/24 | 10.210.3.0/24)                    │ │
│  │ • Private Endpoints for managed services                         │ │
│  │ • NSG: spoke{N}-nsg-paas                                         │ │
│  │ │  └─ Allow HTTPS (443) from Hub + other spoke                 │ │
│  │ • UDR: spoke{N}-udr-paas → Firewall for cross-spoke traffic    │ │
│  │ │                                                                │ │
│  │ ┌──────────────────────────────────────────────────────────────┐ │ │
│  │ │ PRIVATE ENDPOINTS (Spoke 1 Only - Active)                    │ │ │
│  │ │                                                               │ │ │
│  │ │ Storage Account PE: client-lz-005-spoke-pe-storage          │ │ │
│  │ │ ├─ Target: {account}-spokest{suffix}                        │ │ │
│  │ │ ├─ Subresource: blob                                         │ │ │
│  │ │ ├─ Private IP: 10.200.3.x                                   │ │ │
│  │ │ ├─ DNS Zone: privatelink.blob.core.windows.net              │ │ │
│  │ │ └─ Records: blob.core.windows.net → 10.200.3.x             │ │ │
│  │ │                                                               │ │ │
│  │ │ Key Vault PE: client-lz-005-spoke-pe-keyvault              │ │ │
│  │ │ ├─ Target: {vaultname}-spokekv{suffix}                     │ │ │
│  │ │ ├─ Subresource: vault                                        │ │ │
│  │ │ ├─ Private IP: 10.200.3.y                                   │ │ │
│  │ │ ├─ DNS Zone: privatelink.vaultcore.azure.net               │ │ │
│  │ │ └─ Records: vaultname.vaultcore.azure.net → 10.200.3.y    │ │ │
│  │ │                                                               │ │ │
│  │ │ [OPTIONAL] SQL PE: client-lz-005-spoke-pe-sql              │ │ │
│  │ │ ├─ Only if sqlServerId provided                             │ │ │
│  │ │ ├─ DNS Zone: privatelink.database.windows.net              │ │ │
│  │ │ └─ Subresource: sqlServer                                    │ │ │
│  │ │                                                               │ │ │
│  │ │ [OPTIONAL] Cosmos DB PE: client-lz-005-spoke-pe-cosmosdb   │ │ │
│  │ │ ├─ Only if cosmosDbAccountId provided                       │ │ │
│  │ │ ├─ DNS Zone: privatelink.documents.azure.com               │ │ │
│  │ │ └─ Subresource: MongoDB/SQL/etc                             │ │ │
│  │ │                                                               │ │ │
│  │ │ [OPTIONAL] App Service PE: client-lz-005-spoke-pe-appservice│ │ │
│  │ │ ├─ Only if appServiceId provided & enabled                  │ │ │
│  │ │ ├─ DNS Zone: privatelink.azurewebsites.net                 │ │ │
│  │ │ └─ Subresource: sites                                        │ │ │
│  │ │                                                               │ │ │
│  │ └──────────────────────────────────────────────────────────────┘ │ │
│  │                                                                  │ │
│  │ ┌──────────────────────────────────────────────────────────────┐ │ │
│  │ │ APPLICATION SECURITY GROUPS (Defined but not active)         │ │ │
│  │ │ • client-lz-005-spoke{N}-infra-asg (infra tier VMs)        │ │ │
│  │ │ • client-lz-005-spoke{N}-app-asg (app tier VMs)            │ │ │
│  │ │ • client-lz-005-spoke{N}-data-asg (data tier services)     │ │ │
│  │ │ • client-lz-005-spoke{N}-paas-asg (PaaS endpoints)         │ │ │
│  │ │ → Use in NSG rules for flexible access management          │ │ │
│  │ └──────────────────────────────────────────────────────────────┘ │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                            │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## 4. DNS Resolution Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     DNS RESOLUTION ARCHITECTURE                         │
└─────────────────────────────────────────────────────────────────────────┘

SCENARIO 1: Spoke VM resolving Private Endpoint hostname
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Spoke 1 VM (10.200.0.x)
  │
  ├─► Query: "myaccount.blob.core.windows.net"
  │   (DNS Client → Configured DNS: 10.100.1.4)
  │
  └──────────────────────────────┐
                                 │
                    ┌────────────▼────────────┐
                    │ Hub DNS Resolver        │
                    │ Inbound: 10.100.1.4     │
                    │                         │
                    │ • Receives query        │
                    │ • Consults zones        │
                    └────────────┬────────────┘
                                 │
                    ┌────────────▼──────────────────┐
                    │ Private DNS Zone Query        │
                    │ Zone: privatelink.blob...     │
                    │ Record: myaccount.blob...     │
                    │ Points to: 10.200.3.4         │
                    │ (Private Endpoint IP)         │
                    └────────────┬──────────────────┘
                                 │
                    ┌────────────▼────────────┐
                    │ Response to VM          │
                    │ IP: 10.200.3.4 (PE)    │
                    └────────────┬────────────┘
                                 │
  Spoke 1 VM                      │
  ├─► Establishes connection to  │
  │   Storage Private Endpoint    │
  │   via 10.200.3.4 (private)    │
  │   NO internet routing needed  │
  └◄──────────────────────────────┘


SCENARIO 2: Azure Firewall DNS Proxy
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Spoke 1 VM (10.200.0.x)
  │
  ├─► Query: "update.microsoft.com"
  │   (Not in private DNS zones)
  │
  └──────────────────────────────┐
                                 │
                    ┌────────────▼────────────┐
                    │ Hub DNS Resolver        │
                    │ Inbound: 10.100.1.4     │
                    │                         │
                    │ • Receives query        │
                    │ • No zone match         │
                    │ • Uses conditional      │
                    │   forwarding to         │
                    │   Firewall DNS Proxy    │
                    └────────────┬────────────┘
                                 │
                    ┌────────────▼────────────┐
                    │ Azure Firewall          │
                    │ DNS Proxy Enabled       │
                    │                         │
                    │ • Intercepts DNS (53)   │
                    │ • Forwards to Azure DNS │
                    │ • Applies rules         │
                    │ • Logs queries          │
                    └────────────┬────────────┘
                                 │
                    ┌────────────▼────────────┐
                    │ Firewall Policy Check   │
                    │                         │
                    │ • Is FQDN allowed?      │
                    │ • YES: update...        │
                    │   (in allow rule)       │
                    │ • Response to VM        │
                    └────────────┬────────────┘
                                 │
  Spoke 1 VM                      │
  ├─► Receives IP for update.mx  │
  │   Connects via firewall       │
  │   (allowed by rule)           │
  └◄──────────────────────────────┘


CURRENT PRIVATE DNS ZONES (Hub-Linked Only)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  HUB VNet
  │
  ├─ privatelink.blob.core.windows.net
  │  └─ Linked to: Hub only
  │     Records: *.blob.core.windows.net → Private Endpoint IPs
  │
  ├─ privatelink.vaultcore.azure.net
  │  └─ Linked to: Hub only
  │     Records: *.vaultcore.azure.net → Private Endpoint IPs
  │
  ├─ privatelink.database.windows.net
  │  └─ Linked to: Hub only (if SQL PE enabled)
  │     Records: *.database.windows.net → Private Endpoint IP
  │
  ├─ privatelink.documents.azure.com
  │  └─ Linked to: Hub only (if Cosmos PE enabled)
  │     Records: *.documents.azure.com → Private Endpoint IP
  │
  ├─ privatelink.azurewebsites.net
  │  └─ Linked to: Hub only (if App Service enabled)
  │     Records: *.azurewebsites.net → Private Endpoint IP
  │
  └─ privatelink.file.core.windows.net
     └─ Linked to: Hub only
        Records: *.file.core.windows.net → Private Endpoint IPs

  SPOKES: Query via resolver → Hub resolver → Zone lookup → Response
```

---

## 5. Network Traffic Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                  TRAFFIC ROUTING & FIREWALL DECISION TREE               │
└─────────────────────────────────────────────────────────────────────────┘

SOURCE: Spoke 1 VM (10.200.0.x)
DESTINATION: Spoke 2 VM (10.210.0.x)
PROTOCOL: Any
────────────────────────────────────────────────────────────────────────

  Spoke 1 VM sends packet
  └─► Check routing table
      │
      ├─ Route to 10.210.0.0/16?
      │  └─ YES: Next hop = Firewall (10.100.0.4)
      │
      └─ Packet routed to Azure Firewall
         │
         ├─► Firewall Policy Rules (Priority order)
         │   │
         │   ├─ Priority 100: allow-internal-hub-spoke
         │   │  ├─ Source: 10.200.0.x (Spoke 1)
         │   │  ├─ Destination: 10.210.0.0/16 (Spoke 2)
         │   │  ├─ Protocol: Any
         │   │  └─ >>> MATCH: ALLOW ✓
         │   │
         │   └─ Packet forwarded to Spoke 2
         │      │
         │      └─ Spoke 2 VM (10.210.0.x) receives
         │         Response: Spoke 2 → Spoke 1 (same path)

────────────────────────────────────────────────────────────────────────

SOURCE: Spoke 1 VM (10.200.0.x)
DESTINATION: Internet (e.g., example.com)
PROTOCOL: HTTPS (443)
────────────────────────────────────────────────────────────────────────

  Case A: enableFirewallDefaultRoute = false (CURRENT)
  ──────────────────────────────────────────────────
  Spoke 1 VM sends packet to example.com
  └─► Check routing table
      │
      ├─ Route to 0.0.0.0/0?
      │  └─ NO: No default route in UDR
      │
      ├─ Route to example.com?
      │  └─ NO: No specific route
      │
      └─ Use system default route
         └─ Direct to internet (via Azure backbone)
            └─ Connection established (no firewall control)


  Case B: enableFirewallDefaultRoute = true (FUTURE OPTION)
  ──────────────────────────────────────────────────────────
  Spoke 1 VM sends packet to example.com
  └─► Check routing table
      │
      ├─ Route to 0.0.0.0/0?
      │  └─ YES: Next hop = Firewall (10.100.0.4)
      │
      └─ Packet routed to Azure Firewall
         │
         ├─► Firewall Policy Rules
         │   │
         │   ├─ Priority 100: allow-internal-hub-spoke
         │   │  └─ NO MATCH (destination is 0.0.0.0/0)
         │   │
         │   ├─ Priority 200: allow-azure-dns
         │   │  └─ NO MATCH (not Azure DNS)
         │   │
         │   ├─ Priority 250: demo-owasp-style-app-rules
         │   │  ├─ Is FQDN example.com in allowed list?
         │   │  └─ NO MATCH
         │   │
         │   ├─ Priority 300: allow-approved-egress-cidrs
         │   │  └─ NO MATCH (array is empty)
         │   │
         │   └─ DEFAULT: DENY ✗
         │
         └─ Packet dropped
            └─ Connection refused

────────────────────────────────────────────────────────────────────────

SOURCE: Hub Management Subnet (10.100.3.x)
DESTINATION: Storage Account Private Endpoint (10.200.3.4)
PROTOCOL: HTTPS (443)
────────────────────────────────────────────────────────────────────────

  bypassFirewallForManagement = true (CURRENT)
  ────────────────────────────────────────────
  Test VM sends packet to storage PE
  └─► Check routing table
      │
      ├─ Management subnet has NO UDR
      │  (bypassFirewallForManagement skips UDR creation)
      │
      ├─ Direct peering route to Spoke 1
      │
      └─ Packet routes directly to 10.200.3.4 (PE)
         └─ NO firewall processing
            └─ Direct access (fast, private link maintained)


  bypassFirewallForManagement = false (ALTERNATIVE)
  ──────────────────────────────────────────────────
  Test VM sends packet to storage PE
  └─► Check routing table
      │
      ├─ Management subnet HAS UDR
      │
      ├─ Route to 10.200.0.0/16 (Spoke 1)?
      │  └─ YES: Next hop = Firewall (10.100.0.4)
      │
      └─ Packet routed to Azure Firewall
         │
         ├─► Firewall Policy Rules
         │   │
         │   ├─ Priority 100: allow-internal-hub-spoke
         │   │  ├─ Source: 10.100.3.x (Hub Management)
         │   │  ├─ Destination: 10.200.3.4 (Spoke 1 PE)
         │   │  ├─ Protocol: TCP 443
         │   │  └─ >>> MATCH: ALLOW ✓
         │   │
         │   └─ Packet forwarded to Storage PE
         │
         └─ Storage PE receives request (via firewall)
            └─ Response returns same path
```

---

## 6. Resource Tagging Strategy

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        RESOURCE TAGGING HIERARCHY                       │
└─────────────────────────────────────────────────────────────────────────┘

ALL RESOURCES
│
├─ "environment": "production"
│  └─ Purpose: Environment classification (compliance, cost allocation)
│
├─ "project": "client-lz-005"
│  └─ Purpose: Project owner (multi-tenant billing, access control)
│
└─ "managedBy": "Bicep"
   └─ Purpose: IaC tracking (distinguishes from manual resources)


VNets & Subnets
├─ "role": "hub" | "spoke"
│  └─ Example: "role": "hub" for hub VNet
│
└─ "spoke": "1" | "2"
   └─ Example: "spoke": "1" (applies to Spoke 1 VNet/resources)


Virtual Machines
├─ "workloadType": "iaas-demo"
│  └─ Example: Workload VMs tagged with workload type
│
├─ "spoke": "1" | "2"
│  └─ Example: Spoke 1 VMs tagged to identify spoke membership
│
└─ "managedBy": "Bicep"
   └─ Inherited from compute module


Private DNS Zones
├─ "placement": "hub-vnet"
│  └─ Purpose: Indicate centralized hub placement
│
├─ "scope": "private-dns"
│  └─ Purpose: Service type classification
│
└─ "deploymentLocation": "eastus2"
   └─ Purpose: Regional tracking


Private Endpoints
├─ "placement": "spoke-vnet"
│  └─ Purpose: Spoke placement indicator
│
├─ "targetService": "storage" | "keyvault" | "sql" | "cosmosdb" | "appservice"
│  └─ Purpose: Target resource identification
│
└─ "scope": "private-endpoint"
   └─ Purpose: Resource type classification


COST ALLOCATION EXAMPLE
──────────────────────

Resource Group Filter:
  Tag: project = client-lz-005
  → Returns all resources in this landing zone

Spoke Breakdown:
  Tag: spoke = 1 OR spoke = 2
  → Separate cost analysis per spoke

Environment Filter:
  Tag: environment = production
  → Compliance & security analysis
```

---

## 7. Security Posture Visualization

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         SECURITY LAYERS                                 │
└─────────────────────────────────────────────────────────────────────────┘

LAYER 1: Network Perimeter
────────────────────────────

  ┌─────────────────────────────────────────┐
  │     AZURE FIREWALL (Hub)                │
  │     • Threat Intelligence: Deny Mode    │
  │     • DDoS Protection: Standard          │
  │     • Stateful inspection               │
  │     • Logs to Log Analytics             │
  │                                         │
  │  Rule Collections:                      │
  │  ┌──────────────────────────────────┐  │
  │  │ 1. Internal allow (hub/spoke)   │  │ ← Priority 100
  │  │ 2. Azure DNS allow               │  │ ← Priority 200
  │  │ 3. Demo OWASP rules              │  │ ← Priority 250
  │  │ 4. External CIDR allow           │  │ ← Priority 300
  │  │ 5. DEFAULT: DENY ALL             │  │ ← Default deny
  │  └──────────────────────────────────┘  │
  └─────────────────────────────────────────┘


LAYER 2: Network Segmentation (Subnets)
────────────────────────────────────────

  Hub:
  ┌──────────────────────────────────┐
  │ AzFirewall    AzBastion Identity │
  │   Subnet       Subnet   Subnet   │
  │  (Managed)   (Managed) (Isolated)│
  │                                  │
  │              Management          │
  │              Subnet (bypass)     │
  └──────────────────────────────────┘

  Spoke 1 & 2:
  ┌─────────────┐
  │   Infra     │  ← IaaS Workloads (VMs)
  │   AppNetwork│  ← Application tier
  │   Data      │  ← Database services
  │   PaaS      │  ← Private Endpoints
  └─────────────┘


LAYER 3: Access Control (NSGs & ASGs)
──────────────────────────────────────

  Each subnet protected by NSG:
  ┌──────────────────────────────────────┐
  │ NSG Rules (explicit allow by default)│
  │                                      │
  │ Inbound Rules:                       │
  │ ◌ RDP (3389) - Infra only            │
  │ ◌ HTTP (80) - App only               │
  │ ◌ HTTPS (443) - App/PaaS             │
  │ ◌ MSSQL (1433) - Data only           │
  │ ◌ All else: DENY                     │
  │                                      │
  │ Outbound Rules:                      │
  │ ◌ All allowed (unless restricted)    │
  └──────────────────────────────────────┘

  ASGs (defined, not active):
  ├─ infra-asg    (Infra tier VMs)
  ├─ app-asg      (App tier services)
  ├─ data-asg     (Data tier services)
  └─ paas-asg     (PaaS endpoints)


LAYER 4: Service Authentication
────────────────────────────────

  Key Vault:
  ├─ RBAC Enabled (no legacy access policies)
  ├─ Purge Protection: On
  ├─ Soft Delete: 7 days
  └─ Private Endpoint: Tunnel HTTPS only

  Storage Account:
  ├─ TLS 1.2 minimum enforced
  ├─ HTTPS only communication
  ├─ Public access disabled
  ├─ Network ACL: Deny by default
  │                (except AzureServices bypass)
  └─ Private Endpoint: Tunnel HTTPS only


LAYER 5: Monitoring & Auditing
───────────────────────────────

  Log Analytics Workspace:
  ├─ Key Vault audit logs
  ├─ Storage access logs
  ├─ Firewall logs & metrics
  ├─ App Service logs (if deployed)
  └─ 30-day retention

  Action Group:
  └─ Alert email: alerts@contoso.com


LAYER 6: Governance Policies (Disabled)
──────────────────────────────────────

  Available (can be enabled):
  ├─ Inherit Project Tag
  ├─ Inherit Environment Tag
  └─ Storage TLS 1.2 Enforcement

  → Activate by setting deployAzurePolicies = true


SECURITY POSTURE SUMMARY
─────────────────────────

  ✓ Network segmentation: 3-tier per spoke
  ✓ Firewall: Centralized perimeter control
  ✓ Private endpoints: No internet exposure
  ✓ RBAC: Key Vault + managed identities
  ✓ Encryption: TLS 1.2+ for all services
  ✓ Monitoring: All logs in single workspace
  ✗ Advanced threat protection: Not enabled (available upgrade)
  ✗ DDoS Premium: Using Standard (upgrade path available)
  ✗ Network Watcher: Not enabled (can be added)
```

---

## 8. State Diagram - Deployment Phases

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       DEPLOYMENT EXECUTION ORDER                        │
└─────────────────────────────────────────────────────────────────────────┘

main.bicep targetScope = 'subscription'
│
├─► Phase 1: Create Resource Group
│   │
│   └─ RG Name: client-lz-005-rg-eastus2
│      Status: Created / Reused
│      │
│      └─► Phase 2: Deploy Networking Module
│          └─► main.bicep → networking.bicep
│              │
│              ├─ Hub VNet (10.100.0.0/16)
│              │  ├─ AzureFirewallSubnet
│              │  ├─ AzureBastionSubnet
│              │  ├─ IdentitySubnet
│              │  ├─ ManagementSubnet
│              │  └─ PrivateDnsResolverSubnet
│              │
│              ├─ Spoke 1 VNet (10.200.0.0/16)
│              │  ├─ InfraSubnet
│              │  ├─ AppSubnet (delegated)
│              │  ├─ DataSubnet
│              │  └─ PaaSSvcSubnet
│              │
│              ├─ Spoke 2 VNet (10.210.0.0/16)
│              │  ├─ InfraSubnet
│              │  ├─ AppSubnet
│              │  ├─ DataSubnet
│              │  └─ PaaSSvcSubnet
│              │
│              ├─ Hub ↔ Spoke1 Peering
│              ├─ Hub ↔ Spoke2 Peering
│              │
│              ├─ NSGs (all subnets)
│              ├─ UDRs (all subnets, if firewall enabled)
│              ├─ ASGs (spokes only)
│              │
│              ├─ Azure Firewall (if enabled)
│              │  └─ Firewall Policy + Rule Collections
│              │
│              ├─ Azure Bastion (if enabled)
│              │
│              └─ DNS Private Resolver (if enabled)
│                 └─ Inbound Endpoint
│
│     Parallel Path 1: Deploy Security Module
│     │
│     ├─► security.bicep → Key Vault
│     │   └─ Stored in: Spoke 1 (conceptually)
│     │      Accessed via: Private Endpoint
│     │      Diagnostics: → Log Analytics
│     │
│     Parallel Path 2: Deploy Storage Module
│     │
│     ├─► storage.bicep → Storage Account
│     │   └─ Stored in: Spoke 1 (conceptually)
│     │      Accessed via: Private Endpoint
│     │      Containers: landing-zone, diagnostics
│     │      Diagnostics: → Log Analytics
│     │
│     Parallel Path 3: Deploy Monitoring Module
│     │
│     ├─► monitoring.bicep → Log Analytics (if enabled)
│     │   └─ Workspace: Hub-centralized
│     │      Action Group: If alert email provided
│     │      Retention: 30 days
│     │
│     Parallel Path 4: Deploy Private DNS Zones Module
│     │
│     ├─► private-dns-zones.bicep → DNS Zones (Hub)
│     │   └─ Zones:
│     │      ├─ privatelink.blob.core.windows.net
│     │      ├─ privatelink.vaultcore.azure.net
│     │      ├─ privatelink.database.windows.net
│     │      ├─ privatelink.documents.azure.com
│     │      ├─ privatelink.azurewebsites.net (conditional)
│     │      └─ privatelink.file.core.windows.net
│     │
│     Parallel Path 5: Deploy Private Endpoints Module
│     │
│     ├─► private-endpoints.bicep → PEs (Spoke 1 PaaS subnet)
│     │   └─ Endpoints:
│     │      ├─ Storage (always)
│     │      ├─ Key Vault (always)
│     │      ├─ SQL (conditional)
│     │      ├─ Cosmos DB (conditional)
│     │      └─ App Service (conditional)
│     │
│     ├─► Phase 3: Deploy Compute Module (if enabled)
│     │   │
│     │   ├─► compute.bicep → Workload VMs
│     │   │   └─ Spoke 1 Infra VM: client-lz-005-spoke1-vm
│     │   │   └─ Spoke 2 Infra VM: client-lz-005-spoke2-vm
│     │   │      • NICs created
│     │   │      • VM deployed with Windows Server 2022
│     │   │      • System Managed Identity assigned
│     │   │      • Boot diagnostics enabled
│     │   │
│     │   ├─► hub-test-vm.bicep → Hub Test VM (if enabled)
│     │   │   └─ Test VM: client-lz-005-hub-test-vm
│     │   │      • Subnet: Hub Management (10.100.3.0/24)
│     │   │      • Purpose: Connectivity validation
│     │   │      • Access: Bastion only
│     │   │
│     │   ├─► Phase 4: Deploy App Service Module (if enabled)
│     │   │   │
│     │   │   └─► app-service.bicep → App Service
│     │   │       └─ Plan: client-lz-005-spoke1-asp-{suffix}
│     │   │       └─ App: client-lz-005-spoke1-app-{suffix}
│     │   │          • Subnet: Spoke 1 AppSubnet (delegated)
│     │   │          • VNet Integration: Enabled
│     │   │          • Public Access: Disabled
│     │   │          • HTTPS Only: Enabled
│     │   │
│     │   └─► Phase 5: Deploy Policies Module (if enabled)
│     │       │
│     │       └─► policies.bicep → Policy Assignments
│     │           └─ Inherit Project Tag
│     │           └─ Inherit Environment Tag
│     │           └─ Storage TLS 1.2 Enforcement
│     │
│     └─ All modules complete
│
├─► Phase 6: Output Deployment Results
│   │
│   └─ Outputs:
│      ├─ Resource Group ID & Name
│      ├─ Hub VNet ID
│      ├─ Spoke 1 VNet ID
│      ├─ Spoke 2 VNet ID
│      ├─ Firewall Private IP (if deployed)
│      ├─ Bastion ID (if deployed)
│      ├─ DNS Resolver IP (if deployed)
│      ├─ Log Analytics ID (if deployed)
│      ├─ Key Vault ID & URI
│      ├─ Storage Account ID
│      ├─ App Service URLs (if deployed)
│      └─ VM Details (IDs, Private IPs, Names)
│
└─► Deployment Complete ✓

CRITICAL DEPENDENCIES
──────────────────────
1. Resource Group must exist before deploying modules
2. Networking (VNets/Subnets) must exist before Private Endpoints
3. Private Endpoints require Network Security Groups to allow traffic
4. Log Analytics must exist before diagnostic settings can reference it
5. Firewall must exist before UDRs can reference its private IP
6. Peering must be complete before cross-spoke routing works
```

---

## 9. Conditional Deployment Decision Tree

```
┌─────────────────────────────────────────────────────────────────────────┐
│              PARAMETERS → MODULE DEPLOYMENT DECISIONS                   │
└─────────────────────────────────────────────────────────────────────────┘

START: Execute main.bicep with parameters.json
│
├─ deployLogAnalytics = true
│  └─► DEPLOY: monitoring.bicep
│      ├─ Log Analytics Workspace
│      ├─ Action Group (if alertEmailAddress provided)
│      └─ Used by: Key Vault, Storage, Firewall diagnostics
│
├─ deployFirewall = true
│  └─► DEPLOY: Azure Firewall in Hub
│      ├─ Firewall Standard SKU
│      ├─ Firewall Policy with rule collections
│      ├─ Public IP for outbound NAT
│      └─ Triggers: UDR creation in all subnets
│
├─ deployBastion = true
│  └─► DEPLOY: Azure Bastion in Hub
│      ├─ Bastion Standard SKU
│      ├─ Public IP for management
│      └─ Enables RDP/SSH access to VMs
│
├─ deployPrivateDnsResolver = true
│  └─► DEPLOY: DNS Private Resolver in Hub
│      ├─ Inbound Endpoint (10.100.1.4)
│      └─ Spokes configured to use this IP
│
├─ deployWorkloadVms = true
│  └─► DEPLOY: compute.bicep
│      ├─ Spoke 1 Workload VM
│      └─ Spoke 2 Workload VM
│
├─ deployHubTestVm = true
│  └─► DEPLOY: hub-test-vm.bicep
│      └─ Hub Management Subnet Test VM
│
├─ deploySpokeAppService = true
│  └─► DEPLOY: app-service.bicep
│      ├─ App Service Plan (B1 or configured)
│      └─ App Service in Spoke 1 AppSubnet
│
├─ deployAzurePolicies = true
│  └─► DEPLOY: policies.bicep
│      ├─ Tag inheritance policies
│      └─ TLS enforcement policy
│
├─ firewall parameters (if deployFirewall = true)
│  │
│  ├─ enableFirewallDefaultRoute = true
│  │  └─► Spokes route 0.0.0.0/0 to firewall
│  │      (Currently FALSE → No default internet routing)
│  │
│  ├─ bypassFirewallForManagement = true
│  │  └─► Management subnet gets NO UDR
│  │      Direct access to private endpoints (no firewall)
│  │      (Currently TRUE → Direct management access)
│  │
│  ├─ allowedFirewallEgressCidrs = [ ]
│  │  └─► External CIDR destinations allowed
│  │      (Currently empty → No external CIDR rules)
│  │
│  └─ firewallThreatIntelMode = "Deny"
│     └─► Threat intelligence blocks denied traffic
│
├─ Private Endpoint Resource IDs (conditional)
│  │
│  ├─ sqlServerId = ""
│  │  └─► Empty = SQL PE NOT deployed
│  │      Provided = SQL PE created in Spoke 1 PaaS subnet
│  │
│  ├─ cosmosDbAccountId = ""
│  │  └─► Empty = Cosmos DB PE NOT deployed
│  │      Provided = Cosmos DB PE created
│  │
│  └─ appServiceId = ""
│     └─► Empty = App Service PE NOT deployed
│         Provided = App Service PE created
│
└─ CURRENT ACTIVE STATE (from parameters.json)
   │
   ├─ ✓ Networking: ALWAYS (hub + dual spokes)
   ├─ ✓ Log Analytics: Enabled
   ├─ ✓ Firewall: Enabled (but NOT forcing all traffic)
   ├─ ✓ Bastion: Enabled
   ├─ ✓ DNS Resolver: Enabled
   ├─ ✓ Workload VMs: Enabled (Spoke 1 & 2)
   ├─ ✓ Hub Test VM: Enabled
   ├─ ✗ App Service: Disabled
   ├─ ✗ Azure Policies: Disabled
   ├─ ✗ SQL PE: Disabled (no ID)
   ├─ ✗ Cosmos DB PE: Disabled (no ID)
   └─ All private DNS zones: Created (hub-only linked)
```

---

## 10. Post-Deployment Extension Points

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    LANDING ZONE EVOLUTION ROADMAP                       │
└─────────────────────────────────────────────────────────────────────────┘

PHASE 1: Current Deployment (Active)
════════════════════════════════════

Data Tier:
├─ SQL Database / Azure Database for MySQL
└─ Connect to Data subnet via private endpoint → PE in data subnet


PHASE 2: Enable App Service (Simple)
════════════════════════════════════

Action: Set deploySpokeAppService = true in parameters.json

Result:
├─ App Service Plan created in Spoke 1
├─ App Service deployed with VNet integration
├─ Private endpoint created automatically in Spoke 1 PaaS subnet
└─ DNS zone linked to hub + app deployed


PHASE 3: On-Premises Connectivity (Complex)
═════════════════════════════════════════════

Prerequisites:
├─ On-premises network (e.g., 192.168.0.0/16)
├─ ExpressRoute circuit or VPN gateway
└─ On-prem IT coordination

Steps:
├─ 1: Add GatewaySubnet to Hub VNet
│  └─ Add subnet 10.100.4.0/27 to hub
│
├─ 2: Deploy ExpressRoute or VPN Gateway
│  └─ Target subnet: GatewaySubnet
│  └─ Type: ExpressRoute (preferred) or VPN
│
├─ 3: Update Hub ↔ Spoke Peering
│  └─ allowGatewayTransit = true (hub peering)
│  └─ useRemoteGateways = true (spoke peering)
│
├─ 4: Update Firewall Policy
│  └─ Add rule collection: allow-onprem-{environment}
│  └─ Sources: Hub + Spokes
│  └─ Destination: On-prem CIDR (192.168.0.0/16)
│  └─ Action: Allow
│
├─ 5: Update Route Propagation
│  └─ Enable BGP on gateway
│  └─ Routes from on-prem auto-propagate to spokes
│
└─ Result: On-prem ↔ Hub ↔ Spoke bidirectional routing


PHASE 4: Multi-Region Hub-Spoke (Advanced)
════════════════════════════════════════════

Example: Deploy another landing zone in westus2

Architecture:
├─ Existing: eastus2 (Hub + 2 Spokes)
├─ New: westus2 (Hub + 2 Spokes)
├─ Connection: VNet peering or Virtual WAN
│
└─ Cross-Region Traffic:
   ├─ eastus2 Spoke1 → westus2 Spoke1
   ├─ Via: Firewall + Gateway + Peering
   └─ Routing: UDR in all spokes for cross-region


PHASE 5: Azure Firewall Manager & Virtual WAN
═════════════════════════════════════════════

Replace:
├─ Individual Firewall Policies (current)
├─ Manual VNet Peering (current)
├─ User-defined Routes (current)

With:
├─ Firewall Manager for centralized policy
├─ Virtual WAN for hub-spoke orchestration
├─ Automated routing at scale
└─ Multi-tenant support


PHASE 6: Container Orchestration
═════════════════════════════════

Add to App Service Subnet:
├─ Azure Container Registry (ACR)
├─ Azure Kubernetes Service (AKS)
│  └─ Cluster VNet Integration
│  └─ Private cluster endpoints
│  └─ Ingress via Application Gateway or Nginx
│
└─ Networking Changes:
   ├─ Expand AppSubnet CIDR (currently /24, may need /22)
   ├─ Add new AKS-specific NSG rules
   └─ Private endpoints for ACR


PHASE 7: Advanced Monitoring & Security
═════════════════════════════════════════

Upgrade from current:
├─ Log Analytics (30-day) → Azure Monitor (longer retention)
├─ Basic NSG rules → Azure Bastion network restrictions
├─ Standard Firewall → Premium Firewall
│  └─ Intrusion detection/prevention
│  └─ URL filtering
│  └─ Advanced threat protection
│
├─ Enable:
│  ├─ Network Watcher (packet capture, flow logs)
│  ├─ Azure Sentinel (SIEM)
│  ├─ Microsoft Defender for Cloud
│  └─ Azure Policy for compliance enforcement
│
└─ Result:
   ├─ Real-time threat detection
   ├─ Compliance auditing
   └─ Incident response automation


COMMON EXTENSION SCENARIOS
═══════════════════════════

Scenario 1: Add Database Server to Data Subnet
──────────────────────────────────────────────

1. Deploy Azure SQL Database / MySQL / PostgreSQL
2. Create private endpoint in Data subnet
3. Link private DNS zone (privatelink.database.windows.net)
4. Update DataSubnet NSG:
   ├─ Inbound: 1433 (SQL) from App subnet
   └─ Outbound: All
5. From App VM: Test ping / connection to private endpoint


Scenario 2: Add Spoke 3 (Third Workload Department)
────────────────────────────────────────────────────

1. Modify networking.bicep to include Spoke 3 VNet (10.220.0.0/16)
2. Create Spoke 3 hub peering (similar to Spoke 1 & 2)
3. Create Spoke 3 UDRs (firewall routes)
4. Create Spoke 3 NSGs (mimic Spoke 1 & 2)
5. Create Spoke 3 VMs (compute.bicep)
6. Create Spoke 3 private endpoints (if needed)


Scenario 3: Restrict Internet Access Further
─────────────────────────────────────────────

1. Enable enableFirewallDefaultRoute = true
2. Remove demo OWASP rules from firewall policy
3. Add strict rule for approved domains only:
   ├─ windows.net (Windows Update)
   ├─ github.com (Git operations)
   ├─ nuget.org (package management)
   └─ Deny everything else
4. Test from spoke VMs


Scenario 4: Implement Identity Subnet with AD
──────────────────────────────────────────────

1. Use IdentitySubnet (currently reserved)
2. Deploy Azure VMs:
   ├─ Active Directory Domain Controller
   ├─ Azure AD Connect (if hybrid)
   └─ Any other identity services
3. Update hub-nsg-identity:
   ├─ Inbound: Kerberos (88), LDAP (389), RDP (3389) from managed IPs
   └─ Outbound: DNS (53), LDAP (389) to identity services
4. Hub peering: Ensure spoke DNS clients can query identity servers
5. Update firewall policy: Route identity traffic directly


Scenario 5: Enable Spoke-to-Spoke Private Endpoint Access
──────────────────────────────────────────────────────────

Current: Private DNS zones linked to hub only
Goal: Spoke2 can access Spoke1 storage via PE

Steps:
1. Manually link DNS zones to all spokes:
   ├─ privatelink.blob.core.windows.net → Hub, Spoke 1, Spoke 2
   └─ privatelink.vaultcore.azure.net → Hub, Spoke 1, Spoke 2
2. Optionally create duplicate PEs in Spoke 2 PaaS subnet
3. Update firewall policy (current rule already allows):
   └─ Priority 100 rule: Spoke2 → Spoke1 PaaS subnet = ALLOW ✓
```

---

## 11. Troubleshooting Decision Tree

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         TROUBLESHOOTING FLOWS                           │
└─────────────────────────────────────────────────────────────────────────┘

ISSUE: Spoke VM cannot access Storage Account Private Endpoint
═════════════════════════════════════════════════════════════════

Step 1: Verify Network Connectivity
───────────────────────────────────
❌ Ping 10.200.3.4 fails from Spoke VM
│
├─ Check 1: Is PE correctly provisioned?
│  └─ Azure Portal → PE → Check status = Succeeded
│
├─ Check 2: Is subnet routable?
│  └─ Route table applied to PaaS subnet?
│  └─ No UDR blocking 10.200.3.0/24?
│
├─ Check 3: Is firewall blocking?
│  └─ Firewall enabled?
│  └─ Check firewall logs in Log Analytics
│  └─ Query: AzureDiagnostics | where Category == "AzureFirewallNetworkRule"
│
└─ Resolution:
   ├─ Verify PaaS subnet accessibility
   ├─ Check firewall rule collection priorities
   └─ Ensure rule 100 (allow-internal) is applied


Step 2: Verify DNS Resolution
──────────────────────────────
❌ nslookup myaccount.blob.core.windows.net fails or resolves to public IP
│
├─ Check 1: Is DNS resolver responding?
│  └─ nslookup 10.100.1.4 (from Spoke VM should list records)
│
├─ Check 2: Is DNS zone linked to hub?
│  └─ Azure Portal → Private DNS Zone → Virtual Network Links
│  └─ Should show: Hub VNet linked
│
├─ Check 3: Is hub resolver IP configured in spoke?
│  └─ Spoke VNet → DNS servers → Should be 10.100.1.4
│  └─ If default Azure DNS: Problem!
│
├─ Check 4: Is DNS record created?
│  └─ Azure Portal → Private DNS Zone → Record Sets
│  └─ Should show: A record for myaccount.blob... → 10.200.3.4
│
└─ Resolution:
   ├─ Verify spoke DNS server setting
   ├─ Verify DNS zone links
   ├─ Verify record sets in zone


Step 3: Verify Private Endpoint Configuration
──────────────────────────────────────────────
❌ PE created but DNS not resolving
│
├─ Check 1: Is PE in correct subnet?
│  └─ PE should be in PaaS subnet (10.200.3.x)
│
├─ Check 2: Is DNS zone group configured?
│  └─ PE → DNS Configuration → Zone groups
│  └─ Should be linked to privatelink.blob...
│
├─ Check 3: Is PE NIC attached to zone?
│  └─ PE → Network interface → IP config
│  └─ Should show private IP (10.200.3.x)
│
└─ Resolution:
   ├─ Recreate PE with correct subnet & zone group
   ├─ Verify zone group binding
   └─ Allow 5 minutes for DNS propagation


═════════════════════════════════════════════════════════════════════════

ISSUE: Cannot RDP to Spoke VM via Bastion
═════════════════════════════════════════════

Step 1: Verify Bastion Deployment
──────────────────────────────────
❌ Bastion host not available
│
├─ Check 1: Is deployBastion = true?
│  └─ Check parameters.json
│
├─ Check 2: Is Bastion subnet created?
│  └─ Hub → AzureBastionSubnet (10.100.2.0/26)
│
├─ Check 3: Is Bastion resource deployed?
│  └─ Azure Portal → Bastion → Check status = Succeeded
│
└─ Resolution:
   ├─ Set deployBastion = true and redeploy
   └─ Wait for Bastion provisioning (5-10 min)


Step 2: Verify VM & Networking
───────────────────────────────
❌ Bastion available but cannot connect
│
├─ Check 1: Is VM selected in Bastion?
│  └─ Azure Portal → Bastion → Connect
│  └─ Verify VM is in list
│
├─ Check 2: Does VM have network connectivity?
│  └─ VM → Networking → NIC → IP configurations
│  └─ Should show private IP (e.g., 10.200.0.x)
│
├─ Check 3: Is NSG allowing RDP inbound?
│  └─ Spoke NSG → Inbound rules
│  └─ Should allow TCP 3389 from:
│     └─ Azure Bastion service tag: AzureBastion
│
├─ Check 4: Is VM RDP service running?
│  └─ Cannot check without SSH/Bastion access
│  └─ If VM just created: Wait 5 min for boot
│
└─ Resolution:
   ├─ Verify NSG inbound rule for RDP
   ├─ Check VM boot status in Azure Portal
   └─ Verify VM admin credentials


═════════════════════════════════════════════════════════════════════════

ISSUE: Firewall logs showing DENY when traffic should be ALLOW
══════════════════════════════════════════════════════════════

Step 1: Identify the Denied Traffic
───────────────────────────────────
❌ Firewall is dropping traffic
│
├─ Check 1: Access firewall logs
│  └─ Log Analytics Workspace
│  └─ Query:
│     AzureDiagnostics
│     | where Category == "AzureFirewallNetworkRule"
│     | where Action == "Deny"
│
├─ Check 2: Identify source, destination, port
│  └─ Log output should show:
│     ├─ SourceIp
│     ├─ DestinationIp
│     ├─ DestinationPort
│     ├─ Protocol
│     └─ Action: Deny
│
└─ Next: Match traffic to rules


Step 2: Check Rule Collection Order
────────────────────────────────────
❌ Rule not matching
│
├─ Firewall rules evaluate by PRIORITY (lowest = first)
│
├─ Current order:
│  ├─ Priority 100: allow-internal-hub-spoke ← FIRST
│  ├─ Priority 200: allow-azure-dns
│  ├─ Priority 250: demo-owasp-rules
│  ├─ Priority 300: allow-approved-egress (if populated)
│  └─ Default: DENY ← LAST
│
├─ Check 3: Does traffic match rule 100?
│  └─ Source: Hub (10.100.x.x) + Spokes (10.200.x.x, 10.210.x.x)?
│  └─ Destination: Hub + Spokes?
│  └─ Protocol: Any?
│  └─ If YES to all: Should ALLOW
│
├─ Check 4: Is traffic Internet (0.0.0.0/0)?
│  └─ If enableFirewallDefaultRoute = false:
│     └─ NO UDR for default route in spokes
│     └─ Internet traffic bypasses firewall
│  └─ If enableFirewallDefaultRoute = true:
│     └─ Internet traffic routed to firewall
│     └─ Firewall rule 250 (OWASP) or default DENY applies
│
└─ Resolution:
   ├─ If internal traffic: Verify rule 100 source/dest
   ├─ If internet traffic: Add rule 250 or check default egress
   └─ Adjust rule priority if needed


Step 3: Update Firewall Policy
──────────────────────────────

To add a new allowed destination:

1. Option A: Modify rule 300 (allowedFirewallEgressCidrs)
   └─ Add CIDR to parameter: ["203.0.113.0/24"]
   └─ Re-deploy

2. Option B: Add new rule collection in firewall policy
   └─ Azure Portal → Firewall Policy → Rule Collection Groups
   └─ New collection: Priority 275
   └─ Add specific traffic pattern
   └─ Save

3. Option C: Whitelist domain in rule 250 (OWASP rules)
   └─ If traffic is to known domain
   └─ Query rule 250 for FQDN patterns
   └─ Add to allowedFqdnList


═════════════════════════════════════════════════════════════════════════

ISSUE: Spoke VM cannot reach Hub DNS Resolver
════════════════════════════════════════════════

Step 1: Verify Resolver Deployment
───────────────────────────────────
❌ DNS resolver unreachable
│
├─ Check 1: Is resolver enabled?
│  └─ deployPrivateDnsResolver = true?
│
├─ Check 2: Is resolver provisioned?
│  └─ Portal → DNS Private Resolver → Status = Succeeded
│
├─ Check 3: Is inbound endpoint created?
│  └─ Portal → DNS Resolver → Inbound endpoints
│  └─ Should show IP: 10.100.1.4
│
└─ Resolution:
   └─ Re-deploy with deployPrivateDnsResolver = true


Step 2: Verify Spoke DNS Configuration
───────────────────────────────────────
❌ Spoke VNet not configured to use resolver
│
├─ Check 1: Spoke VNet DNS servers
│  └─ Portal → Spoke VNet → DNS servers
│  └─ Should be: Custom: 10.100.1.4
│
├─ Check 2: VM DNS configuration
│  └─ From VM: ipconfig /all (Windows)
│  └─ Should show DNS server: 10.100.1.4
│
├─ Check 3: Test DNS from VM
│  └─ nslookup 8.8.8.8 10.100.1.4
│  └─ Or: Resolve-DnsName -Name 8.8.8.8 -Server 10.100.1.4
│
└─ Resolution:
   ├─ Verify spoke VNet DNS server setting
   ├─ May need to restart VM or restart network services
   └─ Test again


Step 3: Check Firewall Blocking DNS
────────────────────────────────────
❌ DNS queries blocked by firewall
│
├─ Check 1: Firewall rule 200 (allow-azure-dns)
│  └─ Has rule allowing UDP/TCP 53 to 168.63.129.16
│  └─ NOT blocking internal resolver (10.100.1.4)
│
├─ Check 2: Is resolver subnet isolated?
│  └─ PrivateDnsResolverSubnet (10.100.1.0/28)
│  └─ Has NSG blocking traffic?
│  └─ Inbound should allow UDP 53 from 0.0.0.0/0
│
├─ Check 3: Firewall logs
│  └─ AzureDiagnostics | where DestinationPort == 53 and Action == "Deny"
│  └─ Should be EMPTY (DNS allowed)
│
└─ Resolution:
   ├─ Remove NSG from resolver subnet (if blocking)
   ├─ Verify firewall rule allows 10.100.1.4 port 53
   └─ Test nslookup again
```

---           