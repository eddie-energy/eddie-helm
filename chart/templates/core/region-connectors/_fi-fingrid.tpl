{{/* fi-fingrid connector environment and volume mappings. */}}
{{- define "eddie.region-connectors.fi-fingrid.volumeMount"}}
{{- $connectors := include "eddie.componentValues" (dict "root" . "component" "regionConnectors") | fromYaml }}
{{- $fingridValues := $connectors.fiFingrid }}
{{- if eq (toString $fingridValues.enabled) "true" }}
- name: fingrid-keystore
  mountPath: /opt/fingrid-keystore
{{- end }}
{{- end }}

{{- define "eddie.region-connectors.fi-fingrid.volume"}}
{{- $connectors := include "eddie.componentValues" (dict "root" . "component" "regionConnectors") | fromYaml }}
{{- $fingridValues := $connectors.fiFingrid }}
{{- if eq (toString $fingridValues.enabled) "true" }}
- name: fingrid-keystore
  secret:
    secretName: {{ $fingridValues.keystore.existingSecret }}
{{- end }}
{{- end }}

{{- define "eddie.region-connectors.fi-fingrid.envs" }}
{{- $connectors := include "eddie.componentValues" (dict "root" . "component" "regionConnectors") | fromYaml }}
{{- $fingridValues := $connectors.fiFingrid }}
{{- $rcPrefix := "REGION_CONNECTOR_FI_FINGRID" }}
{{- $keystorePrefix := "SPRING_SSL_BUNDLE_JKS_FINGRID" }}
{{- if eq (toString $fingridValues.enabled) "true" }}
- name: {{ $rcPrefix }}_ENABLED
  value: {{ $fingridValues.enabled | quote }}
- name: {{ $rcPrefix }}_API_URL
  value: {{ $fingridValues.apiUrl | quote }}
- name: {{ $rcPrefix }}_ORGANISATION_USER
  valueFrom:
    secretKeyRef:
      name: {{ include "eddie.connectors.secretName" . }}
      key: fingridOrganisationUser
- name: {{ $rcPrefix }}_ORGANISATION_NAME
  value: {{ $fingridValues.organisation.name | quote }}
- name: {{ $rcPrefix }}_POLLING
  value: {{ $fingridValues.polling | quote }}
- name: {{ $keystorePrefix }}_KEYSTORE_LOCATION
  value: "/opt/fingrid-keystore/fingrid.jks"
- name: {{ $keystorePrefix }}_KEYSTORE_TYPE
  value: "JKS"
- name: {{ $keystorePrefix }}_KEYSTORE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "eddie.connectors.secretName" . }}
      key: fingridKeystorePassword
- name: {{ $keystorePrefix }}_KEY_ALIAS
  valueFrom:
    secretKeyRef:
      name: {{ include "eddie.connectors.secretName" . }}
      key: fingridKeyAlias
- name: {{ $keystorePrefix }}_KEY_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "eddie.connectors.secretName" . }}
      key: fingridKeyPassword
{{- end }}
{{- end }}
