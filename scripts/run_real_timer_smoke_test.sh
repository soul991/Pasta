#!/bin/bash
set -euo pipefail

echo "=================================================="
echo "Running Section 33.7 Real-Timer Smoke Test (50x Loop)"
echo "=================================================="

swift run PastaTests --smoke-real-timer-50
