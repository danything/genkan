# genkan

[English](./README.en.md)

コンテナの玄関。ホスト名でコンテナにルーティングするリバースプロキシです。

[caddy-docker-proxy](https://github.com/lucaslorentz/caddy-docker-proxy) のコンテナが80/443番で待ち受け、ホスト名を各コンテナに振り分けます。設定はこの `compose.yml` 1枚だけ。各プロジェクトはラベル2行でオプトインし、ポートを公開しないのでポート競合が起きません。

ローカル開発では `*.localhost` がそのまま使えます（DNS設定不要）。実ドメインを向ければLet's Encryptで証明書も自動取得されるので、サーバーでも同じ構成が使えます。

## 使い方

```sh
curl -sf https://raw.githubusercontent.com/danything/genkan/main/init.sh | sh -s
```

初回はこのリポジトリをクローンして起動し、2回目以降は `git pull` で変更に追従してから再適用します。同梱の Arcane 用の暗号化キーと管理者パスワードも、初回だけ生成されます（[その他](#その他)）。手動なら:

```sh
git clone https://github.com/danything/genkan.git
cd genkan
cat > compose.override.yml <<EOT
services:
  arcane:
    environment:
      - ENCRYPTION_KEY=$(od -An -tx1 -N32 /dev/urandom | tr -d ' \n')
EOT
docker compose up -d
```

## プロジェクトの追加

ラベルを2行追加して `proxy` ネットワークに参加させるだけです。

```yml
services:
  app:
    labels:
      caddy: myapp.localhost
      caddy.reverse_proxy: "{{upstreams 5173}}"
    networks: [default, proxy]

networks:
  proxy:
    external: true
```

- `{{upstreams 5173}}` は「このコンテナ自身のIP:5173」に展開されます。ポートは**アプリがコンテナ内で待ち受けているポート**を必ず指定してください（`EXPOSE` からの自動検出はありません）
- プロジェクト側で `ports:` は公開しないでください。公開しないことがポート競合をなくす仕組みそのものです

あとは http://myapp.localhost を開くだけです（自動的にHTTPSへリダイレクトされます）。

## HTTPS

`*.localhost` にはCaddyの内部CAが証明書を自動発行します。ブラウザの警告を消したい場合は、ルート証明書を一度だけ信頼ストアに登録してください:

```sh
docker compose cp proxy:/data/caddy/pki/authorities/local/root.crt .
```

実ドメインの場合は何もしなくてもLet's Encryptで自動取得されます。

## その他

DockerをWeb UIで管理できる [Arcane](https://github.com/getarcaneapp/arcane) が同梱されています → http://arcane.localhost

Arcaneの管理者は `arcane` / `arcane-admin` で作られ、初回ログイン時にパスワード変更を強制されます。手で入力するのは面倒なので、`init.sh` が起動後にAPI経由で強いパスワードを生成して設定し、`arcane-password.txt` に保存したうえで画面にも表示します。すでに変更済みなら何もしません。

```
ユーザー名: arcane
パスワード: arcane-password.txt の2行目
```

`arcane-password.txt` もホストごとの秘密なのでコミットされません。パスワードを忘れたときはこのファイルを見てください（消してしまった場合はArcaneのUIから変更するか、`arcane-data` ボリュームを消して作り直しになります）。

Arcaneは保存する認証情報の暗号化に32文字以上の `ENCRYPTION_KEY` を要求します。これは `init.sh` が初回に生成する `compose.override.yml` から渡されます。Composeが自動で読み込むので `-f` の指定は要りません。

`compose.override.yml` はホストごとの秘密なのでコミットされません（消すとArcaneに保存済みの認証情報が復号できなくなります）。このファイルが無いままArcaneを起動すると `ENCRYPTION_KEY passphrase must be at least 32 characters in production` で再起動を繰り返すので、`docker compose logs arcane` で確認してください。

`compose.yml` を直接編集せずに設定を足したいときも、このファイルに書き足せます。

以前のPortainer同梱版から更新した場合、古いコンテナは `init.sh`（`docker compose up -d --remove-orphans`）で片付きます。データを消してよければボリュームも削除してください:

```sh
docker volume rm genkan_portainer-data
```
