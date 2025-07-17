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


###########################     Invenio env render     ###########################
{{/*
  This template renders the envs for the PostgreSQL instance.
  consumes 
*/}}
{{- define "invenio.svc.renderEnv" -}}
{{- $root := . }}
{{- $myVal := ( fromYaml .myVal) }}
- name: {{ .envName }}
  {{- if and (not (eq $myVal.instance "internalSecret")) (not (eq $myVal.instance "externalSecret")) }}
  value: {{ printf "%q" (toString $myVal.value) }}
  {{- else }}
  valueFrom:
    secretKeyRef:
      name: {{ $myVal.secretName }}
      key: {{ $myVal.value }}
  {{- end -}}
{{- end -}}

###########################     Invenio projected secret render     ###########################
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

############################     Redis Hostname     ############################

{{/*
  This template renders the name of the default secret that stores info about RabbitMQ.
*/}}
{{- define "invenio.redis.secretName" -}}
  {{- if .Values.redis.enabled }}
    {{- include "redis.secretName" .Subcharts.redis }}
  {{- else if and (not .Values.redis.enabled) .Values.redisExternal.existingSecret }}
    {{- required "Missing .Values.redisExternal.existingSecret" .Values.redisExternal.existingSecret }}
  {{- end }}
{{- end -}}

{{/*
  This template renders the hostname for Redis.
*/}}
{{- define "invenio.redis.hostname" -}}
{{- $root := . }}
{{- $return := dict }}
{{- if .Values.redis.enabled -}}
    {{- $_ := set $return "instance" "internal" }}
    {{- $_ := set $return "key" "hostname" }}
    {{- $_ := set $return "value" (printf "%s" (include "common.names.fullname" $root.Subcharts.redis)) }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "redis" "root" $root)) | trim) }}
{{- else }}
  {{- if .Values.redisExternal.hostname }}
    {{- $_ := set $return "instance" "external" }}
    {{- $_ := set $return "key" "hostname" }}
    {{- $_ := set $return "value" .Values.redisExternal.hostname }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "redis" "root" $root)) | trim) }}
  {{- else if .Values.redisExternal.hostnameKey }}
    {{- $_ := set $return "instance" "externalSecret" }}
    {{- $_ := set $return "key" "hostnameKey" }}
    {{- $_ := set $return "value" .Values.redisExternal.hostnameKey }}
    {{- $_ := set $return "secretName" ( coalesce .Values.redisExternal.hostnameSecret (include "invenio.redis.secretName" . | trim)) }}
  {{- else }}
    {{- include "invenio.failingConfig" (dict "root" $root "key" "hostname" "service" "redis") }}
  {{- end }}
{{- end -}}
{{- toYaml $return }}
{{- end -}}

{{/*
  This template renders the password for Redis.
*/}}
{{- define "invenio.redis.password" -}}
{{- $root := . }}
{{- $return := dict }}
{{- if and .Values.redis.enabled }} 
  {{- if .Values.redis.password }}
    {{- $_ := set $return "instance" "internal" }}
    {{- $_ := set $return "key" "password" }}
    {{- $_ := set $return "value" (required "Missing .Values.redis.auth.password" (tpl .Values.redis.auth.password .)) }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "redis" "root" $root)) | trim) }}
  {{- else if .Values.redis.auth.existingSecret -}}
    {{- $_ := set $return "instance" "internalSecret" }}
    {{- $_ := set $return "key" "existingSecretPasswordKey" }}
    {{- $_ := set $return "value" (required "Missing .Values.redis.auth.existingSecretPasswordKey" (tpl .Values.redis.auth.existingSecretPasswordKey .)) -}}
    {{- $_ := set $return "secretName"  .Values.redis.auth.existingPasswordSecret }}
  {{- else }}
    {{- $_ := set $return "instance" "internalSecret" }}
    {{- $_ := set $return "key" "password" }}
    {{- $_ := set $return "value" "redis-password" -}}
    {{- $_ := set $return "secretName" ( include "redis.secretName" $root.Subcharts.redis | trim) }}
  {{- end }}
{{- else }} 
  {{- if and .Values.redisExternal.password }}
    {{- $_ := set $return "instance" "external" }}
    {{- $_ := set $return "key" "password" }}
    {{- $_ := set $return "value" .Values.redisExternal.password }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "redis" "root" $root)) | trim) }}
  {{- else if .Values.redisExternal.passwordKey }}
    {{- $_ := set $return "instance" "externalSecret" }}
    {{- $_ := set $return "key" "passwordKey" }}
    {{- $_ := set $return "value" .Values.redisExternal.passwordKey }}
    {{- $_ := set $return "secretName" ( coalesce .Values.redisExternal.passwordSecret (include "invenio.redis.secretName" . | trim)) }}
  {{- else }}
    {{- include "invenio.failingConfig" (dict "root" $root "key" "password" "service" "redis") }} 
  {{- end -}}
{{- end -}}
{{- toYaml $return }}
{{- end -}}

{{/*
  This template renders the protocol for accessing Redis.
*/}}
{{- define "invenio.redis.protocol" -}}
{{- $root := . }}
{{- $return := dict }}
{{- if .Values.redis.enabled -}}
    {{- $_ := set $return "instance" "internal" }}
    {{- $_ := set $return "key" "protocol" }}
    {{- $_ := set $return "value" "redis" }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "redis" "root" $root)) | trim) }}
{{- else }}
  {{- if .Values.redisExternal.protocol }}
    {{- $_ := set $return "instance" "external" }}
    {{- $_ := set $return "key" "protocol" }}
    {{- $_ := set $return "value" (tpl (toString .Values.redisExternal.protocol) . | toString) }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "redis" "root" $root)) | trim) }}
  {{- else if .Values.redisExternal.protocolKey }}
    {{- $_ := set $return "instance" "externalSecret" }}
    {{- $_ := set $return "key" "protocolKey" }}
    {{- $_ := set $return "value" .Values.redisExternal.protocolKey }}
    {{- $_ := set $return "secretName" ( coalesce .Values.redisExternal.protocolSecret (include "invenio.redis.secretName" . | trim)) }}
  {{- else }}
    {{- $_ := set $return "instance" "external" }}
    {{- $_ := set $return "key" "protocol" }}
    {{- $_ := set $return "value" "redis" }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "redis" "root" $root)) | trim) }}
  {{- end }}
{{- end -}}
{{- toYaml $return }}
{{- end -}}

