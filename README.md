# open-ev-data-helm

Helm chart repository for the [OpenEV Data](https://github.com/open-ev-data) platform. Charts are published
as OCI artifacts to GHCR.

## Charts

| Chart | Description |
|---|---|
| [`open-ev-data`](charts/open-ev-data) | Deploys the [API](https://github.com/open-ev-data/open-ev-data-api) (`ev-server`), which fetches the [dataset](https://github.com/open-ev-data/open-ev-data-dataset)'s sqlite release at pod startup. A single chart, no chart dependencies. |
| [`openev-data-mcp`](charts/openev-data-mcp) | Deploys [openev-data-mcp](https://github.com/ChargePi/openev-data-mcp), an MCP server exposing EV specs over the Model Context Protocol, backed by PostgreSQL provisioned via the [CloudNativePG](https://cloudnative-pg.io) operator. |

## Installing

```console
helm install my-release oci://ghcr.io/chargepi/open-ev-data-helm/open-ev-data --version <version>
helm install my-release oci://ghcr.io/chargepi/open-ev-data-helm/openev-data-mcp --version <version>
```

See [`charts/open-ev-data/README.md`](charts/open-ev-data/README.md) and
[`charts/openev-data-mcp/README.md`](charts/openev-data-mcp/README.md) for full configuration docs.

## Development

```console
helm lint charts/open-ev-data
helm template test charts/open-ev-data

helm lint charts/openev-data-mcp
helm template test charts/openev-data-mcp
```
