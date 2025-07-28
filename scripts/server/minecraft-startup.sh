#!/bin/bash
# /usr/local/bin/minecraft-startup.sh

# Check if we're resuming from hibernation
if dmesg | grep -q "hibernation image"; then
    echo "$(date): Resumed from hibernation"
    
    # Give network time to stabilize
    sleep 5
    
    # Always start Minecraft fresh after hibernation
    if [ -f /srv/minecraft/unplanned-shutdown ]; then
        echo "$(date): Detected previous unplanned shutdown"
        # Could implement world verification here
        rm /srv/minecraft/unplanned-shutdown
    fi
    
    # Start Minecraft
    systemctl start minecraft
    
    # Notify Fargate proxy that server is ready
    curl -X POST http://your-fargate-proxy:8080/server-ready || true
fi