{{/*
  This template renders the port for accessing Redis.
*/}}
{{- define "invenio.redis.portString" -}}
{{- $root := . }}
{{- $return := dict }}
{{- if .Values.redis.enabled -}}
    {{- $_ := set $return "instance" "internal" }}
    {{- $_ := set $return "key" "redisPortString" }}
    {{- $_ := set $return "value" ( toString "6379") }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "redis" "root" $root)) | trim) }}
{{- else }}
  {{- if .Values.redisExternal.redisPortString }}
    {{- $_ := set $return "instance" "external" }}
    {{- $_ := set $return "key" "redisPortString" }}
    {{- $_ := set $return "value" (tpl (toString .Values.redisExternal.redisPortString) . | toString) }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "redis" "root" $root)) | trim) }}
  {{- else if .Values.redisExternal.redisPortStringKey }}
    {{- $_ := set $return "instance" "externalSecret" }}
    {{- $_ := set $return "key" "redisPortStringKey" }}
    {{- $_ := set $return "value" .Values.redisExternal.redisPortStringKey }}
    {{- $_ := set $return "secretName" ( coalesce .Values.redisExternal.redisPortStringSecret (include "invenio.redis.secretName" . | trim)) }}
  {{- else }}
    {{- $_ := set $return "instance" "external" }}
    {{- $_ := set $return "key" "redisPortString" }}
    {{- $_ := set $return "value" ( toString "6379") }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "redis" "root" $root)) | trim) }}
  {{- end }}
{{- end -}}
{{- toYaml $return }}
{{- end -}}

{{/*
  This template renders the whole config for the Redis instance used.
*/}}
{{- define "invenio.config.cache" -}}
{{- $connectionString := ":$(INVENIO_CONFIG_REDIS_PASSWORD)@$(INVENIO_CONFIG_REDIS_HOST)" -}}
{{- $connectionUrl := "$(INVENIO_CONFIG_REDIS_PROTOCOL)://:$(INVENIO_CONFIG_REDIS_PASSWORD)@$(INVENIO_CONFIG_REDIS_HOST):$(INVENIO_CONFIG_REDIS_PORT)" }}
{{- include "invenio.svc.renderEnv" (dict "myVal" (include "invenio.redis.hostname" .) "envName" "INVENIO_CONFIG_REDIS_HOST") | trim | nindent 0 }}
{{- include "invenio.svc.renderEnv" (dict "myVal" (include "invenio.redis.password" .) "envName" "INVENIO_CONFIG_REDIS_PASSWORD") | trim | nindent 0 }}
{{- include "invenio.svc.renderEnv" (dict "myVal" (include "invenio.redis.portString" .) "envName" "INVENIO_CONFIG_REDIS_PORT") | trim | nindent 0 }}
{{- include "invenio.svc.renderEnv" (dict "myVal" (include "invenio.redis.protocol" .) "envName" "INVENIO_CONFIG_REDIS_PROTOCOL") | trim | nindent 0 }}
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
{{- $fields := dict "password" "INVENIO_CONFIG_REDIS_PASSWORD" "hostname" "INVENIO_CONFIG_REDIS_HOST" "portString" "INVENIO_CONFIG_REDIS_PORT" "protocol" "INVENIO_CONFIG_REDIS_PROTOCOL" }}
{{- $root := . }}
- name: redis-config
  projected:
    sources:
    {{- range $item, $value := $fields }}
      {{- $invenioHelper := (printf "%s%s" "invenio.redis." $item)  }}
      {{- include "invenio.render.projectedSecret" (dict "myVal" (include $invenioHelper $root) "envName" $value) | trim | nindent 4 }}
    {{- end }}
{{- end }}


#######################     RabbitMQ connection configuration     #######################
{{/*
  This template renders the name of the default secret that stores info about RabbitMQ.
*/}}
{{- define "invenio.rabbitmq.secretName" -}}
{{- $root := . }}
  {{- if .Values.rabbitmq.enabled }}
    {{- include "rabbitmq.secretPasswordName" .Subcharts.rabbitmq }}
  {{- else if and (not .Values.rabbitmq.enabled) .Values.rabbitmqExternal.existingSecret }}
    {{- required "Missing .Values.rabbitmqExternal.existingSecret" .Values.rabbitmqExternal.existingSecret }}
  {{- end }}
{{- end -}}

{{/*
  This template renders the username for accessing RabbitMQ.
*/}}
{{- define "invenio.rabbitmq.username" -}}
{{- $root := . }}
{{- $return := dict }}
{{- if .Values.rabbitmq.enabled -}}
    {{- $_ := set $return "instance" "internal" }}
    {{- $_ := set $return "key" "username" }}
    {{- $_ := set $return "value" (required "Missing .values.rabbitmq.auth.username" (tpl .Values.rabbitmq.auth.username .)) }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "rabbitmq" "root" $root)) | trim) }}
{{- else }}
  {{- if .Values.rabbitmqExternal.username }}
    {{- $_ := set $return "instance" "external" }}
    {{- $_ := set $return "key" "username" }}
    {{- $_ := set $return "value" .Values.rabbitmqExternal.username }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "rabbitmq" "root" $root)) | trim) }}
  {{- else if .Values.rabbitmqExternal.usernameKey }}
    {{- $_ := set $return "instance" "externalSecret" }}
    {{- $_ := set $return "key" "usernameKey" }}
    {{- $_ := set $return "value" .Values.rabbitmqExternal.usernameKey }}
    {{- $_ := set $return "secretName" ( coalesce .Values.rabbitmqExternal.usernameSecret (include "invenio.rabbitmq.secretName" . | trim)) }}
  {{- else }}
    {{- include "invenio.failingConfig" (dict "root" $root "key" "username" "service" "rabbitmq") }} 
  {{- end }}
{{- end -}}
{{- toYaml $return }}
{{- end -}}

