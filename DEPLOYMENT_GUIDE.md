# Azure Landing Zone Deployment Guide

## Overview

This guide covers deploying the Azure Landing Zone using Bicep infrastructure-as-code. The landing zone implements a Hub and Spoke topology with enterprise-grade security, networking, monitoring, and governance.

**Organization**: Sinet Technologies  
**Project Name**: sinet-technologies-lz (sinet-lz3 in parameters)

---

## Architecture Components

The deployment includes the following modules:

| Module | File | Description |
|--------|------|-------------|
| **Networking** | [`modules/networking.bicep`](modules/networking.bicep) | Hub VNet (10.100.0.0/16) with 6 subnets and Spoke VNet (10.200.0.0/16) with 4 subnets, NSGs, UDRs, and VNet Peering |
| **Monitoring** | [`modules/monitoring.bicep`](modules/monitoring.bicep) | Log Analytics Workspace, Action Groups for alerts |
| **Security** | [`modules/security.bicep`](modules/security.bicep) | Key Vault with Private DNS Zones for Storage, Key Vault, SQL, App Service, and CosmosDB |
| **Storage** | [`modules/storage.bicep`](modules/storage.bicep) | Storage Account (LRS) with landing-zone and diagnostics containers |
| **Policies** | [`modules/policies.bicep`](modules/policies.bicep) | Custom Azure Policies for TLS, HTTPS, Key Vault encryption, and resource tagging |
| **Private Endpoints** | [`modules/private-endpoints.bicep`](modules/private-endpoints.bicep) | Private Endpoints for Storage Account and Key Vault |

---

## Default Parameters

| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| `location` | `eastus` | Azure region for deployment |
| `environment` | `production` | Environment name for tagging |
| `projectName` | `sinet-lz3` | Project name for resource naming |
| `hubVnetAddressSpace` | `10.100.0.0/16` | Hub VNet address space |
| `spokeVnetAddressSpace` | `10.200.0.0/16` | Spoke VNet address space |
| `firewallPrivateIp` | `10.100.0.4` | Private IP of Azure Firewall or NVA |
| `deployLogAnalytics` | `true` | Enable Log Analytics deployment |
| `deployPrivateDns` | `true` | Enable Private DNS Zones |
| `deployAzurePolicies` | `true` | Enable Azure Policy deployment |

---

## Prerequisites Check

```powershell
# Check Azure CLI version
az --version

# Check Bicep support
az bicep version

# Check current subscription
az account show

# List available subscriptions
az account list -o table
```

---

## Pre-Deployment Checklist

- [ ] Azure CLI 2.40+ installed
- [ ] Bicep CLI installed
- [ ] Valid Azure subscription with sufficient permissions
- [ ] Owner or Contributor role on subscription
- [ ] Subscription ID or subscription name ready for `az account set --subscription ...`
- [ ] Review and customize parameters.json
- [ ] Note the alert email address: `Lolu@sinettechnologies.com`

---

## Fast Track Deployment (Beginner-Friendly, Specific Subscription)

### Step 1: Sign in to Azure
```bash
az login
```

### Step 2: Pick the exact subscription
```bash
# List all subscriptions you can access
az account list --output table

# Set the one you want to deploy to (ID or Name both work)
az account set --subscription "<YOUR_SUBSCRIPTION_ID_OR_NAME>"

# Confirm current context
az account show --query "{name:name, id:id, tenantId:tenantId}" --output table
```

### Step 3: Deploy with Azure CLI (explicit subscription)
```bash
cd "c:\Users\Zahid\Downloads\Bicep landing zone - Copy"

az deployment sub create \
  --subscription "<YOUR_SUBSCRIPTION_ID_OR_NAME>" \
  --name SinetLandingZoneDeployment \
  --location eastus \
  --template-file main.bicep \
  --parameters @parameters.json
```

### Step 4: Verify deployment
```bash
az deployment sub show \
  --subscription "<YOUR_SUBSCRIPTION_ID_OR_NAME>" \
  --name SinetLandingZoneDeployment \
  --query "{state:properties.provisioningState, timestamp:properties.timestamp}" \
  --output table

az deployment sub show \
  --subscription "<YOUR_SUBSCRIPTION_ID_OR_NAME>" \
  --name SinetLandingZoneDeployment \
  --query properties.outputs
```

---

## PowerShell Deployment

```powershell
# Connect to Azure
Connect-AzAccount

# Select subscription
Set-AzContext -SubscriptionId "YOUR_SUBSCRIPTION_ID"

# Navigate to template directory
cd "c:\Users\Zahid\Downloads\Bicep landing zone - Copy"

# Deploy
New-AzSubscriptionDeployment `
  -Name "SinetLandingZoneDeployment" `
  -Location "eastus" `
  -TemplateFile "main.bicep" `
  -TemplateParameterFile "parameters.json" `
  -Verbose

