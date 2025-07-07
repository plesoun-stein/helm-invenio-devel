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

###########################     Invenio inline configfile      ###########################
{{/*
  This template renders the hostname for Invenio.
*/}}
{{- define "invenio.inline.secretName" -}}
{{- $root := .root }}
{{ printf "%s-inline-%s" (include "invenio.fullname" $root) .myName }}
{{- end -}}
###########################     Invenio Extra Config files     ###########################

{{- define "invenio.extraConfigFiles" -}}
{{- $root := . }}
- name: extra-configfiles
  projected:
    sources:
    {{- range $secret := $root.Values.invenio.extraConfigFiles }}
    - secret:
        name: {{ $secret }}
    {{- end }}
{{- end }}

###########################     Invenio failing config     ###########################

{{/*
invenio.failingConfig

params:
 - service: postgresql, redis, rabbitmq
 - key: hostname, port, vhost etc.
 - root: it's rootof the chart, to access Values like $root.Values.
*/}}

{{- define "invenio.failingConfig" -}}
{{- $root := .root }}
{{- $service := .service }}
{{- $serviceExternal := (printf "%sExternal" $service) }}
{{- $serviceContext := default dict (get $root.Values $service) }}
{{- $serviceContextExternal := default dict (get $root.Values $serviceExternal) }}
{{- $a := (printf "\n\n%s congfiguration" .service) }}
{{- $b := (printf "\n\nmissing param: %s or %sKey" .key .key) }}
{{- $c := (printf "\n\nprinting config contexts") }}
{{- $d := (printf "\n\n%s:%v" $service ($serviceContext | toYaml | nindent 2)) }}
{{- $e := (printf "\n\n%s:%v" $serviceExternal ($serviceContextExternal | toYaml | nindent 2)) }}
{{- fail (printf "%s %s %s %v %v" $a $b $c $d $e) }} 
{{- end }}


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
    {{- fail (printf "\n\nInternal redis is disabled\n\nexternalRedis is missing existingSecret key,\n\nI'm printing contexts \n\n\nredis:\n%v\n\n\nexternalRedis:\n%v" (toYaml .Values.redis | indent 2) (toYaml .Values.redisExternal | indent 2)) | indent 4 }} 
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
  {{- else if and (not .Values.redis.enabled) .Values.redisExternal.hostnameKey }}
valueFrom:
  secretKeyRef:
    name: {{ coalesce .Values.redisExternal.hostnameSecret (include "invenio.redis.secretName" . | trim) }}
    key: {{ required "Missing .Values.redisExternal.hostnameKey" (tpl  .Values.redisExternal.hostnameKey .) }}
  {{- else }}
{{- fail (printf "\n\nthere is somthing wrong with redis hostname,\n\nI'm printing contexts\n\nredis:\n\n\n%v\n\nredisExternal:\n%v" (toYaml .Values.redis) (toYaml .Values.redisExternal)) | indent 4 }} 
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
{{/* - fail (printf "\n\nthere is somthing wrong with redis password,\n\nI'm printing contexts for redis\n\ninternal config:\n%v\n\nexternal config:\n%v" (toYaml .Values.redis) (toYaml .Values.redisExternal)) | indent 4 */}} 
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

