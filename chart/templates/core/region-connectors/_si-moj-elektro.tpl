{{/* si-moj-elektro connector environment and volume mappings. */}}
{{- define "eddie.region-connectors.si-moj-elektro.envs" }}
{{- $mojValues := .Values.regionConnectors.siMojElektro }}
{{- if eq (toString $mojValues.enabled) "true" }}
- name: REGION_CONNECTOR_SI_MOJ_ELEKTRO_ENABLED
  value: {{ $mojValues.enabled | quote }}
{{- end }}
{{- end }}
