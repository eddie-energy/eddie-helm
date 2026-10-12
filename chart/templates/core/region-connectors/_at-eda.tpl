{{/* at-eda connector environment and volume mappings. */}}
{{- define "eddie.region-connectors.at-eda.envs" }}
{{- $connectors := include "eddie.componentValues" (dict "root" . "component" "regionConnectors") | fromYaml }}
{{- $edaValues := $connectors.ponton }}
{{- $pontonValues := $connectors.ponton }}
{{- $rcPrefix := "REGION_CONNECTOR_AT_EDA" }}
{{- $pontonPrefix := "REGION_CONNECTOR_AT_EDA_PONTON_MESSENGER" }}
{{- if eq (toString $edaValues.enabled) "true" }}
- name: {{ $rcPrefix }}_ENABLED
  value: {{ $edaValues.enabled | quote }}
- name: {{ $rcPrefix }}_ELIGIBLEPARTY_ID
  value: {{ $edaValues.eligiblePartyId | quote }}
- name: {{ $rcPrefix }}_RETRY
  value: {{ $edaValues.retry | quote }}
- name: {{ $pontonPrefix }}_ADAPTER_ID
  value: {{ $pontonValues.adapter.id | quote }}
- name: {{ $pontonPrefix }}_ADAPTER_VERSION
  value: {{ $pontonValues.adapter.version | quote }}
- name: {{ $pontonPrefix }}_HOSTNAME
  value: {{ $pontonValues.hostname | quote }}
- name: {{ $pontonPrefix }}_PORT
  value: {{ $pontonValues.port | quote }}
- name: {{ $pontonPrefix }}_API_ENDPOINT
  value: {{ $pontonValues.apiEndpoint | quote }}
- name: {{ $pontonPrefix }}_FOLDER
  value: {{ $pontonValues.folder | quote }}
- name: {{ $pontonPrefix }}_USERNAME
  valueFrom:
    secretKeyRef:
      name: {{ include "eddie.connectors.secretName" . }}
      key: pontonUsername
- name: {{ $pontonPrefix }}_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "eddie.connectors.secretName" . }}
      key: pontonPassword
- name: {{ $rcPrefix }}_CONSUMPTION_RECORDS_REMOVE_DUPLICATES_ENABLED
  value: {{ $edaValues.consumptionRecordsDuplicatesEnabled | default "false" | quote }}
{{- end }}
{{- end }}
