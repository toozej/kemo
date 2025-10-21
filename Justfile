set shell := ["bash", "-cu"]

k8s-provider := `if command -v orb &>/dev/null; then echo orbstack; else echo minikube; fi`

default:
    @just --choose

# Preferred Kubernetes setup: OrbStack or fallback to Minikube
kubernetes-setup:
    @gum style --foreground cyan "⚙️ Setting up Kubernetes environment..."
    @if [[ "{{k8s-provider}}" == "orbstack" ]]; then \
        gum style --foreground green '🟢 OrbStack detected, using OrbStack'; \
        just start-orbstack; \
        just use-orbstack; \
        just install-ingress-nginx-https; \
        just setup-https; \
        just install-kubernetes-dashboard; \
        just configure-hosts dashboard; \
    else \
        gum style --foreground blue '🔵 OrbStack not found, falling back to Minikube'; \
        just start-minikube; \
        just use-minikube; \
        just install-ingress-nginx-https; \
        just setup-https; \
        just install-kubernetes-dashboard; \
        just configure-hosts dashboard; \
    fi

kubernetes-cleanup:
    @gum style --foreground yellow "🧼 Cleaning up Kubernetes environment..."
    @if [[ "{{k8s-provider}}" == "orbstack" ]]; then \
        gum style --foreground yellow '🧹 Cleaning up OrbStack...'; \
        just clean-orbstack; \
    else \
        gum style --foreground yellow '🧹 Cleaning up Minikube...'; \
        just clean-minikube; \
    fi
    just kubectl-cleanup

kubectl-cleanup:
    #!/usr/bin/env bash
    set -euo pipefail
    gum style --foreground yellow "🧼 Cleaning up custom kubectl contexts..."
    current="$(kubectl config current-context 2>/dev/null || echo '')"
    if [[ -n "$current" ]]; then
        gum style --foreground yellow "🔄 Unsetting current context: $current"
        kubectl config unset current-context
    else
        gum style --foreground yellow "⚠️  No current context set. Proceeding to delete all contexts."
    fi
    gum spin --spinner dot --title "Finding contexts..." -- sleep 0.5
    for ctx in $(kubectl config get-contexts -o name); do
        gum style --foreground red "🗑️  Deleting context: $ctx";
        kubectl config delete-context "$ctx";
    done
    gum style --foreground yellow "✅ Cleanup of custom kubectl contexts complete"
    if gum confirm "Also delete unused users and clusters?"; then
        gum style --foreground yellow "🧹 Deleting users..."
        for user in $(kubectl config get-users | tail -n +2); do
            if [[ "$user" == "NAME" || -z "$user" ]]; then continue; fi
            gum style --foreground red "🗑️  Deleting user: $user"
            kubectl config delete-user "$user"
        done
        gum style --foreground yellow "🧹 Deleting clusters..."
        for cluster in $(kubectl config get-clusters | tail -n +2); do
            if [[ "$cluster" == "NAME" || -z "$cluster" ]]; then continue; fi
            gum style --foreground red "🗑️  Deleting cluster: $cluster"
            kubectl config delete-cluster "$cluster"
        done
        gum style --foreground yellow "✅ Cleanup of custom kubectl users and clusters complete"
    fi

start-orbstack:
    @gum style --foreground green "🚀 Starting OrbStack Kubernetes..."
    @gum spin --spinner globe --title "Starting OrbStack..." -- orb start k8s
    @gum spin --spinner dot --title "Waiting for Kubernetes cluster..." -- \
        bash -c 'for i in {1..60}; do kubectl cluster-info &>/dev/null && exit 0; sleep 1; done; exit 1'

use-orbstack:
    @gum spin --spinner dot --title "Waiting for OrbStack context..." -- \
        bash -c 'for i in {1..30}; do kubectl config get-contexts -o name | grep -q "^orbstack$" && exit 0; sleep 1; done; exit 1'
    @kubectl config use-context orbstack
    @gum style --foreground yellow "😴 Waiting for cluster to fully spin up..."
    @gum spin --spinner moon --title "Initializing cluster..." -- \
        bash -c 'for i in {1..30}; do kubectl get nodes --context=orbstack &>/dev/null && exit 0; sleep 1; done; exit 1'
    @gum style --foreground green "✅ OrbStack cluster ready"

