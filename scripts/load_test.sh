#!/usr/bin/env bash
set -euo pipefail

TARGET_URL=${TARGET_URL:-http://localhost:8000/predict}
SCRIPT=${SCRIPT:-load-testing/k6.js}
SCENARIO=${SCENARIO:-baseline}

echo "Running k6 scenario: ${SCENARIO}"
k6 run -e TARGET_URL="${TARGET_URL}" -e SCENARIO="${SCENARIO}" "${SCRIPT}"