{{- define "invenio.redis.configFile" -}}
{{- $fields := dict "password" "INVENIO_CONFIG_REDIS_PASSWORD" "hostname" "INVENIO_CONFIG_REDIS_HOST" "port" "INVENIO_CONFIG_REDIS_PORT" "protocol" "INVENIO_CONFIG_REDIS_PROTOCOL" }}
{{- $root := . }}
- name: redis-config
  projected:
    sources:
  {{- if .Values.redisExternal.uri }}
    - secret:
        name: {{ include "invenio.fullname" $root }}-invenio-redis-inline
	items:
	- key: uri
	  path: INVENIO_BROKER_URL
	- key: uri
	  path: INVENIO_CELERY_BROKER_URL
  {{- else if .Values.redisExternal.uriKey }}
    - secret:
        name: {{ coalesce .Values.redisExternal.uriSecret (include "invenio.redis.secretName" $root | trim) }} 
        items:
        - key: {{ .Values.redisExternal.uriKey }} 
          path: INVENIO_BROKER_URL
        - key: {{ .Values.redisExternal.uriKey }} 
          path: INVENIO_CELERY_BROKER_URL
  {{- else }}
    {{- range $item, $value := $fields }}
    - secret:
      {{- if hasKey $root.Values.redisExternal $item }}
        name: {{ include "invenio.fullname" $root }}-invenio-redis-inline
        items:
        - key: {{ $item }}
          path: {{ $value }}
      {{- else }}
        {{- $keyName := (printf "%sKey" $item) }}
        {{- $secretName := (printf "%sSecret" $item) }}
        name: {{ coalesce (get $root.Values.redisExternal $secretName) (include "invenio.redis.secretName" $root | trim) }}
        items: 
        - key: {{ get $root.Values.redisExternal $keyName }}
          path: {{ $value | toString }}
      {{- end }}
    {{- end }}
  {{- end }}
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
  This template renders the name of the default secret that stores info about RabbitMQ.
*/}}
{{- define "invenio.rabbitmq.secretName" -}}
  {{- if .Values.rabbitmq.enabled }}
    {{- include "rabbitmq.secretPasswordName" .Subcharts.rabbitmq }}
  {{- else if and (not .Values.rabbitmq.enabled) .Values.rabbitmqExternal.existingSecret }}
    {{- required "Missing .Values.rabbitmqExternal.existingSecret" .Values.rabbitmqExternal.existingSecret }}
  {{- else }}
    {{- fail (printf "\n\nthere is somthing wrong with rabbitmq secret,\n\nI'm printing contexts for rabbitmq\n\nrabbitmq:\n%v\n\nrabbitmqExternal:\n%v" (toYaml .Values.rabbitmq | nindent 2) (toYaml .Values.rabbitmqExternal | nindent 2)) | indent 4 }}
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
  {{- else if and (not .Values.rabbitmq.enabled) .Values.rabbitmqExternal.amqpPortKey }}
valueFrom:
  secretKeyRef:
    name: {{ coalesce .Values.rabbitmqExternal.amqpPortSecret (include "invenio.rabbitmq.secretName" . | trim) }}
    key: {{ required "Missing .Values.rabbitmqExternal.amqpPortKey" (tpl  .Values.rabbitmqExternal.amqpPortKey .) }}
  {{- else }}
{{- printf "value: 5672" | nindent 0 }}
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
  {{- else if and (not .Values.rabbitmq.enabled) .Values.rabbitmqExternal.managementPortKey }}
valueFrom:
  secretKeyRef:
    name: {{ coalesce .Values.rabbitmqExternal.managementPortSecret (include "invenio.rabbitmq.secretName" . | trim) }}
    key: {{ required "Missing .Values.rabbitmqExternal.managementPortKey" (tpl  .Values.rabbitmqExternal.managementPortKey .) }}
  {{- else }}
{{- printf "value: 15672" | nindent 0 }}
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
  This template renders the whole URI into one string for RabbitMQ.
*/}}
{{- define "invenio.rabbitmq.uri" -}}
  {{- if and (not .Values.rabbitmq.enabled) .Values.rabbitmqExternal.uri }}
{{- printf "value: %s" .Values.rabbitmqExternal.uri | nindent 0 }}
  {{- else if and (not .Values.rabbitmq.enabled) .Values.rabbitmqExternal.uriKey }}
valueFrom:
  secretKeyRef:
    name: {{ coalesce .Values.rabbitmqExternal.uriSecret (include "invenio.rabbitmq.secretName" . | trim) }}
    key: {{ required "Missing .Values.rabbitmqExternal.uriKey" (tpl  .Values.rabbitmqExternal.uriKey .) }}
  {{- end -}}
{{- end -}}

{{/*
  RabbitMQ connection env section.
*/}}
{{- define "invenio.config.queue" -}}
{{- if and (not .Values.rabbitmqExternal.uriKey) (not .Values.rabbitmqExternal.uri) }}
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
{{- else }}
- name: INVENIO_BROKER_URL
  {{- (include "invenio.rabbitmq.uri" . | trim) | nindent 2 }}
