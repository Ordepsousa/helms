{{/* core name */}}
{{- define "paperless.coreName" -}}
    {{- printf "%s-core" (include "common.names.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* webserver name */}}
{{- define "paperless.webServerName" -}}
    {{- printf "%s-webserver" (include "common.names.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* worker name */}}
{{- define "paperless.workerName" -}}
    {{- printf "%s-worker" (include "common.names.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* paperless-ngx image */}}
{{- define "paperless.image" -}}
    {{ include "common.images.image" (dict "imageRoot" .Values.image "global" .Values.global) }}
{{- end -}}

{{/* api token job image */}}
{{- define "paperless.apiTokenImage" -}}
    {{ include "common.images.image" (dict "imageRoot" .Values.apiTokenJob.image "global" .Values.global) }}
{{- end -}}

{{/* apache tika image */}}
{{- define "paperless.tikaImage" -}}
    {{ include "common.images.image" (dict "imageRoot" .Values.core.tika.image "global" .Values.global) }}
{{- end -}}

{{/* gotenberg image */}}
{{- define "paperless.gotenbergImage" -}}
    {{ include "common.images.image" (dict "imageRoot" .Values.core.gotenberg.image "global" .Values.global) }}
{{- end -}}

{{/* Return the proper Docker Image Registry Secret Names */}}
{{- define "paperless.imagePullSecrets" -}}
    {{- include "common.images.renderPullSecrets" (dict "images" (list .Values.image .Values.apiTokenJob.image .Values.core.tika.image .Values.core.gotenberg.image) "context" .) -}}
{{- end -}}

{{/* gotenberg service name */}}
{{- define "paperless.gotenbergServiceName" -}}
    {{- printf "%s-gotenberg" (include "common.names.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* tika service name */}}
{{- define "paperless.tikaServiceName" -}}
    {{- printf "%s-tika" (include "common.names.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* apiToken job name */}}
{{- define "paperless.apiTokenJobName" -}}
    {{- printf "%s-api-token" (include "common.names.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* config secret name */}}
{{- define "paperless.configSecretName" -}}
    {{- if .Values.config.existingSecret -}}
        {{- .Values.config.existingSecret -}}
    {{- else -}}
        {{- printf "%s-config" (include "common.names.fullname" .) | trunc 63 | trimSuffix "-" -}}
    {{- end -}}
{{- end -}}

{{/* Resolve automatic database selection from the dependency switch */}}
{{- define "paperless.databaseMode" -}}
    {{- if eq .Values.config.database.mode "auto" -}}
        {{- if .Values.config.database.external.host -}}
            {{- print "external" -}}
        {{- else if .Values.postgresql.enabled -}}
            {{- print "postgresql" -}}
        {{- else -}}
            {{- print "sqlite" -}}
        {{- end -}}
    {{- else -}}
        {{- .Values.config.database.mode -}}
    {{- end -}}
{{- end -}}

{{/*
Use the bundled PostgreSQL Service and credentials when PostgreSQL is enabled
without an external database configuration
*/}}
{{- define "paperless.databaseUsesBundledPostgresql" -}}
    {{- and (eq (include "paperless.databaseMode" .) "postgresql") .Values.postgresql.enabled -}}
{{- end -}}

{{/* database password secret name */}}
{{- define "paperless.databasePasswordSecretName" -}}
    {{- if eq (include "paperless.databaseMode" .) "postgresql" -}}
        {{- printf "%s-postgresql" .Release.Name -}}
    {{- else if .Values.config.database.external.existingSecret -}}
        {{- .Values.config.database.external.existingSecret -}}
    {{- else -}}
        {{- printf "%s-database" (include "common.names.fullname" .) -}}
    {{- end -}}
{{- end -}}

{{/* database password secret key */}}
{{- define "paperless.databasePasswordSecretKey" -}}
    {{- if eq (include "paperless.databaseMode" .) "postgresql" -}}
        {{- print "password" -}}
    {{- else -}}
        {{- .Values.config.database.external.existingSecretPasswordKey | default "password" -}}
    {{- end -}}
{{- end -}}

{{/* database host */}}
{{- define "paperless.databaseHost" -}}
    {{- if eq (include "paperless.databaseUsesBundledPostgresql" . | trim) "true" -}}
        {{- printf "%s-postgresql" .Release.Name -}}
    {{- else -}}
        {{- required "config.database.external.host is required for external mode" .Values.config.database.external.host -}}
    {{- end -}}
{{- end -}}

{{/* database port */}}
{{- define "paperless.databasePort" -}}
    {{- if eq (include "paperless.databaseUsesBundledPostgresql" . | trim) "true" -}}
        {{- .Values.postgresql.primary.service.ports.postgresql -}}
    {{- else -}}
        {{- required "config.database.external.port is required for external mode" .Values.config.database.external.port -}}
    {{- end -}}
{{- end -}}

{{/* database name */}}
{{- define "paperless.databaseName" -}}
    {{- if eq (include "paperless.databaseMode" .) "postgresql" -}}
        {{- .Values.postgresql.auth.database -}}
    {{- else -}}
        {{- .Values.config.database.external.name -}}
    {{- end -}}
{{- end -}}

{{/* database user */}}
{{- define "paperless.databaseUser" -}}
    {{- if eq (include "paperless.databaseUsesBundledPostgresql" . | trim) "true" -}}
        {{- required "postgresql.auth.username is required for bundled PostgreSQL" .Values.postgresql.auth.username -}}
    {{- else -}}
        {{- required "config.database.external.username is required for external mode" .Values.config.database.external.username -}}
    {{- end -}}
{{- end -}}

{{/* database redis url */}}
{{- define "paperless.redis.url" -}}
    {{- $d := .Values.dragonfly -}}
    {{- $ext := .Values.config.redis.external -}}

    {{- $host := $d.enabled | ternary (printf "%s-dragonfly" .Release.Name) .Values.config.redis.external.host -}}
    {{- $port := $d.enabled | ternary (toString .Values.dragonfly.service.port) (toString $ext.port) -}}
    {{- $user := $d.enabled | ternary "" $ext.username -}}
    {{- $pass := $d.enabled | ternary "" $ext.password -}}
    {{- $index := $d.enabled | ternary "0" (default "0" $ext.index) -}}

    {{- if and $user $pass -}}
        {{- printf "redis://%s:%s@%s:%s/%s" $user $pass $host $port $index -}}
    {{- else if $pass -}}
        {{- printf "redis://:%s@%s:%s/%s" $pass $host $port $index -}}
    {{- else -}}
        {{- printf "redis://%s:%s/%s" $host $port $index -}}
    {{- end -}}
{{- end -}}

{{/* database base env to be used by all paperless containers */}}
{{- define "paperless.baseEnv" -}}
-   name: PAPERLESS_SECRET_KEY
    valueFrom:
        secretKeyRef:
            name: {{ include "paperless.configSecretName" . }}
            key: secretKey
{{- if ne (include "paperless.databaseMode" .) "sqlite" }}
-   name: PAPERLESS_DBENGINE
    value: "{{- if eq .Values.config.database.external.engine "mysql" -}}mariadb{{- else -}}postgresql{{- end -}}"
-   name: PAPERLESS_DBHOST
    value: {{ include "paperless.databaseHost" . | quote }}
-   name: PAPERLESS_DBPORT
    value: {{ include "paperless.databasePort" . | quote }}
-   name: PAPERLESS_DBNAME
    value: {{ include "paperless.databaseName" . | quote }}
-   name: PAPERLESS_DBUSER
    value: {{ include "paperless.databaseUser" . | quote }}
-   name: PAPERLESS_DBPASS
    valueFrom:
        secretKeyRef:
            name: {{ include "paperless.databasePasswordSecretName" . }}
            key: {{ include "paperless.databasePasswordSecretKey" . }}
{{- end }}
-   name: PAPERLESS_REDIS
    value: {{ include "paperless.redis.url" . | quote }}
-   name: PAPERLESS_DATA_DIR
    value: {{ .Values.persistence.data.mountPath | quote }}
{{- end -}}

{{/* webserver replica count defaults to 1 if database is SQLite */}}
{{- define "paperless.webServerReplicaCount" -}}
    {{- if eq (include "paperless.databaseMode" .) "sqlite" -}}
        {{- int 1 -}}
    {{- else -}}
        {{- .Values.webserver.replicaCount -}}
    {{- end -}}
{{- end -}}

{{/* worker replica count defaults to 1 if database is SQLite */}}
{{- define "paperless.workerReplicaCount" -}}
    {{- if eq (include "paperless.databaseMode" .) "sqlite" -}}
        {{- int 1 -}}
    {{- else -}}
        {{- .Values.worker.replicaCount -}}
    {{- end -}}
{{- end -}}

{{/* web server strategy type - SQLite requires a Recreate update to avoid overlapping volume mounts */}}
{{- define "paperless.webServerStrategyType" -}}
    {{- if eq (include "paperless.databaseMode" .) "sqlite" -}}
        {{- print "Recreate" -}}
    {{- else -}}
        {{- .Values.webserver.strategy.type -}}
    {{- end -}}
{{- end -}}

{{/* worker strategy type - SQLite requires a Recreate update to avoid overlapping volume mounts */}}
{{- define "paperless.workerStrategyType" -}}
    {{- if eq (include "paperless.databaseMode" .) "sqlite" -}}
        {{- print "Recreate" -}}
    {{- else -}}
        {{- .Values.worker.strategy.type -}}
    {{- end -}}
{{- end -}}

{{/* service account name to use */}}
{{- define "paperless.serviceAccountName" -}}
    {{- if .Values.serviceAccount.create }}
        {{- default (include "common.names.fullname" .) .Values.serviceAccount.name }}
    {{- else }}
        {{- default "default" .Values.serviceAccount.name }}
    {{- end }}
{{- end -}}

{{/* api token service account name to use */}}
{{- define "paperless.apiTokenServiceAccountName" -}}
    {{- if .Values.apiTokenJob.serviceAccount.create -}}
        {{- default (printf "%s-api-token" (include "common.names.fullname" .)) .Values.apiTokenJob.serviceAccount.name -}}
    {{- else -}}
        {{- default "default" .Values.apiTokenJob.serviceAccount.name -}}
    {{- end -}}
{{- end -}}

{{/* secret name to store the api key */}}
{{- define "paperless.apiKeySecretName" -}}
    {{- default (printf "%s-token-secret" (include "common.names.fullname" .)) .Values.apiTokenJob.apiKeySecretName -}}
{{- end -}}

{{/* credentials secret name - returns existingCredentialsSecret or, if empty, a name for the generated secret */}}
{{- define "paperless.credentialsSecretName" -}}
    {{- if .Values.config.existingCredentialsSecret -}}
        {{- .Values.config.existingCredentialsSecret -}}
    {{- else -}}
        {{- printf "%s-credentials" (include "common.names.fullname" .) -}}
    {{- end -}}
{{- end -}}

{{/* scratch path to store the temporary media uploaded to be processed */}}
{{- define "paperless.scratchPath" -}}
    {{- printf "%s/scratch" .Values.persistence.media.mountPath -}}
{{- end -}}

{{/* generate volumes */}}
{{- define "paperless.volumes" -}}
    {{- $context := .context -}}
    {{- range $volName := .volumes -}}
        {{- $volConfig := index $context.Values.persistence $volName }}
-   name: {{ $volName }}
        {{- if $volConfig.existingClaim }}
    persistentVolumeClaim:
        claimName: {{ $volConfig.existingClaim | quote }}
        {{- else if $volConfig.enabled }}
    persistentVolumeClaim:
        claimName: {{ $volConfig.volumeName | quote }}
        {{- else }}
    emptyDir: {}
        {{- end }}
    {{- end -}}
{{- end -}}

{{/* database base env to be used by all paperless containers */}}
{{- define "paperless.baseVolumeMounts" -}}
-   name: data
    mountPath: {{ .Values.persistence.data.mountPath }}
    {{- if .Values.persistence.data.subPath }}
    subPath: {{ .Values.persistence.data.subPath }}
    {{- end }}
{{- end -}}

{{/* wait for core initContainer used to wait for databse, migrations, tika and gotenberg to be ready */}}
{{- define "paperless.waitForCore" -}}
-   name: wait-for-core
    image: {{ include "paperless.image" . | quote }}
    imagePullPolicy: {{ .Values.image.pullPolicy }}
    command:
        - /bin/sh
        - -c
        - |
            set -eu
            echo "Waiting for database and migrations..."
            until python3 manage.py migrate --check; do
                echo "Database or migrations are not ready yet. Retrying..."
                sleep 3
            done
            {{- if .Values.core.tika.enabled }}
            echo "Waiting for Tika..."
            until curl -fsS "http://{{ include "paperless.tikaServiceName" . }}:{{ .Values.core.tika.service.port }}/" >/dev/null; do
                echo "Tika is not ready yet. Retrying..."
                sleep 3
            done
            {{- end }}
            {{- if .Values.core.gotenberg.enabled }}
            echo "Waiting for Gotenberg..."
            until curl -fsS "http://{{ include "paperless.gotenbergServiceName" . }}:{{ .Values.core.gotenberg.service.port }}/health" >/dev/null; do
                echo "Gotenberg is not ready yet. Retrying..."
                sleep 3
            done
            {{- end }}
            echo "Ready"
    {{- if .Values.waitForCore.containerSecurityContext.enabled }}
    securityContext: {{- include "common.compatibility.renderSecurityContext" (dict "secContext" .Values.waitForCore.containerSecurityContext "context" $) | nindent 8 }}
    {{- end }}
    env: {{- include "paperless.baseEnv" . | nindent 8 }}
        {{- if .Values.waitForCore.extraEnvVars }}
        {{- include "common.tplvalues.render" (dict "value" .Values.waitForCore.extraEnvVars "context" $) | nindent 8 }}
        {{- end }}
    resources: {{- toYaml .Values.waitForCore.resources | nindent 8 }}
    volumeMounts: {{- include "paperless.baseVolumeMounts" . | nindent 8 }}
        -   name: wait-tmp
            mountPath: /tmp
        {{- if .Values.waitForCore.extraVolumeMounts }}
        {{- include "common.tplvalues.render" (dict "value" .Values.waitForCore.extraVolumeMounts "context" $) | nindent 8 }}
        {{- end }}
{{- end -}}