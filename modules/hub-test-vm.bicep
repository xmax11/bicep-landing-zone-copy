/*
  Hub Test VM Module - Deploys a single private VM in Hub ManagementSubnet
*/

param location string
param projectName string
param environment string
param hubManagementSubnetId string
param adminUsername string = 'azureuser'
@secure()
param adminPassword string
param vmSize string = 'Standard_D2s_v3'

var vmName = '${projectName}-hub-test-vm'

var commonTags = {
  environment: environment
  project: projectName
  role: 'hub-test-vm'
}

resource hubTestVmNic 'Microsoft.Network/networkInterfaces@2023-02-01' = {
  name: '${vmName}-nic'
  location: location
  tags: commonTags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: hubManagementSubnetId
          }
        }
      }
    ]
  }
}

resource hubTestVm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmName
  location: location
  tags: commonTags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-g2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    osProfile: {
      computerName: 'hubtestvm'
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: hubTestVmNic.id
          properties: {
            primary: true
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

output vmId string = hubTestVm.id
output vmName string = hubTestVm.name
output vmPrivateIp string = hubTestVmNic.properties.ipConfigurations[0].properties.privateIPAddress
