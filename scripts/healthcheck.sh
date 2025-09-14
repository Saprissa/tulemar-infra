#!/bin/bash

echo "🏥 Running health checks..."

FAILED=0

# Check grocery app
if docker compose exec -T grocery-web python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/admin/login/')" 2>/dev/null; then
    echo "✅ Grocery app: OK"
else
    echo "❌ Grocery app: FAILED"
    FAILED=1
fi

# Check VIP app
if docker compose exec -T vipsite-web python -c "import urllib.request; urllib.request.urlopen('http://localhost:8001/admin/login/')" 2>/dev/null; then
    echo "✅ VIP app: OK"
else
    echo "❌ VIP app: FAILED"
    FAILED=1
fi

# Check databases
if docker compose exec -T grocery-db pg_isready -U grocery_user -d grocery_order_db >/dev/null 2>&1; then
    echo "✅ Grocery database: OK"
else
    echo "❌ Grocery database: FAILED"
    FAILED=1
fi

if docker compose exec -T vipsite-db pg_isready -U vipsite_user -d vipsite_guide_db >/dev/null 2>&1; then
    echo "✅ VIP database: OK"
else
    echo "❌ VIP database: FAILED"
    FAILED=1
fi

# Check Redis
if docker compose exec -T redis-grocery redis-cli ping >/dev/null 2>&1; then
    echo "✅ Grocery Redis: OK"
else
    echo "❌ Grocery Redis: FAILED"
    FAILED=1
fi

if docker compose exec -T redis-vip redis-cli -p 6380 ping >/dev/null 2>&1; then
    echo "✅ VIP Redis: OK"
else
    echo "❌ VIP Redis: FAILED"
    FAILED=1
fi

if [ $FAILED -eq 0 ]; then
    echo "✅ All health checks passed!"
else
    echo "❌ Some health checks failed!"
    exit 1
fi