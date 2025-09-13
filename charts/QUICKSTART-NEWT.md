<!-- markdownlint-disable MD033 -->
# Newt Helm Chart - Quickstart

This guide shows two supported ways to install the Newt Helm chart: using an existing Kubernetes Secret (preferred) or passing credentials inline via Helm values. Without the proper credentials, the installation will fail.

## Prerequisites

- Kubernetes Cluster: >= 1.28.15
- `kubectl` configured for your cluster
- Helm CLI: v3
- Chart version: 0.0.7

Namespace in examples below: `newt-ns`

## Option A (preferred): Use an existing Secret

1) Store your credentials in a file (e.g. `newt-cred.env`) and avoid CLI input:

    Example content for `newt-cred.env`:

    ```env
    PANGOLIN_ENDPOINT=https://pangolin.yourdomain.com
    NEWT_ID=yourNewtID
    NEWT_SECRET=yourSecretPassword
    ```

    Do not commit this file to git. It should only exist locally/temporarily. Optionally protect it with `chmod 600 newt-cred.env`.

2) Create the Secret directly from the file:

    ```bash
    kubectl create secret generic newt-cred -n newt-ns --from-env-file=newt-cred.env
    ```

3) Create a values file that fits your requirements. For this Test we create a minimal values file called `myvalues.yaml`:

    ```yaml
    newtInstances:
      - name: main
        enabled: true
        auth:
          existingSecretName: newt-cred
    ```

4) Adding & Installing the chart:

    The command below installs the chart with your chosen release name (`newt`), namespace (`newt-ns`), and values file (`myvalues.yaml`). You can change these to fit your environment. (helm install <release-name> <chart> -n <namespace> -f <values-file>)

    ```bash
    helm install newt ./newt-0.0.7.tgz -n newt-ns -f myvalues.yaml
    ```

    Alternative instead of using a values file you can set the values directly in the command line:

    ```bash
    helm install newt ./newt-0.0.7.tgz \
    -n newt-ns \
    --set newtInstances[0].name=main \
    --set newtInstances[0].enabled=true \
    --set newtInstances[0].auth.existingSecretName=newt-cred
    ```

    When the helm chart is published it can be done with the following commands. There will be mutltiple charts published on <https://charts.digpangolin.com>

    ```bash
    helm repo add fosrl https://charts.digpangolin.com
    helm repo update fosrl
    helm install newt fosrl/newt -n newt-ns -f myvalues.yaml
    ```

## Option B: Inline credentials via Helm values

If you prefer to provide credentials inline (not recommended), install with:

```bash
export NEWT_SECRET='<your-secret-here>'   # Set securely
helm install newt ./newt-0.0.7.tgz -n newt-ns \
  --set newtInstances[0].name=main \
  --set newtInstances[0].enabled=true \
  --set newtInstances[0].pangolinEndpoint=https://pangolin.yourdomain.com \
  --set newtInstances[0].id=XXXX \
  --set-string newtInstances[0].secret="$NEWT_SECRET"
```

## Notes

- Credentials required: When an instance is enabled, you must supply credentials either via an existing Secret (preferred) or inline values. The chart’s schema enforces this.
- Test Job: The Helm test Job is gated behind `values.tests.enabled` (default: false) and will only render and run when enabled.
- NetworkPolicy: If you enable `global.networkPolicy.create` and `defaultDenyIngress`, a deny-all-INGRESS baseline is created and UDP 51820/51821 are allowed for instances with `acceptClients=true`. Egress is not restricted by this chart.
- Security: Never commit secrets into version control. Prefer existing Secret, sealed-secrets, or other secret managers.

## Troubleshooting

- Dry-run template:

```bash
helm template newt ./newt-0.0.7.tgz -n newt-ns -f myvalues.yaml
```

- Uninstall:

```bash
helm uninstall newt -n newt-ns
```
