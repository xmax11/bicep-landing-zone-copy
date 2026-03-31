# Deployment Guide (Project: client-lz-005)

This guide is specific to the current repository state and `parameters.json` profile.

## 1. What This Deployment Creates

- Subscription-scoped deployment that creates one resource group
- Hub VNet + Spoke 1 + Spoke 2 topology
- Azure Firewall in hub
- Azure Bastion in hub
- Azure DNS Private Resolver in hub
- Key Vault + Storage + private endpoints (Storage and Key Vault)
- Two spoke VMs + one hub test VM
- Log Analytics workspace and action group
- Azure Policies are currently disabled in parameters
- App Service is currently disabled in parameters

## 2. Current Parameter Profile

| Setting | Current Value |
|---|---|
| `projectName` | `client-lz-005` |
| `location` | `eastus2` |
| `environment` | `production` |
| `deployFirewall` | `true` |
| `deployBastion` | `true` |
| `deployPrivateDnsResolver` | `true` |
| `deploySpokeAppService` | `false` |
| `deployWorkloadVms` | `true` |
| `deployHubTestVm` | `true` |
| `deployLogAnalytics` | `true` |
| `deployAzurePolicies` | `false` |
| `enableFirewallDefaultRoute` | `false` |

## 3. Prerequisites

- Azure CLI installed and logged in
- Bicep support available in Azure CLI
- Subscription-level permission to deploy resources
- Local access to this repository folder

Recommended checks:

```powershell
az version
az bicep version
az account show
```

## 4. Security First (Recommended Before Deploy)

`parameters.json` currently contains a plain-text VM admin password value. For safer deployment:

1. Remove the password from source-controlled parameter files.
2. Pass the password at deploy time (or from a secure secret store).
3. Rotate any password that has already been committed/shared.

## 5. Deployment Steps (Azure CLI)

Run from repository root:

```powershell
Set-Location "c:\Users\Zahid\Downloads\Bicep landing zone - Copy"
```

### Step 1: Set subscription context

```powershell
$Subscription = "<YOUR_SUBSCRIPTION_ID_OR_NAME>"
az login
az account set --subscription $Subscription
az account show --query "{name:name,id:id,tenantId:tenantId}" -o table
```

### Step 2: Define deployment variables

```powershell
$DeploymentName = "client-lz-005-$(Get-Date -Format yyyyMMdd-HHmmss)"
$TemplateFile = "main.bicep"
$ParametersFile = "parameters.json"
```

### Step 3: Validate template and parameters

```powershell
az bicep build --file $TemplateFile

az deployment sub validate `
  --name "$DeploymentName-validate" `
  --location eastus2 `
  --template-file $TemplateFile `
  --parameters @$ParametersFile
```

### Step 4: (Optional) Run what-if preview

```powershell
az deployment sub what-if `
  --name "$DeploymentName-whatif" `
  --location eastus2 `
  --template-file $TemplateFile `
  --parameters @$ParametersFile
```

### Step 5: Deploy

Safer deployment with runtime password override:

```powershell
$VmPassword = Read-Host "Enter VM admin password" -AsSecureString
$VmPasswordPlain = [System.Net.NetworkCredential]::new("", $VmPassword).Password

az deployment sub create `
  --name $DeploymentName `
  --location eastus2 `
  --template-file $TemplateFile `
  --parameters @$ParametersFile vmAdminPassword="$VmPasswordPlain"
```

If you keep using the password from `parameters.json`, omit the inline override.

## 6. Post-Deployment Verification

### Step 1: Get deployment outputs

```powershell
az deployment sub show `
  --name $DeploymentName `
  --query "properties.outputs" `
  -o jsonc
```

### Step 2: Capture resource group and key outputs

```powershell
$RgName = az deployment sub show --name $DeploymentName --query "properties.outputs.resourceGroupName.value" -o tsv
$DnsInboundIp = az deployment sub show --name $DeploymentName --query "properties.outputs.privateDnsResolverInboundEndpointIp.value" -o tsv

Write-Host "Resource Group: $RgName"
Write-Host "DNS Resolver Inbound IP: $DnsInboundIp"
```

### Step 3: Verify core resources for this project profile

```powershell
az network vnet list --resource-group $RgName -o table
az network azure-firewall list --resource-group $RgName -o table
az network bastion list --resource-group $RgName -o table
az network dns-resolver list --resource-group $RgName -o table
az network private-endpoint list --resource-group $RgName -o table
az vm list --resource-group $RgName -o table
```

Expected for current profile:

- 3 VNets (hub, spoke1, spoke2)
- Firewall present
- Bastion present
- DNS resolver present
- Private endpoints for Storage and Key Vault
- 3 VMs (spoke1 VM, spoke2 VM, hub test VM)
- No App Service resources
- No policy assignment changes from this deployment (policy module disabled)

## 7. Project-Specific Operational Notes

- Spoke UDRs currently disable BGP route propagation.
- Default internet egress is not force-routed through firewall (`enableFirewallDefaultRoute = false`).
- Management subnet bypasses firewall UDR association (`bypassFirewallForManagement = true`).
- Private DNS zones are hub-linked; spokes resolve through hub DNS Private Resolver.

## 8. ExpressRoute Next Step

If you want to extend this landing zone with on-premises private connectivity, use:

- `ExpressRoute.md`

That guide explains the full step-by-step process to add and connect ExpressRoute to this exact topology.