{{/*
  This template renders the password for accessing RabbitMQ.
*/}}
{{- define "invenio.rabbitmq.password" -}}
{{- $root := . }}
{{- $return := dict }}
{{- if and .Values.rabbitmq.enabled }} 
  {{- if .Values.rabbitmq.password }}
    {{- $_ := set $return "instance" "internal" }}
    {{- $_ := set $return "key" "password" }}
    {{- $_ := set $return "value" (required "Missing .Values.rabbitmq.auth.password" (tpl .Values.rabbitmq.auth.password .)) }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "rabbitmq" "root" $root)) | trim) }}
  {{- else if .Values.rabbitmq.auth.existingPasswordSecret -}}
    {{- $_ := set $return "instance" "internalSecret" }}
    {{- $_ := set $return "key" "existingSecretPasswordKey" }}
    {{- $_ := set $return "value" (required "Missing .Values.rabbitmq.auth.existingSecretPasswordKey" (tpl .Values.rabbitmq.auth.existingSecretPasswordKey .)) -}}
    {{- $_ := set $return "secretName"  .Values.rabbitmq.auth.existingPasswordSecret }}
  {{- else }}
    {{- $_ := set $return "instance" "internalSecret" }}
    {{- $_ := set $return "key" "password" }}
    {{- $_ := set $return "value" "rabbitmq-password" -}}
    {{- $_ := set $return "secretName" ( include "rabbitmq.secretPasswordName" $root.Subcharts.rabbitmq | trim) }}
  {{- end }}
{{- else }} 
  {{- if and .Values.rabbitmqExternal.password }}
    {{- $_ := set $return "instance" "external" }}
    {{- $_ := set $return "key" "password" }}
    {{- $_ := set $return "value" .Values.rabbitmqExternal.password }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "rabbitmq" "root" $root)) | trim) }}
  {{- else if .Values.rabbitmqExternal.passwordKey }}
    {{- $_ := set $return "instance" "externalSecret" }}
    {{- $_ := set $return "key" "passwordKey" }}
    {{- $_ := set $return "value" .Values.rabbitmqExternal.passwordKey }}
    {{- $_ := set $return "secretName" ( coalesce .Values.rabbitmqExternal.passwordSecret (include "invenio.rabbitmq.secretName" . | trim)) }}
  {{- else }}
    {{- include "invenio.failingConfig" (dict "root" $root "key" "password" "service" "rabbitmq") }} 
  {{- end -}}
{{- end -}}
{{- toYaml $return }}
{{- end -}}

{{/*
  This template renders the AMQP port number for RabbitMQ.
*/}}
{{- define "invenio.rabbitmq.amqpPortString" -}}
{{- $root := . }}
{{- $return := dict }}
{{- if .Values.rabbitmq.enabled -}}
  {{- if .Values.rabbitmq.service.ports.amqp }}
    {{- $_ := set $return "instance" "internal" }}
    {{- $_ := set $return "key" "amqpPortString" }}
    {{- $_ := set $return "value" .Values.rabbitmq.service.ports.amqp }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "rabbitmq" "root" $root)) | trim) }}
  {{- else }}
    {{- $_ := set $return "instance" "internalSecret" }}
    {{- $_ := set $return "key" "amqpPortString" }}
    {{- $_ := set $return "value" ( toString "5672") }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "rabbitmq" "root" $root)) | trim) }}
  {{- end }}
{{- else }}
  {{- if .Values.rabbitmqExternal.amqpPortString }}
    {{- $_ := set $return "instance" "external" }}
    {{- $_ := set $return "key" "amqpPortString" }}
    {{- $_ := set $return "value" (tpl (toString .Values.rabbitmqExternal.amqpPortString) . | toString) }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "rabbitmq" "root" $root)) | trim) }}
  {{- else if .Values.rabbitmqExternal.amqpPortStringKey }}
    {{- $_ := set $return "instance" "externalSecret" }}
    {{- $_ := set $return "key" "amqpPortStringKey" }}
    {{- $_ := set $return "value" .Values.rabbitmqExternal.amqpPortStringKey }}
    {{- $_ := set $return "secretName" ( coalesce .Values.rabbitmqExternal.amqpPortStringSecret (include "invenio.rabbitmq.secretName" . | trim)) }}
  {{- else }}
    {{- include "invenio.failingConfig" (dict "root" $root "key" "amqpPortString" "service" "rabbitmq") }} 
  {{- end }}
{{- end -}}
{{- toYaml $return }}
{{- end -}}


{{/*
  This template renders the management port number for RabbitMQ.
*/}}
{{- define "invenio.rabbitmq.managementPortString" -}}
{{- $root := . }}
{{- $return := dict }}
{{- if .Values.rabbitmq.enabled -}}
  {{- if .Values.rabbitmq.service.ports.management }}
    {{- $_ := set $return "instance" "internal" }}
    {{- $_ := set $return "key" "managementPortString" }}
    {{- $_ := set $return "value" .Values.rabbitmq.service.ports.management }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "rabbitmq" "root" $root)) | trim) }}
  {{- else }}
    {{- $_ := set $return "instance" "internal" }}
    {{- $_ := set $return "key" "managementPortString" }}
    {{- $_ := set $return "value" (toString "15672") }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "rabbitmq" "root" $root)) | trim) }}
  {{- end }}
{{- else }}
  {{- if .Values.rabbitmqExternal.managementPortString }}
    {{- $_ := set $return "instance" "external" }}
    {{- $_ := set $return "key" "managementPortString" }}
    {{- $_ := set $return "value" (tpl (toString .Values.rabbitmqExternal.managementPortString) . | toString) }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "rabbitmq" "root" $root)) | trim) }}
  {{- else if .Values.rabbitmqExternal.managementPortStringKey }}
    {{- $_ := set $return "instance" "externalSecret" }}
    {{- $_ := set $return "key" "managementPortStringKey" }}
    {{- $_ := set $return "value" .Values.rabbitmqExternal.managementPortStringKey }}
    {{- $_ := set $return "secretName" ( coalesce .Values.rabbitmqExternal.managementPortStringSecret (include "invenio.rabbitmq.secretName" . | trim)) }}
  {{- else }}
    {{- $_ := set $return "instance" "external" }}
    {{- $_ := set $return "key" "managementPortString" }}
    {{- $_ := set $return "value" (toString "15672") }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "rabbitmq" "root" $root)) | trim) }}
  {{- end }}
{{- end -}}
{{- toYaml $return }}
{{- end -}}


