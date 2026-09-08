#!/bin/sh
set -e

if [ -d genkan/.git ]; then
	cd genkan
	git pull --ff-only
else
	git clone https://github.com/danything/genkan.git
	cd genkan
fi

# Arcane の暗号化キーは初回だけ生成する。既存の compose.override.yml は上書きしない。
if [ ! -f compose.override.yml ]; then
	arcane_key=$(od -An -tx1 -N32 /dev/urandom | tr -d ' \n')
	cat > compose.override.yml <<EOT
# init.sh が生成。Arcane が保存する認証情報の暗号化キー。
# ホストごとの秘密なのでコミットしないこと。
# 消すとArcaneに保存済みの認証情報が復号できなくなる。
services:
  arcane:
    environment:
      - ENCRYPTION_KEY=$arcane_key
EOT
fi

docker compose up -d --remove-orphans
