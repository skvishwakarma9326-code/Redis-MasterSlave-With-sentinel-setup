#!/bin/bash

#######################################################################
# Redis Configuration and Service File Creator/Updater (Shell Script)
#
# This script automatically creates or updates Redis server and Sentinel
# configuration files based on the built-in configuration.
# No user input required after running the script.
#
# Usage: sudo ./redis_setup.sh
#######################################################################

# Set script variables
SCRIPT_NAME="Redis Configuration Setup"
LOG_FILE="temp_log/redis_setup_$(date +%Y%m%d_%H%M%S).log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Configuration directories
REDIS_CONF_DIR="/etc/systemd/system"
REDIS_SERVICE_DIR="/etc/systemd/system"
REDIS_DATA_DIR="/var/lib/redis"

# Redis executables
REDIS_SERVER_BIN="/usr/bin/redis-server"
REDIS_SENTINEL_BIN="/usr/bin/redis-sentinel"

# Default permissions
FILE_MODE="755"
DEFAULT_USER="root"
DEFAULT_GROUP="root"

# Master IP (change this to your actual master IP)
MASTER_IP="192.168.1.42"

# Resource Limits
# For "1cr read and write" (10 Million keys) and 50K OPS on a 32GB/12Core system:
# - Memory: 10M keys depending on size can take 2GB to 15GB+. Allocating 16GB (50% of RAM) is safe.
# - CPU: Redis is mostly single-threaded but background tasks (IO, saving) use more.
#   Allocating 4 cores (400%) ensures the main thread is never throttled.
REDIS_MEMORY_LIMIT="5G"     # increased from 4G for 1cr data
REDIS_CPU_QUOTA="600%"       # increased from 200% for high throughput
SENTINEL_MEMORY_LIMIT="1G"   # increased for safety
SENTINEL_CPU_QUOTA="100%"    # increased for safety
FILE_DESCRIPTORS_LIMIT="65536" # High limit for high concurrency

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

#######################################################################
# Logging function
#######################################################################
log_message() {
   local level="$1"
   local message="$2"
   echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$LOG_FILE"
  
   case "$level" in
       "ERROR")
           echo -e "${RED}[ERROR] $message${NC}"
           ;;
       "SUCCESS")
           echo -e "${GREEN}[SUCCESS] $message${NC}"
           ;;
       "WARNING")
           echo -e "${YELLOW}[WARNING] $message${NC}"
           ;;
       "INFO")
           echo -e "${BLUE}[INFO] $message${NC}"
           ;;
       *)
           echo "[INFO] $message"
           ;;
   esac
}

#######################################################################
# Check if running as root
#######################################################################
check_root() {
   if [[ $EUID -ne 0 ]]; then
       log_message "ERROR" "This script must be run as root (use sudo)"
       exit 1
   fi
}

#######################################################################
# Ensure directory exists
#######################################################################
ensure_directory() {
   local dir_path="$1"
  
   if [[ ! -d "$dir_path" ]]; then
       mkdir -p "$dir_path"
       if [[ $? -eq 0 ]]; then
           log_message "SUCCESS" "Created directory: $dir_path"
           chmod "$FILE_MODE" "$dir_path"
       else
           log_message "ERROR" "Failed to create directory: $dir_path"
           exit 1
       fi
   fi
}

#######################################################################
# Create ACL File (users.acl)
#######################################################################
create_acl_file() {
   local filename="$1"
   local conf_path="$REDIS_CONF_DIR/$filename"
  
   log_message "INFO" "Creating ACL file: $conf_path..."
  
   cat > "$conf_path" << EOF
user default on >StrongPassword sanitize-payload ~* &* +@all
user Asgard on >21d44b4dfa34a57bb2e6b2f5aa8cb706cbca3085c6bb1d3d2c17229c6e888ff2 ~* +@read +@write -@dangerous +PING +MONITOR +CLIENT +INFO
user sentinel on >21d44b4dfa34a57bb2e6b2f5aa8cb706cbca3085c6bb1d3d2c17229c6e888ff2 allchannels +multi +slaveof +ping +exec +subscribe +config|rewrite +role +publish +info +client|setname +client|kill +script|kill
EOF

   chmod "600" "$conf_path"
   log_message "SUCCESS" "Created: $conf_path"
   echo "$conf_path"
}

