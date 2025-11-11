# CICD-AKS Technical Exercise

## プロジェクト概要

- 本リポジトリは、Azure Kubernetes Service (AKS) 上で動作する Node.js アプリケーションと、周辺インフラを Bicep と GitHub Actions で自動化するトレーニング用プロジェクトです。
- インフラ構築、アプリケーションデプロイ、セキュリティスキャン、監視までを一連のパイプラインで体験し、CI/CD と DevSecOps の実務感覚を習得することを目的としています。
- 主要な技術スタック
  - Azure: AKS、Azure Container Registry (ACR)、Virtual Network、Log Analytics、Azure Monitor Workbook、Azure Policy、System Assigned Managed Identity を備えた MongoDB VM、Storage Account など
  - CI/CD: GitHub Actions (インフラ展開、アプリケーションビルド、コンテナスキャン)
  - アプリ: Node.js + Express + EJS、MongoDB
  - IaC・スクリプト: Bicep モジュール、PowerShell / Bash スクリプト
- 初期準備の詳細は `SetupGuide.md` にまとまっているため、作業前に必ず参照してください。

## ネットワーク構成

```text
+------------------------------------------------ Azure Subscription ------------------------------------------------+
| Resource Group: rg-bbs-cicd-aks                                                                                     |
|                                                                                                                    |
|  +---------------------------+      10.0.1.0/24       +-------------------------+                                  |
|  | AKS Cluster (aks-dev)     |------------------------| Subnet snet-aks          |                                  |
|  |  - NGINX Ingress (public) |                        +-------------------------+                                  |
|  |  - guestbook Pods (x2)    |                         | Service: guestbook      |                                  |
|  |  - Kubernetes Secrets     |                         | Port 80 -> Pod 3000     |                                  |
|  +---------------------------+                         v                                                             |
|                                                                                                                    |
|  +---------------------------+      10.0.2.0/24       +-------------------------+                                  |
|  | MongoDB VM (MI enabled)   |<----- NSG allow 22 ----| Subnet snet-mongo        |                                  |
|  |  - Public IP (training)   |<----- NSG allow 27017 -|                          |                                  |
|  |  - Backup cron scripts    |                        +-------------------------+                                  |
|  +---------------------------+                         | Managed Identity auth   |                                  |
|                                                        v                                                             |
|                                                +----------------------+                                             |
|                                                | Storage Account      |                                             |
|                                                |  - Blob (backups)    |                                             |
|                                                +----------------------+                                             |
|                                                                                                                    |
|  +---------------------------+                                                                           +--------+ |
|  | Log Analytics Workspace   |<-- Diagnostic Settings (AKS/ACR/VM/NSG) --> Azure Monitor Workbook        | Policy | |
|  +---------------------------+                                                                           +--------+ |
+--------------------------------------------------------------------------------------------------------------------+
```

