#!/bin/bash
# /usr/local/bin/minecraft-hibernate.sh

# Wait to ensure Minecraft fully stopped
sleep 10

# Check if this was a planned shutdown (not crash or spot interruption)
if [ -f /tmp/minecraft-planned-shutdown ]; then
    rm /tmp/minecraft-planned-shutdown
    echo "$(date): Initiating hibernation after planned Minecraft shutdown"
    systemctl hibernate
else
    echo "$(date): Minecraft stopped unexpectedly, not hibernating"
fi