- name: INVENIO_CELERY_BROKER_URL
  {{- (include "invenio.rabbitmq.uri" . | trim) | nindent 2 }}
{{- end }}
{{- end }}

{{/*
  Define a projected volume for RabbitMQ config file.

  Usage:
    {{ include "invenio.rabbitmq.configFile" . | nindent 6 }}

  Expected context:
    .Values.rabbitmqExternal.*
*/}}

{{- define "invenio.rabbitmq.configFile" -}}
{{- $fields := dict "username" "INVENIO_AMQP_BROKER_USER" "password" "INVENIO_AMQP_BROKER_PASSWORD" "hostname" "INVENIO_AMQP_BROKER_HOST" "amqpPort" "INVENIO_AMQP_BROKER_PORT" "vhost" "INVENIO_AMQP_BROKER_VHOST" "protocol" "INVENIO_AMQP_BROKER_PROTOCOL" }}
{{- $root := . }}
- name: rabbitmq-config
  projected:
    sources:
  {{- if .Values.rabbitmqExternal.uri }}
    - secret:
        name: {{ include "invenio.fullname" $root }}-invenio-rabbitmq-inline
	items:
	- key: uri
	  path: INVENIO_BROKER_URL
	- key: uri
	  path: INVENIO_CELERY_BROKER_URL
  {{- else if .Values.rabbitmqExternal.uriKey }}
    - secret:
        name: {{ coalesce .Values.rabbitmqExternal.uriSecret (include "invenio.rabbitmq.secretName" $root | trim) }} 
        items:
        - key: {{ .Values.rabbitmqExternal.uriKey }} 
          path: INVENIO_BROKER_URL
        - key: {{ .Values.rabbitmqExternal.uriKey }} 
          path: INVENIO_CELERY_BROKER_URL
  {{- else }}
    {{- range $item, $value := $fields }}
    - secret:
      {{- if hasKey $root.Values.rabbitmqExternal $item }}
        name: {{ include "invenio.fullname" $root }}-invenio-rabbitmq-inline
        items:
        - key: {{ $item }}
          path: {{ $value }}
      {{- else }}
        {{- $keyName := (printf "%sKey" $item) }}
        {{- $secretName := (printf "%sSecret" $item) }}
	{{- if not (hasKey $root.Values.rabbitmqExternal $keyName) }}
        {{- fail (printf "\n\nthere is somthing wrong with rabbitmq config file definition. I'm missing key: %s,\n\n\nI'm printing contexts.\n\nrabbitmq:%v\n\nrabbitmqExternal:%v" $keyName (toYaml $root.Values.rabbitmq | nindent 2) (toYaml $root.Values.rabbitmqExternal | nindent 2)) | indent 4 }}
        {{- end }}
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
  This template renders the envs for the PostgreSQL instance.
  consumes 
*/}}
{{- define "invenio.svc.renderEnv" -}}
{{- $root := . }}
{{- $myVal := ( fromYaml .myVal) }}
- name: {{ .envName }}
  {{- if and (not (eq $myVal.instance "internalSecret")) (not (eq $myVal.instance "externalSecret")) }}
  value: {{ printf "%q" $myVal.value }}
  {{- else }}
  valueFrom:
    secretKeyRef:
      name: {{ $myVal.secretName }}
      key: {{ $myVal.value }}
  {{- end -}}
{{- end -}}



{{/*
  This template renders the projected secrets ofor the PostgreSQL instance.
  consumes 
*/}}
{{- define "invenio.render.projectedSecret" -}}
{{- $root := . }}
{{- $myVal := ( fromYaml .myVal) }}
{{- $envName := .envName }}
{{- $myKey := "" }}
{{- if or (eq $myVal.instance "internal") (eq $myVal.instance "external") }}
{{- $myKey = $myVal.key }}
{{- else }}
{{- $myKey = $myVal.value }}
{{- end }}
- secret:
    name: {{ $myVal.secretName }}
    items:
    - key: {{ $myKey }}
      path: {{ $envName  }} 
{{- end -}}




