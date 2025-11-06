# セキュリティポリシー

## ⚠️ 重要なお知らせ

**このプロジェクトは教育目的で意図的にセキュリティ脆弱性を含んでいます。**

すべての脆弱性は文書化され、追跡され、セキュリティ検出と修復能力を実証するために使用されています。

---

## 🔒 脆弱性の報告

このプロジェクトで**意図しない**セキュリティ脆弱性を発見した場合は、責任を持って報告してください:

### オプション 1: GitHub セキュリティアドバイザリ（推奨）

1. https://github.com/aktsmm/CICD-AKS-technical-exercise/security/advisories にアクセス
2. **"New draft security advisory"** をクリック
3. テンプレートに詳細を記入
4. レビュー用に送信

### オプション 2: プライベートメール

- **メール**: security@example.com（プレースホルダー - 実際の連絡先に更新してください）
- **PGP Key**: リクエストに応じて提供
- **予想応答時間**: 48 時間以内

### オプション 3: GitHub Issue（低重要度のみ）

セキュリティクリティカルでない低重要度の問題については、公開の GitHub Issue を作成できます。

---

## 📋 既知の脆弱性（意図的）

以下の脆弱性は、技術演習要件の一部として**意図的に実装**されています:

### 🔴 クリティカル

#### GHSA-001: MongoDB VM のインターネット公開 SSH ポート

- **CVSS**: 9.8 Critical
- **ステータス**: 既知、デモ用に意図的
- **場所**: [`infra/modules/vm-mongodb.bicep:123`](../infra/modules/vm-mongodb.bicep)
- **説明**: NSG ルールを通じて SSH ポート(22)がインターネット(0.0.0.0/0)に公開
- **影響**: ブルートフォース攻撃、不正な VM アクセス
- **緩和策**: sourceAddressPrefix を特定の IP に制限するか、Azure Bastion を使用
- **検出**: ✅ "SSH が有効なインターネット公開 VM"

#### GHSA-003: 公開アクセス可能な MongoDB バックアップストレージ

- **CVSS**: 9.1 Critical
- **ステータス**: 既知、デモ用に意図的
- **場所**: [`infra/modules/storage.bicep:45`](../infra/modules/storage.bicep)
- **説明**: `publicAccess: 'Blob'` を持つ Blob コンテナが匿名ダウンロードを許可
- **影響**: データの流出、認証情報の露出
- **緩和策**: `publicAccess: 'None'` を設定し、プライベートエンドポイントを使用
- **検出**: ✅ "機密データを含む公開ストレージコンテナ"
- **公開 URL 例**: `https://stwizdevj2axc7dgverlk.blob.core.windows.net/backups/mongodb_backup_*.tar.gz`

#### GHSA-102: 環境変数にハードコードされた MongoDB 認証情報

- **CVSS**: 9.8 Critical
- **ステータス**: 部分的に緩和（Kubernetes Secrets）
- **場所**: [`app/k8s/deployment.yaml:30`](../app/k8s/deployment.yaml)
- **説明**: 認証情報が埋め込まれた MongoDB 接続文字列
- **影響**: Pod が侵害された場合の認証情報漏洩
- **緩和策**: Azure Key Vault + Secrets Store CSI Driver を使用
- **検出**: ✅ "コンテナ環境内のハードコードされたシークレット"

### 🟠 高

#### GHSA-002: MongoDB VM の過剰なクラウド権限

- **CVSS**: 8.1 High
- **ステータス**: 既知、デモ用に意図的
- **場所**: [`infra/modules/vm-mongodb.bicep:89`](../infra/modules/vm-mongodb.bicep)
- **説明**: マネージド ID に Contributor ロールが割り当てられている（VM 作成/削除可能）
- **影響**: 横展開、権限昇格、リソース操作
- **緩和策**: 最小限必要な権限のみを割り当て（Storage Blob Data Contributor のみ）
- **検出**: ✅ "過剰な権限を持つクラウド ID"