#######################################################################
# Create Redis Server Configuration (Port 6271 - Master)
#######################################################################
create_redis_6271_conf() {
   local conf_path="$REDIS_CONF_DIR/redis-6271.conf"
  
   log_message "INFO" "Creating Redis 6271 configuration..."
  
   cat > "$conf_path" << EOF
# Redis configuration file created by script
# Dynamic Redis configuration
port 6271
dir $REDIS_DATA_DIR
dbfilename dump-6271.rdb
aclfile $REDIS_CONF_DIR/users-6271.acl
protected-mode no
# High Performance Tuning for 50k+ QPS
maxclients $FILE_DESCRIPTORS_LIMIT
tcp-backlog 65536
maxmemory $REDIS_MEMORY_LIMIT
maxmemory-policy noeviction
masterauth StrongPassword
masteruser default
EOF

   chmod "$FILE_MODE" "$conf_path"
   log_message "SUCCESS" "Created: $conf_path"
   echo "$conf_path"
}

#######################################################################
# Create Redis Slave Configuration (Port 6272 - Slave)
#######################################################################
create_redis_6272_conf() {
   local conf_path="$REDIS_CONF_DIR/redis-6272.conf"
  
   log_message "INFO" "Creating Redis 6272 configuration..."
  
   cat > "$conf_path" << EOF
# Redis configuration file created by script
# Dynamic Redis configuration
port 6272
dir $REDIS_DATA_DIR
dbfilename dump-6272.rdb
replicaof $MASTER_IP 6271
aclfile $REDIS_CONF_DIR/users-6272.acl
protected-mode no
# High Performance Tuning for 50k+ QPS
maxclients $FILE_DESCRIPTORS_LIMIT
tcp-backlog 65536
maxmemory $REDIS_MEMORY_LIMIT
maxmemory-policy noeviction
masterauth StrongPassword
masteruser default
EOF

   chmod "$FILE_MODE" "$conf_path"
   log_message "SUCCESS" "Created: $conf_path"
   echo "$conf_path"
}

#######################################################################
# Create Sentinel Configuration (Port 26271)
#######################################################################
create_sentinel_26271_conf() {
   local conf_path="$REDIS_CONF_DIR/sentinel-normal-redis-26271.conf"
  
   log_message "INFO" "Creating Sentinel 26271 configuration..."
  
   cat > "$conf_path" << EOF
# Redis configuration file created by script
# Dynamic Redis configuration
port 26271
dir $REDIS_DATA_DIR
dbfilename dump-26271.rdb
sentinel announce-ip $MASTER_IP
sentinel monitor mymaster $MASTER_IP 6271 2
sentinel auth-user mymaster sentinel
sentinel auth-pass mymaster 21d44b4dfa34a57bb2e6b2f5aa8cb706cbca3085c6bb1d3d2c17229c6e888ff2
sentinel down-after-milliseconds mymaster 30000
sentinel failover-timeout mymaster 60000
sentinel parallel-syncs mymaster 1
protected-mode no
EOF

   chmod "$FILE_MODE" "$conf_path"
   log_message "SUCCESS" "Created: $conf_path"
   echo "$conf_path"
}

