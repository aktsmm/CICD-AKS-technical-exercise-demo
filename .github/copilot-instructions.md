# .github/copilot-instructions.md

# GitHub Copilot Instructions for CICD-AKS-Technical Exercise

## プロジェクト概要

このリポジトリは **意図的に脆弱な構成を含む 2 層アプリケーション** (AKS + MongoDB) の教育用デモプロジェクトです。

**⚠️ 重要**: このプロジェクトは**セキュリティ検証と学習目的**であり、**意図的な脆弱性**を含んでいます。本番環境での使用は想定していません。

---

## プロジェクト構成

### アーキテクチャ

- **フロントエンド**: Node.js + Express.js (Guestbook アプリ)
- **バックエンド**: MongoDB (Azure VM 上)
- **インフラ**: Azure Kubernetes Service (AKS)
- **IaC**: Azure Bicep
- **CI/CD**: GitHub Actions
- **セキュリティスキャン**: Checkov (IaC), Trivy (Container)

### ディレクトリ構造

```
wiz-technical-exercise/
├── .github/workflows/      # GitHub Actions ワークフロー
│   ├── 01.infra-deploy.yml   # インフラデプロイ (Bicep)
│   └── 02-1.app-deploy.yml     # アプリデプロイ (Docker + Kubernetes)
├── app/                    # Node.js アプリケーション
│   ├── app.js             # Express.js サーバー
│   ├── Dockerfile         # コンテナイメージ定義
│   ├── views/index.ejs    # フロントエンド UI
│   └── k8s/               # Kubernetes マニフェスト
├── infra/                  # Azure Bicep IaC
│   ├── main.bicep         # メインテンプレート
│   ├── parameters.json    # パラメータファイル
│   └── modules/           # モジュール分割
│       ├── aks.bicep
│       ├── networking.bicep
│       ├── vm-mongodb.bicep
│       ├── storage.bicep
│       └── monitoring.bicep
├── docs/                   # ドキュメント
└── Docs_issue_point/       # トラブルシューティング資料
```

---

## Copilot への指示

### 1. セキュリティの扱い

#### ⚠️ 意図的な脆弱性を含む箇所

このプロジェクトには**意図的に**以下のセキュリティ問題が含まれています:

**AKS 関連:**

- ローカル管理者アカウントが有効 (`disableLocalAccounts: false`)
- ネットワークポリシー未設定
- 自動アップグレード無効
- 一時ディスク暗号化なし

**MongoDB VM 関連:**

- パスワード認証使用 (SSH キー認証なし)
- Basic 認証使用
- ホスト暗号化なし
- VM 拡張機能インストール済み

**Kubernetes マニフェスト:**

- 過剰な RBAC 権限 (`cluster-admin`)
- `privileged: true` コンテナ
- Security Context 未設定

#### Copilot の推奨事項

- ✅ これらの脆弱性を**修正しないでください**（意図的な設計）
- ✅ コード提案時は脆弱性の存在を認識して説明する
- ✅ セキュリティベストプラクティスとの差異を明示する
- ✅ 本番環境向けの修正案を別途提示する

### 2. トラブル発生時の対応

#### 📝 重要: すべてのトラブルを記録する

**問題が発生したら必ず Docs_issue_point 配下に Markdown で記録してください:**

```markdown
## 🔴 トラブル発生 (日付)

### 問題タイトル

**現象:**

- エラーメッセージ全文
- 発生した状況

**原因:**

- なぜ問題が起きたか

**解決方法:**

- 実施した修正内容
- 使用したコマンド

**参考リンク:**

- 役立った情報源
```

#### トラブル記録の例

````markdown
## 🔴 GitHub Push Protection エラー (2025-10-29)

### 機密情報検出によるプッシュブロック

**現象:**

```bash
remote: error: GH013: Repository rule violations found for refs/heads/main.
remote: - GITHUB PUSH PROTECTION
remote:   - Push cannot contain secrets
```
````

**原因:**

- `docs/AZURE_SETUP_INFO.md` に Service Principal の clientSecret が含まれていた
- GitHub の Secret Scanning が検出してプッシュをブロック

**解決方法:**

```powershell
# 機密情報ファイルを.gitignoreに追加
git rm --cached docs/AZURE_SETUP_INFO.md mongo_password.txt
git add .gitignore
git commit -m "Remove sensitive files and update .gitignore"

# Git履歴から完全削除
git reset --soft deda077
git commit -m "Clean commit without secrets"
git push origin main --force
```

**参考リンク:**

- https://docs.github.com/code-security/secret-scanning

````

#### 作業履歴の管理
Docs_work_history 配下にフェーズごとに作業履歴を保存してください。

