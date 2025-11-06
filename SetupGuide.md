# 初回セットアップガイド

このガイドでは、新しい環境にこのプロジェクトをデプロイするための完全な手順を説明します。

## 📋 前提条件

以下のツールがインストールされていることを確認してください:

- **[Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli)** (最新版)
- **[GitHub CLI](https://cli.github.com/)** (`gh`)
- **Git**
- **PowerShell 7+** (推奨) または **Bash**

## 🚀 クイックスタート（3 ステップ）

```powershell
# 1. Service Principalを作成
.\Scripts\Setup-ServicePrincipal.ps1 -SubscriptionId "<YOUR_SUBSCRIPTION_ID>"

# 2. GitHub Secretsを設定
.\Scripts\Setup-GitHubSecrets.ps1

# 3. デプロイ実行
gh workflow run infra-deploy.yml
```

---

## 📖 詳細セットアップ手順

### ステップ 1: Azure 環境の準備

#### 1-1. Azure にログイン

```powershell
# Azureにログイン
az login

# 使用するサブスクリプションを確認
az account list --output table

# サブスクリプションを設定
az account set --subscription "<YOUR_SUBSCRIPTION_ID>"
```

**💡 ヒント:** テナント ID を指定する場合は `az login --tenant <TENANT_ID>` を使用します。

#### 1-2. サブスクリプション ID の確認

```powershell
# 現在のサブスクリプションIDを取得
az account show --query id -o tsv
```

**出力例:** `832c4080-181c-476b-9db0-b3ce9596d40a`

この ID を次のステップで使用します。

---

### ステップ 2: Service Principal の作成 🔐

**自動化スクリプトを使用します（推奨）:**

```powershell
# プロジェクトのルートディレクトリに移動
cd d:\00_temp\wizwork\CICD-AKS-technical-exercise

# Service Principalセットアップスクリプトを実行
.\Scripts\Setup-ServicePrincipal.ps1 -SubscriptionId "<YOUR_SUBSCRIPTION_ID>"
```

**このスクリプトが自動的に実行すること:**

1. ✅ Service Principal の作成（または既存のものを使用）
2. ✅ 必要な 3 つのロールの割り当て:
   - **Contributor** - リソース管理
   - **Resource Policy Contributor** - Azure Policy 管理
   - **User Access Administrator** - RBAC 自動管理
3. ✅ GitHub Secrets 用 JSON の生成
4. ✅ クリップボードへの自動コピー（Windows/macOS/Linux）

**⚠️ スクリプト実行時の注意:**

- 既存の Service Principal が見つかった場合、再利用または再作成を選択できます
- 出力される JSON は **1 回しか表示されません** - 必ずコピーしてください
- Windows の場合、JSON は自動的にクリップボードにコピーされます

**出力例:**

```
🚀 GitHub Actions用Service Principalセットアップ開始

📌 サブスクリプション設定: 832c4080-181c-476b-9db0-b3ce9596d40a
   ✅ サブスクリプション: Azure subscription 1

🔐 Service Principal作成/確認: sp-wizexercise-github
   🆕 新しいService Principalを作成中...
   ✅ Service Principal作成完了
   App ID: 493ba101-1a1c-48f2-babd-46e13e04d710
   Object ID: da54fda7-b30b-41ac-869b-f5ed9725ea4d

🔒 必要な権限を付与中...
   📋 ロール: Contributor
      ✅ 割り当て完了
   📋 ロール: Resource Policy Contributor
      ✅ 割り当て完了
   📋 ロール: User Access Administrator
      ✅ 割り当て完了

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ セットアップ完了!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📌 次のステップ:

1. GitHubリポジトリの Settings > Secrets and variables > Actions を開く

2. 以下のSecretを作成/更新:

   Secret名: AZURE_CREDENTIALS
   値:
   {"clientId":"493ba101-...","clientSecret":"Nhy8Q~~...","subscriptionId":"832c4080-...","tenantId":"a816de9e-..."}

   Secret名: AZURE_SUBSCRIPTION_ID
   値: 832c4080-181c-476b-9db0-b3ce9596d40a

📋 AZURE_CREDENTIALS の値をクリップボードにコピーしました!
```

---

### ステップ 3: MongoDB パスワードの生成 🔑

```powershell
# セキュアなランダムパスワードを生成（32文字）
$mongoPassword = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | ForEach-Object {[char]$_})
Write-Host "MongoDB Password: $mongoPassword" -ForegroundColor Green

# パスワードをクリップボードにコピー
$mongoPassword | Set-Clipboard
Write-Host "✅ パスワードをクリップボードにコピーしました" -ForegroundColor Cyan
```

**出力例:** `ZGLvtXB3z1b8Q5glsWTdUaPSHEN627My`

**💾 このパスワードを安全に保存してください** - 次のステップで GitHub Secrets に設定します。

---

### ステップ 4: GitHub リポジトリの準備 🐙

#### 4-1. リポジトリをクローン（まだの場合）

```powershell
# リポジトリをクローン
git clone https://github.com/YOUR_USERNAME/CICD-AKS-technical-exercise.git
cd CICD-AKS-technical-exercise

# GitHub CLIで認証
gh auth login
```

#### 4-2. GitHub Secrets の設定

**方法 1: GitHub CLI を使用（推奨）**

> ⚠️ **重要な注意事項:**
>
> - 複数のリモートリポジトリがある場合は、すべてのコマンドに `-R <owner>/<repo>` オプションを付けてください
> - コマンド実行後は必ず `gh secret list` と `gh variable list` で設定を確認してください
> - `AZURE_SUBSCRIPTION_ID` が設定されていないとワークフローが失敗します

```powershell
# 【重要】作業ディレクトリがプロジェクトルートであることを確認
cd d:\00_temp\wizwork\CICD-AKS-technical-exercise

# リモートリポジトリを確認（複数ある場合は-Rオプションが必須）
git remote -v

# AZURE_CREDENTIALS を設定
# ステップ2で取得したJSON全体を一時ファイルに保存
@"
{
  "clientId": "<CLIENT_ID>",
  "clientSecret": "<CLIENT_SECRET>",
  "subscriptionId": "<SUBSCRIPTION_ID>",
  "tenantId": "<TENANT_ID>"
}
"@ | Out-File -FilePath azure_creds.json -Encoding UTF8

# Secretに設定（リポジトリ指定）
Get-Content azure_creds.json | gh secret set AZURE_CREDENTIALS -R <YOUR_USERNAME>/<YOUR_REPO>

# 一時ファイルを削除
Remove-Item azure_creds.json -Force

# 【重要】個別のSecretsを設定（ワークフロー実行に必須）
gh secret set AZURE_SUBSCRIPTION_ID --body '<YOUR_SUBSCRIPTION_ID>' -R <YOUR_USERNAME>/<YOUR_REPO>
gh secret set AZURE_CLIENT_ID --body '<CLIENT_ID_FROM_STEP2>' -R <YOUR_USERNAME>/<YOUR_REPO>
gh secret set AZURE_TENANT_ID --body '<TENANT_ID_FROM_STEP2>' -R <YOUR_USERNAME>/<YOUR_REPO>
gh secret set MONGO_ADMIN_PASSWORD --body '<MONGO_PASSWORD_FROM_STEP3>' -R <YOUR_USERNAME>/<YOUR_REPO>

# 【必須】設定を確認
Write-Host "`n✅ Secrets設定確認:" -ForegroundColor Cyan
gh secret list

Write-Host "`n📋 必須Secretsチェックリスト:" -ForegroundColor Yellow
$requiredSecrets = @(
    'AZURE_CREDENTIALS',
    'AZURE_SUBSCRIPTION_ID',
    'AZURE_CLIENT_ID',
    'AZURE_TENANT_ID',
    'MONGO_ADMIN_PASSWORD'
)
$existingSecrets = gh secret list --json name -q '.[].name'
foreach ($secret in $requiredSecrets) {
    if ($existingSecrets -contains $secret) {
        Write-Host "  ✅ $secret" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $secret - 未設定！" -ForegroundColor Red
    }
}
```

> 💡 **Tip**: 複数のリモートリポジトリがある場合は、`-R <owner>/<repo>`オプションでリポジトリを明示的に指定してください。
>
> **実行例:**
>
> ```powershell
> # 例: aktsmm/CICD-AKS-technical-exerciseリポジトリに設定
> gh secret set AZURE_SUBSCRIPTION_ID --body '832c4080-181c-476b-9db0-b3ce9596d40a' -R aktsmm/CICD-AKS-technical-exercise
> ```

**方法 2: GitHub Web UI を使用**

1. GitHub リポジトリページを開く
2. **Settings** > **Secrets and variables** > **Actions** に移動
3. **New repository secret** をクリック
4. 以下の Secrets を追加:

| Secret 名               | 値の取得元                               | 必須 |
| ----------------------- | ---------------------------------------- | ---- |
| `AZURE_CREDENTIALS`     | ステップ 2 のスクリプト出力（JSON 全体） | ✅   |
| `AZURE_SUBSCRIPTION_ID` | ステップ 2 のスクリプト出力              | ✅   |
| `AZURE_CLIENT_ID`       | ステップ 2 のスクリプト出力（clientId）  | ✅   |
| `AZURE_TENANT_ID`       | ステップ 2 のスクリプト出力（tenantId）  | ✅   |
| `MONGO_ADMIN_PASSWORD`  | ステップ 3 で生成したパスワード          | ✅   |
| `GITGUARDIAN_API_KEY`   | GitGuardian ダッシュボードから取得       | 任意 |

#### 4-3. GitHub Variables の設定

```powershell
# 【重要】作業ディレクトリがプロジェクトルートであることを確認
cd d:\00_temp\wizwork\CICD-AKS-technical-exercise

# Service PrincipalのオブジェクトIDを取得
$objectId = az ad sp list --display-name "sp-wizexercise-github" --query "[0].id" -o tsv

# Variables を設定（複数リモートがある場合は -R オプションを追加）
gh variable set AZURE_RESOURCE_GROUP --body 'rg-bbs-cicd-aks'
gh variable set AZURE_LOCATION --body 'japaneast'
gh variable set IMAGE_NAME --body 'bbs-app'
gh variable set AZURE_GITHUB_PRINCIPAL_ID --body $objectId
gh variable set AZURE_GRANT_GITHUB_OWNER --body 'false'

# 【必須】設定を確認
Write-Host "`n✅ Variables設定確認:" -ForegroundColor Cyan
gh variable list

Write-Host "`n📋 必須Variablesチェックリスト:" -ForegroundColor Yellow
$requiredVariables = @(
    'AZURE_RESOURCE_GROUP',
    'AZURE_LOCATION',
    'IMAGE_NAME',
    'AZURE_GITHUB_PRINCIPAL_ID',
    'AZURE_GRANT_GITHUB_OWNER'
)
$existingVariables = gh variable list --json name -q '.[].name'
foreach ($variable in $requiredVariables) {
    if ($existingVariables -contains $variable) {
        Write-Host "  ✅ $variable" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $variable - 未設定！" -ForegroundColor Red
    }
}
```

> ⚠️ **重要:** `AZURE_GITHUB_PRINCIPAL_ID`は**Variable**として設定してください（Secret ではありません）。誤って Secret に設定した場合は削除してください:
>
> ```powershell
> # 誤って設定したSecretを削除
> gh secret remove AZURE_GITHUB_PRINCIPAL_ID
> ```

**Variables の説明:**

| Variable 名                 | 説明                                                      | 推奨値              |
| --------------------------- | --------------------------------------------------------- | ------------------- |
| `AZURE_RESOURCE_GROUP`      | デプロイ先のリソースグループ名                            | `rg-aks-wizio-demo` |
| `AZURE_LOCATION`            | Azure リージョン                                          | `japaneast`         |
| `IMAGE_NAME`                | コンテナイメージ名                                        | `bbs-app`           |
| `AZURE_GITHUB_PRINCIPAL_ID` | Service Principal のオブジェクト ID（自動取得）           | -                   |
| `AZURE_GRANT_GITHUB_OWNER`  | Owner ロール自動付与フラグ（本番環境では `false` を推奨） | `false`             |

---

### ステップ 5: デプロイの実行 🚀

#### 5-1. インフラストラクチャのデプロイ

```powershell
# GitHub Actionsワークフローを実行
gh workflow run infra-deploy.yml

# 実行状況を確認
gh run list --workflow="infra-deploy.yml" --limit 5

# リアルタイムで監視
gh run watch
```

**デプロイされるリソース:**

- ✅ Azure Kubernetes Service (AKS)
- ✅ Azure Container Registry (ACR) - AKS との自動統合済み
- ✅ MongoDB VM (Ubuntu 22.04)
- ✅ Virtual Network & Subnets（セキュアなネットワーク分離）
- ✅ Storage Account（MongoDB バックアップ用）
- ✅ Log Analytics Workspace
- ✅ Azure Monitor Workbook（可視化ダッシュボード）
- ✅ Azure Policy（セキュリティコントロール）

**⏱️ 所要時間:** 約 15-20 分

**✅ デプロイ完了の確認:**

```powershell
# リソースグループ内のリソースを確認
az resource list --resource-group rg-aks-wizio-demo --output table

# AKSクラスターの状態を確認
az aks show --resource-group rg-aks-wizio-demo --name aksexercise --query "provisioningState" -o tsv
```

#### 5-2. アプリケーションのデプロイ

インフラデプロイ完了後、アプリケーションをデプロイします:

```powershell
# アプリデプロイワークフローを実行
gh workflow run 02-1.app-deploy.yml

# 実行状況を確認
gh run watch
```

**デプロイ内容:**

- ✅ Node.js アプリケーションのビルド
- ✅ Docker イメージの作成と ACR へのプッシュ
- ✅ Kubernetes マニフェストの適用
- ✅ Ingress の設定（HTTP/HTTPS）
- ✅ 自己署名証明書の生成

**⏱️ 所要時間:** 約 5-10 分

---

## ✅ ステップ 6: 動作確認

### 6-1. アプリケーションへのアクセス

```powershell
# External IPを取得
kubectl get svc nginx-ingress-controller -n ingress-nginx

# Ingressの確認
kubectl get ingress guestbook-ingress
```

**アクセス URL:**

- **HTTP:** `http://<EXTERNAL_IP>`
- **HTTPS:** `https://<EXTERNAL_IP>.nip.io`

**💡 ヒント:** GitHub Actions の実行ログにも URL が表示されます。

### 6-2. Kubernetes クラスターへの接続

```powershell
# AKS認証情報を取得
az aks get-credentials `
  --resource-group rg-aks-wizio-demo `
  --name aksexercise `
  --overwrite-existing

# Podの状態を確認
kubectl get pods -A

# アプリケーションのログを確認
kubectl logs -l app=guestbook --tail=50
```

### 6-3. MongoDB 接続確認

```powershell
# MongoDB VMのプライベートIPを取得
$mongoIp = az vm show --resource-group rg-aks-wizio-demo --name vm-mongo-dev --show-details --query privateIps -o tsv

# AKSのPodから接続テスト
kubectl run mongodb-test --image=mongo:7.0 --rm -it --restart=Never -- \
  mongosh "mongodb://mongoadmin:<PASSWORD>@${mongoIp}:27017/guestbook?authSource=admin"
```

### 6-4. セキュリティスキャン結果の確認

```powershell
# GitHub Securityタブを開く
gh browse --repo YOUR_USERNAME/CICD-AKS-technical-exercise /security

# または
start https://github.com/YOUR_USERNAME/CICD-AKS-technical-exercise/security
```

**確認項目:**

- **Checkov**: Bicep/Kubernetes マニフェストの静的解析結果
- **Trivy**: コンテナイメージの脆弱性スキャン結果
- **GitGuardian**: シークレット漏洩検出結果（API キー設定時のみ）

---

## 📊 設定内容の完全なリスト

### GitHub Secrets 一覧

| Secret 名               | 説明                                | 例 / 形式                                   |
| ----------------------- | ----------------------------------- | ------------------------------------------- |
| `AZURE_CREDENTIALS`     | Service Principal JSON 全体         | `{"clientId": "...", "clientSecret": "...}` |
| `AZURE_SUBSCRIPTION_ID` | Azure サブスクリプション ID         | `832c4080-181c-476b-9db0-b3ce9596d40a`      |
| `AZURE_CLIENT_ID`       | Service Principal のクライアント ID | `493ba101-1a1c-48f2-babd-46e13e04d710`      |
| `AZURE_TENANT_ID`       | Azure テナント ID                   | `a816de9e-88b2-4fd8-9afc-84d67d5b0d45`      |
| `MONGO_ADMIN_PASSWORD`  | MongoDB の管理者パスワード          | `ZGLvtXB3z1b8Q5glsWTdUaPSHEN627My`          |
| `GITGUARDIAN_API_KEY`   | GitGuardian API キー（オプション）  | `ee2EdfA1cf7b172be8dC699b040E7B4Bcd...`     |

> 💡 **注意:** 以前のバージョンで必要だった`AZURE_CREDENTIALS_ADMIN`は不要になりました。RBAC ワークフローが削除されたためです。

### GitHub Variables 一覧

| Variable 名                 | 説明                                                      | 推奨値                                 |
| --------------------------- | --------------------------------------------------------- | -------------------------------------- |
| `AZURE_RESOURCE_GROUP`      | リソースグループ名                                        | `rg-aks-wizio-demo`                    |
| `AZURE_LOCATION`            | デプロイ先のリージョン                                    | `japaneast`                            |
| `IMAGE_NAME`                | コンテナイメージ名                                        | `bbs-app`                              |
| `AZURE_GITHUB_PRINCIPAL_ID` | Service Principal オブジェクト ID（自動 RBAC 管理に使用） | `da54fda7-b30b-41ac-869b-f5ed9725ea4d` |
| `AZURE_GRANT_GITHUB_OWNER`  | Owner ロール自動付与フラグ（本番環境では `false` 推奨）   | `false`                                |

---

## 🔧 トラブルシューティング

### よくある問題と解決方法

#### 0. サブスクリプション ID エラー（最も多い問題） 🔴

**エラー:** `ERROR: The subscription of '***' doesn't exist in cloud 'AzureCloud'.`

**原因:** GitHub Secrets の`AZURE_SUBSCRIPTION_ID`が設定されていない、または誤った値が設定されている

**解決方法:**

```powershell
# 現在のサブスクリプションIDを確認
az account show --query id -o tsv

# 出力例: 832c4080-181c-476b-9db0-b3ce9596d40a

# GitHub Secretsに正しい値を設定（複数リモートがある場合は-Rオプション必須）
gh secret set AZURE_SUBSCRIPTION_ID --body '832c4080-181c-476b-9db0-b3ce9596d40a' -R <owner>/<repo>

# 設定を確認
gh secret list | Select-String "AZURE_SUBSCRIPTION_ID"
```

**予防策:**

- ステップ 4-2 で必ず`gh secret list`と`gh variable list`を実行して設定を確認する
- 初回ワークフロー実行前に、すべての必須 Secrets/Variables が設定されているかチェックする

#### 1. Service Principal の認証エラー

**エラー:** `Invalid client secret provided` または `AADSTS7000215`

**原因:** Client Secret の有効期限切れ、または誤った値

**解決方法:**

```powershell
# Service Principalのシークレットをリセット
.\Scripts\Setup-ServicePrincipal.ps1 -SubscriptionId "<YOUR_SUBSCRIPTION_ID>"

# 新しいJSONをGitHub Secretsに更新
Get-Clipboard | gh secret set AZURE_CREDENTIALS
```

#### 2. ポリシー作成の権限エラー

**エラー:** `AuthorizationFailed: does not have authorization to perform action 'Microsoft.Authorization/policySetDefinitions/write'`

**原因:** Resource Policy Contributor ロールが不足

**確認:**

```powershell
# Service PrincipalのオブジェクトIDを取得
$spObjectId = az ad sp list --display-name "sp-wizexercise-github" --query "[0].id" -o tsv

# ロール割り当てを確認
az role assignment list --assignee-object-id $spObjectId --output table
```

**解決方法:**

```powershell
# Setup-ServicePrincipal.ps1を再実行（自動的にロールを付与）
.\Scripts\Setup-ServicePrincipal.ps1 -SubscriptionId "<YOUR_SUBSCRIPTION_ID>"
```

#### 3. 複数リモートリポジトリでの gh secret 設定エラー

**エラー:** `multiple remotes detected. please specify which repo to use by providing the -R, --repo argument`

**原因:** 作業ディレクトリに複数の Git リモートが設定されている

**解決方法:**

```powershell
# リモートの確認
git remote -v

# リポジトリを明示的に指定してSecretを設定
gh secret set <SECRET_NAME> --body '<VALUE>' -R <owner>/<repo>

# 例:
gh secret set AZURE_CREDENTIALS -R aktsmm/CICD-AKS-technical-exercise
```

#### 4. ACR へのプッシュエラー

**エラー:** `unauthorized: authentication required` または `Error response from daemon: Get https://acrwizexercise.azurecr.io/v2/: unauthorized`

**原因:** AKS から ACR へのアクセス権限が不足

**解決方法:**

```powershell
# AKSとACRの統合を確認・修正
az aks update `
  --resource-group rg-aks-wizio-demo `
  --name aksexercise `
  --attach-acr acrwizexercise

# マネージドIDの権限を確認
az aks show --resource-group rg-aks-wizio-demo --name aksexercise --query "identityProfile"
```

**💡 注意:** このプロジェクトでは、ACR 統合は Bicep テンプレートで自動的に設定されています。

#### 5. MongoDB 接続エラー

**エラー:** `MongoNetworkError: connect ETIMEDOUT` または `Authentication failed`

**確認手順:**

```powershell
# 1. MongoDB VMの状態を確認
az vm get-instance-view --resource-group rg-aks-wizio-demo --name vm-mongo-dev --query "instanceView.statuses[?starts_with(code, 'PowerState/')].displayStatus" -o tsv

# 2. VM拡張機能のステータスを確認
az vm extension list --resource-group rg-aks-wizio-demo --vm-name vm-mongo-dev --output table

# 3. MongoDB VMのログを確認（Azure Portal経由）
az vm run-command invoke `
  --resource-group rg-aks-wizio-demo `
  --name vm-mongo-dev `
  --command-id RunShellScript `
  --scripts "sudo systemctl status mongod"
```

**解決方法:**

```powershell
# MongoDB VMを再起動
az vm restart --resource-group rg-aks-wizio-demo --name vm-mongo-dev

# VM拡張機能を再実行（必要に応じて）
# 注: GitHub Actionsのinfra-deploy.ymlを再実行することで自動的に修正されます
```

#### 6. Ingress が External IP を取得できない

**エラー:** `kubectl get svc` で `<pending>` 状態が続く

**確認:**

```powershell
# Ingress Controllerのログを確認
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx

# LoadBalancerサービスの状態を確認
kubectl describe svc nginx-ingress-controller -n ingress-nginx
```

**解決方法:**

```powershell
# Ingress Controllerを再デプロイ
kubectl delete namespace ingress-nginx
gh workflow run 02-1.app-deploy.yml
```

#### 7. GitHub Actions ワークフローが失敗する

**一般的なデバッグ手順:**

```powershell
# 1. 最新の実行を確認
gh run list --limit 5

# 2. 失敗した実行の詳細を表示
gh run view <RUN_ID>

# 3. ログをダウンロード
gh run download <RUN_ID>

# 4. Secretsが正しく設定されているか確認
gh secret list

# 5. Variablesが正しく設定されているか確認
gh variable list
```

---

## 🧹 クリーンアップ

### リソースの削除

**方法 1: GitHub Actions ワークフローを使用**

```powershell
# クリーンアップワークフローを実行
gh workflow run cleanup.yml

# 実行状況を確認
gh run watch
```

**方法 2: Azure CLI を使用**

```powershell
# リソースグループごと削除（高速）
az group delete --name rg-aks-wizio-demo --yes --no-wait

# 削除状況を確認
az group show --name rg-aks-wizio-demo --query "properties.provisioningState" -o tsv
```

### Service Principal の削除

```powershell
# Service Principalを削除
$spObjectId = az ad sp list --display-name "sp-wizexercise-github" --query "[0].id" -o tsv
az ad sp delete --id $spObjectId

# 確認
az ad sp list --display-name "sp-wizexercise-github" --output table
```

**⚠️ 注意:** Service Principal を削除すると、GitHub Actions ワークフローが動作しなくなります。

---

## 🎯 次のステップ

デプロイが完了したら、以下を試してみてください:

### 1. セキュリティスキャン結果の確認

```powershell
# GitHub Securityタブを開く
gh browse /security
```

**確認項目:**

- Checkov による IaC セキュリティスキャン結果
- Trivy によるコンテナイメージ脆弱性スキャン結果
- 検出された問題の優先度と修正方法

### 2. モニタリングダッシュボードの確認

```powershell
# Azure Portalでワークブックを開く
az portal
```

**ナビゲーション:**

1. リソースグループ `rg-aks-wizio-demo` を開く
2. Log Analytics Workspace を選択
3. **Workbooks** タブを開く
4. カスタムワークブック「AKS Monitoring Dashboard」を確認

**ダッシュボードで確認できる情報:**

- AKS クラスターのヘルスステータス
- Pod の CPU/メモリ使用率
- アプリケーションログ
- MongoDB 接続状態

### 3. アプリケーションのカスタマイズ

```powershell
# アプリケーションコードを編集
code app/app.js

# 変更をコミット＆プッシュ
git add app/app.js
git commit -m "feat: アプリケーション機能を追加"
git push origin main

# 自動的にCI/CDが実行されます
gh run watch
```

### 4. セキュリティ設定の強化

プロジェクトの `README.md` の「本番環境向けセキュリティ強化」セクションを参照してください:

- Azure Key Vault の統合
- マネージド ID の使用
- Network Policy の有効化
- Azure Policy の追加

### 5. バックアップの確認

```powershell
# MongoDB バックアップジョブの状態を確認
kubectl get cronjob mongodb-backup

# 最新のバックアップを確認
az storage blob list `
  --account-name <STORAGE_ACCOUNT_NAME> `
  --container-name mongodb-backups `
  --output table `
  --query "[?properties.creationTime>'2025-11-01'].{Name:name, Size:properties.contentLength, Created:properties.creationTime}" `
  --auth-mode login
```

---

## 📚 参考リンク

### Azure ドキュメント

- [Azure Kubernetes Service (AKS)](https://learn.microsoft.com/ja-jp/azure/aks/)
- [Azure Container Registry](https://learn.microsoft.com/ja-jp/azure/container-registry/)
- [Azure Bicep](https://learn.microsoft.com/ja-jp/azure/azure-resource-manager/bicep/)
- [Azure RBAC](https://learn.microsoft.com/ja-jp/azure/role-based-access-control/)
- [Azure Policy](https://learn.microsoft.com/ja-jp/azure/governance/policy/)

### GitHub ドキュメント

- [GitHub Actions](https://docs.github.com/ja/actions)
- [Encrypted Secrets](https://docs.github.com/ja/actions/security-guides/encrypted-secrets)
- [Azure Login Action](https://github.com/Azure/login)

### Kubernetes ドキュメント

- [Kubernetes Documentation](https://kubernetes.io/docs/home/)
- [kubectl チートシート](https://kubernetes.io/ja/docs/reference/kubectl/cheatsheet/)

### セキュリティツール

- [Checkov](https://www.checkov.io/1.Welcome/Quick%20Start.html)
- [Trivy](https://aquasecurity.github.io/trivy/)

---

## � 補足: 実際の設定例

### 実際の構成例（2025 年 11 月 6 日時点）

以下は、実際に動作確認済みの設定例です:

**GitHub Secrets（7 個）:**

```text
AZURE_CREDENTIALS         - Service Principal JSON全体
AZURE_SUBSCRIPTION_ID     - 832c4080-181c-476b-9db0-b3ce9596d40a ⚠️ 必須！
AZURE_CLIENT_ID           - ebe82f26-e7eb-4964-ae98-db8e3d4b40fe
AZURE_TENANT_ID           - a816de9e-88b2-4fd8-9afc-84d67d5b0d45
MONGO_ADMIN_PASSWORD      - 生成した32文字のパスワード
GITGUARDIAN_API_KEY       - （オプション）
```

> ⚠️ **最重要:** `AZURE_SUBSCRIPTION_ID`が設定されていないと、すべてのワークフローが失敗します！
>
> 💡 **注意:** `AZURE_CREDENTIALS_ADMIN`は不要です（以前の RBAC ワークフロー用でしたが、そのワークフローは削除されました）

**GitHub Variables（5 個）:**

```text
AZURE_RESOURCE_GROUP       - rg-bbs-cicd-aks
AZURE_LOCATION             - japaneast
IMAGE_NAME                 - bbs-app
AZURE_GITHUB_PRINCIPAL_ID  - ba5e5bf1-4e1b-484a-a4cd-d8b9be224de3
AZURE_GRANT_GITHUB_OWNER   - false
```

> 💡 **注意:** `AZURE_GITHUB_PRINCIPAL_ID`は**Variable**です（Secret ではありません）

**設定確認コマンド:**

```powershell
# すべてのSecretsを確認
gh secret list

# すべてのVariablesを確認
gh variable list

# 必須項目の完全チェック
Write-Host "📋 設定状況チェック" -ForegroundColor Cyan
Write-Host "`n【Secrets - 7個必須（うち1個はオプション）】" -ForegroundColor Yellow
gh secret list
Write-Host "`n【Variables - 5個必須】" -ForegroundColor Yellow
gh variable list
```

**ワークフロー実行順序:**

1. `1. Deploy Infrastructure` - インフラデプロイ（15-20 分）
2. `2-1. Build and Deploy Application` - アプリデプロイ（5-10 分）
3. （オプション）`2-2. Apply Azure Policy Guardrails` - ポリシー適用
4. （オプション）`2-3. GitGuardian Security Scan` - シークレットスキャン

---

## �💡 よくある質問（FAQ）

### Q1: Service Principal の有効期限はありますか?

**A:** はい、Client Secret にはデフォルトで有効期限があります（通常 1 年）。期限が近づいたら、`Setup-ServicePrincipal.ps1` を再実行してシークレットをローテーションしてください。

### Q2: 複数の環境（開発/ステージング/本番）を管理できますか?

**A:** はい。以下の方法があります:

1. **リソースグループを分ける** - GitHub Variables の `AZURE_RESOURCE_GROUP` を環境ごとに変更
2. **ブランチ戦略** - `main`, `staging`, `develop` ブランチでワークフローを分岐
3. **GitHub Environments** - 環境ごとに Secrets/Variables を管理

### Q3: コストはどのくらいかかりますか?

**A:** 主なコストは以下の通りです（Japan East リージョン、2025 年 11 月時点）:

- **AKS**: 約 ¥8,000/月（3 ノード、Standard_D2s_v3）
- **MongoDB VM**: 約 ¥5,000/月（Standard_B2s）
- **ACR**: 約 ¥1,000/月（Basic SKU）
- **Storage Account**: 約 ¥500/月（数 GB 程度）

**合計:** 約 ¥15,000/月（使用状況により変動）

### Q4: User Access Administrator ロールは本当に必要ですか?

**A:** 完全自動化には必要ですが、セキュリティ要件によっては以下の選択肢があります:

- **必要な場合:** GitHub Actions でロール割り当てを自動化したい
- **不要な場合:** 手動でロール割り当てを行う運用でも可（ワークフロー修正が必要）

### Q5: このプロジェクトは本番環境で使えますか?

**A:** 基本的な構成は本番対応していますが、以下の追加対応を推奨します:

- ✅ マネージド ID の使用（Service Principal の代わり）
- ✅ Azure Key Vault の統合（シークレット管理）
- ✅ Application Gateway の追加（WAF 機能）
- ✅ Azure Backup の設定（MongoDB）
- ✅ 複数リージョンへのデプロイ（高可用性）

---

**📅 作成日:** 2025 年 11 月 6 日  
**📦 対象プロジェクト:** CICD-AKS-technical-exercise  
**📌 バージョン:** 2.0  
**✍️ 最終更新:** 2025 年 11 月 6 日
