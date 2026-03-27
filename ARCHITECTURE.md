# Landing Zone Architecture (Template Aligned)

This document is aligned to the deployed code in:
- `main.bicep`
- `modules/networking.bicep`
- `modules/monitoring.bicep`
- `modules/security.bicep`
- `modules/storage.bicep`
- `modules/private-dns-zones.bicep`
- `modules/private-endpoints.bicep`
- `modules/policies.bicep`

## 1. What This Template Deploys

The template deploys a subscription-scoped Azure landing zone with a hub-and-spoke network model:
- One resource group for all resource-group scoped resources.
- One Hub VNet for shared network services.
- One Spoke VNet for workloads.
- Optional Azure Firewall (Standard SKU).
- Optional Hub Transit Gateway (Virtual Network Gateway) for gateway transit.
- Optional Hub Azure DNS Private Resolver with inbound endpoint for on-prem forwarding.
- Central private DNS zones hosted in hub scope and linked to both hub and spoke VNets.
- Private endpoints for Storage and Key Vault by default.
- Optional monitoring and optional policy assignments.

## 2. Deployment Scopes and Module Ownership

`main.bicep` uses `targetScope = 'subscription'`.

Resource creation flow:
1. Create resource group: `{projectName}-rg-{location}`.
2. Deploy resource-group modules:
   - `networking.bicep`
   - `monitoring.bicep` (if `deployLogAnalytics = true`)
   - `security.bicep`
   - `storage.bicep`
   - `private-dns-zones.bicep`
   - `private-endpoints.bicep`
3. Deploy subscription module:
   - `policies.bicep` (if `deployAzurePolicies = true`)

## 3. Network Topology

### Hub VNet

- Name: `{projectName}-hub-vnet`
- Address space default: `10.100.0.0/16`
- Subnets:
  - `AzureFirewallSubnet` (`/24`)
  - `GatewaySubnet` (`/24`)
  - `BastionSubnet` (`/26`)
  - `PrivateDnsResolverSubnet` (`/26`)
  - `IdentitySubnet` (`/26`)
  - `ManagementSubnet` (`/24`)

### Spoke VNet

- Name: `{projectName}-spoke-infra-vnet`
- Address space default: `10.200.0.0/16`
- Subnets:
  - `InfraSubnet` (`/24`)
  - `AppSubnet` (`/24`)
  - `DataSubnet` (`/24`)
  - `PaaSSvcSubnet` (`/24`)

## 4. Communication and Routing Model

### 4.1 Base Connectivity

Bidirectional peering is always created between hub and spoke:
- Hub to spoke peering:
  - `allowForwardedTraffic = true`
  - `allowGatewayTransit = enableTransitRouting`
- Spoke to hub peering:
  - `allowForwardedTraffic = true`
  - `useRemoteGateways = enableTransitRouting`

### 4.2 Transit Gateway Behavior

A hub transit gateway is deployed only when both are true:
- `enableTransitRouting = true`
- `deployTransitGateway = true`

Deployed resources:
- `{projectName}-hub-vpngw-pip` (Standard public IP)
- `{projectName}-hub-vpngw` (VPN, RouteBased Virtual Network Gateway)

Important:
- This is a **Virtual Network Gateway**, not a Virtual WAN hub router.
- On-prem objects (local network gateway, VPN connection, ER connection) are not part of this template.

### 4.3 UDR and Traffic Steering

Hub route tables:
- `IdentitySubnet` is associated with UDR only when `deployFirewall = true`.
- `ManagementSubnet` UDR association is controlled by `bypassFirewallForManagement`.
- Their `ToSpoke` route uses next hop `VirtualAppliance` to `nvaIpAddress`.

Spoke route tables:
- UDRs are attached to all four spoke subnets only when `deployFirewall = true`.
- `disableBgpRoutePropagation = !enableTransitRouting`.
- Optional default route to firewall when `enableFirewallDefaultRoute = true`.
- Additional routes to firewall for each prefix in `transitDestinationPrefixes`.

### 4.4 Hub-to-Spoke and Spoke-to-Spoke Outcomes

- Hub to spoke communication works over peering regardless of firewall deployment.
- Spoke-to-spoke through hub requires transit design:
  - Gateway-transit path requires `enableTransitRouting = true` plus a working hub gateway.
  - Firewall-steered spoke-to-spoke path requires destination prefixes in `transitDestinationPrefixes` and matching firewall allow rules.
- If traffic goes through firewall for spoke-to-spoke, it is still hub transit from an architecture perspective, but it is **UDR + firewall forwarding**, not native peering transitivity alone.

## 5. Firewall Design and Security Behavior

### 5.1 Firewall Deployment

When `deployFirewall = true`:
- Firewall public IP is created as Standard SKU.
- Azure Firewall is deployed with:
  - SKU name: `AZFW_VNet`
  - Tier: `Standard`
- Firewall policy is attached.

### 5.2 Firewall Policy Baseline

Configured policy behavior:
- Threat intel mode from `firewallThreatIntelMode` (`Deny` by default).
- DNS proxy enabled.
- Rule collection group `default-secure-rules` includes:
  - `allow-internal-transit` for hub/spoke/transit prefixes.
  - `allow-azure-dns` to `168.63.129.16` on TCP/UDP 53.
  - `allow-approved-egress-cidrs` only when `allowedFirewallEgressCidrs` has values.
- Any traffic not matching allow rules is implicitly denied.

### 5.3 Security Controls by Resource Type

Network:
- NSGs are deployed for hub/spoke subnets.
- No explicit NSG rule resources are defined; default NSG rules apply unless extended.

