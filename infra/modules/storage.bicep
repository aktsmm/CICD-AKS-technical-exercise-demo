@description('デプロイ先リージョン')
param location string

@description('環境名')
param environment string

@description('Public Blob Access許可（脆弱性）')
param allowPublicBlobAccess bool = true

var storageAccountName = 'stwiz${environment}${uniqueString(resourceGroup().id)}'

// Storage Account（脆弱性: Public Access有効）
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Cool'
    allowBlobPublicAccess: allowPublicBlobAccess  // 脆弱性
    minimumTlsVersion: 'TLS1_0'  // 脆弱性: 古いTLS
    supportsHttpsTrafficOnly: false  // 脆弱性: HTTP許可
  }
}

// Blob Container（Public Access）
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
}

resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'backups'
  properties: {
    publicAccess: 'Blob'  // 脆弱性: Public Read
  }
}

output storageAccountName string = storageAccount.name
output containerName string = container.name
output storageAccountId string = storageAccount.id
