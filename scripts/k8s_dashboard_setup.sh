#!/usr/bin/env bash
set -euo pipefail

# Kubernetes Dashboard Setup for Kemo
# This script sets up the Kubernetes dashboard if not already installed

check_dashboard() {
  kubectl get deployment kubernetes-dashboard -n kubernetes-dashboard >/dev/null 2>&1
}

install_dashboard() {
  gum style --foreground cyan "🌐 Installing Kubernetes Dashboard..."
  
  gum spin --spinner globe --title "Downloading dashboard manifest..." -- \
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

  gum style --foreground green "✅ Dashboard installed"
}

create_admin_user() {
  gum style --foreground cyan "👤 Creating admin user for dashboard..."

  # Create service account
  kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF

  gum style --foreground green "✅ Admin user created"
}

get_token() {
  gum style --foreground cyan "🔑 Getting access token..."
  
  token=$(kubectl -n kubernetes-dashboard create token admin-user 2>/dev/null || \
           kubectl -n kubernetes-dashboard get secret admin-user-token -o jsonpath='{.data.token}' | base64 -d)
  
  if [[ -n "$token" ]]; then
    echo "$token" > /tmp/kemo-dashboard-token
    gum style --foreground green "✅ Token saved to /tmp/kemo-dashboard-token"
    gum style --foreground yellow "📋 Dashboard Token (copy this):"
    echo "$token"
  else
    gum style --foreground red "❌ Failed to get token"
    return 1
  fi
}

start_proxy() {
  gum style --foreground cyan "🚀 Starting kubectl proxy..."
  
  # Kill existing proxy if running
  pkill -f "kubectl proxy" || true
  
  # Start proxy in background
  kubectl proxy --port=8001 >/dev/null 2>&1 &
  proxy_pid=$!
  echo "$proxy_pid" > /tmp/kemo-proxy-pid
  
  sleep 2
  
  if kill -0 "$proxy_pid" 2>/dev/null; then
    gum style --foreground green "✅ Proxy started (PID: $proxy_pid)"
    gum style --foreground cyan "🌐 Dashboard URL: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
  else
    gum style --foreground red "❌ Failed to start proxy"
    return 1
  fi
}

open_browser() {
  url="http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
  
  if gum confirm "🌐 Open dashboard in browser?"; then
    if command -v open >/dev/null; then
      open "$url"
    elif command -v xdg-open >/dev/null; then
      xdg-open "$url"
    else
      gum style --foreground yellow "📋 Please open: $url"
    fi
  fi
}

main() {
  gum style --foreground cyan --bold "🌐 Kubernetes Dashboard Setup"
  echo

  # Check if dashboard is already installed
  if check_dashboard; then
    gum style --foreground green "✅ Dashboard already installed"
  else
    if gum confirm "📦 Dashboard not found. Install it?"; then
      install_dashboard
      gum spin --spinner dot --title "Waiting for dashboard to be ready..." -- sleep 10
    else
      gum style --foreground yellow "⏭️  Skipping dashboard installation"
      exit 0
    fi
  fi

  # Check if admin user exists
  if ! kubectl get serviceaccount admin-user -n kubernetes-dashboard >/dev/null 2>&1; then
    if gum confirm "👤 Create admin user for dashboard access?"; then
      create_admin_user
    fi
  else
    gum style --foreground green "✅ Admin user already exists"
  fi

  # Get access token
  if gum confirm "🔑 Get access token?"; then
    get_token
  fi

  # Start proxy
  if gum confirm "🚀 Start kubectl proxy for dashboard access?"; then
    start_proxy
    open_browser
    
    gum style --foreground cyan "💡 Tips:"
    echo "  • Use token from above to login to dashboard"
    echo "  • Token is also saved to /tmp/kemo-dashboard-token"
    echo "  • Proxy will run in background (PID in /tmp/kemo-proxy-pid)"
    echo "  • Stop proxy with: kill \$(cat /tmp/kemo-proxy-pid)"
  fi

  gum style --foreground green "🎉 Dashboard setup complete!"
}

# Handle cleanup on exit
cleanup() {
  if [[ -f /tmp/kemo-proxy-pid ]]; then
    proxy_pid=$(cat /tmp/kemo-proxy-pid)
    if kill -0 "$proxy_pid" 2>/dev/null; then
      gum style --foreground yellow "🛑 Stopping proxy..."
      kill "$proxy_pid"
      rm -f /tmp/kemo-proxy-pid
    fi
  fi
}

trap cleanup EXIT

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi