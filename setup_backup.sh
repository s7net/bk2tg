#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}📦 Telegram Backup Setup Script${NC}"
echo "This script will set up automated backups for your files and folders."

# Check and install dependencies
echo -e "\n${YELLOW}Checking dependencies...${NC}"
dependencies=("zip" "curl" "jq" "sudo")
missing_deps=()

for dep in "${dependencies[@]}"; do
    if ! command -v "$dep" &> /dev/null; then
        missing_deps+=("$dep")
    fi
done

if [ ${#missing_deps[@]} -ne 0 ]; then
    echo -e "${YELLOW}Installing missing dependencies: ${missing_deps[*]}${NC}"
    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y "${missing_deps[@]}"
    elif command -v yum &> /dev/null; then
        sudo yum install -y "${missing_deps[@]}"
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y "${missing_deps[@]}"
    else
        echo -e "${RED}Error: Could not install dependencies. Please install them manually: ${missing_deps[*]}${NC}"
        exit 1
    fi
fi

# Get user input
read -p "Enter your Telegram Bot Token: " BOT_TOKEN
read -p "Enter your Chat ID: " CHAT_ID
read -p "Enter your Backup ID (numeric): " BACKUP_ID
read -p "Enter Message Thread ID (use -1 for no thread): " MESSAGE_THREAD_ID
read -p "Enter backup interval in minutes (e.g., 10): " BACKUP_INTERVAL

# Ask for backup path
echo -e "\n${YELLOW}Backup Path Configuration${NC}"
echo "Enter the full path of the folder you want to backup:"
read -p "> " BACKUP_PATH

# Validate backup path
if [ ! -d "$BACKUP_PATH" ]; then
    echo -e "${RED}Error: Backup path does not exist: $BACKUP_PATH${NC}"
    exit 1
fi

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
BACKUP_PATH="__BACKUP_PATH__"  # Path to backup

# Variables
ip=$(hostname -I | awk '{print $1}')
timestamp=$(TZ='Asia/Tehran' date +%m%d-%H%M)
CAPTION="
📦 <b>From </b><code>${ip}</code>
🆔 <b>Backup ID:</b> <code>${BACKUP_ID}</code>"
backup_name="${BACKUP_ID}_${timestamp}_backup.zip"
base_name="${BACKUP_ID}_${timestamp}_backup."

# Clean up old backup files
rm -rf *"_backup."* 2>/dev/null || true

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

# Function to check if a file is readable
is_readable() {
    local file="$1"
    [ -r "$file" ] || sudo -n test -r "$file" 2>/dev/null
}

# Copy files from backup path
echo "Copying files from $BACKUP_PATH..."
if [ -d "$BACKUP_PATH" ]; then
    # Create a list of files to backup
    find "$BACKUP_PATH" -type f -not -path "*/backingFsBlockDev/*" | while read -r file; do
        if is_readable "$file"; then
            rel_path="${file#$BACKUP_PATH/}"
            target_dir="$TEMP_DIR/$(dirname "$rel_path")"
            mkdir -p "$target_dir"
            sudo cp "$file" "$target_dir/" 2>/dev/null || true
        fi
    done
else
    echo "Error: Backup path does not exist: $BACKUP_PATH"
    exit 1
fi

# Check if we have any files to backup
if [ -z "$(ls -A "$TEMP_DIR")" ]; then
    echo "Error: No readable files found in backup path"
    exit 1
fi

# Compress files
echo "Creating backup archive..."
cd "$TEMP_DIR"
if ! zip -9 -r "$backup_name" . -x "*/backingFsBlockDev/*" "*/\.*" 2>/dev/null; then
    message="Failed to compress files. Please check the server."
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
rm -rf *"_backup."* 2>/dev/null || true
EOL

# Replace placeholders with actual values
sed -i "s/__BOT_TOKEN__/$BOT_TOKEN/" backup.sh
sed -i "s/__CHAT_ID__/$CHAT_ID/" backup.sh
sed -i "s/__BACKUP_ID__/$BACKUP_ID/" backup.sh
sed -i "s/__MESSAGE_THREAD_ID__/$MESSAGE_THREAD_ID/" backup.sh
sed -i "s|__BACKUP_PATH__|$BACKUP_PATH|" backup.sh

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
echo -e "${GREEN}[INFO] Backup path: $BACKUP_PATH${NC}"
echo -e "${GREEN}[INFO] Cron job: Every $BACKUP_INTERVAL minutes${NC}"
echo -e "${GREEN}[SUCCESS] First backup created and sent.${NC}"
echo -e "${GREEN}[SUCCESS] Thank you for using the backup script. Enjoy automated backups!${NC}" 
