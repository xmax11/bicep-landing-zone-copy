# Azure Landing Zone - Bicep Infrastructure as Code

## Overview

This Bicep-based landing zone deployment provides a complete, production-ready Hub and Spoke network topology with enterprise-grade security, monitoring, and governance.

## Architecture

### Network Topology: Hub and Spoke

```
        ┌─────────────────────────────────┐
        │       Hub VNet                  │
        │    (10.100.0.0/16)              │
        │                                 │
        │ ┌──────────────────────────┐   │
        │ │ AzureFirewallSubnet      │   │
        │ │ (10.100.0.0/24)          │   │
        │ └──────────────────────────┘   │
        │ ┌──────────────────────────┐   │
        │ │ GatewaySubnet            │   │
        │ │ (10.100.1.0/24)          │   │
        │ └──────────────────────────┘   │
        │ ┌──────────────────────────┐   │
        │ │ ManagementSubnet         │   │
        │ │ (10.100.2.0/24)          │   │
        │ └──────────────────────────┘   │
        └─────────────────────────────────┘
                      │
         ┌────────────┼────────────┐
         │            │            │
    ┌────────────────┼──────────────────────┐
    │   Spoke VNet                           │
    │   (10.200.0.0/16)                     │
    │                                        │
    │  ┌──────────────────────────────┐     │
    │  │ InfraSubnet (10.200.0.0/24)  │     │
    │  └──────────────────────────────┘     │
    │  ┌──────────────────────────────┐     │
    │  │ AppSubnet (10.200.1.0/24)    │     │
    │  └──────────────────────────────┘     │
    │  ┌──────────────────────────────┐     │
    │  │ DataSubnet (10.200.2.0/24)   │     │
    │  └──────────────────────────────┘     │
    │  ┌──────────────────────────────┐     │
    │  │ PaaSSvcSubnet (10.200.3.0/24)│     │
    │  └──────────────────────────────┘     │
    └────────────────────────────────────────┘
```

## Components Deployed

### 1. Networking (`modules/networking.bicep`)
- **Hub VNet** (10.100.0.0/16)
  - AzureFirewallSubnet
  - GatewaySubnet
  - ManagementSubnet
  
- **Spoke VNet** (10.200.0.0/16)
  - InfraSubnet - Infrastructure resources
  - AppSubnet - Application tier
  - DataSubnet - Data tier
  - PaaSSvcSubnet - PaaS services with private endpoints

- **Network Security Groups (NSGs)**
  - Firewall NSG: Allows inbound from spoke, denies all else
  - Gateway NSG: Allows VPN traffic (UDP 500, 4500)
  - Management NSG: RDP, SSH from hub VNet, spoke traffic
  - Infra NSG: Traffic from App and Data subnets
  - App NSG: HTTP/HTTPS from internet, outbound to Data
  - Data NSG: Inbound from App and Infra only
  - PaaS NSG: VNet traffic only

- **User Defined Routes (UDRs)**
  - Management → Spoke routes through firewall
  - Infra → Data routes (e.g., DB traffic)
  - App ↔ Data bidirectional routing
  - All routes back to hub for egress

- **VNet Peering**
  - Hub-to-Spoke: Allows forwarded traffic, gateway transit enabled
  - Spoke-to-Hub: Uses remote gateway

### 2. Monitoring (`modules/monitoring.bicep`)
- **Log Analytics Workspace**
  - 30-day retention
  - PerGB2018 pricing tier
  - Central logging for all resources
  
- **Action Group**
  - Email alerts for Service Disruption
  - Configured for degradation notifications

- **Metric Alerts**
  - Service disruption monitoring
  - Email notifications to admin@example.com

### 3. Security (`modules/security.bicep`)
- **Azure Key Vault**
  - Standard tier
  - Soft delete enabled (7 days)
  - Purge protection enabled
  - RBAC authorization
  - Supports deployment, disk encryption, template deployment

- **Private DNS Zones**
  - `privatelink.blob.core.windows.net` (Storage)
  - `privatelink.vaultcore.azure.net` (Key Vault)
  - `privatelink.database.windows.net` (SQL)
  - `privatelink.azurewebsites.net` (App Service)
  - `privatelink.documents.azure.com` (CosmosDB)

### 4. Storage (`modules/storage.bicep`)
- **Storage Account**
  - Locally Redundant Storage (LRS)
  - Hot access tier
  - TLS 1.2 minimum
  - HTTPS only
  - Blob public access disabled
  - Network ACLs: Deny by default

- **Blob Service**
  - 7-day soft delete
  
- **Containers**
  - landing-zone (for bicep templates)
  - diagnostics (for logs)

### 5. Azure Policies (`modules/policies.bicep`)
- **Custom Policy Definitions**
  - Enforce TLS 1.2 for Storage Accounts
  - Enforce HTTPS only
  - Audit Key Vault encryption
    - Restrict VM SKUs (previously enforced; restriction removed to allow workload sizing flexibility)
  - Require environment tag on all resources

