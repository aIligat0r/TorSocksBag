#!/bin/bash


BRIDGE_FILE=${BRIDGE_FILE:-/etc/tor/bridges.txt}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Clean after exit
cleanup() {
    log "Stopping all TOR instances..."
    for pid in ${TOR_PIDS[@]}; do
        kill $pid 2>/dev/null || true
    done
    exit 0
}

trap cleanup SIGTERM SIGINT

# Variables validate
if ! [[ "$PROXY_COUNT" =~ ^[0-9]+$ ]] || [ "$PROXY_COUNT" -lt 1 ] || [ "$PROXY_COUNT" -gt 100 ]; then
    error "PROXY_COUNT must be between 1 and 100"
fi

log "Initializing TorSocksBag with $PROXY_COUNT proxies..."
log "Number of proxies: $PROXY_COUNT"
log "Base SOCKS port: $START_PORT"

# Dirs for instances
mkdir -p /tmp/tor_configs

# Bridges config
BRIDGE_CONFIG=""
if [ "$USE_BRIDGES" = "true" ]; then
    if [ -f "$BRIDGE_FILE" ]; then
        log "Loading bridges from $BRIDGE_FILE"
        BRIDGE_CONFIG=$(cat "$BRIDGE_FILE" | grep -v '^#' | grep -v '^$' | sed 's/^/Bridge /')
        if [ -z "$BRIDGE_CONFIG" ]; then
            warn "Bridge file is empty or contains no valid bridges"
        else
            log "Loaded $(echo "$BRIDGE_CONFIG" | wc -l) bridges"
            BRIDGE_CONFIG="UseBridges 1\nClientTransportPlugin obfs4 exec /usr/bin/obfs4proxy\n$BRIDGE_CONFIG"
        fi
    else
        warn "USE_BRIDGES=true but $BRIDGE_FILE not found."
    fi
fi

TOR_PIDS=()

# Generate and start
for i in $(seq 1 $PROXY_COUNT); do
    INSTANCE_ID=$i
    SOCKS_PORT=$((START_PORT + i - 1))
    DATA_DIR="/var/lib/tor/instance_$INSTANCE_ID"
    
    # Control port (optional)
    if [ "$ENABLE_CONTROL" = "true" ]; then
        CONTROL_PORT=$((CONTROL_BASE_PORT + 1000 + i - 1))
        CONTROL_PORT_CONFIG="ControlPort 127.0.0.1:$CONTROL_PORT
CookieAuthentication 0"
    else
        CONTROL_PORT_CONFIG="# ControlPort disabled"
    fi

    # Data dir
    mkdir -p "$DATA_DIR"
    chmod 700 "$DATA_DIR"
    
    # Generate config
    CONFIG_FILE="/tmp/tor_configs/torrc_$INSTANCE_ID"
    
    cat > "$CONFIG_FILE" << EOF
# Auto-generated config for instance $INSTANCE_ID
SocksPort 0.0.0.0:$SOCKS_PORT
SocksPolicy accept *
$CONTROL_PORT_CONFIG
DataDirectory $DATA_DIR
MaxCircuitDirtiness 10
NewCircuitPeriod 15
UseEntryGuards 1
NumEntryGuards 8
Log $TOR_LOG_LEVEL stderr
Sandbox 0
$(echo -e "$BRIDGE_CONFIG")
EOF

    log "Starting TOR instance $INSTANCE_ID on SOCKS port $SOCKS_PORT"
    
    # Start TOR in background
    tor -f "$CONFIG_FILE" &
    TOR_PIDS+=($!)

    # Save - race condition
    sleep 0.5
done

log "All $PROXY_COUNT TOR instances started"
log "SOCKS proxies available on ports $START_PORT-$((START_PORT + PROXY_COUNT - 1))"

# Check
sleep 2
log "Checking proxy status..."

for i in $(seq 1 $PROXY_COUNT); do
    PORT=$((START_PORT + i - 1))
    # Проверяем, слушает ли порт
    if timeout 5 bash -c "echo > /dev/tcp/127.0.0.1/$PORT" 2>/dev/null; then
        log "Instance $i (port $PORT): ${GREEN}OK${NC}"
    else
        warn "Instance $i (port $PORT) not responding yet"
    fi
done

echo -e "\n${GREEN}=== TOR PROXY CLUSTER STATUS ===${NC}"
echo "Container IP: $(hostname -i 2>/dev/null || echo 'localhost')"
echo "Proxy Count: $PROXY_COUNT"
echo "Port Range: $START_PORT - $((START_PORT + PROXY_COUNT - 1))"
echo ""
echo "Usage examples:"
echo "  curl --socks5-hostname localhost:$START_PORT https://check.torproject.org"
echo ""

# Monitoring
if [ "$ENABLE_MONITORING" = "true" ]; then
    log "Starting health check monitoring..."
    while true; do
        for i in "${!TOR_PIDS[@]}"; do
            pid=${TOR_PIDS[$i]}
            if ! kill -0 $pid 2>/dev/null; then
                warn "Instance $((i+1)) (PID $pid) died. Restarting..."
                # Restart instance
                CONFIG_FILE="/tmp/tor_configs/torrc_$((i+1))"
                tor -f "$CONFIG_FILE" &
                TOR_PIDS[$i]=$!
            fi
        done
        sleep 10
    done
else
    wait
fi
