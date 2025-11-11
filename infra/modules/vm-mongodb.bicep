@description('デプロイ先リージョン')
param location string

@description('環境名')
param environment string

@description('管理者パスワード')
@secure()
param adminPassword string

@description('VM 管理者ユーザー名 (デモでは既定を固定し脆弱性を残す)')
param adminUsername string = 'azureuser'

@description('サブネットID')
param subnetId string

@description('SSH公開許可（脆弱性）')
param allowSSHFromInternet bool = true

@description('Storage Account名（バックアップ先）')
param storageAccountName string

@description('バックアップコンテナ名')
param backupContainerName string = 'backups'

@description('MongoDB管理者パスワード')
@secure()
param mongoAdminPassword string

@description('VM拡張の強制更新タグ')
param forceUpdateTag string = utcNow()

var vmName = 'vm-mongo-${environment}'
var nicName = '${vmName}-nic'
var nsgName = '${vmName}-nsg'
var publicIPName = '${vmName}-pip'

// Public IP（脆弱性: VM直接公開）
resource publicIP 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: publicIPName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// NSG（脆弱性: SSH全開放）
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH-Internet'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: allowSSHFromInternet ? '*' : 'VirtualNetwork'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'Allow-MongoDB'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '27017'
          sourceAddressPrefix: '10.0.1.0/24'  // AKS サブネット経由のアクセスに限定
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// NIC
resource nic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIP.id
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: nsg.id
    }
  }
}

// VM（脆弱性: 古いUbuntu 18.04）
resource vm 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: vmName
  location: location
  identity: {
    type: 'SystemAssigned'  // 脆弱性: 過剰な権限付与のためManaged Identityを有効化
  }
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B2s'
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername  // Default keeps intentional vulnerability visible
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-focal'  // Ubuntu 20.04 LTS (Focal Fossa)
        sku: '20_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

// AMA 拡張を導入して Log Analytics へ Linux ゲスト情報を送信
resource vmAmaExtension 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = {
  parent: vm
  name: 'AzureMonitorLinuxAgent'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorLinuxAgent'
    typeHandlerVersion: '1.21'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
  }
}

// MongoDB インストールスクリプト（認証付き）
resource vmExtension 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = {
  parent: vm
  name: 'install-mongodb'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    forceUpdateTag: forceUpdateTag  // 毎回拡張を再実行
    settings: {
      fileUris: [
        'https://raw.githubusercontent.com/aktsmm/CICD-AKS-technical-exercise-demo/main/infra/scripts/install-mongodb.sh'
        'https://raw.githubusercontent.com/aktsmm/CICD-AKS-technical-exercise-demo/main/infra/scripts/setup-mongodb-auth.sh'
        'https://raw.githubusercontent.com/aktsmm/CICD-AKS-technical-exercise-demo/main/infra/scripts/setup-backup.sh'
      ]
    }
    protectedSettings: {
      commandToExecute: 'bash install-mongodb.sh && MONGO_ADMIN_PASSWORD="${mongoAdminPassword}" bash setup-mongodb-auth.sh && MONGO_ADMIN_PASSWORD="${mongoAdminPassword}" bash setup-backup.sh ${storageAccountName} ${backupContainerName}'
    }
  }
}

output publicIP string = publicIP.properties.ipAddress
output privateIP string = nic.properties.ipConfigurations[0].properties.privateIPAddress
output vmIdentityPrincipalId string = vm.identity.principalId
output vmName string = vm.name
output nsgName string = nsg.name