{{/*
  This template renders the hostname for RabbitMQ.
*/}}
{{- define "invenio.rabbitmq.hostname" -}}
{{- $root := . }}
{{- $return := dict }}
{{- if .Values.rabbitmq.enabled -}}
    {{- $_ := set $return "instance" "internal" }}
    {{- $_ := set $return "key" "hostname" }}
    {{- $_ := set $return "value" (printf "%s" (include "common.names.fullname" $root.Subcharts.rabbitmq)) }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "rabbitmq" "root" $root)) | trim) }}
{{- else }}
  {{- if .Values.rabbitmqExternal.hostname }}
    {{- $_ := set $return "instance" "external" }}
    {{- $_ := set $return "key" "hostname" }}
    {{- $_ := set $return "value" .Values.rabbitmqExternal.hostname }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "rabbitmq" "root" $root)) | trim) }}
  {{- else if .Values.rabbitmqExternal.hostnameKey }}
    {{- $_ := set $return "instance" "externalSecret" }}
    {{- $_ := set $return "key" "hostnameKey" }}
    {{- $_ := set $return "value" .Values.rabbitmqExternal.hostnameKey }}
    {{- $_ := set $return "secretName" ( coalesce .Values.rabbitmqExternal.hostnameSecret (include "invenio.rabbitmq.secretName" . | trim)) }}
  {{- else }}
    {{- include "invenio.failingConfig" (dict "root" $root "key" "hostname" "service" "rabbitmq") }} 
  {{- end }}
{{- end -}}
{{- toYaml $return }}
{{- end -}}

{{/*
  This template renders the protocol for RabbitMQ.
*/}}
{{- define "invenio.rabbitmq.protocol" -}}
{{- $root := . }}
{{- $return := dict }}
{{- if .Values.rabbitmq.enabled -}}
    {{- $_ := set $return "instance" "internal" }}
    {{- $_ := set $return "key" "protocol" }}
    {{- $_ := set $return "value" "amqp" }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "rabbitmq" "root" $root)) | trim) }}
{{- else }}
  {{- if .Values.rabbitmqExternal.protocol }}
    {{- $_ := set $return "instance" "external" }}
    {{- $_ := set $return "key" "protocol" }}
    {{- $_ := set $return "value" (tpl (toString .Values.rabbitmqExternal.protocol) . | toString) }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "rabbitmq" "root" $root)) | trim) }}
  {{- else if .Values.rabbitmqExternal.protocolKey }}
    {{- $_ := set $return "instance" "externalSecret" }}
    {{- $_ := set $return "key" "protocolKey" }}
    {{- $_ := set $return "value" .Values.rabbitmqExternal.protocolKey }}
    {{- $_ := set $return "secretName" ( coalesce .Values.rabbitmqExternal.protocolSecret (include "invenio.rabbitmq.secretName" . | trim)) }}
  {{- else }}
    {{- include "invenio.failingConfig" (dict "root" $root "key" "protocol" "service" "rabbitmq") }} 
  {{- end }}
{{- end -}}
{{- toYaml $return }}
{{- end -}}

{{/*
  This template renders the vhost for RabbitMQ.
*/}}
{{- define "invenio.rabbitmq.vhost" -}}
{{- $root := . }}
{{- $return := dict }}
{{- if .Values.rabbitmq.enabled -}}
    {{- $_ := set $return "instance" "internal" }}
    {{- $_ := set $return "key" "vhost" }}
    {{- $_ := set $return "value" "/" }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "rabbitmq" "root" $root)) | trim) }}
{{- else }}
  {{- if .Values.rabbitmqExternal.vhost }}
    {{- $_ := set $return "instance" "external" }}
    {{- $_ := set $return "key" "vhost" }}
    {{- $_ := set $return "value" (tpl (toString .Values.rabbitmqExternal.vhost) . | toString) }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "rabbitmq" "root" $root)) | trim) }}
  {{- else if .Values.rabbitmqExternal.vhostKey }}
    {{- $_ := set $return "instance" "externalSecret" }}
    {{- $_ := set $return "key" "vhostKey" }}
    {{- $_ := set $return "value" .Values.rabbitmqExternal.vhostKey }}
    {{- $_ := set $return "secretName" ( coalesce .Values.rabbitmqExternal.vhostSecret (include "invenio.rabbitmq.secretName" . | trim)) }}
  {{- else }}
    {{- $_ := set $return "instance" "external" }}
    {{- $_ := set $return "key" "vhost" }}
    {{- $_ := set $return "value" "" }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "rabbitmq" "root" $root)) | trim) }}
  {{- end }}
{{- end -}}
{{- toYaml $return }}
{{- end -}}

{{/*
  This template renders the whole URI into one string for RabbitMQ.
*/}}
{{- define "invenio.rabbitmq.uri" -}}
{{- $root := . }}
{{- $return := dict }}
{{- if and (not .Values.rabbitmq.enabled) .Values.rabbitmqExternal.uri }}
    {{- $_ := set $return "instance" "external" }}
    {{- $_ := set $return "key" "uri" }}
    {{- $_ := set $return "value" (tpl (toString .Values.rabbitmqExternal.uri) . | toString) }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "rabbitmq" "root" $root)) | trim) }}
{{- else if and (not .Values.rabbitmq.enabled) .Values.rabbitmqExternal.uriKey }}
    {{- $_ := set $return "instance" "externalSecret" }}
    {{- $_ := set $return "key" "uriKey" }}
    {{- $_ := set $return "value" .Values.rabbitmqExternal.uriKey }}
    {{- $_ := set $return "secretName" ( coalesce .Values.rabbitmqExternal.uriSecret (include "invenio.rabbitmq.secretName" . | trim)) }}
{{- end }}
{{- toYaml $return }}
{{- end -}}