clean-orbstack:
    @gum style --foreground yellow "🧼 Stopping OrbStack Kubernetes..."
    @if gum confirm "This will destroy the OrbStack cluster. Continue?"; then \
        gum spin --spinner dot --title "Stopping OrbStack..." -- orb stop k8s; \
        gum spin --spinner dot --title "Deleting OrbStack..." -- orb delete --force k8s; \
    fi

start-minikube:
    @gum style --foreground green "🚀 Starting Minikube..."
    @if ! minikube status >/dev/null 2>&1; then \
        gum spin --spinner globe --title "Starting Minikube..." -- minikube start; \
    else \
        gum style --foreground green "✅ Minikube already running"; \
    fi

use-minikube:
    @gum style --foreground cyan "🔗 Setting kubectl context to Minikube..."
    @kubectl config use-context minikube
    @gum style --foreground yellow "😴 Waiting for cluster to fully spin up..."
    @gum spin --spinner moon --title "Initializing cluster..." -- \
        bash -c 'for i in {1..30}; do kubectl get nodes --context=minikube &>/dev/null && exit 0; sleep 1; done; exit 1'
    @gum style --foreground green "✅ Minikube cluster ready"

clean-minikube:
    @gum style --foreground yellow "🧹 Stopping and deleting Minikube..."
    @if gum confirm "This will destroy the Minikube cluster. Continue?"; then \
        gum spin --spinner dot --title "Deleting Minikube..." -- minikube delete; \
    fi

install-ingress-nginx-https:
    @gum style --foreground cyan "🔧 Installing Ingress-NGINX with HTTPS support..."
    @gum spin --spinner dot --title "Installing Ingress-NGINX..." -- \
        helm upgrade --install ingress-nginx ingress-nginx \
        --repo https://kubernetes.github.io/ingress-nginx \
        --namespace ingress-nginx --create-namespace
    @gum spin --spinner dot --title "Waiting for Ingress-NGINX to be ready..." -- \
        kubectl wait -n ingress-nginx --for=condition=Ready pod -l app.kubernetes.io/component=controller --timeout=120s
    @gum style --foreground green "✅ Ingress-NGINX with HTTPS support installed"

install-kubernetes-dashboard:
    @gum style --foreground cyan "🔧 Installing Kubernetes Dashboard via Helm..."
    @gum spin --spinner dot --title "Adding dashboard repo..." -- \
        helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
    @gum spin --spinner dot --title "Updating Helm repos..." -- \
        helm repo update
    @gum spin --spinner dot --title "Installing dashboard..." -- \
        helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard  --create-namespace --namespace kubernetes-dashboard
    @gum spin --spinner dot --title "Configuring dashboard-user..." -- \
        kubectl apply --namespace kubernetes-dashboard -f ./manifests/kubernetes-dashboard-sa.yaml && sleep 1
    @gum spin --spinner dot --title "Creating TLS secret for dashboard..." -- \
        just create-tls-secret kubernetes-dashboard && sleep 1
    @gum spin --spinner dot --title "Setting up dashboard ingress..." -- \
        kubectl apply -f ./manifests/kubernetes-dashboard-ingress.yaml && sleep 1

create-namespace demo variant k8s-provider:
    #!/usr/bin/env bash
    set -euo pipefail
    ns="${KEMO_NAMESPACE:-{{demo}}-{{variant}}}"
    gum style --foreground cyan "📂 Creating namespace '$ns'..."
    gum spin --spinner dot --title "Setting up namespace..." -- sleep 0.5
    kubectl get namespace "$ns" >/dev/null 2>&1 || kubectl create namespace "$ns"
    kubectl config set-context "$ns" --cluster {{k8s-provider}} --user {{k8s-provider}} --namespace "$ns"
    kubectl config use-context "$ns"
    gum style --foreground green "✅ Namespace '$ns' ready"

apply-manifests demo variant:
    #!/usr/bin/env bash
    set -euo pipefail
    ns="${KEMO_NAMESPACE:-{{demo}}-{{variant}}}"
    gum style --foreground cyan "📂 Applying manifests for '{{demo}}/{{variant}}'..."
    if [[ "${KEMO_DRY_RUN:-false}" == "true" ]]; then
        gum style --foreground blue "🔍 DRY RUN: Would execute:"
        gum style --foreground white "kubectl apply -n $ns -k demos/{{demo}}/{{variant}}"
    else
        gum spin --spinner dot --title "Applying manifests..." -- \
        kubectl apply -n "$ns" -k demos/{{demo}}/{{variant}}
        gum style --foreground green "✅ Manifests applied successfully"
    fi

