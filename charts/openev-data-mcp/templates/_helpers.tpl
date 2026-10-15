{{- define "mcp.fullname" -}}
{{- printf "%s-mcp" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "mcp.labels" -}}
app.kubernetes.io/name: mcp
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: openev-data-mcp
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "mcp.selectorLabels" -}}
app.kubernetes.io/name: mcp
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "mcp.serviceAccountName" -}}
{{- if .Values.mcp.serviceAccount.create -}}
{{- default (include "mcp.fullname" .) .Values.mcp.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.mcp.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/*
Upstream publishes images tagged with the release's git tag (v<semver>), while
the chart's appVersion is plain semver.
*/}}
{{- define "mcp.version" -}}
{{- .Values.mcp.image.tag | default (printf "v%s" .Chart.AppVersion) -}}
{{- end -}}

{{- define "mcp.image" -}}
{{- printf "%s:%s" .Values.mcp.image.repository (include "mcp.version" .) -}}
{{- end -}}

{{/*
Image tags are the release's git tag, so the migration matching the deployed
image lives at that same ref (a tag given without the "v" prefix gets one).
*/}}
{{- define "mcp.migrationGitRef" -}}
{{- if .Values.migration.gitRef -}}
{{- .Values.migration.gitRef -}}
{{- else -}}
{{- $version := include "mcp.version" . -}}
{{- if not (regexMatch "^v?[0-9]+\\.[0-9]+\\.[0-9]+" $version) -}}
{{- fail (printf "migration.gitRef is required when mcp.image.tag (%q) is not a semver release" $version) -}}
{{- end -}}
{{- printf "v%s" (trimPrefix "v" $version) -}}
{{- end -}}
{{- end -}}

{{- define "mcp.postgresClusterName" -}}
{{- default (printf "%s-postgres" .Release.Name) .Values.postgresql.cnpg.clusterName -}}
{{- end -}}

{{/*
Connection details resolve either to the bundled CNPG Cluster's generated
"<cluster>-rw" service and "<cluster>-app" secret, or to postgresql.external.
*/}}
{{- define "mcp.postgresHost" -}}
{{- if .Values.postgresql.cnpg.enabled -}}
{{- printf "%s-rw" (include "mcp.postgresClusterName" .) -}}
{{- else -}}
{{- required "postgresql.external.host is required when postgresql.cnpg.enabled is false" .Values.postgresql.external.host -}}
{{- end -}}
{{- end -}}

{{- define "mcp.postgresPort" -}}
{{- if .Values.postgresql.cnpg.enabled -}}
5432
{{- else -}}
{{- .Values.postgresql.external.port -}}
{{- end -}}
{{- end -}}

{{- define "mcp.postgresDatabase" -}}
{{- if .Values.postgresql.cnpg.enabled -}}
{{- .Values.postgresql.cnpg.database -}}
{{- else -}}
{{- .Values.postgresql.external.database -}}
{{- end -}}
{{- end -}}

{{- define "mcp.postgresSecretName" -}}
{{- if .Values.postgresql.cnpg.enabled -}}
{{- printf "%s-app" (include "mcp.postgresClusterName" .) -}}
{{- else -}}
{{- required "postgresql.external.existingSecret is required when postgresql.cnpg.enabled is false" .Values.postgresql.external.existingSecret -}}
{{- end -}}
{{- end -}}

{{- define "mcp.postgresUserKey" -}}
{{- if .Values.postgresql.cnpg.enabled -}}
username
{{- else -}}
{{- .Values.postgresql.external.userKey -}}
{{- end -}}
{{- end -}}

{{- define "mcp.postgresPasswordKey" -}}
{{- if .Values.postgresql.cnpg.enabled -}}
password
{{- else -}}
{{- .Values.postgresql.external.passwordKey -}}
{{- end -}}
{{- end -}}

{{/*
Mirrors the Qdrant subchart's own fullname logic, which its Service and API key
Secret are named after.
*/}}
{{- define "mcp.qdrantFullname" -}}
{{- if .Values.qdrant.fullnameOverride -}}
{{- .Values.qdrant.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default "qdrant" .Values.qdrant.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Connection details resolve either to the bundled Qdrant subchart's Service and
generated API key Secret, or to qdrant.external.
*/}}
{{- define "mcp.qdrantHost" -}}
{{- if .Values.qdrant.enabled -}}
{{- include "mcp.qdrantFullname" . -}}
{{- else -}}
{{- required "qdrant.external.host is required when qdrant.enabled is false" .Values.qdrant.external.host -}}
{{- end -}}
{{- end -}}

{{- define "mcp.qdrantPort" -}}
{{- if .Values.qdrant.enabled -}}
6334
{{- else -}}
{{- .Values.qdrant.external.port -}}
{{- end -}}
{{- end -}}

{{- define "mcp.qdrantUseTls" -}}
{{- if .Values.qdrant.enabled -}}
false
{{- else -}}
{{- .Values.qdrant.external.useTls -}}
{{- end -}}
{{- end -}}

{{/* Empty when Qdrant has no API key. */}}
{{- define "mcp.qdrantSecretName" -}}
{{- if .Values.qdrant.enabled -}}
{{- if .Values.qdrant.apiKey -}}
{{- printf "%s-apikey" (include "mcp.qdrantFullname" .) -}}
{{- end -}}
{{- else -}}
{{- .Values.qdrant.external.existingSecret -}}
{{- end -}}
{{- end -}}

