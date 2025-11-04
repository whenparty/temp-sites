# Temp Sites

Disposable web applications for `*.temp.nii.au`. Projects live in this repo, build into container images, and deploy behind the shared Traefik router that sits behind the public Nginx proxy.

```
Internet → Cloudflare → Nginx (TLS) → Traefik (HTTP) → Project containers
```

## Architecture at a Glance

- **Nginx (infra repo)** – Terminates TLS with the Cloudflare Origin certificate and forwards every `*.temp.nii.au` request to Traefik on `127.0.0.1:8000`. The config lives in `nginx-config/`.
- **Traefik (infra repo)** – Runs once on the VPS (`docker compose -f lab/infra/tempsites-router/compose.yml up -d`). It discovers containers via Docker labels and routes purely by `Host`.
- **Temp projects (this repo)** – Each project folder contains a `compose.yml` and, optionally, a `Dockerfile`. Containers join the shared external network `tempsites` so Traefik can see them.
- **GitHub Actions** – On pushes to `main`, the workflow detects changed projects, builds/pushes images to GHCR, then SSHes into the VPS to `git pull` this repo and `docker compose up -d --remove-orphans` the affected project(s).

## Repository Layout

```
nginx-config/
  temp-sites.conf             # Wildcard server block (copy to infra repo)
  cloudflare_real_ip.conf     # Cloudflare IP allow list (included from the server block)
projects/
  <project>/
    Dockerfile                # Optional – build instructions for GHCR
    compose.yml               # Required – service definition + Traefik labels
    README.md                 # Project specific notes
    ...project assets...
```

## First-Time VPS Preparation

1. Install the Cloudflare Origin certificate as described in `nginx-config/README.md` and load the wildcard server block in your infra repo.
2. Enable the automated Cloudflare IP updater (`scripts/update-cloudflare-real-ip` in `whenparty/infra`) so `/etc/nginx/conf.d/cloudflare_real_ip.conf` stays current (see `nginx-config/README.md` for details).
3. Create the shared Docker network (once):
   ```bash
   docker network create tempsites
   ```
4. Clone the repo where you want deployments to land (matches the GitHub Action default: `/opt/services/whenparty/tempsites`):
   ```bash
   git clone git@github.com:whenparty/temp-sites.git /opt/services/whenparty/tempsites
   ```
5. Start the Traefik router from `lab/infra/tempsites-router/compose.yml`.

Ensure the VPS user that runs deployments can pull from GitHub using the SSH key referenced in the GitHub Action secrets.

## Deployment Pipeline

1. `detect-changes` job computes which `projects/*` directories changed in the push.
2. For each changed project, `build-and-deploy`:
   - Builds a GHCR image if a `Dockerfile` exists (tags: `latest` + `sha-<commit>`).
   - Attempts to set the container package visibility to public (falls back to manual if the API call is not permitted).
   - SSHes into the VPS, fetches this repo, checks out the commit, ensures the `tempsites` network exists, and runs `docker compose up -d --remove-orphans` inside the project directory. If an image was built, the deployment uses the `sha-<commit>` tag so the rollout is deterministic.
   - Prunes dangling images after the update.

## Adding a New Project

1. Create a folder under `projects/<name>/`.
2. Add a `Dockerfile` (optional but recommended). Example static site:
   ```dockerfile
   FROM nginx:alpine
   COPY site/ /usr/share/nginx/html/
   HEALTHCHECK CMD wget --quiet --tries=1 --spider http://localhost/ || exit 1
   ```
3. Add `compose.yml` with Traefik labels:
   ```yaml
   name: tempsite-my-site

   services:
     app:
       image: ${IMAGE:-ghcr.io/whenparty/temp-my-site:latest}
       restart: unless-stopped
       labels:
         - 'traefik.enable=true'
         - 'traefik.http.routers.my-site.rule=Host(`my-site.temp.nii.au`)'
         - 'traefik.http.routers.my-site.entrypoints=web'
         - 'traefik.http.services.my-site.loadbalancer.server.port=80'
       networks:
         - tempsites

   networks:
     tempsites:
       external: true
   ```
4. Commit, push to `main`, and wait for the workflow. Traefik routes traffic as soon as the container is healthy.

## Local Development

Each project is self-contained. To build/test locally:

```bash
cd projects/my-site
docker build -t my-site:test .
docker run --rm -p 8080:80 my-site:test
# or, to use compose:
IMAGE=my-site:test docker compose up -d
```

Stop or clean resources with:

```bash
docker compose down -v    # inside the project directory
```

## Maintenance

- **Remove a temp site**: delete the project folder (and optionally run `docker compose down -v` on the VPS). The next deployment removes the container because `--remove-orphans` is enabled.
- **Cloudflare real IP allow list**: the `/etc/nginx/conf.d/cloudflare_real_ip.conf` include is generated on the VPS by the `whenparty/infra` scheduled task (`scripts/update-cloudflare-real-ip`). Run that script manually if you need an immediate refresh.
- **Secrets**: Never bake secrets into images. Inject them on the VPS using compose `env_file` entries or environment variables that live outside the repo.
- **Traefik tweaks**: Change routing behaviour in the project `compose.yml` via additional labels (middlewares, custom services, etc.).

## Troubleshooting

- Check GitHub Actions logs for build or deployment errors.
- On the VPS, inspect container status with `docker compose ps` inside the project directory, or view logs with `docker compose logs -f`.
- Traefik dashboard and logs live with the infra repository; confirm the container carries the expected labels if routing fails.