{{/*
  RabbitMQ connection env section.
*/}}
{{- define "invenio.config.queue" -}}
{{- if and (not .Values.rabbitmqExternal.uriKey) (not .Values.rabbitmqExternal.uri) }}
{{- $uri := "$(INVENIO_AMQP_BROKER_PROTOCOL)://$(INVENIO_AMQP_BROKER_USER):$(INVENIO_AMQP_BROKER_PASSWORD)@$(INVENIO_AMQP_BROKER_HOST):$(INVENIO_AMQP_BROKER_PORT)/$(INVENIO_AMQP_BROKER_VHOST)" -}}
{{- include "invenio.svc.renderEnv" (dict "myVal" (include "invenio.rabbitmq.amqpPortString" .) "envName" "INVENIO_AMQP_BROKER_PORT") | trim | nindent 0 }}
{{- include "invenio.svc.renderEnv" (dict "myVal" (include "invenio.rabbitmq.username" .) "envName" "INVENIO_AMQP_BROKER_USER") | trim | nindent 0 }}
{{- include "invenio.svc.renderEnv" (dict "myVal" (include "invenio.rabbitmq.hostname" .) "envName" "INVENIO_AMQP_BROKER_HOST") | trim | nindent 0 }}
{{- include "invenio.svc.renderEnv" (dict "myVal" (include "invenio.rabbitmq.password" .) "envName" "INVENIO_AMQP_BROKER_PASSWORD") | trim | nindent 0 }}
{{- include "invenio.svc.renderEnv" (dict "myVal" (include "invenio.rabbitmq.vhost" .) "envName" "INVENIO_AMQP_BROKER_VHOST") | trim | nindent 0 }}
{{- include "invenio.svc.renderEnv" (dict "myVal" (include "invenio.rabbitmq.protocol" .) "envName" "INVENIO_AMQP_BROKER_PROTOCOL") | trim | nindent 0 }}
{{- include "invenio.svc.renderEnv" (dict "myVal" (include "invenio.rabbitmq.managementPortString" .) "envName" "INVENIO_AMQP_MGMT_PORT") | trim | nindent 0 }}
- name: INVENIO_BROKER_URL
  value: {{ $uri }}
- name: INVENIO_CELERY_BROKER_URL
  value: $(INVENIO_BROKER_URL)
- name: RABBITMQ_API_URI
  value: "http://$(INVENIO_AMQP_BROKER_USER):$(INVENIO_AMQP_BROKER_PASSWORD)@$(INVENIO_AMQP_BROKER_HOST):$(INVENIO_AMQP_BROKER_PORT)/api/"
{{- else }}
{{- include "invenio.svc.renderEnv" (dict "myVal" (include "invenio.rabbitmq.protocol" .) "envName" "INVENIO_BROKER_URL") | trim | nindent 0 }}
{{- include "invenio.svc.renderEnv" (dict "myVal" (include "invenio.rabbitmq.protocol" .) "envName" "INVENIO_CELERY_BROKER_URL") | trim | nindent 0 }}
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
{{- $fields := dict "username" "INVENIO_AMQP_BROKER_USER" "password" "INVENIO_AMQP_BROKER_PASSWORD" "hostname" "INVENIO_AMQP_BROKER_HOST" "amqpPortString" "INVENIO_AMQP_BROKER_PORT" "vhost" "INVENIO_AMQP_BROKER_VHOST" "protocol" "INVENIO_AMQP_BROKER_PROTOCOL" "managementPortString" "INVENIO_AMQP_MGMT_PORT" }}
{{- $root := . }}
- name: rabbitmq-config
  projected:
    sources:
    {{- if and (not .Values.rabbitmq.enabled) (or .Values.rabbitmqExternal.uri .Values.rabbitmqExternal.uriKey) }}
      {{- include "invenio.render.projectedSecret" (dict "myVal" (include "invenio.rabbitmq.uri" $root) "envName" "INVENIO_CELERY_BROKER_URL") | trim | nindent 4 }}
      {{- include "invenio.render.projectedSecret" (dict "myVal" (include "invenio.rabbitmq.uri" $root) "envName" "INVENIO_BROKER_URL") | trim | nindent 4 }}
    {{- else }}
      {{- range $item, $value := $fields }}
        {{- $invenioHelper := (printf "%s%s" "invenio.rabbitmq." $item)  }}
        {{- include "invenio.render.projectedSecret" (dict "myVal" (include $invenioHelper $root) "envName" $value) | trim | nindent 4 }}
      {{- end }}
    {{- end }}
{{- end }}


{{/*
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
*/}}

#########################     OpenSearch  #########################

{{/*
  This template renders the secret name of the OpenSearch instance.
*/}}
{{- define "invenio.opensearch.secretName" -}}
  {{- if .Values.opensearch.enabled }}
    {{- include "opensearch.secretName" .Subcharts.opensearch }}
  {{- else if and (not .Values.opensearch.enabled) .Values.opensearchExternal.existingSecret }}
    {{- required "Missing .Values.opensearchExternal.existingSecret" .Values.opensearchExternal.existingSecret }}
  {{- end }}
{{- end -}}

{{/*
  This template renders the hostname of the OpenSearch instance.
*/}}
{{- define "invenio.opensearch.hostname" -}}
{{- $root := . }} 
{{- $return := dict }}
{{- if .Values.opensearch.enabled -}}
    {{- $_ := set $return "instance" "internal" }}
    {{- $_ := set $return "key" "hostname" }}
    {{- $_ := set $return "value" (printf "%s" (include "opensearch.service.name" $root.Subcharts.opensearch)) }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "opensearch" "root" $root)) | trim) }}
{{- else }}
  {{- if .Values.opensearchExternal.hostname }}
    {{- $_ := set $return "instance" "external" }}
    {{- $_ := set $return "key" "hostname" }} 
    {{- $_ := set $return "value" .Values.opensearchExternal.hostname }} 
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "opensearch" "root" $root)) | trim) }}
  {{- else if .Values.opensearchExternal.hostnameKey }}
    {{- $_ := set $return "instance" "externalSecret" }}
    {{- $_ := set $return "key" "hostnameKey" }}
    {{- $_ := set $return "value" .Values.opensearchExternal.hostnameKey }}
    {{- $_ := set $return "secretName" ( coalesce .Values.opensearchExternal.hostnameSecret (include "invenio.opensearch.secretName" . | trim)) }}
  {{- else }}
    {{- include "invenio.failingConfig" (dict "root" $root "key" "hostname" "service" "opensearch") }}
  {{- end }}
{{- end -}}
{{- toYaml $return }}
{{- end -}}

