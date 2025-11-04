# Nginx Configuration for Temp Sites

This directory contains the nginx configuration that should be deployed to the infrastructure repository.

## Deployment Instructions

### One-Time Setup

1. **Generate Cloudflare Origin Certificate** (if not already done):
   - Go to Cloudflare Dashboard → SSL/TLS → Origin Server
   - Click "Create Certificate"
   - Add hostnames: `*.temp.nii.au`, `temp.nii.au`
   - Choose 15 years validity
   - Copy the certificate and private key

2. **Install certificate on VPS**:
   ```bash
   ssh whenpartydeploy@your-vps

   # Create certificate files
   sudo nano /opt/services/whenparty/infra/nginx/certs/temp.nii.au.crt
   # Paste the certificate

   sudo nano /opt/services/whenparty/infra/nginx/certs/temp.nii.au.key
   # Paste the private key

   # Set permissions
   sudo chmod 644 /opt/services/whenparty/infra/nginx/certs/temp.nii.au.crt
   sudo chmod 600 /opt/services/whenparty/infra/nginx/certs/temp.nii.au.key
   sudo chown -R whenpartydeploy:whenpartydeploy /opt/services/whenparty/infra/nginx/certs/
   ```

3. **Copy nginx config to infra repository** (the Cloudflare allowlist is generated automatically; see below):

   **Option A: Manual copy**
   ```bash
   # On your local machine
   cp nginx-config/temp-sites.conf /path/to/whenparty-infra/nginx/conf.d/

   # Push to infra repo
   cd /path/to/whenparty-infra
   git add nginx/conf.d/temp-sites.conf
   git commit -m "Add temp sites wildcard nginx config"
   git push origin main
   ```

   **Option B: SSH to VPS**
   ```bash
   ssh whenpartydeploy@your-vps

   # Copy the config directly
   sudo nano /opt/services/whenparty/infra/nginx/conf.d/temp-sites.conf
   # Paste the contents of temp-sites.conf

   # Test and reload nginx
   docker exec nginx nginx -t
   docker exec nginx nginx -s reload
   ```

4. **Verify deployment**:
   ```bash
   # Test nginx configuration
   docker exec nginx nginx -t

   # Reload nginx
   docker exec nginx nginx -s reload

   # Test that nginx is forwarding to Traefik
   curl -H "Host: test.temp.nii.au" http://localhost:8000
   ```

### Cloudflare DNS Setup

Ensure your Cloudflare DNS has the wildcard record:

```
Type    Name     Content           Proxy Status
A       temp     YOUR_VPS_IP       Proxied (☁️)
A       *.temp   YOUR_VPS_IP       Proxied (☁️)
```

Or if Cloudflare doesn't support wildcard subdomain proxying for your plan, use DNS-only mode.

### Cloudflare SSL/TLS Settings

1. Go to Cloudflare Dashboard → SSL/TLS
2. Set mode to **"Full (strict)"**
3. Enable "Always Use HTTPS"

## Configuration Details

### What This Config Does

1. **HTTP → HTTPS Redirect**: All HTTP requests to `*.temp.nii.au` are redirected to HTTPS
2. **TLS Termination**: Nginx terminates TLS using the Cloudflare Origin Certificate
3. **Proxy to Traefik**: All HTTPS requests are proxied to Traefik on `localhost:8000`
4. **WebSocket Support**: Includes upgrade headers for WebSocket connections
5. **Security Headers**: Adds security headers (X-Frame-Options, etc.)
6. **Cloudflare Real IP**: Extracts the real client IP from Cloudflare headers

### Certificate Paths

The config expects certificates at:
- Certificate: `/etc/nginx/certs/temp.nii.au.crt`
- Private Key: `/etc/nginx/certs/temp.nii.au.key`

These paths are inside the nginx container. They map to:
- Host: `/opt/services/whenparty/infra/nginx/certs/temp.nii.au.crt`
- Host: `/opt/services/whenparty/infra/nginx/certs/temp.nii.au.key`

## Troubleshooting

### Certificate Error

If you see "SSL certificate not found":
```bash
# Check certificate files exist
ls -la /opt/services/whenparty/infra/nginx/certs/temp.nii.au.*

# Check permissions
ls -la /opt/services/whenparty/infra/nginx/certs/

# Verify certificate content
openssl x509 -in /opt/services/whenparty/infra/nginx/certs/temp.nii.au.crt -text -noout
```

### Nginx Won't Reload

```bash
# Test configuration
docker exec nginx nginx -t

# Check logs
docker logs nginx

# Restart nginx if needed
cd /opt/services/whenparty/infra
docker compose restart nginx
```

### Traefik Connection Error

```bash
# Verify Traefik is running
docker ps | grep traefik-tempsites

# Test Traefik directly
curl -H "Host: test.temp.nii.au" http://localhost:8000

# Check Traefik logs
docker logs traefik-tempsites
```

### Automated Cloudflare IP Updates

The file included by `temp-sites.conf` (`/etc/nginx/conf.d/cloudflare_real_ip.conf`) is generated on the VPS by the `whenparty/infra` automation. Add the `update-cloudflare-real-ip` script and timer in that repo so the list refreshes daily (or faster if preferred). Each run should:

1. Pull `https://www.cloudflare.com/ips-v4` and `https://www.cloudflare.com/ips-v6`.
2. Write the combined allowlist to `/opt/services/whenparty/infra/nginx/conf.d/cloudflare_real_ip.conf` with the appropriate `set_real_ip_from` directives and metadata comments.
3. Validate the nginx configuration (`docker compose exec nginx nginx -t`) and reload (`docker compose exec nginx nginx -s reload`) if the file changed.

Run the script manually after wiring it up to ensure nginx reloads cleanly. No manual editing of `cloudflare_real_ip.conf` in this repo is required once the automation is in place.

## Updating the Config

If you need to update the nginx config:

1. Edit `nginx-config/temp-sites.conf` in this repo
2. Copy to infra repo (see "Copy nginx config" above)
3. Test and reload:
   ```bash
   docker exec nginx nginx -t
   docker exec nginx nginx -s reload
   ```

## Security Notes

- The certificate is valid for 15 years - no renewal needed
- Only Cloudflare can reach your VPS (configure firewall to allow only Cloudflare IPs)
- All temp site traffic goes through HTTPS
- Containers are isolated on the `tempsites` network
- No internal communication between temp site containers
