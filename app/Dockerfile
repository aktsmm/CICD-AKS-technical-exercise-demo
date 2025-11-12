# ベースイメージ：軽量な Alpine 上の Node.js 18 を使用
FROM node:18-alpine

# 作業ディレクトリを /app に設定（以降のコマンドの基準ディレクトリ）
WORKDIR /app

# デモ用ファイルをイメージに同梱（課題要件の“wizexercise.txt”）
COPY wizexercise.txt /app/wizexercise.txt

# 依存解決レイヤーをキャッシュさせるため、まず package*.json だけコピー
COPY package*.json ./

# 本番依存のみをインストール（devDependencies を除外）
# ※ lock を参照しつつ、状況により lock を更新することがあるのが npm install の挙動
#   → 再現性重視なら npm ci --omit=dev を推奨（下に推奨版あり）
RUN npm install --omit=dev

# アプリ本体（ソース、テンプレ、静的ファイル等）をコピー
COPY . .

# コンテナが待ち受けるポート（メタ情報。実際の公開は -p や Service/Ingress で行う）
EXPOSE 3000

# コンテナ起動時に実行するコマンド（package.json の "start" を起動）
CMD ["npm", "start"]
