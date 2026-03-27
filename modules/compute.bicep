/*
  Compute Module - Deploys one IaaS VM into each spoke Infra subnet
*/

param location string
param projectName string
param environment string
param spoke1InfraSubnetId string
param spoke2InfraSubnetId string
param adminUsername string = 'azureuser'
@secure()
param adminPassword string
param vmSize string = 'Standard_D2s_v3'

var commonTags = {
  environment: environment
  project: projectName
}

var vmDefinitions = [
  {
    vmName: '${projectName}-spoke1-vm'
    computerName: 'spoke1vm'
    subnetId: spoke1InfraSubnetId
  }
  {
    vmName: '${projectName}-spoke2-vm'
    computerName: 'spoke2vm'
    subnetId: spoke2InfraSubnetId
  }
]

resource vmNics 'Microsoft.Network/networkInterfaces@2023-02-01' = [for (vm, i) in vmDefinitions: {
  name: '${vm.vmName}-nic'
  location: location
  tags: union(commonTags, { spoke: string(i + 1) })
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vm.subnetId
          }
        }
      }
    ]
  }
}]

resource windowsVms 'Microsoft.Compute/virtualMachines@2023-09-01' = [for (vm, i) in vmDefinitions: {
  name: vm.vmName
  location: location
  tags: union(commonTags, {
    spoke: string(i + 1)
    workloadType: 'iaas-demo'
  })
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
      computerName: vm.computerName
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vmNics[i].id
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
}]

output vmIds array = [for i in range(0, length(vmDefinitions)): windowsVms[i].id]
output vmNames array = [for i in range(0, length(vmDefinitions)): windowsVms[i].name]
output vmPrivateIps array = [for i in range(0, length(vmDefinitions)): vmNics[i].properties.ipConfigurations[0].properties.privateIPAddress]