Key Vault:
- RBAC authorization enabled.
- Purge protection enabled.
- Soft delete retention configured.

Storage:
- HTTPS only.
- TLS minimum 1.2.
- Public blob access disabled.
- Network ACL default action set to `Deny`.

## 6. Private DNS and Private Endpoint Model

### 6.1 Private DNS (Hub Hosted)

Private DNS zones are deployed centrally and tagged:
- `role: hub-dns-zone`
- `placement: hub-vnet`
- `scope: private-dns`

Zones include:
- `privatelink.blob.core.windows.net`
- `privatelink.file.core.windows.net`
- `privatelink.queue.core.windows.net`
- `privatelink.table.core.windows.net`
- `privatelink.vaultcore.azure.net`
- `privatelink.database.windows.net`
- `privatelink.azurewebsites.net`
- `privatelink.web.azurewebsites.net`
- `privatelink.documents.azure.com`

Each zone creates two links:
- `...-link-hub-vnet`
- `...-link-spoke-vnet`

### 6.2 Private Endpoints

Private endpoints are placed in spoke `PaaSSvcSubnet`:
- Always created:
  - `{projectName}-spoke-pe-storage` (blob)
  - `{projectName}-spoke-pe-keyvault` (vault)
- Conditionally created if IDs are passed:
  - SQL
  - Cosmos DB
  - App Service

### 6.3 On-Prem DNS Forwarding Pattern

When `deployPrivateDnsResolver = true`:
- A hub DNS resolver and inbound endpoint are deployed in `PrivateDnsResolverSubnet`.
- Deployment outputs expose the inbound endpoint IP.
- On-prem DNS conditional forwarder target should be this inbound IP for `azure.com` (as requested).

With `bypassFirewallForManagement = true`:
- `ManagementSubnet` does not attach firewall UDR.
- Management access to Key Vault private endpoint uses private routing over peering/private link path instead of firewall hairpin.

## 7. Monitoring and Governance

Monitoring (`deployLogAnalytics = true`):
- Log Analytics workspace.
- Action group if `alertEmailAddress` is not empty.
- Diagnostics for:
  - Key Vault
  - Storage blob service
  - Firewall (if firewall is enabled)

Governance (`deployAzurePolicies = true`):
- Subscription-level policy assignments for:
  - Inherit `project` tag.
  - Inherit `environment` tag.
  - Enforce TLS 1.2 for storage.

## 8. Naming Convention in the Template

Placement-aware naming is used where Azure permits:
- Hub network resource pattern: `{projectName}-hub-*`
- Spoke workload resource pattern: `{projectName}-spoke-*`
- DNS links explicitly include VNet placement:
  - `...-link-hub-vnet`
  - `...-link-spoke-vnet`

Azure-constrained names include spoke context in generated values:
- Key Vault: `{normalizedProjectName}spokekv{uniqueSuffix}`
- Storage: `{normalizedProjectName}spokest{uniqueSuffix}`

## 9. Parameter Decision Matrix

- `deployFirewall`:
  - `true`: deploy firewall and attach firewall policy.
  - `false`: no firewall in path, no subnet UDR associations.
- `enableFirewallDefaultRoute`:
  - `true`: spoke default route (`0.0.0.0/0`) points to firewall.
  - `false`: no forced default egress through firewall.
- `transitDestinationPrefixes`:
  - Adds explicit destination routes via firewall for east-west or custom transit paths.
- `enableTransitRouting`:
  - Enables peering gateway transit flags and BGP route propagation in spoke UDRs.
- `deployTransitGateway`:
  - Creates hub virtual network gateway only when transit is enabled.
- `deployPrivateDnsResolver`:
  - Deploys `Microsoft.Network/dnsResolvers` in hub VNet.
- `privateDnsResolverInboundIp`:
  - Optional static inbound endpoint IP; empty means dynamic allocation.
- `bypassFirewallForManagement`:
  - Keeps ManagementSubnet direct to private endpoints and bypasses firewall route table attachment.

## 10. Current Runtime Profile (`parameters.json`)

Current values in this repo:
- `projectName = client-lz`
- `location = eastus`
- `deployFirewall = true`
- `deployTransitGateway = true`
- `enableTransitRouting = true`
- `enableFirewallDefaultRoute = false`
- `transitDestinationPrefixes = []`
- `deployPrivateDnsResolver = true`
- `privateDnsResolverInboundIp = ""` (dynamic)
- `bypassFirewallForManagement = true`
- `firewallThreatIntelMode = Deny`
- `allowedFirewallEgressCidrs = []`
- `deployLogAnalytics = true`
- `deployAzurePolicies = false`

Interpretation of current profile:
- Firewall is deployed, but default spoke internet egress is not forced through firewall.
- Transit gateway exists for gateway transit scenarios.
- Spoke-to-spoke firewall-steered routes are not active until `transitDestinationPrefixes` is populated.
- Hub DNS resolver inbound endpoint is deployed for on-prem DNS forwarding.
- Management subnet is configured to bypass firewall UDR association for private-link access paths.
- Private DNS remains centralized in hub scope and linked to both VNets.

## 11. Known Boundaries and Next Extension Points

- The template currently deploys one spoke VNet.
- No on-prem connectivity objects are deployed.
- On-prem DNS server configuration (conditional forwarders) is external and must be configured outside Azure IaC.
- Explicit NSG rule sets are not defined (only NSG containers).
- If full forced-egress security is required, set `enableFirewallDefaultRoute = true` and maintain `allowedFirewallEgressCidrs` to avoid unintended denies.
