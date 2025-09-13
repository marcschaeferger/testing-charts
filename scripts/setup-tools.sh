#!/usr/bin/env bash
# Global tooling setup for Helm chart development and tests
# Installs or verifies pinned versions of CLI tools into $HOME/go/bin
set -euo pipefail

# Versions (pin for reproducibility)
HELM_DOCS_VER="v1.14.2"
YQ_VER="v4.44.3"
KUBECONFORM_VER="v0.6.7"
KUBE_SCORE_VER="v1.18.0"
KUBE_LINTER_VER="v0.6.6"
# Kubescape is optional; we do not install automatically (prints version if present)

BIN_DIR="$HOME/go/bin"
export GOPATH="${GOPATH:-$HOME/go}"
export PATH="$BIN_DIR:$PATH"

need() { command -v "$1" >/dev/null 2>&1; }

echo "Using BIN_DIR=$BIN_DIR"
mkdir -p "$BIN_DIR"

if ! need go; then
  echo "Go is required but not found. Please install Go (>=1.20) and re-run." >&2
  exit 1
fi

# helm-docs
if ! need helm-docs; then
  echo "Installing helm-docs ${HELM_DOCS_VER} via go install"
  GO111MODULE=on go install github.com/norwoodj/helm-docs/cmd/helm-docs@${HELM_DOCS_VER}
else
  echo "helm-docs already installed: $(helm-docs --version 2>/dev/null || true)"
fi

# yq
if ! need yq; then
  echo "Installing yq ${YQ_VER} via go install"
  GO111MODULE=on go install github.com/mikefarah/yq/v4@${YQ_VER}
else
  echo "yq already installed: $(yq --version 2>/dev/null || true)"
fi

# kubeconform
if ! need kubeconform; then
  echo "Installing kubeconform ${KUBECONFORM_VER} via go install"
  GO111MODULE=on go install github.com/yannh/kubeconform/cmd/kubeconform@${KUBECONFORM_VER}
else
  echo "kubeconform already installed: $(kubeconform -v 2>/dev/null || true)"
fi

# kube-score
if ! need kube-score; then
  echo "Installing kube-score ${KUBE_SCORE_VER} via go install"
  GO111MODULE=on go install github.com/zegl/kube-score/cmd/kube-score@${KUBE_SCORE_VER}
else
  echo "kube-score already installed: $(kube-score version 2>/dev/null || true)"
fi

# kube-linter
if ! need kube-linter; then
  echo "Installing kube-linter ${KUBE_LINTER_VER} via go install"
  GO111MODULE=on go install golang.stackrox.io/kube-linter/cmd/kube-linter@${KUBE_LINTER_VER}
else
  echo "kube-linter already installed: $(kube-linter version 2>/dev/null || true)"
fi

# kubescape (optional)
if need kubescape; then
  echo "kubescape present: $(kubescape version 2>/dev/null || true)"
else
  echo "kubescape not installed (optional). See https://kubescape.io for installation methods."
fi

cat <<EOF

Installed tool versions:
- helm-docs: $(helm-docs --version 2>/dev/null || echo not-installed)
- yq: $(yq --version 2>/dev/null || echo not-installed)
- kubeconform: $(kubeconform -v 2>/dev/null || echo not-installed)
- kube-score: $(kube-score version 2>/dev/null || echo not-installed)
- kube-linter: $(kube-linter version 2>/dev/null || echo not-installed)
- kubescape: $(kubescape version 2>/dev/null || echo not-installed)

Note: ensure "${HOME}/go/bin" is in your PATH (e.g., in ~/.bashrc or ~/.zshrc):
  export PATH="\$HOME/go/bin:\$PATH"
EOF

