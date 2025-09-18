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
  This template renders the hostname for the Redis instance used.
*/}}
{{- define "invenio.redis.hostname" -}}
  {{- if .Values.redis.enabled }}
    {{- printf "%s-master" (include "common.names.fullname" .Subcharts.redis) }}
  {{- else }}
      {{- required "Missing .Values.redisExternal.hostname" .Values.redisExternal.hostname }}
  {{- end }}
{{- end -}}

{{/*
  This template renders the password for accessing RabbitMQ.
*/}}
{{- define "invenio.redis.password" -}}
  {{- if and .Values.redis.enabled }}
    {{- required "Missing .Values.redis.auth.password" .Values.redis.auth.password -}}
  {{- else }}
    {{- required "Missing .Values.redisExternal.password" .Values.redisExternal.password -}}
  {{- end }}
{{- end -}}

{{/*
  Get the database password secret name
*/}}
{{- define "invenio.redis.secretName" -}}
  {{- if .Values.redis.enabled -}}
    {{- required "Missing .Values.redis.auth.existingSecret" (tpl .Values.redis.auth.existingSecret .) -}}
  {{- else -}}
    {{- required "Missing .Values.redisExternal.existingSecret" (tpl .Values.redisExternal.existingSecret .) -}}
  {{- end -}}
{{- end -}}

{{/*
  Get the database password secret key
*/}}
{{- define "invenio.redis.secretKey" -}}
  {{- if .Values.redis.enabled -}}
    {{- required "Missing .Values.redis.auth.existingSecretPasswordKey" .Values.redis.auth.existingSecretPasswordKey -}}
  {{- else -}}
    {{- required "Missing .Values.redisExternal.existingSecretPasswordKey" .Values.redisExternal.existingSecretPasswordKey -}}
  {{- end }}
{{- end }}

{{/*
  This template renders the port number for Redis.
*/}}
{{- define "invenio.redis.portString" -}}
  {{- if .Values.redis.enabled }}
    {{- print "6379" | quote -}}
  {{- else }}
    {{- print "6379" | quote -}}
  {{- end }}
{{- end -}}

{{/*
  This template renders the protocol for Redis 
*/}}
{{- define "invenio.redis.protocol" -}}
  {{- if .Values.redis.enabled }}
    {{- print "redis" -}}
  {{- else }}
    {{- print "redis" -}}
  {{- end }}
{{- end -}}

{{/*
  Redis connection env section.
*/}}
{{- define "invenio.config.cache" -}}
{{- $uri := "$(INVENIO_CONFIG_REDIS_PROTOCOL)://:$(INVENIO_CONFIG_REDIS_PASSWORD)@$(INVENIO_CONFIG_REDIS_HOST):$(INVENIO_CONFIG_REDIS_PORT)" -}}
{{- $hostString := ":$(INVENIO_CONFIG_REDIS_PASSWORD)@$(INVENIO_CONFIG_REDIS_HOST)" -}}
- name: INVENIO_CONFIG_REDIS_HOST
  value: {{ include "invenio.redis.hostname" . }}
- name: INVENIO_CONFIG_REDIS_PORT
  value: {{ include "invenio.redis.portString" . }}
- name: INVENIO_CONFIG_REDIS_PROTOCOL
  value: {{ include "invenio.redis.protocol" . }}
- name: INVENIO_CONFIG_REDIS_PASSWORD
{{- if and .Values.redis.enabled (not .Values.redis.auth.enabled) }}
  value: {{ print "\"\"" }}  
{{- else if or (and .Values.redis.enabled .Values.redis.auth.password) .Values.redisExternal.password }}
  value: {{ include "invenio.redis.password" .  | quote }}
{{- else }}
  valueFrom:
    secretKeyRef:
      name: {{ include "invenio.redis.secretName" .}}
      key: {{ include "invenio.redis.secretKey" .}}
{{- end }}
- name: INVENIO_CACHE_REDIS_HOST
  value: {{ $hostString }}
- name: INVENIO_CACHE_REDIS_URL
  value: {{ printf "%s/0" $uri }}
- name: INVENIO_IIIF_CACHE_REDIS_URL
  value: {{ printf "%s/0" $uri }}
- name: INVENIO_ACCOUNTS_SESSION_REDIS_URL
  value: {{ printf "%s/1" $uri }}
- name: INVENIO_CELERY_RESULT_BACKEND
  value: {{ printf "%s/2" $uri }}