{{/*
  Get the database cluster config secret name
*/}}
{{- define "invenio.postgresql.secretName" -}}
  {{- if .Values.postgresql.enabled -}}
    {{- required "Missing .Values.postgresql.auth.existingSecret" (tpl .Values.postgresql.auth.existingSecret .) -}}
  {{- else if and (not .Values.postgresql.enabled) .Values.postgresqlExternal.existingSecret -}}
    {{- required "Missing .Values.postgresqlExternal.existingSecret" (tpl .Values.postgresqlExternal.existingSecret .) -}}
  {{- else }}
    {{- fail (printf "\n\nthere is somthing wrong with postgresql congfiguration,\n\nI'm printing contexts.\n\npostgresql:%v\n\npostgresqlExternal:%v" (toYaml .Values.postgresql | nindent 2) (toYaml .Values.postgresqlExternal | nindent 2)) | indent 4 }}
  {{- end -}}
{{- end -}}

{{/*
  This template renders the username used for the PostgreSQL instance.
*/}}
{{- define "invenio.postgresql.username" -}}
{{- $root := . }}
{{- $return := dict }}
{{- if .Values.postgresql.enabled -}}
  {{- if .Values.postgresql.auth.username }}
    {{- $_ := set $return "instance" "internal" }}
    {{- $_ := set $return "key" "username" }}
    {{- $_ := set $return "value" (required "Missing .values.postgresql.auth.username" (tpl .Values.postgresql.auth.username .)) }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "postgresql" "root" $root)) | trim) }}
  {{- else }}
    {{- include "invenio.failingConfig" (dict "root" $root "key" "username" "service" "postgresql") }} 
  {{- end }}
{{- else }}
  {{- if .Values.postgresqlExternal.username }}
    {{- $_ := set $return "instance" "external" }}
    {{- $_ := set $return "key" "username" }}
    {{- $_ := set $return "value" .Values.postgresqlExternal.username }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "postgresql" "root" $root)) | trim) }}
  {{- else if .Values.postgresqlExternal.usernameKey }}
    {{- $_ := set $return "instance" "externalSecret" }}
    {{- $_ := set $return "key" "usernameKey" }}
    {{- $_ := set $return "value" .Values.postgresqlExternal.usernameKey }}
    {{- $_ := set $return "secretName" ( coalesce .Values.postgresqlExternal.usernameSecret (include "invenio.postgresql.secretName" . | trim)) }}
  {{- else }}
    {{- include "invenio.failingConfig" (dict "root" $root "key" "username" "service" "postgresql") }} 
  {{- end }}
{{- end -}}
{{- toYaml $return }}
{{- end -}}

{{/*
  This template renders the hostname used for the PostgreSQL instance.
*/}}
{{- define "invenio.postgresql.hostname" -}}
{{- $root := . }}
{{- $return := dict }}
{{- if .Values.postgresql.enabled -}}
  {{- if .Values.postgresql.hostname }}
    {{- $_ := set $return "instance" "internal" }}
    {{- $_ := set $return "key" "hostname" }}
    {{- $_ := set $return "value" (required "Missing .Values.postgresql.hostname" (tpl .Values.postgresql.hostname .)) }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "postgresql" "root" $root)) | trim) }}
  {{- else }}
    {{- include "invenio.failingConfig" (dict "root" $root "key" "hostname" "service" "postgresql") }} 
  {{- end }}
{{- else }}
  {{- if .Values.postgresqlExternal.hostname }}
    {{- $_ := set $return "instance" "external" }}
    {{- $_ := set $return "key" "hostname" }}
    {{- $_ := set $return "value" "hostname" }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "postgresql" "root" $root)) | trim) }}
  {{- else if .Values.postgresqlExternal.hostnameKey }}
    {{- $_ := set $return "instance" "externalSecret" }}
    {{- $_ := set $return "key" "hostnameKey" }}
    {{- $_ := set $return "value" .Values.postgresqlExternal.hostnameKey }}
    {{- $_ := set $return "secretName" ( coalesce .Values.postgresqlExternal.hostnameSecret (include "invenio.postgresql.secretName" . | trim)) }}
  {{- else }}
    {{- include "invenio.failingConfig" (dict "root" $root "key" "hostname" "service" "postgresql") }} 
  {{- end }}
{{- end -}}
{{- toYaml $return }}
{{- end -}}

