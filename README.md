# CICD-AKS Technical Exercise

> **注意:** このリポジトリは 意図的な脆弱性を含むため、本番用途では必ず防御策を追加してください。

## 🚀 クイックスタート (初回セットアップ)

### 前提条件

- Azure CLI がインストールされ、`az login` 済み
- GitHub リポジトリへの管理者アクセス権限
- PowerShell 7+ (Windows/macOS/Linux)

### 1. Service Principal 作成と権限付与

```powershell
# リポジトリをクローン
git clone https://github.com/aktsmm/CICD-AKS-technical-exercise.git
cd CICD-AKS-technical-exercise

# 自動セットアップスクリプトを実行
.\Scripts\Setup-ServicePrincipal.ps1 -SubscriptionId "YOUR_SUBSCRIPTION_ID"
```

このスクリプトは以下を自動実行します:

- ✅ Service Principal `sp-wizexercise-github` を作成
- ✅ 必要な権限を付与:
  - **Contributor**: リソース管理
  - **Resource Policy Contributor**: Azure Policy 管理
  - **User Access Administrator**: RBAC 自動管理(完全自動化に必要)
- ✅ GitHub Secrets 用 JSON を生成してクリップボードにコピー

### 2. GitHub Secrets 設定

1. リポジトリの **Settings** > **Secrets and variables** > **Actions** を開く
1. スクリプト出力の値を使って以下の Secrets を作成:

| Secret 名               | 値                                                     |
| ----------------------- | ------------------------------------------------------ |
| `AZURE_CREDENTIALS`     | スクリプトが出力した JSON (クリップボードにコピー済み) |
| `AZURE_SUBSCRIPTION_ID` | Azure サブスクリプション ID                            |
| `MONGO_ADMIN_PASSWORD`  | MongoDB 管理者パスワード(任意の強力なパスワード)       |

1. **Variables** タブで以下を設定:

| Variable 名            | 値                | 説明                 |
| ---------------------- | ----------------- | -------------------- |
| `AZURE_RESOURCE_GROUP` | `rg-bbs-cicd-aks` | リソースグループ名   |
| `AZURE_LOCATION`       | `japaneast`       | デプロイ先リージョン |
| `IMAGE_NAME`           | `guestbook`       | コンテナイメージ名   |

### 3. GitHub Actions 実行

1. **Actions** タブを開く
2. **"1. Deploy Infrastructure"** ワークフローを手動実行 (Run workflow)
3. 完了後、自動的に **"2-1. Build and Deploy Application"** と **"2-2. Deploy Azure Policy Guardrails"** が実行されます

✅ **完了!** 以降はコミット時に自動デプロイされます。

---

## 1. プロジェクト概要

### 目的と背景

- 2 層構成 (AKS 上の Node.js アプリ + Azure VM 上の MongoDB) を題材に、CI/CD、IaC、監視、セキュリティ診断の一連の流れを体験する教材です。
- あえて脆弱な設定を残しており、セキュリティレビューや改善策検討の練習に利用できます。

### 使用技術スタック

- **インフラ:** Azure Kubernetes Service (AKS)、Azure Virtual Network、Azure Virtual Machine、Azure Container Registry、Log Analytics Workspace。
- **アプリ:** Node.js + Express + EJS、MongoDB (Mongoose ODM)。
- **IaC:** Azure Bicep (`infra/` 配下でモジュール分割)。
- **CI/CD:** GitHub Actions (`.github/workflows/`)、Checkov と Trivy のセキュリティスキャン。
- **監視:** Azure Monitor / Log Analytics Workbook (セキュリティ ダッシュボード)。

## 2. ネットワーク構成

### 全体図 (論理構成)

```text
インターネット
  │ (TLS/HTTPS)
  ▼
Azure Public Load Balancer (AKS Ingress)
  │
  ▼
AKS クラスター (ノードプール: 10.0.1.0/24)
  │
  ▼
Kubernetes Pod (guestbook-app)
  │ (MongoDB 認証付き URI)
  ▼
MongoDB VM (10.0.2.0/24) ──► Azure Storage (バックアップ用 BLOB)
```

