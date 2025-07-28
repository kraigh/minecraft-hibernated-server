#!/bin/bash
# /usr/local/bin/minecraft-idle-check.sh

# Source the minecraft-server config
source /etc/conf.d/minecraft

# Check if server is running
if ! systemctl is-active --quiet minecraft; then
    exit 0
fi

# Get player count using minecraftd
PLAYER_COUNT=$(minecraftd command list | grep -oP 'There are \K[0-9]+' || echo "0")

# Check last activity
LAST_ACTIVITY_FILE="/tmp/minecraft-last-activity"
CURRENT_TIME=$(date +%s)

if [ "$PLAYER_COUNT" -gt 0 ]; then
    # Players online, update activity time
    echo "$CURRENT_TIME" > "$LAST_ACTIVITY_FILE"
else
    # No players, check how long since last activity
    if [ -f "$LAST_ACTIVITY_FILE" ]; then
        LAST_ACTIVITY=$(cat "$LAST_ACTIVITY_FILE")
        IDLE_TIME=$((CURRENT_TIME - LAST_ACTIVITY))
        
        if [ "$IDLE_TIME" -gt "$IDLE_IF_TIME" ]; then
            echo "Server idle for $IDLE_TIME seconds, initiating shutdown"
            
            # Mark as planned shutdown
            touch /tmp/minecraft-planned-shutdown
            
            # Save and stop server
            minecraftd command say "Server idle - shutting down in 30 seconds"
            sleep 20
            minecraftd command say "Shutting down in 10 seconds..."
            sleep 10
            minecraftd command save-all
            sleep 5
            systemctl stop minecraft
        fi
    else
        # First check with no players
        echo "$CURRENT_TIME" > "$LAST_ACTIVITY_FILE"
    fi
fi
