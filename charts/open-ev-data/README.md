# open-ev-data

Helm chart for the [OpenEV Data](https://github.com/open-ev-data) platform. A single chart with no chart
dependencies — everything lives directly under `templates/`.

- **[open-ev-data-api](https://github.com/open-ev-data/open-ev-data-api)** (`ev-server`) — the Rust/Axum REST API.
- **[open-ev-data-dataset](https://github.com/open-ev-data/open-ev-data-dataset)** — the canonical EV specification
  dataset, published as versioned GitHub Releases (JSON/CSV/XML/SQLite/SQL).

## Prerequisites

- Kubernetes 1.23+
- Helm 3.8+

## Installing

Charts are published as OCI artifacts to GHCR. Install directly by reference:

```console
helm install my-release oci://ghcr.io/open-ev-data/charts/open-ev-data --version <version>
```

Or from a local checkout of this repository:

```console
helm install my-release charts/open-ev-data
```
## Configuring the data source

By default, `api.database.fetch` downloads the dataset's `.db` release asset from GitHub Releases into an
`emptyDir` shared with the `api` container:

```yaml
api:
  database:
    path: /data/vehicles.db
    fetch:
      enabled: true
      githubRepo: open-ev-data/open-ev-data-dataset
      releaseTag: latest   # or a pinned tag, e.g. "v1.4.0"
      # githubTokenSecret: my-github-token  # avoids unauthenticated GitHub API rate limits
```

To source the database file some other way instead (a PVC, a ConfigMap, a sidecar you manage, an image
that already bundles the file, etc.), disable the fetch initContainer and supply your own volume:

```yaml
api:
  database:
    path: /data/vehicles.db
    fetch:
      enabled: false
  extraVolumes:
    - name: dataset
      persistentVolumeClaim:
        claimName: my-vehicles-db-pvc
  extraVolumeMounts:
    - name: dataset
      mountPath: /data
      readOnly: true
```

## Values

| Key | Description | Default |
|---|---|---|
| `api.enabled` | Deploy the API | `true` |
| `api.replicaCount` | API replica count | `1` |
| `api.image.repository` / `api.image.tag` | API image; pin `tag` to a specific release in production | `ghcr.io/open-ev-data/ev-server` / `latest` |
| `api.database.path` | sqlite file path inside the container | `/data/vehicles.db` |
| `api.database.fetch.enabled` | Download the dataset via an initContainer | `true` |
| `api.database.fetch.releaseTag` | Dataset release tag to fetch, or `latest` | `latest` |
| `api.extraVolumes` / `api.extraVolumeMounts` | Bring-your-own data source (used when `fetch.enabled: false`) | `[]` |
| `api.service.port` | Service port | `3000` |
| `api.ingress.enabled` | Expose the API via Ingress | `false` |
| `api.autoscaling.enabled` | Enable a HorizontalPodAutoscaler | `false` |
| `api.autoscaling.targetCPUUtilizationPercentage` | CPU target for HPA | `80` |
| `api.autoscaling.targetMemoryUtilizationPercentage` | Memory target for HPA | `80` |

See `values.yaml` for the full set of options (resources, security contexts, node selectors, etc.).

## Upgrading the dataset

Bump `api.database.fetch.releaseTag` (or leave it at `latest`) and roll the deployment:

```console
kubectl rollout restart deployment/my-release-api
```

This re-runs the `fetch-dataset` initContainer against the currently configured release.