#### 環境情報を必ず記録
Docs_Secrets 配下に機密情報やシークレットなどを記録。
各フェーズでなにに使用したものか、どうやって設定したかを明記してください。

#### トラブル記録のルール
Docs_issue_point 配下にフェーズに分けてトラブルを管理してください。
1. ✅ **エラーメッセージは全文コピー**
2. ✅ **発生日時を記録**
3. ✅ **解決までの試行錯誤も含める**
4. ✅ **最終的な解決方法を明記**
5. ✅ **再発防止策も記載**

### 3. コーディング規約

#### Azure Bicep

```bicep
// ✅ Good: 明示的なパラメータ定義
@description('AKS クラスター名')
@minLength(3)
@maxLength(63)
param aksClusterName string

// ✅ Good: モジュール分割
module aks 'modules/aks.bicep' = {
  name: 'aksDeployment'
  params: {
    clusterName: aksClusterName
    location: location
  }
}

// ❌ Bad: 未定義のプロパティ使用
// azurePolicyEnabled: true  // このプロパティは存在しない
````

#### JavaScript/Node.js (app.js)

```javascript
// ✅ Good: 環境変数の使用
const mongoHost = process.env.MONGODB_HOST || "localhost";
const mongoPort = process.env.MONGODB_PORT || 27017;

// ✅ Good: エラーハンドリング
app.post("/add", async (req, res) => {
  try {
    // 処理...
  } catch (error) {
    console.error("Error:", error);
    res.status(500).send("Internal Server Error");
  }
});

// ❌ Bad: 機密情報のハードコーディング
// const mongoPassword = 'password123';  // 絶対に避ける
```

#### Kubernetes マニフェスト

```yaml
# ✅ Good: ConfigMap で環境変数を管理
env:
  - name: MONGODB_HOST
    valueFrom:
      configMapKeyRef:
        name: app-config
        key: mongodb.host

# ⚠️ 意図的な脆弱性（修正しない）
containers:
  - name: guestbook
    securityContext:
      privileged: true # デモ用に意図的に設定
```

### 3. GitHub Actions ワークフロー

#### ベストプラクティス

```yaml
# ✅ Good: 最新バージョンの使用
- uses: github/codeql-action/upload-sarif@v3

# ✅ Good: continue-on-error でレジリエンス確保
- name: Upload Scan Results
  continue-on-error: true

# ✅ Good: soft_fail でセキュリティスキャンを警告のみに
- name: Run Checkov Scan
  with:
    soft_fail: true # 意図的な脆弱性があるため

# ❌ Bad: 非推奨バージョン
# - uses: github/codeql-action/upload-sarif@v2  # v3 を使用すること
```

### 4. 機密情報管理

#### ✅ 正しい管理方法

```yaml
# GitHub Secrets の使用
env:
  AZURE_CREDENTIALS: ${{ secrets.AZURE_CREDENTIALS }}
  MONGO_ADMIN_PASSWORD: ${{ secrets.MONGO_ADMIN_PASSWORD }}
```

```gitignore
# .gitignore に機密ファイルを追加
docs/AZURE_SETUP_INFO.md
mongo_password.txt
*.secret
*.credentials
```

#### ❌ 避けるべきパターン

```javascript
// ❌ Bad: コード内にハードコーディング
const password = "MySecretPassword123";

// ❌ Bad: コミットに含める
// Service Principal clientSecret: jJj8Q~Zp...
```

### 5. ドキュメント作成

#### コメント規約

```bicep
// Bicep: 各リソースの目的を説明
// ⚠️ 意図的な脆弱性: ローカル管理者アカウントを有効化（デモ用）
resource aks 'Microsoft.ContainerService/managedClusters@2024-01-01' = {
  properties: {
    disableLocalAccounts: false  // 本番環境では true にすること
  }
}
```

```javascript
// JavaScript: エンドポイントの説明
// POST /add - 新しいゲストブックエントリを追加
// Body: { name: string, message: string }
app.post("/add", async (req, res) => {
  // ...
});
```

---

## トラブルシューティング

### よくある問題と対処法

#### 1. GitHub Push Protection エラー

```bash
# エラー: Push cannot contain secrets
# 対処: 機密情報を .gitignore に追加してコミット履歴から削除
git rm --cached docs/AZURE_SETUP_INFO.md
git commit --amend
```

#### 2. Checkov スキャン失敗

```yaml
# 対処: soft_fail: true が設定されていることを確認
# このプロジェクトは意図的な脆弱性を含むため、スキャン失敗は正常
```

#### 3. SARIF Upload 権限エラー

```yaml
# 対処: continue-on-error: true を追加
- name: Upload Checkov Results
  continue-on-error: true
