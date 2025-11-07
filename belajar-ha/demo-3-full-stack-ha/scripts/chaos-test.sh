#!/bin/bash

# Chaos testing - simulate various failure scenarios

scenario=${1:-help}

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

show_help() {
    echo "=========================================="
    echo "Chaos Testing Tool"
    echo "=========================================="
    echo ""
    echo "Usage: $0 <scenario>"
    echo ""
    echo "Scenarios:"
    echo "  1  - Kill one application instance (app1)"
    echo "  2  - Kill both application instances"
    echo "  3  - Kill master load balancer (haproxy1)"
    echo "  4  - Kill both load balancers"
    echo "  5  - Kill database primary"
    echo "  6  - Kill database replica"
    echo "  7  - Cascade failure (app1 → haproxy1 → db-replica)"
    echo "  8  - Network partition (disconnect haproxy1)"
    echo "  9  - Restore all services"
    echo "  all - Run all scenarios in sequence"
    echo ""
    echo "Example: $0 1"
    echo ""
}

wait_time() {
    local seconds=${1:-5}
    echo -e "${YELLOW}Waiting ${seconds}s for system to stabilize...${NC}"
    sleep $seconds
}

check_status() {
    echo ""
    echo -e "${YELLOW}Current Status:${NC}"
    docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "(haproxy|app|postgres)" || echo "No services running"
    echo ""
}

scenario_1() {
    echo -e "${RED}[Scenario 1] Killing app1...${NC}"
    docker stop app1
    wait_time 3
    check_status
    echo -e "${GREEN}Expected: Traffic should route only to app2${NC}"
}

scenario_2() {
    echo -e "${RED}[Scenario 2] Killing both app instances...${NC}"
    docker stop app1 app2
    wait_time 3
    check_status
    echo -e "${GREEN}Expected: Service unavailable (503)${NC}"
}

scenario_3() {
    echo -e "${RED}[Scenario 3] Killing master load balancer (haproxy1)...${NC}"
    docker stop haproxy1
    wait_time 3
    echo "Checking VIP ownership:"
    docker exec haproxy2 ip addr show eth0 2>/dev/null | grep "172.30.0.100" && \
        echo -e "${GREEN}✓ VIP moved to haproxy2${NC}" || \
        echo -e "${RED}✗ VIP not found${NC}"
    check_status
    echo -e "${GREEN}Expected: VIP fails over to haproxy2, minimal downtime${NC}"
}

scenario_4() {
    echo -e "${RED}[Scenario 4] Killing both load balancers...${NC}"
    docker stop haproxy1 haproxy2
    wait_time 3
    check_status
    echo -e "${GREEN}Expected: Complete service outage${NC}"
}

scenario_5() {
    echo -e "${RED}[Scenario 5] Killing database primary...${NC}"
    docker stop postgres-primary
    wait_time 3
    check_status
    echo -e "${GREEN}Expected: Writes fail, reads still work from replica${NC}"
}

scenario_6() {
    echo -e "${RED}[Scenario 6] Killing database replica...${NC}"
    docker stop postgres-replica1
    wait_time 3
    check_status
    echo -e "${GREEN}Expected: App falls back to reading from primary${NC}"
}

scenario_7() {
    echo -e "${RED}[Scenario 7] Cascade failure...${NC}"
    echo "Step 1: Kill app1"
    docker stop app1
    wait_time 2

    echo "Step 2: Kill haproxy1"
    docker stop haproxy1
    wait_time 2

    echo "Step 3: Kill postgres-replica1"
    docker stop postgres-replica1
    wait_time 2

    check_status
    echo -e "${GREEN}Expected: System degraded but still functional${NC}"
}

scenario_8() {
    echo -e "${RED}[Scenario 8] Network partition - disconnect haproxy1...${NC}"
    docker network disconnect demo-3-full-stack-ha_fullstack-net haproxy1 2>/dev/null
    wait_time 3
    check_status
    echo -e "${GREEN}Expected: VIP fails over to haproxy2${NC}"
}

scenario_9() {
    echo -e "${GREEN}[Scenario 9] Restoring all services...${NC}"

    # Reconnect network if disconnected
    docker network connect demo-3-full-stack-ha_fullstack-net haproxy1 2>/dev/null

    # Start all containers
    docker start app1 app2 haproxy1 haproxy2 postgres-primary postgres-replica1 2>/dev/null

    wait_time 10
    check_status
    echo -e "${GREEN}✓ All services restored${NC}"
}

run_all() {
    echo "=========================================="
    echo "Running ALL Chaos Scenarios"
    echo "=========================================="
    echo ""

    for i in {1..8}; do
        scenario_$i
        echo ""
        echo -e "${YELLOW}Testing application accessibility...${NC}"
        curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://localhost:8080/api/stats
        echo ""
        read -p "Press Enter to continue to next scenario..."
        echo ""

        # Restore before next scenario (except for last one)
        if [ $i -lt 8 ]; then
            scenario_9
            wait_time 5
        fi
    done

    scenario_9
}

# Main
case $scenario in
    1) scenario_1 ;;
    2) scenario_2 ;;
    3) scenario_3 ;;
    4) scenario_4 ;;
    5) scenario_5 ;;
    6) scenario_6 ;;
    7) scenario_7 ;;
    8) scenario_8 ;;
    9) scenario_9 ;;
    all) run_all ;;
    help|*) show_help ;;
esac
