#!/bin/bash

# Generate continuous load on full stack

DURATION=${1:-60}
WRITE_INTERVAL=${2:-2}
READ_INTERVAL=${3:-1}

BASE_URL="http://localhost:8080"

echo "=========================================="
echo "Full Stack Load Generator"
echo "=========================================="
echo "Duration: ${DURATION}s"
echo "Write interval: ${WRITE_INTERVAL}s"
echo "Read interval: ${READ_INTERVAL}s"
echo "=========================================="
echo ""

start_time=$(date +%s)
write_success=0
write_error=0
read_success=0
read_error=0
last_write=0

# Function to do writes
do_write() {
    timestamp=$(date +%s)
    name="LoadUser_$timestamp"
    email="load_${timestamp}@example.com"

    response=$(curl -s -w "\n%{http_code}" -X POST $BASE_URL/api/users \
        -H "Content-Type: application/json" \
        -d "{\"name\":\"$name\",\"email\":\"$email\"}" 2>&1)

    http_code=$(echo "$response" | tail -1)
    body=$(echo "$response" | head -n -1)

    if [ "$http_code" = "201" ]; then
        app=$(echo "$body" | python3 -c "import sys, json; print(json.load(sys.stdin)['app_instance'])" 2>/dev/null || echo "unknown")
        db=$(echo "$body" | python3 -c "import sys, json; print(json.load(sys.stdin)['database'])" 2>/dev/null || echo "unknown")
        write_success=$((write_success + 1))
        echo "[WRITE] ✓ Created user via $app → $db"
    else
        write_error=$((write_error + 1))
        echo "[WRITE] ✗ Failed (HTTP $http_code)"
    fi
}

# Function to do reads
do_read() {
    response=$(curl -s -w "\n%{http_code}" $BASE_URL/api/stats 2>&1)
    http_code=$(echo "$response" | tail -1)
    body=$(echo "$response" | head -n -1)

    if [ "$http_code" = "200" ]; then
        app=$(echo "$body" | python3 -c "import sys, json; print(json.load(sys.stdin)['app_instance'])" 2>/dev/null || echo "unknown")
        db=$(echo "$body" | python3 -c "import sys, json; print(json.load(sys.stdin)['database_host'])" 2>/dev/null || echo "unknown")
        role=$(echo "$body" | python3 -c "import sys, json; print(json.load(sys.stdin)['database_role'])" 2>/dev/null || echo "unknown")
        users=$(echo "$body" | python3 -c "import sys, json; print(json.load(sys.stdin)['total_users'])" 2>/dev/null || echo "?")
        read_success=$((read_success + 1))
        echo "[READ]  ✓ Stats from $app → $db ($role) - $users users"
    else
        read_error=$((read_error + 1))
        echo "[READ]  ✗ Failed (HTTP $http_code)"
    fi
}

# Main loop
while true; do
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))

    if [ $elapsed -ge $DURATION ]; then
        break
    fi

    # Write operation
    if [ $((elapsed - last_write)) -ge $WRITE_INTERVAL ]; then
        do_write
        last_write=$elapsed
    fi

    # Read operation
    do_read

    sleep $READ_INTERVAL
done

echo ""
echo "=========================================="
echo "Load Generation Complete"
echo "=========================================="
echo "Writes - Success: $write_success, Errors: $write_error"
echo "Reads  - Success: $read_success, Errors: $read_error"

if [ $((write_success + write_error)) -gt 0 ]; then
    write_rate=$(awk "BEGIN {printf \"%.2f\", ($write_success / ($write_success + $write_error)) * 100}")
    echo "Write success rate: ${write_rate}%"
fi

if [ $((read_success + read_error)) -gt 0 ]; then
    read_rate=$(awk "BEGIN {printf \"%.2f\", ($read_success / ($read_success + $read_error)) * 100}")
    echo "Read success rate: ${read_rate}%"
fi

echo "=========================================="
