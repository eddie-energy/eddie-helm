{{- define "eddie.podScheduling" }}
{{- with .nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .affinity }}
affinity:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .topologySpreadConstraints }}
topologySpreadConstraints:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}

{{- define "eddie.probes" }}
{{- range $key := list "startupProbe" "readinessProbe" "livenessProbe" }}
{{- with index $ $key }}
{{ $key }}:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}
{{- end }}

{{/* Keep the public min/max values interface; render native Kubernetes resources. */}}
{{- define "eddie.resources" }}
requests:
  memory: {{ .memory.min | quote }}
  cpu: {{ .cpu.min | quote }}
  ephemeral-storage: {{ .ephemeralStorage.min | quote }}
limits:
  memory: {{ .memory.max | quote }}
  cpu: {{ .cpu.max | quote }}
  ephemeral-storage: {{ .ephemeralStorage.max | quote }}
{{- end }}