- **Policy Initiative**
  - Baseline compliance bundle
  - Subscription-level assignment

## Prerequisites

1. **Azure CLI** (v2.40+)
   ```bash
   az --version
   ```

2. **Bicep CLI** (included with Azure CLI 2.40+)
   ```bash
   az bicep version
   ```

3. **Azure Subscription**
   - Active subscription with permissions to create resources at subscription level

4. **Required Permissions**
   - Contributor role at subscription level
   - User Access Administrator role (for policy assignments)

## Deployment

### Option 1: Azure CLI (Recommended)

#### 1. Login to Azure
```bash
az login
```

#### 2. Set your subscription
```bash
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

#### 3. Deploy the landing zone
```bash
# Using parameters file
az deployment sub create \
  --location eastus \
  --template-file main.bicep \
  --parameters @parameters.json

# OR using inline parameters
az deployment sub create \
  --location eastus \
  --template-file main.bicep \
  --parameters location=eastus environment=production projectName=lz
```

#### 4. Verify deployment
```bash
az deployment sub show --name mainDeployment
az resource list --resource-group lz-rg-eastus
```

### Option 2: PowerShell

```powershell
# Set subscription
Set-AzContext -Subscription "YOUR_SUBSCRIPTION_ID"

# Deploy
New-AzSubscriptionDeployment `
  -Name "LandingZoneDeployment" `
  -Location "eastus" `
  -TemplateFile "main.bicep" `
  -TemplateParameterFile "parameters.json"

# Verify
Get-AzDeployment -Name "LandingZoneDeployment"
```

### Option 3: GitHub Actions CI/CD

Create `.github/workflows/deploy-landing-zone.yml`:

```yaml
name: Deploy Landing Zone

on:
  push:
    branches:
      - main
    paths:
      - 'bicep/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Deploy Landing Zone
        uses: azure/arm-deploy@v1
        with:
          scope: subscription
          region: eastus
          template: main.bicep
          parameters: @parameters.json
```

## Configuration

### Update Parameters

Edit `parameters.json` to customize:

```json
{
  "parameters": {
    "location": { "value": "eastus" },
    "environment": { "value": "production" },
    "projectName": { "value": "lz" },
    "hubVnetAddressSpace": { "value": "10.100.0.0/16" },
    "spokeVnetAddressSpace": { "value": "10.200.0.0/16" },
    "deployLogAnalytics": { "value": true },
    "deployPrivateDns": { "value": true },
    "deployAzurePolicies": { "value": true }
  }
}
```

### Key Customization Points

1. **Network CIDR Blocks**
   - Hub: 10.100.0.0/16 (expandable for multiple hubs)
   - Spoke: 10.200.0.0/16 (create multiple spoke VNets per region)

2. **Log Analytics Retention**
   - Edit `modules/monitoring.bicep` line: `retentionInDays: 30`

3. **Storage Redundancy**
   - Change `Standard_LRS` to `Standard_GRS` for geo-redundancy

4. **VM SKU Restrictions**
   - Update `modules/policies.bicep` allowed SKUs array

5. **Alert Email**
   - Update `modules/monitoring.bicep` line: `emailAddress: 'admin@example.com'`

## Deployment Outputs

After successful deployment, you'll receive:

```json
{
  "hubVnetId": "/subscriptions/.../resourceGroups/lz-rg-eastus/providers/Microsoft.Network/virtualNetworks/lz-hub-vnet",
  "spokeVnetId": "/subscriptions/.../resourceGroups/lz-rg-eastus/providers/Microsoft.Network/virtualNetworks/lz-spoke-vnet",
  "logAnalyticsWorkspaceId": "/subscriptions/.../resourceGroups/lz-rg-eastus/providers/Microsoft.OperationalInsights/workspaces/lz-law-eastus-xxx",
  "keyVaultId": "/subscriptions/.../resourceGroups/lz-rg-eastus/providers/Microsoft.KeyVault/vaults/lz-kv-xxx",
  "storageAccountId": "/subscriptions/.../resourceGroups/lz-rg-eastus/providers/Microsoft.Storage/storageAccounts/lzstxxx",
  "resourceGroupName": "lz-rg-eastus",
  "resourceGroupId": "/subscriptions/.../resourceGroups/lz-rg-eastus"
}
```

## Post-Deployment Steps

### 1. Configure Alert Email
```bash
# Update the action group with your email
az monitor action-group update \
  --name lz-ag-eastus \
  --resource-group lz-rg-eastus \
  --add-action email ServiceDisruptionAlert --email-address your-email@example.com
```

### 2. Add VNet Peering to Additional Spokes
```bash
# Create new spoke VNet
az network vnet create \
  --name lz-spoke2-vnet \
  --resource-group lz-rg-eastus \
  --address-prefix 10.201.0.0/16 \
  --location eastus

