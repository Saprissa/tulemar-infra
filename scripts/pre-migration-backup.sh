#!/bin/bash
set -e

echo "🛡️  Starting comprehensive pre-migration backup..."

# Create backup directory with timestamp
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/root/backups/pre_migration_$DATE"
mkdir -p $BACKUP_DIR

cd ~/grocery_order

echo "📦 Backup location: $BACKUP_DIR"

# 1. Database backups (CRITICAL)
echo "💾 Backing up databases..."
docker compose exec -T db pg_dump -U grocery_user grocery_order_db > $BACKUP_DIR/grocery_database_$DATE.sql
docker compose exec -T vipsite-db pg_dump -U vipsite_user vipsite_guide_db > $BACKUP_DIR/vipsite_database_$DATE.sql

# Verify database backups
echo "✅ Database backup sizes:"
ls -lh $BACKUP_DIR/*.sql

# 2. Document current container state
echo "📋 Documenting current container state..."
docker ps > $BACKUP_DIR/containers_before_migration.txt
docker compose config > $BACKUP_DIR/compose_config_before_migration.yml
docker volume ls > $BACKUP_DIR/volumes_before_migration.txt

# 3. Document volume mappings (CRITICAL for migration)
echo "🗂️  Documenting volume mappings..."
for container in $(docker ps --format "{{.Names}}"); do
    echo "=== $container ===" >> $BACKUP_DIR/volume_mappings.txt
    docker inspect $container | grep -A20 '"Mounts"' >> $BACKUP_DIR/volume_mappings.txt
    echo "" >> $BACKUP_DIR/volume_mappings.txt
done

# 4. Media directory structure analysis
echo "📁 Analyzing media directory structure..."
find media/ -type f > $BACKUP_DIR/media_file_list.txt
du -sh media/* > $BACKUP_DIR/media_sizes.txt 2>/dev/null || echo "Some directories inaccessible" > $BACKUP_DIR/media_sizes.txt

# 5. Environment files backup
echo "⚙️  Backing up configuration..."
cp .env.production $BACKUP_DIR/grocery_env_backup.txt
cp vip-microsite/.env.production $BACKUP_DIR/vipsite_env_backup.txt
cp docker-compose.yml $BACKUP_DIR/docker_compose_backup.yml

# 6. Test database connectivity (ensure both DBs are working)
echo "🏥 Testing database connectivity..."
if docker compose exec -T db pg_isready -U grocery_user -d grocery_order_db; then
    echo "✅ Grocery database: HEALTHY" >> $BACKUP_DIR/database_health.txt
else
    echo "❌ Grocery database: UNHEALTHY" >> $BACKUP_DIR/database_health.txt
fi

if docker compose exec -T vipsite-db pg_isready -U vipsite_user -d vipsite_guide_db; then
    echo "✅ VIP database: HEALTHY" >> $BACKUP_DIR/database_health.txt
else
    echo "❌ VIP database: UNHEALTHY" >> $BACKUP_DIR/database_health.txt
fi

# 7. Create restoration instructions
cat > $BACKUP_DIR/RESTORATION_INSTRUCTIONS.md << 'EOF'
# Emergency Restoration Instructions

## If migration fails, restore using:

### 1. Stop any running containers
```bash
cd ~/tulemar-apps/infra
docker compose down
cd ~/grocery_order
docker compose up -d
```

### 2. Restore databases (if needed)
```bash
# Restore grocery database
docker compose exec -T db psql -U grocery_user -d grocery_order_db < grocery_database_TIMESTAMP.sql

# Restore VIP database
docker compose exec -T vipsite-db psql -U vipsite_user -d vipsite_guide_db < vipsite_database_TIMESTAMP.sql
```

### 3. Verify services
```bash
docker compose ps
curl -I https://shop.tulemar.vip
curl -I https://guide.tulemar.vip
```

## Critical Volume Names (DO NOT DELETE)
- grocery_order_pgdata (Grocery database - 6 weeks of data)
- grocery_order_vipsite_pgdata (VIP database - recent concierge edits)

## Contact
If issues occur, restore from this backup: $BACKUP_DIR
EOF

# 8. Compress critical backups
echo "🗜️  Compressing database backups..."
gzip $BACKUP_DIR/grocery_database_$DATE.sql
gzip $BACKUP_DIR/vipsite_database_$DATE.sql

# Final summary
echo "✅ Pre-migration backup completed successfully!"
echo ""
echo "📋 Backup Summary:"
echo "   Location: $BACKUP_DIR"
echo "   Database backups: ✅ (compressed)"
echo "   Configuration files: ✅"
echo "   Volume mappings: ✅"
echo "   Media analysis: ✅"
echo "   Restoration guide: ✅"
echo ""
echo "🔒 Critical volumes preserved:"
echo "   - grocery_order_pgdata"
echo "   - grocery_order_vipsite_pgdata"
echo ""
echo "Ready for media migration and deployment!"