- name: INVENIO_RATELIMIT_STORAGE_URI
  value: {{ printf "%s/3" $uri }}
- name: INVENIO_COMMUNITIES_IDENTITIES_CACHE_REDIS_URL
  value: {{ printf "%s/4" $uri }}
{{- end }}



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
  This template renders the name of the secret that stores the password for RabbitMQ.
*/}}
{{- define "invenio.rabbitmq.passwordSecret" -}}
  {{- if .Values.rabbitmq.enabled }}
    {{- include "rabbitmq.secretPasswordName" .Subcharts.rabbitmq }}
  {{- else }}
      {{- required "Missing .Values.rabbitmqExternal.existingPasswordSecret" .Values.rabbitmqExternal.existingPasswordSecret }}
  {{- end }}
{{- end -}}

{{/*
  This template renders the username for accessing RabbitMQ.
*/}}
{{- define "invenio.rabbitmq.username" -}}
  {{- if .Values.rabbitmq.enabled }}
    {{- required "Missing .Values.rabbitmq.auth.username" .Values.rabbitmq.auth.username -}}
  {{- else }}
    {{- required "Missing .Values.rabbitmqExternal.username" (tpl .Values.rabbitmqExternal.username .) -}}
  {{- end }}
{{- end -}}

{{/*
  This template renders the password for accessing RabbitMQ.
*/}}
{{- define "invenio.rabbitmq.password" -}}
  {{- if .Values.rabbitmq.enabled }}
    {{- required "Missing .Values.rabbitmq.auth.password" .Values.rabbitmq.auth.password -}}
  {{- else }}
    {{- required "Missing .Values.rabbitmqExternal.password" .Values.rabbitmqExternal.password -}}
  {{- end }}
{{- end -}}

{{/*
  Get the database password secret name
*/}}
{{- define "invenio.rabbitmq.secretName" -}}
  {{- if .Values.rabbitmq.enabled -}}
    {{- required "Missing .Values.rabbitmq.auth.existingPasswordSecret" (tpl .Values.rabbitmq.auth.existingPasswordSecret .) -}}
  {{- else -}}
    {{- required "Missing .Values.rabbitmqExternal.existingSecret" (tpl .Values.rabbitmqExternal.existingSecret .) -}}
  {{- end -}}
{{- end -}}

{{/*
  Get the database password secret key
*/}}
{{- define "invenio.rabbitmq.secretKey" -}}
  {{- if .Values.rabbitmq.enabled -}}
    {{- required "Missing .Values.rabbitmq.auth.existingSecretPasswordKey" .Values.rabbitmq.auth.existingSecretPasswordKey -}}
  {{- else -}}
    {{- required "Missing .Values.rabbitmqExternal.existingSecretPasswordKey" .Values.rabbitmqExternal.existingSecretPasswordKey -}}
  {{- end -}}
{{- end -}}

{{/*
  This template renders the AMQP port number for RabbitMQ.
*/}}
{{- define "invenio.rabbitmq.amqpPortString" -}}
  {{- if .Values.rabbitmq.enabled }}
    {{- required "Missing .Values.rabbitmq.service.ports.amqp" .Values.rabbitmq.service.ports.amqp | quote -}}
  {{- else }}
    {{- required "Missing .Values.rabbitmqExternal.amqpPort" (tpl (toString .Values.rabbitmqExternal.amqpPort) .) | quote -}}
  {{- end }}
{{- end -}}

{{/*
  This template renders the management port number for RabbitMQ.
*/}}
{{- define "invenio.rabbitmq.managementPortString" -}}
  {{- if .Values.rabbitmq.enabled }}
    {{- required "Missing .Values.rabbitmq.service.ports.manager" .Values.rabbitmq.service.ports.manager | quote -}}
  {{- else }}
    {{- required "Missing .Values.rabbitmqExternal.managementPort" (tpl (toString .Values.rabbitmqExternal.managementPort) .) | quote -}}
  {{- end }}
{{- end -}}

{{/*
  This template renders the hostname for RabbitMQ.
*/}}
{{- define "invenio.rabbitmq.hostname" -}}
  {{- if .Values.rabbitmq.enabled }}
    {{- include "common.names.fullname" .Subcharts.rabbitmq -}}
  {{- else }}
    {{- required "Missing .Values.rabbitmqExternal.hostname" (tpl .Values.rabbitmqExternal.hostname .) }}
  {{- end }}
{{- end -}}