### コンポーネント接続関係

- VNet `10.0.0.0/16` を 2 サブネット (`snet-aks`, `snet-mongo`) に分割し、それぞれ AKS と MongoDB VM を収容します。
- AKS クラスターはパブリック API サーバーを維持したまま Ingress-Nginx を利用して外部公開します。
- MongoDB VM は同一 VNet 内のプライベート IP で Pod と通信しつつ、SSH 用のパブリック IP を持ちます (デモ用の脆弱設定)。
- Azure Storage は MongoDB のバックアップ先として使用され、Custom Script でジョブが設定されます。

### 外部アクセスと制限

- Web アプリは Ingress 経由で HTTPS 提供 (cert-manager による自己署名 ClusterIssuer)。
- MongoDB ポート (27017/TCP) は AKS サブネットからのアクセスのみ許可、SSH (22/TCP) は全世界へ開放されています。
- GitHub Actions と Azure の連携は OIDC + サービス プリンシパルで行い、Bicep 内で RBAC を最小化できる構造です。

## 3. セキュリティ設計

### 認証・認可

- Azure 側では GitHub Actions 用サービス プリンシパルと、AKS kubelet / Mongo VM の Managed Identity を利用します。
- Kubernetes 側では `rbac-vulnerable.yaml` が `cluster-admin` を付与しており、意図的な過剰権限が存在します。
- MongoDB は Custom Script で `mongoadmin` を作成し、Secret に接続 URI を保存します。

### 通信暗号化

- Ingress と cert-manager で TLS 証明書を払い出し、ブラウザ～ Ingress 間を HTTPS 化します。
- Pod ～ MongoDB 間はプレーン TCP ですが、認証付き URI を使い最低限の保護を確保しています。実運用では TLS トンネルや Private Link の利用が推奨です。

### Secrets / 環境変数管理

- GitHub Actions では `AZURE_CREDENTIALS`、`AZURE_CLIENT_ID`、`AZURE_TENANT_ID`、`AZURE_SUBSCRIPTION_ID`、`MONGO_ADMIN_PASSWORD` を Secrets に保持します。
- Kubernetes Secret `mongo-credentials` に MongoDB 接続 URI を保存し、Deployment の `env` から参照します。
- Bicep パラメーターには `@secure()` を付与し、`azure/arm-deploy` アクションに安全に渡します。

### 意図的に残している脆弱性

- MongoDB VM への SSH を全世界に開放 (`Allow-SSH-Internet`)。
- AKS API サーバーがパブリック公開で、ClusterRoleBinding により `cluster-admin` を付与。
- Storage アカウントのパブリック BLOB アクセスを許可。
- Defender for Cloud は有効化済みで検知は可能ですが、緩和策は各自で実施する想定です。

### 実運用向け Tips

- SSH 制限には Azure Bastion や NSG の IP フィルタリングを導入し、Bicep の `allowSSHFromInternet` を `false` に変更します。
- AKS を非公開化する場合は `enablePrivateCluster` を `true` にして、Azure Firewall や Private Endpoint と組み合わせます。
- Storage は `allowPublicBlobAccess` を `false` に変更し、Private Endpoint への切り替えを検討してください。

## 4. システムアーキテクチャ

### サービス構成

- **Guestbook アプリ (AKS 上 Pod):** `app/app.js` の Express アプリが一覧表示と投稿処理を担当。`/health` で Liveness/Readiness Probe に応答します。
- **MongoDB (Azure VM):** `infra/modules/vm-mongodb.bicep` と `infra/scripts/*.sh` がインストールと認証設定、バックアップを自動化します。
- **Azure Container Registry:** `02-1.app-deploy.yml` の `build-push` ジョブが `acrname.azurecr.io/guestbook:<tag>` 形式でイメージを管理します。
- **監視 (Log Analytics + Workbook):** `infra/modules/workbook-security.bicep` が Defender アラートやアクティビティログを可視化するダッシュボードを展開します。

