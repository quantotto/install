{{/*
Expand the name of the chart.
*/}}
{{- define "config.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "config.fullname" -}}
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
{{- define "config.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "config.labels" -}}
helm.sh/chart: {{ include "config.chart" . }}
{{ include "config.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "config.selectorLabels" -}}
app.kubernetes.io/name: {{ include "config.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "config.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "config.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create secret to access docker registry
*/}}
{{- define "imagePullSecret" }}
{{- printf "{\"auths\": {\"%s\": {\"auth\": \"%s\"}}}" .Values.image.pullSecret.repositoryUrl (printf "%s:%s" .Values.image.pullSecret.user .Values.image.pullSecret.password | b64enc) | b64enc }}
{{- end }}

{{/*
Credits: https://medium.com/nuvo-group-tech/move-your-certs-to-helm-4f5f61338aca
Generate certificates
*/}}
{{- define "gen-certs" -}}
{{- $altNames := list .Values.portalFqdn "127.0.0.1" -}}
{{- $ca := genCA ( printf "%s-ca" .Release.Namespace ) 3650 -}}
{{- $cert := genSignedCert .Values.portalFqdn nil $altNames 3650 $ca -}}
tls.crt: {{ $cert.Cert | b64enc }}
tls.key: {{ $cert.Key | b64enc }}
{{- end -}}

{{/*
Generate key pair
*/}}
{{- define "gen-private-key" -}}
{{- $key := genPrivateKey "rsa" -}}
private.key: {{ $key | b64enc | quote }}
{{- end -}}
