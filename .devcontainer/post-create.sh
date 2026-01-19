#!/usr/bin/env bash
set -euo pipefail

echo "🔧 Installing Kemo dependencies..."

# Install just
curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to /usr/local/bin
sudo chmod +x /usr/local/bin/just

# Install gum
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
sudo apt-get update && sudo apt-get install -y gum

# Install yq
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq

# Install tmux and yamllint
sudo apt-get install -y tmux yamllint

# Optional: Install VHS for terminal recordings
if [[ "${INSTALL_VHS:-false}" == "true" ]]; then
    echo "🎬 Installing VHS for terminal recordings..."
    go install github.com/charmbracelet/vhs@latest
    sudo apt-get install -y ffmpeg
    echo "✅ VHS installed!"
fi

echo "✅ Dependencies installed!"
echo ""
echo "🚀 To get started:"
echo "   1. Start minikube: minikube start"
echo "   2. Run health check: just health-check"
echo "   3. Browse demos: just browse-demos"
echo ""
echo "📹 To enable VHS recordings, set INSTALL_VHS=true before running post-create.sh"
