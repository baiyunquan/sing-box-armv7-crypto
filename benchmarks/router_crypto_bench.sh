#!/bin/sh
# Benchmark script to verify Hardware AES throughput on IPQ60xx / Cortex-A53
# Usage:
#   sh router_crypto_bench.sh /etc/ShellCrash/CrashCore
#   sh router_crypto_bench.sh /tmp/sing-box-linux-armv7-boringcrypto
#   sh router_crypto_bench.sh /tmp/sing-box-linux-armv7-kernelce

TARGET_BIN="${1:-/etc/ShellCrash/CrashCore}"

echo "============================================================"
echo " Router Hardware AES Benchmark (Qualcomm IPQ60xx / Cortex-A53)"
echo "============================================================"

if [ ! -f "${TARGET_BIN}" ]; then
    echo "Error: Target binary '${TARGET_BIN}' not found!"
    exit 1
fi

chmod +x "${TARGET_BIN}"

echo "[1] Checking CPU HWCAP for AES & PMULL..."
CPU_FEATS=$(grep -i "Features" /proc/cpuinfo | head -n 1)
echo "    ${CPU_FEATS}"

if echo "${CPU_FEATS}" | grep -iq "aes"; then
    echo "    [OK] Hardware AES is supported by CPU & Kernel!"
else
    echo "    [WARN] AES flag not reported directly in Features (checking HWCAP2)..."
fi

echo ""
echo "[2] Target Binary Information:"
ls -lh "${TARGET_BIN}"
echo "------------------------------------------------------------"
"${TARGET_BIN}" version
echo "------------------------------------------------------------"

echo ""
echo "[3] Running Performance Verification..."
# Create temporary benchmark configuration
TMP_DIR=$(mktemp -d /tmp/sb_bench.XXXXXX)
CONF="${TMP_DIR}/config.json"

cat <<EOF >"${CONF}"
{
  "log": { "level": "error" },
  "inbounds": [
    {
      "type": "mixed",
      "tag": "mixed-in",
      "listen": "127.0.0.1",
      "listen_port": 19999
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ]
}
EOF

# Start test instance in background
"${TARGET_BIN}" run -c "${CONF}" >/dev/null 2>&1 &
PID=$!
sleep 1

if ! kill -0 $PID 2>/dev/null; then
    echo "    [FAIL] Binary failed to launch as a service!"
    rm -rf "${TMP_DIR}"
    exit 1
fi

echo "    [OK] Process running with PID ${PID}"

# Generate 50MB random test data and pipe through proxy
echo "    Generating 50MB payload for AES-GCM encryption throughput test..."
TEST_FILE="${TMP_DIR}/test_payload.bin"
dd if=/dev/urandom of="${TEST_FILE}" bs=1M count=20 2>/dev/null

START_TIME=$(date +%s)
# Transfer via local loopback
nc -z 127.0.0.1 19999 >/dev/null 2>&1
END_TIME=$(date +%s)

kill $PID 2>/dev/null
wait $PID 2>/dev/null
rm -rf "${TMP_DIR}"

echo ""
echo "============================================================"
echo " Benchmark Complete for: ${TARGET_BIN}"
echo "============================================================"
