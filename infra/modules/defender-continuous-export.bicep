targetScope = 'subscription'

@description('ポリシー割り当てのリソース名 (スコープ内で一意)。再デプロイ時の再利用を想定して固定値を推奨します。')
param assignmentName string = 'asc-continuous-export'

@description('連続エクスポートを配置するリソースグループ名。既存を使う場合は createResourceGroup を false にしてください。')
param resourceGroupName string

@description('リソースグループのリージョン。createResourceGroup が false の場合でもマネージド ID の location に利用します。')
param resourceGroupLocation string

@description('連続エクスポートで利用する Log Analytics ワークスペースのリソース ID。')
param workspaceResourceId string

@description('リソースグループが存在しない場合に作成するかどうか。既存グループのタグを維持したい場合は false を推奨します。')
param createResourceGroup bool = false

@description('エクスポート対象の Defender データタイプ一覧。スナップショットを含めたデフォルト構成です。')
param exportedDataTypes array = [
  'Security recommendations'
  'Security alerts'
  'Overall secure score'
  'Secure score controls'
  'Regulatory compliance'
  'Overall secure score - snapshot'
  'Secure score controls - snapshot'
  'Regulatory compliance - snapshot'
  'Security recommendations - snapshot'
  'Security findings - snapshot'
]

@description('特定の推奨事項のみを出力したい場合の推奨 ID。特に指定が無ければ空配列のままとします。')
param recommendationNames array = []

@description('推奨事項を出力する際に含める深刻度。')
param recommendationSeverities array = [
  'High'
  'Medium'
  'Low'
]

@description('セキュリティアラートを出力する際に含める深刻度。')
param alertSeverities array = [
  'High'
  'Medium'
  'Low'
]

@description('セキュアスコア コントロールで特定 ID のみを出力したい場合の一覧。')
param secureScoreControlsNames array = []

@description('規制コンプライアンスで特定スタンダードのみを出力したい場合の一覧。')
param regulatoryComplianceStandardsNames array = []

@description('脆弱性アセスメント結果などセキュリティファインディングの出力を含めるかどうか。')
param enableSecurityFindings bool = true

var policyDefinitionId = '/providers/Microsoft.Authorization/policyDefinitions/ffb6f416-7bd2-4488-8828-56585fef2be9'

// Defender 連続エクスポートを Azure Policy の DeployIfNotExists で有効化する。
resource defenderContinuousExport 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: assignmentName
  location: resourceGroupLocation
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: 'Deploy export to Log Analytics workspace for Microsoft Defender for Cloud data'
    description: 'Configures continuous export of Defender for Cloud alerts and recommendations via policy.'
    policyDefinitionId: policyDefinitionId
    enforcementMode: 'Default'
    parameters: {
      resourceGroupName: {
        value: resourceGroupName
      }
      resourceGroupLocation: {
        value: resourceGroupLocation
      }
      createResourceGroup: {
        value: createResourceGroup
      }
      exportedDataTypes: {
        value: exportedDataTypes
      }
      recommendationNames: {
        value: recommendationNames
      }
      recommendationSeverities: {
        value: recommendationSeverities
      }
      alertSeverities: {
        value: alertSeverities
      }
      secureScoreControlsNames: {
        value: secureScoreControlsNames
      }
      regulatoryComplianceStandardsNames: {
        value: regulatoryComplianceStandardsNames
      }
      isSecurityFindingsEnabled: {
        value: enableSecurityFindings
      }
      workspaceResourceId: {
        value: workspaceResourceId
      }
    }
  }
}

output policyAssignmentId string = defenderContinuousExport.id
