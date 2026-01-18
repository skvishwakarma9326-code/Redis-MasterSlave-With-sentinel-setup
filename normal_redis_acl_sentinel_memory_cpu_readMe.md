# Redis High Availability Setup

> **Production-Ready Redis Master-Slave Configuration with Sentinel**  
> Optimized for 20M operations/second with 50K concurrent read/write operations

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture Diagram](#architecture-diagram)
- [System Requirements](#system-requirements)
- [Features](#features)
- [Quick Start](#quick-start)
- [Configuration Details](#configuration-details)
- [ACL Security Model](#acl-security-model)
- [Performance Tuning](#performance-tuning)
- [High Availability](#high-availability)
- [Monitoring & Operations](#monitoring--operations)
- [Troubleshooting](#troubleshooting)
- [Recommended Improvements](#recommended-improvements)

---

## 🎯 Overview

This automated setup script creates a production-grade Redis High Availability cluster with:

- **1 Master Node** (Port 6271)
- **1 Replica Node** (Port 6272)
- **3 Sentinel Instances** (Ports 26271, 26272, 26273)
- **ACL-based Security**
- **Automatic Failover**
- **Optimized for High Throughput**

### Performance Targets

| Metric | Target |
|--------|--------|
| Total Operations | 20M ops/second |
| Concurrent Read/Write | 50K ops/second |
| Max Connections | 65,536 |
| Memory per Instance | 5GB |
| CPU Quota | 600% (6 cores) |

---

## 🏗️ Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         Redis HA Cluster                         │
│                    (Server: 12 Core, 32GB RAM)                   │
└─────────────────────────────────────────────────────────────────┘

                    ┌─────────────────────┐
                    │   Load Balancer/    │
                    │   Application       │
                    │   Connection Pool   │
                    └──────────┬──────────┘
                               │
                ┌──────────────┼──────────────┐
                │              │              │
                ▼              ▼              ▼
        ┌──────────────┬──────────────┬──────────────┐
        │  Sentinel 1  │  Sentinel 2  │  Sentinel 3  │
        │  Port 26271  │  Port 26272  │  Port 26273  │
        └──────┬───────┴──────┬───────┴──────┬───────┘
               │              │              │
               └──────────────┼──────────────┘
                              │
                    ┌─────────▼─────────┐
                    │   Master Check    │
                    │   Quorum: 2/3     │
                    └─────────┬─────────┘
                              │
            ┌─────────────────┼─────────────────┐
            │                                   │
            ▼                                   ▼
    ┌───────────────┐                  ┌───────────────┐
    │ Redis Master  │◄─────────────────┤ Redis Replica │
    │  Port 6271    │   Replication    │  Port 6272    │
    │               │                  │               │
    │ • 5GB Memory  │                  │ • 5GB Memory  │
    │ • 600% CPU    │                  │ • 600% CPU    │
    │ • 65K Conns   │                  │ • 65K Conns   │
    └───────────────┘                  └───────────────┘
            │                                   │
            ▼                                   ▼
    ┌───────────────┐                  ┌───────────────┐
    │ dump-6271.rdb │                  │ dump-6272.rdb │
    └───────────────┘                  └───────────────┘

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Failover Scenario:

  Master Fails → Sentinels Detect (30s) → Vote (Quorum 2/3)
       ↓
  Promote Replica to Master → Update Clients → Old Master becomes Replica

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## 💻 System Requirements

### Minimum Server Specifications

```yaml
CPU: 12 Cores
RAM: 32 GB
SWAP: 8 GB
Disk: 500 GB SSD (NVMe recommended)
Network: 10 Gbps
OS: Ubuntu 20.04+ / CentOS 8+ / RHEL 8+
```

### Software Requirements

- Redis Server 6.0+ (with ACL support)
- systemd
- bash 4.0+
- Root/sudo access

### Network Requirements

**Required Open Ports:**
- `6271` - Redis Master
- `6272` - Redis Replica
- `26271-26273` - Sentinel Instances

---

## ✨ Features

### 🔒 Security
- **ACL (Access Control Lists)** with role-based access
- **Password authentication** for all users
- **Protected mode disabled** for cluster communication
- **Separate ACL files** per instance

### ⚡ Performance
- **65,536 max connections** per instance
- **5GB memory limit** with noeviction policy
- **600% CPU quota** (6 cores per Redis instance)
- **High TCP backlog** (65,536) for connection handling
- **OOM protection** with OOMScoreAdjust=-900

### 🛡️ High Availability
- **Automatic failover** with 3 Sentinel nodes
- **Quorum-based voting** (2/3 required)
- **30-second failure detection**
- **Configurable failover timeout** (60 seconds)

### 📊 Resource Management
- **systemd integration** with resource limits
- **Automatic restart** on failure
- **File descriptor limits** (65,536)
- **Memory and CPU quotas** enforced

---

## 🚀 Quick Start

### 1. Download and Prepare Script

```bash
# Download the script
wget https://your-repo/redis_setup.sh

# Make executable
chmod +x redis_setup.sh

# Create log directory
mkdir -p temp_log
```

### 2. Configure Master IP

Edit the script and set your master IP:

```bash
# Open the script
nano redis_setup.sh

# Change this line to your actual master IP
MASTER_IP="192.168.1.42"  # Replace with your server IP
```

### 3. Run Installation

```bash
# Execute with sudo
sudo ./redis_setup.sh
```

### 4. Start Services

```bash
# Start Redis instances
sudo systemctl start redis-server-6271.service
sudo systemctl start redis-server-6272.service

# Start Sentinel instances
sudo systemctl start redis-sentinel-26271.service
sudo systemctl start redis-sentinel-26272.service
sudo systemctl start redis-sentinel-26273.service

# Enable auto-start on boot
sudo systemctl enable redis-server-6271.service
sudo systemctl enable redis-server-6272.service
sudo systemctl enable redis-sentinel-26271.service
sudo systemctl enable redis-sentinel-26272.service
sudo systemctl enable redis-sentinel-26273.service
```

### 5. Verify Installation

```bash
# Check Master
redis-cli -u redis://default:StrongPassword@192.168.1.42:6271 ping
# Expected: PONG

# Check Replica
redis-cli -u redis://default:StrongPassword@192.168.1.42:6272 ping
# Expected: PONG

# Check Sentinel
redis-cli -p 26271 sentinel master mymaster
# Expected: Master details

# Check replication status
redis-cli -u redis://default:StrongPassword@192.168.1.42:6271 INFO replication
```

---

## ⚙️ Configuration Details

### Directory Structure

```
/etc/systemd/system/
├── redis-6271.conf                      # Master config
├── redis-6272.conf                      # Replica config
├── sentinel-normal-redis-26271.conf     # Sentinel 1
├── sentinel-normal-redis-26272.conf     # Sentinel 2
├── sentinel-normal-redis-26273.conf     # Sentinel 3
├── users-6271.acl                       # Master ACL
├── users-6272.acl                       # Replica ACL
├── redis-server-6271.service            # Master service
├── redis-server-6272.service            # Replica service
├── redis-sentinel-26271.service         # Sentinel 1 service
├── redis-sentinel-26272.service         # Sentinel 2 service
└── redis-sentinel-26273.service         # Sentinel 3 service

/var/lib/redis/
├── dump-6271.rdb                        # Master data
├── dump-6272.rdb                        # Replica data
├── dump-26271.rdb                       # Sentinel 1 data
├── dump-26272.rdb                       # Sentinel 2 data
└── dump-26273.rdb                       # Sentinel 3 data
```

### Key Configuration Parameters

#### Redis Server (6271, 6272)

```conf
port                    6271/6272
maxclients              65536
tcp-backlog             65536
maxmemory               5G
maxmemory-policy        noeviction
protected-mode          no
masterauth              StrongPassword
masteruser              default
```

#### Sentinel (26271, 26272, 26273)

```conf
port                              26271/26272/26273
sentinel monitor                  mymaster 192.168.1.42 6271 2
sentinel down-after-milliseconds  30000
sentinel failover-timeout         60000
sentinel parallel-syncs           1
sentinel auth-user                sentinel
```

---

## 🔐 ACL Security Model

### User Roles and Permissions

| User | Password | Permissions | Use Case |
|------|----------|-------------|----------|
| **default** | `StrongPassword` | `+@all` (Full Access) | Admin, Replication |
| **Asgard** | `21d44b4d...` (SHA256) | `+@read +@write -@dangerous` | Application User |
| **sentinel** | `21d44b4d...` (SHA256) | Sentinel Commands Only | Sentinel Automation |

### User Details

#### 1. Default User (Administrator)

```acl
user default on >StrongPassword sanitize-payload ~* &* +@all
```

**Capabilities:**
- Full administrative access
- All commands allowed
- Used for replication (`masteruser`)
- Key pattern: All keys (`~*`)
- Pub/Sub channels: All (`&*`)

**Connection String:**
```bash
redis-cli -u redis://default:StrongPassword@192.168.1.42:6271
```

#### 2. Asgard User (Application)

```acl
user Asgard on >21d44b4dfa34a57bb2e6b2f5aa8cb706cbca3085c6bb1d3d2c17229c6e888ff2 ~* +@read +@write -@dangerous +PING +MONITOR +CLIENT +INFO
```

**Capabilities:**
- Read operations: `GET`, `MGET`, `HGETALL`, etc.
- Write operations: `SET`, `HSET`, `LPUSH`, etc.
- Monitoring: `PING`, `INFO`, `CLIENT LIST`
- **Blocked:** `FLUSHALL`, `FLUSHDB`, `KEYS`, `CONFIG`, `SHUTDOWN`

**Security Features:**
- Cannot execute dangerous commands
- Cannot flush databases
- Cannot modify server configuration
- Ideal for application connections

**Connection String:**
```bash
redis-cli -u redis://Asgard:21d44b4dfa34a57bb2e6b2f5aa8cb706cbca3085c6bb1d3d2c17229c6e888ff2@192.168.1.42:6271
```

#### 3. Sentinel User (Automation)

```acl
user sentinel on >21d44b4d... allchannels +multi +slaveof +ping +exec +subscribe +config|rewrite +role +publish +info +client|setname +client|kill +script|kill
```

**Capabilities:**
- Sentinel-specific commands only
- Used exclusively by Sentinel for:
  - Monitoring master/replica status
  - Executing failover
  - Reconfiguring instances

**Not for manual use**

### Password Security

The script uses two password types:

1. **Plain text:** `StrongPassword` (change in production!)
2. **SHA256 hash:** `21d44b4d...` (pre-hashed)

**Generate secure password hash:**
```bash
echo -n "YourSecurePassword" | sha256sum
```

---

## 🎯 Performance Tuning

### Current Optimizations

#### 1. Memory Management
```yaml
Per Instance: 5GB
Policy: noeviction
Total Redis Memory: 10GB (Master + Replica)
Remaining System: 22GB for OS and cache
```

#### 2. CPU Allocation
```yaml
Per Redis Instance: 600% (6 cores)
Per Sentinel: 100% (1 core)
Total Usage: ~15 cores (out of 12 physical)
Note: Allows bursting and multithreading
```

#### 3. Connection Handling
```yaml
Max Clients: 65,536
TCP Backlog: 65,536
File Descriptors: 65,536
```

#### 4. Kernel Tuning

The script automatically applies:

```bash
vm.overcommit_memory = 1        # Prevent fork() failures
net.core.somaxconn = 65535      # Max connection queue
```

### Performance Testing

#### Benchmark with redis-benchmark

```bash
# Test Master (50K requests, 50 parallel)
redis-benchmark -h 192.168.1.42 -p 6271 -a StrongPassword -t set,get -n 50000 -c 50

# Test with pipelining (higher throughput)
redis-benchmark -h 192.168.1.42 -p 6271 -a StrongPassword -t set,get -n 1000000 -c 200 -P 16

# Test specific operations
redis-benchmark -h 192.168.1.42 -p 6271 -a StrongPassword -t lpush,lpop -n 100000 -c 100
```

#### Expected Results

```
SET: ~100,000 ops/sec
GET: ~150,000 ops/sec
LPUSH: ~120,000 ops/sec
With pipelining: 500,000+ ops/sec
```

---

## 🛡️ High Availability

### Sentinel Configuration

**Quorum:** 2 out of 3 Sentinels must agree

```
┌──────────────────────────────────────────┐
│     Sentinel Decision Making             │
├──────────────────────────────────────────┤
│  Sentinel 1: Master Down? YES            │
│  Sentinel 2: Master Down? YES  ✓ Quorum  │
│  Sentinel 3: Master Down? NO             │
│                                          │
│  Result: 2/3 agree → Initiate Failover  │
└──────────────────────────────────────────┘
```

### Failover Process

1. **Detection** (30 seconds)
   - Sentinel pings master every 1 second
   - No response for 30s → Mark as `SDOWN` (Subjectively Down)

2. **Voting** (Milliseconds)
   - Sentinels communicate
   - 2/3 agree → Mark as `ODOWN` (Objectively Down)

3. **Leader Election**
   - One Sentinel becomes leader
   - Leader executes failover

4. **Promotion** (~1-5 seconds)
   - Replica promoted to master
   - `SLAVEOF NO ONE` command sent
   - Old master reconfigured as replica

5. **Client Update**
   - Sentinels publish new master address
   - Clients reconnect to new master

**Total Failover Time:** ~35-40 seconds

### Testing Failover

```bash
# Simulate master failure
sudo systemctl stop redis-server-6271.service

# Watch Sentinel logs
sudo journalctl -u redis-sentinel-26271.service -f

# Check new master
redis-cli -p 26271 sentinel get-master-addr-by-name mymaster

# Verify promotion
redis-cli -u redis://default:StrongPassword@192.168.1.42:6272 INFO replication
# Should show: role:master

# Restart old master (becomes replica)
sudo systemctl start redis-server-6271.service
```

---

## 📊 Monitoring & Operations

### Health Checks

```bash
# Master status
redis-cli -u redis://default:StrongPassword@192.168.1.42:6271 INFO replication

# Replica lag
redis-cli -u redis://default:StrongPassword@192.168.1.42:6272 INFO replication | grep master_repl_offset

# Sentinel status
redis-cli -p 26271 sentinel masters

# Connected clients
redis-cli -u redis://default:StrongPassword@192.168.1.42:6271 CLIENT LIST | wc -l

# Memory usage
redis-cli -u redis://default:StrongPassword@192.168.1.42:6271 INFO memory

# Slow queries
redis-cli -u redis://default:StrongPassword@192.168.1.42:6271 SLOWLOG GET 10
```

### Service Management

```bash
# Check service status
sudo systemctl status redis-server-6271.service

# View logs
sudo journalctl -u redis-server-6271.service -f

# Restart service
sudo systemctl restart redis-server-6271.service

# Enable on boot
sudo systemctl enable redis-server-6271.service

# Check resource usage
systemctl show redis-server-6271.service | grep -E 'MemoryCurrent|CPUUsage'
```

### Monitoring Metrics

**Key Metrics to Track:**

| Metric | Command | Threshold |
|--------|---------|-----------|
| Connected Clients | `INFO clients` | < 60,000 |
| Memory Usage | `INFO memory` | < 4.5GB |
| Replication Lag | `INFO replication` | < 100 bytes |
| Keyspace Hits Ratio | `INFO stats` | > 95% |
| Evicted Keys | `INFO stats` | 0 |

---

## 🔧 Troubleshooting

### Common Issues

#### 1. Connection Refused

**Symptom:**
```
Error: Connection refused
```

**Solutions:**
```bash
# Check if service is running
sudo systemctl status redis-server-6271.service

# Check if port is open
sudo netstat -tulpn | grep 6271

# Check firewall
sudo ufw status
sudo ufw allow 6271

# Check protected mode
redis-cli -u redis://default:StrongPassword@192.168.1.42:6271 CONFIG GET protected-mode
```

#### 2. Authentication Failed

**Symptom:**
```
NOAUTH Authentication required
```

**Solutions:**
```bash
# Verify password
redis-cli -h 192.168.1.42 -p 6271 -a StrongPassword ping

# Check ACL file
cat /etc/systemd/system/users-6271.acl

# Reload ACL
redis-cli -u redis://default:StrongPassword@192.168.1.42:6271 ACL LOAD
```

#### 3. Replication Not Working

**Symptom:**
```
master_link_status:down
```

**Solutions:**
```bash
# Check replica configuration
redis-cli -u redis://default:StrongPassword@192.168.1.42:6272 INFO replication

# Verify masterauth
redis-cli -u redis://default:StrongPassword@192.168.1.42:6272 CONFIG GET masterauth

# Manually configure replication
redis-cli -u redis://default:StrongPassword@192.168.1.42:6272 REPLICAOF 192.168.1.42 6271

# Check network connectivity
telnet 192.168.1.42 6271
```

#### 4. Sentinel Not Detecting Master

**Symptom:**
```
sentinel master mymaster returns error
```

**Solutions:**
```bash
# Check Sentinel config
cat /etc/systemd/system/sentinel-normal-redis-26271.conf

# Verify Sentinel is monitoring
redis-cli -p 26271 sentinel masters

# Reset Sentinel
redis-cli -p 26271 sentinel reset mymaster

# Check Sentinel logs
sudo journalctl -u redis-sentinel-26271.service -n 100
```

#### 5. High Memory Usage

**Symptom:**
```
Memory usage > 4.5GB
```

**Solutions:**
```bash
# Check memory stats
redis-cli -u redis://default:StrongPassword@192.168.1.42:6271 INFO memory

# Check largest keys
redis-cli -u redis://default:StrongPassword@192.168.1.42:6271 --bigkeys

# Set expiration on keys
redis-cli -u redis://default:StrongPassword@192.168.1.42:6271 EXPIRE your-key 3600

# Consider enabling eviction
redis-cli -u redis://default:StrongPassword@192.168.1.42:6271 CONFIG SET maxmemory-policy allkeys-lru
```

---

## 🚀 Recommended Improvements

### 1. **Persistence Strategy**

**Current:** RDB snapshots only  
**Recommended:** Add AOF (Append-Only File)

```conf
# Add to redis-6271.conf and redis-6272.conf
appendonly yes
appendfilename "appendonly-6271.aof"
appendfsync everysec
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb
```

**Benefits:**
- Better durability
- Minimal data loss on crashes
- Faster recovery

---

### 2. **Multi-Server Deployment**

**Current:** Single server  
**Recommended:** 3-server cluster

```
Server 1: Master + Sentinel
Server 2: Replica + Sentinel
Server 3: Replica + Sentinel
```

**Benefits:**
- True high availability
- Geographic redundancy
- Better resource distribution

---

### 3. **TLS Encryption**

**Add secure communication:**

```conf
tls-port 6371
tls-cert-file /etc/redis/tls/redis.crt
tls-key-file /etc/redis/tls/redis.key
tls-ca-cert-file /etc/redis/tls/ca.crt
tls-auth-clients optional
```

---

### 4. **Monitoring Stack**

**Recommended Tools:**

- **Prometheus + Redis Exporter**
  ```bash
  docker run -d -p 9121:9121 \
    oliver006/redis_exporter \
    --redis.addr=redis://192.168.1.42:6271
  ```

- **Grafana Dashboard**
  - Import dashboard ID: 11835
  - Real-time metrics visualization

- **RedisInsight**
  ```bash
  docker run -d -p 8001:8001 redislabs/redisinsight
  ```

---

### 5. **Connection Pooling**

**Application-side optimization:**

```python
# Python example with redis-py
import redis

pool = redis.ConnectionPool(
    host='192.168.1.42',
    port=6271,
    password='StrongPassword',
    max_connections=1000,
    socket_keepalive=True,
    socket_connect_timeout=5,
    retry_on_timeout=True
)

r = redis.Redis(connection_pool=pool)
```

**Benefits:**
- Reduced connection overhead
- Better resource utilization
- Improved performance

---

### 6. **Backup Strategy**

**Automated backups:**

```bash
#!/bin/bash
# /usr/local/bin/redis-backup.sh

BACKUP_DIR="/backup/redis"
DATE=$(date +%Y%m%d_%H%M%S)

# Trigger BGSAVE
redis-cli -u redis://default:StrongPassword@192.168.1.42:6271 BGSAVE

# Wait for completion
while [ $(redis-cli -u redis://default:StrongPassword@192.168.1.42:6271 LASTSAVE) -eq $LAST_SAVE ]; do
    sleep 1
done

# Copy RDB file
cp /var/lib/redis/dump-6271.rdb "$BACKUP_DIR/dump-6271-$DATE.rdb"

# Compress and rotate
gzip "$BACKUP_DIR/dump-6271-$DATE.rdb"
find "$BACKUP_DIR" -name "*.gz" -mtime +7 -delete
```

**Add to crontab:**
```bash
0 2 * * * /usr/local/bin/redis-backup.sh
```

---

### 7. **Security Hardening**

- **Change default passwords** (use strong, unique passwords)
- **Restrict network access** (firewall rules, VPN)
- **Enable TLS** (as shown above)
- **Regular ACL audits**
- **Disable dangerous commands:**

```conf
rename-command FLUSHDB ""
rename-command FLUSHALL ""
rename-command KEYS ""
rename-command CONFIG "CONFIG-ADMIN-ONLY"
```

---

### 8. **Kernel Tuning Persistence**

**Make kernel tuning permanent:**

```bash
# Add to /etc/sysctl.conf
echo "vm.overcommit_memory = 1" >> /etc/sysctl.conf
echo "net.core.somaxconn = 65535" >> /etc/sysctl.conf
echo "net.ipv4.tcp_max_syn_backlog = 65536" >> /etc/sysctl.conf

# Apply
sudo sysctl -p
```

---

### 9. **Redis Cluster (Sharding)**

**For 20M ops/sec target:**

Consider Redis Cluster for horizontal scaling:

```
Master 1 (Slots 0-5460)     + Replica 1
Master 2 (Slots 5461-10922) + Replica 2
Master 3 (Slots 10923-16383) + Replica 3
```

**Benefits:**
- Horizontal scalability
- Automatic sharding
- 3x throughput capacity

---

### 10. **Slow Log Analysis**

**Enable detailed slow log:**

```conf
slowlog-log-slower-than 10000  # 10ms
slowlog-max-len 1000
```

**Regular analysis:**
```bash
redis-cli -u redis://default:StrongPassword@192.168.1.42:6271 SLOWLOG GET 100 | grep -E "set|get" | sort | uniq -c
```

---

## 📚 Additional Resources

- [Redis Documentation](https://redis.io/documentation)
- [Redis Sentinel Documentation](https://redis.io/topics/sentinel)
- [Redis ACL Guide](https://redis.io/topics/acl)
- [Redis Performance Optimization](https://redis.io/topics/optimization)
- [Redis Best Practices](https://redis.io/topics/best-practices)

---

## 📝 License

This setup script is provided as-is for production use. Modify according to your requirements.

---

## 🤝 Support

For issues or questions:
1. Check logs: `tail -f temp_log/redis_setup_*.log`
2. Review systemd logs: `journalctl -u redis-server-6271.service`
3. Verify configuration files in `/etc/systemd/system/`

---

**Last Updated:** January 2026  
**Script Version:** 1.0  
**Target Redis Version:** 6.0+
