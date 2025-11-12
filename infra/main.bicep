targetScope = 'subscription'

@description('リソースグループ名')
param resourceGroupName string = 'rg-bbs-cicd-aks'

@description('デプロイ先リージョン')
param location string = 'japaneast'

@description('環境名')
param environment string = 'dev'

@description('MongoDB管理者pass')
@secure()
param mongoAdminPassword string

@description('Object ID for the GitHub Actions service principal that runs infrastructure deployments.')
param automationPrincipalObjectId string = ''

@description('Grant the automation principal Owner at subscription scope. Use sparingly to keep least privilege.')
param grantAutomationPrincipalOwner bool = false

@description('既存 Storage Blob Data Contributor ロール割り当て名 (GUID)。既存がある場合は入力。')
param existingStorageRoleAssignmentName string = ''

@description('既存 Virtual Machine Contributor ロール割り当て名 (GUID)。既存がある場合は入力。')
param existingVmContributorRoleAssignmentName string = ''

@description('デプロイタイムスタンプ!! (ユニークなデプロイ名生成)')
param deploymentTimestamp string = utcNow('yyyyMMddHHmmss')

@description('Storage Account のパブリックアクセス有効化を検知するアクティビティログアラートをデプロイする場合に true。')
param enableStoragePublicAccessAlert bool = true

@description('アラート通知に利用する既存アクショングループのリソース ID。通知が不要な場合は空文字のままとしてください。')
param storagePublicAccessActionGroupId string = ''

@description('Microsoft Defender for Cloud の連続エクスポートを有効化する場合に true。')
param enableDefenderContinuousExport bool = false

@description('連続エクスポート構成のポリシー割り当て名。再デプロイ時に同じ値を利用して整合性を保ちます。')
param defenderContinuousExportAssignmentName string = 'asc-cont-export-${environment}'

@description('連続エクスポートで利用するリソースグループ名。既存のインフラリソースグループを流用する場合はその名称を指定します。')
param defenderContinuousExportResourceGroupName string = resourceGroupName

@description('連続エクスポート用リソースグループのリージョン。')
param defenderContinuousExportResourceGroupLocation string = location

var defenderPlanNames = [
  'VirtualMachines'
  'AppServices'
  'StorageAccounts'
  'SqlServers'
  'SqlServerVirtualMachines'
  'KubernetesService'
  'ContainerRegistry'
]

// リソースグループ作成
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
}

module automationRbac 'modules/rbac-bootstrap.bicep' = if (automationPrincipalObjectId != '') {
  scope: rg
  name: 'rbac-rg-${deploymentTimestamp}'
  params: {
    principalObjectId: automationPrincipalObjectId
  }
}

module automationOwner 'modules/rbac-bootstrap-owner.bicep' = if (grantAutomationPrincipalOwner && automationPrincipalObjectId != '') {
  name: 'rbac-owner-${deploymentTimestamp}'
  params: {
    principalObjectId: automationPrincipalObjectId
  }
}

// ネットワーキング
module networking 'modules/networking.bicep' = {
  scope: rg
  name: 'networking-${deploymentTimestamp}'
  params: {
    location: location
    environment: environment
  }
}

// Log Analytics (監査ログ用)
module monitoring 'modules/monitoring.bicep' = {
  scope: rg
  name: 'monitoring-${deploymentTimestamp}'
  params: {
    location: location
    environment: environment
  }
}

// Security Workbook (監査ログ/Defenderアラート可視化)
module securityWorkbook 'modules/workbook-security.bicep' = {
  scope: rg
  name: 'workbook-${deploymentTimestamp}'
  params: {
    location: location
    environment: environment
    workspaceId: monitoring.outputs.workspaceId
  }
}

resource subscriptionActivityDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'activitylog-to-law-${environment}'
  scope: subscription()
  properties: {
    workspaceId: monitoring.outputs.workspaceId
    logs: [
      {
        category: 'Administrative'
        enabled: true
      }
      {
        category: 'Security'
        enabled: true
      }
      {
        category: 'ServiceHealth'
        enabled: true
      }
      {
        category: 'Alert'
        enabled: true
      }
      {
        category: 'Recommendation'
        enabled: true
      }
      {
        category: 'Policy'
        enabled: true
      }
      {
        category: 'Autoscale'
        enabled: true
      }
      {
        category: 'ResourceHealth'
        enabled: true
      }
    ]
  }
}

