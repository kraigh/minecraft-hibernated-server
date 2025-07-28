#!/bin/bash
# /usr/local/bin/spot-interruption-handler.sh

METADATA_URL="http://169.254.169.254/latest/meta-data/spot/instance-action"
MINECRAFT_STATUS=$(systemctl is-active minecraft)

check_spot_interruption() {
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 1 "$METADATA_URL")
    if [ "$HTTP_CODE" -eq 200 ]; then
        return 0
    fi
    return 1
}

handle_interruption() {
    echo "$(date): SPOT INTERRUPTION DETECTED!"
    
    # Notify through Cockpit logs
    logger -t spot-handler "EC2 Spot interruption detected - saving Minecraft world"
    
    if [ "$MINECRAFT_STATUS" = "active" ]; then
        # Emergency save procedure
        minecraftd command say "§c§lEMERGENCY: Server interrupted by AWS!"
        minecraftd command say "§c§lSaving world and shutting down..."
        sleep 1
        
        # Multiple saves for safety
        for i in {1..3}; do
            minecraftd command save-all flush
            sleep 3
        done
        
        # Quick backup
        minecraftd backup
        
        # Mark as unplanned shutdown
        touch /srv/minecraft/unplanned-shutdown
        
        # Stop server
        systemctl stop minecraft
        
        # Quick S3 backup if configured
        if [ -n "$S3_BACKUP_BUCKET" ]; then
            aws s3 sync /srv/minecraft/backups/ "s3://${S3_BACKUP_BUCKET}/emergency/" --storage-class GLACIER_IR
        fi
    fi
    
    # Wait for termination
    sleep 120
}

# Main loop
while true; do
    if check_spot_interruption; then
        handle_interruption
        exit 0
    fi
    sleep 2
done