```

#### 4. Bicep デプロイエラー

```powershell
# Azure Provider が登録されているか確認
az provider show --namespace Microsoft.ContainerService
az provider show --namespace Microsoft.Compute

# 未登録の場合は登録
az provider register --namespace Microsoft.ContainerService --wait
```

---

## デプロイ手順

### 前提条件

1. Azure サブスクリプション
2. Azure CLI インストール済み
3. kubectl インストール済み
4. GitHub リポジトリ作成済み

### 初期セットアップ

```powershell
# 1. Service Principal 作成
az ad sp create-for-rbac --name spexercise-github `
  --role Contributor `
  --scopes /subscriptions/<SUBSCRIPTION_ID> `
  --sdk-auth

# 2. Resource Group 作成
az group create --name rg-bbs-cicd-aks --location japaneast

# 3. ACR 作成
az acr create --resource-group rg-bbs-cicd-aks `
  --name acrwizexercise `
  --sku Standard

# 4. GitHub Secrets 設定
# AZURE_CREDENTIALS (Service Principal JSON)
# AZURE_SUBSCRIPTION_ID
# MONGO_ADMIN_PASSWORD
```

### GitHub Actions でデプロイ

```bash
# 1. コードをプッシュ（01.infra-deploy.yml が自動実行）
git push origin main

# 2. インフラデプロイ完了後、ACR と AKS を統合
az aks update --resource-group rg-bbs-cicd-aks `
  --name aksexercise `
  --attach-acr acrwizexercise

# 3. アプリデプロイを手動実行
# GitHub Actions > "Build and Deploy Application" > Run workflow
```

---

## コード修正時の注意事項

### Bicep ファイル修正

- ✅ `azurePolicyEnabled` プロパティは存在しないため使用禁止
- ✅ API バージョンは最新を使用: `@2024-01-01` 以降
- ✅ モジュール分割を維持（main.bicep から modules を参照）

### Kubernetes マニフェスト修正

- ✅ `rbac-vulnerable.yaml` の過剰な権限は意図的（修正しない）
- ✅ `deployment.yaml` の `privileged: true` は意図的（修正しない）
- ✅ イメージ名は `${ACR_NAME}.azurecr.io/guestbook:${TAG}` 形式

### GitHub Actions ワークフロー修正

- ✅ `continue-on-error: true` を削除しない
- ✅ `soft_fail: true` を削除しない
- ✅ CodeQL Action は v3 を使用

---

## Copilot への質問例

### 推奨される質問

- "この AKS Bicep テンプレートのセキュリティ問題を説明してください"
- "本番環境向けに rbac-vulnerable.yaml を修正するならどうしますか？"
- "Checkov で検出された CKV_AZURE_171 を修正する方法は？"
- "MongoDB VM を SSH キー認証に変更する手順は？"

### 避けるべき質問

- "すべてのセキュリティ問題を自動修正してください" → 意図的な脆弱性を消してしまう
- "Checkov スキャンをパスするように修正して" → プロジェクトの目的に反する

---

## 参考リソース

### Azure

- [AKS ベストプラクティス](https://learn.microsoft.com/azure/aks/best-practices)
- [Bicep ドキュメント](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [Azure セキュリティベースライン](https://learn.microsoft.com/security/benchmark/azure/)

### Kubernetes

- [Kubernetes セキュリティベストプラクティス](https://kubernetes.io/docs/concepts/security/)
- [RBAC 設定ガイド](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)

### GitHub Actions

- [GitHub Actions ドキュメント](https://docs.github.com/actions)
- [CodeQL Action](https://github.com/github/codeql-action)
- [Azure Login Action](https://github.com/Azure/login)

### セキュリティツール

- [Checkov](https://www.checkov.io/)
- [Trivy](https://aquasecurity.github.io/trivy/)
- [Wiz Platform](https://www.wiz.io/)

---

## ライセンスと免責事項

### ⚠️ 免責事項

このプロジェクトは**教育とデモンストレーション目的**で作成されています。

- ❌ 本番環境での使用は**推奨しません**
- ❌ 意図的なセキュリティ脆弱性を含んでいます
- ❌ 提供されるコードは**そのまま使用しないでください**
- ✅ セキュリティ学習と検証のために使用してください

### プロジェクトの目的

1. クラウドセキュリティスキャンツールの動作確認
2. IaC (Infrastructure as Code) のベストプラクティス学習
3. CI/CD パイプライン構築の実践
4. 脆弱性検出と修復方法の理解

---

**最終更新**: 2025 年 10 月 29 日  
**プロジェクト**: CICD-AKS-Technical Exercise  
**用途**: 技術面接課題 / セキュリティデモ
