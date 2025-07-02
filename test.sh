#!/bin/bash

# test-proxy.sh - Script to test proxy functionality

echo "=== Docker Proxy Test Setup with DNS ==="
echo

# Create necessary directories and files
mkdir -p squid-logs
echo "Created squid-logs directory"

# Check if Corefile exists
if [ ! -f "Corefile" ]; then
    echo "⚠️  Corefile not found. Please create it from the CoreDNS configuration artifact."
fi

# Start the services
echo "Starting Docker Compose services..."
docker-compose up -d

# Wait for services to be ready
echo "Waiting for services to start..."
sleep 10

# Test 1: Check if all services are running
echo "=== Test 1: Checking Service Status ==="
if docker-compose ps dns-server | grep -q "Up"; then
    echo "✓ DNS server is running"
else
    echo "✗ DNS server is not running"
fi

if docker-compose ps squid-proxy | grep -q "Up"; then
    echo "✓ Squid proxy is running"
else
    echo "✗ Squid proxy is not running"
    exit 1
fi

# Test 2: Test DNS resolution
echo
echo "=== Test 2: Testing DNS Resolution ==="
echo "Testing DNS resolution from test client:"
docker-compose exec test-client nslookup google.com || echo "✗ DNS resolution test failed"
echo
echo "Testing internal name resolution:"
docker-compose exec test-client nslookup squid-proxy || echo "✗ Internal DNS resolution failed"

# Test 3: Test direct connection to proxy
echo
echo "=== Test 3: Testing Proxy Connection ==="
if curl -x http://localhost:3128 -s http://httpbin.org/ip > /dev/null; then
    echo "✓ Proxy is accepting connections"
else
    echo "✗ Proxy connection failed"
fi

# Test 4: Test from inside container with DNS
echo
echo "=== Test 4: Testing from Test Client Container ==="
echo "Testing HTTP request through proxy:"
docker-compose exec test-client curl -s http://httpbin.org/ip || echo "✗ Test client request failed"
echo
echo "Testing hostname resolution + proxy:"
docker-compose exec test-client curl -s http://httpbin.org/user-agent || echo "✗ Hostname resolution + proxy failed"

# Test 5: Check proxy logs with detailed tracking
echo
echo "=== Test 5: Proxy Logging - Each Call Tracked ==="
if [ -f "./squid-logs/access.log" ]; then
    echo "Standard access logs (last 5 entries):"
    tail -5 ./squid-logs/access.log
    echo
fi

if [ -f "./squid-logs/detailed.log" ]; then
    echo "Detailed logs with full request info (last 5 entries):"
    tail -5 ./squid-logs/detailed.log
    echo
fi

echo "WebSocket/WSS connection test:"
docker-compose exec test-client curl -I -H "Connection: Upgrade" -H "Upgrade: websocket" -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" -H "Sec-WebSocket-Version: 13" http://echo.websocket.org || echo "WebSocket test connection attempted"

# Test 6: Test your application - automatic startup
echo
echo "=== Test 6: Your Application (Auto-Starting Download) ==="
echo "Your app-under-test container starts downloading immediately."
echo "Monitor these logs to verify proxy usage:"
echo
echo "1. Application logs: docker-compose logs -f app-under-test"
echo "2. Standard proxy logs: docker-compose logs -f squid-proxy"
echo "3. Detailed access logs: tail -f squid-logs/access.log"
echo "4. Enhanced detailed logs: tail -f squid-logs/detailed.log"
echo
echo "All HTTP/HTTPS/WSS requests from your app should appear in proxy logs."

echo
echo "=== WebSocket (WSS) Support Enabled ==="
echo "• WebSocket ports configured: 80, 443, 8080, 8443, 9001"
echo "• CONNECT method allowed for WebSocket upgrades"
echo "• Connection timeouts optimized for WebSocket"
echo "• Enhanced logging tracks all connection types"

echo
echo "=== Additional Testing Commands ==="
echo "• Test DNS resolution: docker-compose exec app-under-test nslookup google.com"
echo "• Test internal DNS: docker-compose exec app-under-test nslookup squid-proxy"
echo "• Check DNS logs: docker-compose logs dns-server"
echo "• Monitor all logs: docker-compose logs -f"
echo "• Watch detailed access logs: tail -f squid-logs/detailed.log"
echo "• Monitor app specifically: docker-compose logs -f app-under-test"
echo "• Check WebSocket connections: grep -i websocket squid-logs/access.log"
echo "• Stop services: docker-compose down"

echo
echo "=== Additional Testing Commands ==="
echo "• Monitor all logs: docker-compose logs -f"
echo "• Enter test client: docker-compose exec test-client sh"
echo "• Test with curl: docker-compose exec test-client curl -v http://httpbin.org/ip"
echo "• Check proxy stats: curl -x http://localhost:3128 http://httpbin.org/ip"
echo "• Stop services: docker-compose down"

echo
echo "=== DNS + Proxy Environment Variables Set ==="
echo "Your app-under-test container has:"
echo "• DNS Server: 172.20.0.10 (internal CoreDNS)"
echo "• HTTP_PROXY=http://squid-proxy:3128"
echo "• HTTPS_PROXY=http://squid-proxy:3128"
echo "• WSS_PROXY=http://squid-proxy:3128 (WebSocket support)"
echo "• NO_PROXY=localhost,127.0.0.1,squid-proxy,dns-server"
echo
echo "=== DNS Features ==="
echo "• Hostname resolution works for external domains"
echo "• Internal container name resolution"
echo "• DNS caching for performance"
echo "• DNS query logging for debugging"
echo
echo "=== Log Files for Call Tracking ==="
echo "• Standard: ./squid-logs/access.log"
echo "• Detailed: ./squid-logs/detailed.log (includes User-Agent, Referer, etc.)"
echo "• Cache: ./squid-logs/cache.log"
echo
echo "Each HTTP/HTTPS/WSS call will be logged with full details!"

# Real-time log monitoring function
echo
echo "=== Starting Real-time Log Monitor ==="
echo "Press Ctrl+C to stop monitoring..."
sleep 2

# Start monitoring logs in background
if [ -f "./squid-logs/detailed.log" ]; then
    echo "Watching detailed proxy logs for your app's connections..."
    tail -f ./squid-logs/detailed.log &
    TAIL_PID=$!
    
    # Wait for user interrupt
    trap "kill $TAIL_PID 2>/dev/null; echo; echo 'Log monitoring stopped.'; exit 0" INT
    wait $TAIL_PID
else
    echo "Detailed log file not created yet. Run 'tail -f squid-logs/detailed.log' after making some requests."
fi