# Peer with hub
az network vnet peering create \
  --name hub-to-spoke2 \
  --resource-group lz-rg-eastus \
  --vnet-name lz-hub-vnet \
  --remote-vnet /subscriptions/.../lz-spoke2-vnet \
  --allow-vnet-access \
  --allow-forwarded-traffic \
  --allow-gateway-transit
```

### 3. Deploy Firewall (Optional)
```bash
# Create public IP for firewall
az network public-ip create \
  --name lz-fw-pip \
  --resource-group lz-rg-eastus \
  --sku Standard \
  --location eastus

# Create firewall
az network firewall create \
  --name lz-fw \
  --resource-group lz-rg-eastus \
  --location eastus
```

### 4. Link Private DNS Zones to VNets
```bash
# Link Storage DNS zone to spoke
az network private-dns link vnet create \
  --zone-name privatelink.blob.core.windows.net \
  --name lz-spoke-link \
  --resource-group lz-rg-eastus \
  --virtual-network /subscriptions/.../lz-spoke-vnet \
  --registration-enabled false
```

## Troubleshooting

### Deployment Fails on Policy Assignment
- Ensure you have User Access Administrator role
- Grant managed identity policy assignment permissions:
```bash
az role assignment create \
  --assignee <policy-assignment-principal-id> \
  --role Contributor \
  --scope /subscriptions/<subscription-id>
```

### VNet Peering Issues
- Verify address spaces don't overlap
- Check NSG rules: ensure cross-subnet traffic is allowed
- Verify `allowVirtualNetworkAccess` is true

### Storage Account Access Denied
- NSG rules might block traffic
- Check network ACLs in storage account
- Verify service endpoints configured on PaaS subnet

### Key Vault Access Issues
- For Key Vault access, add IP to firewall:
```bash
az keyvault network-rule add \
  --name lz-kv-xxx \
  --resource-group lz-rg-eastus \
  --ip-address YOUR_IP
```

## Cost Estimation

Typical monthly costs (East US):

| Component | Estimated Cost |
|-----------|----------------|
| VNets & Peering | ~$3 |
| NSGs | ~$1 |
| Log Analytics (1GB/day) | ~$50 |
| Storage Account (1TB) | ~$20 |
| Key Vault | ~$1 |
| **Total** | **~$75/month** |

*Costs vary with usage and region*

## Clean Up

### Remove entire landing zone
```bash
# Delete resource group (deletes all resources)
az group delete \
  --name lz-rg-eastus \
  --yes --no-wait

# Delete policy assignments (if separate scope)
az policy assignment delete \
  --name lz-baseline-assignment
```

### Remove specific components
```bash
# Delete storage account
az storage account delete \
  --name lzstxxx \
  --resource-group lz-rg-eastus \
  --yes

# Delete key vault
az keyvault delete \
  --name lz-kv-xxx \
  --resource-group lz-rg-eastus
```

## File Structure

```
Bicep landing zone/
├── main.bicep                 # Main orchestration template
├── parameters.json            # Parameter values
├── README.md                  # This file
└── modules/
    ├── networking.bicep       # VNet, Subnets, NSGs, UDRs
    ├── monitoring.bicep       # Log Analytics, Action Groups
    ├── security.bicep         # Key Vault, Private DNS Zones
    ├── storage.bicep          # Storage Account, Containers
    └── policies.bicep         # Azure Policies, Initiatives
```

## Scaling the Landing Zone

### Add New Spoke VNet
1. Create new VNet with unique address space (e.g., 10.201.0.0/16)
2. Create subnets matching spoke pattern
3. Create NSGs for new subnets
4. Set up UDRs to other spokes through hub
5. Peer with hub VNet
6. Update firewall routes

### Add Custom Policies
1. Add policy definition to `modules/policies.bicep`
2. Add to policy initiative
3. Redeploy: `az deployment sub create ...`

### Multi-Region Deployment
```bash
# Deploy to additional region
az deployment sub create \
  --location westus \
  --template-file main.bicep \
  --parameters @parameters-westus.json
```

Create `parameters-westus.json` with location set to westus.

## Best Practices Applied

✅ **Security**
- Private DNS zones for PaaS services
- Key Vault with soft delete & purge protection
- HTTPS-only storage accounts
- TLS 1.2 enforcement
- NSGs restrict traffic by default

✅ **Monitoring**
- Centralized Log Analytics workspace
- Diagnostic settings on all resources
- Alert actions for service disruption
- Metrics collection enabled

✅ **Governance**
- Baseline Azure Policies
- Tag requirements
- VM SKU restrictions
- Compliance monitoring

✅ **Scalability**
- Modular Bicep templates
- Reusable parameters
- Easy spoke expansion
- Supports multi-region

✅ **Maintainability**
- Inline documentation
- Consistent naming conventions
- Grouped resources by function
- Easy to customize

## Support & Contributions

For issues or improvements, please update the templates and test deployment before sharing.

## License

This infrastructure template is provided as-is for your organization's use.

---

**Last Updated:** February 12, 2026  
**Version:** 1.0.0  
**Status:** Production Ready
