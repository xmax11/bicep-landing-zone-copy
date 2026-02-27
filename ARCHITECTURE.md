# Landing Zone Architecture Documentation

## Table of Contents
1. [Overview](#overview)
2. [Architecture Principles](#architecture-principles)
3. [Network Design](#network-design)
4. [Security Architecture](#security-architecture)
5. [Monitoring & Logging](#monitoring--logging)
6. [Scalability & Expansion](#scalability--expansion)
7. [Design Decisions](#design-decisions)

## Overview

This landing zone provides a production-ready foundation for Azure deployments using a **Hub and Spoke network topology** with enterprise-grade security, compliance, and governance.

### Key Components
- **Hub VNet**: Central networking hub (10.100.0.0/16)
- **Spoke VNet**: Workload VNet (10.200.0.0/16)
- **Network Segmentation**: 10 isolated subnets (6 hub + 4 spoke)
- **Security**: NSGs, UDRs, Private DNS, Key Vault, Private Endpoints
- **Monitoring**: Centralized Log Analytics
- **Compliance**: Azure Policy baseline

### Deployment Organization
- **Organization**: Sinet Technologies
- **Project Name**: sinet-technologies-lz (sinet-lz3 in parameters)
- **Environment**: Production

---

## Architecture Principles

### 1. Zero Trust Network Architecture
- Default deny on all NSGs
- Explicit allow rules for required traffic
- Encrypted communication (TLS 1.2+)
- Private DNS for service discovery
- Private Endpoints for sensitive resources

### 2. Defense in Depth
```
┌─────────────────────────────────────┐
│ Perimeter (NSG + UDR)              │
├─────────────────────────────────────┤
│ VNet + Subnet (Network isolation)   │
├─────────────────────────────────────┤
│ Private Endpoints (Private access)  │
├─────────────────────────────────────┤
│ Service Endpoints (Controlled access)
├─────────────────────────────────────┤
│ Encryption (TLS, RBAC)             │
└─────────────────────────────────────┘
```

### 3. Separation of Concerns
- **Hub**: Network connectivity, security, management, identity
- **Spoke**: Workload deployment, application logic
- **Monitoring**: Centralized observability
- **Security**: Dedicated security resources

### 4. Scalability
- Single hub can connect multiple spokes
- Subnet space reserved for expansion
- Policy framework extensible for new rules
- Modular Bicep templates for easy updates

---

## Network Design

### VNet Topology: Hub and Spoke

#### Hub VNet (10.100.0.0/16)
**Purpose**: Central networking hub for all spokes

**Subnets**:
```
AzureFirewallSubnet      10.100.0.0/24    (Reserved for Azure Firewall or NVA)
├─ Purpose: North-South traffic control
├─ NSG Rules: Not attached (Azure limitation)
└─ No UDRs (Firewall is source of truth for routing)

GatewaySubnet           10.100.1.0/24    (VPN/ExpressRoute Gateway)
├─ Purpose: Site-to-site connectivity
├─ NSG Rules: Not attached (Azure limitation)
└─ No UDRs (Gateway handles routing)

BastionSubnet           10.100.2.0/26    (Azure Bastion host)
├─ Purpose: Secure RDP/SSH access
├─ NSG Rules: Allow from internet, deny all else
└─ Use Cases: Jumpbox, admin access

PrivateDnsResolverSubnet 10.100.2.64/26  (Private DNS Resolver)
├─ Purpose: DNS resolution for private endpoints
├─ NSG Rules: Allow from VNet
└─ Use Cases: DNS forwarding to Azure DNS

IdentitySubnet          10.100.2.128/26  (Identity services)
├─ Purpose: AD DS, domain controllers
├─ NSG Rules: Allow from management, spoke VNets
├─ UDR: Routes through firewall
└─ Use Cases: Azure AD DS, traditional AD

ManagementSubnet        10.100.3.0/24    (Ops, monitoring, tools)
├─ Purpose: Administrative and operational
├─ NSG Rules: RDP/SSH from bastion, allow from spokes
├─ UDR: Routes through firewall
└─ Use Cases: Jumpboxes, monitoring agents, automation
```

#### Spoke VNet (10.200.0.0/16)
**Purpose**: Hosts application workloads and services

**Subnets**:
```
InfraSubnet             10.200.0.0/24    (Infrastructure resources)
├─ Purpose: Core infra, middleware, databases
├─ NSG Rules: Accept from App, Data; allow from Hub
├─ UDR: Routes to Data through firewall
└─ Use Cases: Load balancers, cache servers, message queues

AppSubnet               10.200.1.0/24    (Application tier)
├─ Purpose: Business logic, web services
├─ NSG Rules: HTTP/HTTPS from internet, routable to Data
├─ UDR: Routes to Data through firewall
└─ Use Cases: App Service, Container instances, VMs

DataSubnet              10.200.2.0/24    (Data tier)
├─ Purpose: Databases, data stores
├─ NSG Rules: Allow only from App and Infra
├─ UDR: Routes to Hub
└─ Use Cases: SQL DB, CosmosDB, MySQL, PostgreSQL

PaaSSvcSubnet           10.200.3.0/24    (PaaS services)
├─ Purpose: Managed services with private endpoints
├─ NSG Rules: Allow VNet traffic only
├─ Service Endpoints: Storage, Key Vault
└─ Use Cases: Storage Accounts, Key Vaults, Service Bus
```

### Application Security Groups (ASGs)

This design leverages Application Security Groups to logically group workload VMs and services within the spoke VNet. ASGs (Infra, App, Data, PaaS) are created and NSG rules reference these ASGs instead of static IP prefixes, simplifying rule management as workloads scale or move.

### Network Traffic Flow

**Spoke-to-Hub (Egress)**
```
App Subnet (10.200.1.0/24)
    ↓ (Route: 10.100.0.0/16 → BGP/Gateway)
Hub Management Subnet (10.100.3.0/24)
    ↓ (Route: Internet → Firewall)
Azure Firewall (10.100.0.4) or NVA
    ↓
Internet / On-premises
```

**App-to-Data (East-West)**
```
App Subnet (10.200.1.0/24)
    ↓ (Route: 10.200.2.0/24 → NVA)
Firewall/NVA (10.200.1.4)
    ↓ (NS rules allow traffic)
Data Subnet (10.200.2.0/24)
```

**Internet-to-Hub (Ingress)**
```
Internet (N/S traffic)
    ↓ (Public IP on firewall)
Azure Firewall (10.100.0.4)
    ↓ (DNAT rules)
Management Subnet or Bastion
```

### IP Address Planning

**Hub VNet Breakdown**
- Total: 10.100.0.0/16 (65,536 IPs)
- AzureFirewall: 10.100.0.0/24 (256 IPs)
  - Usable: 251 IPs
  - Reserved for firewall instances
  
- Gateway: 10.100.1.0/24 (256 IPs)
  - Usable for VPN/ExpressRoute gateway
  
- Bastion: 10.100.2.0/26 (64 IPs)
  - Azure Bastion deployment
  
- PrivateDnsResolver: 10.100.2.64/26 (64 IPs)
  - DNS resolver instances
  
- Identity: 10.100.2.128/26 (64 IPs)
  - AD DS, domain controllers
  
- Management: 10.100.3.0/24 (256 IPs)
  - Jumpboxes, monitoring, automation

- Reserved: 10.100.4.0 - 10.100.255.0 (252 × /24)
  - For future expansion or additional regions

**Spoke VNet Breakdown**
- Total: 10.200.0.0/16 (65,536 IPs)
- Infra: 10.200.0.0/24 (256 IPs)
- App: 10.200.1.0/24 (256 IPs)
- Data: 10.200.2.0/24 (256 IPs)
- PaaS: 10.200.3.0/24 (256 IPs)
- Reserved: 10.200.4.0 - 10.200.255.0 (252 × /24)

**Scaling for Multiple Regions**
```
Region 1 (East US):
  Hub:   10.100.0.0/16
  Spoke: 10.200.0.0/16

Region 2 (West US):
  Hub:   10.110.0.0/16
  Spoke: 10.210.0.0/16

Region 3 (West Europe):
  Hub:   10.120.0.0/16
  Spoke: 10.220.0.0/16
```

---

## Security Architecture

### Network Security Groups (NSGs)

#### Hub Network Security Groups
| Subnet | NSG Name | Purpose |
|--------|----------|---------|
| AzureFirewallSubnet | (N/A) | Azure doesn't allow NSG |
| GatewaySubnet | (N/A) | Azure doesn't allow NSG |
| BastionSubnet | sinet-lz3-nsg-bastion | Bastion access control |
| PrivateDnsResolverSubnet | sinet-lz3-nsg-dnsresolver | DNS resolver rules |
| IdentitySubnet | sinet-lz3-nsg-identity | AD DS access |
| ManagementSubnet | sinet-lz3-nsg-management | Jumpbox access |

#### Spoke Network Security Groups
| Subnet | NSG Name | UDR Name |
|--------|----------|----------|
| InfraSubnet | sinet-lz3-nsg-infra | sinet-lz3-udr-infra |
| AppSubnet | sinet-lz3-nsg-app | sinet-lz3-udr-app |
| DataSubnet | sinet-lz3-nsg-data | sinet-lz3-udr-data |
| PaaSSvcSubnet | sinet-lz3-nsg-paas | sinet-lz3-udr-paas |

### User Defined Routes (UDRs)

**Purpose**: Override Azure default routing for advanced traffic control

**Routes Configuration**

```bicep
Identity Subnet UDR:
  Route Name: ToHub
  Address Prefix: 10.100.0.0/16
  Next Hop Type: VirtualGateway

  Route Name: ToSpoke
  Address Prefix: 10.200.0.0/16
  Next Hop Type: VirtualAppliance
  Next Hop IP: 10.100.0.4 (Firewall)

Management Subnet UDR:
  Route Name: ToSpoke
  Address Prefix: 10.200.0.0/16
  Next Hop Type: VirtualAppliance
  Next Hop IP: 10.100.0.4 (Firewall)

App Subnet UDR:
  Route Name: ToDataSubnet
  Address Prefix: 10.200.2.0/24
  Next Hop Type: VirtualAppliance
  Next Hop IP: 10.200.1.4 (NVA in app subnet)
  
  Route Name: ToHub
  Address Prefix: 10.100.0.0/16
  Next Hop Type: VirtualGateway

Data Subnet UDR:
  Route Name: ToHub
  Address Prefix: 10.100.0.0/16
  Next Hop Type: VirtualGateway

Infra Subnet UDR:
  Route Name: ToDataSubnet
  Address Prefix: 10.200.2.0/24
  Next Hop Type: VirtualAppliance
  Next Hop IP: 10.200.1.4
```

### Advanced Security Features

#### Private DNS Zones
Enables private name resolution for Azure PaaS services without exposing to public internet.

**Configured Zones**:
```
privatelink.blob.core.windows.net         (Azure Storage)
privatelink.vaultcore.azure.net          (Azure Key Vault)
privatelink.database.windows.net         (Azure SQL Database)
privatelink.azurewebsites.net            (Azure App Service)
privatelink.documents.azure.com          (Azure CosmosDB)
```

**Private Endpoint Integration**:
```
User Request
  ↓
Private DNS Zone (myservice.privatelink.blob.core.windows.net)
  ↓ (CNAME resolves to)
Private Endpoint (private IP in subnet)
  ↓
PaaS Service (via Microsoft backbone)
```

#### Private Endpoints

The landing zone deploys Private Endpoints for:
1. **Storage Account** - Located in PaaSSvcSubnet
   - Private DNS Zone Group links to privatelink.blob.core.windows.net
   
2. **Key Vault** - Located in PaaSSvcSubnet
   - Private DNS Zone Group links to privatelink.vaultcore.azure.net

#### Key Vault Security
```yaml
Network Security:
  - Soft Delete: 7 days (accidental deletion recovery)
  - Purge Protection: Enabled (prevents permanent deletion)
  - RBAC Authorization: Yes (modern access control)
  - TLS 1.2: Enforced
  
Access Control:
  - Access Policies: Array-based fine-grained permissions
  - RBAC: Azure AD groups and service principals
  - Firewall: IP-based access restrictions (or VNet)
```

#### Storage Account Security
```yaml
Network Configuration:
  - Default Action: Deny
  - Bypass: AzureServices (for Microsoft services)
  - Network Rules: Whitelist only allowed VNets/IPs
  
Data Security:
  - HTTPS Only: Enforced
  - Minimum TLS: 1.2
  - Public Blob Access: Disabled
  - Blob Versioning: Enabled
  - Soft Delete: 7 days
```

### Encryption Strategy

**In Transit**
- TLS 1.2 minimum for all communications
- IPsec for VPN connections
- Data encryption for ExpressRoute (optional)

**At Rest**
- Storage: Azure Storage Service Encryption (SSE-S)
- Databases: Transparent Data Encryption (TDE)
- Disks: Azure Disk Encryption (ADE)
- Key Vault: RBAC + network isolation

---

## Monitoring & Logging

### Log Analytics Architecture

```
Central Log Analytics Workspace
    ↓
Resource Diagnostic Settings
    ├─→ Azure Firewall logs
    ├─→ NSG flow logs
    ├─→ VNet peering logs
    ├─→ Key Vault audit logs
    ├─→ Storage account logs
    └─→ Application logs
    ↓
Log Aggregation & Analysis
    ├─ Queries
    ├─ Workbooks
    └─ Alerts
    ↓
Action Groups
    ├─ Email notifications (Lolu@sinettechnologies.com)
    ├─ SMS alerts (optional)
    └─ Webhooks (optional)
```

### Diagnostic Settings Configuration

**Enabled Logs**:
```yaml
Key Vault:
  - AuditEvent
  Retention: 30 days

Storage Account:
  - StorageRead
  - StorageWrite
  - StorageDelete
  Retention: 30 days

Virtual Networks:
  - AllMetrics
  Retention: 30 days
```

### Alerting Strategy

**Alert Rules**:
1. Service Disruption (Severity 1)
2. Resource Degradation (Severity 2)
3. Security Events (Severity 1)
4. Quota Warnings (Severity 3)

**Alert Actions**:
- Email to `Lolu@sinettechnologies.com`
- Webhook to ITSM system (optional)
- SMS for critical alerts (optional)

---

## Scalability & Expansion

### Adding New Spoke VNets

**Process**:
```
1. Create New Spoke VNet (e.g., 10.201.0.0/16)
2. Create Subnets (Infra, App, Data, PaaS pattern)
3. Create NSGs (same rules as existing spoke)
4. Create UDRs (route through hub firewall)
5. Peer with Hub:
   - Hub-to-Spoke (allow forwarded traffic, gateway transit)
   - Spoke-to-Hub (allow virtual network access)
6. Update firewall rules for new spoke CIDR
7. Link private DNS zones to new spoke
```

### Multi-Region Deployment

**Regional Hubs Connected via ExpressRoute/VPN**:
```
East US Region              West US Region
┌──────────────┐            ┌──────────────┐
│ Hub 10.100   │ ◄─ VPN ─► │ Hub 10.110   │
│ Spoke 10.200 │            │ Spoke 10.210 │
└──────────────┘            └──────────────┘
```

### Growth Planning

**Current Capacity**:
- Hub subnets: 253 additional /24 networks available
- Spoke subnets: 252 additional /24 networks available
- VNet peering: Unlimited spoke connections to hub

**Scaling Timeline**:
- Month 1-3: Single hub, 1 spoke, basic security
- Month 3-6: Add 2-3 additional spokes, enable all security features
- Month 6-12: Multi-region expansion, cross-region peering
- Year 2+: Add hub-to-hub connections, federated model

---

## Design Decisions

### 1. Hub and Spoke Over Mesh
**Why Hub and Spoke?**
- ✅ Simpler management (central firewall)
- ✅ Cost effective (fewer peerings)
- ✅ Easier security policies
- ❌ Hub becomes single point of failure (mitigated with redundancy)

### 2. /16 Networks Over /24
**Why /16?**
- ✅ Future expansion for +65,000 resources per region
- ✅ Subnets don't overlap across regions
- ❌ Larger address space (but not an issue in Azure)

### 3. /24 Subnets Over /25 or /26
**Why /24?**
- ✅ 251 usable IPs per subnet (enough for most workloads)
- ✅ Standard enterprise practice
- ✅ Easier to remember and manage

### 4. Private DNS Over Public DNS
**Why Private DNS?**
- ✅ DNS integration with Private Endpoints
- ✅ Prevents DNS exfiltration attacks
- ✅ Service discovery within VNet
- ❌ Requires management of DNS records

### 5. Azure Firewall Over NVA
**When to Use Azure Firewall**:
- ✅ Managed service (no patching)
- ✅ Built-in threat intelligence
- ✅ High availability
- ❌ More expensive than NVA

**When to Use NVA** (replaced with custom appliances):
- Regional firewall functionality needed
- Specific third-party integration
- Cost optimization for low volume

### 6. NSG Default Deny
**Why Default Deny?**
- ✅ Must explicitly allow traffic
- ✅ Reduces attack surface
- ✅ Enforces zero trust principles
- ❌ Requires careful rule management

### 7. Service Endpoints for PaaS Subnet
**Why Service Endpoints?**
- ✅ Traffic stays on Azure backbone (no internet egress)
- ✅ Reduced cost vs Azure Firewall outbound filtering
- ✅ Simpler than Private Endpoints for some services
- ❌ Limited to specific Azure services

### 8. Key Vault with RBAC
**Why RBAC Over Access Policies?**
- ✅ Modern identity model
- ✅ Conditional access support
- ✅ Easier multi-tenant management
- ❌ Still supports access policies for compatibility

### 9. Private Endpoints for Storage and Key Vault
**Why Private Endpoints?**
- ✅ Traffic stays on Azure backbone
- ✅ No public internet exposure
- ✅ DNS resolution via private zones
- ✅ Required for compliance and security

### 10. Azure Bastion Subnet
**Why Separate Bastion Subnet?**
- ✅ Managed RDP/SSH access
- ✅ No public IPs on VMs
- ✅ SSL-based access
- ✅ Reduced attack surface

---

## Module Architecture

### Main Template (main.bicep)
- **Purpose**: Orchestration and resource creation
- **Scope**: Subscription level
- **Creates**: Resource Group, modules orchestration, outputs

### Modules

| Module | File | Responsibilities |
|--------|------|------------------|
| Networking | modules/networking.bicep | VNets, Subnets, NSGs, UDRs, Peering |
| Monitoring | modules/monitoring.bicep | Log Analytics, Action Groups |
| Security | modules/security.bicep | Key Vault, Private DNS Zones |
| Storage | modules/storage.bicep | Storage Account, Blob Containers |
| Policies | modules/policies.bicep | Azure Policy Definitions, Initiatives |
| Private Endpoints | modules/private-endpoints.bicep | Private Endpoints for Storage & KV |

---

**Document Version**: 1.0.0  
**Last Updated**: February 26, 2026  
**Status**: Production Ready
