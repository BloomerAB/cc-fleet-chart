{{/*
Expand the name of the chart.
*/}}
{{- define "cc-fleet.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fullname with release name.
*/}}
{{- define "cc-fleet.fullname" -}}
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
{{- define "cc-fleet.labels" -}}
helm.sh/chart: {{ include "cc-fleet.name" . }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: cc-fleet
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}

{{/*
Session Manager selector labels.
*/}}
{{- define "cc-fleet.sessionManager.selectorLabels" -}}
app.kubernetes.io/name: session-manager
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
CORS origin - defaults to https://<ingress host>
*/}}
{{- define "cc-fleet.corsOrigin" -}}
{{- if .Values.corsOrigin }}
{{- .Values.corsOrigin }}
{{- else if .Values.ingress.enabled }}
{{- printf "https://%s" .Values.ingress.host }}
{{- else if .Values.ingressRoute.enabled }}
{{- printf "https://%s" .Values.ingressRoute.host }}
{{- else }}
{{- "http://localhost:3000" }}
{{- end }}
{{- end }}

{{/*
ScyllaDB host — uses built-in service when scylla.enabled, otherwise user-provided host.
*/}}
{{- define "cc-fleet.scyllaHost" -}}
{{- if .Values.scylla.enabled }}
{{- printf "%s-scylla" (include "cc-fleet.fullname" .) }}
{{- else if .Values.scylla.host }}
{{- .Values.scylla.host }}
{{- else }}
{{- "localhost" }}
{{- end }}
{{- end }}

