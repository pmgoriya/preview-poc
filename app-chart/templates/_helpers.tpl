{{- define "preview-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "preview-app.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{- define "preview-app.labels" -}}
app.kubernetes.io/name: {{ include "preview-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "preview-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "preview-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