select-demo:
    @scripts/select-demo.sh

run-demo demo variant full_setup="true":
    @gum style --foreground green --bold "🎬 Starting demo: {{demo}}/{{variant}}"
    @echo
    @if [[ "{{full_setup}}" == "true" ]]; then \
        just kubernetes-setup; \
    fi
    @just create-namespace {{demo}} {{variant}} {{k8s-provider}}
    @just configure-https "" {{demo}} {{variant}}
    @scripts/run-demo.sh {{demo}} {{variant}} run bash demos/{{demo}}/{{variant}}/run.sh
    @if [[ "${KEMO_SKIP_CLEANUP:-false}" != "true" ]]; then \
        echo; \
        if gum confirm "🧹 Clean up resources?"; then \
            if [[ "{{full_setup}}" == "true" ]]; then \
                just kubernetes-cleanup; \
            else \
                just clean-demo-namespace {{demo}} {{variant}}; \
            fi; \
        fi; \
    fi

install-deps:
    @echo "🔧 Installing prerequisites for Kemo..."
    @if [ "$(uname)" = "Darwin" ]; then \
        echo "🍎 Detected macOS. Installing with brew..."; \
        brew install minikube kubectl gum yq tmux helm nss mkcert; \
        mkcert -install; \
    elif [ -f /etc/debian_version ]; then \
        echo "🐧 Detected Debian-based Linux. Installing with apt..."; \
        sudo apt update && sudo apt install -y jq yq tmux curl gnupg lsb-release software-properties-common libnss3-tools mkcert; \
        curl -s -LO https://storage.googleapis.com/minikube/releases/latest/minikube_latest_amd64.deb && \
        sudo dpkg -i minikube_latest_amd64.deb && \
        rm minikube_latest_amd64.deb; \
        curl -s https://api.github.com/repos/charmbracelet/gum/releases/latest \
          | jq -r ".assets[] | select(.name | test(\"gum_.*_Linux_x86_64.tar.gz\")) | .browser_download_url" \
          | xargs curl -L | tar xz && sudo mv gum /usr/local/bin/; \
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash; \
        mkcert -install; \
    elif [ -f /etc/redhat-release ]; then \
        echo "🐧 Detected RHEL-based Linux. Installing with dnf..."; \
        sudo dnf install -y jq yq tmux helm nss-tools mkcert; \
        curl -s -LO https://storage.googleapis.com/minikube/releases/latest/minikube-latest.x86_64.rpm && \
        sudo rpm -Uvh minikube-latest.x86_64.rpm && \
        rm minikube-latest.x86_64.rpm; \
        curl -s https://api.github.com/repos/charmbracelet/gum/releases/latest \
          | jq -r ".assets[] | select(.name | test(\"gum_.*_Linux_x86_64.tar.gz\")) | .browser_download_url" \
          | xargs curl -L | tar xz && sudo mv gum /usr/local/bin/; \
        mkcert -install; \
    else \
        echo "❌ Unsupported system. Please install minikube, kubectl, gum, yq, helm, tmux, and mkcert manually."; \
        exit 1; \
    fi
    @gum style --foreground green "✅ All dependencies installed successfully!"

# Interactive demo browser with metadata preview
browse-demos:
    @gum style --foreground cyan --bold "🧪 Kemo Demo Browser"
    @echo
    @demos_json="/tmp/kemo-demos.json"
    @find demos -name metadata.yaml | while read metadata; do \
        dir=$(dirname "$metadata"); \
        relpath="${dir#demos/}"; \
        demo="${relpath%/*}"; \
        variant="${relpath##*/}"; \
        name=$(yq e '.name' "$metadata"); \
        desc=$(yq e '.description' "$metadata" | head -n 1); \
        tags=$(yq e '.tags // [] | join(", ")' "$metadata"); \
        echo "{\"demo\":\"$demo\",\"variant\":\"$variant\",\"name\":\"$name\",\"desc\":\"$desc\",\"tags\":\"$tags\",\"path\":\"$metadata\"}"; \
    done | jq -s '.' > "$demos_json"
    @cat "$demos_json" | jq -r '.[] | "\(.demo)/\(.variant) - \(.name)"' | \
    gum filter --placeholder "Search demos..." | \
    head -n 1 | \
    while read selection; do \
        if [[ -n "$selection" ]]; then \
            demo_variant=$(echo "$selection" | cut -d' ' -f1); \
            demo=${demo_variant%/*}; \
            variant=${demo_variant#*/}; \
            metadata_path=$(cat "$demos_json" | jq -r ".[] | select(.demo == \"$demo\" and .variant == \"$variant\") | .path"); \
            gum style --foreground green "Selected: $demo/$variant"; \
            echo; \
            yq e '.' "$metadata_path" | gum pager; \
            if gum confirm "Run this demo?"; then \
                just run-demo "$demo" "$variant"; \
            fi; \
        fi; \
    done
    @rm -f "$demos_json"

