#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}📦 Telegram Backup Setup Script${NC}"
echo "This script will set up automated backups for your Docker volumes."

# Get user input
read -p "Enter your Telegram Bot Token: " BOT_TOKEN
read -p "Enter your Chat ID: " CHAT_ID
read -p "Enter your Backup ID (numeric): " BACKUP_ID
read -p "Enter Message Thread ID (use -1 for no thread): " MESSAGE_THREAD_ID
read -p "Enter backup interval in minutes (e.g., 10): " BACKUP_INTERVAL

# Validate inputs
if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ] || [ -z "$BACKUP_ID" ] || [ -z "$MESSAGE_THREAD_ID" ] || [ -z "$BACKUP_INTERVAL" ]; then
    echo -e "${RED}Error: All fields are required!${NC}"
    exit 1
fi

# Create backup script with the provided configuration
echo -e "\n${YELLOW}Creating backup script...${NC}"
cat > backup.sh << 'EOL'
#!/bin/bash
set -e 

# Configuration
BOT_TOKEN="__BOT_TOKEN__"
CHAT_ID="__CHAT_ID__"
BACKUP_ID="__BACKUP_ID__"  # Unique identifier for this backup
MESSAGE_THREAD_ID="__MESSAGE_THREAD_ID__"  # -1 for no thread, or specific thread ID

# Variables
ip=$(hostname -I | awk '{print $1}')
timestamp=$(TZ='Asia/Tehran' date +%m%d-%H%M)
CAPTION="
📦 <b>From </b><code>${ip}</code>
🆔 <b>Backup ID:</b> <code>${BACKUP_ID}</code>"
backup_name="${BACKUP_ID}_${timestamp}_session1_backuper.zip"
base_name="${BACKUP_ID}_${timestamp}_session1_backuper."

# Clean up old backup files (only specific backup files)
rm -rf *"_session1_backuper."* 2>/dev/null || true

# Create a temporary directory for the backup
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Function to copy files with proper permissions
copy_files() {
    local src="$1"
    local dest="$2"
    
    # Create destination directory
    mkdir -p "$dest"
    
    # Copy files with sudo to handle permissions
    sudo cp -r "$src"/* "$dest/" 2>/dev/null || true
}

# Copy Docker volumes to temporary directory
echo "Copying Docker volumes..."
for volume in /var/lib/docker/volumes/*; do
    if [ -d "$volume" ] && [ "$(basename "$volume")" != "backingFsBlockDev" ]; then
        volume_name=$(basename "$volume")
        echo "Copying volume: $volume_name"
        copy_files "$volume" "$TEMP_DIR/$volume_name"
    fi
done

# Compress files
echo "Creating backup archive..."
cd "$TEMP_DIR"
if ! zip -9 -r "$backup_name" .; then
    message="Failed to compress session1 files. Please check the server."
    echo "$message"
    exit 1
fi

# Move the backup file to /root
if ! mv "$backup_name" "/root/$backup_name"; then
    message="Failed to move backup file to /root"
    echo "$message"
    exit 1
fi

# Verify backup file exists
if [ ! -f "/root/$backup_name" ]; then
    message="Backup file was not created: /root/$backup_name"
    echo "$message"
    exit 1
fi

# Send backup file
echo "Sending backup file..."
if [ "$MESSAGE_THREAD_ID" != "-1" ]; then
    # Send with thread ID
    if curl -s -F "chat_id=$CHAT_ID" -F "message_thread_id=$MESSAGE_THREAD_ID" -F "document=@/root/$backup_name" -F "caption=$CAPTION" -F "parse_mode=HTML" "https://api.telegram.org/bot$BOT_TOKEN/sendDocument"; then
        echo "Backup sent successfully to thread $MESSAGE_THREAD_ID"
    else
        message="Failed to send backup file to thread. Please check the server."
        echo "$message"
        exit 1
    fi
else
    # Send without thread ID
    if curl -s -F "chat_id=$CHAT_ID" -F "document=@/root/$backup_name" -F "caption=$CAPTION" -F "parse_mode=HTML" "https://api.telegram.org/bot$BOT_TOKEN/sendDocument"; then
        echo "Backup sent successfully"
    else
        message="Failed to send backup file. Please check the server."
        echo "$message"
        exit 1
    fi
fi

# Cleanup
rm -rf *"_session1_backuper."* 2>/dev/null || true
EOL

# Replace placeholders with actual values
sed -i "s/__BOT_TOKEN__/$BOT_TOKEN/" backup.sh
sed -i "s/__CHAT_ID__/$CHAT_ID/" backup.sh
sed -i "s/__BACKUP_ID__/$BACKUP_ID/" backup.sh
sed -i "s/__MESSAGE_THREAD_ID__/$MESSAGE_THREAD_ID/" backup.sh

# Make the script executable
chmod +x backup.sh

# Set up cron job
echo -e "\n${YELLOW}Setting up cron job...${NC}"
# Remove any existing cron job for this backup
(crontab -l 2>/dev/null | grep -v "backup.sh") | crontab -
# Add new cron job
(crontab -l 2>/dev/null; echo "*/$BACKUP_INTERVAL * * * * $(pwd)/backup.sh") | crontab -

# Run first backup
echo -e "\n${YELLOW}Running first backup...${NC}"
./backup.sh

echo -e "\n${GREEN}[SUCCESS] Backup system setup complete!${NC}"
echo -e "${GREEN}[INFO] Backup script location: $(pwd)/backup.sh${NC}"
echo -e "${GREEN}[INFO] Cron job: Every $BACKUP_INTERVAL minutes${NC}"
echo -e "${GREEN}[SUCCESS] First backup created and sent.${NC}"
echo -e "${GREEN}[SUCCESS] Thank you for using the backup script. Enjoy automated backups!${NC}" 
