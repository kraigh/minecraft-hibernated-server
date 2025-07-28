// /usr/share/cockpit/minecraft/minecraft.js
const minecraft = {
    init: function() {
        this.updateStatus();
        this.bindEvents();
        this.startLogStream();
        
        // Update status every 5 seconds
        setInterval(() => this.updateStatus(), 5000);
    },
    
    updateStatus: function() {
        cockpit.spawn(["systemctl", "is-active", "minecraft"])
            .done(output => {
                const status = output.trim();
                const statusEl = document.getElementById("status");
                
                if (status === "active") {
                    statusEl.innerHTML = '<span class="label label-success">Running</span>';
                    // Get player count
                    this.getPlayerCount();
                } else {
                    statusEl.innerHTML = '<span class="label label-danger">Stopped</span>';
                }
            });
    },
    
    getPlayerCount: function() {
        cockpit.spawn(["sudo", "-u", "minecraft", "minecraftd", "command", "list"])
            .done(output => {
                const match = output.match(/There are (\d+)/);
                if (match) {
                    const count = match[1];
                    const statusEl = document.getElementById("status");
                    statusEl.innerHTML += ` - ${count} players online`;
                }
            });
    },
    
    bindEvents: function() {
        document.getElementById("start-btn").addEventListener("click", () => {
            cockpit.spawn(["systemctl", "start", "minecraft"])
                .done(() => this.updateStatus());
        });
        
        document.getElementById("stop-btn").addEventListener("click", () => {
            if (confirm("Stop the server? This will kick all players.")) {
                cockpit.spawn(["systemctl", "stop", "minecraft"])
                    .done(() => this.updateStatus());
            }
        });
        
        document.getElementById("restart-btn").addEventListener("click", () => {
            cockpit.spawn(["systemctl", "restart", "minecraft"])
                .done(() => this.updateStatus());
        });
        
        document.getElementById("save-btn").addEventListener("click", () => {
            cockpit.spawn(["sudo", "-u", "minecraft", "minecraftd", "command", "save-all"])
                .done(() => alert("World saved!"));
        });
        
        document.getElementById("backup-btn").addEventListener("click", () => {
            cockpit.spawn(["sudo", "-u", "minecraft", "minecraftd", "backup"])
                .done(() => alert("Backup completed!"));
        });
        
        document.getElementById("hibernate-btn").addEventListener("click", () => {
            if (confirm("Hibernate the instance? Server will stop.")) {
                cockpit.spawn(["touch", "/tmp/minecraft-planned-shutdown"])
                    .then(() => cockpit.spawn(["systemctl", "stop", "minecraft"]))
                    .done(() => alert("Server stopping, instance will hibernate."));
            }
        });
        
        document.getElementById("send-cmd-btn").addEventListener("click", () => {
            const cmd = document.getElementById("command-input").value;
            if (cmd) {
                cockpit.spawn(["sudo", "-u", "minecraft", "minecraftd", "command", cmd])
                    .done(() => {
                        document.getElementById("command-input").value = "";
                    });
            }
        });
    },
    
    startLogStream: function() {
        const logsEl = document.getElementById("logs");
        const proc = cockpit.spawn(["journalctl", "-u", "minecraft", "-f", "-n", "50"]);
        
        proc.stream(data => {
            logsEl.textContent += data;
            logsEl.scrollTop = logsEl.scrollHeight;
        });
    }
};

document.addEventListener("DOMContentLoaded", () => minecraft.init());
