#!/usr/bin/env bash

gum spin --spinner dot --title "🔌 Applying manifests..." -- \
kubectl apply -n "$KEMO_NS" --kustomize='.'
gum style --foreground green "✅ Manifests applied successfully"

echo "👀 Observing status..."
kubectl rollout status deployment/canary-stable -n $KEMO_NS
kubectl rollout status deployment/canary-canary -n $KEMO_NS
kubectl get svc -n $KEMO_NS
kubectl get ingress -n $KEMO_NS

# Detect NGINX versions from deployment images
stable_image=$(kubectl get pods -n "$KEMO_NS" -l app=canary,version=stable -o jsonpath='{.items[0].metadata.name}' )
canary_image=$(kubectl get pods -n "$KEMO_NS" -l app=canary,version=canary -o jsonpath='{.items[0].metadata.name}')
stable_version=$(kubectl exec -n "$KEMO_NS" "$stable_image" -- nginx -v 2>&1 | awk -F/ '{print $2}')
canary_version=$(kubectl exec -n "$KEMO_NS" "$canary_image" -- nginx -v 2>&1 | awk -F/ '{print $2}')
echo "Testing canary deployment..."
stable_count=0
canary_count=0
for i in $(seq 1 100); do
  version=$(curl -s canary.k8s.orb.local/nginx-version)
  if [[ "$version" == *"$stable_version"* ]]; then
    ((stable_count++))
  elif [[ "$version" == *"$canary_version"* ]]; then
    ((canary_count++))
  fi
done
echo "Stable NGINX version ($stable_version) responses: $stable_count"
echo "Canary NGINX version ($canary_version) responses: $canary_count"

echo "nginx-version" > ".url_path"
echo "🎉 Your \"bad\" canary app is now live. Press ctrl-k u to open the ${KEMO_DEMO} websites."
