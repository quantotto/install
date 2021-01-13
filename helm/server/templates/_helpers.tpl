{{/*
Expand the name of the chart.
*/}}
{{- define "quantotto.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "quantotto.fullname" -}}
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
{{- define "quantotto.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "quantotto.labels" -}}
helm.sh/chart: {{ include "quantotto.chart" . }}
{{ include "quantotto.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "quantotto.selectorLabels" -}}
app.kubernetes.io/name: {{ include "quantotto.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "quantotto.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "quantotto.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}


{{/*
Build service FQDN
*/}}
{{- define "quantotto.serviceFQDN" -}}
{{- printf "%s.%s.svc.%s" .serviceName .root.Release.Namespace .root.clusterDomain }}
{{- end }}

{{/*
Build Postgres DSN for Hydra
*/}}
{{- define "quantotto.hydraDSN" -}}
{{- with .Values.qdb }}
{{- printf "postgres://%s:%s@qdb:%d/hydra?sslmode=disable" .qdb.user .qdb.password .service.port }}
{{- end }}
{{- end }}