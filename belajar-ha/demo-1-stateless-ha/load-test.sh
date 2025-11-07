#!/bin/bash

# Load testing script to visualize load balancing and failover

URL=${1:-http://localhost:8080}
REQUESTS=${2:-100}
DELAY=${3:-0.5}

echo "=========================================="
echo "Load Testing HAProxy"
echo "=========================================="
echo "URL: $URL"
echo "Requests: $REQUESTS"
echo "Delay: ${DELAY}s between requests"
echo "=========================================="
echo ""

declare -A counts
total=0
errors=0

for i in $(seq 1 $REQUESTS); do
    response=$(curl -s -w "\n%{http_code}" $URL 2>/dev/null)
    http_code=$(echo "$response" | tail -1)
    body=$(echo "$response" | head -n -1)

    if [ "$http_code" = "200" ]; then
        # Extract instance name from HTML
        instance=$(echo "$body" | grep -o "NGINX Instance [0-9]" | head -1)

        if [ -n "$instance" ]; then
            counts["$instance"]=$((${counts["$instance"]:-0} + 1))
            total=$((total + 1))
            echo "[$i/$REQUESTS] ✓ $instance"
        else
            echo "[$i/$REQUESTS] ? Unknown instance"
        fi
    else
        errors=$((errors + 1))
        echo "[$i/$REQUESTS] ✗ Error: HTTP $http_code"
    fi

    sleep $DELAY
done

echo ""
echo "=========================================="
echo "Results Summary"
echo "=========================================="
echo "Total successful: $total"
echo "Total errors: $errors"
echo ""
echo "Distribution:"
for instance in "${!counts[@]}"; do
    count=${counts[$instance]}
    percentage=$(awk "BEGIN {printf \"%.1f\", ($count / $total) * 100}")
    bar=$(printf '█%.0s' $(seq 1 $(($count * 50 / $total))))
    printf "%-20s: %3d requests (%5.1f%%) %s\n" "$instance" $count $percentage "$bar"
done
echo "=========================================="