# Check deployment status
Get-AzDeployment -Name "SinetLandingZoneDeployment" | Select-Object ProvisioningState, Timestamp
```

---

## Customized Deployment

> Tip: For all commands below, add `--subscription "<YOUR_SUBSCRIPTION_ID_OR_NAME>"` (or run `az account set --subscription "<ID_OR_NAME>"` first) to target a specific subscription.

### Deploy with Custom Project Name
```bash
az deployment sub create \
  --name SinetLandingZoneDeployment \
  --location eastus \
  --template-file main.bicep \
  --parameters \
    projectName="my-custom-lz" \
    environment="staging" \
    location="eastus" \
    hubVnetAddressSpace="10.100.0.0/16" \
    spokeVnetAddressSpace="10.200.0.0/16" \
    deployLogAnalytics=true \
    deployPrivateDns=true \
    deployAzurePolicies=true
```

### Deploy to Different Region
```bash
az deployment sub create \
  --name SinetLandingZoneDeployment \
  --location westus \
  --template-file main.bicep \
  --parameters location="westus" environment="production"
```

### Deploy Without Policies
```bash
az deployment sub create \
  --name SinetLandingZoneDeployment \
  --location eastus \
  --template-file main.bicep \
  --parameters @parameters.json deployAzurePolicies=false
```

### Deploy Without Private DNS
```bash
az deployment sub create \
  --name SinetLandingZoneDeployment \
  --location eastus \
  --template-file main.bicep \
  --parameters @parameters.json deployPrivateDns=false
```

---

## Getting Deployment Results

### View All Resources Created
```bash
# Get resource group name from outputs
az deployment sub show \
  --name SinetLandingZoneDeployment \
  --query 'properties.outputs.resourceGroupName.value' \
  -o tsv

# Store in variable
$rgName = az deployment sub show \
  --name SinetLandingZoneDeployment \
  --query 'properties.outputs.resourceGroupName.value' \
  -o tsv

# List all resources
az resource list --resource-group $rgName -o table
```

### Export Deployment Outputs
```bash
# Export outputs to JSON file
az deployment sub show \
  --name SinetLandingZoneDeployment \
  --query 'properties.outputs' > deployment-outputs.json

# View specific outputs
az deployment sub show \
  --name SinetLandingZoneDeployment \
  --query 'properties.outputs.hubVnetId.value'
```

---

## Redeployment & Updates

### Rinse and Repeat Model (Blow Away & Redeploy)

```bash
# Step 1: Delete existing deployment
$rgName = "sinet-lz3-rg-eastus"
az group delete --name $rgName --yes --no-wait

# Wait for deletion
az group wait --deleted --name $rgName

# Step 2: Redeploy
az deployment sub create \
  --name SinetLandingZoneDeployment \
  --location eastus \
  --template-file main.bicep \
  --parameters @parameters.json
```

### Update Existing Deployment (No Delete)
```bash
# Update parameters in parameters.json
# Then redeploy
az deployment sub create \
  --name SinetLandingZoneDeployment \
  --location eastus \
  --template-file main.bicep \
  --parameters @parameters.json
```

---

## CI/CD Integration

### GitHub Actions Workflow

The project includes a comprehensive GitHub Actions workflow at [`.github/workflows/deploy-landing-zone.yml`](.github/workflows/deploy-landing-zone.yml). The workflow includes:

- **Validate Job**: Validates Bicep syntax and templates against Azure
- **Deploy Job**: Deploys the landing zone with verification steps
- **Rollback Job**: Automatically triggers on failure for main branch deployments

To use the workflow:

1. Configure Azure credentials as a GitHub secret (`AZURE_CREDENTIALS`)
2. Configure subscription ID as a GitHub secret (`AZURE_SUBSCRIPTION_ID`)
3. Push to main branch or manually trigger via workflow_dispatch

The workflow will:
- Validate all Bicep templates
- Deploy the landing zone
- Verify deployed resources
- Check network connectivity
- Verify monitoring setup
- Check Key Vault configuration
- Verify Azure Policy assignments
- Generate and upload a deployment report

### Azure DevOps Pipeline
Create `azure-pipelines.yml`:

```yaml
trigger:
  - main

pool:
  vmImage: 'ubuntu-latest'

steps:
- task: AzureCLI@2
  inputs:
    azureSubscription: 'YourServiceConnection'
    scriptType: 'bash'
    scriptLocation: 'inlineScript'
    inlineScript: |
      az deployment sub create \
        --name SinetLandingZoneDeployment \
        --location eastus \
        --template-file main.bicep \
        --parameters @parameters.json
