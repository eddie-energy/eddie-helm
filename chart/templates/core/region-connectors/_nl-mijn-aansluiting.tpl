{{/* nl-mijn-aansluiting connector environment and volume mappings. */}}
{{- define "eddie.region-connectors.nl-mijn-aansluiting.volumeMount"}}
{{- $connectors := include "eddie.componentValues" (dict "root" . "component" "regionConnectors") | fromYaml }}
{{- $aansluitingValues := $connectors.nlMijnAansluiting }}
{{- if eq (toString $aansluitingValues.enabled) "true" }}
- name: aansluiting-keystore
  mountPath: /opt/aansluiting-keystore
{{- end }}
{{- end }}

{{- define "eddie.region-connectors.nl-mijn-aansluiting.volume"}}
{{- $connectors := include "eddie.componentValues" (dict "root" . "component" "regionConnectors") | fromYaml }}
{{- $aansluitingValues := $connectors.nlMijnAansluiting }}
{{- if eq (toString $aansluitingValues.enabled) "true" }}
- name: aansluiting-keystore
  secret:
    secretName: {{ $aansluitingValues.keystore.existingSecret }}
{{- end }}
{{- end }}

{{- define "eddie.region-connectors.nl-mijn-aansluiting.envs" }}
{{- $connectors := include "eddie.componentValues" (dict "root" . "component" "regionConnectors") | fromYaml }}
{{- $aansluitingValues := $connectors.nlMijnAansluiting }}
{{- $rcPrefix := "REGION_CONNECTOR_NL_MIJN_AANSLUITING" }}
{{- $keystorePrefix := "SPRING_SSL_BUNDLE_JKS_NL" }}
{{- if eq (toString $aansluitingValues.enabled) "true" }}
- name: {{ $rcPrefix }}_ENABLED
  value: {{ $aansluitingValues.enabled | quote }}
- name: {{ $rcPrefix }}_ISSUER_URL
  value: {{ $aansluitingValues.issuerUrl | quote }}
- name: {{ $rcPrefix }}_REDIRECT_URL
  value: {{ $aansluitingValues.redirectUrl | quote }}
- name: {{ $rcPrefix }}_CONTINUOUS_KEY_ID
  valueFrom:
    secretKeyRef:
      name: {{ include "eddie.connectors.secretName" . }}
      key: mijnAansluitingContinuousKeyId
- name: {{ $rcPrefix }}_CONTINUOUS_CLIENT_ID
  value: {{ $aansluitingValues.continuous.clientId | quote }}
- name: {{ $rcPrefix }}_CONTINUOUS_SCOPE
  value: {{ $aansluitingValues.continuous.scope | quote }}
- name: {{ $rcPrefix }}_CODEBOEK_API
  value: {{ $aansluitingValues.codeboekApi | quote }}
- name: {{ $rcPrefix }}_CODEBOEK_API_TOKEN
  valueFrom:
    secretKeyRef:
      name: {{ include "eddie.connectors.secretName" . }}
      key: mijnAansluitingCodeboekApiToken
- name: {{ $rcPrefix }}_POLLING
  value: {{ $aansluitingValues.polling | quote }}
- name: {{ $keystorePrefix }}_KEYSTORE_LOCATION
  value: "/opt/aansluiting-keystore/aansluiting.jks"
- name: {{ $keystorePrefix }}_KEYSTORE_TYPE
  value: "JKS"
- name: {{ $keystorePrefix }}_KEYSTORE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "eddie.connectors.secretName" . }}
      key: mijnAansluitingKeystorePassword
- name: {{ $keystorePrefix }}_KEY_ALIAS
  valueFrom:
    secretKeyRef:
      name: {{ include "eddie.connectors.secretName" . }}
      key: mijnAansluitingKeyAlias
- name: {{ $keystorePrefix }}_KEY_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "eddie.connectors.secretName" . }}
      key: mijnAansluitingKeyPassword
{{- end }}
{{- end }}
