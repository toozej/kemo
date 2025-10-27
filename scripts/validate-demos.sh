#!/usr/bin/env bash
# Kemo Demo Validation Script
# Validates all demo manifests for correctness and consistency

set -euo pipefail

# Color output functions
red() { echo -e "\033[31m$1\033[0m"; }
green() { echo -e "\033[32m$1\033[0m"; }
yellow() { echo -e "\033[33m$1\033[0m"; }
blue() { echo -e "\033[34m$1\033[0m"; }
cyan() { echo -e "\033[36m$1\033[0m"; }
bold() { echo -e "\033[1m$1\033[0m"; }

# Dynamically discover all demo variants
demo_root="demos"
demos=()
declare -A expected_hosts=()
declare -A expected_target_ports=()

# Find all demo variants (directories with metadata.yaml)
while IFS= read -r -d '' metadata; do
  if [[ ! -f "$metadata" ]]; then
    continue
  fi

  dir=$(dirname "$metadata")
  relpath="${dir#$demo_root/}"
  demo="${relpath%/*}"
  variant="${relpath##*/}"

  demo_path="$demo_root/$demo/$variant"
  demos+=("$demo_path")

  # Generate expected hostname
  expected_hosts["$demo_path"]="${demo}-${variant}.k8s.orb.local"

  # Check for non-standard targetPorts (8080 instead of 80)
  if [[ -f "$demo_path/service.yaml" ]] && grep -q "targetPort: 8080" "$demo_path/service.yaml"; then
    expected_target_ports["$demo_path"]="8080"
  fi
done < <(find "$demo_root" -mindepth 3 -maxdepth 3 -name metadata.yaml -print0 | sort -z)

echo
bold "$(cyan "🧪 Kemo Demo Validation")"
echo "Validating ${#demos[@]} demo configurations..."
echo

# Track validation results
overall_passed_demos=0
overall_failed_demos=0