{{/*
  This template renders the protocol for RabbitMQ.
*/}}
{{- define "invenio.rabbitmq.protocol" -}}
  {{- if .Values.rabbitmq.enabled }}
    {{- "amqp" }}
  {{- else }}
    {{- required "Missing .Values.rabbitmqExternal.protocol" .Values.rabbitmqExternal.protocol }}
  {{- end }}
{{- end -}}

{{/*
  This template renders the vhost for RabbitMQ.
*/}}
{{- define "invenio.rabbitmq.vhost" -}}
  {{- if .Values.rabbitmq.enabled }}
    {{- "" }}
  {{- else }}
    {{- required "Missing .Values.rabbitmqExternal.vhost" (tpl .Values.rabbitmqExternal.vhost .) }}
  {{- end }}
{{- end -}}

{{/*
  RabbitMQ connection env section.
*/}}
{{- define "invenio.config.queue" -}}
{{- $uri := "$(INVENIO_AMQP_BROKER_PROTOCOL)://$(INVENIO_AMQP_BROKER_USER):$(INVENIO_AMQP_BROKER_PASSWORD)@$(INVENIO_AMQP_BROKER_HOST):$(INVENIO_AMQP_BROKER_PORT)/$(INVENIO_AMQP_BROKER_VHOST)" -}}
- name: INVENIO_AMQP_BROKER_USER
  value: {{ include "invenio.rabbitmq.username" . }}
- name: INVENIO_AMQP_BROKER_HOST
  value: {{ include "invenio.rabbitmq.hostname" . }}
- name: INVENIO_AMQP_BROKER_PORT
  value: {{ include "invenio.rabbitmq.amqpPortString" . }}
- name: INVENIO_AMQP_BROKER_VHOST
  value: {{ include "invenio.rabbitmq.vhost" . }}
- name: INVENIO_AMQP_BROKER_PROTOCOL
  value: {{ include "invenio.rabbitmq.protocol" . }}
- name: INVENIO_AMQP_BROKER_PASSWORD
{{- if or (and .Values.rabbitmq.enabled .Values.rabbitmq.auth.password) .Values.rabbitmqExternal.password }}
  value: {{ include "invenio.rabbitmq.password" .  | quote }}
{{- else }}
  valueFrom:
    secretKeyRef:
      name: {{ include "invenio.rabbitmq.secretName" .}}
      key: {{ include "invenio.rabbitmq.secretKey" .}}
{{- end }}
- name: INVENIO_BROKER_URL
  value: {{ $uri }}
- name: INVENIO_CELERY_BROKER_URL
  value: $(INVENIO_BROKER_URL)
- name: RABBITMQ_API_URI
  value: "http://$(INVENIO_AMQP_BROKER_USER):$(INVENIO_AMQP_BROKER_PASSWORD)@$(INVENIO_AMQP_BROKER_HOST):$(INVENIO_AMQP_BROKER_PORT)/api/"
{{- end -}}

#########################     OpenSearch hostname     #########################
{{/*
  This template renders the hostname of the OpenSearch instance.
*/}}
{{- define "invenio.opensearch.hostname" -}}
  {{- if .Values.opensearch.enabled }}
    {{- $hostname := (include "opensearch.service.name" .Subcharts.opensearch) | trim  -}}
    {{- printf "%q" (printf "[{\"host\": \"$hostname\"}]") -}}
  {{- else }}
    {{- $hostname := (required "Missing .Values.opensearchExternal.hostname" .Values.opensearchExternal.hostname) -}}
    {{- printf "%q" (printf "[{\"host\": \"%s\"}]" $hostname) -}}
  {{- end }}
{{- end -}}

{{/*
  This template renders the username for accessing opensearch 
*/}}
{{- define "invenio.opensearch.username" -}}
  {{- if and .Values.opensearch.enabled }}
    {{- "" -}}
  {{- else }}
    {{- required "Missing .Values.opensearchExternal.username" .Values.opensearchExternal.username -}}
  {{- end }}
{{- end -}}

{{/*
  This template renders the password for accessing opensearch 
*/}}
{{- define "invenio.opensearch.password" -}}
  {{- if and .Values.opensearch.enabled }}
    {{- "" -}}
  {{- else }}
    {{- required "Missing .Values.opensearchExternal.password" .Values.opensearchExternal.password -}}
  {{- end }}
{{- end -}}

