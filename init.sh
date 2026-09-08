#!/bin/sh
set -e

if [ -d genkan/.git ]; then
	cd genkan
	git pull --ff-only
else
	git clone https://github.com/danything/genkan.git
	cd genkan
fi

# Arcane の暗号化キーは初回だけ生成する。既存の .env は上書きしない。
if [ ! -f .env ]; then
	printf 'ARCANE_ENCRYPTION_KEY=%s\n' "$(od -An -tx1 -N32 /dev/urandom | tr -d ' \n')" > .env
fi

docker compose up -d --remove-orphans