#######################################################################
# Create Sentinel Configuration (Port 26272)
#######################################################################
create_sentinel_26272_conf() {
   local conf_path="$REDIS_CONF_DIR/sentinel-normal-redis-26272.conf"
  
   log_message "INFO" "Creating Sentinel 26272 configuration..."
  
   cat > "$conf_path" << EOF
# Redis configuration file created by script
# Dynamic Redis configuration
port 26272
dir $REDIS_DATA_DIR
dbfilename dump-26272.rdb
sentinel announce-ip $MASTER_IP
sentinel monitor mymaster $MASTER_IP 6271 2
sentinel auth-user mymaster sentinel
sentinel auth-pass mymaster 21d44b4dfa34a57bb2e6b2f5aa8cb706cbca3085c6bb1d3d2c17229c6e888ff2
sentinel down-after-milliseconds mymaster 30000
sentinel failover-timeout mymaster 60000
sentinel parallel-syncs mymaster 1
protected-mode no
EOF

   chmod "$FILE_MODE" "$conf_path"
   log_message "SUCCESS" "Created: $conf_path"
   echo "$conf_path"
}

#######################################################################
# Create Sentinel Configuration (Port 26273)
#######################################################################
create_sentinel_26273_conf() {
   local conf_path="$REDIS_CONF_DIR/sentinel-normal-redis-26273.conf"
  
   log_message "INFO" "Creating Sentinel 26273 configuration..."
  
   cat > "$conf_path" << EOF
# Redis configuration file created by script
# Dynamic Redis configuration
port 26273
dir $REDIS_DATA_DIR
dbfilename dump-26273.rdb
sentinel announce-ip $MASTER_IP
sentinel monitor mymaster $MASTER_IP 6271 2
sentinel auth-user mymaster sentinel
sentinel auth-pass mymaster 21d44b4dfa34a57bb2e6b2f5aa8cb706cbca3085c6bb1d3d2c17229c6e888ff2
sentinel down-after-milliseconds mymaster 30000
sentinel failover-timeout mymaster 60000
sentinel parallel-syncs mymaster 1
protected-mode no
EOF

   chmod "$FILE_MODE" "$conf_path"
   log_message "SUCCESS" "Created: $conf_path"
   echo "$conf_path"
}

#######################################################################
# Create systemd service file
#######################################################################
create_service_file() {
   local service_name="$1"
   local conf_file="$2"
   local redis_type="$3"
   local executable="$4"
   local memory_limit="$5"
   local cpu_quota="$6"
   local service_path="$REDIS_SERVICE_DIR/$service_name"
  
   log_message "INFO" "Creating service file: $service_name with Mem=$memory_limit, CPU=$cpu_quota"
  
   cat > "$service_path" << EOF
[Unit]
Description=Redis ${redis_type^} Service
After=network.target

[Service]
User=$DEFAULT_USER
Group=$DEFAULT_GROUP
ExecStart=$executable $conf_file
ExecStop=/bin/kill -s TERM \$MAINPID
Restart=always

# Resource Limits & Performance Tuning
LimitNOFILE=$FILE_DESCRIPTORS_LIMIT
MemoryLimit=$memory_limit
CPUQuota=$cpu_quota
# Prevent OOM killer from killing Redis easily (optional but recommended for DBs)
OOMScoreAdjust=-900

[Install]
WantedBy=multi-user.target
EOF

   chmod "$FILE_MODE" "$service_path"
   log_message "SUCCESS" "Created service: $service_path"
   echo "$service_path"
}

