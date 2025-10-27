#!/usr/bin/env bash
set -euo pipefail

gum spin --spinner dot --title "🔌 Applying manifests (deployments, service, ingress)..." -- \
kubectl apply -n "$KEMO_NS" --kustomize='.'
gum style --foreground green "✅ Base manifests applied"

echo "👀 Waiting for backends to become ready..."
kubectl rollout status -n "$KEMO_NS" deployment/endpoints-a
kubectl rollout status -n "$KEMO_NS" deployment/endpoints-b

echo "🔎 Discovering backend Pod IPs..."
IP_A=$(kubectl get pod -n "$KEMO_NS" -l app=endpoints-demo,version=a -o jsonpath='{.items[0].status.podIP}')
IP_B=$(kubectl get pod -n "$KEMO_NS" -l app=endpoints-demo,version=b -o jsonpath='{.items[0].status.podIP}')

if [[ -z "${IP_A}" || -z "${IP_B}" ]]; then
  gum style --foreground 196 "❌ Failed to resolve backend Pod IPs"
  echo "Got: IP_A='${IP_A}', IP_B='${IP_B}'"
  exit 1
fi

echo "🧩 Creating Endpoints for Service 'endpoints-demo' with IPs: ${IP_A}, ${IP_B}"
cat <<EOF | kubectl apply -n "$KEMO_NS" -f -
apiVersion: v1
kind: Endpoints
metadata:
  name: endpoints-demo
subsets:
- addresses:
  - ip: ${IP_A}
  - ip: ${IP_B}
  ports:
  - port: 80
    protocol: TCP
EOF

gum style --foreground green "✅ Endpoints applied"

echo "📊 Current objects:"
kubectl get pods,svc,endpoints,ingress -n "$KEMO_NS" -o wide

echo "🎉 Service is exposed via HTTPS at: https://endpoints-good.k8s.orb.local/"
echo "    The Service has no selector; routing is controlled by the Endpoints object."