```

---

## Troubleshooting Commands

### Check Deployment Status
```bash
# View deployment details
az deployment sub show --name SinetLandingZoneDeployment

# View deployment errors
az deployment sub show \
  --name SinetLandingZoneDeployment \
  --query 'properties.error'

# View operation logs
az deployment operation sub list --name SinetLandingZoneDeployment -o table
```

### Validate Template Before Deployment
```bash
# Validate syntax
az bicep build --file main.bicep

# Validate all modules
az bicep build --file modules/networking.bicep
az bicep build --file modules/monitoring.bicep
az bicep build --file modules/security.bicep
az bicep build --file modules/storage.bicep
az bicep build --file modules/policies.bicep
az bicep build --file modules/private-endpoints.bicep

# Validate against Azure
az deployment sub validate \
  --location eastus \
  --template-file main.bicep \
  --parameters @parameters.json
```

---

## Common Issues & Fixes

### Issue: Policy assignment fails
```bash
# Check if user has permissions
az role assignment list --scope /subscriptions/YOUR_SUB_ID

# Grant permissions if needed
az role assignment create \
  --role "User Access Administrator" \
  --assignee YOUR_EMAIL@example.com \
  --scope /subscriptions/YOUR_SUB_ID
```

### Issue: Resource group already exists
```bash
# Delete existing resource group
az group delete --name sinet-lz3-rg-eastus --yes

# Or use different project name
az deployment sub create \
  --name SinetLandingZoneDeployment2 \
  --location eastus \
  --template-file main.bicep \
  --parameters projectName="sinet-lz4"
```

### Issue: Insufficient quota
```bash
# In this template, quota can come from App Service Plan SKU.
# If Standard quota is 0, use Basic SKU override:
az deployment sub create \
  --name SinetLandingZoneDeployment \
  --location <YOUR_LOCATION> \
  --template-file main.bicep \
  --parameters @parameters.json appServicePlanSkuName="B1" appServicePlanSkuTier="Basic" appServicePlanCapacity=1

# If you only need network + security + VMs for now, skip App Service:
az deployment sub create \
  --name SinetLandingZoneDeployment \
  --location <YOUR_LOCATION> \
  --template-file main.bicep \
  --parameters @parameters.json deploySpokeAppService=false

# Also check VM quotas in region
az vm list-usage --location <YOUR_LOCATION> -o table
```

### Issue: Key Vault name exists in deleted state
```bash
# List soft-deleted vaults
az keyvault list-deleted -o table

# Option A: Recover the deleted vault
az keyvault recover --name <KEYVAULT_NAME>

# Option B: Purge it, then redeploy with same name
az keyvault purge --name <KEYVAULT_NAME> --location <YOUR_LOCATION>
```

### Issue: VNet peering fails
```bash
# Check if VNets exist
az network vnet show --name hubVnet --resource-group sinet-lz3-rg-eastus
az network vnet show --name spokeVnet --resource-group sinet-lz3-rg-eastus

# Manual peering if needed
az network vnet peering create \
  --name hub-to-spoke \
  --resource-group sinet-lz3-rg-eastus \
  --vnet-name hubVnet \
  --allow-vnet-access \
  --allow-forwarded-traffic \
  --remote-vnet /subscriptions/SUB_ID/resourceGroups/sinet-lz3-rg-eastus/providers/Microsoft.Network/virtualNetworks/spokeVnet
```

### Issue: Private Endpoint deployment fails
```bash
# Check if private DNS zones exist
az network private-dns zone list --resource-group sinet-lz3-rg-eastus

# Verify subnet IDs
az network vnet subnet show --name PaaSSvcSubnet --vnet-name spokeVnet --resource-group sinet-lz3-rg-eastus
```

---

## Cleanup Commands

```bash
# Delete everything in resource group
az group delete --name sinet-lz3-rg-eastus --yes

# Delete policy assignments
az policy assignment delete --name sinet-lz3-baseline-assignment

# Delete custom policy definitions
az policy definition delete --name sinet-lz3-enforce-tls-12
az policy definition delete --name sinet-lz3-enforce-https
az policy definition delete --name sinet-lz3-audit-kv-encryption
az policy definition delete --name sinet-lz3-require-tags

# Delete policy initiative
az policy set-definition delete --name sinet-lz3-baseline-initiative

# Delete private DNS zones (if not in resource group)
az network private-dns zone delete --name privatelink.blob.core.windows.net
az network private-dns zone delete --name privatelink.vaultcore.azure.net
```

---

## Performance & Monitoring

### Monitor Deployment Progress
```powershell
# Watch deployment in real-time
function Watch-Deployment() {
    while ($true) {
        $deployment = Get-AzDeployment -Name SinetLandingZoneDeployment
        Write-Host "$(Get-Date -Format 'HH:mm:ss') - State: $($deployment.ProvisioningState)"
        
        if ($deployment.ProvisioningState -eq 'Succeeded' -or 
            $deployment.ProvisioningState -eq 'Failed') {
            break
        }
        Start-Sleep -Seconds 10
    }
}