### データフローと依存関係

1. ユーザーがフォームから投稿すると Express が MongoDB にドキュメントを保存します。
2. バックエンドは Secret から `MONGO_URI` を読み込み、Mongoose で `messages` コレクションを操作します。
3. MongoDB は Azure Storage に定期バックアップをアップロードします。
4. Azure Monitor が各リソースの診断ログを収集し、Workbook で可視化します。

## 5. 処理のフロー (ユーザー操作基点)

1. ブラウザが HTTPS で Ingress にアクセスします。
2. Ingress が Service `guestbook-service` (ClusterIP) にルーティングし、Pod がリクエストを処理します。
3. `POST /post` で送信されたデータを MongoDB に保存し、`/` へリダイレクトします。
4. `GET /` で最新メッセージを取得し、EJS テンプレートで描画します。
5. `/health` エンドポイントが 200 を返し、Kubernetes が Pod の正常性を監視します。
6. MongoDB バックアップスクリプトが Azure Storage にデータを同期します。

## 6. 通信のフロー

| ソース                | 宛先                  | プロトコル | ポート | 用途                      |
| --------------------- | --------------------- | ---------- | ------ | ------------------------- |
| ユーザー端末          | Ingress Load Balancer | HTTPS      | 443    | Web UI へのアクセス       |
| Ingress Controller    | guestbook-service     | HTTP       | 80     | Pod へのルーティング      |
| guestbook Pod         | MongoDB VM            | TCP        | 27017  | データの読み書き          |
| GitHub Actions Runner | Azure APIs            | HTTPS      | 443    | Bicep デプロイや AKS 操作 |
| MongoDB VM            | Azure Storage         | HTTPS      | 443    | バックアップ転送          |
| 管理者端末            | MongoDB VM            | SSH        | 22     | 管理用途 (意図的脆弱性)   |

## 7. デプロイ手順

### 7.1 必要な前提条件

1. Azure サブスクリプション (Contributor 以上)。
2. GitHub リポジトリと必要に応じて GitHub CLI。
3. ローカルに Azure CLI、kubectl、Docker、Node.js 20.x をインストール済み。

### 7.2 Azure 側の初期設定

```powershell
# サービス プリンシパルを作成し、GitHub Actions から Azure に接続できるようにする
az ad sp create-for-rbac `
  --name sp-wizexercise-github `
  --role Contributor `
  --scopes /subscriptions/<SUBSCRIPTION_ID> `
  --sdk-auth

# リソース グループを作成 (infra/main.bicep の既定値と合わせる)
az group create `
  --name rg-bbs-cicd-aks `
  --location japaneast
```

### 7.3 GitHub Secrets / Repository Variables 登録

- `Settings > Secrets and variables > Actions` で以下を設定します。
  - Secrets: `AZURE_CREDENTIALS`、`AZURE_CLIENT_ID`、`AZURE_TENANT_ID`、`AZURE_SUBSCRIPTION_ID`、`MONGO_ADMIN_PASSWORD`。
  - Variables: `AZURE_RESOURCE_GROUP`、`AZURE_LOCATION`、`IMAGE_NAME` (例: `guestbook`)、`AZURE_GITHUB_PRINCIPAL_ID` (任意で RBAC 自動付与を制御)。

### 7.4 GitHub Actions ワークフローの流れ

1. `01.infra-deploy.yml`
   - Checkov/Trivy で Bicep をスキャン (soft_fail=true)。
   - `az deployment sub what-if` で差分を確認し、`azure/arm-deploy` で `main.bicep` を展開します。
   - 成果物サマリに AKS 名称や Workbook URL を出力します。
2. `02-1.app-deploy.yml`
   - Lint/Jest、CodeQL、Trivy を実行して品質と脆弱性を確認します。
   - ACR にイメージをプッシュし、`az aks command invoke` でマニフェストや Secret を適用します。
   - cert-manager を導入し、自己署名証明書で HTTPS を有効化します。

### 7.5 手動で必要な作業