resource defenderForCloudPlans 'Microsoft.Security/pricings@2022-03-01' = [for planName in defenderPlanNames: {
  name: planName
  properties: {
    pricingTier: 'Standard'
  }
}]

// Storage Account (脆弱な構成)
module storage 'modules/storage.bicep' = {
  scope: rg
  name: 'storage-${deploymentTimestamp}'
  params: {
    location: location
    environment: environment
    // 脆弱性: Public Access有効
    allowPublicBlobAccess: true
  }
}

// Azure Container Registry (脆弱な構成)
module acr 'modules/acr.bicep' = {
  scope: rg
  name: 'acr-${deploymentTimestamp}'
  params: {
    location: location
    environment: environment
  }
}

// MongoDB VM (脆弱な構成)
module mongoVM 'modules/vm-mongodb.bicep' = {
  scope: rg
  name: 'mongodb-${deploymentTimestamp}'
  params: {
    location: location
    environment: environment
    adminPassword: mongoAdminPassword
    mongoAdminPassword: mongoAdminPassword
    subnetId: networking.outputs.mongoSubnetId
    storageAccountName: storage.outputs.storageAccountName
    backupContainerName: storage.outputs.containerName
    // 脆弱性: SSH公開
    allowSSHFromInternet: true
  }
}

module vmStorageRole 'modules/vm-storage-role.bicep' = {
  scope: rg
  name: 'vm-storage-role-${deploymentTimestamp}'
  params: {
    vmPrincipalId: mongoVM.outputs.vmIdentityPrincipalId
    storageAccountName: storage.outputs.storageAccountName
    existingStorageAssignmentName: existingStorageRoleAssignmentName
    existingVmContributorAssignmentName: existingVmContributorRoleAssignmentName
  }
}

// AKSクラスター
module aks 'modules/aks.bicep' = {
  scope: rg
  name: 'aks-${deploymentTimestamp}'
  params: {
    location: location
    environment: environment
    subnetId: networking.outputs.aksSubnetId
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceId
  }
}

module aksAcrRole 'modules/aks-acr-role.bicep' = {
  scope: rg
  name: 'aks-acr-role-${deploymentTimestamp}'
  params: {
    kubeletIdentityPrincipalId: aks.outputs.kubeletIdentity
    acrName: acr.outputs.acrName
  }
}

module diagnostics 'modules/diagnostics.bicep' = {
  scope: rg
  name: 'diagnostics-${deploymentTimestamp}'
  params: {
    workspaceId: monitoring.outputs.workspaceId
    storageAccountName: storage.outputs.storageAccountName
    acrName: acr.outputs.acrName
    aksName: aks.outputs.clusterName
    vmName: mongoVM.outputs.vmName
    nsgName: mongoVM.outputs.nsgName
    vnetName: networking.outputs.vnetName
  }
}

module storageAlerts 'modules/alerts-storage.bicep' = if (enableStoragePublicAccessAlert) {
  scope: rg
  name: 'alerts-storage-${deploymentTimestamp}'
  params: {
    environment: environment
    actionGroupResourceId: storagePublicAccessActionGroupId
  }
}

module defenderContinuousExport 'modules/defender-continuous-export.bicep' = if (enableDefenderContinuousExport) {
  name: 'defender-cont-export-${deploymentTimestamp}'
  params: {
    assignmentName: defenderContinuousExportAssignmentName
    resourceGroupName: defenderContinuousExportResourceGroupName
    resourceGroupLocation: defenderContinuousExportResourceGroupLocation
    workspaceResourceId: monitoring.outputs.workspaceId
  }
}

output aksClusterName string = aks.outputs.clusterName
output mongoVMPublicIP string = mongoVM.outputs.publicIP
output mongoVMPrivateIP string = mongoVM.outputs.privateIP
output storageAccountName string = storage.outputs.storageAccountName
output acrName string = acr.outputs.acrName
output acrLoginServer string = acr.outputs.acrLoginServer
output kubeletIdentityPrincipalId string = aks.outputs.kubeletIdentity
output mongoVMIdentityPrincipalId string = mongoVM.outputs.vmIdentityPrincipalId
output logAnalyticsWorkspaceId string = monitoring.outputs.workspaceId
output securityWorkbookId string = securityWorkbook.outputs.workbookId
