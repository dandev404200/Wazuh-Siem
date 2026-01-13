# Wazuh Agent Setup for macOS

This guide walks through installing and configuring a Wazuh agent on macOS with password-based authentication.

## Prerequisites

- macOS 10.15 or later (macOS Big Sur+ for Apple Silicon)
- Administrator access (sudo)
- Enrollment password from the Wazuh manager
- NLB DNS name: `wazuh-poc-nlb-37882f6f3c6428ab.elb.us-east-1.amazonaws.com`

## Overview

| Step | Purpose |
|------|---------|
| 1 | Download the Wazuh agent package |
| 2 | Install the agent |
| 3 | Stop the agent service |
| 4 | Configure the agent |
| 5 | Set up enrollment password |
| 6 | Enroll the agent |
| 7 | Start the agent |
| 8 | Verify connection |

---

## Step 1: Download Wazuh Agent

**Run on:** Your macOS laptop  
**Purpose:** Download the official Wazuh agent installer package

First, check your Mac architecture:

```bash
uname -m
```

- Output `arm64` = Apple Silicon (M1/M2/M3) - use ARM64 package
- Output `x86_64` = Intel Mac - use Intel64 package

Download the appropriate package:

```bash
cd ~/Downloads

# For Apple Silicon (M1/M2/M3) - ARM64
curl -so wazuh-agent.pkg https://packages.wazuh.com/4.x/macos/wazuh-agent-4.9.0-1.arm64.pkg

# OR for Intel Macs - x86_64
# curl -so wazuh-agent.pkg https://packages.wazuh.com/4.x/macos/wazuh-agent-4.9.0-1.intel64.pkg
```

Verify the download:

```bash
ls -la wazuh-agent.pkg
```

Expected: File size ~6-7 MB (ARM64) or ~15-20 MB (Intel64)

---

## Step 2: Install the Agent

**Run on:** Your macOS laptop  
**Purpose:** Install the Wazuh agent to `/Library/Ossec/`

```bash
sudo installer -pkg ~/Downloads/wazuh-agent.pkg -target /
```

This installs:
- Agent binaries in `/Library/Ossec/bin/`
- Configuration in `/Library/Ossec/etc/`
- Logs in `/Library/Ossec/logs/`

Verify installation:

```bash
ls /Library/Ossec/bin/
```

Expected: `wazuh-control`, `wazuh-agentd`, `wazuh-logcollector`, etc.

---

## Step 3: Stop the Agent Service

**Run on:** Your macOS laptop  
**Purpose:** Stop the agent before modifying configuration

```bash
sudo /Library/Ossec/bin/wazuh-control stop
```

Verify it's stopped:

```bash
sudo /Library/Ossec/bin/wazuh-control status
```

Expected: All processes show "not running"

---

## Step 4: Configure the Agent

**Run on:** Your macOS laptop  
**Purpose:** Configure the agent to connect to the Wazuh manager via NLB

### Backup existing config:

```bash
sudo cp /Library/Ossec/etc/ossec.conf /Library/Ossec/etc/ossec.conf.bak
```

### Edit configuration:

```bash
sudo nano /Library/Ossec/etc/ossec.conf
```

### Find and replace the `<client>` block:

Look for the existing `<client>` section (usually near the top of the file) and replace the entire block with:

```xml
<client>
  <server>
    <address>wazuh-poc-nlb-37882f6f3c6428ab.elb.us-east-1.amazonaws.com</address>
    <port>1514</port>
    <protocol>tcp</protocol>
  </server>
  <enrollment>
    <enabled>yes</enabled>
    <manager_address>wazuh-poc-nlb-37882f6f3c6428ab.elb.us-east-1.amazonaws.com</manager_address>
    <port>1515</port>
    <authorization_pass_path>/Library/Ossec/etc/authd.pass</authorization_pass_path>
  </enrollment>
  <config-profile>darwin</config-profile>
  <crypto_method>aes</crypto_method>
</client>
```

### Configuration explained:

