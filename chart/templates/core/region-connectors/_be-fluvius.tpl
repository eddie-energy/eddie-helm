{{/* be-fluvius connector environment and volume mappings. */}}
{{- define "eddie.region-connectors.be-fluvius.volumeMount"}}
{{- $connectors := include "eddie.componentValues" (dict "root" . "component" "regionConnectors") | fromYaml }}
{{- $fluviusValues := $connectors.beFluvius }}
{{- $tlsSecretName := $fluviusValues.tls.existingSecret }}
{{- if and (eq (toString $fluviusValues.enabled) "true") $tlsSecretName }}
- name: fluvius-tls
  mountPath: /opt/fluvius-tls
  readOnly: true
{{- end }}
{{- end }}

{{- define "eddie.region-connectors.be-fluvius.volume"}}
{{- $connectors := include "eddie.componentValues" (dict "root" . "component" "regionConnectors") | fromYaml }}
{{- $fluviusValues := $connectors.beFluvius }}
{{- $tlsSecretName := $fluviusValues.tls.existingSecret }}
{{- if and (eq (toString $fluviusValues.enabled) "true") $tlsSecretName }}
- name: fluvius-tls
  secret:
    secretName: {{ $tlsSecretName }}
{{- end }}
{{- end }}

{{- define "eddie.region-connectors.be-fluvius.envs" }}
{{- $connectors := include "eddie.componentValues" (dict "root" . "component" "regionConnectors") | fromYaml }}
{{- $fluviusValues := $connectors.beFluvius }}
{{- $tlsSecretName := $fluviusValues.tls.existingSecret }}
{{- $rcPrefix := "REGION_CONNECTOR_BE_FLUVIUS" }}
{{- if eq (toString $fluviusValues.enabled) "true" }}
- name: {{ $rcPrefix }}_ENABLED
  value: {{ $fluviusValues.enabled | quote }}
- name: {{ $rcPrefix }}_BASE_URL
  value: {{ $fluviusValues.baseUrl | quote }}
- name: {{ $rcPrefix }}_OAUTH_TOKEN_URL
  value: {{ default (printf "https://login.microsoftonline.com/%s/oauth2/V2.0/token" $fluviusValues.oauth.tenantId) $fluviusValues.oauth.tokenUrl | quote }}
- name: {{ $rcPrefix }}_OAUTH_CLIENT_ID
  valueFrom:
    secretKeyRef:
      name: {{ include "eddie.connectors.secretName" . }}
      key: fluviusOAuthClientId
- name: {{ $rcPrefix }}_OAUTH_TENANT_ID
  value: {{ $fluviusValues.oauth.tenantId | quote }}
- name: {{ $rcPrefix }}_OAUTH_CLIENT_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "eddie.connectors.secretName" . }}
      key: fluviusOAuthClientSecret
- name: {{ $rcPrefix }}_OAUTH_SCOPE
  value: {{ $fluviusValues.oauth.scope | quote }}
- name: {{ $rcPrefix }}_SUBSCRIPTION_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "eddie.connectors.secretName" . }}
      key: fluviusSubscriptionKey
- name: {{ $rcPrefix }}_CONTRACT_NUMBER
  value: {{ $fluviusValues.contractNumber | quote }}
- name: {{ $rcPrefix }}_MOCK_MANDATES
  value: {{ $fluviusValues.mockMandates | quote }}
- name: {{ $rcPrefix }}_REDIRECT_URI
  value: {{ default (include "eddie.publicUrl" .) $fluviusValues.redirectUri | quote }}
- name: {{ $rcPrefix }}_RETRY
  value: {{ $fluviusValues.retry | quote }}
- name: {{ $rcPrefix }}_CHECK_ACCEPTANCE
  value: {{ $fluviusValues.checkAcceptance | quote }}
- name: {{ $rcPrefix }}_POLLING
  value: {{ $fluviusValues.polling | quote }}
{{- if $tlsSecretName }}
- name: SPRING_SSL_BUNDLE_PEM_FLUVIUS_KEYSTORE_CERTIFICATE
  value: "/opt/fluvius-tls/{{ $fluviusValues.tls.certificateFile }}"
- name: SPRING_SSL_BUNDLE_PEM_FLUVIUS_KEYSTORE_PRIVATE_KEY
  value: "/opt/fluvius-tls/{{ $fluviusValues.tls.privateKeyFile }}"
{{- end }}
{{- end }}
{{- end }}
