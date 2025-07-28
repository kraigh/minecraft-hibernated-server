#!/bin/bash
# setup-server.sh - Install minecraft-hibernated-server on EC2 instance

set -e

echo "Installing Minecraft Hibernated Server..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

# Detect installation context (CloudFormation vs manual)
INSTALL_TYPE="manual"
if [ -n "$MINECRAFT_INSTANCE_ID" ] && [ -n "$MINECRAFT_ELASTIC_IP" ]; then
    INSTALL_TYPE="cloudformation"
    echo "Detected CloudFormation deployment"
else
    echo "Manual installation mode"
fi

# Install scripts
echo "Installing scripts..."
cp scripts/server/*.sh /usr/local/bin/
chmod +x /usr/local/bin/{minecraft-hibernation.sh,minecraft-idle-monitor.sh,spot-interruption-handler.sh,minecraft-startup.sh}

# Install systemd services
echo "Installing systemd services..."
cp systemd/*.service /etc/systemd/system/
cp systemd/*.timer /etc/systemd/system/

# Install config if minecraft-server is installed
if [ -d /etc/conf.d ]; then
    cp config/minecraft.conf /etc/conf.d/minecraft
    echo "Installed minecraft config"
else
    echo "Warning: /etc/conf.d not found - please install minecraft-server first"
fi

# Install Cockpit plugin
if [ -d /usr/share/cockpit ]; then
    echo "Installing Cockpit plugin..."
    mkdir -p /usr/share/cockpit/minecraft
    cp cockpit/* /usr/share/cockpit/minecraft/
    echo "Cockpit plugin installed"
else
    echo "Warning: Cockpit not found - skipping plugin installation"
fi

# Reload systemd
systemctl daemon-reload

# Enable services
echo "Enabling services..."
systemctl enable minecraft-hibernate
systemctl enable minecraft-idle-check.timer
systemctl enable spot-interruption-handler
systemctl enable minecraft-resume

# Start services
echo "Starting services..."
systemctl start minecraft-idle-check.timer
systemctl start spot-interruption-handler

echo ""
echo "Installation complete!"
echo ""

if [ "$INSTALL_TYPE" = "cloudformation" ]; then
    echo "CloudFormation deployment detected - system configured automatically"
    echo ""
    echo "Services status:"
    systemctl status minecraft-idle-check.timer --no-pager -l
    systemctl status spot-interruption-handler --no-pager -l
    echo ""
    echo "Minecraft server will be available after initialization completes."
    echo "Check status with: systemctl status minecraft"
else
    echo "Manual installation - Next steps:"
    echo "1. Install minecraft-server from https://github.com/Edenhofer/minecraft-server"
    echo "2. Configure your Minecraft server in /srv/minecraft/"
    echo "3. Set up environment variables for Gate proxy:"
    echo "   export MINECRAFT_INSTANCE_ID=i-xxxxxxxxx"
    echo "   export MINECRAFT_ELASTIC_IP=x.x.x.x"
    echo "   export AWS_REGION=us-east-1"
    echo "4. Deploy CloudFormation stack or configure Gate proxy manually"
    echo ""
    echo "Hibernation swap space setup:"
    echo "  sudo fallocate -l 8G /swapfile"
    echo "  sudo chmod 600 /swapfile"
    echo "  sudo mkswap /swapfile"
    echo "  sudo swapon /swapfile"
    echo "  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab"
fi

echo ""
echo "Logs can be viewed with:"
echo "  journalctl -u minecraft -f          # Minecraft server logs"
echo "  journalctl -u spot-interruption-handler -f  # Spot handling logs"
echo ""
echo "Web management available at: http://$(curl -s http://checkip.amazonaws.com/):9090"
echo ""
