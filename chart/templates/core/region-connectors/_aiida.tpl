{{/* aiida connector environment and volume mappings. */}}
{{- define "eddie.region-connectors.aiida.envs" }}
{{- $rcPrefix := "REGION_CONNECTOR_AIIDA" }}
{{- $aiidaValues := .Values.regionConnectors.aiida }}
{{- $defaultMqttUri := printf "tcp://%s:1883" (include "eddie.mqtt.serviceName" .) }}
{{- if eq (toString $aiidaValues.enabled) "true" }}
- name: {{ $rcPrefix }}_ENABLED
  value: {{ $aiidaValues.enabled | quote }}
- name: {{ $rcPrefix }}_CUSTOMER_ID
  value: {{ $aiidaValues.customer.id | quote }}
- name: {{ $rcPrefix }}_BCRYPT_STRENGTH
  value: {{ $aiidaValues.bcrypt.strength | quote }}
- name: {{ $rcPrefix }}_MQTT_SERVER_URI
  value: {{ default $defaultMqttUri $aiidaValues.mqtt.server.uri | quote }}
- name: {{ $rcPrefix }}_MQTT_USERNAME
  value: {{ $aiidaValues.mqtt.username | quote }}
- name: {{ $rcPrefix }}_MQTT_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "eddie.mqtt.secretName" . }}
      key: mqttPassword
{{- end }}
{{- end }}
