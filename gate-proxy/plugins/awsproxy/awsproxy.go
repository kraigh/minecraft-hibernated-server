package awsproxy

import (
    "context"
    "fmt"
    "log"
    "os"
    "sync"
    "time"

    "github.com/aws/aws-sdk-go-v2/config"
    "github.com/aws/aws-sdk-go-v2/service/ec2"
    "go.minekube.com/gate/pkg/command"
    "go.minekube.com/gate/pkg/edition/java/proxy"
    "go.minekube.com/common/minecraft/component"
    "go.minekube.com/brigodier"
)

type AWSProxyPlugin struct {
    proxy      *proxy.Proxy
    instanceID string
    elasticIP  string
    region     string
    ec2Client  *ec2.Client
    
    mu           sync.RWMutex
    serverState  string
    lastStateCheck time.Time
}

func NewAWSProxyPlugin() func(ctx context.Context, proxy *proxy.Proxy) error {
    return func(ctx context.Context, p *proxy.Proxy) error {
        plugin := &AWSProxyPlugin{
            proxy:      p,
            instanceID: os.Getenv("MINECRAFT_INSTANCE_ID"),
            elasticIP:  os.Getenv("MINECRAFT_ELASTIC_IP"),
            region:     os.Getenv("AWS_REGION"),
        }

        if plugin.region == "" {
            plugin.region = "us-east-1"
        }

        // Initialize AWS client
        cfg, err := config.LoadDefaultConfig(ctx, config.WithRegion(plugin.region))
        if err != nil {
            return fmt.Errorf("failed to load AWS config: %w", err)
        }
        plugin.ec2Client = ec2.NewFromConfig(cfg)

        // Register a simple command for testing
        p.Command().Register(brigodier.Literal("serverstatus").
            Executes(command.Command(plugin.statusCommand)))

        // Start background status checker
        go plugin.statusChecker(ctx)

        log.Println("AWS Proxy plugin initialized successfully")
        return nil
    }
}

func (p *AWSProxyPlugin) statusCommand(c *command.Context) error {
    state := p.getServerState()
    
    message := &component.Text{
        Content: fmt.Sprintf("Server State: %s", state),
    }
    
    c.Source.SendMessage(message)
    return nil
}

func (p *AWSProxyPlugin) getServerState() string {
    p.mu.RLock()
    if time.Since(p.lastStateCheck) < 5*time.Second {
        state := p.serverState
        p.mu.RUnlock()
        return state
    }
    p.mu.RUnlock()
    
    // Update state
    go p.updateServerState()
    
    p.mu.RLock()
    state := p.serverState
    p.mu.RUnlock()
    return state
}

func (p *AWSProxyPlugin) updateServerState() {
    if p.instanceID == "" {
        log.Println("No instance ID configured")
        return
    }
    
    result, err := p.ec2Client.DescribeInstances(context.TODO(), &ec2.DescribeInstancesInput{
        InstanceIds: []string{p.instanceID},
    })
    
    if err != nil || len(result.Reservations) == 0 || len(result.Reservations[0].Instances) == 0 {
        log.Printf("Failed to get instance state: %v", err)
        return
    }
    
    state := string(result.Reservations[0].Instances[0].State.Name)
    
    p.mu.Lock()
    p.serverState = state
    p.lastStateCheck = time.Now()
    p.mu.Unlock()
    
    log.Printf("Instance state updated: %s", state)
}

func (p *AWSProxyPlugin) statusChecker(ctx context.Context) {
    ticker := time.NewTicker(30 * time.Second)
    defer ticker.Stop()
    
    for {
        select {
        case <-ctx.Done():
            return
        case <-ticker.C:
            p.updateServerState()
        }
    }
}