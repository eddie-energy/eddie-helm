{{/* dk-energinet connector environment and volume mappings. */}}
{{- define "eddie.region-connectors.dk-energinet.envs" }}
{{- $connectors := include "eddie.componentValues" (dict "root" . "component" "regionConnectors") | fromYaml }}
{{- $rcPrefix := "REGION_CONNECTOR_DK_ENERGINET" }}
{{- $energinetValues := $connectors.dkEnerginet }}
{{- if eq (toString $energinetValues.enabled) "true" }}
- name: {{ $rcPrefix }}_ENABLED
  value: {{ $energinetValues.enabled | quote }}
- name: {{ $rcPrefix }}_CUSTOMER_CLIENT_BASEPATH
  value: {{ $energinetValues.customer.client.basePath | quote }}
- name: {{ $rcPrefix }}_POLLING
  value: {{ $energinetValues.polling | quote }}
- name: {{ $rcPrefix }}_RETRY
  value: {{ $energinetValues.retry | quote }}
{{- end }}
{{- end }}
