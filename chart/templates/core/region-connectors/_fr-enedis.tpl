{{/* fr-enedis connector environment and volume mappings. */}}
{{- define "eddie.region-connectors.fr-enedis.envs" }}
{{- $connectors := include "eddie.componentValues" (dict "root" . "component" "regionConnectors") | fromYaml }}
{{- $enedisValues := $connectors.frEnedis }}
{{- $rcPrefix := "REGION_CONNECTOR_FR_ENEDIS" }}
{{- if eq (toString $enedisValues.enabled) "true" }}
- name: {{ $rcPrefix }}_ENABLED
  value: {{ $enedisValues.enabled | quote }}
- name: {{ $rcPrefix }}_BASEPATH
  value: {{ $enedisValues.basePath | quote }}
- name: {{ $rcPrefix }}_CLIENT_ID
  valueFrom:
    secretKeyRef:
      name: {{ include "eddie.connectors.secretName" . }}
      key: enedisClientId
- name: {{ $rcPrefix }}_CLIENT_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "eddie.connectors.secretName" . }}
      key: enedisClientSecret
- name: {{ $rcPrefix }}_POLLING
  value: {{ $enedisValues.polling | quote }}
{{- end }}
{{- end }}
