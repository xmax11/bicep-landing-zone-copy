# Azure Hub-and-Dual-Spoke Landing Zone (Bicep)

## Overview

This repository deploys an Azure landing zone using a **Hub + 2 Spokes** topology with:

- Centralized **Hub VNet** security and transit
- **One VM per spoke** (`Standard_B2ms`)
- **One App Service** in spoke1 with private access
- **Azure Bastion** in Hub for VM administration
- **Private DNS + Private Endpoints** linked to Hub and both spokes
- **Azure Policies enabled** by default

## Deployed Architecture

| Component | Purpose |
|---|---|
| Hub VNet (`10.100.0.0/16`) | Central transit/security VNet |
| Spoke1 VNet (`10.200.0.0/16`) | Workload VNet #1 (VM + App Service integration + PE targets) |
| Spoke2 VNet (`10.210.0.0/16`) | Workload VNet #2 (VM) |
| Azure Firewall (optional) | Hub transit and rule enforcement |
| Azure Bastion | Secure VM access from Hub |
| App Service (spoke1) | PaaS app integrated with spoke1 `AppSubnet` |
| App Service Private Endpoint (spoke1) | Private inbound access from VNets |
| Key Vault + Storage + Private Endpoints | Shared secured PaaS services |
| Private DNS Zones | Linked to Hub + spoke1 + spoke2 |
| Azure Policy Assignments | Tag inheritance + TLS guardrail |

## Topology

```text
Hub VNet (10.100.0.0/16)
  - AzureFirewallSubnet
  - AzureBastionSubnet
  - IdentitySubnet
  - ManagementSubnet

Spoke1 VNet (10.200.0.0/16)
  - InfraSubnet     -> VM (B2ms)
  - AppSubnet       -> App Service VNet integration
  - DataSubnet
  - PaaSSvcSubnet   -> Private Endpoints (Storage, Key Vault, App Service)

Spoke2 VNet (10.210.0.0/16)
  - InfraSubnet     -> VM (B2ms)
  - AppSubnet
  - DataSubnet
  - PaaSSvcSubnet

Peering:
  Hub <-> Spoke1
  Hub <-> Spoke2
```

## Routing and UDRs (Important)

### Hub UDRs

| Subnet | Route | Next Hop |
|---|---|---|
| IdentitySubnet | `10.200.0.0/16` (spoke1), `10.210.0.0/16` (spoke2) | Hub Firewall private IP |
| ManagementSubnet | Same as above (unless bypass enabled) | Hub Firewall private IP |

### Spoke UDRs

When `deployFirewall = true`, each spoke subnet gets UDRs:

| Spoke | Route | Purpose |
|---|---|---|
| Spoke1 subnets | `10.210.0.0/16` -> Firewall | Force spoke1-to-spoke2 transit via Hub Firewall |
| Spoke2 subnets | `10.200.0.0/16` -> Firewall | Force spoke2-to-spoke1 transit via Hub Firewall |

Optional default route:

- If `enableFirewallDefaultRoute = true`, each spoke subnet also gets `0.0.0.0/0 -> Firewall`.
- If `false` (default), internet egress is **not** force tunneled.

This meets the requirement to demonstrate hub transit between spokes without forcing all outbound traffic through firewall.

### Cross-Spoke Connectivity (Hub-Spoke Transit)

The architecture ensures full connectivity between spokes via the Hub:

1. **VM to VM**: VMs in spoke1 InfraSubnet can reach VMs in spoke2 InfraSubnet (and vice versa) via the Hub Firewall using UDRs
2. **VM to App Service**: VMs in either spoke can reach the App Service in spoke1 via Hub Firewall
3. **Bastion Access**: Azure Bastion in Hub can access all VMs in both spokes via NSG rules allowing RDP (port 3389) from Hub VNet

All cross-spoke traffic transits through the Hub VNet, enabling inspection and logging by the Azure Firewall.

## Access Model

### VM Access

- One Windows VM is deployed in each spoke `InfraSubnet`.
- Azure Bastion in Hub provides administrative access to both VMs.
- NSG rules allow RDP (port 3389) from Hub VNet to both spoke InfraSubnets.

### App Service Access

- App Service is deployed in spoke1 and integrated to spoke1 `AppSubnet`.
- A private endpoint for App Service is deployed in spoke1 `PaaSSvcSubnet`.
- Private DNS zones are linked to Hub, spoke1, and spoke2, so both spokes can resolve/reach App Service privately.
- Cross-spoke App Service access from spoke2 traverses Hub Firewall using spoke2 UDR to spoke1 CIDR.
- NSG rules allow HTTP/HTTPS from Hub VNet and Spoke2 to spoke1 AppSubnet.
- Bastion operators can validate App Service private access by connecting to either spoke VM through Bastion and testing the private endpoint hostname from that VM session.

### Cross-Spoke Access via Hub VNet

All traffic between spokes transits via the Hub VNet:

