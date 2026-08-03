# Contributing

Thanks for considering a contribution to this repository.

## Prerequisites

- [Helm](https://helm.sh/) 3.8+
- Access to a Kubernetes cluster for manual testing (e.g. [kind](https://kind.sigs.k8s.io/) or Docker Desktop)

## Making changes

1. Fork/branch from `main`.
2. Make your changes under `charts/open-ev-data/`.
3. Validate locally before opening a PR:

   ```console
   helm lint charts/open-ev-data
   helm template test charts/open-ev-data
   ```

4. If you can, install the chart against a real cluster (e.g. `kind`) and confirm the pod comes up healthy:

   ```console
   helm install test charts/open-ev-data --wait
   kubectl port-forward svc/test-api 3000:3000
   curl http://localhost:3000/api/v1/health
   ```

## Pull requests

- Keep PRs focused on a single change where possible.
- CI (`.github/workflows/lint-test.yml`) runs `helm lint`, `helm template` against a couple of value
  combinations, and a mock deployment in a `kind` cluster on every PR — make sure it's green.
- Describe *why* the change is needed, not just what changed.

## Releasing

Releases are cut by pushing a tag matching `v*.*.*` (e.g. `v0.2.0`), which triggers
`.github/workflows/release.yml` to package and publish the chart to GHCR as an OCI artifact. The git tag is
the source of truth for the published version — `Chart.yaml`'s `version` field is not used for this.

## Reporting issues

Open a GitHub issue with as much detail as you can: the values you're using (redact secrets), the Kubernetes
version, and any relevant `kubectl describe`/logs output.
