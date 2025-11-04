# DTM Cleaning Web - Temp Site

Example temporary site hosted at `dtm-cleaning-web.temp.nii.au`

## Stack

- **Web Server**: Nginx (Alpine)
- **Content**: Static HTML in `site/` directory
- **Routing**: Traefik via Docker labels

## Local Development

```bash
cd projects/dtm-cleaning-web

# Build a local image for iteration
docker build -t dtm-cleaning-web:dev .

# Run through compose (uses the IMAGE env var if provided)
IMAGE=dtm-cleaning-web:dev docker compose up -d

# Follow logs
docker compose logs -f

# Stop and remove resources
docker compose down -v
```

## Deployment

Automatically deployed via GitHub Actions when changes are pushed to `projects/dtm-cleaning-web/`

## Accessing the Site

- Production: https://dtm-cleaning-web.temp.nii.au
- Local (via Traefik): Configure local DNS or hosts file to point to localhost

## File Structure

```
dtm-cleaning-web/
├── Dockerfile       # Builds the GHCR image
├── compose.yml      # Service definition + Traefik labels
├── site/            # Static website files
│   └── index.html
└── README.md        # This file
```
