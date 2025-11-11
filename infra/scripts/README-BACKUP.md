# MongoDB バックアップ設定ガイド

## 📋 概要

MongoDB VM 上で **1 日 3 回自動バックアップ** を実行する cron ベースのバックアップシステムです。

> ℹ️ バックアップ構成は `setup-backup.sh` が一括で作成します。再設定が必要な場合は本スクリプトを再実行するか、後述の手順で cron エントリを直接編集してください。

### バックアップスケジュール

| 時刻 (JST) | 時刻 (UTC)   | 説明             |
| ---------- | ------------ | ---------------- |
| 02:00      | 17:00 (前日) | 深夜バックアップ |
| 10:00      | 01:00        | 午前バックアップ |
| 18:00      | 09:00        | 夕方バックアップ |

---

## 🚀 初回セットアップ

### 1. バックアップスクリプトのインストール

**PowerShell (推奨):**

```powershell
# Azure にログイン
az login

# 環境変数設定
$RG = "rg-bbs-cicd-aks200"
$VM_NAME = "vm-mongo-dev"
$STORAGE_ACCOUNT = "stwizdevrwocrqcivjsx4"  # 実際の値に置き換え
$MONGO_ADMIN_USER = "mongoadmin"
$MONGO_ADMIN_PASSWORD = "your-password"

# setup-backup.sh をダウンロードして実行
az vm run-command invoke `
  --resource-group $RG `
  --name $VM_NAME `
  --command-id RunShellScript `
  --scripts @"
export MONGO_ADMIN_USER='$MONGO_ADMIN_USER'
export MONGO_ADMIN_PASSWORD='$MONGO_ADMIN_PASSWORD'
curl -fsSL https://raw.githubusercontent.com/aktsmm/CICD-AKS-technical-exercise-demo/main/infra/scripts/setup-backup.sh | bash -s -- '$STORAGE_ACCOUNT' 'backups'
"@
```

**Bash (Linux/macOS):**

```bash
# Azure にログイン
az login

# 環境変数設定
export RG="rg-bbs-cicd-aks200"
export VM_NAME="vm-mongo-dev"
export STORAGE_ACCOUNT="stwizdevrwocrqcivjsx4"
export MONGO_ADMIN_USER="mongoadmin"
export MONGO_ADMIN_PASSWORD="your-password"

# setup-backup.sh をダウンロードして実行
az vm run-command invoke \
  --resource-group "$RG" \
  --name "$VM_NAME" \
  --command-id RunShellScript \
  --scripts "
export MONGO_ADMIN_USER='$MONGO_ADMIN_USER'
export MONGO_ADMIN_PASSWORD='$MONGO_ADMIN_PASSWORD'
curl -fsSL https://raw.githubusercontent.com/aktsmm/CICD-AKS-technical-exercise-demo/main/infra/scripts/setup-backup.sh | bash -s -- '$STORAGE_ACCOUNT' 'backups'
"
```

### 2. cron ジョブを再適用したい場合 (任意)

`setup-backup.sh` は root ユーザーの crontab に `0 * * * * /usr/local/bin/mongodb-backup.sh` を登録します。実行タイミングを変更したい場合は以下のいずれかで調整してください。

- `setup-backup.sh` を再実行し、スクリプト内の cron 行 (`0 * * * * /usr/local/bin/mongodb-backup.sh ...`) を事前に編集してから適用する。
- VM へ SSH ログインし、`sudo crontab -e` で該当行を編集したのち `sudo systemctl reload cron` を実行する。

```bash
# 現在設定されている cron エントリを確認
sudo crontab -l | grep mongodb-backup
```

> ℹ️ 旧 `manual/setup-cron-backup.sh` は削除済みです。上記のいずれかの方法で最新状態を維持してください。

---

## 🔧 オンデマンドバックアップ

### VM 内で実行

```bash
sudo /usr/local/bin/mongodb-backup.sh
```

### Azure CLI 経由で実行

**PowerShell (推奨):**

```powershell
az vm run-command invoke `
  --resource-group "rg-bbs-cicd-aks200" `
  --name "vm-mongo-dev" `
  --command-id RunShellScript `
  --scripts '/usr/local/bin/mongodb-backup.sh'
```