| Setting | Purpose |
|---------|---------|
| `<address>` | NLB DNS name - where to send events |
| `<port>1514</port>` | Agent event communication port |
| `<protocol>tcp</protocol>` | Use TCP (required for NLB) |
| `<manager_address>` | NLB DNS name - where to enroll |
| `<port>1515</port>` | Agent enrollment/registration port |
| `<authorization_pass_path>` | Path to password file for enrollment |
| `<config-profile>darwin</config-profile>` | macOS-specific configuration profile |
| `<crypto_method>aes</crypto_method>` | Encryption method for communication |

Save and exit: `Ctrl+O`, `Enter`, `Ctrl+X`

---

## Step 5: Set Up Enrollment Password

**Run on:** Your macOS laptop  
**Purpose:** Create the password file for agent enrollment

```bash
# Create password file (use the same password configured on the manager)
echo 'Password123' | sudo tee /Library/Ossec/etc/authd.pass

# Set proper ownership and permissions
sudo chown root:wazuh /Library/Ossec/etc/authd.pass
sudo chmod 640 /Library/Ossec/etc/authd.pass
```

**Note:** Replace `Password123` with the actual enrollment password from your Wazuh manager.

---

## Step 6: Enroll the Agent

**Run on:** Your macOS laptop  
**Purpose:** Register the agent with the Wazuh manager

```bash
# Enroll the agent
sudo /Library/Ossec/bin/agent-auth \
  -m wazuh-poc-nlb-37882f6f3c6428ab.elb.us-east-1.amazonaws.com \
  -P 'Password123' \
  -A $(hostname)
```

Expected output:
```
INFO: Started (pid: XXXXX).
INFO: Requesting a key from server: wazuh-poc-nlb-37882f6f3c6428ab.elb.us-east-1.amazonaws.com
INFO: Using agent name as: your-hostname
INFO: Waiting for server reply
INFO: Valid key received
```

If you see `Valid key received`, enrollment was successful!

---

## Step 7: Start the Agent

**Run on:** Your macOS laptop  
**Purpose:** Start the Wazuh agent service

```bash
sudo /Library/Ossec/bin/wazuh-control start
```

Expected output:
```
Starting Wazuh v4.9.0...
Started wazuh-execd...
Started wazuh-agentd...
Started wazuh-syscheckd...
Started wazuh-logcollector...
Started wazuh-modulesd...
Completed.
```

---

## Step 8: Verify Connection

**Run on:** Your macOS laptop  
**Purpose:** Confirm the agent is running and connected

### Check agent status:

```bash
sudo /Library/Ossec/bin/wazuh-control status
```

Expected: All processes show "is running"

### View agent logs:

```bash
sudo tail -f /Library/Ossec/logs/ossec.log
```

Look for:
- `INFO: Connected to the server` - Success!
- `INFO: Server responded` - Agent is communicating
- `ERROR: ` - Something went wrong

Press `Ctrl+C` to exit tail.

### Check connection state:

```bash
sudo cat /Library/Ossec/var/run/wazuh-agentd.state
```

Expected: `status='connected'`

---

## Step 9: Verify on Manager

**Run on:** EC2 instance via SSM  
**Purpose:** Confirm the manager sees the connected agent

```bash
# Connect to EC2
aws ssm start-session --target <instance-id>

# Switch to root
sudo su -

# List agents
cd /opt/wazuh/wazuh-docker/single-node
docker-compose exec wazuh.manager /var/ossec/bin/agent_control -l
```

Expected: Your macOS agent listed with "Active" status

---

## Troubleshooting

### Agent won't enroll - "Invalid request for new agent"

This usually means password authentication is not enabled on the manager.

**On the manager (EC2 via SSM):**
```bash
cd /opt/wazuh/wazuh-docker/single-node

# Check if use_password is enabled
docker-compose exec wazuh.manager grep "use_password" /var/ossec/etc/ossec.conf

# If it shows <use_password>no</use_password>, fix it:
sed -i 's/<use_password>no<\/use_password>/<use_password>yes<\/use_password>/' config/wazuh_cluster/wazuh_manager.conf

# Restart manager
docker-compose restart wazuh.manager
```