| Source | Destination | Path |
|---|---|---|
| Spoke1 VM | Spoke2 VM | Spoke1 InfraSubnet -> Hub Firewall -> Spoke2 InfraSubnet |
| Spoke2 VM | Spoke1 VM | Spoke2 InfraSubnet -> Hub Firewall -> Spoke1 InfraSubnet |
| Spoke1 VM | App Service | Spoke1 -> Hub Firewall -> Spoke1 AppSubnet (direct via peering) |
| Spoke2 VM | App Service | Spoke2 InfraSubnet -> Hub Firewall -> Spoke1 AppSubnet |
| Bastion (Hub) | Spoke1 VM | Hub BastionSubnet -> Spoke1 InfraSubnet (via NSG rules) |
| Bastion (Hub) | Spoke2 VM | Hub BastionSubnet -> Spoke2 InfraSubnet (via NSG rules) |

### NSG Rules Summary

The following NSG rules have been configured to enable the access model:

| NSG | Rule | Source | Destination Port | Purpose |
|---|---|---|---|---|
| spoke1-infra-nsg | AllowRdpFromHub | Hub VNet (10.100.0.0/16) | 3389 | Bastion access to Spoke1 VM |
| spoke2-infra-nsg | AllowRdpFromHub | Hub VNet (10.100.0.0/16) | 3389 | Bastion access to Spoke2 VM |
| spoke1-app-nsg | AllowHttpFromHubAndSpokes | Hub VNet + Spoke2 | 80 | App Service HTTP access |
| spoke1-app-nsg | AllowHttpsFromHubAndSpokes | Hub VNet + Spoke2 | 443 | App Service HTTPS access |
| spoke2-app-nsg | AllowHttpFromHubAndSpoke1 | Hub VNet + Spoke1 | 80 | App Service HTTP access |
| spoke2-app-nsg | AllowHttpsFromHubAndSpoke1 | Hub VNet + Spoke1 | 443 | App Service HTTPS access |
| spoke1-data-nsg | AllowMssqlFromHubAndSpokes | Hub VNet + Spoke2 | 1433 | SQL/database access |
| spoke2-data-nsg | AllowMssqlFromHubAndSpokes | Hub VNet + Spoke1 | 1433 | SQL/database access |
| spoke1-paas-nsg | AllowHttpsFromHubAndSpokes | Hub VNet + Spoke2 | 443 | Private Endpoint access |
| spoke2-paas-nsg | AllowHttpsFromHubAndSpokes | Hub VNet + Spoke1 | 443 | Private Endpoint access |

## Firewall Rules

The Azure Firewall policy includes:

1. **Internal allow rule** for Hub + both spoke CIDRs (allows all traffic between Hub and spokes)
2. **Azure DNS allow rule** (`168.63.129.16:53`)
3. **Two OWASP-style demo application rules** (from both spoke CIDRs):
   - `owasp.org` and `*.owasp.org` over HTTPS - for web application security resources
   - `*.update.microsoft.com` and `*.download.windowsupdate.com` over HTTPS - for Azure update endpoints

These demo app rules are intentionally limited to 2 rules for cost control while demonstrating OWASP-style rule configuration. The spoke VNets (10.200.0.0/16 and 10.210.0.0/16) are included as source addresses in these rules.

> Note: Native OWASP managed rules are provided by WAF services (e.g., Application Gateway WAF / Front Door WAF), not Azure Firewall policy objects. Azure Firewall provides network and application-level filtering with custom rules.

## Key Parameters (`parameters.json`)

| Parameter | Recommended Value |
|---|---|
| `hubVnetAddressSpace` | `10.100.0.0/16` |
| `spokeVnetAddressSpace` | `10.200.0.0/16` |
| `spoke2VnetAddressSpace` | `10.210.0.0/16` |
| `deployFirewall` | `true` |
| `deployBastion` | `true` |
| `enableFirewallDefaultRoute` | `false` |
| `deploySpokeAppService` | `true` |
| `deployWorkloadVms` | `true` |
| `vmAdminPassword` | Set a strong secret before deployment |
| `vmSku` | `Standard_B2ms` |
| `deployAzurePolicies` | `true` |

## Deploy

```bash
az deployment sub create \
  --location eastus \
  --template-file main.bicep \
  --parameters @parameters.json
```

## Expected Outputs

You should see outputs for:

- `hubVnetId`, `spoke1VnetId`, `spoke2VnetId`
- `firewallPrivateIpAddress`
- `bastionHostId`
- `appServiceId`, `appServiceName`
- `vmIds`, `vmNames`, `vmPrivateIps`
- `spoke1InfraSubnetId`, `spoke2InfraSubnetId`
- `storagePrivateEndpointId`, `keyVaultPrivateEndpointId`, `appServicePrivateEndpointId`

## Module Layout

```text
main.bicep
parameters.json
modules/
  networking.bicep
  compute.bicep
  app-service.bicep
  private-dns-zones.bicep
  private-endpoints.bicep
  security.bicep
  storage.bicep
  monitoring.bicep
  policies.bicep
```

## Notes

- Azure Policy deployment remains enabled and is not commented out.
- If you disable `deployFirewall`, cross-spoke transit UDR behavior will not be active.
- Update `vmAdminPassword` in `parameters.json` before production use.
