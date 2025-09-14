#!/bin/bash
set -e

echo "🚀 Starting deployment with DigitalOcean Container Registry..."

# Ensure we're logged into DOCR
echo "🔐 Logging into DigitalOcean Container Registry..."
doctl registry login

# Load environment with image tags
source .env

# Export for docker compose
export REGISTRY GROCERY_TAG VIP_TAG

echo "📦 Deploying from DOCR:"
echo "  Registry: ${REGISTRY}"
echo "  Grocery: ${GROCERY_TAG}"
echo "  VIP: ${VIP_TAG}"

# Pull latest images from DOCR
echo "⬇️ Pulling images from DOCR..."
docker compose -f docker-compose.yml -f compose.grocery.yml -f compose.vip.yml pull

# Start/update services
echo "🔄 Starting services..."
docker compose -f docker-compose.yml -f compose.grocery.yml -f compose.vip.yml up -d

# Wait for services to be healthy
echo "⏳ Waiting for services to be healthy..."
sleep 15

# Run migrations (after services are up)
echo "🔧 Running database migrations..."
docker compose -f docker-compose.yml -f compose.grocery.yml exec -T grocery-web python manage.py migrate --noinput
docker compose -f docker-compose.yml -f compose.vip.yml exec -T vipsite-web python manage.py migrate --noinput

# Collect static files
echo "📁 Collecting static files..."
docker compose -f docker-compose.yml -f compose.grocery.yml exec -T grocery-web python manage.py collectstatic --noinput
docker compose -f docker-compose.yml -f compose.vip.yml exec -T vipsite-web python manage.py collectstatic --noinput

# Health check
echo "🏥 Running health checks..."
./scripts/healthcheck.sh

# Clean up old images
echo "🧹 Cleaning up old images..."
docker image prune -f

echo "✅ Deployment complete!"
echo "   Grocery: https://shop.tulemar.vip"
echo "   VIP Guide: https://guide.tulemar.vip"