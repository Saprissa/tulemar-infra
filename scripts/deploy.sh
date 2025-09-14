#!/bin/bash
set -e

echo "🚀 Starting SAFE deployment with DigitalOcean Container Registry..."
echo "🛡️  This deployment preserves all existing databases and media files"

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

# Verify critical volumes exist before deployment
echo "🔍 Verifying critical volumes exist..."
if ! docker volume inspect grocery_order_pgdata >/dev/null 2>&1; then
    echo "❌ CRITICAL: grocery_order_pgdata volume not found!"
    echo "   This volume contains 6 weeks of grocery data and MUST exist"
    exit 1
fi

if ! docker volume inspect grocery_order_vipsite_pgdata >/dev/null 2>&1; then
    echo "❌ CRITICAL: grocery_order_vipsite_pgdata volume not found!"
    echo "   This volume contains recent VIP concierge edits and MUST exist"
    exit 1
fi

echo "✅ Critical database volumes verified"

# Start/update services (SAFE - uses external volumes)
echo "🔄 Starting services with preserved data..."
echo "   📊 Using existing grocery_order_pgdata (preserves 6 weeks of data)"
echo "   📊 Using existing grocery_order_vipsite_pgdata (preserves concierge edits)"
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