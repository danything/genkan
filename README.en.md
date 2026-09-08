# genkan

[日本語](./README.md)

Genkan (玄関) is the entryway of a Japanese home — here, the entryway to your containers. A reverse proxy that routes hostnames to containers.

A [caddy-docker-proxy](https://github.com/lucaslorentz/caddy-docker-proxy) container listens on ports 80/443 and routes each hostname to its container. The entire setup is this single `compose.yml`. Each project opts in with two labels and publishes no ports, so port conflicts cannot happen.

For local development, `*.localhost` works out of the box (no DNS setup). Point a real domain at it and certificates come from Let's Encrypt automatically, so the same setup works on servers too.

## How to use

```sh
curl -sf https://raw.githubusercontent.com/danything/genkan/main/init.sh | sh -s
```

On first run it clones this repository and starts the proxy; on subsequent runs it pulls the latest changes and re-applies them. It also generates the encryption key for the bundled Arcane into `compose.override.yml`, once. Or manually:

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

## Adding a project

Add two labels and join the `proxy` network.

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

- `{{upstreams 5173}}` expands to "this container's IP:5173". Always specify the port your app listens on inside the container — there is no auto-detection from `EXPOSE`
- Do not publish ports in the project's compose file; not publishing is exactly what makes port conflicts impossible

Then open http://myapp.localhost (it redirects to HTTPS automatically).

## HTTPS

Caddy's internal CA issues certificates for `*.localhost` automatically. To avoid browser warnings, trust the root certificate once:

```sh
docker compose cp proxy:/data/caddy/pki/authorities/local/root.crt .
```

For real domains, certificates are obtained from Let's Encrypt automatically.

## Extras

Comes with [Arcane](https://github.com/getarcaneapp/arcane), a web UI for managing Docker → http://arcane.localhost

Arcane requires an `ENCRYPTION_KEY` of at least 32 characters to encrypt the credentials it stores. It is passed in from `compose.override.yml`, which `init.sh` generates on first run; Compose picks that file up automatically, so no `-f` flag is needed.

`compose.override.yml` is a per-host secret and is not committed (delete it and Arcane can no longer decrypt the credentials it has saved). If Arcane is started without it, it restart-loops with `ENCRYPTION_KEY passphrase must be at least 32 characters in production` — check `docker compose logs arcane`.

The same file is also the place to add your own settings without editing `compose.yml`.

If you are upgrading from the Portainer-bundled version, `init.sh` (`docker compose up -d --remove-orphans`) cleans up the old container. Remove the volume too if you don't need its data:

```sh
docker volume rm genkan_portainer-data
```
