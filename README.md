# Azure Hub-and-Dual-Spoke Landing Zone (Bicep)

## What this deploys

This repository deploys a subscription-scoped Azure landing zone with:

- Hub + dual-spoke VNets
- Optional Azure Firewall (hub transit and filtering)
- Optional Azure Bastion (VM management)
- Optional App Service in Spoke1
- Private Endpoints for PaaS services in Spoke1
- Centralized Private DNS zones in Hub
- Hub-only Private DNS VNet links
- Azure DNS Private Resolver in Hub (default enabled) with spoke VNets pointed to it
- One Windows VM per spoke (optional)
- One temporary Hub test VM for connectivity validation (optional)
- Optional monitoring (Log Analytics + alerts)
- Optional subscription-level policy assignments

## Architecture overview

### Network topology

- Hub VNet: `10.100.0.0/16`
- Spoke1 VNet: `10.200.0.0/16`
- Spoke2 VNet: `10.210.0.0/16`
- Peering: `Hub <-> Spoke1` and `Hub <-> Spoke2`

Hub subnets:

- `AzureFirewallSubnet`
- `AzureBastionSubnet`
- `IdentitySubnet`
- `ManagementSubnet`
- `PrivateDnsResolverSubnet` (when `deployPrivateDnsResolver = true`)

Spoke1 and Spoke2 subnets:

- `InfraSubnet`
- `AppSubnet`
- `DataSubnet`
- `PaaSSvcSubnet`

### Private DNS and Private Link model

- Private DNS zones are created centrally in Hub via `modules/private-dns-zones.bicep`.
- DNS zones are linked to **Hub VNet only**.
- Spoke VNets are configured with custom DNS servers pointing to the Hub DNS Private Resolver inbound IP (when enabled).
- Private Endpoints are deployed in Spoke1 `PaaSSvcSubnet` via `modules/private-endpoints.bicep`.

This gives centralized DNS governance while still allowing spoke workloads to resolve `privatelink.*` records through Hub DNS.

### Traffic behavior

- Hub-to-spoke and spoke-to-spoke connectivity is enabled through peering and optional firewall routing.
- If `deployFirewall = true`, spoke UDRs steer inter-spoke traffic via Hub Firewall.
- If `enableFirewallDefaultRoute = true`, internet egress is force-routed to firewall.
- If `deployPrivateDnsResolver = false`, Hub-only DNS links remain, but spoke workloads may not resolve private FQDNs unless another DNS forwarder exists.

## Active module structure

The following modules are used by `main.bicep`:

```text
main.bicep
parameters.json
modules/
  networking.bicep
  monitoring.bicep
  security.bicep
  storage.bicep
  app-service.bicep
  compute.bicep
  hub-test-vm.bicep
  private-dns-zones.bicep
  private-endpoints.bicep
  policies.bicep
```

Other files in `modules/` can exist for legacy/alternate patterns, but the list above is the current deployment path.

## Key parameters

| Parameter | Default | Purpose |
|---|---|---|
| `location` | `eastus` | Deployment region |
| `projectName` | `sinet-hub-spoke` | Name prefix for resources |
| `deployFirewall` | `false` | Deploy Azure Firewall in Hub |
| `deployBastion` | `true` | Deploy Azure Bastion in Hub |
| `deployPrivateDnsResolver` | `true` | Deploy Hub DNS Private Resolver + set spoke VNet DNS |
| `enableFirewallDefaultRoute` | `false` | Force `0.0.0.0/0` through firewall |
| `deploySpokeAppService` | `true` | Deploy App Service in Spoke1 |
| `deployWorkloadVms` | `true` | Deploy one VM in each spoke |
| `deployHubTestVm` | `false` | Deploy temporary Hub test VM in `ManagementSubnet` |
| `deployLogAnalytics` | `true` | Deploy monitoring workspace and diagnostics targets |
| `deployAzurePolicies` | `true` | Deploy subscription policies |
| `vmSku` | `Standard_D2s_v3` | VM size for spoke VMs and Hub test VM |
| `vmAdminPassword` | (required) | Admin password for deployed VMs |

## End-to-end deployment with Azure CLI (bash)

### 1. Prerequisites

```bash
az version
az bicep version
```

If needed:

```bash
az bicep install
```

Login:

```bash
az login
```

### 2. Set deployment variables

```bash
export SUBSCRIPTION_ID="<your-subscription-id-or-name>"
export LOCATION="eastus2"
export DEPLOYMENT_NAME="landing-zone-$(date +%Y%m%d-%H%M%S)"
export TEMPLATE_FILE="main.bicep"
export PARAM_FILE="parameters.json"
```