#######################################################################
# Create all Redis configurations and services
#######################################################################
create_all_configs() {
   local created_files=()
  
   # Ensure required directories exist
   ensure_directory "$REDIS_CONF_DIR"
   ensure_directory "$REDIS_SERVICE_DIR"
   ensure_directory "$REDIS_DATA_DIR"
  
   log_message "INFO" "Starting Redis configuration creation..."
  
   # Create Redis server configurations
   created_files+=("$(create_acl_file "users-6271.acl")")
   created_files+=("$(create_acl_file "users-6272.acl")")
   created_files+=("$(create_redis_6271_conf)")
   created_files+=("$(create_redis_6272_conf)")
  
   # Create Sentinel configurations
   created_files+=("$(create_sentinel_26271_conf)")
   created_files+=("$(create_sentinel_26272_conf)")
   created_files+=("$(create_sentinel_26273_conf)")
  
   # Create service files
   # Passing: service_name, conf_file, redis_type, executable, memory_limit, cpu_quota
   created_files+=("$(create_service_file "redis-server-6271.service" "$REDIS_CONF_DIR/redis-6271.conf" "server" "$REDIS_SERVER_BIN" "$REDIS_MEMORY_LIMIT" "$REDIS_CPU_QUOTA")")
   created_files+=("$(create_service_file "redis-server-6272.service" "$REDIS_CONF_DIR/redis-6272.conf" "server" "$REDIS_SERVER_BIN" "$REDIS_MEMORY_LIMIT" "$REDIS_CPU_QUOTA")")
   created_files+=("$(create_service_file "redis-sentinel-26271.service" "$REDIS_CONF_DIR/sentinel-normal-redis-26271.conf" "sentinel" "$REDIS_SENTINEL_BIN" "$SENTINEL_MEMORY_LIMIT" "$SENTINEL_CPU_QUOTA")")
   created_files+=("$(create_service_file "redis-sentinel-26272.service" "$REDIS_CONF_DIR/sentinel-normal-redis-26272.conf" "sentinel" "$REDIS_SENTINEL_BIN" "$SENTINEL_MEMORY_LIMIT" "$SENTINEL_CPU_QUOTA")")
   created_files+=("$(create_service_file "redis-sentinel-26273.service" "$REDIS_CONF_DIR/sentinel-normal-redis-26273.conf" "sentinel" "$REDIS_SENTINEL_BIN" "$SENTINEL_MEMORY_LIMIT" "$SENTINEL_CPU_QUOTA")")
  
   # Print summary
   echo ""
   log_message "SUCCESS" "Setup complete!"
   log_message "INFO" "Created/updated ${#created_files[@]} files:"
  
   for file in "${created_files[@]}"; do
       echo "  - $file"
   done
  
   # Find and list service files
   echo ""
   log_message "INFO" "Service files created:"
   for file in "${created_files[@]}"; do
       if [[ "$file" == *".service" ]]; then
           service_name=$(basename "$file")
           echo "  - $service_name"
       fi
   done
}

#######################################################################
# Reload systemd daemon
#######################################################################
reload_systemd() {
   log_message "INFO" "Reloading systemd daemon..."
  
   if systemctl daemon-reload; then
       log_message "SUCCESS" "systemctl daemon-reload executed successfully"
   else
       log_message "ERROR" "Failed to reload systemd daemon"
       return 1
   fi
}

#######################################################################
# Display service management commands
#######################################################################
show_service_commands() {
   echo ""
   log_message "INFO" "To manage your Redis services, use these commands:"
   echo ""
   echo "Start services:"
   echo "  sudo systemctl start redis-server-6271.service"
   echo "  sudo systemctl start redis-server-6272.service"
   echo "  sudo systemctl start redis-sentinel-26271.service"
   echo "  sudo systemctl start redis-sentinel-26272.service"
   echo "  sudo systemctl start redis-sentinel-26273.service"
   echo ""
   echo "Enable services (auto-start on boot):"
   echo "  sudo systemctl restart redis-server-6271.service"
   echo "  sudo systemctl restart redis-server-6272.service"
   echo "  sudo systemctl restart redis-sentinel-26271.service"
   echo "  sudo systemctl restart redis-sentinel-26272.service"
   echo "  sudo systemctl restart redis-sentinel-26273.service"
   echo ""
   echo "Check service status:"
   echo "  sudo systemctl status redis-server-6271.service"
   echo "  sudo systemctl status redis-sentinel-26271.service"
   echo ""
}