{{/*
  This template renders the username for accessing Opensearch.
*/}}
{{- define "invenio.opensearch.username" -}}
{{- $root := . }}
{{- $return := dict }}
{{- if .Values.opensearch.enabled -}}
    {{- $_ := set $return "instance" "internal" }}
    {{- $_ := set $return "key" "username" }}
    {{- $_ := set $return "value" ""}}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "opensearch" "root" $root)) | trim) }}
{{- else }}
  {{- if .Values.opensearchExternal.username }}
    {{- $_ := set $return "instance" "external" }}
    {{- $_ := set $return "key" "username" }}
    {{- $_ := set $return "value" .Values.opensearchExternal.username }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "opensearch" "root" $root)) | trim) }}
  {{- else if .Values.opensearchExternal.usernameKey }}
    {{- $_ := set $return "instance" "externalSecret" }}
    {{- $_ := set $return "key" "usernameKey" }}
    {{- $_ := set $return "value" .Values.opensearchExternal.usernameKey }}
    {{- $_ := set $return "secretName" ( coalesce .Values.opensearchExternal.usernameSecret (include "invenio.opensearch.secretName" . | trim)) }}
  {{- else }}
    {{- include "invenio.failingConfig" (dict "root" $root "key" "username" "service" "opensearch") }} 
  {{- end }}
{{- end -}}
{{- toYaml $return }}
{{- end -}}

{{/*
  This template renders the password for accessing Opensearch.
*/}}
{{- define "invenio.opensearch.password" -}}
{{- $root := . }}
{{- $return := dict }}
{{- if and .Values.opensearch.enabled }} 
    {{- $_ := set $return "instance" "internal" }}
    {{- $_ := set $return "key" "password" }}
    {{- $_ := set $return "value" "" }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "opensearch" "root" $root)) | trim) }}
{{- else }} 
  {{- if and .Values.opensearchExternal.password }}
    {{- $_ := set $return "instance" "external" }}
    {{- $_ := set $return "key" "password" }}
    {{- $_ := set $return "value" .Values.opensearchExternal.password }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "opensearch" "root" $root)) | trim) }}
  {{- else if .Values.opensearchExternal.passwordKey }}
    {{- $_ := set $return "instance" "externalSecret" }}
    {{- $_ := set $return "key" "passwordKey" }}
    {{- $_ := set $return "value" .Values.opensearchExternal.passwordKey }}
    {{- $_ := set $return "secretName" ( coalesce .Values.opensearchExternal.passwordSecret (include "invenio.opensearch.secretName" . | trim)) }}
  {{- else }}
    {{- include "invenio.failingConfig" (dict "root" $root "key" "password" "service" "opensearch") }} 
  {{- end -}}
{{- end -}}
{{- toYaml $return }}
{{- end -}}

{{/*
  This template renders the protocol for Opensearch.
*/}}
{{- define "invenio.opensearch.protocol" -}}
{{- $root := . }}
{{- $return := dict }}
{{- if .Values.opensearch.enabled -}}
    {{- $_ := set $return "instance" "internal" }}
    {{- $_ := set $return "key" "protocol" }}
    {{- $_ := set $return "value" "" }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "opensearch" "root" $root)) | trim) }}
{{- else }}
  {{- if .Values.opensearchExternal.protocol }}
    {{- $_ := set $return "instance" "external" }}
    {{- $_ := set $return "key" "protocol" }}
    {{- $_ := set $return "value" (tpl (toString .Values.opensearchExternal.protocol) . | toString) }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "opensearch" "root" $root)) | trim) }}
  {{- else if .Values.opensearchExternal.protocolKey }}
    {{- $_ := set $return "instance" "externalSecret" }}
    {{- $_ := set $return "key" "protocolKey" }}
    {{- $_ := set $return "value" .Values.opensearchExternal.protocolKey }}
    {{- $_ := set $return "secretName" ( coalesce .Values.opensearchExternal.protocolSecret (include "invenio.opensearch.secretName" . | trim)) }}
  {{- else }}
    {{- $_ := set $return "instance" "external" }}
    {{- $_ := set $return "key" "protocol" }}
    {{- $_ := set $return "value" "https" }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "opensearch" "root" $root)) | trim) }}
  {{- end }}
{{- end -}}
{{- toYaml $return }}
{{- end -}}

{{/*
  This template renders the port for Opensearch.
*/}}
{{- define "invenio.opensearch.port" -}}
{{- $root := . }}
{{- $return := dict }}
{{- if .Values.opensearch.enabled -}}
    {{- $_ := set $return "instance" "internal" }}
    {{- $_ := set $return "key" "port" }}
    {{- $_ := set $return "value" "9200" }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "opensearch" "root" $root)) | trim) }}
{{- else }}
  {{- if .Values.opensearchExternal.port }}
    {{- $_ := set $return "instance" "external" }}
    {{- $_ := set $return "key" "port" }}
    {{- $_ := set $return "value" (tpl (toString .Values.opensearchExternal.port) . | toString) }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "opensearch" "root" $root)) | trim) }}
  {{- else if .Values.opensearchExternal.portKey }}
    {{- $_ := set $return "instance" "externalSecret" }}
    {{- $_ := set $return "key" "portKey" }}
    {{- $_ := set $return "value" .Values.opensearchExternal.portKey }}
    {{- $_ := set $return "secretName" ( coalesce .Values.opensearchExternal.portSecret (include "invenio.opensearch.secretName" . | trim)) }}
  {{- else }}
    {{- $_ := set $return "instance" "external" }}
    {{- $_ := set $return "key" "port" }}
    {{- $_ := set $return "value" ("9200" | toString) }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "opensearch" "root" $root)) | trim) }}
  {{- end }}
{{- end -}}
{{- toYaml $return }}
{{- end -}}


