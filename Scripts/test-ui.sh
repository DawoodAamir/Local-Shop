#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 Server/server.py > /tmp/local-shop-server.log 2>&1 &
shop_server_pid=$!
trap 'kill "$shop_server_pid" 2>/dev/null || true' EXIT
for attempt in {1..20}; do
  if curl --fail --silent http://localhost:8080/health > /dev/null; then break; fi
  sleep 1
done
shop_simulator_id=$(xcrun simctl list devices available -j | python3 -c 'import json,sys; devices=json.load(sys.stdin)["devices"]; print(next(d["udid"] for group in devices.values() for d in group if d["name"].startswith("iPhone")))')
xcodebuild -project 'Local Shop.xcodeproj' -scheme 'Local Shop' \
  -destination "platform=iOS Simulator,id=$shop_simulator_id" \
  -parallel-testing-enabled NO -derivedDataPath build \
  -resultBundlePath build/Shopping.xcresult test