Select subscription:

```bash
az account set --subscription "$SUBSCRIPTION_ID"
az account show --query "{name:name,id:id,tenantId:tenantId}" -o table
```

### 3. Validate before deployment

```bash
az deployment sub validate \
  --name "${DEPLOYMENT_NAME}-validate" \
  --location "$LOCATION" \
  --template-file "$TEMPLATE_FILE" \
  --parameters @"$PARAM_FILE"
```

Optional what-if preview:

```bash
az deployment sub what-if \
  --name "${DEPLOYMENT_NAME}-whatif" \
  --location "$LOCATION" \
  --template-file "$TEMPLATE_FILE" \
  --parameters @"$PARAM_FILE"
```

### 4. Deploy

```bash
az deployment sub create \
  --name "$DEPLOYMENT_NAME" \
  --location "$LOCATION" \
  --template-file "$TEMPLATE_FILE" \
  --parameters @"$PARAM_FILE"
```

### 5. Get outputs

```bash
az deployment sub show \
  --name "$DEPLOYMENT_NAME" \
  --query "properties.outputs" \
  -o jsonc
```

Capture important values:

```bash
RG_NAME=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query "properties.outputs.resourceGroupName.value" -o tsv)
DNS_INBOUND_IP=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query "properties.outputs.privateDnsResolverInboundEndpointIp.value" -o tsv)

echo "Resource Group: $RG_NAME"
echo "DNS Resolver Inbound IP: $DNS_INBOUND_IP"
```

## Post-deployment verification (bash)

### Verify resolver and inbound endpoint

```bash
# Set this to the same value used in parameters.json
PROJECT_NAME="<project-name-from-parameters>"

az network dns-resolver show \
  --resource-group "$RG_NAME" \
  --name "${PROJECT_NAME}-hub-dns-resolver" \
  -o table

az network dns-resolver inbound-endpoint show \
  --resource-group "$RG_NAME" \
  --dns-resolver-name "${PROJECT_NAME}-hub-dns-resolver" \
  --name "${PROJECT_NAME}-hub-dns-inbound" \
  -o jsonc
```

### Verify Hub-only Private DNS links

```bash
STORAGE_SUFFIX=$(az cloud show --query "suffixes.storageEndpoint" -o tsv | sed 's/^\.//')
SQL_SUFFIX=$(az cloud show --query "suffixes.sqlServerHostname" -o tsv | sed 's/^\.//')

ZONES=(
  "privatelink.blob.${STORAGE_SUFFIX}"
  "privatelink.file.${STORAGE_SUFFIX}"
  "privatelink.queue.${STORAGE_SUFFIX}"
  "privatelink.table.${STORAGE_SUFFIX}"
  "privatelink.vaultcore.azure.net"
  "privatelink.${SQL_SUFFIX}"
  "privatelink.documents.azure.com"
)

for zone in "${ZONES[@]}"; do
  echo "=== $zone ==="
  az network private-dns link vnet list \
    --resource-group "$RG_NAME" \
    --zone-name "$zone" \
    --query "[].{name:name,vnetId:virtualNetwork.id}" \
    -o table
done
```

If App Service is enabled, also verify:

```bash
az network private-dns link vnet list \
  --resource-group "$RG_NAME" \
  --zone-name "privatelink.azurewebsites.net" \
  --query "[].{name:name,vnetId:virtualNetwork.id}" \
  -o table

az network private-dns link vnet list \
  --resource-group "$RG_NAME" \
  --zone-name "privatelink.web.azurewebsites.net" \
  --query "[].{name:name,vnetId:virtualNetwork.id}" \
  -o table
```

## Typical deployment modes

### Full landing zone (recommended baseline)

- `deployFirewall = true`
- `deployBastion = true`
- `deployPrivateDnsResolver = true`
- `deployWorkloadVms = true`
- `deploySpokeAppService = true/false` based on workload

### Network + DNS foundation only

- `deployWorkloadVms = false`
- `deploySpokeAppService = false`
- keep `deployPrivateDnsResolver = true`

### Connectivity testing mode

- `deployHubTestVm = true`
- `deployWorkloadVms = true`
- Use Hub test VM + spoke VMs for route and DNS validation

## Security notes

- Replace `vmAdminPassword` in `parameters.json` before production use.
- Restrict inbound admin access using just-in-time and approved jump workflows.
- Keep `deployPrivateDnsResolver = true` when using Hub-only private DNS zone links.
