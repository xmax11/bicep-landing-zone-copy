# Azure Hub-and-Spoke Landing Zone - Bicep Deployment

## Overview

This repository contains an **Azure Landing Zone** deployed using **Bicep** with a **Hub-and-Spoke** network topology. This architecture provides a secure, scalable foundation for Azure workloads with centralized network security and management.

### Components Deployed

| Component | Description |
|-----------|-------------|
| **Hub VNet** | Central network (10.100.0.0/16) containing Azure Firewall, Gateway, Bastion, DNS Resolver, and Management subnets |
| **Spoke VNet** | Application network (10.200.0.0/16) with Infra, App, Data, and PaaS subnets |
| **Azure Firewall** | Centralized network security with dynamically assigned private IP |
| **Key Vault** | RBAC-enabled secrets management with private endpoint |
| **Storage Account** | LRS storage with private endpoint for secure data access |
| **Log Analytics** | Monitoring workspace for diagnostics and alerting |
| **Private Endpoints** | Secure private access to Key Vault and Storage |
| **Azure Policies** | Custom policies for TLS enforcement and tag compliance |
| **VNet Peering** | Bi-directional peering between Hub and Spoke |

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        Azure Subscription                        │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                     Hub VNet (10.100.0.0/16)              │  │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────┐│  │
│  │  │AzureFirewall│ │ Gateway     │ │    Bastion          ││  │
│  │  │  Subnet     │ │ Subnet      │ │    Subnet           ││  │
│  │  │ Dynamic IP  │ │             │ │                     ││  │
│  │  └─────────────┘ └─────────────┘ └─────────────────────┘│  │
│  │  ┌─────────────┐ ┌─────────────┐                         │  │
│  │  │ DNS Resolver│ │ Identity    │                         │  │
│  │  │   Subnet    │ │   Subnet    │                         │  │
│  │  └─────────────┘ └─────────────┘                         │  │
│  └──────────────────────────────────────────────────────────┘  │
│                              │                                   │
│                         VNet Peering                             │
│                              │                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                   Spoke VNet (10.200.0.0/16)             │  │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────┐│  │
│  │  │   Infra     │ │    App      │ │      Data           ││  │
│  │  │   Subnet    │ │   Subnet    │ │     Subnet          ││  │
│  │  └─────────────┘ └─────────────┘ └─────────────────────┘│  │
│  │  ┌─────────────────────────────────────────────────────┐ │  │
│  │  │               PaaS Service Subnet                    │ │  │
│  │  │     (Private Endpoints for Key Vault & Storage)     │ │  │
│  │  └─────────────────────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌────────────────────────┐│
│  │ Key Vault   │  │   Storage   │  │   Log Analytics        ││
│  │ (RBAC)      │  │  Account    │  │   Workspace            ││
│  └─────────────┘  └─────────────┘  └────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

Before deploying the landing zone, ensure you have the following:

### 1. Azure Subscription
- An active Azure subscription
- Sufficient quota for the required resources

### 2. Azure CLI
- Azure CLI version **2.50.0 or later** installed
- Bicep CLI installed (`az bicep install`)

### 3. Required Permissions
- **Contributor** or **Owner** role on the subscription
- Key Vault Contributor role (for deployment identity to access Key Vault)

### 4. Verify Prerequisites

Run the following commands to verify your environment:

```bash
# Check Azure CLI version
az --version

# Check Bicep installation
az bicep version

# Login to Azure
az login

# Set your subscription (replace with your subscription name or ID)
az account set --subscription "Your-Subscription-Name"

# Verify you're in the correct subscription
az account show
```

---

## Parameters to Update

Before deployment, you must update the following parameters in [`parameters.json`](parameters.json):

### Required Parameters

| Parameter | Description | Example Value |
|-----------|-------------|---------------|
| `projectName` | **UPDATE**: Name of your project (used for resource naming) | `myapp` |
| `location` | **UPDATE**: Azure region | `eastus` |
| `environment` | Environment name | `production` or `staging` |
| `hubVnetAddressSpace` | **UPDATE**: CIDR for Hub VNet | `10.100.0.0/16` |
| `spokeVnetAddressSpace` | **UPDATE**: CIDR for Spoke VNet | `10.200.0.0/16` |
| `alertEmailAddress` | **UPDATE**: Email for monitoring alerts | `alerts@contoso.com` |