{{/*
  This template renders the password used for the PostgreSQL instance.
  In production environments we encourage you to use secrets instead.
*/}}
{{- define "invenio.postgresql.password" -}}
{{- $root := . }}
{{- $return := dict }}
{{- if and .Values.postgresql.enabled }} 
  {{- if .Values.postgresql.auth.password -}}
    {{- $_ := set $return "instance" "internal" }}
    {{- $_ := set $return "key" "password" }}
    {{- $_ := set $return "value" (required "Missing .Values.postgresql.auth.password" (tpl .Values.postgresql.auth.password .)) }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "postgresql" "root" $root)) | trim) }}
  {{- else if .Values.postgresql.auth.existingSecret -}}
    {{- $_ := set $return "instance" "internalSecret" }}
    {{- $_ := set $return "key" "userPasswordKey" }}
    {{- $_ := set $return "value" (required "Missing .Values.postgresql.auth.secretKeys.userPasswordKey" (tpl .Values.postgresql.auth.secretKeys.userPasswordKey .)) -}}
    {{- $_ := set $return "secretName"  (include "invenio.postgresql.secretName" .) }}
  {{- else }}
    {{- include "invenio.failingConfig" (dict "root" $root "key" "password" "service" "postgresql") }} 
  {{- end }}
{{- else }} 
  {{- if and .Values.postgresqlExternal.password }}
    {{- $_ := set $return "instance" "external" }}
    {{- $_ := set $return "key" "password" }}
    {{- $_ := set $return "value" .Values.postgresqlExternal.password }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "postgresql" "root" $root)) | trim) }}
  {{- else if .Values.postgresqlExternal.passwordKey }}
    {{- $_ := set $return "instance" "externalSecret" }}
    {{- $_ := set $return "key" "passwordKey" }}
    {{- $_ := set $return "value" .Values.postgresqlExternal.passwordKey }}
    {{- $_ := set $return "secretName" ( coalesce .Values.postgresqlExternal.passwordSecret (include "invenio.postgresql.secretName" . | trim)) }}
  {{- else }}
    {{- include "invenio.failingConfig" (dict "root" $root "key" "password" "service" "postgresql") }} 
  {{- end -}}
{{- end -}}
{{- toYaml $return }}
{{- end -}}

{{/*
  This template renders the port number used for the PostgreSQL instance (as a string).
*/}}
{{- define "invenio.postgresql.portString" -}}
{{- $root := . }}
{{- $return := dict }}
{{- if .Values.postgresql.enabled -}}
    {{- $_ := set $return "instance" "internal" }}
    {{- $_ := set $return "key" "portString" }}
    {{- $_ := set $return "value" (required "Missing .Values.postgresql.primary.service.ports.postgresql" (tpl (toString .Values.postgresql.primary.service.ports.postgresql) .)) }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "postgresql" "root" $root)) | trim) }}
{{- else }}
  {{- if .Values.postgresqlExternal.portString }}
    {{- $_ := set $return "instance" "external" }}
    {{- $_ := set $return "key" "portString" }}
    {{- $_ := set $return "value" (tpl (toString .Values.postgresqlExternal.portString) . | toString) }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "postgresql" "root" $root)) | trim) }}
  {{- else if .Values.postgresqlExternal.portStringKey }}
    {{- $_ := set $return "instance" "externalSecret" }}
    {{- $_ := set $return "key" "portStringKey" }}
    {{- $_ := set $return "value" .Values.postgresqlExternal.portStringKey }}
    {{- $_ := set $return "secretName" ( coalesce .Values.postgresqlExternal.portStringSecret (include "invenio.postgresql.secretName" . | trim)) }}
  {{- else }}
    {{- include "invenio.failingConfig" (dict "root" $root "key" "portString" "service" "postgresql") }} 
  {{- end }}
{{- end -}}
{{- toYaml $return }}
{{- end -}}

