{{/*
Expand the name of the chart.
*/}}
{{- define "netbird.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "netbird.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "netbird.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "netbird.labels" -}}
helm.sh/chart: {{ include "netbird.chart" . }}
{{ include "netbird.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "netbird.selectorLabels" -}}
app.kubernetes.io/name: {{ include "netbird.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Component selector labels.
*/}}
{{- define "netbird.componentSelectorLabels" -}}
{{ include "netbird.selectorLabels" .root }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{/*
NetBird server service name.
*/}}
{{- define "netbird.serverServiceName" -}}
{{- printf "%s-server" (include "netbird.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
NetBird dashboard service name.
*/}}
{{- define "netbird.dashboardServiceName" -}}
{{- printf "%s-dashboard" (include "netbird.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
NetBird data volume name.
*/}}
{{- define "netbird.dataVolumeName" -}}
{{- printf "%s-data" (include "netbird.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
NetBird STUN service name.
*/}}
{{- define "netbird.stunServiceName" -}}
{{- printf "%s-stun" (include "netbird.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
NetBird config secret name.
*/}}
{{- define "netbird.configSecretName" -}}
{{- if .Values.server.config.existingSecret -}}
{{- .Values.server.config.existingSecret -}}
{{- else -}}
{{- printf "%s-config" (include "netbird.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- end -}}

{{/*
Required public domain.
*/}}
{{- define "netbird.domain" -}}
{{- required "domain is required" .Values.domain -}}
{{- end -}}

{{/*
Required server authentication secret.
*/}}
{{- define "netbird.authSecret" -}}
{{- required "server.authSecret is required" .Values.server.authSecret -}}
{{- end -}}

{{/*
Required server database encryption key.
*/}}
{{- define "netbird.encryptionKey" -}}
{{- required "server.encryptionKey is required" .Values.server.encryptionKey -}}
{{- end -}}

{{/*
Resolve automatic database selection from the dependency switch.
*/}}
{{- define "netbird.databaseMode" -}}
{{- if eq .Values.server.database.mode "auto" -}}
{{- if or .Values.server.database.external.dsn .Values.server.database.external.host .Values.server.database.external.existingSecret -}}
external
{{- else if .Values.postgresql.enabled -}}
postgresql
{{- else -}}
sqlite
{{- end -}}

{{- else -}}
{{- .Values.server.database.mode -}}
{{- end -}}
{{- end -}}

{{- define "netbird.databaseExternalPassword" -}}
{{- if .Values.server.database.external.password -}}
{{- .Values.server.database.external.password -}}
{{- else if .Values.server.database.external.existingSecret -}}
{{- $secret := lookup "v1" "Secret" .Release.Namespace .Values.server.database.external.existingSecret -}}
{{- if not $secret -}}
{{- required "external database password Secret/key is required" "" -}}
{{- else -}}
{{- $encodedPassword := index $secret.data .Values.server.database.external.existingSecretPasswordKey -}}
{{- required "external database password Secret/key is required" ($encodedPassword | b64dec) -}}
{{- end -}}
{{- else -}}
{{- required "server.database.external.password or existingSecret is required" .Values.server.database.external.password -}}
{{- end -}}
{{- end -}}

{{/*
Use the bundled PostgreSQL Service and credentials when PostgreSQL is enabled
without an external database configuration.
*/}}
{{- define "netbird.databaseUsesBundledPostgresql" -}}
{{- and (eq (include "netbird.databaseMode" .) "postgresql") .Values.postgresql.enabled -}}
{{- end -}}

{{- define "netbird.databaseHost" -}}
{{- if eq (include "netbird.databaseUsesBundledPostgresql" . | trim) "true" -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- else -}}
{{- required "server.database.external.host is required for external mode" .Values.server.database.external.host -}}
{{- end -}}
{{- end -}}

{{- define "netbird.databasePort" -}}
{{- if eq (include "netbird.databaseUsesBundledPostgresql" . | trim) "true" -}}
5432
{{- else -}}
{{ .Values.server.database.external.port | toString }}
{{- required "server.database.external.port is required for external mode" .Values.server.database.external.port -}}
{{- end -}}
{{- end -}}

{{- define "netbird.databaseUser" -}}
{{- if eq (include "netbird.databaseUsesBundledPostgresql" . | trim) "true" -}}
{{- required "postgresql.auth.username is required for bundled PostgreSQL" .Values.postgresql.auth.username -}}
{{- else -}}
{{- required "server.database.external.username is required for external mode" .Values.server.database.external.username -}}
{{- end -}}
{{- end -}}

{{- define "netbird.databasePassword" -}}
{{- if eq (include "netbird.databaseUsesBundledPostgresql" . | trim) "true" -}}
{{- required "postgresql.auth.postgresPassword is required for bundled PostgreSQL" .Values.postgresql.auth.postgresPassword -}}
{{- else -}}
{{- include "netbird.databaseExternalPassword" . -}}
{{- end -}}
{{- end -}}

{{/*
SQLite supports a single server replica because the data volume and database
are not designed for concurrent writers.
*/}}
{{- define "netbird.serverReplicaCount" -}}
{{- if eq (include "netbird.databaseMode" .) "sqlite" -}}
1
{{- else -}}
{{- .Values.server.replicaCount -}}
{{- end -}}
{{- end -}}

{{/*
SQLite requires a recreate update to avoid overlapping volume mounts.
*/}}
{{- define "netbird.serverStrategyType" -}}
{{- if eq (include "netbird.databaseMode" .) "sqlite" -}}
Recreate
{{- else -}}
{{- .Values.server.strategy.type -}}
{{- end -}}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "netbird.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "netbird.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end -}}

{{- define "netbird.bootstrapServiceAccountName" -}}
{{- if .Values.bootstrap.serviceAccount.create -}}
{{- default (printf "%s-bootstrap" (include "netbird.fullname" .)) .Values.bootstrap.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.bootstrap.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "netbird.bootstrapApiKeySecretName" -}}
{{- default (printf "%s-mgmt-api-key" (include "netbird.fullname" .)) .Values.bootstrap.apiKeySecretName -}}
{{- end -}}

{{- define "netbird.bootstrapCredentialsSecretName" -}}
{{- if .Values.bootstrap.existingCredentialsSecret -}}
{{- .Values.bootstrap.existingCredentialsSecret -}}
{{- else -}}
{{- printf "%s-bootstrap-credentials" (include "netbird.fullname" .) -}}
{{- end -}}
{{- end -}}
