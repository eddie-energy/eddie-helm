{{/* cds connector environment and volume mappings. */}}
{{- define "eddie.region-connectors.cds.envs" }}
{{- $connectors := include "eddie.componentValues" (dict "root" . "component" "regionConnectors") | fromYaml }}
{{- $cdsValues := $connectors.cds }}
{{- $rcPrefix := "REGION_CONNECTOR_CDS" }}
{{- if eq (toString $cdsValues.enabled) "true" }}
- name: {{ $rcPrefix }}_ENABLED
  value: {{ $cdsValues.enabled | quote }}
- name: {{ $rcPrefix }}_REDIRECT_URL
  value: {{ default (printf "%s/region-connectors/cds/callback" (include "eddie.publicUrl" .)) $cdsValues.redirectUrl | quote }}
- name: {{ $rcPrefix }}_CLIENT_NAME
  value: {{ $cdsValues.clientName | quote }}
- name: {{ $rcPrefix }}_PAR_ENABLED
  value: {{ $cdsValues.par.enabled | quote }}
- name: {{ $rcPrefix }}_RETRY
  value: {{ $cdsValues.retry | quote }}
- name: {{ $rcPrefix }}_POLLING
  value: {{ $cdsValues.polling | quote }}
{{- end }}
{{- end }}