{{/*
  Get the opensearch password secret name
*/}}
{{- define "invenio.opensearch.secretName" -}}
  {{- if .Values.opensearch.enabled -}}
    {{- "" -}}
  {{- else -}}
    {{- required "Missing .Values.opensearchExternal.existingSecret" (tpl .Values.opensearchExternal.existingSecret .) -}}
  {{- end -}}
{{- end -}}

{{/*
  Get the opensearch password secret key
*/}}
{{- define "invenio.opensearch.secretKey" -}}
  {{- if .Values.opensearch.enabled -}}
    {{- "" -}}
  {{- else -}}
    {{- required "Missing .Values.opensearchExternal.existingSecretPasswordKey" .Values.opensearchExternal.existingSecretPasswordKey -}}
  {{- end }}
{{- end }}

{{/*
  This template renders the port number for opensearch.
*/}}
{{- define "invenio.opensearch.portString" -}}
  {{- if .Values.opensearch.enabled }}
    {{- print "9200" | quote -}}
  {{- else }}
    {{- print "9200" | quote -}}
  {{- end }}
{{- end -}}

{{/*
  This template renders the protocol for opensearch
*/}}
{{- define "invenio.opensearch.protocol" -}}
  {{- if .Values.opensearch.enabled }}
    {{- "" -}}
  {{- else }}
    {{- required "Missing .Values.opensearchExternal.protocol" .Values.opensearchExternal.protocol -}}
  {{- end }}
{{- end -}}

{{/*
  This template renders the useSsl for opensearch
*/}}
{{- define "invenio.opensearch.useSsl" -}}
  {{- if .Values.opensearch.enabled }}
    {{- "" -}}
  {{- else }}
    {{- required "Missing .Values.opensearchExternal.useSsl" .Values.opensearchExternal.useSsl -}}
  {{- end }}
{{- end -}}

{{/*
  This template renders the verifyCerts for opensearch
*/}}
{{- define "invenio.opensearch.verifyCerts" -}}
  {{- if .Values.opensearch.enabled }}
    {{- "" -}}
  {{- else }}
    {{- required "Missing .Values.opensearchExternal.verifyCerts" .Values.opensearchExternal.verifyCerts -}}
  {{- end }}
{{- end -}}

{{/*
  This template renders the caCerts for opensearch
*/}}
{{- define "invenio.opensearch.caCerts" -}}
  {{- if .Values.opensearch.enabled }}
    {{- "" -}}
  {{- else }}
    {{- required "Missing .Values.opensearchExternal.caCerts" .Values.opensearchExternal.caCerts -}}
  {{- end }}
{{- end -}}

{{/*
  This template renders the sslAssertHostname for opensearch
*/}}
{{- define "invenio.opensearch.sslAssertHostname" -}}
  {{- if .Values.opensearch.enabled }}
    {{- "" -}}
  {{- else }}
    {{- required "Missing .Values.opensearchExternal.sslAssertHostname" .Values.opensearchExternal.sslAssertHostname -}}
  {{- end }}
{{- end -}}

{{/*
  This template renders the sslShowWarn for opensearch
*/}}
{{- define "invenio.opensearch.sslShowWarn" -}}
  {{- if .Values.opensearch.enabled }}
    {{- "" -}}
  {{- else }}
    {{- required "Missing .Values.opensearchExternal.sslShowWarn" .Values.opensearchExternal.sslShowWarn -}}
  {{- end }}
{{- end -}}


{{/*
SEARCH_CLIENT_CONFIG={'use_ssl': False, 'verify_certs': False, 'ssl_assert_hostname': False, 'ssl_show_warn': False, 'ca_certs': None}
INVENIO_SEARCH_HOSTS: {{ printf "[{'host': '%s'}]" (include "invenio.opensearch.hostname" .) | quote }}
  value: {{ printf "%q" (printf "{\"use_ssl\": $(INVENIO_CONFIG_OPENSEARCH_USE_SSL), \"verify_certs\": $(INVENIO_CONFIG_OPENSEARCH_VERIFY_CERTS), \"ssl_assert_hostname\": $(INVENIO_CONFIG_OPENSEARCH_SSL_ASSERT_HOSTNAME), \"ssl_show_warn\": $(INVENIO_CONFIG_OPENSEARCH_SSL_SHOW_WARN), \"ca_certs\": \"$(INVENIO_CONFIG_OPENSEARCH_CA_CERTS)\", \"http_auth\": [\"$(INVENIO_CONFIG_OPENSEARCH_USER)\", \"$(INVENIO_CONFIG_OPENSEARCH_PASSWORD)\"]}") }}

*/}}