# Health check for the Kemo environment
health-check:
    #!/usr/bin/env bash
    set -euo pipefail
    gum style --foreground cyan --bold "🏥 Kemo Health Check"
    checks=("kubectl" "gum" "yq" "tmux" "helm" "just")
    for cmd in ${checks[@]}; do
        if command -v "$cmd" >/dev/null 2>&1; then
            gum style --foreground green "✅ $cmd available"
        else
            gum style --foreground red "❌ $cmd missing"
        fi
    done
    if kubectl cluster-info >/dev/null 2>&1; then
        gum style --foreground green "✅ Kubernetes cluster accessible"
        current_context=$(kubectl config current-context 2>/dev/null || echo "none")
        gum style --foreground cyan "📋 Current context: $current_context"
    else
        gum style --foreground yellow "⚠️  Kubernetes cluster not accessible"
    fi
    demo_count=$(find demos -name metadata.yaml | wc -l)
    gum style --foreground cyan "📦 Total demos available: $demo_count"

# Alias for run-demo with full_setup=false
rapid-demo demo variant:
    @just run-demo {{demo}} {{variant}} false

clean-demo-namespace demo variant:
    #!/usr/bin/env bash
    set -euo pipefail
    ns="${KEMO_NAMESPACE:-{{demo}}-{{variant}}}"
    gum style --foreground cyan "🧹 Cleaning up demo namespace '$ns'..."
    if kubectl get namespace "$ns" >/dev/null 2>&1; then
        gum spin --spinner dot --title "Deleting namespace resources..." -- \
            kubectl delete namespace "$ns" --timeout=60s --ignore-not-found=true
        gum style --foreground green "✅ Demo namespace '$ns' cleaned up"
    else
        gum style --foreground yellow "⚠️  Namespace '$ns' not found"
    fi

configure-https namespace="demo" demo="" variant="":
    #!/usr/bin/env bash
    set -euo pipefail
    # Determine namespace and display format
    if [[ -n "{{variant}}" && -n "{{demo}}" ]]; then
        # Variant format
        ACTUAL_NAMESPACE="{{demo}}-{{variant}}"
        DISPLAY_NAME="{{variant}}.{{demo}}.demo.local"
        gum style --foreground cyan "🔒 Configuring HTTPS for '{{demo}}/{{variant}}'..."
    else
        # Simple format
        ACTUAL_NAMESPACE="{{namespace}}"
        DISPLAY_NAME="{{namespace}}.demo.local"
        gum style --foreground cyan "🔒 Configuring HTTPS for namespace '{{namespace}}'..."
    fi
    # Create TLS secret
    just create-tls-secret "$ACTUAL_NAMESPACE"
    # Configure hosts entry
    just configure-hosts "$ACTUAL_NAMESPACE" "{{demo}}" "{{variant}}"
    # Apply HTTPS ingress configuration only for variant format (demos)
    if [[ -n "{{variant}}" && -n "{{demo}}" ]]; then
        gum style --foreground green "✅ HTTPS configured for '{{demo}}/{{variant}}'"
        gum style --foreground cyan "🌐 Access your demo at: https://$DISPLAY_NAME"
    else
        # Apply HTTPS ingress configuration for simple namespace format
        sed "s/demo-service/{{namespace}}-service/g; s/namespace: ingress-nginx/namespace: {{namespace}}/g" manifests/ingress-nginx-https.yaml | \
            kubectl apply -f -
        gum style --foreground green "✅ HTTPS configured for namespace '{{namespace}}'"
        gum style --foreground cyan "🌐 Access your demo at: https://$DISPLAY_NAME"
    fi

