@description('デプロイ先リージョン')
param location string

@description('環境名')
param environment string

@description('Log Analytics Workspace ID')
param workspaceId string

var workbookName = 'workbook-security-${environment}'
var workbookDisplayName = 'Security Dashboard - ${environment}'

resource securityWorkbook 'Microsoft.Insights/workbooks@2022-04-01' = {
  name: guid(workbookName)
  location: location
  kind: 'shared'
  properties: {
    displayName: workbookDisplayName
    category: 'security'
    serializedData: loadTextContent('workbook-security.json')
    sourceId: workspaceId
    version: '1.0'
  }
}

output workbookId string = securityWorkbook.id
output workbookName string = securityWorkbook.name
