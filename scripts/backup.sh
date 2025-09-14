#!/bin/bash
set -e

BACKUP_DIR="/root/backups"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

echo "📦 Starting database backups..."

# Backup databases with correct compose files
docker compose -f docker-compose.yml -f compose.grocery.yml exec -T grocery-db \
    pg_dump -U grocery_user grocery_order_db > $BACKUP_DIR/grocery_$DATE.sql

docker compose -f docker-compose.yml -f compose.vip.yml exec -T vipsite-db \
    pg_dump -U vipsite_user vipsite_guide_db > $BACKUP_DIR/vipsite_$DATE.sql

# Compress
gzip $BACKUP_DIR/grocery_$DATE.sql
gzip $BACKUP_DIR/vipsite_$DATE.sql

# Rotate old backups (keep 30 days)
find $BACKUP_DIR -name "*.sql.gz" -mtime +30 -delete

echo "✅ Backup complete:"
echo "   $BACKUP_DIR/grocery_$DATE.sql.gz"
echo "   $BACKUP_DIR/vipsite_$DATE.sql.gz"

# Optional: sync to DO Spaces (S3-compatible)
# doctl compute cdn flush your-space-name
# s3cmd sync $BACKUP_DIR s3://your-space-name/database-backups/