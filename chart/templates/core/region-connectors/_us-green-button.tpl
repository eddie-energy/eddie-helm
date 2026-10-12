{{/* us-green-button connector environment and volume mappings. */}}
{{- define "eddie.region-connectors.us-green-button.envs" }}
{{- $connectors := include "eddie.componentValues" (dict "root" . "component" "regionConnectors") | fromYaml }}
{{- $greenButtonValues := $connectors.usGreenButton }}
{{- $rcPrefix := "REGION_CONNECTOR_US_GREEN_BUTTON" }}
{{- if eq (toString $greenButtonValues.enabled) "true" }}
- name: {{ $rcPrefix }}_ENABLED
  value: {{ $greenButtonValues.enabled | quote }}
- name: {{ $rcPrefix }}_BASEPATH
  value: {{ $greenButtonValues.basePath | quote }}
- name: {{ $rcPrefix }}_REDIRECT_URI
  value: {{ default (printf "%s/region-connectors/us-green-button/authorization-callback" (include "eddie.publicUrl" .)) $greenButtonValues.redirectUri | quote }}
- name: {{ $rcPrefix }}_WEBHOOK_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "eddie.connectors.secretName" . }}
      key: greenButtonWebhookSecret
- name: {{ $rcPrefix }}_POLLING
  value: {{ $greenButtonValues.polling | quote }}
- name: {{ $rcPrefix }}_TERMINATION_RETRY
  value: {{ $greenButtonValues.termination.retry | quote }}
{{- range $client := $greenButtonValues.clients }}
- name: {{ $rcPrefix }}_CLIENT_IDS_{{ $client.name }}
  valueFrom:
    secretKeyRef:
      name: {{ include "eddie.connectors.secretName" $ }}
      key: greenButton{{ $client.name }}Id
- name: {{ $rcPrefix }}_CLIENT_SECRETS_{{ $client.name }}
  valueFrom:
    secretKeyRef:
      name: {{ include "eddie.connectors.secretName" $ }}
      key: greenButton{{ $client.name }}ClientSecret
- name: {{ $rcPrefix }}_TOKENS_{{ $client.name }}
  valueFrom:
    secretKeyRef:
      name: {{ include "eddie.connectors.secretName" $ }}
      key: greenButton{{ $client.name }}Token
{{- end }}
{{- end }}
{{- end }}
