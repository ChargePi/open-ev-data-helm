# open-ev-data-helm

Helm chart repository for the [OpenEV Data](https://github.com/open-ev-data) platform. Charts are published
as OCI artifacts to GHCR.

## Charts

| Chart | Description |
|---|---|
| [`open-ev-data`](charts/open-ev-data) | Deploys the [API](https://github.com/open-ev-data/open-ev-data-api) (`ev-server`), which fetches the [dataset](https://github.com/open-ev-data/open-ev-data-dataset)'s sqlite release at pod startup. A single chart, no chart dependencies. |

## Installing

```console
helm install my-release oci://ghcr.io/open-ev-data/charts/open-ev-data --version <version>
```

See [`charts/open-ev-data/README.md`](charts/open-ev-data/README.md) for full configuration docs, including
how to source the sqlite database file from somewhere other than GitHub Releases.
## Development

```console
helm lint charts/open-ev-data
helm template test charts/open-ev-data
```