### Agent won't start

```bash
# Check logs for errors
sudo tail -100 /Library/Ossec/logs/ossec.log

# Check if ports are blocked
nc -zv wazuh-poc-nlb-37882f6f3c6428ab.elb.us-east-1.amazonaws.com 1514
nc -zv wazuh-poc-nlb-37882f6f3c6428ab.elb.us-east-1.amazonaws.com 1515
```

### Password mismatch

```bash
# Verify password file content on Mac
sudo cat /Library/Ossec/etc/authd.pass

# Verify password on manager
docker-compose exec wazuh.manager cat /var/ossec/etc/authd.pass

# Passwords must match exactly (no extra spaces or newlines)
```

### Connection refused

```bash
# Test connectivity to NLB
nc -zv wazuh-poc-nlb-37882f6f3c6428ab.elb.us-east-1.amazonaws.com 1514
nc -zv wazuh-poc-nlb-37882f6f3c6428ab.elb.us-east-1.amazonaws.com 1515

# Check if firewall is blocking
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
```

### Re-enroll agent

If you need to re-register the agent:

```bash
sudo /Library/Ossec/bin/wazuh-control stop
sudo rm -f /Library/Ossec/etc/client.keys
sudo /Library/Ossec/bin/agent-auth \
  -m wazuh-poc-nlb-37882f6f3c6428ab.elb.us-east-1.amazonaws.com \
  -P 'Password123' \
  -A $(hostname)
sudo /Library/Ossec/bin/wazuh-control start
```

---

## Uninstall Agent

If you need to remove the agent:

```bash
sudo /Library/Ossec/bin/wazuh-control stop
sudo /bin/rm -rf /Library/Ossec
sudo /bin/rm -rf /Library/LaunchDaemons/com.wazuh.agent.plist
sudo /bin/rm -rf /Library/StartupItems/WAZUH
sudo /usr/bin/dscl . -delete /Users/wazuh
sudo /usr/bin/dscl . -delete /Groups/wazuh
```

---

## Quick Reference

| Command | Purpose |
|---------|---------|
| `sudo /Library/Ossec/bin/wazuh-control start` | Start agent |
| `sudo /Library/Ossec/bin/wazuh-control stop` | Stop agent |
| `sudo /Library/Ossec/bin/wazuh-control restart` | Restart agent |
| `sudo /Library/Ossec/bin/wazuh-control status` | Check status |
| `sudo tail -f /Library/Ossec/logs/ossec.log` | View logs |
| `sudo cat /Library/Ossec/var/run/wazuh-agentd.state` | Check connection state |

---

## Common Issues and Fixes

### Issue 1: Certificate Permission Error
**Symptom:** `ERROR: Unable to read private key file`

**Cause:** The `wazuh` user cannot read certificate files.

**Fix:**
```bash
sudo chown -R root:wazuh /Library/Ossec/etc/certs/
sudo chmod 640 /Library/Ossec/etc/certs/*
```

### Issue 2: Expired SSL Certificates
**Symptom:** `ERROR: certificate has expired`

**Cause:** Manager's SSL certificates are expired.

**Fix:** Regenerate certificates on the manager (see manager documentation).

### Issue 3: Self-Signed Certificate Rejected
**Symptom:** `ERROR: 18:self-signed certificate`

**Cause:** Agent cannot verify manager's self-signed certificate.

**Solution:** Use password-based authentication (as shown in this guide) instead of certificate-based authentication.

---

## Access Wazuh Dashboard

Once your agent is connected, you can view it in the Wazuh Dashboard:

```
https://wazuh-poc-nlb-37882f6f3c6428ab.elb.us-east-1.amazonaws.com
```

**Default credentials:**
- Username: `admin`
- Password: `SecretPassword`

Navigate to **Agents** to see your macOS agent listed as **Active**.