{{- define "mcp.qdrantSecretKey" -}}
{{- if .Values.qdrant.enabled -}}
api-key
{{- else -}}
{{- .Values.qdrant.external.apiKeyKey -}}
{{- end -}}
{{- end -}}

{{- define "mcp.embeddingSecretName" -}}
{{- $embedding := .Values.mcp.config.embedding -}}
{{- if $embedding.existingSecret -}}
{{- $embedding.existingSecret -}}
{{- else if $embedding.apiKey -}}
{{- printf "%s-embedding" (include "mcp.fullname" .) -}}
{{- else -}}
{{- fail "mcp.config.embedding.apiKey or mcp.config.embedding.existingSecret is required (Gemini API key for semantic search)" -}}
{{- end -}}
{{- end -}}

{{- define "mcp.embeddingSecretKey" -}}
{{- if .Values.mcp.config.embedding.existingSecret -}}
{{- .Values.mcp.config.embedding.existingSecretKey -}}
{{- else -}}
api-key
{{- end -}}
{{- end -}}

{{/*
Environment shared by the MCP server and the vector sync jobs, which run the
same binary against the same database, Qdrant collection and embedding model.
*/}}
{{- define "mcp.env" -}}
- name: OPENEV_MCP_PORT
  value: {{ .Values.mcp.service.port | quote }}
- name: OPENEV_MCP_HEALTH_PORT
  value: {{ .Values.mcp.service.healthPort | quote }}
- name: OPENEV_MCP_REFRESH_INTERVAL
  value: {{ .Values.mcp.config.refreshInterval | quote }}
- name: OPENEV_MCP_OBSERVABILITY_ENABLED
  value: {{ .Values.mcp.config.observability.enabled | quote }}
- name: OPENEV_MCP_OBSERVABILITY_OTLP_ENDPOINT
  value: {{ .Values.mcp.config.observability.otlpEndpoint | quote }}
- name: OPENEV_MCP_DATABASE_HOST
  value: {{ include "mcp.postgresHost" . | quote }}
- name: OPENEV_MCP_DATABASE_PORT
  value: {{ include "mcp.postgresPort" . | quote }}
- name: OPENEV_MCP_DATABASE_DBNAME
  value: {{ include "mcp.postgresDatabase" . | quote }}
- name: OPENEV_MCP_DATABASE_SSL_MODE
  value: {{ .Values.postgresql.sslMode | quote }}
- name: OPENEV_MCP_DATABASE_USER
  valueFrom:
    secretKeyRef:
      name: {{ include "mcp.postgresSecretName" . }}
      key: {{ include "mcp.postgresUserKey" . }}
- name: OPENEV_MCP_DATABASE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "mcp.postgresSecretName" . }}
      key: {{ include "mcp.postgresPasswordKey" . }}
- name: OPENEV_MCP_QDRANT_HOST
  value: {{ include "mcp.qdrantHost" . | quote }}
- name: OPENEV_MCP_QDRANT_PORT
  value: {{ include "mcp.qdrantPort" . | quote }}
- name: OPENEV_MCP_QDRANT_USE_TLS
  value: {{ include "mcp.qdrantUseTls" . | quote }}
{{- with include "mcp.qdrantSecretName" . }}
- name: OPENEV_MCP_QDRANT_API_KEY
  valueFrom:
    secretKeyRef:
      name: {{ . }}
      key: {{ include "mcp.qdrantSecretKey" $ }}
{{- end }}
- name: OPENEV_MCP_QDRANT_COLLECTION
  value: {{ .Values.mcp.config.search.collection | quote }}
- name: OPENEV_MCP_QDRANT_SEARCH_LIMIT
  value: {{ .Values.mcp.config.search.limit | quote }}
- name: OPENEV_MCP_QDRANT_MIN_SCORE
  value: {{ .Values.mcp.config.search.minScore | quote }}
- name: OPENEV_MCP_EMBEDDING_API_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "mcp.embeddingSecretName" . }}
      key: {{ include "mcp.embeddingSecretKey" . }}
- name: OPENEV_MCP_EMBEDDING_MODEL
  value: {{ .Values.mcp.config.embedding.model | quote }}
- name: OPENEV_MCP_EMBEDDING_DIMENSIONS
  value: {{ .Values.mcp.config.embedding.dimensions | quote }}
- name: OPENEV_MCP_EMBEDDING_BATCH_SIZE
  value: {{ .Values.mcp.config.embedding.batchSize | quote }}
{{- with .Values.mcp.extraEnv }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{/* Pod spec of the vector sync Job, shared by the Helm hook and the CronJob. */}}
{{- define "mcp.vectorSyncPodSpec" -}}
restartPolicy: Never
serviceAccountName: {{ include "mcp.serviceAccountName" . }}
{{- with .Values.mcp.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
securityContext:
  {{- toYaml .Values.mcp.podSecurityContext | nindent 2 }}
containers:
  - name: vector-sync
    image: {{ include "mcp.image" . }}
    imagePullPolicy: {{ .Values.mcp.image.pullPolicy }}
    command: ["/usr/local/bin/openev-data-mcp", "migrate"]
    securityContext:
      {{- toYaml .Values.mcp.securityContext | nindent 6 }}
    env:
      {{- include "mcp.env" . | nindent 6 }}
    resources:
      {{- toYaml .Values.vectorSync.resources | nindent 6 }}
{{- with .Values.mcp.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.mcp.affinity }}
affinity:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.mcp.tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end -}}
