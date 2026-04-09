{{/*
Expand the name of the chart.
*/}}
{{- define "tekmetric-backend.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
Truncated to 63 chars because some K8s name fields are limited to this.
*/}}
{{- define "tekmetric-backend.fullname" -}}
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
{{- define "tekmetric-backend.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Standard Kubernetes recommended labels.
*/}}
{{- define "tekmetric-backend.labels" -}}
helm.sh/chart: {{ include "tekmetric-backend.chart" . }}
{{ include "tekmetric-backend.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: backend
app.kubernetes.io/part-of: tekmetric
tekmetric.com/environment: {{ .Values.environment.name | quote }}
tekmetric.com/team: sre
{{- end }}

{{/*
Selector labels — used by both the Deployment and the Service.
Must NOT change between upgrades or selectors will break.
*/}}
{{- define "tekmetric-backend.selectorLabels" -}}
app.kubernetes.io/name: {{ include "tekmetric-backend.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Container image — use digest if provided, otherwise tag.
*/}}
{{- define "tekmetric-backend.image" -}}
{{- if .Values.image.digest -}}
{{ .Values.image.repository }}@{{ .Values.image.digest }}
{{- else -}}
{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}
{{- end -}}
{{- end }}

{{/*
Service account name.
*/}}
{{- define "tekmetric-backend.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "tekmetric-backend.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
