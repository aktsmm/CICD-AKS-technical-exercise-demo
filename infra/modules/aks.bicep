@description('デプロイ先リージョン')
param location string

@description('環境名')
param environment string

@description('サブネットID')
param subnetId string

@description('Log Analytics Workspace ID')
param logAnalyticsWorkspaceId string

var clusterName = 'aks-${environment}'

// AKSクラスター
resource aks 'Microsoft.ContainerService/managedClusters@2023-10-01' = {
  name: clusterName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: clusterName
    // パブリック クラスターを想定して API Server を公開
    apiServerAccessProfile: {
      enablePrivateCluster: false
    }
    agentPoolProfiles: [
      {
        name: 'nodepool1'
        count: 2
        vmSize: 'Standard_B2s'
        osType: 'Linux'
        mode: 'System'
        vnetSubnetID: subnetId
      }
    ]
    networkProfile: {
      networkPlugin: 'azure'
      serviceCidr: '10.1.0.0/16'
      dnsServiceIP: '10.1.0.10'
      loadBalancerSku: 'standard'
      // LoadBalancer を Public に設定して Ingress 経由の外部アクセスを許可
      outboundType: 'loadBalancer'
    }
    // 監査ログ有効化
    addonProfiles: {
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalyticsWorkspaceId
        }
      }
    }
    // 脆弱性注意: RBACは有効だが、後でCluster Admin権限を不適切に付与
    enableRBAC: true
  }
}

output clusterName string = aks.name
// パブリッククラスターなので通常の FQDN を使用
output clusterFqdn string = aks.properties.fqdn
output kubeletIdentity string = aks.properties.identityProfile.kubeletidentity.objectId
output clusterResourceId string = aks.id
