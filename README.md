# Minecraft Hibernated Server

A cost-effective Minecraft server solution on AWS that automatically starts when players connect and hibernates when idle. Designed to minimize costs while providing a seamless player experience.

## 🎯 Features

- **💰 Cost Effective**: ~85% cost reduction vs always-on servers (~$6-15/month)
- **🚀 Auto-Start**: Server automatically starts when players connect  
- **😴 Auto-Hibernation**: Hibernates after 20 minutes of inactivity
- **⚡ Fast Resume**: 30-60 second startup from hibernation
- **🛡️ Spot Protection**: Handles AWS spot interruptions gracefully
- **🌐 Web Management**: Cockpit web UI for server administration
- **📡 Gate Proxy**: Seamless player experience with limbo holding area

## 🏗️ Architecture

- **Gate Proxy** (t4g.nano ~$3/month): Always-on lightweight proxy that handles connections
- **Minecraft Server** (m8g.large spot): Hibernated EC2 instance that runs the actual game
- **Automatic Management**: Scripts handle hibernation, spot interruptions, and backups

## 🚀 Quick Start

### Prerequisites

- AWS CLI configured with appropriate permissions
- An EC2 key pair for SSH access
- Your public IP address for security group access

### 1. Clone and Configure

```bash
git clone https://github.com/yourusername/minecraft-hibernated-server
cd minecraft-hibernated-server
```

### 2. Configure Parameters

Edit `cloudformation/parameters.json` with your values:

```json
[
  {
    "ParameterKey": "KeyPairName",
    "ParameterValue": "your-ec2-key-pair"
  },
  {
    "ParameterKey": "HomeIP", 
    "ParameterValue": "1.2.3.4/32"
  },
  {
    "ParameterKey": "PublicSubnetId",
    "ParameterValue": "subnet-xxxxxxxxx"
  },
  {
    "ParameterKey": "GitRepoUrl",
    "ParameterValue": "https://github.com/yourusername/minecraft-hibernated-server"
  }
]
```

### 3. Deploy Infrastructure

```bash
# Validate templates
./scripts/deployment/validate-templates.sh

# Deploy the stack
./scripts/deployment/deploy.sh
```

### 4. Connect and Play

After deployment completes, connect your Minecraft client to the IP address shown in the output. The server will automatically start when you connect!

## 📋 Configuration Parameters

| Parameter | Required | Description | Example |
|-----------|----------|-------------|---------|
| `KeyPairName` | ✅ | EC2 key pair for SSH access | `my-minecraft-key` |
| `HomeIP` | ✅ | Your public IP for SSH access | `203.0.113.1/32` |
| `PublicSubnetId` | ✅ | Public subnet for instances | `subnet-12345abc` |
| `GitRepoUrl` | ✅ | Your fork of this repository | `https://github.com/user/repo` |
| `DomainName` | ❌ | Custom domain name | `minecraft.example.com` |
| `HostedZoneId` | ❌ | Route53 hosted zone ID | `Z1234567890ABC` |
| `MinecraftPort` | ❌ | Minecraft server port | `25565` |

## 🎮 Player Connection Flow

1. Player connects to your server address
2. Gate proxy immediately accepts the connection
3. If server is hibernated, Gate starts the EC2 instance
4. Player waits in a limbo holding area with status messages
5. When server is ready, Gate seamlessly transfers the player
6. No reconnection required!

## 💰 Cost Breakdown

| Component | Cost | Notes |
|-----------|------|-------|
| Gate Proxy (t4g.nano) | ~$3/month | Always running |
| Minecraft Server (m8g.large spot) | ~$0.03/hour | Only when playing |
| EBS Storage (30GB) | ~$2.40/month | Persistent world data |
| Elastic IPs (2) | Free | When attached to instances |
| **Total** | **~$6-15/month** | Depends on usage |

## 🔧 Management

### Web Interface
Access Cockpit at `http://minecraft-server-ip:9090` for:
- Server start/stop/restart
- Player management  
- Log viewing
- Backup creation
- Manual hibernation

### SSH Access
```bash
# Gate proxy
ssh -i ~/.ssh/your-key.pem ubuntu@proxy-ip

# Minecraft server  
ssh -i ~/.ssh/your-key.pem ubuntu@server-ip
```

### Useful Commands
```bash
# Check server status
systemctl status minecraft

# View logs
journalctl -u minecraft -f

# Manual backup
sudo -u minecraft minecraftd backup

# Force hibernation
sudo touch /tmp/minecraft-planned-shutdown && sudo systemctl stop minecraft
```

## 🔄 Update Deployment

To update your deployment:

```bash
# Update parameters if needed
vim cloudformation/parameters.json

# Apply updates
./scripts/deployment/update-stack.sh
```

## 📊 Monitoring

The system includes several monitoring mechanisms:

- **Spot Interruption Handler**: Monitors AWS metadata for interruption warnings
- **Idle Check**: Automatically hibernates after 20 minutes of inactivity  
- **Health Checks**: Gate proxy monitors server availability
- **Logging**: All components log to systemd journal

## 🛠️ Customization

### Minecraft Server Types
The system supports different server types by modifying the installation:

- **Vanilla**: Default configuration
- **Paper**: Better performance, more features
- **Forge**: Mod support
- **Fabric**: Lightweight mod support

### Backup Configuration
Backups can be configured to use S3:

```bash
# Set S3 bucket in environment
export S3_BACKUP_BUCKET=minecraft-backups-yourbucket

# Backups will automatically upload to S3
```

### Idle Timer
Modify the idle timeout by updating the systemd timer:

```bash
sudo systemctl edit minecraft-idle-check.timer
```

## 🐛 Troubleshooting

### Server Won't Start
1. Check CloudWatch logs for the EC2 instance
2. Verify spot capacity is available in your region
3. Check security group allows connections

### Players Can't Connect  
1. Verify security groups allow port 25565
2. Check if Elastic IPs are properly associated
3. Test Gate proxy connectivity

### High Costs
1. Verify instances hibernate when idle
2. Check for spot price spikes in your region
3. Monitor EBS snapshot costs

## 🔧 Development

### Prerequisites
- Go 1.24+ (for Gate proxy development)
- AWS CLI
- Docker (optional, for containerized builds)

### Gate Proxy Development
```bash
cd gate-proxy

# Note: Requires Go 1.24+
go mod tidy
go build
```

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## ⚠️ Known Issues

- Gate proxy requires Go 1.24+ (implementation ready, waiting for Go version availability)
- Spot interruption handling requires 2-minute graceful shutdown window
- First startup may take longer due to Minecraft server jar download

## 📚 Additional Resources

- [AWS Spot Instances Documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-spot-instances.html)
- [Gate Proxy Documentation](https://gate.minekube.com/)
- [Minecraft Server Administration](https://minecraft.wiki/w/Tutorials/Setting_up_a_server)