Watch-Deployment
```

### View Resource Costs
```bash
# After deployment, check costs in Azure Portal
# Or use cost management API

# Check Log Analytics for cost analysis
az monitor metrics list \
  --resource-group sinet-lz3-rg-eastus \
  --resource-type Microsoft.OperationalInsights/workspaces \
  --resource sinet-lz3-law-eastus-xxx \
  --metric AverageBillingUnits
```

---

## Post-Deployment Verification

### Verify Networking
```bash
# Check VNets
az network vnet list --resource-group sinet-lz3-rg-eastus -o table

# Check peerings
az network vnet peering list --resource-group sinet-lz3-rg-eastus --vnet-name hubVnet -o table

# Check NSGs
az network nsg list --resource-group sinet-lz3-rg-eastus -o table
```

### Verify Security
```bash
# Check Key Vault
az keyvault show --name sinet-lz3-kv-xxxxxxx --resource-group sinet-lz3-rg-eastus

# Check Private DNS Zones
az network private-dns zone list --resource-group sinet-lz3-rg-eastus -o table

# Check Private Endpoints
az network private-endpoint list --resource-group sinet-lz3-rg-eastus -o table
```

### Verify Monitoring
```bash
# Check Log Analytics
az monitor log-analytics workspace show --workspace-name sinet-lz3-laweastusxxxx --resource-group sinet-lz3-rg-eastus

# Check Action Group
az monitor action-group show --name sinet-lz3-ag-eastus --resource-group sinet-lz3-rg-eastus
```

### Verify Storage
```bash
# Check Storage Account
az storage account show --name sinetlz3stxxxxxx --resource-group sinet-lz3-rg-eastus

# Check Containers
az storage container list --account-name sinetlz3stxxxxxx
```

---

## Export Configuration

```bash
# Export deployment template
az deployment sub export \
  --name SinetLandingZoneDeployment \
  --query 'template' > exported-template.json

# Export resource group state
az resource list \
  --resource-group sinet-lz3-rg-eastus \
  --output json > resource-state.json
```

---

## Network Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         HUB VNET (10.100.0.0/16)                   │
├─────────────────────────────────────────────────────────────────────┤
│  ┌──────────────────┐                                              │
│  │ AzureFirewall    │ 10.100.0.0/24                               │
│  │ (Not deployed)   │                                              │
│  └──────────────────┘                                              │
│  ┌──────────────────┐                                              │
│  │ GatewaySubnet    │ 10.100.1.0/24                               │
│  └──────────────────┘                                              │
│  ┌──────────────────┐                                              │
│  │ BastionSubnet    │ 10.100.2.0/26                               │
│  └──────────────────┘                                              │
│  ┌──────────────────┐                                              │
│  │ PrivateDNSResolver│ 10.100.2.64/26                             │
│  └──────────────────┘                                              │
│  ┌──────────────────┐                                              │
│  │ IdentitySubnet   │ 10.100.2.128/26                             │
│  └──────────────────┘                                              │
│  ┌──────────────────┐                                              │
│  │ ManagementSubnet │ 10.100.3.0/24                               │
│  └──────────────────┘                                              │
└─────────────────────────────────────────────────────────────────────┘
                              ↕ VNet Peering
┌─────────────────────────────────────────────────────────────────────┐
│                       SPOKE VNET (10.200.0.0/16)                   │
├─────────────────────────────────────────────────────────────────────┤
│  ┌──────────────────┐  ┌──────────────────┐                      │
│  │ InfraSubnet      │  │ AppSubnet        │                      │
│  │ 10.200.0.0/24   │  │ 10.200.1.0/24    │                      │
│  └──────────────────┘  └──────────────────┘                      │
│  ┌──────────────────┐  ┌──────────────────┐                      │
│  │ DataSubnet       │  │ PaaSSvcSubnet    │                      │
│  │ 10.200.2.0/24   │  │ 10.200.3.0/24    │◄── Private Endpoints │
│  └──────────────────┘  └──────────────────┘     (Storage, KV)    │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Quick Links

- Main Documentation: [README.md](README.md)
- Architecture: [ARCHITECTURE.md](ARCHITECTURE.md)
- Project Summary: [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md)
- Main Template: [main.bicep](main.bicep)
- Parameters: [parameters.json](parameters.json)

---

**Deployment Support**: For issues, check the troubleshooting section or contact your Azure administrator.