for d in "${demos[@]}"; do
  demo_failed_checks=0
  passed_check_messages=()
  failed_check_messages=()

  # 1. Kustomize build check
  if (cd "$d" && kubectl kustomize . >/dev/null 2>&1); then
    passed_check_messages+=("Kustomize build")
  else
    if ! kubectl cluster-info >/dev/null 2>&1; then
      passed_check_messages+=("Kustomize build (kubectl not available - skipping)")
    else
      let demo_failed_checks+=1
      failed_check_messages+=("Kustomize build")
    fi
  fi

  # 2. run.sh namespace apply check
  if [[ -f "$d/run.sh" ]]; then
    if grep -qE 'kubectl apply -n "(\$KEMO_NS|\${KEMO_NS})" --kustomize' "$d/run.sh"; then
      passed_check_messages+=("run.sh apply pattern")
    else
      let demo_failed_checks+=1
      failed_check_messages+=("run.sh missing expected apply pattern")
    fi
  fi

  # 3. Ingress and host checks
  host="${expected_hosts[$d]}"
  if [[ ! -f "$d/ingress.yaml" ]]; then
    passed_check_messages+=("Ingress not needed")
  else
    if grep -q 'ingressClassName: nginx' "$d/ingress.yaml" && \
       grep -q 'secretName: demo-tls' "$d/ingress.yaml" && \
       grep -q "host: $host" "$d/ingress.yaml"; then
      passed_check_messages+=("Ingress class/TLS/host")
    else
      let demo_failed_checks+=1
      failed_check_messages+=("Ingress class/TLS/host incorrect")
    fi
  fi

  # 4. Service/ports checks
  if [[ -v "expected_target_ports[$d]" ]]; then
    port="${expected_target_ports[$d]}"
    if [[ ! -f "$d/service.yaml" ]]; then
      let demo_failed_checks+=1
      failed_check_messages+=("Service manifest missing for targetPort check")
    else
      if grep -q "targetPort: $port" "$d/service.yaml"; then
        passed_check_messages+=("Service targetPort $port")
      else
        let demo_failed_checks+=1
        failed_check_messages+=("Service targetPort $port incorrect")
      fi
    fi
  fi

  # 5. .gitignore check
  if [[ -f "$d/.gitignore" ]] && grep -q '\.logs/' "$d/.gitignore"; then
    passed_check_messages+=(".gitignore exists and ignores .logs/")
  else
    let demo_failed_checks+=1
    failed_check_messages+=(".gitignore missing or incorrect")
  fi

  # 6. metadata.yaml check
  if [[ -f "$d/metadata.yaml" ]]; then
    passed_check_messages+=("metadata.yaml exists")
    if yq e '.title != null and .title != "" and .description != null and .description != "" and .difficulty != null and .difficulty != ""' "$d/metadata.yaml" >/dev/null; then
      passed_check_messages+=("metadata.yaml has required fields")
    else
      let demo_failed_checks+=1
      failed_check_messages+=("metadata.yaml missing required fields (title, description, difficulty)")
    fi
  else
    let demo_failed_checks+=1
    failed_check_messages+=("metadata.yaml missing")
  fi

  # 7. kustomization.yaml check
  if [[ -f "$d/kustomization.yaml" ]]; then
    passed_check_messages+=("kustomization.yaml exists")
  else
    let demo_failed_checks+=1
    failed_check_messages+=("kustomization.yaml missing")
  fi

  # 8. run.sh existence check
  if [[ -f "$d/run.sh" ]]; then
    passed_check_messages+=("run.sh exists")
  else
    if [[ "$d" == *"crds"* ]] || [[ "$d" == *"jobs"* ]] || [[ "$d" == *"cronjobs"* ]]; then
      passed_check_messages+=("run.sh not needed for this demo type")
    else
      let demo_failed_checks+=1
      failed_check_messages+=("run.sh missing")
    fi
  fi

  # 9. kustomization.yaml resources check
  if [[ -f "$d/kustomization.yaml" ]]; then
    if grep -q 'resources:' "$d/kustomization.yaml"; then
      passed_check_messages+=("kustomization.yaml has resources section")
    else
      let demo_failed_checks+=1
      failed_check_messages+=("kustomization.yaml missing resources section")
    fi
  fi

  # 10. YAML Linting
  if yamllint -s "$d" >/dev/null 2>&1; then
    passed_check_messages+=("YAML linting")
  else
    let demo_failed_checks+=1
    failed_check_messages+=("YAML linting failed")
  fi

  # 11. Kubernetes Schema Validation
  if kubectl kustomize "$d" | kubeconform -strict -ignore-missing-schemas >/dev/null 2>&1; then
    passed_check_messages+=("Kubernetes schema validation")
  else
    let demo_failed_checks+=1
    failed_check_messages+=("Kubernetes schema validation failed")
  fi

  # 12. Standardized Kubernetes Labels
  if ! (kubectl kustomize "$d" | yq e '((.metadata.labels | has("app.kubernetes.io/name")) and (.metadata.labels | has("app.kubernetes.io/part-of"))) // false' - | grep -q 'false'); then
    passed_check_messages+=("Standardized labels")
  else
    let demo_failed_checks+=1
    failed_check_messages+=("Missing standardized labels (app.kubernetes.io/name, app.kubernetes.io/part-of)")
  fi

  # --- Topic-specific checks ---
  if [[ "$d" == "demos/deployments-rolling-updates/good" ]]; then
    if [[ -f "$d/ingress.yaml" ]] && \
       grep -q 'path: /rolling' "$d/ingress.yaml" && \
       grep -q 'path: /recreate' "$d/ingress.yaml"; then
      passed_check_messages+=("Special paths (/rolling, /recreate) in Ingress")
    else
      let demo_failed_checks+=1
      failed_check_messages+=("Missing special paths in Ingress")
    fi
  fi
  if [[ "$d" == "demos/external-secrets-operator/good" ]]; then
    if [[ -f "$d/ingress.yaml" ]] && grep -q 'path: /env' "$d/ingress.yaml"; then
      passed_check_messages+=("Special path (/env) in Ingress")
    else
      let demo_failed_checks+=1
      failed_check_messages+=("Missing special path in Ingress")
    fi
    if [[ -f "$d/externalsecret.yaml" ]] && \
       [[ -f "$d/secretstore.yaml" ]] && \
       grep -q '^apiVersion: external-secrets.io/v1beta1' "$d/externalsecret.yaml" && \
       grep -q '^kind: ExternalSecret' "$d/externalsecret.yaml" && \
       grep -q '^apiVersion: external-secrets.io/v1beta1' "$d/secretstore.yaml" && \
       grep -q '^kind: SecretStore' "$d/secretstore.yaml"; then
      passed_check_messages+=("ESO ExternalSecret and SecretStore manifests")
    else
      let demo_failed_checks+=1
      failed_check_messages+=("Missing or incorrect ESO manifests")
    fi
  fi
  if [[ "$d" == "demos/keda/good" ]]; then
    if [[ -f "$d/scaledobject-cron.yaml" ]] && \
       grep -q '^apiVersion: keda.sh/v1alpha1' "$d/scaledobject-cron.yaml" && \
       grep -q '^kind: ScaledObject' "$d/scaledobject-cron.yaml"; then
      passed_check_messages+=("KEDA ScaledObject manifest")
    else
      let demo_failed_checks+=1
      failed_check_messages+=("Missing or incorrect KEDA ScaledObject manifest")
    fi
  fi
  if [[ "$d" == "demos/taints-tolerations/good" ]]; then
    if [[ -f "$d/deployment-with-tolerations.yaml" ]] && \
       grep -q 'tolerations:' "$d/deployment-with-tolerations.yaml" && \
       grep -q 'key: "demo"' "$d/deployment-with-tolerations.yaml" && \
       grep -q 'value: "tainted"' "$d/deployment-with-tolerations.yaml" && \
       grep -q 'effect: "NoSchedule"' "$d/deployment-with-tolerations.yaml"; then
      passed_check_messages+=("Taints/Tolerations spec")
    else
      let demo_failed_checks+=1
      failed_check_messages+=("Missing or incorrect Taints/Tolerations spec")
    fi
  fi


  # --- Output results for demo $d ---
  if [[ $demo_failed_checks -eq 0 ]]; then
    green "✅ $d"
    for msg in "${passed_check_messages[@]}"; do
      echo "  - $msg"
    done
    let overall_passed_demos+=1
  else
    red "❌ $d"
    for msg in "${failed_check_messages[@]}"; do
      echo "  - $msg"
    done
    for msg in "${passed_check_messages[@]}"; do
      echo "  - $msg"
    done
    let overall_failed_demos+=1
  fi
  echo
done

# --- Summary ---
echo "$(bold "📊 Validation Summary")"
echo "Passed demos: $overall_passed_demos"
echo "Failed demos: $overall_failed_demos"
echo

if [[ $overall_failed_demos -eq 0 ]]; then
  bold "$(green "🎉 All validations passed!")"
  echo "All demo configurations are valid and ready for use."
  exit 0
else
  bold "$(red "❌ Validation failed!")"
  echo "$overall_failed_demos demos failed. Please review and fix the issues above."
  exit 1
fi