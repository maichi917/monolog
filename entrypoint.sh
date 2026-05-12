#!/bin/bash
set -e

# server.pidファイルを削除する
rm -f /app/tmp/pids/server.pid

# コンテナのメインプロセス（CMDコマンドの中身）を実行する
exec "$@"