- Ingress の Public IP に合わせて DNS レコード (A レコード) を設定する場合があります。
- Azure AD と統合した認証が必要なときは、App Gateway + Entra ID などで保護レイヤーを追加してください。
- Security Workbook の URL は GitHub Actions のアーティファクトに出力されるため、組織ポリシーに沿って閲覧権限を調整してください。

## 8. 初期セットアップ (ローカル動作確認)

### 8.1 リポジトリ取得

```powershell
# リポジトリ URL を変数化してクローンし、アプリケーション ディレクトリへ移動する
$repoUrl = "https://github.com/aktsmm/CICD-AKS-technical-exercise.git"
git clone $repoUrl
cd CICD-AKS-technical-exercise/app
```

### 8.2 MongoDB ローカル起動 (簡易確認)

#### Docker を利用する場合

```powershell
# デモ用にローカル MongoDB を起動し、Guestbook 用データベースを準備する
docker run `
  --name mongo-local `
  -p 27017:27017 `
  -e MONGO_INITDB_ROOT_USERNAME=mongoadmin `
  -e MONGO_INITDB_ROOT_PASSWORD=P@ssw0rd! `
  -d mongo:6
```

#### 既存の MongoDB を利用する場合

- 環境変数 `MONGO_URI` を適切な接続文字列で上書きし、`app/app.js` の既定値を無効化します。

### 8.3 Node.js 依存関係のインストールとテスト

```powershell
# 依存関係をインストールし、ユニットテスト後にローカルサーバーを起動する
npm ci
npm test
npm start
```

### 8.4 kubectl / AKS への接続 (検証用)

```powershell
# AKS の認証情報を取得し、主要なリソースを確認する
az aks get-credentials `
  --resource-group rg-bbs-cicd-aks `
  --name aks-dev

kubectl get pods -n ingress-nginx
kubectl get svc guestbook-service
kubectl get ingress guestbook-ingress
```

### 8.5 よくあるトラブルと対処

- **AKS API が未準備:** `app-deploy` ワークフローは最大 10 分待機します。失敗した場合はワークフローを再実行してください。
- **MongoDB 接続失敗:** `kubectl logs deployment/guestbook-app` でアプリログを確認し、`mongo-secret.yaml` の URI が想定通りかチェックします。
- **cert-manager Pod が Ready にならない:** 数分待機しても改善しない場合は `kubectl describe pod -n cert-manager` で詳細を確認します。

## 9. 参考資料 (公式ドキュメント)

- #microsoft.docs.mcp [Azure Kubernetes Service の概要](https://learn.microsoft.com/ja-jp/azure/aks/intro-kubernetes) — AKS の公開エンドポイントや制御プレーンの説明が記載されています。
- #microsoft.docs.mcp [Azure Container Registry とは](https://learn.microsoft.com/ja-jp/azure/container-registry/container-registry-intro) — ACR 連携手順とセキュリティ構成が示されています。
- #microsoft.docs.mcp [Bicep 入門](https://learn.microsoft.com/ja-jp/azure/azure-resource-manager/bicep/overview) — `infra/main.bicep` のような宣言的 IaC の基本を確認できます。
- #microsoft.docs.mcp [Custom Script Extension (Linux)](https://learn.microsoft.com/ja-jp/azure/virtual-machines/extensions/custom-script-linux) — MongoDB セットアップに使う拡張の仕組みが解説されています。
- #microsoft.docs.mcp [GitHub Actions から Azure へデプロイ](https://learn.microsoft.com/ja-jp/azure/developer/github/connect-from-azure?tabs=azure-cli) — サービス プリンシパルと OIDC の連携手順を参照できます。

## 10. 次のステップ (任意)

- 脆弱な構成を 1 つずつ修正し、Checkov/Trivy の結果変化を比較して学習を深める。
- Azure Policy を追加し、`policy-guardrails.bicep` をベースにガバナンス強化を行う。
- GitHub Actions に手動承認ステップや環境保護ルールを追加し、実運用に近いパイプライン設計を検証する。
