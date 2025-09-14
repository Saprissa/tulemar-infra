# Tulemar Infrastructure

Multi-application Docker Compose infrastructure for Tulemar's web services using DigitalOcean Container Registry.

## Architecture

- **grocery_order**: Main grocery ordering application
- **vip-microsite**: VIP guest guide and amenity booking
- **nginx**: Reverse proxy and static file serving
- **postgresql**: Separate databases for each application
- **redis**: Separate Redis instances for each application

## Services

### Applications
- `shop.tulemar.vip` → grocery-web:8000
- `guide.tulemar.vip` → vipsite-web:8001

### Infrastructure
- nginx: Load balancer and static file server
- postgresql: Two separate database instances
- redis: Two separate cache instances (different ports)

## Quick Start

### Prerequisites
- Docker and Docker Compose
- DigitalOcean CLI (`doctl`)
- Access to TVHR DigitalOcean account

### Local Development

```bash
# Login to DOCR
doctl auth switch --context tvhr
doctl registry login

# Start services
export REGISTRY=registry.digitalocean.com/tulemar
export GROCERY_TAG=2025-09-14.1
export VIP_TAG=2025-09-14.1

docker compose -f docker-compose.yml -f compose.grocery.yml -f compose.vip.yml -f compose.local.yml up -d
```

### Production Deployment

```bash
# Login to DOCR
doctl registry login

# Deploy
./scripts/deploy.sh
```

## Configuration

- `.env`: Image tags and registry configuration
- `env/grocery.env.sample`: Sample environment for grocery app
- `env/vipsite.env.sample`: Sample environment for VIP app
- Production secrets stored in `/etc/tulemar/env/`

## Scripts

- `scripts/deploy.sh`: Full deployment with health checks
- `scripts/backup.sh`: Database backup utility
- `scripts/healthcheck.sh`: Service health verification

## Volume Management

**CRITICAL**: Production volumes are external and must exist before deployment:
- `grocery_order_pgdata`: Grocery database
- `grocery_order_vipsite_pgdata`: VIP database
- `certbot_certs`: SSL certificates
- `certbot_webroot`: Certbot validation

## Registry Information

- **Registry**: `registry.digitalocean.com/tulemar`
- **Repositories**: `grocery_order`, `vip-microsite`
- **Subscription**: Basic tier (5GB, 1TB transfer)

## Migration from Nested Structure

This infrastructure replaces the previous nested repository anti-pattern with clean separation:

```
OLD: ~/grocery_order/vip-microsite/
NEW: ~/tulemar-apps/grocery_order/
     ~/tulemar-apps/vip-microsite/
     ~/tulemar-apps/infra/
```

## Monitoring

- Health checks on all services
- Resource limits configured
- Logging with rotation
- DOCR usage tracking via `doctl registry get`