{{/*
  This template renders the username for accessing Opensearch.
*/}}
{{- define "invenio.opensearch.useSsl" -}}
{{- $root := . }}
{{- $return := dict }}
{{- if not .Values.opensearch.enabled -}}
  {{- if .Values.opensearchExternal.useSsl }}
    {{- $_ := set $return "instance" "external" }}
    {{- $_ := set $return "key" "useSsl" }}
    {{- $_ := set $return "value" .Values.opensearchExternal.useSsl }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "opensearch" "root" $root)) | trim) }}
  {{- else if .Values.opensearchExternal.useSslKey }}
    {{- $_ := set $return "instance" "externalSecret" }}
    {{- $_ := set $return "key" "useSslKey" }}
    {{- $_ := set $return "value" .Values.opensearchExternal.useSslKey }}
    {{- $_ := set $return "secretName" ( coalesce .Values.opensearchExternal.useSslSecret (include "invenio.opensearch.secretName" . | trim)) }}
  {{- else }}
    {{- $_ := set $return "instance" "external" }}
    {{- $_ := set $return "key" "useSsl" }}
    {{- $_ := set $return "value" (toString "True" ) }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "opensearch" "root" $root)) | trim) }}
  {{- end }}
{{- end -}}
{{- toYaml $return }}
{{- end -}}

{{/*
  This template renders the username for accessing Opensearch.
*/}}
{{- define "invenio.opensearch.verifyCerts" -}}
{{- $root := . }}
{{- $return := dict }}
{{- if not .Values.opensearch.enabled -}}
  {{- if .Values.opensearchExternal.verifyCerts }}
    {{- $_ := set $return "instance" "external" }}
    {{- $_ := set $return "key" "verifyCerts" }}
    {{- $_ := set $return "value" .Values.opensearchExternal.verifyCerts }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "opensearch" "root" $root)) | trim) }}
  {{- else if .Values.opensearchExternal.verifyCertsKey }}
    {{- $_ := set $return "instance" "externalSecret" }}
    {{- $_ := set $return "key" "verifyCertsKey" }}
    {{- $_ := set $return "value" .Values.opensearchExternal.verifyCertsKey }}
    {{- $_ := set $return "secretName" ( coalesce .Values.opensearchExternal.verifyCertsSecret (include "invenio.opensearch.secretName" . | trim)) }}
  {{- else }}
    {{- $_ := set $return "instance" "external" }}
    {{- $_ := set $return "key" "verifyCerts" }}
    {{- $_ := set $return "value" (toString "False" ) }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "opensearch" "root" $root)) | trim) }}
  {{- end }}
{{- end -}}
{{- toYaml $return }}
{{- end -}}

{{/*
  This template renders the username for accessing Opensearch.
*/}}
{{- define "invenio.opensearch.sslAssertHostname" -}}
{{- $root := . }}
{{- $return := dict }}
{{- if not .Values.opensearch.enabled -}}
  {{- if .Values.opensearchExternal.sslAssertHostname }}
    {{- $_ := set $return "instance" "external" }}
    {{- $_ := set $return "key" "sslAssertHostname" }}
    {{- $_ := set $return "value" .Values.opensearchExternal.sslAssertHostname }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "opensearch" "root" $root)) | trim) }}
  {{- else if .Values.opensearchExternal.sslAssertHostnameKey }}
    {{- $_ := set $return "instance" "externalSecret" }}
    {{- $_ := set $return "key" "sslAssertHostnameKey" }}
    {{- $_ := set $return "value" .Values.opensearchExternal.sslAssertHostnameKey }}
    {{- $_ := set $return "secretName" ( coalesce .Values.opensearchExternal.sslAssertHostnameSecret (include "invenio.opensearch.secretName" . | trim)) }}
  {{- else }}
    {{- $_ := set $return "instance" "external" }}
    {{- $_ := set $return "key" "sslAssertHostname" }}
    {{- $_ := set $return "value" (toString "False" ) }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "opensearch" "root" $root)) | trim) }}
  {{- end }}
{{- end -}}
{{- toYaml $return }}
{{- end -}}

{{/*
  This template renders the username for accessing Opensearch.
*/}}
{{- define "invenio.opensearch.sslShowWarn" -}}
{{- $root := . }}
{{- $return := dict }}
{{- if not .Values.opensearch.enabled -}}
  {{- if .Values.opensearchExternal.sslShowWarn }}
    {{- $_ := set $return "instance" "external" }}
    {{- $_ := set $return "key" "sslShowWarn" }}
    {{- $_ := set $return "value" .Values.opensearchExternal.sslShowWarn }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "opensearch" "root" $root)) | trim) }}
  {{- else if .Values.opensearchExternal.sslShowWarnKey }}
    {{- $_ := set $return "instance" "externalSecret" }}
    {{- $_ := set $return "key" "sslShowWarnKey" }}
    {{- $_ := set $return "value" .Values.opensearchExternal.sslShowWarnKey }}
    {{- $_ := set $return "secretName" ( coalesce .Values.opensearchExternal.sslShowWarnSecret (include "invenio.opensearch.secretName" . | trim)) }}
  {{- else }}
    {{- $_ := set $return "instance" "external" }}
    {{- $_ := set $return "key" "sslShowWarn" }}
    {{- $_ := set $return "value" (toString "False" ) }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "opensearch" "root" $root)) | trim) }}
  {{- end }}
{{- end -}}
{{- toYaml $return }}
{{- end -}}

