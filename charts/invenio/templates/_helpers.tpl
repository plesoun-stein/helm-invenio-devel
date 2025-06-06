{{/*
Expand the name of the chart.
*/}}
{{- define "invenio.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name, the release name will be used as a full name.
*/}}
{{- define "invenio.fullname" -}}
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
{{- define "invenio.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "invenio.selectorLabels" -}}
app.kubernetes.io/name: {{ include "invenio.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "invenio.labels" -}}
helm.sh/chart: {{ include "invenio.chart" . }}
{{ include "invenio.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Return the proper Invenio image name
*/}}
{{- define "invenio.image" -}}
{{- $registryName :=  required "Missing .Values.image.registry" .Values.image.registry -}}
{{- $repositoryName :=  required "Missing .Values.image.repository" .Values.image.repository -}}
{{- $separator := ":" -}}
{{- $termination := .Values.image.tag | default .Chart.AppVersion | toString -}}

{{- if .Values.image.digest }}
  {{- $separator = "@" -}}
  {{- $termination = .Values.image.digest | toString -}}
{{- end -}}

{{- printf "%s/%s%s%s" $registryName $repositoryName $separator $termination -}}
{{- end -}}

###########################     Invenio hostname     ###########################
{{/*
  This template renders the hostname for Invenio.
*/}}
{{- define "invenio.hostname" -}}
  {{- tpl (required "Missing .Values.invenio.hostname" .Values.invenio.hostname) . }}
{{- end -}}

############################     Redis Hostname     ############################

{{/*
  This template renders the name of the default secret that stores info about RabbitMQ.
*/}}
{{- define "invenio.redis.secretName" -}}
  {{- if .Values.redis.enabled }}
    {{- include "redis.secretName" .Subcharts.redis }}
  {{- else if and (not .Values.redis.enabled) .Values.redisExternal.existingSecret }}
    {{- required "Missing .Values.redisExternal.existingSecret" .Values.redisExternal.existingSecret }}
  {{- else }}
    {{- fail (printf "\n\nthere is somthing wrong with redis secret,\n\nI'm printing contexts for redis\n\ninternal config\n%v\n\nexternal config\n%v" (toYaml .Values.redis) (toYaml .Values.redisExternal)) | indent 4 }} 
  {{- end }}
{{- end -}}



{{/*
  This template renders the hostname for Redis.
*/}}
{{- define "invenio.redis.hostname" -}}
  {{- if .Values.redis.enabled }}
{{- printf "value: %s-master" (include "common.names.fullname" .Subcharts.redis) | nindent 0 }}
  {{- else if and (not .Values.redis.enabled) .Values.redisExternal.hostname }}
{{- printf "value: %q" .Values.redisExternal.hostname | nindent 0 }}
  {{- else }}
valueFrom:
  secretKeyRef:
    name: {{ coalesce .Values.redisExternal.hostnameSecret (include "invenio.redis.secretName" . | trim) }}
    key: {{ required "Missing .Values.redisExternal.hostnameKey" (tpl  .Values.redisExternal.hostnameKey .) }}
  {{- end -}}
{{- end -}}


{{/*
  This template renders the password for Redis.
*/}}
{{- define "invenio.redis.password" -}}
  {{- if and .Values.redis.enabled .Values.redis.auth.enabled }}
{{- printf "value: %s" (required "Missing .Values.redis.auth.username" (tpl .Values.redis.auth.username .)) | nindent 0 }}
  {{- else if and (not .Values.redis.enabled) .Values.redisExternal.password }}
{{- printf "value: %q" (.Values.redisExternal.password | toString) | nindent 0 }}
  {{- else if and (not .Values.redis.enabled) .Values.redisExternal.passwordKey }}
valueFrom:
  secretKeyRef:
    name: {{ coalesce .Values.redisExternal.passwordSecret (include "invenio.redis.secretName" . | trim) }}
    key: {{ required "Missing .Values.redisExternal.passwordKey" (tpl  .Values.redisExternal.passwordKey .) }}
  {{- else }}
{{- fail (printf "\n\nthere is somthing wrong with redis password,\n\nI'm printing contexts for redis\n\ninternal config:\n%v\n\nexternal config:\n%v" (toYaml .Values.redis) (toYaml .Values.redisExternal)) | indent 4 }} 
  {{- end -}}
{{- end -}}

{{/*
  This template renders the protocol for accessing Redis.
*/}}
{{- define "invenio.redis.protocol" -}}
  {{- if .Values.redis.enabled }}
{{- printf "value: redis" | nindent 0 }}
  {{- else if and (not .Values.redis.enabled) .Values.redisExternal.protocol }}
{{- printf "value: %s" .Values.redisExternal.protocol | nindent 0 }}
  {{- else if and (not .Values.redis.enabled) .Values.redisExternal.protocolKey }}
valueFrom:
  secretKeyRef:
    name: {{ coalesce .Values.redisExternal.protocolSecret (include "invenio.redis.secretName" . | trim) }}
    key: {{ required "Missing .Values.redisExternal.protocolKey" (tpl  .Values.redisExternal.protocolKey .) }}
  {{- else }}  
{{- printf "value: redis" | nindent 0 }}
  {{- end -}}
{{- end -}}

{{/*
  This template renders the port for accessing Redis.
*/}}
{{- define "invenio.redis.port" -}}
  {{- if .Values.redis.enabled }}
{{- printf "value: 6379" | nindent 0 }}
  {{- else if and (not .Values.redis.enabled) .Values.redisExternal.port }}
{{- printf "value: %q" (.Values.redisExternal.port | toString) | nindent 0 }}
  {{- else if and (not .Values.redis.enabled) .Values.redisExternal.portKey }}
valueFrom:
  secretKeyRef:
    name: {{ coalesce .Values.redisExternal.portSecret (include "invenio.redis.secretName" . | trim) }}
    key: {{ required "Missing .Values.redisExternal.portKey" (tpl  .Values.redisExternal.portKey .) }}
  {{- else }}  
{{- printf "value: %q" "6379" | nindent 0 }}
  {{- end -}}
{{- end -}}

{{/*
  This template renders the whole config for the Redis instance used.
*/}}
{{- define "invenio.config.cache" -}}
{{- $connectionString := ":$(INVENIO_CONFIG_REDIS_PASSWORD)@$(INVENIO_CONFIG_REDIS_HOST)" -}}
{{- $connectionUrl := "$(INVENIO_CONFIG_REDIS_PROTOCOL)://:$(INVENIO_CONFIG_REDIS_PASSWORD)@$(INVENIO_CONFIG_REDIS_HOST):$(INVENIO_CONFIG_REDIS_PORT)" }}
- name: INVENIO_CONFIG_REDIS_HOST
  {{- (include "invenio.redis.hostname" . | trim) | nindent 2 }}
- name: INVENIO_CONFIG_REDIS_PORT
  {{- (include "invenio.redis.port" . | trim) | nindent 2 }}
- name: INVENIO_CONFIG_REDIS_PROTOCOL
  {{- (include "invenio.redis.protocol" . | trim) | nindent 2 }}
- name: INVENIO_CONFIG_REDIS_PASSWORD
  {{- (include "invenio.redis.password" . | trim) | nindent 2 }}
- name: INVENIO_ACCOUNTS_SESSION_REDIS_URL
  value: {{ printf "%s/1" $connectionUrl }}
- name: INVENIO_CACHE_REDIS_HOST
  value:  {{ $connectionString  }}
- name: INVENIO_CACHE_REDIS_URL
  value: {{ printf "%s/0" $connectionUrl }}
- name: INVENIO_CELERY_RESULT_BACKEND
  value: {{ printf "%s/2" $connectionUrl }}
- name: INVENIO_IIIF_CACHE_REDIS_URL
  value: {{ printf "%s/0" $connectionUrl }}
- name: INVENIO_RATELIMIT_STORAGE_URI
  value: {{ printf "%s/3" $connectionUrl }}
- name: INVENIO_COMMUNITIES_IDENTITIES_CACHE_REDIS_URL
  value: {{ printf "%s/4" $connectionUrl }}
{{- end -}}

#######################     Ingress TLS secret name     #######################
{{/*
  This template renders the name of the TLS secret used in
  `Ingress.spec.tls.secretName`.
*/}}
{{- define "invenio.tlsSecretName" -}}
  {{- if .Values.ingress.tlsSecretNameOverride }}
    {{- tpl .Values.ingress.tlsSecretNameOverride $ }}
  {{- else }}
    {{- include "invenio.hostname" . -}}-tls
  {{- end }}
{{- end -}}

#######################     RabbitMQ connection configuration     #######################
{{/*
  This template renders the name of the default secret that stores info about RabbitMQ.
*/}}
{{- define "invenio.rabbitmq.secretName" -}}
  {{- if .Values.rabbitmq.enabled }}
    {{- include "rabbitmq.secretPasswordName" .Subcharts.rabbitmq }}
  {{- else if and (not .Values.rabbitmq.enabled) .Values.rabbitmqExternal.existingSecret }}
    {{- required "Missing .Values.rabbitmqExternal.existingSecret" .Values.rabbitmqExternal.existingSecret }}
  {{- else }}
    {{- fail (printf "\n\nthere is somthing wrong with rabbitmq secret,\n\nI'm printing contexts for rabbitmq\n\ninternal config\n%v\n\nexternal config\n%v" (toYaml .Values.rabbitmq) (toYaml .Values.rabbitmqExternal)) | indent 4 }} 
  {{- end }}
{{- end -}}

{{/*
  This template renders the username for accessing RabbitMQ.
*/}}
{{- define "invenio.rabbitmq.username" -}}
  {{- if .Values.rabbitmq.enabled }}
{{- printf "value: %s" (required "Missing .Values.rabbitmq.auth.username" (tpl .Values.rabbitmq.auth.username .)) | nindent 0 }}
  {{- else if and (not .Values.rabbitmq.enabled) .Values.rabbitmqExternal.username }}
{{- printf "value: %s" .Values.rabbitmqExternal.username | nindent 0 }}
  {{- else }}
valueFrom:
  secretKeyRef:
    name: {{ coalesce .Values.rabbitmqExternal.usernameSecret (include "invenio.rabbitmq.secretName" . | trim) }}
    key: {{ required "Missing .Values.rabbitmqExternal.usernameKey" (tpl  .Values.rabbitmqExternal.usernameKey .) }}
  {{- end -}}
{{- end -}}



{{/*
  This template renders the password for accessing RabbitMQ.
*/}}
{{- define "invenio.rabbitmq.password" -}}
  {{- if .Values.rabbitmq.enabled }}
{{- printf "value: %s" (required "Missing .Values.rabbitmq.auth.password" (tpl .Values.rabbitmq.auth.password .)) | nindent 0 }}
  {{- else if and (not .Values.rabbitmq.enabled) .Values.rabbitmqExternal.password }}
{{- printf "value: %s" .Values.rabbitmqExternal.password | nindent 0 }}
  {{- else }}
valueFrom:
  secretKeyRef:
    name: {{ coalesce .Values.rabbitmqExternal.passwordSecret (include "invenio.rabbitmq.secretName" . | trim) }}
    key: {{ required "Missing .Values.rabbitmqExternal.passwordKey" (tpl  .Values.rabbitmqExternal.passwordKey .) }}
  {{- end -}}
{{- end -}}



{{/*
  This template renders the AMQP port number for RabbitMQ.
*/}}
{{- define "invenio.rabbitmq.amqpPortString" -}}
  {{- if .Values.rabbitmq.enabled }}
{{- printf "value: %q" (required "Missing .Values.rabbitmq.service.ports.amqp" (tpl (.Values.rabbitmq.service.ports.amqp | toString) .)) | nindent 0 }}
  {{- else if and (not .Values.rabbitmq.enabled) .Values.rabbitmqExternal.amqpPort }}
{{- printf "value: %q" (.Values.rabbitmqExternal.amqpPort | toString) | nindent 0 }}
  {{- else }}
valueFrom:
  secretKeyRef:
    name: {{ coalesce .Values.rabbitmqExternal.amqpPortSecret (include "invenio.rabbitmq.secretName" . | trim) }}
    key: {{ required "Missing .Values.rabbitmqExternal.amqpPortKey" (tpl  .Values.rabbitmqExternal.amqpPortKey .) }}
  {{- end -}}
{{- end -}}


{{/*
  This template renders the management port number for RabbitMQ.
*/}}
{{- define "invenio.rabbitmq.managementPortString" -}}
  {{- if .Values.rabbitmq.enabled }}
{{- printf "value: %q" (required "Missing .Values.rabbitmq.service.ports.manager" (tpl .Values.rabbitmq.service.ports.manager .)) | nindent 0 }}
  {{- else if and (not .Values.rabbitmq.enabled) .Values.rabbitmqExternal.managementPort }}
{{- printf "value: %q" .Values.rabbitmqExternal.managementPort | nindent 0 }}
  {{- else }}
valueFrom:
  secretKeyRef:
    name: {{ coalesce .Values.rabbitmqExternal.managementPortSecret (include "invenio.rabbitmq.secretName" . | trim) }}
    key: {{ required "Missing .Values.rabbitmqExternal.managementPortKey" (tpl  .Values.rabbitmqExternal.managementPortKey .) }}
  {{- end -}}
{{- end -}}


{{/*
  This template renders the hostname for RabbitMQ.
*/}}
{{- define "invenio.rabbitmq.hostname" -}}
  {{- if .Values.rabbitmq.enabled }}
{{- printf "value: %s" (include "common.names.fullname" .Subcharts.rabbitmq) | nindent 0 }}
  {{- else if and (not .Values.rabbitmq.enabled) .Values.rabbitmqExternal.hostname }}
{{- printf "value: %q" .Values.rabbitmqExternal.hostname | nindent 0 }}
  {{- else }}
valueFrom:
  secretKeyRef:
    name: {{ coalesce .Values.rabbitmqExternal.hostnameSecret (include "invenio.rabbitmq.secretName" . | trim) }}
    key: {{ required "Missing .Values.rabbitmqExternal.hostnameKey" (tpl  .Values.rabbitmqExternal.hostnameKey .) }}
  {{- end -}}
{{- end -}}

{{/*
  This template renders the protocol for RabbitMQ.
*/}}
{{- define "invenio.rabbitmq.protocol" -}}
  {{- if .Values.rabbitmq.enabled }}
{{- printf "value: amqp" | nindent 0 }}
  {{- else if and (not .Values.rabbitmq.enabled) .Values.rabbitmqExternal.protocol }}
{{- printf "value: %q" .Values.rabbitmqExternal.protocol | nindent 0 }}
  {{- else }}
valueFrom:
  secretKeyRef:
    name: {{ coalesce .Values.rabbitmqExternal.protocolSecret (include "invenio.rabbitmq.secretName" . | trim) }}
    key: {{ required "Missing .Values.rabbitmqExternal.protocolKey" (tpl  .Values.rabbitmqExternal.protocolKey .) }}
  {{- end -}}
{{- end -}}

{{/*
  This template renders the vhost for RabbitMQ.
*/}}
{{- define "invenio.rabbitmq.vhost" -}}
  {{- if .Values.rabbitmq.enabled }}
{{- printf "value: %q" "" | nindent 0 }}
  {{- else if and (not .Values.rabbitmq.enabled) (hasKey .Values.rabbitmqExternal "vhost") }}
{{- printf "value: %q" .Values.rabbitmqExternal.vhost | nindent 0 }}
  {{- else }}
valueFrom:
  secretKeyRef:
    name: {{ coalesce .Values.rabbitmqExternal.vhostSecret (include "invenio.rabbitmq.secretName" . | trim) }}
    key: {{ required "Missing .Values.rabbitmqExternal.vhostKey" (tpl  .Values.rabbitmqExternal.vhostKey .) }}
  {{- end -}}
{{- end -}}


{{/*
  RabbitMQ connection env section.
*/}}
{{- define "invenio.config.queue" -}}
{{- $uri := "$(INVENIO_AMQP_BROKER_PROTOCOL)://$(INVENIO_AMQP_BROKER_USER):$(INVENIO_AMQP_BROKER_PASSWORD)@$(INVENIO_AMQP_BROKER_HOST):$(INVENIO_AMQP_BROKER_PORT)/$(INVENIO_AMQP_BROKER_VHOST)" -}}
- name: INVENIO_AMQP_BROKER_USER
  {{- (include "invenio.rabbitmq.username" . | trim) | nindent 2 }}
- name: INVENIO_AMQP_BROKER_HOST
  {{- (include "invenio.rabbitmq.hostname" . | trim) | nindent 2 }}
- name: INVENIO_AMQP_BROKER_PORT
  {{- (include "invenio.rabbitmq.amqpPortString" . | trim) | nindent 2 }}
- name: INVENIO_AMQP_BROKER_VHOST
  {{- (include "invenio.rabbitmq.vhost" . | trim) | nindent 2 }}
- name: INVENIO_AMQP_BROKER_PROTOCOL
  {{- (include "invenio.rabbitmq.protocol" . | trim) | nindent 2 }}
- name: INVENIO_AMQP_BROKER_PASSWORD
  {{- (include "invenio.rabbitmq.password" . | trim) | nindent 2 }}
- name: INVENIO_BROKER_URL
  value: {{ $uri }}
- name: INVENIO_CELERY_BROKER_URL
  value: $(INVENIO_BROKER_URL)
- name: RABBITMQ_API_URI
  value: "http://$(INVENIO_AMQP_BROKER_USER):$(INVENIO_AMQP_BROKER_PASSWORD)@$(INVENIO_AMQP_BROKER_HOST):$(INVENIO_AMQP_BROKER_PORT)/api/"
{{- end -}}

{{/*
  Define a projected volume for PostgreSQL config file.

  Usage:
    {{ include "invenio.rabbitmq.configFile" . | nindent 6 }}

  Expected context:
    .Values.rabbitmqExternal.*
*/}}

{{- define "invenio.rabbitmq.configFile" -}}
{{- $fields := dict "username" "password" "hostname" "portString" "vhost" "protocol" }}
{{- $parts := dict }}

{{- $root := . }}
- name: rabbitmq-config
  projected:
    sources:
    {{- if or .Values.rabbitmqExternal.uri }}
    - secret:
        name: invenio-rabbitmq-inline
	items:
	- key: uri
	  path: INVENIO_SQLALCHEMY_DATABASE_URI
    {{- else if .Values.rabbitmqExternal.uriKey }}
    - secret:
        name: {{ coalesce .Values.rabbitmqExternal.uriSecret (include "invenio.rabbitmq.secretName" $root | trim) }} 
        items:
        - key: {{ .Values.rabbitmqExternal.uriKey }} 
          path: INVENIO_SQLALCHEMY_DATABASE_URI
    {{- else }}
    {{- range $item, $value := $fields }}
    - secret:
      {{- if hasKey $root.Values.rabbitmqExternal $item }}
        name: invenio-rabbitmq-inline
        items:
        - key: {{ $item }}
          path: {{ $value }}
      {{- else }}
        {{- $keyName := (printf "%sKey" $item) }}
        {{- $secretName := (printf "%sSecret" $item) }}
        name: {{ coalesce (get $root.Values.rabbitmqExternal $secretName) (include "invenio.rabbitmq.secretName" $root | trim) }}
        items: 
        - key: {{ get $root.Values.rabbitmqExternal $keyName }}
          path: {{ $value | toString }}
      {{- end }}
      {{- end }}
    {{- end }}
{{- end }}





#########################     OpenSearch hostname     #########################
{{/*
  This template renders the hostname of the OpenSearch instance.
*/}}
{{- define "invenio.opensearch.hostname" -}}
  {{- if .Values.opensearch.enabled }}
    {{- include "opensearch.service.name" .Subcharts.opensearch -}}
  {{- else }}
    {{- required "Missing .Values.opensearchExternal.hostname" .Values.opensearchExternal.hostname -}}
  {{- end }}
{{- end -}}

#########################     PostgreSQL connection configuration     #########################

{{/*
  Get the database cluster config secret name
*/}}
{{- define "invenio.postgresql.secretName" -}}
  {{- if .Values.postgresql.enabled -}}
    {{- required "Missing .Values.postgresql.auth.existingSecret" (tpl .Values.postgresql.auth.existingSecret .) -}}
  {{- else -}}
    {{- required "Missing .Values.postgresqlExternal.existingSecret" (tpl .Values.postgresqlExternal.existingSecret .) -}}
  {{- end -}}
{{- end -}}

{{/*
  This template renders the username used for the PostgreSQL instance.
*/}}
{{- define "invenio.postgresql.username" -}}
  {{- if .Values.postgresql.enabled -}}
{{- printf "value: %s" (required "Missing .Values.postgresql.auth.username" (tpl .Values.postgresql.auth.username .)) | nindent 0 }}
  {{- else if and (not .Values.postgresql.enabled) .Values.postgresqlExternal.username }}
{{- printf "value: %s" .Values.postgresqlExternal.username | nindent 0 }}
  {{- else }}
valueFrom:
  secretKeyRef:
    name: {{ coalesce .Values.postgresqlExternal.usernameSecret (include "invenio.postgresql.secretName" . | trim) }}
    key: {{ required "Missing .Values.postgresqlExternal.usernameKey" (tpl  .Values.postgresqlExternal.usernameKey .) }}
  {{- end -}}
{{- end -}}

{{/*
  This template renders the hostname used for the PostgreSQL instance.
*/}}

{{- define "invenio.postgresql.hostname" -}}
  {{- if .Values.postgresql.enabled -}}
{{- printf "value: %s" (include "postgresql.v1.primary.fullname" .Subcharts.postgresql) | nindent 0 -}}
  {{- else if and (not .Values.postgresql.enabled) .Values.postgresqlExternal.hostname }}
{{- printf "value: %s" .Values.postgresqlExternal.hostname | nindent 0 }}
  {{- else }}
valueFrom:
  secretKeyRef:
    name: {{ coalesce .Values.postgresqlExternal.hostnameSecret (include "invenio.postgresql.secretName" . | trim) }}
    key: {{ required "Missing .Values.postgresqlExternal.hostnameKey" (tpl  .Values.postgresqlExternal.hostnameKey .) }}
  {{- end -}}
{{- end -}}

{{/*
  This template renders the password used for the PostgreSQL instance.
  In production environments we encourage you to use secrets instead.
*/}}

{{- define "invenio.postgresql.password" -}}
  {{- if .Values.postgresql.enabled -}}
{{- printf "value: %s" (required "Missing .Values.postgresql.auth.password" .Values.postgresql.auth.password) | nindent 0 -}}
  {{- else if and (not .Values.postgresql.enabled) .Values.postgresqlExternal.password }}
{{- printf "value: %s" .Values.postgresqlExternal.password | nindent 0 }}
  {{- else }}
valueFrom:
  secretKeyRef:
    name: {{ coalesce .Values.postgresqlExternal.passwordSecret (include "invenio.postgresql.secretName" . | trim) }}
    key: {{ required "Missing .Values.postgresqlExternal.passwordKey" (tpl  .Values.postgresqlExternal.passwordKey .) }}
  {{- end -}}
{{- end -}}

{{/*
  This template renders the port number used for the PostgreSQL instance (as a string).
*/}}
{{- define "invenio.postgresql.portString" -}}
  {{- if .Values.postgresql.enabled -}}
{{- printf "value: %q" (required "Missing .Values.postgresql.primary.service.ports.postgresql" (tpl (toString .Values.postgresql.primary.service.ports.postgresql) .)) | nindent 0 -}}
  {{- else if and (not .Values.postgresql.enabled) .Values.postgresqlExternal.portString }}
{{- printf "value: %q" (.Values.postgresqlExternal.portString | toString) | nindent 0 }}
  {{- else }}
valueFrom:
  secretKeyRef:
    name: {{ coalesce .Values.postgresqlExternal.portStringSecret (include "invenio.postgresql.secretName" . | trim) }}
    key: {{ required "Missing .Values.postgresqlExternal.portStringKey" (tpl  .Values.postgresqlExternal.portStringKey .) }}
  {{- end -}}
{{- end -}}

{{/*
  This template renders the name of the database in PostgreSQL.
*/}}
{{- define "invenio.postgresql.database" -}}
  {{- if .Values.postgresql.enabled -}}
{{- printf "value: %s" (required "Missing .Values.postgresql.auth.database" (tpl .Values.postgresql.auth.database .)) | nindent 0 }}
  {{- else if and (not .Values.postgresql.enabled) .Values.postgresqlExternal.database }}
{{- printf "value: %s" .Values.postgresqlExternal.database | nindent 0 }}
  {{- else }}
valueFrom:
  secretKeyRef:
    name: {{ coalesce .Values.postgresqlExternal.databaseSecret (include "invenio.postgresql.secretName" . | trim) }}
    key: {{ required "Missing .Values.postgresqlExternal.databaseKey" (tpl  .Values.postgresqlExternal.databaseKey .) }}
  {{- end -}}
{{- end -}}

{{/*
  This template renders the name of the uri in PostgreSQL.
*/}}
{{- define "invenio.postgresql.uri" -}}
  {{- if and (not .Values.postgresql.enabled) .Values.postgresqlExternal.uri }}
{{- printf "value: %s" .Values.postgresqlExternal.uri | nindent 0 }}
  {{- else if and (not .Values.postgresql.enabled) .Values.postgresqlExternal.uriKey }}
valueFrom:
  secretKeyRef:
    name: {{ coalesce .Values.postgresqlExternal.uriSecret (include "invenio.postgresql.secretName" . | trim) }}
    key: {{ required "Missing .Values.postgresqlExternal.uriKey" (tpl  .Values.postgresqlExternal.uriKey .) }}
  {{- end -}}
{{- end -}}

{{/*
  Define database connection env section.
*/}}
{{- define "invenio.config.database" -}}
{{- if and (not .Values.postgresqlExternal.uriKey) (not .Values.postgresqlExternal.uri) }} 
- name: INVENIO_DB_USER
  {{- (include "invenio.postgresql.username" . | trim) | nindent 2 }}
- name: INVENIO_DB_HOST
  {{- (include "invenio.postgresql.hostname" . | trim) | nindent 2 }}
- name: INVENIO_DB_PORT
  {{- (include "invenio.postgresql.portString" . | trim) | nindent 2 }}
- name: INVENIO_DB_NAME
  {{- (include "invenio.postgresql.database" . | trim) | nindent 2 }}
- name: INVENIO_DB_PROTOCOL
  value: "postgresql+psycopg2"
- name: INVENIO_DB_PASSWORD
  {{- (include "invenio.postgresql.password" . | trim) | nindent 2 }}
- name: INVENIO_SQLALCHEMY_DATABASE_URI
  value: "$(INVENIO_DB_PROTOCOL)://$(INVENIO_DB_USER):$(INVENIO_DB_PASSWORD)@$(INVENIO_DB_HOST):$(INVENIO_DB_PORT)/$(INVENIO_DB_NAME)"
{{- else }}
- name: INVENIO_SQLALCHEMY_DATABASE_URI
  {{- (include "invenio.postgresql.uri" . | trim) | nindent 2 }}
{{- end }}
{{- end -}}


{{/*
  Define a projected volume for PostgreSQL config file.

  Usage:
    {{ include "invenio.postgresql.configFile" . | nindent 6 }}

  Expected context:
    .Values.postgresqlExternal.*
*/}}

{{- define "invenio.postgresql.configFile" -}}
{{- $fields := dict "username" "INVENIO_DB_USER" "password" "INVENIO_DB_PASSWORD" "hostname" "INVENIO_DB_HOST" "portString" "INVENIO_DB_PORT" "database" "INVENIO_DB_NAME" }}
{{- $root := . }}
- name: postgresql-config
  projected:
    sources:
    {{- if or .Values.postgresqlExternal.uri }}
    - secret:
        name: invenio-postgresql-inline
	items:
	- key: uri
	  path: INVENIO_SQLALCHEMY_DATABASE_URI
    {{- else if .Values.postgresqlExternal.uriKey }}
    - secret:
        name: {{ coalesce .Values.postgresqlExternal.uriSecret (include "invenio.postgresql.secretName" $root | trim) }} 
        items:
        - key: {{ .Values.postgresqlExternal.uriKey }} 
          path: INVENIO_SQLALCHEMY_DATABASE_URI
    {{- else }}
    {{- range $item, $value := $fields }}
    - secret:
      {{- if hasKey $root.Values.postgresqlExternal $item }}
        name: invenio-postgresql-inline
        items:
        - key: {{ $item }}
          path: {{ $value }}
      {{- else }}
        {{- $keyName := (printf "%sKey" $item) }}
        {{- $secretName := (printf "%sSecret" $item) }}
        name: {{ coalesce (get $root.Values.postgresqlExternal $secretName) (include "invenio.postgresql.secretName" $root | trim) }}
        items: 
        - key: {{ get $root.Values.postgresqlExternal $keyName }}
          path: {{ $value | toString }}
      {{- end }}
      {{- end }}
    {{- end }}
{{- end }}


{{/*
Get the sentry secret name
*/}}
{{- define "invenio.sentrySecretName" -}}
{{- if .Values.invenio.sentry.existingSecret -}}
  {{- print (tpl .Values.invenio.sentry.existingSecret .) -}}
{{- else if  .Values.invenio.sentry.secret_name -}}
  {{- print .Values.invenio.sentry.secret_name -}}
{{- else -}}
  {{- printf "%s-%s" (include "invenio.fullname" .) "sentry" -}}
{{- end -}}
{{- end -}}

{{/*
Add sentry environmental variables
*/}}
{{- define "invenio.config.sentry" -}}
{{- if .Values.invenio.sentry.enabled -}}
- name: INVENIO_SENTRY_DSN
  valueFrom:
    secretKeyRef:
      name: {{ include "invenio.sentrySecretName" . }}
      key: {{ .Values.invenio.sentry.secretKeys.dsnKey }}
{{- end }}
{{- end -}}

{{/*
Invenio basic configuration variables
*/}}
{{- define "invenio.configBase" -}}
INVENIO_APP_ALLOWED_HOSTS: '["{{ include "invenio.hostname" $ }}"]'
INVENIO_TRUSTED_HOSTS: '["{{ include "invenio.hostname" $ }}"]'
INVENIO_SEARCH_HOSTS: {{ printf "[{'host': '%s'}]" (include "invenio.opensearch.hostname" .) | quote }}
INVENIO_SITE_HOSTNAME: '{{ include "invenio.hostname" $ }}'
INVENIO_SITE_UI_URL: 'https://{{ include "invenio.hostname" $ }}'
INVENIO_SITE_API_URL: 'https://{{ include "invenio.hostname" $ }}/api'
INVENIO_DATACITE_ENABLED: {{ ternary "True" "False" .Values.invenio.datacite.enabled | quote }}
INVENIO_LOGGING_CONSOLE_LEVEL: "WARNING"
{{- end -}}

{{/*
Merge invenio.extraConfig and configBase using mergeOverwrite and rendering templates.
invenio.ExtraConfig will overwrite the values from configBase in case of duplicates.
*/}}
{{- define "invenio.mergeConfig" -}}
{{- $dst := dict -}}
{{- $values := list (include "invenio.configBase" .)  (.Values.invenio.extra_config | toYaml) (.Values.invenio.extraConfig | toYaml) -}}
{{- range $values -}}
{{- $dst = tpl  . $ | fromYaml | mergeOverwrite $dst -}}
{{- end -}}
{{- $dst | toYaml -}}
{{- end -}}

{{/*
Get the invenio general secret name
*/}}
{{- define "invenio.secretName" -}}
{{- if .Values.invenio.existingSecret -}}
  {{- tpl .Values.invenio.existingSecret . -}}
{{- else -}}
  {{- include "invenio.fullname" . -}}
{{- end -}}
{{- end -}}

{{/*
Get the sentry secret name
*/}}
{{- define "invenio.dataciteSecretName" -}}
{{- if .Values.invenio.datacite.existingSecret -}}
  {{- print (tpl .Values.invenio.datacite.existingSecret .) -}}
{{- else if  .Values.invenio.datacite.secret_name -}}
  {{- print .Values.invenio.datacite.secret_name -}}
{{- else -}}
  {{- printf "%s-%s" (include "invenio.fullname" .) "datacite" -}}
{{- end -}}
{{- end -}}

{{/*
Add datacite environmental variables
*/}}
{{- define "invenio.config.datacite" -}}
{{- if .Values.invenio.datacite.enabled }}
- name: INVENIO_DATACITE_USERNAME
  valueFrom:
    secretKeyRef:
      name: {{ include "invenio.dataciteSecretName" . }}
      key: {{ .Values.invenio.datacite.secretKeys.usernameKey }}
- name: INVENIO_DATACITE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "invenio.dataciteSecretName" . }}
      key: {{ .Values.invenio.datacite.secretKeys.passwordKey }}
- name: INVENIO_DATACITE_PREFIX
  value: {{ required "Missing .Values.invenio.datacite.prefix" .Values.invenio.datacite.prefix | quote }}
- name: INVENIO_DATACITE_TEST_MODE
  value: {{ required "Missing .Values.invenio.values.datacite.testMode" .Values.invenio.datacite.testMode | quote }}
{{- with .Values.invenio.datacite.format }}
- name: INVENIO_DATACITE_FORMAT
  value: {{ . }}
{{- end}}
{{- with .Values.invenio.datacite.dataCenterSymbol }}
- name: INVENIO_DATACITE_DATACENTER_SYMBOL
  value: {{ . }}
{{- end}}
{{- end }}
{{- end -}}
