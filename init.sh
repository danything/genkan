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

# Arcane の管理者は arcane / arcane-admin で作られ、初回ログイン時にパスワード変更を強制される。
# 手で入力するのは面倒なので、まだ初期パスワードのままなら API 経由でここで済ませておく。

arcane_api() {
	# Caddy 経由で叩く。*.localhost が名前解決できないホストがあるので --resolve で固定する。
	# 証明書はCaddyの内部CA発行なので -k で通す（宛先は 127.0.0.1 固定）。
	path=$1
	shift
	curl -sk -m 10 --resolve arcane.localhost:443:127.0.0.1 "https://arcane.localhost$path" "$@"
}

arcane_json() {
	# "key":"value" を取り出す。値に " を含まない前提（トークンもパスワードも該当しない）。
	sed -n 's/.*"'"$1"'":"\([^"]*\)".*/\1/p'
}

arcane_gen_password() {
	# Arcane の strong ポリシー: 12文字以上 + 大文字・小文字・数字・記号。
	# JSON に素で入れるので " と \ は使わない。
	alphabet='abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@%*+=-'
	n=$(printf %s "$alphabet" | wc -c | tr -d ' ')
	while :; do
		pw=''
		for byte in $(od -An -tu1 -N20 /dev/urandom); do
			pw="$pw$(printf %s "$alphabet" | cut -c$((byte % n + 1)))"
		done
		printf %s "$pw" | grep -q '[a-z]' || continue
		printf %s "$pw" | grep -q '[A-Z]' || continue
		printf %s "$pw" | grep -q '[0-9]' || continue
		printf %s "$pw" | grep -q '[!@%*+=-]' || continue
		printf %s "$pw"
		return
	done
}

arcane_setup_password() {
	i=0
	until arcane_api /api/health >/dev/null 2>&1; do
		i=$((i + 1))
		if [ "$i" -ge 60 ]; then
			echo "Arcane が起動しませんでした。docker compose logs arcane を確認してください。" >&2
			return
		fi
		sleep 1
	done

	token=$(arcane_api /api/auth/login -X POST \
		-H 'Content-Type: application/json' \
		-d '{"username":"arcane","password":"arcane-admin"}' | arcane_json token)
	if [ -z "$token" ]; then
		# 初期パスワードで入れない = すでに変更済み。何もしない。
		return
	fi

	password=$(arcane_gen_password)
	result=$(arcane_api /api/auth/password -X POST \
		-H "Authorization: Bearer $token" \
		-H 'Content-Type: application/json' \
		-d "{\"currentPassword\":\"arcane-admin\",\"newPassword\":\"$password\"}")
	case $result in
	*'"success":true'*) ;;
	*)
		echo "Arcane のパスワード変更に失敗しました: $result" >&2
		return
		;;
	esac

	(umask 077; printf 'arcane\n%s\n' "$password" > arcane-password.txt)
	echo
	echo "Arcane の管理者パスワードを生成しました (arcane-password.txt にも保存):"
	echo "  ユーザー名: arcane"
	echo "  パスワード: $password"
	echo
}

arcane_setup_password
