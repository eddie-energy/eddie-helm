{{/* de-eta connector environment and volume mappings. */}}
{{- define "eddie.region-connectors.de-eta.envs" }}
{{- $connectors := include "eddie.componentValues" (dict "root" . "component" "regionConnectors") | fromYaml }}
{{- $etaValues := $connectors.deEta }}
{{- $rcPrefix := "REGION_CONNECTOR_DE_ETA" }}
{{- if eq (toString $etaValues.enabled) "true" }}
- name: {{ $rcPrefix }}_ENABLED
  value: {{ $etaValues.enabled | quote }}
- name: {{ $rcPrefix }}_ELIGIBLE_PARTY_ID
  value: {{ $etaValues.eligiblePartyId | quote }}
- name: {{ $rcPrefix }}_API_BASE_URL
  value: {{ $etaValues.apiBaseUrl | quote }}
- name: {{ $rcPrefix }}_API_CLIENT_ID
  valueFrom:
    secretKeyRef:
      name: {{ include "eddie.connectors.secretName" . }}
      key: etaApiClientId
- name: {{ $rcPrefix }}_API_CLIENT_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "eddie.connectors.secretName" . }}
      key: etaApiClientSecret
- name: {{ $rcPrefix }}_METERED_DATA_ENDPOINT
  value: {{ $etaValues.meteredDataEndpoint | quote }}
- name: {{ $rcPrefix }}_ACCOUNTING_POINT_ENDPOINT
  value: {{ $etaValues.accountingPointEndpoint | quote }}
- name: {{ $rcPrefix }}_RESPONSE_TIMEOUT_SECONDS
  value: {{ $etaValues.responseTimeoutSeconds | quote }}
- name: {{ $rcPrefix }}_RETRY_MAX_ATTEMPTS
  value: {{ $etaValues.retryMaxAttempts | quote }}
- name: {{ $rcPrefix }}_RETRY_INITIAL_BACKOFF_SECONDS
  value: {{ $etaValues.retryInitialBackoffSeconds | quote }}
- name: {{ $rcPrefix }}_SSL_ENABLED
  value: {{ $etaValues.sslEnabled | quote }}
- name: {{ $rcPrefix }}_SSL_TRUST_ALL
  value: {{ $etaValues.sslTrustAll | quote }}
- name: {{ $rcPrefix }}_POLLING
  value: {{ $etaValues.polling | quote }}
- name: {{ $rcPrefix }}_AUTH_CLIENT_ID
  valueFrom:
    secretKeyRef:
      name: {{ include "eddie.connectors.secretName" . }}
      key: etaAuthClientId
- name: {{ $rcPrefix }}_AUTH_CLIENT_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "eddie.connectors.secretName" . }}
      key: etaAuthClientSecret
- name: {{ $rcPrefix }}_AUTH_TOKEN_URL
  value: {{ $etaValues.auth.tokenUrl | quote }}
- name: {{ $rcPrefix }}_AUTH_AUTHORIZATION_URL
  value: {{ $etaValues.auth.authorizationUrl | quote }}
- name: {{ $rcPrefix }}_AUTH_REDIRECT_URI
  value: {{ default (printf "%s/region-connectors/de-eta/authorization-callback" (include "eddie.publicUrl" .)) $etaValues.auth.redirectUri | quote }}
- name: {{ $rcPrefix }}_AUTH_SCOPE
  value: {{ $etaValues.auth.scope | quote }}
{{- end }}
{{- end }}
