package main

import (
    "context"
    "log"

    "go.minekube.com/gate/pkg/edition/java/proxy"
    "go.minekube.com/gate/pkg/gate"
    "minecraft-hibernated-server/gate-proxy/plugins/awsproxy"
)

func main() {
    // Register our AWS proxy plugin
    proxy.Plugins = append(proxy.Plugins, proxy.Plugin{
        Name: "AWSProxy",
        Init: awsproxy.NewAWSProxyPlugin(),
    })

    // Start Gate proxy with the registered plugins
    if err := gate.Start(context.Background()); err != nil {
        log.Fatal(err)
    }
}