**Bash (Linux/macOS):**

```bash
az vm run-command invoke \
  --resource-group "rg-bbs-cicd-aks200" \
  --name "vm-mongo-dev" \
  --command-id RunShellScript \
  --scripts '/usr/local/bin/mongodb-backup.sh'
```

---

## 📊 監視・確認

### cron ジョブ確認

```bash
sudo crontab -l | grep mongodb-backup
```

### ログ確認

```bash
# リアルタイムログ
sudo tail -f /var/log/mongodb-backup.log

# 最新20行
sudo tail -n 20 /var/log/mongodb-backup.log
```

### バックアップファイル確認

**PowerShell (推奨):**

```powershell
# ローカルバックアップ一覧
az vm run-command invoke `
  --resource-group $RG `
  --name $VM_NAME `
  --command-id RunShellScript `
  --scripts 'ls -lh /var/backups/mongodb/'

# Azure Storage 内のバックアップ確認
az storage blob list `
  --account-name $STORAGE_ACCOUNT `
  --container-name "backups" `
  --output table
```

**Bash (Linux/macOS):**

```bash
# ローカルバックアップ一覧
az vm run-command invoke \
  --resource-group "$RG" \
  --name "$VM_NAME" \
  --command-id RunShellScript \
  --scripts 'ls -lh /var/backups/mongodb/'

# Azure Storage 内のバックアップ確認
az storage blob list \
  --account-name "$STORAGE_ACCOUNT" \
  --container-name "backups" \
  --output table
```

---

## 🛠️ トラブルシューティング

### cron が実行されない場合

```bash
# cron サービス状態確認
sudo systemctl status cron

# cron を再起動
sudo systemctl restart cron

# cron ログ確認
sudo grep CRON /var/log/syslog | tail -n 20
```

### バックアップが失敗する場合

```bash
# 手動実行でエラー確認
sudo /usr/local/bin/mongodb-backup.sh

# MongoDB 接続確認
mongosh -u "$MONGO_ADMIN_USER" -p "$MONGO_ADMIN_PASSWORD" --eval "db.adminCommand('ping')"

# Azure CLI 認証確認
az account show
```

---

## 📦 バックアップファイル構造

```text
/var/backups/mongodb/
└── mongodb_backup_20250105_020000.tar.gz  # YYYYMMDD_HHMMSS 形式

Azure Storage:
└── backups/
    └── mongodb_backup_20250105_020000.tar.gz
```

---

## 🔒 セキュリティ考慮事項

- ✅ バックアップストレージは **公開リスト・公開読み取り可能** (Wiz 課題要件)
- ✅ MongoDB 認証必須
- ✅ Kubernetes ネットワーク内からのみ MongoDB アクセス可能
- ⚠️ SSH ポートはパブリックに公開 (Wiz 課題要件)

---

## 📚 関連ファイル

| ファイル                           | 説明                               |
| ---------------------------------- | ---------------------------------- |
| `setup-backup.sh`                  | バックアップスクリプトインストール |
| `/usr/local/bin/mongodb-backup.sh` | 実際のバックアップスクリプト       |
| `/var/log/mongodb-backup.log`      | バックアップログ                   |

---

## ❓ よくある質問

**Q: バックアップは自動削除される？**  
A: いいえ。手動削除が必要です。将来的にログローテーション機能を追加予定。

**Q: バックアップ時刻を変更したい**  
A: `/etc/cron.d/mongodb-backup` を編集して `cron` を再読み込みするか、`setup-backup.sh` を再実行してください。

**Q: GitHub Actions は使わないの？**  
A: Azure Run Command の不安定性により、VM 内 cron に変更しました。より信頼性が高く、シンプルです。

**Q: 以前の GitHub Actions ワークフロー (`backup-schedule.yml`) はどうなった？**  
A: 2025 年 11 月 6 日に削除されました。VM 内 cron で安定稼働しているため、GitHub Actions 経由のバックアップは不要になりました。手動バックアップが必要な場合は、上記の「オンデマンドバックアップ」セクションを参照してください。
