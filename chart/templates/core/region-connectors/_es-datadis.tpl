{{/* es-datadis connector environment and volume mappings. */}}
{{- define "eddie.region-connectors.es-datadis.envs" }}
{{- $connectors := include "eddie.componentValues" (dict "root" . "component" "regionConnectors") | fromYaml }}
{{- $datadisValues := $connectors.esDatadis }}
{{- $rcPrefix := "REGION_CONNECTOR_ES_DATADIS" }}
{{- if eq (toString $datadisValues.enabled) "true" }}
- name: {{ $rcPrefix }}_ENABLED
  value: {{ $datadisValues.enabled | quote }}
- name: {{ $rcPrefix }}_USERNAME
  valueFrom:
    secretKeyRef:
      name: {{ include "eddie.connectors.secretName" . }}
      key: datadisUsername
- name: {{ $rcPrefix }}_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "eddie.connectors.secretName" . }}
      key: datadisPassword
- name: {{ $rcPrefix }}_POLLING
  value: {{ $datadisValues.polling | quote }}
- name: {{ $rcPrefix }}_RETRY
  value: {{ $datadisValues.retry | quote }}
- name: {{ $rcPrefix }}_BASEPATH
  value: {{ $datadisValues.basePath | quote }}
{{- end }}
{{- end }}