{{/*
  Opensearch connection env section.
*/}}
{{- define "invenio.config.opensearch" -}}
{{- if .Values.opensearch.enabled }}
- name: INVENIO_SEARCH_HOSTS
  value: {{ (include "invenio.opensearch.hostname" . | trim) }}
{{- else }}
- name: INVENIO_SEARCH_HOSTS
  value: {{ (include "invenio.opensearch.hostname" . | trim) }}
- name: "INVENIO_CONFIG_OPENSEARCH_USER"
  value: {{ printf "%q" (include "invenio.opensearch.username" . | trim) }}
- name: "INVENIO_CONFIG_OPENSEARCH_PROTOCOL"
  value: {{ printf "%q" (include "invenio.opensearch.protocol" . | trim) }}
- name: "INVENIO_CONFIG_OPENSEARCH_PORT"
  value: {{ printf "%q" (include "invenio.opensearch.portString" . | trim) }}
- name: "INVENIO_CONFIG_OPENSEARCH_USE_SSL"
  value: {{ printf "%q" (include "invenio.opensearch.useSsl" . | trim) }}
- name: "INVENIO_CONFIG_OPENSEARCH_VERIFY_CERTS"
  value: {{ printf "%q" (include "invenio.opensearch.verifyCerts" . | trim) }}
- name: "INVENIO_CONFIG_OPENSEARCH_SSL_ASSERT_HOSTNAME"
  value: {{ printf "%q" (include "invenio.opensearch.sslAssertHostname" . | trim) }}
- name: "INVENIO_CONFIG_OPENSEARCH_SSL_SHOW_WARN"
  value: {{ printf "%q" (include "invenio.opensearch.sslShowWarn" . | trim) }}
- name: "INVENIO_CONFIG_OPENSEARCH_CA_CERTS"
  value: {{ printf "%q" (include "invenio.opensearch.caCerts" . | trim) }}
- name: "INVENIO_CONFIG_OPENSEARCH_PASSWORD"
{{- if .Values.opensearchExternal.password }}
  value: {{ printf "%q" (include "invenio.opensearch.password" . | trim) }}
{{- else }}
  valueFrom:
    secretKeyRef:
      name: {{ include "invenio.opensearch.secretName" . | trim }}
      key:  {{ include "invenio.opensearch.secretKey" . | trim }}
{{- end }}
- name: INVENIO_SEARCH_CLIENT_CONFIG
  value: {{ printf "%q" (printf "{\"use_ssl\": $(INVENIO_CONFIG_OPENSEARCH_USE_SSL), \"verify_certs\": $(INVENIO_CONFIG_OPENSEARCH_VERIFY_CERTS), \"ssl_assert_hostname\": $(INVENIO_CONFIG_OPENSEARCH_SSL_ASSERT_HOSTNAME), \"ssl_show_warn\": $(INVENIO_CONFIG_OPENSEARCH_SSL_SHOW_WARN), \"ca_certs\": \"$(INVENIO_CONFIG_OPENSEARCH_CA_CERTS)\", \"http_auth\": [\"$(INVENIO_CONFIG_OPENSEARCH_USER)\", \"$(INVENIO_CONFIG_OPENSEARCH_PASSWORD)\"]}") }}
{{- end }}
{{- end }}

#########################     PostgreSQL connection configuration     #########################
{{/*
  This template renders the username used for the PostgreSQL instance.
*/}}
{{- define "invenio.postgresql.username" -}}
  {{- if .Values.postgresql.enabled -}}
    {{- required "Missing .Values.postgresql.auth.username" (tpl .Values.postgresql.auth.username .) -}}
  {{- else -}}
    {{- required "Missing .Values.postgresqlExternal.username" (tpl  .Values.postgresqlExternal.username .) -}}
  {{- end -}}
{{- end -}}

{{/*
  This template renders the password used for the PostgreSQL instance.
  In production environments we encourage you to use secrets instead.
*/}}
{{- define "invenio.postgresql.password" -}}
  {{- if .Values.postgresql.enabled -}}
    {{- required "Missing .Values.postgresql.auth.password" .Values.postgresql.auth.password -}}
  {{- else -}}
    {{- required "Missing .Values.postgresqlExternal.password" .Values.postgresqlExternal.password -}}
  {{- end -}}
{{- end -}}