### Optional Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `deployLogAnalytics` | Enable Log Analytics deployment | `true` |
| `deployPrivateDns` | Enable Private DNS Zones | `true` |
| `deployAzurePolicies` | Enable Azure Policies | `true` |
| `nvaPrivateIp` | Static IP for NVA/firewall (leave empty for dynamic) | `""` (dynamic) |

---

## Deployment Steps

### Step 1: Prepare parameters.json

Create or update the [`parameters.json`](parameters.json) file with your values. **Update the following highlighted values**:

> **⚠️ IMPORTANT**: Replace the placeholder values marked with `<!-- UPDATE -->` with your specific configuration.

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "location": {
      "value": "eastus"  <!-- UPDATE: Your Azure region (e.g., eastus, westus2, uksouth) -->
    },
    "environment": {
      "value": "production"  <!-- UPDATE: staging, production, or development -->
    },
    "projectName": {
      "value": "myapp"  <!-- UPDATE: Your project name (used for resource naming) -->
    },
    "hubVnetAddressSpace": {
      "value": "10.100.0.0/16"  <!-- UPDATE: Hub VNet CIDR block -->
    },
    "spokeVnetAddressSpace": {
      "value": "10.200.0.0/16"  <!-- UPDATE: Spoke VNet CIDR block -->
    },
    "nvaPrivateIp": {
      "value": ""  <!-- Optional: Leave empty for dynamic IP assignment -->
    },
    "deployLogAnalytics": {
      "value": true  <!-- Set to false to skip Log Analytics -->
    },
    "deployPrivateDns": {
      "value": true  <!-- Set to false to skip Private DNS Zones -->
    },
    "deployAzurePolicies": {
      "value": true  <!-- Set to false to skip Policy deployment -->
    },
    "alertEmailAddress": {
      "value": "alerts@contoso.com"  <!-- UPDATE: Your alert email address -->
    }
  }
}
```

# Build the code if you made changes in parameters.json before deploying

az bicep build --file main.bicep

### Step 2: Run Deployment

Deploy the landing zone using **subscription-level deployment**:

```bash
# Deploy using parameters.json
az deployment sub create \
  --location eastus \
  --template-file main.bicep \
  --parameters @parameters.json
```

> **Note**: The deployment location (`--location`) should match the `location` parameter in your `parameters.json`.

### Step 3: Enable/Disable Optional Components

To enable or disable optional components, modify the boolean parameters in `parameters.json`:

#### Disable Log Analytics
```json
"deployLogAnalytics": {
  "value": false
}
```

#### Disable Private DNS Zones
```json
"deployPrivateDns": {
  "value": false
}
```

#### Disable Azure Policies
```json
"deployAzurePolicies": {
  "value": false
}
```

---

## Post-Deployment

### Verify Outputs

After a successful deployment, the following outputs will be displayed. **Verify these values**:

```json
{
  "hubVnetId": "/subscriptions/<subscription-id>/resourceGroups/<rg-name>/providers/Microsoft.Network/virtualNetworks/<projectName>-hub-vnet",
  "spokeVnetId": "/subscriptions/<subscription-id>/resourceGroups/<rg-name>/providers/Microsoft.Network/virtualNetworks/<projectName>-spoke-vnet",
  "firewallPrivateIpAddress": "10.100.0.4",
  "keyVaultId": "/subscriptions/<subscription-id>/resourceGroups/<rg-name>/providers/Microsoft.KeyVault/vaults/<kv-name>",
  "storageAccountId": "/subscriptions/<subscription-id>/resourceGroups/<rg-name>/providers/Microsoft.Storage/storageAccounts/<st-name>",
  "storagePrivateEndpointId": "/subscriptions/<subscription-id>/resourceGroups/<rg-name>/providers/Microsoft.Network/privateEndpoints/<st-pe-name>",
  "keyVaultPrivateEndpointId": "/subscriptions/<subscription-id>/resourceGroups/<rg-name>/providers/Microsoft.Network/privateEndpoints/<kv-pe-name>",
  "resourceGroupName": "<projectName>-rg-<location>",
  "resourceGroupId": "/subscriptions/<subscription-id>/resourceGroups/<projectName>-rg-<location>",
  "paasSubnetId": "/subscriptions/<subscription-id>/resourceGroups/<rg-name>/providers/Microsoft.Network/virtualNetworks/<projectName>-spoke-vnet/subnets/PaaS",
  "appSubnetId": "/subscriptions/<subscription-id>/resourceGroups/<rg-name>/providers/Microsoft.Network/virtualNetworks/<projectName>-spoke-vnet/subnets/App"
}
```

### Access Key Vault

The deployment identity automatically gets access to Key Vault through RBAC. No manual access configuration is required.

To access Key Vault:

```bash
# Get Key Vault details (replace with your resource group and key vault name)
az keyvault show \
  --name "<keyvault-name>" \
  --resource-group "<resource-group-name>"

