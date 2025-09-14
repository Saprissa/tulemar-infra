#!/bin/bash
set -e

echo "🗂️  Starting media separation and migration..."

# Create backup timestamp
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/root/backups/media_migration_$DATE"

echo "📦 Creating backup directory: $BACKUP_DIR"
mkdir -p $BACKUP_DIR

# Step 1: Create Docker volumes for media
echo "📁 Creating Docker volumes for media files..."
docker volume create grocery_media || echo "Volume grocery_media already exists"
docker volume create vipsite_media || echo "Volume vipsite_media already exists"

# Step 2: Backup current media directories
echo "💾 Backing up current media directories..."
cp -r ~/grocery_order/media $BACKUP_DIR/grocery_media_original
if [ -d ~/grocery_order/vip-microsite/media ]; then
    cp -r ~/grocery_order/vip-microsite/media $BACKUP_DIR/vip_media_original
fi

# Step 3: Identify VIP files in grocery media (using VIP-specific patterns)
echo "🔍 Identifying VIP files in grocery media directory..."
cd ~/grocery_order/media

# Create list of VIP files (based on your patterns observed)
find . -name "*vip*" -o -name "*guide*" -o -name "*tulemar_vip*" -o -name "casa-del-mar*" > $BACKUP_DIR/vip_files_in_grocery.txt

echo "📋 Found $(wc -l < $BACKUP_DIR/vip_files_in_grocery.txt) VIP files in grocery media"
cat $BACKUP_DIR/vip_files_in_grocery.txt

# Step 4: Copy grocery media (excluding VIP files) to grocery_media volume
echo "📂 Migrating grocery media files to Docker volume..."

# Mount grocery_media volume to temporary container and copy files
docker run --rm -v grocery_media:/target -v ~/grocery_order/media:/source alpine sh -c "
    echo 'Copying grocery media files...'
    # Copy all files first
    cp -r /source/* /target/ 2>/dev/null || true
    # Remove VIP files from grocery volume
    while IFS= read -r file; do
        if [ -f \"/target/\$file\" ]; then
            echo \"Removing VIP file from grocery: \$file\"
            rm -f \"/target/\$file\"
        fi
    done < /dev/null
    echo 'Grocery media migration complete'
    du -sh /target/*
"

# Step 5: Copy VIP media files to vipsite_media volume
echo "📂 Migrating VIP media files to Docker volume..."

# First copy from grocery_order/media (VIP files that were mixed in)
if [ -s $BACKUP_DIR/vip_files_in_grocery.txt ]; then
    docker run --rm -v vipsite_media:/target -v ~/grocery_order/media:/source alpine sh -c "
        echo 'Copying VIP files from grocery media...'
        while IFS= read -r file; do
            if [ -f \"/source/\$file\" ]; then
                echo \"Copying VIP file: \$file\"
                mkdir -p \"/target/\$(dirname \"\$file\")\"
                cp \"/source/\$file\" \"/target/\$file\"
            fi
        done < /dev/stdin
        echo 'VIP media from grocery copied'
    " < $BACKUP_DIR/vip_files_in_grocery.txt
fi

# Then copy from vip-microsite/media if it exists
if [ -d ~/grocery_order/vip-microsite/media ]; then
    docker run --rm -v vipsite_media:/target -v ~/grocery_order/vip-microsite/media:/vipsource alpine sh -c "
        echo 'Copying VIP-specific media files...'
        cp -r /vipsource/* /target/ 2>/dev/null || true
        echo 'VIP media migration complete'
        du -sh /target/*
    "
fi

# Step 6: Remove VIP files from grocery media directory (cleanup)
echo "🧹 Cleaning up VIP files from grocery media directory..."
cd ~/grocery_order/media
while IFS= read -r file; do
    if [ -f "$file" ]; then
        echo "Removing VIP file from grocery: $file"
        rm -f "$file"
    fi
done < $BACKUP_DIR/vip_files_in_grocery.txt

# Step 7: Verify migration
echo "🔍 Verifying media migration..."
echo "Grocery media volume contents:"
docker run --rm -v grocery_media:/data alpine du -sh /data/* | head -10

echo "VIP media volume contents:"
docker run --rm -v vipsite_media:/data alpine du -sh /data/* | head -10

echo "📊 Migration summary:"
echo "Backup location: $BACKUP_DIR"
echo "Grocery media volume: grocery_media"
echo "VIP media volume: vipsite_media"
echo "VIP files identified: $(wc -l < $BACKUP_DIR/vip_files_in_grocery.txt)"

echo "✅ Media migration completed successfully!"
echo "⚠️  Backups preserved at: $BACKUP_DIR"