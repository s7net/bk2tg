# Telegram Backup System

A simple and efficient backup system that automatically sends your files and folders to Telegram.

## Features

- 🔄 Automated file and folder backups
- 📱 Telegram integration with thread support
- ⏱️ Configurable backup intervals
- 🔒 Secure file handling
- 🧹 Automatic cleanup
- 📊 Detailed backup status messages

## Prerequisites

- Linux server
- Telegram Bot Token (get from [@BotFather](https://t.me/BotFather))
- Telegram Chat ID (group or channel)
- Basic knowledge of Linux commands

## Quick Start

### One-line Installation
```bash
bash <(curl -Ls https://raw.githubusercontent.com/s7net/bk2tg/refs/heads/main/setup_backup.sh)
```

### Manual Installation
1. Download the setup script:
```bash
wget https://raw.githubusercontent.com/yourusername/yourrepo/main/setup_backup.sh
chmod +x setup_backup.sh
```

2. Run the setup script:
```bash
./setup_backup.sh
```

3. Follow the interactive prompts to configure:
   - Telegram Bot Token
   - Chat ID
   - Backup ID
   - Message Thread ID
   - Backup interval
   - Backup folder path

## Configuration Details

### Telegram Bot Token
- Get from [@BotFather](https://t.me/BotFather)
- Format: `123456789:ABCdefGHIjklMNOpqrsTUVwxyz`

### Chat ID
- For groups: Usually starts with `-100`
- For channels: Usually starts with `-100`
- For private chats: Your user ID

### Backup ID
- Unique identifier for this backup
- Used in backup file names and messages
- Example: `1`, `2`, `backup1`, etc.

### Message Thread ID
- `-1` for no thread (main chat)
- Specific thread ID for threaded messages
- Example: `36` for a specific thread

### Backup Interval
- Time between backups in minutes
- Example: `10` for backups every 10 minutes
- Minimum: `1` minute
- Recommended: `10` to `60` minutes

### Backup Path
- Full path to the folder you want to backup
- Example: `/home/user/documents`
- Must be an existing directory
- Will backup all contents of the specified folder

## Backup Process

1. **Preparation**
   - Creates temporary directory
   - Cleans up old backup files

2. **Backup Creation**
   - Copies files from specified path
   - Creates zip archive
   - Handles permissions properly

3. **Sending**
   - Sends to Telegram
   - Includes status message
   - Supports threads

4. **Cleanup**
   - Removes temporary files
   - Maintains clean system

## File Structure

```
/root/
├── setup_backup.sh    # Setup script
├── backup.sh         # Backup script (created by setup)
└── *_backup.zip      # Backup files
```

## Cron Job

The setup script automatically creates a cron job:
```bash
*/<interval> * * * * /root/backup.sh
```

## Backup Message Format

```
📦 From <server_ip>
🆔 Backup ID: <backup_id>
```

## Troubleshooting

1. **Permission Issues**
   - Ensure script is executable: `chmod +x setup_backup.sh`
   - Run as root or with sudo
   - Check folder permissions

2. **Telegram Issues**
   - Verify bot token is correct
   - Check bot is added to group/channel
   - Ensure bot has permission to send messages

3. **Backup Issues**
   - Check if backup path exists
   - Verify folder permissions
   - Check disk space

## Security Notes

- Keep your bot token secure
- Don't share your backup script
- Regularly update your bot token
- Monitor backup success
- Be careful with sensitive data in backups

## Support

For issues and support:
1. Check the troubleshooting section
2. Verify all prerequisites
3. Check Telegram bot permissions
4. Review backup logs

## License

This project is open source and available under the MIT License.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. 
