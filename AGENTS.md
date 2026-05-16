# AGENTS.md

## プロジェクト概要
Rails 7.1 + PostgreSQL の在庫管理・レビューアプリ。認証は Devise、CSS は Tailwind CSS。Docker Compose で開発する。

## コマンド
- 起動: `docker compose up`
- 停止: `docker compose down`
- DBマイグレーション: `docker compose exec web bin/rails db:migrate`
- テスト: `docker compose exec web bin/rails test`
- テスト（単一）: `docker compose exec web bin/rails test test/models/item_test.rb`
- Railsコンソール: `docker compose exec web bin/rails console`

## コードスタイル
- Rails の標準的な MVC 構成に従う
- 変数名・メソッド名・モデル名・カラム名は英語、画面文言とコメントは日本語
- controller は薄くし、在庫や使用履歴の判定ロジックは model に寄せる

## アーキテクチャ
- モデルは `app/models/`
- コントローラは `app/controllers/`
- ビューは `app/views/`
- マイグレーションは `db/migrate/`
- テストは `test/`

## 在庫管理方針
- `items` はアイテム本体、`usage_logs` は使用履歴を表す
- 使用状態は `items.status` ではなく、未完了の `usage_logs` から判定する
- `usage_logs.finished_at` が `nil` のレコードは使用中を表す

## 権限
- 自動実行OK: テスト、読み取り系コマンド
- 確認が必要: パッケージ追加、DB操作、git push

## 困ったら
要件が曖昧な場合は推測で大きな変更をせず、質問すること。

## AI Response Rules

- 初学者向けに説明する
- 現在地を毎回説明する
- 実装に入る前にこれから触るファイル（DB/model/controller/view等）を明示する
- コード提示前に目的を説明する
- 複数ファイルにまたがる変更は、一気に実装しない
- 一度に大量のコードを出さない
- issue対応では、最初に issue の内容を要約し、作業ステップに分解して提示する
- エラーが発生した場合は、原因を明確にし、必要に応じてエラー文の解説をする
- 推測で大規模な変更をしない
- 修正後は「何ができるようになったか」を説明する
