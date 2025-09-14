# 🛡️ Safe Production Migration Execution Plan

## Critical Data Preservation Strategy

**ZERO DATA LOSS GUARANTEE**: All existing databases and media files will be preserved.

## Current Production State
- **Grocery Database**: `grocery_order_pgdata` (6 weeks of authoritative data)
- **VIP Database**: `grocery_order_vipsite_pgdata` (recent concierge team edits)
- **Media Files**: 578MB in `~/grocery_order/media/` (mixed grocery + VIP content)

## Migration Phases

### Phase 1: Pre-Migration Safety Backup (5 minutes)
```bash
ssh davidralston@tulemar.vip
cd ~/grocery_order
./scripts/pre-migration-backup.sh
```

**What this does:**
- ✅ Full database dumps (compressed)
- ✅ Documents all volume mappings
- ✅ Creates restoration instructions
- ✅ Tests database connectivity
- ✅ Preserves all configuration files

### Phase 2: Media Separation (10 minutes)
```bash
./scripts/migrate-media.sh
```

**What this does:**
- ✅ Creates Docker volumes: `grocery_media`, `vipsite_media`
- ✅ Separates VIP files from grocery media directory
- ✅ Migrates grocery media → `grocery_media` volume
- ✅ Migrates VIP media → `vipsite_media` volume
- ✅ Creates backups of original directories
- ⚠️ **SAFE**: All original files backed up before any changes

### Phase 3: Infrastructure Setup (3 minutes)
```bash
# Setup new infrastructure
mkdir -p ~/tulemar-apps
cd ~/tulemar-apps
git clone git@github.com:Saprissa/tulemar-infra.git infra
cd infra

# Configure production secrets (reuse existing)
sudo mkdir -p /etc/tulemar/env
sudo cp ~/grocery_order/.env.production /etc/tulemar/env/grocery.env
sudo cp ~/grocery_order/vip-microsite/.env.production /etc/tulemar/env/vipsite.env

# Set image tags
cat > .env << 'EOF'
GROCERY_TAG=2025-09-14.1
VIP_TAG=2025-09-14.1
REGISTRY=registry.digitalocean.com/tulemar
EOF
```

### Phase 4: DOCR Authentication (1 minute)
```bash
# Switch to TVHR account and login
doctl auth switch --context tvhr
doctl registry login
```

### Phase 5: Safe Cutover Deployment (5 minutes)
```bash
cd ~/grocery_order

# Stop current stack (containers only - volumes preserved)
docker compose --profile production down

# Deploy new stack (uses same volumes)
cd ~/tulemar-apps/infra
./scripts/deploy.sh
```

**What deploy.sh does:**
- ✅ Verifies critical volumes exist (exits if not found)
- ✅ Pulls images from DOCR
- ✅ Starts containers with **SAME database volumes**
- ✅ Runs migrations (safe - additive only)
- ✅ Collects static files
- ✅ Performs health checks
- ✅ Cleans up unused images

## Safety Guarantees

### Database Preservation
```yaml
# compose.grocery.yml
volumes:
  grocery_order_pgdata:
    name: grocery_order_pgdata
    external: true  # Uses existing volume - NO DATA LOSS

# compose.vip.yml
volumes:
  grocery_order_vipsite_pgdata:
    name: grocery_order_vipsite_pgdata
    external: true  # Uses existing volume - NO DATA LOSS
```

### Media Preservation
- **Before**: Bind mounts (`~/grocery_order/media/`)
- **After**: Docker volumes with proper separation
- **Backup**: Full copies preserved in `/root/backups/`

### Rollback Plan (2 minutes)
If anything goes wrong:
```bash
# Stop new stack
cd ~/tulemar-apps/infra
docker compose down

# Restore old stack
cd ~/grocery_order
docker compose up -d

# Verify services
curl -I https://shop.tulemar.vip
curl -I https://guide.tulemar.vip
```

## Post-Migration Verification

### Database Verification
```bash
# Check grocery database (should have same record counts)
docker compose exec grocery-db psql -U grocery_user -d grocery_order_db -c "SELECT COUNT(*) FROM your_main_table;"

# Check VIP database (should have recent concierge edits)
docker compose exec vipsite-db psql -U vipsite_user -d vipsite_guide_db -c "SELECT COUNT(*) FROM wagtailcore_page;"
```

### Media Verification
```bash
# Check media volumes
docker volume ls | grep media
docker run --rm -v grocery_media:/data alpine du -sh /data
docker run --rm -v vipsite_media:/data alpine du -sh /data
```

### Service Verification
```bash
# Health checks
./scripts/healthcheck.sh

# Web access
curl -I https://shop.tulemar.vip/admin/
curl -I https://guide.tulemar.vip/admin/
```

## Timeline Summary
- **Pre-backup**: 5 minutes
- **Media separation**: 10 minutes
- **Infrastructure setup**: 3 minutes
- **Authentication**: 1 minute
- **Cutover deployment**: 5 minutes
- **Total downtime**: ~5 minutes (only during cutover)
- **Total process**: ~25 minutes

## Risk Mitigation
- ✅ **Database volumes**: External references prevent deletion
- ✅ **Media files**: Full backups before any changes
- ✅ **Configuration**: All secrets preserved and reused
- ✅ **Rollback**: Simple revert to previous stack
- ✅ **Verification**: Comprehensive health and data checks

**CRITICAL SUCCESS FACTORS:**
1. Database volumes are marked `external: true` - prevents Docker from managing them
2. Media migration creates Docker volumes, doesn't delete original directories
3. Rollback plan tested and documented
4. All scripts include verification steps
5. Backups created before any destructive operations