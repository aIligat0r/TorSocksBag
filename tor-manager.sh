#!/bin/bash

[ -f .env ] || {
	echo "⛔ File '.env' not found. Create .env. (example in .env.Example)"
	exit 1
}
set -a
source .env
set +a

CONTAINER_NAME="torsocksbag"

COMMAND=$1
case $COMMAND in
    start)
        echo "🧅 Starting TOR cluster..."
        docker-compose up -d --build
        ;;

    stop)
        echo "🛑 Stopping TOR cluster..."
        docker-compose down
        ;;

    restart)
        echo "🔄 Restarting TOR cluster..."
        docker-compose restart
        ;;

    status)
        echo "=== TorSocksBag Status ==="
        docker-compose ps
        echo ""
        echo "Active connections:"
        docker exec "$CONTAINER_NAME" netstat -tlnp 2>/dev/null | grep tor || docker exec "$CONTAINER_NAME" ss -tlnp | grep tor
        ;;

    logs)
        docker-compose logs -f
        ;;

    newnym)
        if [[ "${ENABLE_CONTROL}" != "true" ]]; then
            echo "🚨 ERROR: ENABLE_CONTROL must be true in .env to use newnym"
            exit 1
        fi

        echo "⇄ Creating new circuits..."
        for port in $(seq "$START_PORT" "$((END_PORT - 1))"); do
            CONTROL_PORT=$((CONTROL_BASE_PORT + 1000 + port - START_PORT))
            
            if docker exec $CONTAINER_NAME bash -c "echo -e 'AUTHENTICATE \"\"\\r\\nsignal NEWNYM\\r\\nQUIT' | socat - TCP:127.0.0.1:$CONTROL_PORT" 2>&1 | grep -q "250 OK"; then
                echo "🔄 Instance on port $port: NEWNYM sent"
            else
                echo "⛔ Instance on port $port: Failed (check debug output above)"
            fi
        done
        ;;

    check)
        echo "🔍 Checking proxies..."
        for port in $(seq $START_PORT $((END_PORT - 1))); do
            IP=$(curl --silent --max-time 20 --socks5-hostname localhost:$port https://check.torproject.org/api/ip | jq -r '.IP' 2>/dev/null || echo "🚫 FAILED")
            echo "✅ Port $port: $IP"
        done
        ;;
    *)

	echo "TorSocksBag"
	echo "Usage: $0 {start|stop|restart|status|logs|newnym|check}"
	echo ""
	echo "Commands:"
	echo "  start     - Build and start the cluster"
	echo "  stop      - Stop the cluster"
	echo "  restart   - Restart the cluster"
	echo "  status    - Show running instances and ports"
	echo "  logs      - Follow logs"
	echo "  newnym    - Create new TOR circuits (requires ENABLE_CONTROL=true)"
	echo "  check     - Test all proxies and show exit IPs"
	;;
esac