#### GHSA-101: 過剰な権限を持つ Kubernetes Pod（cluster-admin）

- **CVSS**: 8.8 High
- **ステータス**: 既知、デモ用に意図的
- **場所**: [`app/k8s/rbac.yaml:10`](../app/k8s/rbac.yaml)
- **説明**: デフォルト ServiceAccount が cluster-admin ClusterRole にバインドされている
- **影響**: Pod が悪用された場合のクラスタ全体の侵害
- **緩和策**: 最小権限 RBAC を持つ専用 ServiceAccount を作成
- **検出**: ✅ "過剰な権限を持つ Kubernetes ワークロード"

#### GHSA-201: CI/CD でのセキュリティスキャン無効化

- **CVSS**: 7.3 High
- **ステータス**: 既知、デモ用に意図的
- **場所**: [`.github/workflows/02-1.app-deploy.yml:45`](../.github/workflows/02-1.app-deploy.yml)
- **説明**: パイプラインで Trivy 脆弱性スキャナがコメントアウトされている
- **影響**: 脆弱なコンテナイメージが本番環境にデプロイされる
- **緩和策**: Trivy アクションのコメントを解除し、HIGH/CRITICAL でビルドを失敗させる
- **検出**: ✅ "パイプラインでのセキュリティゲート欠如"

#### GHSA-202: GitHub リポジトリに保存されたシークレット

- **CVSS**: 8.2 High
- **ステータス**: 緩和済み（GitHub Secrets）
- **場所**: [`.github/workflows/01.infra-deploy.yml:20`](../.github/workflows/01.infra-deploy.yml)
- **説明**: MongoDB パスワードが GitHub Secrets に保存されている（保存時に暗号化）
- **影響**: GitHub アカウント侵害によるシークレット露出
- **緩和策**: マネージド ID を使用した Azure Key Vault を使用
- **検出**: ✅ "CI/CD 変数内の認証情報"

### 🟡 中

#### GHSA-004: 古い MongoDB バージョン（4.4.29）

- **CVSS**: 6.5 Medium
- **ステータス**: 既知、意図的（プロジェクト要件）
- **場所**: [`infra/scripts/install-mongodb.sh:15`](../infra/scripts/install-mongodb.sh)
- **説明**: MongoDB 4.4.29 には既知の CVE がある（例: CVE-2021-32050）
- **影響**: サービス拒否、潜在的なリモートコード実行
- **緩和策**: セキュリティパッチを含む MongoDB 7.0+にアップグレード
- **検出**: ✅ "既知の CVE を持つ古いデータベースバージョン"

#### GHSA-005: 古いオペレーティングシステム（Ubuntu 20.04）

- **CVSS**: 5.9 Medium
- **ステータス**: 既知、意図的（プロジェクト要件）
- **場所**: [`infra/modules/vm-mongodb.bicep:67`](../infra/modules/vm-mongodb.bicep)
- **説明**: Ubuntu 20.04 LTS（2020 年 4 月リリース）は 1 年以上前のバージョン
- **影響**: OS 脆弱性のセキュリティパッチ欠如
- **緩和策**: Ubuntu 22.04 LTS 以降にアップグレード
- **検出**: ✅ "古い OS バージョン"

#### GHSA-103: Web アプリケーションのレート制限欠如

- **CVSS**: 6.1 Medium
- **ステータス**: 既知、簡略化のため未実装
- **場所**: [`app/app.js:25`](../app/app.js)
- **説明**: Express.js アプリケーションにレート制限ミドルウェアが欠けている
- **影響**: リクエストフラッディングによるサービス拒否
- **緩和策**: `express-rate-limit`ミドルウェアを追加
- **検出**: ❌（アプリケーションレベルの制御、インフラストラクチャではない）

---

## 🛡️ 実装されているセキュリティ対策

### インフラストラクチャレベル

