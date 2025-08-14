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
        just install-ingress-nginx; \
        just install-kubernetes-dashboard; \
    else \
        gum style --foreground blue '🔵 OrbStack not found, falling back to Minikube'; \
        just start-minikube; \
        just use-minikube; \
        just install-ingress-nginx; \
        just install-kubernetes-dashboard; \
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

install-ingress-nginx:
    @gum style --foreground cyan "🔧 Installing Ingress-NGINX via Helm..."
    @gum spin --spinner dot --title "Installing Ingress-NGINX..." -- \
        helm upgrade --install ingress-nginx ingress-nginx \
        --repo https://kubernetes.github.io/ingress-nginx \
        --namespace ingress-nginx --create-namespace
    @gum spin --spinner dot --title "Waiting for Ingress-NGINX to be ready..." -- \
        kubectl wait -n ingress-nginx --for=condition=Ready pod -l app.kubernetes.io/component=controller --timeout=120s

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

run-demo demo variant:
    @gum style --foreground green --bold "🎬 Starting demo: {{demo}}/{{variant}}"
    @echo
    @just kubernetes-setup
    @just create-namespace {{demo}} {{variant}} {{k8s-provider}}
    @scripts/run-demo.sh {{demo}} {{variant}} run bash demos/{{demo}}/{{variant}}/run.sh
    @if [[ "${KEMO_SKIP_CLEANUP:-false}" != "true" ]]; then \
        echo; \
        if gum confirm "🧹 Clean up resources?"; then \
            just kubernetes-cleanup; \
        fi; \
    fi

list-tags:
    @gum style --foreground cyan "Available tags:"
    @find demos -name metadata.yaml -exec yq e '.tags // [] | .[]' {} \; | grep -v '^$' | sort -u | while read tag; do \
        gum style --foreground green "🏷️  $$tag"; \
    done

install-deps:
    @echo "🔧 Installing prerequisites for Kemo..."
    @if [ "$(uname)" = "Darwin" ]; then \
        echo "🍎 Detected macOS. Installing with brew..."; \
        brew install minikube kubectl gum yq tmux helm; \
    elif [ -f /etc/debian_version ]; then \
        echo "🐧 Detected Debian-based Linux. Installing with apt..."; \
        sudo apt update && sudo apt install -y curl gnupg lsb-release software-properties-common; \
        sudo apt install -y jq yq tmux; \
        curl -s -LO https://storage.googleapis.com/minikube/releases/latest/minikube_latest_amd64.deb && \
        sudo dpkg -i minikube_latest_amd64.deb && \
        rm minikube_latest_amd64.deb; \
        curl -s https://api.github.com/repos/charmbracelet/gum/releases/latest \
          | jq -r ".assets[] | select(.name | test(\"gum_.*_Linux_x86_64.tar.gz\")) | .browser_download_url" \
          | xargs curl -L | tar xz && sudo mv gum /usr/local/bin/; \
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash; \
    elif [ -f /etc/redhat-release ]; then \
        echo "🐧 Detected RHEL-based Linux. Installing with dnf..."; \
        sudo dnf install -y jq yq tmux helm; \
        curl -s -LO https://storage.googleapis.com/minikube/releases/latest/minikube-latest.x86_64.rpm && \
        sudo rpm -Uvh minikube-latest.x86_64.rpm && \
        rm minikube-latest.x86_64.rpm; \
        curl -s https://api.github.com/repos/charmbracelet/gum/releases/latest \
          | jq -r ".assets[] | select(.name | test(\"gum_.*_Linux_x86_64.tar.gz\")) | .browser_download_url" \
          | xargs curl -L | tar xz && sudo mv gum /usr/local/bin/; \
    else \
        echo "❌ Unsupported system. Please install minikube, kubectl, gum, yq, helm, and tmux manually."; \
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
    gum style --foreground cyan "📦 Found $demo_count demo variants"
