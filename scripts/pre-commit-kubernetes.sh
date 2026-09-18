#!/usr/bin/env bash
# Validate changed Kubernetes manifests for the local pre-commit hooks.

set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <kubeconform|pluto> <yaml-file>..." >&2
    exit 2
fi

validator=$1
shift

if [[ $# -eq 0 ]]; then
    exit 0
fi

declare -A demo_dirs=()
declare -A manifest_dirs=()
declare -a resource_files=()

for file in "$@"; do
    [[ -f "$file" ]] || continue

    case "$file" in
        demos/*/*/*.yaml|demos/*/*/*.yml)
            demo_dirs["$(dirname "$file")"]=1
            ;;
        manifests/*.yaml|manifests/*.yml)
            manifest_dirs["$(dirname "$file")"]=1
            ;;
        *)
            continue
            ;;
    esac

    case "$(basename "$file")" in
        metadata.yaml|metadata.yml|kustomization.yaml|kustomization.yml)
            ;;
        *)
            resource_files+=("$file")
            ;;
    esac
done

if [[ ${#demo_dirs[@]} -eq 0 && ${#manifest_dirs[@]} -eq 0 && ${#resource_files[@]} -eq 0 ]]; then
    exit 0
fi

if ! command -v "$validator" >/dev/null 2>&1; then
    echo "$validator is required for the pre-commit checks. Run 'just install-deps'." >&2
    exit 1
fi

case "$validator" in
    kubeconform)
        if [[ ${#resource_files[@]} -gt 0 ]]; then
            kubeconform -strict -ignore-missing-schemas "${resource_files[@]}"
        fi

        for directory in "${!demo_dirs[@]}"; do
            kubectl kustomize "$directory" |
                kubeconform -strict -ignore-missing-schemas
        done
        ;;
    pluto)
        for directory in "${!demo_dirs[@]}" "${!manifest_dirs[@]}"; do
            pluto detect-files -d "$directory"
        done
        ;;
    *)
        echo "Unsupported Kubernetes validator: $validator" >&2
        exit 2
        ;;
esac