{{/*
  This template renders the name of the database in PostgreSQL.
*/}}
{{- define "invenio.postgresql.database" -}}
{{- $root := . }}
{{- $return := dict }}
{{- if .Values.postgresql.enabled -}}
    {{- $_ := set $return "instance" "internal" }}
    {{- $_ := set $return "key" "database" }}
    {{- $_ := set $return "value" (required "Missing .Values.postgresql.auth.database" (tpl .Values.postgresql.auth.database .)) }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "postgresql" "root" $root)) | trim) }}
{{- else }}
  {{- if .Values.postgresqlExternal.database }}
    {{- $_ := set $return "instance" "external" }}
    {{- $_ := set $return "key" "database" }}
    {{- $_ := set $return "value" .Values.postgresqlExternal.database }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "postgresql" "root" $root)) | trim) }}
  {{- else if .Values.postgresqlExternal.databaseKey }}
    {{- $_ := set $return "instance" "externalSecret" }}
    {{- $_ := set $return "key" "databaseKey" }}
    {{- $_ := set $return "value" .Values.postgresqlExternal.databaseKey }}
    {{- $_ := set $return "secretName" ( coalesce .Values.postgresqlExternal.databaseSecret (include "invenio.postgresql.secretName" . | trim)) }}
  {{- else }}
    {{- include "invenio.failingConfig" (dict "root" $root "key" "database" "service" "postgresql") }} 
  {{- end }}
{{- end -}}
{{- toYaml $return }}
{{- end -}}

{{/*
  This template renders the port number used for the PostgreSQL instance (as a string).
*/}}
{{- define "invenio.postgresql.protocol" -}}
{{- $root := . }}
{{- $return := dict }}
{{- if .Values.postgresql.enabled -}}
  {{- if .Values.postgresql.protocol }}
    {{- $_ := set $return "instance" "internal" }}
    {{- $_ := set $return "key" "protocol" }}
    {{- $_ := set $return "value" (tpl .Values.postgresql.protocol .) }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "postgresql" "root" $root)) | trim) }}
  {{- else }}
    {{- $_ := set $return "instance" "internal" }}
    {{- $_ := set $return "key" "protocol" }}
    {{- $_ := set $return "value" "postgresql+psycopg2"}}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "postgresql" "root" $root)) | trim) }}
  {{- end }}
{{- else }}
  {{- if .Values.postgresqlExternal.protocol }}
    {{- $_ := set $return "instance" "external" }}
    {{- $_ := set $return "key" "protocol" }}
    {{- $_ := set $return "value" (tpl (toString .Values.postgresqlExternal.protocol) . | toString) }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "postgresql" "root" $root)) | trim) }}
  {{- else if .Values.postgresqlExternal.protocolKey }}
    {{- $_ := set $return "instance" "externalSecret" }}
    {{- $_ := set $return "key" "protocolKey" }}
    {{- $_ := set $return "value" .Values.postgresqlExternal.protocolKey }}
    {{- $_ := set $return "secretName" ( coalesce .Values.postgresqlExternal.protocolSecret (include "invenio.postgresql.secretName" . | trim)) }}
  {{- else }}
    {{- $_ := set $return "instance" "external" }}
    {{- $_ := set $return "key" "protocol" }}
    {{- $_ := set $return "value" "postgresql+psycopg2"}}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "postgresql" "root" $root)) | trim) }}
  {{- end }}
{{- end -}}
{{- toYaml $return }}
{{- end -}}

{{/*
  This template renders the name of the uri in PostgreSQL.
*/}}
{{- define "invenio.postgresql.uri" -}}
{{- $root := . }}
{{- $return := dict }}
  {{- if and (not .Values.postgresql.enabled) .Values.postgresqlExternal.uri }}
    {{- $_ := set $return "instance" "external" }}
    {{- $_ := set $return "key" "uri" }}
    {{- $_ := set $return "value" (tpl (toString .Values.postgresqlExternal.uri) . | toString) }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "postgresql" "root" $root)) | trim) }}
  {{- else if and (not .Values.postgresql.enabled) .Values.postgresqlExternal.uriKey }}
    {{- $_ := set $return "instance" "externalSecret" }}
    {{- $_ := set $return "key" "uriKey" }}
    {{- $_ := set $return "value" .Values.postgresqlExternal.uriKey }}
    {{- $_ := set $return "secretName" ( coalesce .Values.postgresqlExternal.protocolSecret (include "invenio.postgresql.secretName" . | trim)) }}
  {{- end -}}
{{- toYaml $return }}
{{- end -}}