- ✅ **ネットワークセグメンテーション**: MongoDB は別サブネット（10.0.2.0/24）に配置
- ✅ **認証必須**: MongoDB はユーザー名/パスワード認証を強制
- ✅ **自動バックアップ**: Azure Blob Storage への日次 cron ジョブ
- ✅ **マネージド ID**: VM はリソースアクセスに Azure AD ID を使用
- ✅ **プライベート AKS サブネット**: Kubernetes ノードがプライベートサブネット（10.0.1.0/24）に配置

### アプリケーションレベル

- ✅ **Kubernetes Secrets**: Secret リソース経由で認証情報を注入
- ✅ **コンテナレジストリ**: イメージを Azure Container Registry（ACR）に保存
- ✅ **HTTPS 対応**: Ingress コントローラーが TLS 終端をサポート
- ✅ **入力検証**: Express.js ルートでの基本的なサニタイゼーション

### CI/CD パイプライン

- ✅ **Infrastructure as Code**: バージョン管理された Bicep テンプレート
- ✅ **自動デプロイ**: GitHub Actions ワークフロー
- ✅ **プルリクエスト検証**: PR での Bicep lint
- ⚠️ **セキュリティスキャン**: Trivy 利用可能だが無効化（デモ目的）

---

## 🔍 セキュリティスキャンツール

### 有効化済み

- ✅ **Dependabot アラート**: 依存関係の脆弱性自動スキャン
- ✅ **シークレットスキャン**: コミット内の認証情報漏洩を防止
- ✅ **CodeQL 分析**: コード脆弱性の静的解析
- ✅ **Bicep Lint**: インフラストラクチャコードの検証

### 利用可能だが無効化（デモ用）

- ⚠️ **Trivy コンテナスキャン**: イメージ脆弱性検出
- ⚠️ **OWASP 依存関係チェック**: サードパーティライブラリの CVE スキャン
- ⚠️ **Checkov**: IaC セキュリティポリシー検証

---

## 📝 責任ある開示ガイドライン

### 意図しない脆弱性について

**上記にリストされていない**脆弱性を発見した場合:

1. 公開の GitHub Issue を**作成しない**
2. セキュリティアドバイザリまたはプライベートメールを**使用する**
3. 公開開示前に 90 日間の修復期間を**許可する**
4. 詳細な再現手順と概念実証を**提供する**
5. セキュリティ謝辞ページでクレジットを**受け取る**

### 予想されるタイムライン

- **初回応答**: 48 時間
- **トリアージと検証**: 7 日
- **修正開発**: 30 日
- **パッチリリース**: 60 日
- **公開開示**: 90 日（報告者と調整）

---

## 📚 セキュリティリソース

### ドキュメント

- [Azure セキュリティベストプラクティス](https://docs.microsoft.com/ja-jp/azure/security/fundamentals/best-practices-and-patterns)
- [Kubernetes セキュリティ](https://kubernetes.io/ja/docs/concepts/security/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CIS Azure Foundations Benchmark](https://www.cisecurity.org/benchmark/azure)

### ツール

- [Azure Defender](https://azure.microsoft.com/ja-jp/services/azure-defender/)
- [Trivy](https://github.com/aquasecurity/trivy)
- [Checkov](https://www.checkov.io/)

### トレーニング

- [Azure Security Engineer Associate](https://docs.microsoft.com/ja-jp/certifications/azure-security-engineer/)
- [Certified Kubernetes Security Specialist (CKS)](https://www.cncf.io/certification/cks/)

---

## 🙏 セキュリティ謝辞

責任を持ってセキュリティ問題を開示してくださった以下の方々に感謝します:

- _意図しない脆弱性はまだ報告されていません_

---

## 📞 連絡先

**プロジェクトメンテナー**: Tatsumi Yamamoto  
**リポジトリ**: https://github.com/aktsmm/CICD-AKS-technical-exercise  
**目的**: 技術演習（教育目的）

---

**最終更新**: 2025-11-06  
**バージョン**: 1.0.0  
**ステータス**: アクティブ（デモプロジェクト）