#######################################################################
# Allow required Redis and Sentinel ports through the firewall
#######################################################################
open_required_ports() {
   local ports=(6271 6272 26271 26272 26273)
   log_message "INFO" "Opening firewall ports: ${ports[*]}"

   if command -v ufw > /dev/null 2>&1; then
       for port in "${ports[@]}"; do
           ufw allow "$port" > /dev/null 2>&1
           if [[ $? -eq 0 ]]; then
               log_message "SUCCESS" "Allowed port $port via ufw"
           else
               log_message "WARNING" "Failed to allow port $port via ufw (may already be open)"
           fi
       done
   elif command -v firewall-cmd > /dev/null 2>&1; then
       for port in "${ports[@]}"; do
           firewall-cmd --permanent --add-port="$port"/tcp > /dev/null 2>&1
           if [[ $? -eq 0 ]]; then
               log_message "SUCCESS" "Allowed port $port via firewalld"
           else
               log_message "WARNING" "Failed to allow port $port via firewalld"
           fi
       done
       firewall-cmd --reload > /dev/null 2>&1
       log_message "INFO" "Reloaded firewalld configuration"
   else
       log_message "WARNING" "No supported firewall tool (ufw or firewalld) found"
   fi
}


#######################################################################
# System Tuning for High Performance (50k+ QPS)
#######################################################################
tune_system() {
   log_message "INFO" "Applying kernel tuning for high performance..."
  
   # restart overcommit memory to prevent fork failures during BGSAVE
   sysctl -w vm.overcommit_memory=1 >/dev/null 2>&1
  
   # Increase max connections (somaxconn) for high concurrency
   sysctl -w net.core.somaxconn=65535 >/dev/null 2>&1
  
   log_message "SUCCESS" "Applied vm.overcommit_memory=1 and net.core.somaxconn=65535"
}

#######################################################################
# Show Verification Commands
#######################################################################
show_verification_commands() {
   echo ""
   echo "========================================================"
   echo "       VERIFICATION AND CHECKING COMMANDS"
   echo "========================================================"
   echo ""
   log_message "INFO" "Use the following commands to verify connectivity:"
  
   echo "1. Check Master (6271) as 'default' user:"
   echo "   redis-cli -u redis://default:StrongPassword@$MASTER_IP:6271 ping"
   echo ""
   echo "2. Check Master (6271) as 'Asgard' user:"
   echo "   redis-cli -u redis://Asgard:21d44b4dfa34a57bb2e6b2f5aa8cb706cbca3085c6bb1d3d2c17229c6e888ff2@$MASTER_IP:6271 ping"
   echo ""
   echo "3. Check Slave (6272) as 'default' user:"
   echo "   redis-cli -u redis://default:StrongPassword@$MASTER_IP:6272 ping"
   echo ""
   echo "4. Check Sentinel (26271) - Check Master Status:"
   echo "   redis-cli -p 26271 sentinel master mymaster"
   echo ""
   echo "5. Check Sentinel (26271) - Get Master Address:"
   echo "   redis-cli -p 26271 sentinel get-master-addr-by-name mymaster"
   echo ""
   echo "6. Access Master via Sentinel (Automatic Discovery):"
   echo "   redis-cli -p 26271 -a StrongPassword --user default sentinel get-master-addr-by-name mymaster"
   echo ""
}

#######################################################################
# Main function
#######################################################################
main() {
   echo "========================================================"
   echo "    Redis Configuration and Service File Creator"
   echo "========================================================"
   echo "Started at: $TIMESTAMP"
   echo "Log file: $LOG_FILE"
   echo ""
  
   # Check if running as root
   check_root
  
   # Create all configurations and services
   create_all_configs
  
   # Reload systemd daemon
   reload_systemd
  
   # Apply System Tuning
   tune_system

   # Show service management commands
   show_service_commands
   # Allow Port To access from Another system
   open_required_ports
   # Show verification commands
   show_verification_commands
   echo ""
   log_message "SUCCESS" "Redis setup completed successfully!"
   echo "Check the log file for detailed information: $LOG_FILE"
}

#######################################################################
# Script execution
#######################################################################
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
   main "$@"
fi