- AKS は Azure CNI (VNet 統合) を利用し、`snet-aks` に直接 Pod IP を割り当てます。MongoDB VM は別サブネットに隔離し、NSG でアクセス制御を行います。
- Ingress Controller は Azure Public Load Balancer のグローバル IP を使用しており、公式解説どおりインターネットから直接トラフィックを受ける構成になっています ([Azure Load Balancer の概要](https://learn.microsoft.com/ja-jp/azure/networking/load-balancer-content-delivery/load-balancing-content-delivery-overview))。演習では公開状態を保ったまま、後述の改善案で Internal Load Balancer + WAF への多層防御移行を検討する前提です。
- バックアップ用 Storage Account は一部脆弱な設定 (HTTP 許可など) を残しており、セキュリティスキャン教材として活用します。
- サブスクリプションレベルで Azure Policy を割り当て、Log Analytics へ診断ログを集約することで監査性を高めています。

## セキュリティ設計

### 認証・認可

- GitHub Actions から Azure への認証は Service Principal を使用し、`Scripts/Setup-ServicePrincipal.ps1` で `Contributor`・`Resource Policy Contributor`・`User Access Administrator` を一括付与します。
- AKS では RBAC を有効化していますが、教材として `app/k8s/rbac-vulnerable.yaml` で広い権限の ServiceAccount を定義しています。実運用では Namespace 分離とロール最小化が必要です。
- MongoDB VM は System Assigned Managed Identity を有効化し、`modules/vm-storage-role.bicep` がバックアップ先 Storage に対するロールを自動割り当てします。

### 通信の暗号化

- Ingress Controller は自己署名証明書を利用した HTTPS 終端を前提としており、TLS は Public Load Balancer で終端します。
- 仮想ネットワーク内通信は平文ですが、Private Link や Azure Firewall の追加でゼロトラスト化を強化できます。
- MongoDB 接続は Kubernetes Secret 経由で行います。現状 TLS 無効のため、本番では `mongod.conf` の TLS 設定とクライアント証明書導入を推奨します。

### Secrets・環境変数の管理

- `AZURE_CREDENTIALS` や `MONGO_ADMIN_PASSWORD` などの資格情報は GitHub Secrets として保管し、`SetupGuide.md` に CLI で一括登録する PowerShell コマンド例を掲載しています。
- AKS の Deployment は `mongo-credentials` Secret から接続文字列を参照し、`env.valueFrom.secretKeyRef` で Pod に注入します。
- VM バックアップスクリプトは Managed Identity と RBAC に依存しており、Storage Account キーを使用しないシークレットレス運用を実現します。

### 認証方式の比較と選定理由

| 経路          | 採用方式                                                   | 理由                                                   | 改善アイデア                                                  |
| ------------- | ---------------------------------------------------------- | ------------------------------------------------------ | ------------------------------------------------------------- |
| CI/CD → Azure | Service Principal (クライアントシークレット)               | `azure/login` アクションとの互換性が高く既存手順が豊富 | GitHub OIDC (Federated Credential) へ移行しシークレットレス化 |
| AKS → ACR     | kubelet の Managed Identity + `modules/aks-acr-role.bicep` | Pull シークレット不要で運用負荷を軽減                  | Azure AD Workload Identity で Pod 単位の権限分離              |
| VM → Storage  | System Assigned Managed Identity                           | ローテーション不要でバックアップ自動化に適合           | Key Vault + Private Endpoint で経路と鍵管理を強化             |

### セキュリティ観点

- 脅威モデル: SSH 全開放や HTTP 許可 Storage など意図的なリスクを残し、Checkov や Trivy での検出体験を提供します。
- ゼロトラスト: 現状はフラットなネットワークのため、Jump Host や Just-In-Time Access を組み合わせる拡張案を `今後の改善点` に整理しています。
- 監査ログ: Subscription Activity Log を Log Analytics に転送し、`modules/workbook-security.bicep` で可視化ダッシュボードを自動生成します。GitHub Actions では SARIF をアップロードして監査証跡を保持します。

## MongoDB バックアップ方式の詳細

- バックアップ構成は `infra/scripts/setup-backup.sh` が自動展開し、MongoDB VM 上で次の処理を自動構成します。
  - Azure CLI を取得（`curl -sL https://aka.ms/InstallAzureCLIDeb | bash`）し、バックアップスクリプト格納先 `/usr/local/bin`・ワークディレクトリ `/var/backups/mongodb`・ログ `/var/log/mongodb-backup.log` を生成。
  - `mongodump` で `localhost:27017` からダンプを取得し、`.tar.gz` へ圧縮。失敗時は即座に終了してログへ `ERROR` を書き込みます。
  - System Assigned Managed Identity で `az login --identity` を実行し、`az storage blob upload --auth-mode login` によりストレージ アカウントへシークレットレスで転送。
  - 成果物は `mongodb_backup_YYYYMMDD_HHMMSS.tar.gz` 形式で Blob へ保存し、`find /var/backups/mongodb -mtime +7` で 7 日超のローカルファイルを削除して保持期間を管理。
  - `crontab` の既存エントリをクリーンアップしたうえで `0 * * * * /usr/local/bin/mongodb-backup.sh`（毎時 0 分実行）を登録し、初回バックアップも自動実行。
  - バックアップ完了後は標準出力とログにサイズ・URL・`curl` 例をまとめたサマリーを出力し、異常時は `::error::` 相当のメッセージで通知します。
- 関連スクリプトと役割

| スクリプト                         | 主な役割                                                                                       |
| ---------------------------------- | ---------------------------------------------------------------------------------------------- |
| `infra/scripts/setup-backup.sh`    | バックアップスクリプト生成・Azure CLI 導入・Managed Identity ログイン・cron 登録を一括実行     |
| `/usr/local/bin/mongodb-backup.sh` | `setup-backup.sh` が生成するバックアップ本体スクリプト。MongoDB のダンプ取得と Blob 転送を実行 |

- 手動実行の例（MongoDB VM で実施）

```bash
# 即時バックアップを取りたい場合は本体スクリプトを直接実行
sudo /usr/local/bin/mongodb-backup.sh
```

- 運用ヒント
  - Blob Storage 側では VM の Managed Identity に `Storage Blob Data Contributor` を割り当てるため、`modules/vm-storage-role.bicep` のカスタマイズで運用環境に合わせたスコープ調整ができます。
  - バックアップサイズや失敗率を監視に取り込む場合、`/var/log/mongodb-backup.log` を Azure Monitor Agent で収集し、失敗キーワードでアラート化するのが実践的です。
  - `az storage blob upload --auth-mode login` による Azure AD 認証フローの詳細は [ストレージへの Azure AD 認証ガイド](https://learn.microsoft.com/ja-jp/azure/storage/blobs/authorize-access-azure-active-directory) に記載されています。Managed Identity でも同じフローでトークンを取得できるため、シークレットレス運用を保ちながらセキュリティを確保できます。 (#microsoft.docs.mcp)

## システムアーキテクチャ

```text
User Browser
  |
  | HTTPS / HTTP
  v
NGINX Ingress Load Balancer
  |
  | L7 routing (path /)
  v
guestbook-service (ClusterIP 80)
  |
  | Forwards to 3000/TCP
  v
guestbook-app Pods (ReplicaSet x2)
  |
  | CRUD via MONGO_URI Secret
  v
MongoDB VM (System Assigned MI)
  |
  | Backup cron → AzCopy
  v
Storage Account (Blob container)
```

- `app/app.js` は Express によるビュー描画と API を提供し、`/health` でヘルスチェック応答を返します。
- MongoDB VM は `infra/scripts/install-mongodb.sh` と `setup-mongodb-auth.sh` により自動構成され、`setup-backup.sh` が Blob Storage へのバックアップを cron に登録します。
- 監視メトリクスは Log Analytics に送信され、ワークブックで状態を可視化できます。

## 処理のフロー

```text
1. User Request (Browser)
   |
   v
2. NGINX Ingress Controller
   |
   v
3. guestbook-service (ClusterIP)
   |
   v
4. guestbook-app Pod
   |-- Emits logs/metrics to Log Analytics
   |
   v
5. MongoDB VM (Data persistence)
   |
   v
6. Backup Script (cron) → Storage Account (Blob)
```

- ユーザー操作は AKS 内 Pod で処理され、MongoDB に永続化されます。
- バックアップは VM 上の cron が非同期実行し、障害時復旧を前提とした設計です。
- ログとメトリクスは Azure Monitor エージェントが収集し、可観測性を確保します。

## 通信のフロー

```text
Internet User
  |
  | TCP 80 / 443
  v
NGINX Ingress LB
  |
  | TCP 80 (internal)
  v
guestbook-service (ClusterIP)
  |
  | TCP 3000
  v
guestbook-app Pod
  |
  | TCP 27017 (only from snet-aks)
  v
MongoDB VM
  |
  | HTTPS 443 (AzCopy to Blob)
  v
Storage Account (Blob)
```

| 経路                | プロトコル / ポート  | 備考                                             |
| ------------------- | -------------------- | ------------------------------------------------ |
| 利用者 → Ingress    | HTTP/HTTPS : 80, 443 | selfsigned-issuer + `<IP>.nip.io` で自己署名 TLS |
| Ingress → Service   | HTTP : 80            | Ingress アノテーションで `/` へルーティング      |
| Service → Pod       | HTTP : 3000          | Liveness / Readiness Probe も同ポート            |
| Pod → MongoDB VM    | TCP : 27017          | NSG で `10.0.1.0/24` のみ許可                    |
| 管理者 → MongoDB VM | SSH : 22             | デモ用に 0.0.0.0/0 を許容 (本番では閉鎖推奨)     |
| VM → Storage        | HTTPS : 443          | Managed Identity + AzCopy によるバックアップ     |

## CI/CD 構成とデプロイ手順

```text
Push / Pull Request / workflow_dispatch
  |
  +--> 1. Deploy Infrastructure (.github/workflows/01.infra-deploy.yml)
  |      |
  |      +--> Checkov が Bicep をスキャンし SARIF で結果を保存 (IaC 品質)
  |      +--> azure/arm-deploy が `infra/main.bicep` を展開し、AKS や MongoDB VM を構築
  |      +--> 生成した AKS 名や MongoDB IP をアーティファクト化して後続ジョブへ連携
  |
  +--> 2-1. Build and Deploy Application (.github/workflows/02-1.app-deploy.yml)
  |         |
  |         +--> quality-check: `npm test` で lint とユニットテストを実行
  |         +--> codeql-analysis: JavaScript 向け CodeQL で静的解析 (continue-on-error=true で学習用途に最適化)
  |         +--> scan-container: Trivy がコンテナイメージをスキャンし SARIF を Security タブへ送信
  |         +--> build-push: ACR へ `sha` と `latest` タグを push、AKS と MongoDB の情報を取得
  |         +--> deploy-aks: `az aks command invoke` でマニフェストとシークレットを適用し、cert-manager まで自動設定
  |
  +--> 2-2. Deploy Azure Policy Guardrails (.github/workflows/02-2.policy-guardrails.yml)
  |         |
  |         +--> Checkov でポリシー定義を再スキャンし、`Build-CustomMcsb.ps1` で Microsoft Cloud Security Benchmark のカスタムセットを生成
  |         +--> 必要な RBAC を検証しながら `policy-guardrails.bicep` をデプロイ (RBAC 未設定なら自動付与を試行)
  |
  +--> 2-3. Secret Scan with GitGuardian (.github/workflows/02-3.GitGuardian_secret-scan.yml)
            |
            +--> `ggshield secret scan` がコミット履歴と差分を解析し、API キーやパスワード漏洩を検出
            +--> `.github/scripts/ggshield_to_sarif.py` で JSON 結果を SARIF へ変換し、Code Scanning Alerts と Step Summary で可視化
            +--> スキャン失敗時もワークフロー全体は止めず、Security タブで詳細を追えるよう警告を発行
```

- 事前準備
  - Azure サブスクリプションとリソースグループ (`rg-bbs-cicd-aks`)
  - GitHub Secrets: `AZURE_CREDENTIALS`, `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `MONGO_ADMIN_PASSWORD`, `GITGUARDIAN_API_KEY` (任意)
  - GitHub Variables: `AZURE_SUBSCRIPTION_ID`
  - GitHub Variables: `AZURE_RESOURCE_GROUP`, `AZURE_LOCATION`, `IMAGE_NAME`, `AZURE_GITHUB_PRINCIPAL_ID`, `AZURE_GRANT_GITHUB_OWNER`
  - 詳細な登録手順と補足は `SetupGuide.md` を参照
- 手動準備が必要な主な項目
  - Service Principal の発行とロール割り当て (`Scripts/Setup-ServicePrincipal.ps1` を推奨)
  - nip.io 以外のドメインで公開する場合の DNS レコード追加
  - Secrets / Variables の投入 (CLI 例は SetupGuide の「Secrets 設定」章に記載)
- 品質ゲートとセキュリティ
  - IaC: Checkov が Bicep のベストプラクティス違反や脆弱設定 (パブリックストレージ許可など) を検知
  - アプリ: Lint + Jest による回帰検知、CodeQL による静的解析、Trivy による CVE スキャンで攻撃面を最小化
  - シークレット: GitGuardian が過去コミットと最新差分を対象にクラウドキーを検出し、Security タブで継続監視
- 実行例

```powershell
# インフラ用ワークフローを手動実行
# (gh CLI の認証が済んでいることが前提)
gh workflow run infra-deploy.yml

# 最新実行を監視し、異常終了時は非ゼロコードで停止
gh run watch --exit-status

# AKS の資格情報をローカルに取得して状態確認
az aks get-credentials `
  --resource-group rg-bbs-cicd-aks `
  --name aks-dev `
  --overwrite-existing
kubectl get pods -A
```

- ワークフローの工夫点
  - スキャンジョブは `continue-on-error: true` や `soft_fail: true` により学習目的で停止させず、結果を SARIF として保存します。
  - インフラワークフローの出力 (AKS 名や MongoDB IP) をアーティファクト化し、アプリワークフローが `actions/download-artifact` で再利用します。
  - Docker イメージにはコミット SHA と `latest` の二重タグを付与し、ロールバック容易性を確保しています。

## 初期セットアップ

- **Step 1: リポジトリを取得**

  ```powershell
  # プロジェクトをクローン
  git clone https://github.com/<YOUR_ACCOUNT>/CICD-AKS-technical-exercise-demo.git
  # 作業ディレクトリへ移動
  Set-Location CICD-AKS-technical-exercise-demo
  ```

- **Step 2: Azure CLI でログイン**

  ```powershell
  # Azure へログイン
  az login
  # 対象サブスクリプションを選択
  az account set --subscription "<YOUR_SUBSCRIPTION_ID>"
  ```

- **Step 3: Service Principal と Secrets/Variables を登録**

  ```powershell
  # Service Principal を作成しロールを自動付与
  .\Scripts\Setup-ServicePrincipal.ps1 -SubscriptionId "<YOUR_SUBSCRIPTION_ID>"
  # 出力された JSON (AZURE_CREDENTIALS) を GitHub Secrets に登録
  ```

- **Step 4: MongoDB 管理者パスワードを生成**

  ```powershell
  # SetupGuide に掲載のスクリプト例を使用し 32 文字のランダムパスワードを生成
  $mongoPassword = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | ForEach-Object { [char]$_ })
  Set-Clipboard $mongoPassword
  ```

- **Step 5: GitHub Actions を実行**

  ```powershell
  # インフラをデプロイ (Workflow Dispatch)
  gh workflow run "1. Deploy Infrastructure"
  # 完了後にアプリをデプロイ
  gh workflow run "2-1. Build and Deploy Application"
  ```

必要ツール (推奨バージョンは SetupGuide に記載): Azure CLI 最新版、GitHub CLI (`gh`)、Git、PowerShell 7 以上または Bash、kubectl、Docker。

## ディレクトリ構成とファイル説明

```text
CICD-AKS-technical-exercise-demo/
├─ app/                      # Node.js アプリと Kubernetes マニフェスト
│  ├─ app.js                 # Express アプリ本体 (Mongo 連携)
│  ├─ Dockerfile             # コンテナビルド定義
│  ├─ k8s/                   # AKS に適用する YAML 群 (deployment, service, ingress, RBAC)
│  └─ __tests__/             # Jest によるヘルスチェックテスト
├─ infra/                    # Bicep モジュール、パラメータ、VM スクリプト
│  ├─ main.bicep             # サブスクリプションスコープのエントリーポイント
│  ├─ modules/               # VNet / AKS / ACR / VM などのモジュラー定義
│  ├─ parameters/            # dev 用パラメータ例
│  └─ scripts/               # MongoDB セットアップ・バックアップ脚本
├─ Scripts/                  # PowerShell セットアップ支援ツール
├─ Docs/                     # 設計メモ・セキュリティ / 運用ノウハウ
├─ Docs_issue_point/         # 調査ログ・課題管理メモ
└─ documentation/            # プレゼン資料・追加ドキュメント
```

初心者は `SetupGuide.md` → `infra/main.bicep` → `app/k8s/` の順に読み進めると構成を理解しやすく、詳細な背景やトラブルシューティングは `Docs/` に整理されています。

## 主要ファイルの技術的説明

### Bicep モジュール

| ファイル                          | 役割                                                                         | 補足                                                                 |
| --------------------------------- | ---------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| `infra/main.bicep`                | リソースグループ、ネットワーク、AKS、ACR、VM、Monitor、Policy を統括デプロイ | Defender for Cloud プランやアクティビティログ収集も同時構成          |
| `infra/modules/networking.bicep`  | 10.0.0.0/16 VNet と AKS / Mongo 用サブネットを定義                           | AKS サブネットでは Private Endpoint ポリシーを無効化して柔軟性を確保 |
| `infra/modules/aks.bicep`         | System Assigned Managed Identity を持つ AKS をデプロイ                       | Public API、Azure CNI、Log Analytics アドオンを有効化                |
| `infra/modules/acr.bicep`         | Standard SKU の ACR を作成                                                   | Admin ユーザー無効化、Managed Identity で Pull する前提              |
| `infra/modules/vm-mongodb.bicep`  | Public IP 付き Ubuntu VM と NSG を作成し MongoDB をセットアップ              | SSH 全開放や古い OS など脆弱設定を意図的に残して学習教材化           |
| `infra/modules/diagnostics.bicep` | AKS / ACR / VM / NSG の診断ログを Log Analytics へ転送                       | 監査・アラート分析のベースラインを形成                               |

### GitHub Actions ワークフロー

- `.github/workflows/01.infra-deploy.yml` などの GitHub Actions が正規フローです。Azure ログイン後に Bicep/AKS をデプロイし、SARIF をセキュリティタブへ送信します。

### スクリプト

- `Scripts/Setup-ServicePrincipal.ps1`: Service Principal の作成・ロール割り当て・Secrets 用 JSON 出力を自動化します。
- `infra/scripts/install-mongodb.sh`: MongoDB のリポジトリ追加とパッケージ導入を行います。
- `infra/scripts/setup-mongodb-auth.sh`: 管理ユーザー作成と認証設定を自動化し、`MONGO_ADMIN_PASSWORD` を注入します。
- `infra/scripts/setup-backup.sh`: Managed Identity を利用した Blob Storage へのバックアップ cron ジョブを登録します。
- `Scripts/deploy-ingress-controller.ps1`: ローカル検証時に NGINX Ingress Controller を展開する補助スクリプトです (GitHub Actions 実行時は不要)。

## 今後の改善点 - DevOps / DevSecOps

- GitHub OIDC を導入して Service Principal シークレットを廃止し、シークレット管理負荷を削減する。
- Ingress Controller を Internal Load Balancer 化し、Application Gateway (リージョン内の WAF/ルーティング) や Azure Front Door (グローバル WAF/DDoS 緩和) を前段に置いて多層防御を構築する。ILB のプライベート IP を Application Gateway のバックエンド プールへ割り当て、外部公開は Front Door / Application Gateway に限定する形にする。
- セキュリティスキャンを段階的に fail-fast 化し、許容ポリシーや Allowlist を整備したうえで CRITICAL / HIGH 検出時にデプロイを停止させる。
- Azure Policy を強化し、SSH 公開や HTTP 許可などの脆弱設定をステージング → 本番の順に段階的に禁止する。
- AKS Workload Identity と Namespaced RBAC を導入し、Pod 単位で最小権限を徹底する。
- GitGuardian SARIF が Security タブへ反映されるよう調査を継続し、必要に応じて GitHub Support や Advanced Security 設定の見直しを行う。
- MongoDB バックアップ実行を GitHub Actions からスケジュールトリガーできるよう再設計し、VM 内 cron と Actions のどちらでも走らせられるハイブリッド構成を検討する。

## 参考資料

- [GitHub Actions から Azure リソースをデプロイする方法](https://learn.microsoft.com/ja-jp/azure/developer/github/github-actions-workflow)
- [AKS ネットワークとセキュリティのベストプラクティス](https://learn.microsoft.com/ja-jp/azure/aks/operator-best-practices-network)
- [Azure Monitor と Log Analytics を活用したログ分析チュートリアル](https://learn.microsoft.com/ja-jp/azure/azure-monitor/logs/log-analytics-tutorial)
