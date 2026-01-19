#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Kubernetes Fundamentals - Introduction
# Based on: https://garnaudov.com/writings/how-i-think-about-kubernetes/
# ============================================================================

gum style \
  --border double \
  --border-foreground 212 \
  --padding "1 2" \
  --margin "1" \
  "🎓 Kubernetes Fundamentals" \
  "" \
  "Think of Kubernetes as a RUNTIME for declarative infrastructure" \
  "with a TYPE SYSTEM - not just an orchestrator."

gum confirm "Ready to explore Kubernetes concepts?" || exit 0

# ----------------------------------------------------------------------------
# SECTION 1: The Type System
# ----------------------------------------------------------------------------
gum style \
  --border rounded \
  --border-foreground 39 \
  --padding "1 2" \
  --margin "1" \
  "📦 CONCEPT 1: The Type System" \
  "" \
  "Kubernetes has a vocabulary of resource 'kinds' that behave like types:" \
  "" \
  "  • Pod        - smallest schedulable unit (like a container wrapper)" \
  "  • Deployment - manages Pods with rollouts and replicas" \
  "  • Service    - stable network identity for Pods" \
  "  • Ingress    - routes external traffic to Services" \
  "" \
  "Each type has strict definitions, valid fields, and semantics." \
  "Think: int, string, bool → Pod, Deployment, Service"

gum confirm "Continue to see these types in action?" || exit 0

# ----------------------------------------------------------------------------
# SECTION 2: Declaring Intent
# ----------------------------------------------------------------------------
gum style \
  --border rounded \
  --border-foreground 220 \
  --padding "1 2" \
  --margin "1" \
  "📝 CONCEPT 2: Declaring Intent" \
  "" \
  "When you 'kubectl apply', you're not running a script." \
  "You're submitting a DECLARATION of desired state." \
  "" \
  "The runtime then works CONTINUOUSLY to make reality match your intent."

echo ""
gum style --foreground 245 "Let's apply our manifests and watch the runtime work..."
echo ""

gum spin --spinner dot --title "🔌 Applying manifests (declaring intent)..." -- \
  kubectl apply -n "$KEMO_NS" --kustomize='.'
gum style --foreground green "✅ Intent declared! The runtime now knows what you want."

echo ""
gum style --foreground 245 "Watching the Deployment roll out..."
kubectl rollout status deployment/k8s-intro -n "$KEMO_NS"

# ----------------------------------------------------------------------------
# SECTION 3: The Runtime Loop
# ----------------------------------------------------------------------------
gum style \
  --border rounded \
  --border-foreground 161 \
  --padding "1 2" \
  --margin "1" \
  "🔄 CONCEPT 3: The Runtime Loop" \
  "" \
  "declare → persist → reconcile → place → execute" \
  "" \
  "This loop runs CONTINUOUSLY. That's the key insight!" \
  "" \
  "Controllers watch for changes and take actions to reduce" \
  "the difference between desired state and actual state."

gum confirm "See current pods?" || exit 0

echo ""
gum style --foreground 245 "Current pods in namespace $KEMO_NS:"
kubectl get pods -n "$KEMO_NS" -o wide

# ----------------------------------------------------------------------------
# SECTION 4: Self-Healing / Reconciliation Demo
# ----------------------------------------------------------------------------
gum style \
  --border rounded \
  --border-foreground 213 \
  --padding "1 2" \
  --margin "1" \
  "🔧 CONCEPT 4: Reconciliation (Self-Healing)" \
  "" \
  "What happens when we DELETE a pod?" \
  "" \
  "The Deployment controller notices the actual state (1 pod)" \
  "doesn't match desired state (2 pods) and RECREATES it!" \
  "" \
  "This is why manual fixes often don't work - the runtime" \
  "enforces the meaning of your declarations."

POD_TO_DELETE=$(kubectl get pods -n "$KEMO_NS" -l app=k8s-intro -o jsonpath='{.items[0].metadata.name}')

gum confirm "Delete pod '$POD_TO_DELETE' and watch it recreate?" || exit 0

echo ""
gum style --foreground 220 "🗑️  Deleting pod: $POD_TO_DELETE"
kubectl delete pod "$POD_TO_DELETE" -n "$KEMO_NS" --wait=false

echo ""
gum style --foreground 245 "Watch the reconciliation happen (a new pod will appear):"
sleep 2
kubectl get pods -n "$KEMO_NS" -l app=k8s-intro -w &
WATCH_PID=$!
sleep 8
kill $WATCH_PID 2>/dev/null || true

echo ""
gum style --foreground green "✅ The runtime recreated the pod to match desired state!"

# ----------------------------------------------------------------------------
# SECTION 5: spec vs status
# ----------------------------------------------------------------------------
gum style \
  --border rounded \
  --border-foreground 84 \
  --padding "1 2" \
  --margin "1" \
  "📊 CONCEPT 5: spec vs status" \
  "" \
  "Every Kubernetes resource has two key sections:" \
  "" \
  "  • spec   = what you WANT (your input/declaration)" \
  "  • status = what the runtime OBSERVED (output/reality)" \
  "" \
  "This is how you debug: Is the runtime progressing toward spec?" \
  "What does status say about why it isn't?"

gum confirm "View the Deployment's spec and status?" || exit 0

echo ""
gum style --foreground 39 "=== SPEC (what you declared) ==="
kubectl get deployment k8s-intro -n "$KEMO_NS" -o jsonpath='{.spec}' | jq '.'

echo ""
gum style --foreground 84 "=== STATUS (what the runtime observed) ==="
kubectl get deployment k8s-intro -n "$KEMO_NS" -o jsonpath='{.status}' | jq '.'

# ----------------------------------------------------------------------------
# Summary
# ----------------------------------------------------------------------------
gum style \
  --border double \
  --border-foreground 212 \
  --padding "1 2" \
  --margin "1" \
  "🎉 Key Takeaways" \
  "" \
  "1. Kubernetes is a RUNTIME with a TYPE SYSTEM" \
  "2. You DECLARE intent, the runtime makes it real" \
  "3. The reconciliation loop runs CONTINUOUSLY" \
  "4. spec = input, status = output" \
  "5. Change desired state, not symptoms" \
  "" \
  "Your app is now live at: https://${KEMO_DEMO}.k8s.orb.local" \
  "" \
  "Press ctrl-k u to open the website."