# List secrets in Key Vault
az keyvault secret list \
  --vault-name "<keyvault-name>"
```

### Verify Firewall Private IP is Dynamically Assigned

The Azure Firewall receives a **dynamic private IP** from the AzureFirewallSubnet. To verify:

```bash
# Get firewall private IP address
az network firewall show \
  --name "<projectName>-azure-fw" \
  --resource-group "<projectName>-rg-<location>" \
  --query "ipConfigurations[0].properties.privateIPAddress" \
  --output tsv
```

> **Note**: The IP address is dynamically assigned and may change if the firewall is recreated.

---

## Tips & Notes

### Dynamic Resource Creation
- All resources are dynamically named using `uniqueString()` based on the subscription ID, location, and project name
- This ensures unique naming across deployments without conflicts
- Azure Firewall automatically receives a dynamic private IP from the AzureFirewallSubnet

### No Manual Key Vault Access Required
- The deployment identity automatically receives **Key Vault Administrator** (or Contributor) access through RBAC
- No need to manually add access policies or role assignments
- Simply use `az keyvault` commands after deployment and your identity will have access

### Keep Tags Intact for Policy Compliance
All resources are automatically tagged with:

| Tag | Value | Description |
|-----|-------|-------------|
| `environment` | From parameter | Production/staging/development |
| `project` | From parameter | Your project name |
| `managedBy` | `Bicep` | Indicates deployment method |

> **⚠️ IMPORTANT**: Do not remove or modify these tags, as they ensure compliance with deployed Azure Policies.

### Security Features
- **Key Vault**: RBAC-enabled authorization (not access policies)
- **Storage Account**: HTTPS-only, TLS 1.2 minimum enforced
- **Private Endpoints**: All PaaS resources accessed via private links
- **Firewall**: All traffic routed through central Azure Firewall
- **VNet Peering**: Bi-directional peering for Hub-Spoke communication

---

## File Structure

```
├── main.bicep                    # Main deployment template (subscription-level)
├── parameters.json               # Deployment parameters (UPDATE THIS FILE)
├── modules/
│   ├── networking.bicep          # VNet, Firewall, NSGs, UDRs, Peering
│   ├── security.bicep            # Key Vault, Private DNS Zones
│   ├── storage.bicep             # Storage Account with diagnostics
│   ├── monitoring.bicep          # Log Analytics, Action Groups, Alerts
│   ├── private-endpoints.bicep   # Private Endpoints for KV & Storage
│   └── policies.bicep            # Azure Policies (TLS, Tags)
├── README.md                     # This file
└── ARCHITECTURE.md               # Detailed architecture documentation
```

---

## Troubleshooting

### Deployment Fails with "Cannot parse the request"
- Ensure you're using the latest Bicep version: `az bicep install`
- Check that VNet peering doesn't have tags (not supported by Azure)

### Key Vault Access Issues
- Ensure your deploying identity has Key Vault Contributor role or Owner on the subscription
- Verify RBAC is enabled on Key Vault:
  ```bash
  az keyvault show --name <kv-name> --query "properties.enableRbacAuthorization"
  ```

### Policy Compliance Errors
- Ensure all resources have `environment` and `project` tags
- Tags are automatically applied by the Bicep templates - do not remove them

### Subscription Scope Deployment Required
- This template uses `targetScope = 'subscription'` and must be deployed at subscription level
- Use `az deployment sub create` (not `az deployment group create`)

---

## License

MIT License - Feel free to use and modify for your needs.

---

## Support

For issues or questions, please review the [Azure Bicep documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/) or open an issue in this repository.