{{/*
  Define database connection env section.
*/}}
{{- define "invenio.config.database" -}}
{{- if and (not .Values.postgresqlExternal.uriKey) (not .Values.postgresqlExternal.uri) }} 

{{- include "invenio.svc.renderEnv" (dict "myVal" (include "invenio.postgresql.database" .) "envName" "INVENIO_DB_NAME") | trim | nindent 0 }}
{{- include "invenio.svc.renderEnv" (dict "myVal" (include "invenio.postgresql.username" .) "envName" "INVENIO_DB_USER") | trim | nindent 0 }}
{{- include "invenio.svc.renderEnv" (dict "myVal" (include "invenio.postgresql.hostname" .) "envName" "INVENIO_DB_HOST") | trim | nindent 0 }}
{{- include "invenio.svc.renderEnv" (dict "myVal" (include "invenio.postgresql.portString" .) "envName" "INVENIO_DB_PORT") | trim | nindent 0 }}
{{- include "invenio.svc.renderEnv" (dict "myVal" (include "invenio.postgresql.password" .) "envName" "INVENIO_DB_PASSWORD") | trim | nindent 0 }}
{{- include "invenio.svc.renderEnv" (dict "myVal" (include "invenio.postgresql.protocol" .) "envName" "INVENIO_DB_PROTOCOL") | trim | nindent 0 }}
- name: INVENIO_SQLALCHEMY_DATABASE_URI
  value: "$(INVENIO_DB_PROTOCOL)://$(INVENIO_DB_USER):$(INVENIO_DB_PASSWORD)@$(INVENIO_DB_HOST):$(INVENIO_DB_PORT)/$(INVENIO_DB_NAME)"

{{- else }}
{{- include "invenio.svc.renderEnv" (dict "myVal" (include "invenio.postgresql.uri" .) "envName" "INVENIO_SQLALCHEMY_DATABASE_URI") | trim | nindent 0 }}
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
{{- $fields := dict "username" "INVENIO_DB_USER" "password" "INVENIO_DB_PASSWORD" "hostname" "INVENIO_DB_HOST" "portString" "INVENIO_DB_PORT" "database" "INVENIO_DB_NAME" "protocol" "INVENIO_DB_PROTOCOL" }}
{{- $root := . }}
- name: postgresql-config
  projected:
    sources:
    {{- if and (not .Values.postgresql.enabled) (or .Values.postgresqlExternal.uri .Values.postgresqlExternal.uriKey) }}
    {{- include "invenio.render.projectedSecret" (dict "myVal" (include "invenio.postgresql.uri" .) "envName" "INVENIO_SQLALCHEMY_DATABASE_URI") | trim | nindent 4 }}
    {{- else }}
    {{- range $item, $value := $fields }}
    - secret:
      {{- if hasKey $root.Values.postgresqlExternal $item }}
        name: {{ include "invenio.fullname" $root }}-invenio-postgresql-inline
        items:
        - key: {{ $item }}
          path: {{ $value }}
      {{- else }}
        {{- $keyName := (printf "%sKey" $item) }}
        {{- $secretName := (printf "%sSecret" $item) }}
	{{- if not (hasKey $root.Values.postgresqlExternal $keyName) }}
        {{- fail (printf "\n\nthere is somthing wrong with postgresql config file definition. I'm missing key: %s,\n\n\nI'm printing contexts.\n\npostgresql:%v\n\npostgresqlExternal:%v" $keyName (toYaml $root.Values.postgresql | nindent 2) (toYaml $root.Values.postgresqlExternal | nindent 2)) | indent 4 }}
        {{- end }}
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
