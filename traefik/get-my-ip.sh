#!/bin/bash
# Helper script to detect your current public IP address
# This is useful for configuring the Traefik dashboard IP whitelist

set -euo pipefail

echo "Detecting your public IP address..."
echo ""

# Try multiple services in case one is down
IP=""

if [ -z "$IP" ]; then
  IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || true)
fi

if [ -z "$IP" ]; then
  IP=$(curl -s --max-time 5 icanhazip.com 2>/dev/null || true)
fi

if [ -z "$IP" ]; then
  IP=$(curl -s --max-time 5 ipinfo.io/ip 2>/dev/null || true)
fi

if [ -z "$IP" ]; then
  echo "Error: Could not detect public IP address"
  echo "Please check your internet connection or manually visit: https://ifconfig.me"
  exit 1
fi

echo "Your public IP address: $IP"
echo ""
echo "To allow only your IP in the Traefik dashboard:"
echo "  CIDR notation: $IP/32"
echo ""
echo "To allow your entire /24 subnet (e.g., your ISP's range):"
echo "  CIDR notation: ${IP%.*}.0/24"
echo ""
echo "Use this value when deploying via GitHub Actions workflow."
