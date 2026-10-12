{{/* Shared labels, public URLs, and release-scoped resource names. */}}
{{- define "eddie.core.labels" }}
labels:
  app: {{ .Release.Name }}-core
{{- include "eddie.labels" . }}
{{- end }}

{{- define "eddie.hivemq.labels" }}
labels:
  app: {{ .Release.Name }}-hivemq
{{- include "eddie.labels" . }}
{{- end }}

{{- define "eddie.mosquitto.labels" }}
labels:
  app: {{ .Release.Name }}-mosquitto
{{- include "eddie.labels" . }}
{{- end }}

{{- define "eddie.publicHost" -}}
{{- default .Values.global.host .Values.ingress.host -}}
{{- end -}}

{{- define "eddie.publicUrl" -}}
{{- if eq (toString .Values.ingress.tls.enabled) "true" }}https{{ else }}http{{ end }}://{{ include "eddie.publicHost" . }}{{ if .Values.ingress.basePath }}/{{ .Values.ingress.basePath }}{{ end }}/eddie
{{- end -}}

{{- define "eddie.publicOrigin" -}}
{{- if eq (toString .Values.ingress.tls.enabled) "true" }}https{{ else }}http{{ end }}://{{ include "eddie.publicHost" . }}
{{- end -}}

{{- define "eddie.contextPath" -}}
{{- if .Values.ingress.basePath }}/{{ .Values.ingress.basePath }}{{ end }}/eddie
{{- end -}}

{{- define "eddie.externalIP" -}}
{{- .Values.global.externalIP -}}
{{- end -}}

{{- define "eddie.eddieId" -}}
{{- default "eddie" .Values.global.eddieId -}}
{{- end -}}

{{- define "eddie.labels" }}
  app.kubernetes.io/name: {{ .Chart.Name | quote }}
  app.kubernetes.io/instance: {{ .Release.Name | quote }}
  app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
  app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
  helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | quote }}
{{- end }}

{{- define "eddie.resourceName" -}}
{{- $name := printf "%s-%s" .root.Release.Name .suffix | lower | replace "_" "-" | replace "." "-" -}}
{{- if gt (len $name) 63 -}}
{{- printf "%s-%s" ($name | trunc 54 | trimSuffix "-") (sha256sum $name | trunc 8) -}}
{{- else -}}{{ $name }}{{- end -}}
{{- end -}}

{{- define "eddie.dataNeeds.configMapName" -}}
{{- if .Values.core.dataNeedsConfig.existingConfigMap -}}
{{ .Values.core.dataNeedsConfig.existingConfigMap }}
{{- else -}}
{{ include "eddie.resourceName" (dict "root" . "suffix" "data-needs") }}
{{- end -}}
{{- end -}}

{{- define "eddie.core.secretName" -}}
{{ default (printf "%s-core-secret" .Release.Name) .Values.core.existingSecret }}
{{- end -}}
{{- define "eddie.connectors.secretName" -}}
{{ default (printf "%s-region-connector-secrets" .Release.Name) .Values.regionConnectors.existingSecret }}
{{- end -}}
{{- define "eddie.auth.secretName" -}}
{{ default (printf "%s-management-basic-auth" .Release.Name) .Values.core.auth.existingSecret }}
{{- end -}}

{{/* Resolve advanced component defaults without changing the shared .Values object. */}}
{{- define "eddie.componentValues" -}}
{{- $defaults := index (.root.Files.Get "values-advanced.yaml" | fromYaml) .component | default dict -}}
{{- $overrides := index .root.Values .component | default dict -}}
{{- $resolved := mergeOverwrite $defaults (deepCopy $overrides) -}}
{{- /* Probes have exactly one handler. An override replaces the whole probe; {} disables it. */ -}}
{{- range $probe := list "startupProbe" "readinessProbe" "livenessProbe" -}}
{{- if hasKey $overrides $probe -}}
{{- $_ := set $resolved $probe (index $overrides $probe) -}}
{{- end -}}
{{- end -}}
{{- $resolved | toYaml -}}
{{- end -}}
