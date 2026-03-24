{{/*
Expand the name of the chart.
*/}}
{{- define "claude-platform.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fullname with release name.
*/}}
{{- define "claude-platform.fullname" -}}
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
Common labels.
*/}}
{{- define "claude-platform.labels" -}}
helm.sh/chart: {{ include "claude-platform.name" . }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: claude-platform
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}

{{/*
Session Manager selector labels.
*/}}
{{- define "claude-platform.sessionManager.selectorLabels" -}}
app.kubernetes.io/name: session-manager
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
CORS origin - defaults to https://<ingress host>
*/}}
{{- define "claude-platform.corsOrigin" -}}
{{- if .Values.corsOrigin }}
{{- .Values.corsOrigin }}
{{- else if .Values.ingress.enabled }}
{{- printf "https://%s" .Values.ingress.host }}
{{- else if .Values.ingressRoute.enabled }}
{{- printf "https://%s" .Values.ingressRoute.host }}
{{- else }}
{{- "http://localhost:5173" }}
{{- end }}
{{- end }}

{{/*
Session Manager internal service URL for runner pods.
*/}}
{{- define "claude-platform.sessionManager.wsUrl" -}}
{{- printf "ws://%s-session-manager.%s.svc.cluster.local:3000/ws/runner" (include "claude-platform.fullname" .) .Release.Namespace }}
{{- end }}