setup-https:
    #!/usr/bin/env bash
    set -euo pipefail
    gum style --foreground cyan "🔒 Setting up HTTPS certificates..."
    if ! command -v mkcert >/dev/null 2>&1; then
        gum style --foreground red "❌ mkcert not found. Run 'just install-deps' first."
        exit 1
    fi
    # Generate certificates for demo domains
    gum style --foreground cyan "📜 Generating certificates for *.demo.local..."
    mkcert -cert-file certs/demo.local.pem -key-file certs/demo.local-key.pem "*.demo.local" demo.local localhost 127.0.0.1
    gum style --foreground green "✅ HTTPS certificates generated"

create-tls-secret namespace="demo":
    #!/usr/bin/env bash
    set -euo pipefail
    gum style --foreground cyan "🔐 Creating TLS secret for namespace '{{namespace}}'..."
    if [[ ! -f certs/demo.local.pem || ! -f certs/demo.local-key.pem ]]; then
        gum style --foreground red "❌ Certificate files not found. Run 'just setup-https' first."
        exit 1
    fi
    kubectl create secret tls demo-tls \
        --cert=certs/demo.local.pem \
        --key=certs/demo.local-key.pem \
        --namespace="{{namespace}}" \
        --dry-run=client -o yaml | kubectl apply -f -
    gum style --foreground green "✅ TLS secret created in namespace '{{namespace}}'"

configure-hosts namespace="demo" demo="" variant="":
    #!/usr/bin/env bash
    set -euo pipefail
    # Determine hostname format for display
    if [[ -n "{{variant}}" && -n "{{demo}}" ]]; then
        DISPLAY_NAME="{{variant}}.{{demo}}.demo.local"
    else
        DISPLAY_NAME="{{namespace}}.demo.local"
    fi
    gum style --foreground cyan "🔧 Configuring DNS for '$DISPLAY_NAME'..."
    # Get ingress controller external IP
    INGRESS_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    if [[ -z "$INGRESS_IP" ]]; then
        gum style --foreground red "❌ Could not find ingress controller external IP"
        exit 1
    fi
    gum style --foreground blue "📋 Ingress IP: $INGRESS_IP"
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS: Use /etc/resolver for wildcard DNS (no /etc/hosts editing!)
        gum style --foreground cyan "🍎 Configuring macOS resolver for *.demo.local..."
        
        # Check if resolver is already configured with correct IP
        if [[ -f /etc/resolver/demo.local ]] && grep -q "nameserver $INGRESS_IP" /etc/resolver/demo.local; then
            gum style --foreground green "✅ DNS resolver already configured for *.demo.local"
        else
            # Create or update resolver configuration
            sudo mkdir -p /etc/resolver
            echo "nameserver $INGRESS_IP" | sudo tee /etc/resolver/demo.local > /dev/null
            gum style --foreground green "✅ DNS resolver configured for all *.demo.local domains"
            gum style --foreground cyan "🔐 Ensuring mkcert CA is trusted..."
            mkcert -install 2>/dev/null || gum style --foreground yellow "⚠️  mkcert CA trust may need manual setup"
        fi
        gum style --foreground green "✅ Certificate trust configured"
        gum style --foreground cyan "🌐 All services accessible at: https://*.demo.local"
    else
        # Linux: Use /etc/hosts as fallback
        gum style --foreground yellow "🐧 Linux detected - using /etc/hosts (manual management required)"
        HOSTNAME="$DISPLAY_NAME"
        # Check if already configured
        if grep -q "$HOSTNAME" /etc/hosts; then
            gum style --foreground yellow "⚠️  $HOSTNAME already in /etc/hosts"
        else
            # Add to /etc/hosts
            echo "$INGRESS_IP $HOSTNAME" | sudo tee -a /etc/hosts > /dev/null
            gum style --foreground green "✅ Added $HOSTNAME to /etc/hosts"
            gum style --foreground cyan "🔐 Ensuring mkcert CA is trusted..."
            mkcert -install 2>/dev/null || gum style --foreground yellow "⚠️  mkcert CA trust may need manual setup"
        fi
        gum style --foreground green "✅ Certificate trust configured"
        gum style --foreground cyan "🌐 Service accessible at: https://$DISPLAY_NAME"
    fi