{{/*
  This template renders the username for accessing Opensearch.
*/}}
{{- define "invenio.opensearch.caCerts" -}}
{{- $root := . }}
{{- $return := dict }}
{{- if not .Values.opensearch.enabled -}}
  {{- if .Values.opensearchExternal.caCerts }}
    {{- $_ := set $return "instance" "external" }}
    {{- $_ := set $return "key" "caCerts" }}
    {{- $_ := set $return "value" .Values.opensearchExternal.caCerts }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "opensearch" "root" $root)) | trim) }}
  {{- else if .Values.opensearchExternal.caCertsKey }}
    {{- $_ := set $return "instance" "externalSecret" }}
    {{- $_ := set $return "key" "caCertsKey" }}
    {{- $_ := set $return "value" .Values.opensearchExternal.caCertsKey }}
    {{- $_ := set $return "secretName" ( coalesce .Values.opensearchExternal.caCertsSecret (include "invenio.opensearch.secretName" . | trim)) }}
  {{- else }}
    {{- $_ := set $return "instance" "external" }}
    {{- $_ := set $return "key" "caCerts" }}
    {{- $_ := set $return "value" (toString "None" ) }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "opensearch" "root" $root)) | trim) }}
  {{- end }}
{{- end -}}
{{- toYaml $return }}
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
INVENIO_SEARCH_HOSTS: {{ printf "[{'host': '%s'}]" (include "invenio.opensearch.hostname" .) | quote }}
{{- else }}
{{- include "invenio.svc.renderEnv" (dict "myVal" (include "invenio.opensearch.username" .) "envName" "INVENIO_CONFIG_OPENSEARCH_USER") | trim | nindent 0 }}
{{- include "invenio.svc.renderEnv" (dict "myVal" (include "invenio.opensearch.hostname" .) "envName" "INVENIO_CONFIG_OPENSEARCH_HOST") | trim | nindent 0 }}
{{- include "invenio.svc.renderEnv" (dict "myVal" (include "invenio.opensearch.password" .) "envName" "INVENIO_CONFIG_OPENSEARCH_PASSWORD") | trim | nindent 0 }}
{{- include "invenio.svc.renderEnv" (dict "myVal" (include "invenio.opensearch.protocol" .) "envName" "INVENIO_CONFIG_OPENSEARCH_PROTOCOL") | trim | nindent 0 }}
{{- include "invenio.svc.renderEnv" (dict "myVal" (include "invenio.opensearch.port" .) "envName" "INVENIO_CONFIG_OPENSEARCH_PORT") | trim | nindent 0 }}
{{- include "invenio.svc.renderEnv" (dict "myVal" (include "invenio.opensearch.useSsl" .) "envName" "INVENIO_CONFIG_OPENSEARCH_USE_SSL") | trim | nindent 0 }}
{{- include "invenio.svc.renderEnv" (dict "myVal" (include "invenio.opensearch.verifyCerts" .) "envName" "INVENIO_CONFIG_OPENSEARCH_VERIFY_CERTS") | trim | nindent 0 }}
{{- include "invenio.svc.renderEnv" (dict "myVal" (include "invenio.opensearch.sslAssertHostname" .) "envName" "INVENIO_CONFIG_OPENSEARCH_SSL_ASSERT_HOSTNAME") | trim | nindent 0 }}
{{- include "invenio.svc.renderEnv" (dict "myVal" (include "invenio.opensearch.sslShowWarn" .) "envName" "INVENIO_CONFIG_OPENSEARCH_SSL_SHOW_WARN") | trim | nindent 0 }}
{{- include "invenio.svc.renderEnv" (dict "myVal" (include "invenio.opensearch.caCerts" .) "envName" "INVENIO_CONFIG_OPENSEARCH_CA_CERTS") | trim | nindent 0 }}
{{- $hostname := get (include "invenio.opensearch.hostname" . | fromYaml) "value" }} 
{{- $httpAuth := "" }}
{{- if .Values.opensearchExternal.clientCert }}
{{- $httpAuth = printf "\"client_cert\": \"/configs/client_tls.pem\", \"client_key\": \"/configs/client_key.pem\"" }}
{{- else }}
{{- $httpAuth = printf "\"http_auth\": [\"$(INVENIO_CONFIG_OPENSEARCH_USER)\", \"$(INVENIO_CONFIG_OPENSEARCH_PASSWORD)\"]" }}
{{- end }}
- name: INVENIO_SEARCH_HOSTS
  value: {{ printf "%q" (printf "[{'host': '%s'}]" $hostname) }}
- name: INVENIO_SEARCH_CLIENT_CONFIG
  value: {{ printf "%q" (printf "{\"use_ssl\": $(INVENIO_CONFIG_OPENSEARCH_USE_SSL), \"verify_certs\": $(INVENIO_CONFIG_OPENSEARCH_VERIFY_CERTS), \"ssl_assert_hostname\": $(INVENIO_CONFIG_OPENSEARCH_SSL_ASSERT_HOSTNAME), \"ssl_show_warn\": $(INVENIO_CONFIG_OPENSEARCH_SSL_SHOW_WARN), \"ca_certs\": \"$(INVENIO_CONFIG_OPENSEARCH_CA_CERTS)\", %s}" $httpAuth ) }}

{{- end }}
{{- end }}



#########################     PostgreSQL connection configuration     #########################


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
  {{- if hasKey .Values.postgresql.auth "username" }}
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
{{- if .Values.postgresql.enabled }} 
    {{- $_ := set $return "instance" "internal" }}
    {{- $_ := set $return "key" "password" }}
    {{- $_ := set $return "value" (required "Missing .Values.postgresql.auth.password" (tpl .Values.postgresql.auth.password .)) }}
    {{- $_ := set $return "secretName" ((include "invenio.inline.secretName" (dict "myName" "postgresql" "root" $root)) | trim) }}
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
      {{- include "invenio.render.projectedSecret" (dict "myVal" (include "invenio.postgresql.uri" $root) "envName" "INVENIO_SQLALCHEMY_DATABASE_URI") | trim | nindent 4 }}
    {{- else }}
      {{- range $item, $value := $fields }}
        {{- $invenioHelper := (printf "%s%s" "invenio.postgresql." $item)  }}
        {{- include "invenio.render.projectedSecret" (dict "myVal" (include $invenioHelper $root) "envName" $value) | trim | nindent 4 }}
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
