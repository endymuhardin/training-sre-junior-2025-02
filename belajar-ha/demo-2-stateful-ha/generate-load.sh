#!/bin/bash

# Generate continuous load on PostgreSQL for failover testing

DURATION=${1:-60}
WRITE_INTERVAL=${2:-1}

echo "=========================================="
echo "PostgreSQL Load Generator"
echo "=========================================="
echo "Duration: ${DURATION}s"
echo "Write interval: ${WRITE_INTERVAL}s"
echo "=========================================="
echo ""

start_time=$(date +%s)
success_count=0
error_count=0

while true; do
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))

    if [ $elapsed -ge $DURATION ]; then
        break
    fi

    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    name="LoadTest_$elapsed"
    email="load_$elapsed@example.com"

    # Try to insert data
    result=$(PGPASSWORD=postgres psql -h localhost -p 5432 -U postgres -d demodb \
        -c "INSERT INTO users (name, email) VALUES ('$name', '$email') RETURNING id;" \
        -t -A 2>&1)

    if echo "$result" | grep -q "^[0-9]*$"; then
        success_count=$((success_count + 1))
        echo "[$elapsed/${DURATION}s] ✓ Inserted user ID: $result (Total: $success_count)"
    else
        error_count=$((error_count + 1))
        echo "[$elapsed/${DURATION}s] ✗ Failed: $result (Errors: $error_count)"
    fi

    sleep $WRITE_INTERVAL
done

echo ""
echo "=========================================="
echo "Load Generation Complete"
echo "=========================================="
echo "Total successful writes: $success_count"
echo "Total errors: $error_count"
echo "Success rate: $(awk "BEGIN {printf \"%.2f\", ($success_count / ($success_count + $error_count)) * 100}")%"
echo "=========================================="

# Show final count
echo ""
echo "Final user count:"
PGPASSWORD=postgres psql -h localhost -p 5432 -U postgres -d demodb -c "SELECT COUNT(*) as total_users FROM users;"
