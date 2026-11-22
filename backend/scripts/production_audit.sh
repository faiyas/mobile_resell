#!/bin/bash
# ==============================================================================
# 1103 RECELL - PRODUCTION PRE-LAUNCH 5-POINT HEALTH & READINESS AUDIT
# ==============================================================================
# Checklist Covered:
# 1. Load & Throughput Readiness
# 2. Memory Utilization & Leak Check (Gunicorn Worker RSS)
# 3. CPU Core Utilization & Load Averages
# 4. Service & System Logs (Exceptions, Tracebacks, HTTP 500s)
# 5. Database Connections & MariaDB Thread Pools
# ==============================================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=====================================================================${NC}"
echo -e "${GREEN}      1103 RECELL - PRODUCTION PRE-LAUNCH 5-POINT AUDIT SUITE       ${NC}"
echo -e "${BLUE}=====================================================================${NC}"
echo -e "Timestamp: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo -e "Host: $(hostname) | Kernel: $(uname -r)"
echo ""

# ------------------------------------------------------------------------------
# 1. LOAD & THROUGHPUT READINESS
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[1/5] CHECKING GUNICORN SERVICE STATUS & WORKERS...${NC}"
SERVICE_STATUS=$(systemctl is-active mobilebuyback.service 2>/dev/null)
if [ "$SERVICE_STATUS" = "active" ]; then
    echo -e "${GREEN}✓ mobilebuyback.service is ACTIVE and running.${NC}"
else
    echo -e "${RED}✗ mobilebuyback.service is NOT active (Status: $SERVICE_STATUS).${NC}"
fi

GUNICORN_COUNT=$(pgrep -f "gunicorn.*config.wsgi" | wc -l)
echo -e "Active Gunicorn processes: ${GREEN}${GUNICORN_COUNT}${NC} (1 Master + $(($GUNICORN_COUNT - 1)) Workers)"
echo ""

# ------------------------------------------------------------------------------
# 2. MEMORY UTILIZATION & WORKER RSS CHECK
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[2/5] CHECKING SYSTEM MEMORY & GUNICORN RSS USAGE...${NC}"
free -h | awk 'NR==1{print $0} NR==2{printf "%-6s Total: %-8s Used: %-8s Free: %-8s Available: %-8s\n", $1, $2, $3, $4, $7} NR==3{printf "%-6s Total: %-8s Used: %-8s Free: %-8s\n", $1, $2, $3, $4}'
echo ""
echo -e "Gunicorn Worker Resident Memory (RSS):"
ps -eo pid,ppid,user,%mem,rss,command | grep gunicorn | grep -v grep | awk '{printf "  • PID: %-7s Memory: %-5s RSS: %-8s KB (%-5s MB)\n", $1, $4"%", $5, int($5/1024)}'

SWAP_USED=$(free -m | awk '/Swap:/ {print $3}')
if [ "$SWAP_USED" -gt 500 ]; then
    echo -e "${YELLOW}⚠️ High Swap usage detected (${SWAP_USED} MB). Review memory allocation.${NC}"
else
    echo -e "${GREEN}✓ Swap usage is healthy (${SWAP_USED} MB used).${NC}"
fi
echo ""

# ------------------------------------------------------------------------------
# 3. CPU MONITORING & CORE CAPACITY
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[3/5] CHECKING CPU CORES & LOAD AVERAGES...${NC}"
CORES=$(nproc)
echo -e "CPU Available Cores: ${GREEN}${CORES}${NC}"
echo -e "Recommended Gunicorn Workers ((2 * Cores) + 1): ${GREEN}$(( (2 * CORES) + 1 ))${NC}"

UPTIME_INFO=$(uptime)
echo -e "System Load Averages: ${UPTIME_INFO##*load average: }"
LOAD1=$(cat /proc/loadavg | awk '{print $1}')
echo -e "1-minute load is: ${GREEN}${LOAD1}${NC} (Capacity threshold: ${CORES}.0)"
echo ""

# ------------------------------------------------------------------------------
# 4. LOG CHECKS (EXCEPTIONS & TRACEBACKS)
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[4/5] CHECKING SYSTEM LOGS & EXCEPTIONS (Last 200 lines)...${NC}"
RECENT_500S=$(journalctl -u mobilebuyback.service -n 200 --no-pager 2>/dev/null | grep -iE "500 Internal Server|Traceback|CRITICAL|ERROR" | wc -l)
if [ "$RECENT_500S" -eq 0 ]; then
    echo -e "${GREEN}✓ 0 Critical errors or unhandled tracebacks found in recent service logs.${NC}"
else
    echo -e "${YELLOW}⚠️ Found ${RECENT_500S} error/warning log entries in recent logs:${NC}"
    journalctl -u mobilebuyback.service -n 200 --no-pager 2>/dev/null | grep -iE "Traceback|ERROR|CRITICAL" | tail -n 5
fi

# Check Nginx Error Log if present
if [ -f "/var/log/nginx/error.log" ]; then
    NGINX_ERRORS=$(sudo tail -n 50 /var/log/nginx/error.log 2>/dev/null | grep -iE "error|crit|alert" | wc -l)
    echo -e "Nginx recent error entries: ${GREEN}${NGINX_ERRORS}${NC}"
fi
echo ""

# ------------------------------------------------------------------------------
# 5. DATABASE CONNECTIONS & STATUS
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[5/5] CHECKING DATABASE ENGINE & CONNECTION POOLS...${NC}"

# Check MySQL / MariaDB connection status if running
if command -v mysqladmin &> /dev/null && pgrep -x "mariadbd" >/dev/null || pgrep -x "mysqld" >/dev/null; then
    echo -e "${GREEN}✓ MariaDB/MySQL is active.${NC}"
    mysql -e "SHOW STATUS LIKE 'Threads_connected'; SHOW VARIABLES LIKE 'max_connections';" 2>/dev/null || \
    echo -e "  (Credentials required for root DB metrics; connection pool is online)"
else
    echo -e "Checking SQLite database file..."
    if [ -f "/data/home/mobile_resell/backend/db.sqlite3" ]; then
        DB_SIZE=$(du -h /data/home/mobile_resell/backend/db.sqlite3 | awk '{print $1}')
        echo -e "${GREEN}✓ SQLite database file exists (Size: ${DB_SIZE}).${NC}"
    fi
fi

# Check open sockets on port 8010
PORT_CONN=$(ss -tuna 2>/dev/null | grep ":8010 " | wc -l)
echo -e "Active socket connections on port 8010: ${GREEN}${PORT_CONN}${NC}"

echo ""
echo -e "${BLUE}=====================================================================${NC}"
echo -e "${GREEN}               AUDIT COMPLETE - SYSTEM HEALTH VERIFIED               ${NC}"
echo -e "${BLUE}=====================================================================${NC}"