{{/*
  Get the database password secret name
*/}}
{{- define "invenio.postgresql.secretName" -}}
  {{- if .Values.postgresql.enabled -}}
    {{- required "Missing .Values.postgresql.auth.existingSecret" (tpl .Values.postgresql.auth.existingSecret .) -}}
  {{- else -}}
    {{- required "Missing .Values.postgresqlExternal.existingSecret" (tpl .Values.postgresqlExternal.existingSecret .) -}}
  {{- end -}}
{{- end -}}

{{/*
  Get the database password secret key
*/}}
{{- define "invenio.postgresql.secretKey" -}}
  {{- if .Values.postgresql.enabled -}}
    {{- required "Missing .Values.postgresql.auth.secretKeys.userPasswordKey" .Values.postgresql.auth.secretKeys.userPasswordKey -}}
  {{- else -}}
    {{- required "Missing .Values.postgresqlExternal.existingSecretPasswordKey" .Values.postgresqlExternal.existingSecretPasswordKey -}}
  {{- end -}}
{{- end -}}

{{/*
  This template renders the hostname used for the PostgreSQL instance.
*/}}
{{- define "invenio.postgresql.hostname" -}}
  {{- if .Values.postgresql.enabled -}}
    {{- include "postgresql.v1.primary.fullname" .Subcharts.postgresql -}}
  {{- else -}}
    {{- required "Missing .Values.postgresqlExternal.hostname" (tpl .Values.postgresqlExternal.hostname .) -}}
  {{- end -}}
{{- end -}}

{{/*
  This template renders the port number used for the PostgreSQL instance (as a string).
*/}}
{{- define "invenio.postgresql.portString" -}}
  {{- if .Values.postgresql.enabled -}}
    {{- required "Missing .Values.postgresql.primary.service.ports.postgresql" (tpl (toString .Values.postgresql.primary.service.ports.postgresql) .) | quote -}}
  {{- else -}}
    {{- required "Missing .Values.postgresqlExternal.port" (tpl (toString .Values.postgresqlExternal.port) .) | quote -}}
  {{- end -}}
{{- end -}}

{{/*
  This template renders the name of the database in PostgreSQL.
*/}}
{{- define "invenio.postgresql.database" -}}
  {{- if .Values.postgresql.enabled -}}
    {{- required "Missing .Values.postgresql.auth.database" (tpl .Values.postgresql.auth.database .) -}}
  {{- else -}}
    {{- required "Missing .Values.postgresqlExternal.database" (tpl .Values.postgresqlExternal.database .) -}}
  {{- end -}}
{{- end -}}

{{/*
  Define database connection env section.
*/}}
{{- define "invenio.config.database" -}}
- name: INVENIO_DB_USER
  value: {{ include "invenio.postgresql.username" . }}
- name: INVENIO_DB_HOST
  value: {{ include "invenio.postgresql.hostname" . }}
- name: INVENIO_DB_PORT
  value: {{ include "invenio.postgresql.portString" . }}
- name: INVENIO_DB_NAME
  value: {{ include "invenio.postgresql.database" . }}
- name: INVENIO_DB_PROTOCOL
  value: "postgresql+psycopg2"
- name: INVENIO_DB_PASSWORD
{{- if or (and .Values.postgresql.enabled .Values.postgresql.auth.password) .Values.postgresqlExternal.password }}
  value: {{ include "invenio.postgresql.password" .  | quote }}
{{- else }}
  valueFrom:
    secretKeyRef:
      name: {{ include "invenio.postgresql.secretName" .}}
      key: {{ include "invenio.postgresql.secretKey" .}}
{{- end }}
- name: INVENIO_SQLALCHEMY_DATABASE_URI
  value: "$(INVENIO_DB_PROTOCOL)://$(INVENIO_DB_USER):$(INVENIO_DB_PASSWORD)@$(INVENIO_DB_HOST):$(INVENIO_DB_PORT)/$(INVENIO_DB_NAME)"
{{- end -}}

{{- define "invenio.config.configFiles" }}
{{- if .Values.invenio.extraSecrets }}
- name: mounted-secrets 
  projected:
    sources:
      {{- with .Values.invenio.extraSecrets }}
      {{- toYaml . | nindent 6 }}
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
