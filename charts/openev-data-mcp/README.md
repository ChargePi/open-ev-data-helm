# openev-data-mcp

Helm chart for [openev-data-mcp](https://github.com/ChargePi/openev-data-mcp), an MCP (Model Context
Protocol) server that exposes EV specifications (battery capacity, range ratings, charging capabilities,
etc) to AI assistants over streamable HTTP, backed by PostgreSQL, with semantic vehicle search
(the `search_vehicles` tool) backed by Qdrant and Gemini embeddings.

## Prerequisites

- Kubernetes 1.23+
- Helm 3.8+
- The [CloudNativePG](https://cloudnative-pg.io) operator, if you want this chart to provision its own
  Postgres cluster (the default — see below for using an external database instead).
- A [Gemini API key](https://aistudio.google.com/apikey), used to embed vehicles and search queries.

## Why no bundled PostgreSQL chart dependency?

The usual default (Bitnami's `postgresql` chart) had its free OCI images frozen in 2025 — no more
updates unless you pay for Bitnami Secure Images. A Helm subchart also isn't a great fit for a Postgres
*operator* anyway: its CRDs are cluster-scoped and normally installed once per cluster by a platform
team, not tied to an individual application release's install/uninstall lifecycle.

Instead, this chart targets [CloudNativePG](https://cloudnative-pg.io): install the operator once per
cluster,

```console
helm repo add cnpg https://cloudnative-pg.github.io/charts
helm upgrade --install cnpg-operator cnpg/cloudnative-pg --namespace cnpg-system --create-namespace
```

and this chart's own `Cluster` resource (`postgresql.cnpg.enabled: true`, the default) provisions a
dedicated Postgres instance per release on top of it. Set `postgresql.cnpg.enabled: false` and configure
`postgresql.external` instead to point at any Postgres you already manage (a CNPG cluster in another
namespace, RDS, etc) without provisioning a new one — see
[`ci/external-db-values.yaml`](ci/external-db-values.yaml) for a worked example:

```console
helm install my-release charts/openev-data-mcp -f charts/openev-data-mcp/ci/external-db-values.yaml
```

## Installing

```console
kubectl create secret generic openev-mcp-gemini --from-literal=api-key='<your-gemini-api-key>'
helm install my-release oci://ghcr.io/chargepi/open-ev-data-helm/openev-data-mcp --version <version> \
  --set mcp.config.embedding.existingSecret=openev-mcp-gemini
```

Or from a local checkout of this repository (fetch the Qdrant dependency first):

```console
helm dependency build charts/openev-data-mcp
helm install my-release charts/openev-data-mcp --set mcp.config.embedding.existingSecret=openev-mcp-gemini
```

`mcp.config.embedding.apiKey` can be set instead of `existingSecret`, in which case the chart stores the
key in a Secret of its own.

## Database schema and seed data

`openev-data-mcp` does not run its schema migration on startup — it just connects. This chart applies
the upstream project's `migrations/001_initial.sql` (schema + seed data) via a **post-install-only** Job
that fetches the file from `raw.githubusercontent.com/ChargePi/openev-data-mcp` at the release tag
matching the deployed image (`v<mcp.image.tag>`, defaulting to the chart's `appVersion`), the same way
`api.database.fetch` in the sibling `open-ev-data` chart fetches its dataset — rather than vendoring the
SQL into this chart, so the schema always matches the server version.

It only runs on install (not on every upgrade) because the migration isn't idempotent — re-running it
against an already-migrated database would fail on "relation already exists". To pick up a newer
migration after bumping `mcp.image.tag`, apply it yourself:

```console
kubectl get configmap my-release-mcp-migrate -o jsonpath='{.data.migrate\.sh}' | kubectl exec -i <a-pod-with-psql> -- sh
```

or run `helm template ... | kubectl apply -f -` targeting just the Job after deleting the old one.

Set `migration.enabled: false` to skip this entirely (e.g. if you're pointing at a database that's
already migrated some other way).

## Semantic search

The `search_vehicles` tool embeds a natural language query with Gemini and matches it against a Qdrant
collection holding one embedded document per vehicle.

**Qdrant.** By default the official [Qdrant chart](https://github.com/qdrant/qdrant-helm) is installed as
a dependency, with an API key generated on install and kept across upgrades. Everything under `qdrant`
other than `external` is passed through to it (persistence, resources, replicas, etc). Set
`qdrant.enabled: false` and configure `qdrant.external` to use a Qdrant you manage yourself, e.g. Qdrant
Cloud — see [`ci/external-qdrant-values.yaml`](ci/external-qdrant-values.yaml).

**Vector sync.** The collection is filled by `openev-data-mcp migrate`, which provisions the collection,
embeds new or changed vehicles, deletes removed ones and skips unchanged ones, so re-running it is cheap.
The chart runs it as a Helm hook Job on install (after the database migration) and on every upgrade.
The MCP server does not wait for it: searches work over whatever is already indexed.

Helm waits for the hook, so a failed sync fails the install or upgrade. On the Gemini **free tier** the
first sync of the full dataset (~1200 vehicles) exceeds the daily embedding quota (~1000 requests); the
sync stops when Gemini reports the daily quota is exhausted and picks up where it left off on the next
run. Either use a paid key, or set `vectorSync.enabled: false` and enable `vectorSync.cronJob` so the
index completes over consecutive days. The CronJob is also useful on its own, to pick up dataset changes
without a Helm upgrade.

## Values

| Key | Description | Default |
|---|---|---|
| `mcp.replicaCount` | Replica count | `1` |
| `mcp.image.repository` / `mcp.image.tag` | MCP server image; `tag` defaults to the chart's `appVersion` | `ghcr.io/chargepi/openev-data-mcp` / `""` |
| `mcp.service.port` | MCP (streamable HTTP) port | `8080` |
| `mcp.service.healthPort` | gRPC health-check port (probed via the `grpc_health_probe` binary baked into the image) | `9090` |
| `mcp.config.refreshInterval` | How often the in-memory resource cache refreshes from the database | `5m` |
| `mcp.config.observability.enabled` / `mcp.config.observability.otlpEndpoint` | OpenTelemetry OTLP export | `false` / `""` |
| `mcp.ingress.enabled` | Expose the MCP endpoint via Ingress | `false` |
| `mcp.autoscaling.enabled` | Enable a HorizontalPodAutoscaler | `false` |
| `postgresql.cnpg.enabled` | Provision a dedicated Postgres cluster via CloudNativePG | `true` |
| `postgresql.cnpg.database` | Application database (and owner role) name | `openevdata` |
| `postgresql.cnpg.storage.size` | PVC size for the CNPG cluster | `1Gi` |
| `postgresql.external.*` | Connection details for a database you manage yourself, used when `postgresql.cnpg.enabled: false` | — |
| `migration.enabled` | Run the post-install schema/seed Job | `true` |
| `migration.gitRef` | Override the git ref to fetch `migrations/001_initial.sql` from; required if `mcp.image.tag` isn't a semver release | `""` (`v<image tag>`) |
| `mcp.config.embedding.apiKey` / `mcp.config.embedding.existingSecret` | Gemini API key, inline or from an existing Secret (key `existingSecretKey`); one is required | `""` / `""` |
| `mcp.config.embedding.model` / `mcp.config.embedding.dimensions` | Embedding model and vector size; changing the size requires deleting the collection | `gemini-embedding-001` / `768` |
| `mcp.config.search.collection` | Qdrant collection name | `ev_vehicles` |
| `mcp.config.search.limit` / `mcp.config.search.minScore` | Maximum results per search and the minimum cosine similarity for a match | `10` / `0.6` |
| `qdrant.enabled` | Install the bundled Qdrant chart | `true` |
| `qdrant.apiKey` | Generate an API key for the bundled Qdrant | `true` |
| `qdrant.persistence.size` | PVC size for the bundled Qdrant | `1Gi` |
| `qdrant.external.*` | Connection details (host, gRPC port, TLS, API key Secret) for a Qdrant you manage yourself, used when `qdrant.enabled: false` | — |
| `vectorSync.enabled` | Run the vector sync as a post-install/post-upgrade hook Job | `true` |
| `vectorSync.activeDeadlineSeconds` | Time limit for one sync run | `3600` |
| `vectorSync.cronJob.enabled` / `vectorSync.cronJob.schedule` | Also run the sync on a schedule | `false` / `"0 3 * * *"` |

See `values.yaml` for the full set of options (resources, security contexts, node selectors, etc).

## Upgrading the MCP server

```console
helm upgrade my-release charts/openev-data-mcp --set mcp.image.tag=1.0.0
```

The database migration Job does not re-run on upgrade (see above); the `mcp` Deployment rolls and the
vector sync re-runs, re-embedding only vehicles whose indexed document changed.
