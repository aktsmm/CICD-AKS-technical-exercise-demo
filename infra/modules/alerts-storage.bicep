targetScope = 'resourceGroup'

@description('デプロイ対象環境名。アラートリソースの命名に利用します。')
param environment string

@description('アラート発火時に呼び出すアクショングループのリソース ID。通知が不要な場合は空文字のままとしてください。')
param actionGroupResourceId string = ''

var actionGroupEntries = empty(actionGroupResourceId) ? [] : [
  {
    actionGroupId: actionGroupResourceId
  }
]

resource storagePublicAccessAlert 'Microsoft.Insights/activityLogAlerts@2020-10-01' = {
  name: 'ala-storage-public-${environment}'
  location: 'global'
  properties: union({
    enabled: true
    description: 'Detects when blob public access is enabled on any storage account.'
    scopes: [
      subscription().id
    ]
    condition: {
      allOf: [
        {
          field: 'category'
          equals: 'Administrative'
        }
        {
          field: 'operationName'
          equals: 'Microsoft.Storage/storageAccounts/blobServices/default/setBlobServiceProperties/action'
        }
        {
          field: 'properties.status'
          equals: 'Succeeded'
        }
        {
          field: 'properties.responseBody'
          containsAny: [
            '"allowBlobPublicAccess":true'
          ]
        }
      ]
    }
  }, empty(actionGroupEntries) ? {} : {
    actions: {
      actionGroups: actionGroupEntries
    }
  })
}
