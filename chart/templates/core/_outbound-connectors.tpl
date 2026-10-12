{{/* Environment blocks for EDDIE's outbound connectors and management API. */}}

{{- define "eddie.outbound-connectors.admin-console.envs" }}
{{- $adminConsoleValues := .Values.outboundConnectors.adminConsole }}
{{- $ocPrefix := "OUTBOUND_CONNECTOR_ADMIN_CONSOLE" }}
- name: {{ $ocPrefix }}_ENABLED
  value: {{ $adminConsoleValues.enabled | quote }}
{{- if eq (toString $adminConsoleValues.login.enabled) "true" }}
- name: {{ $ocPrefix }}_LOGIN_MODE
  value: {{ $adminConsoleValues.login.mode | quote }}
  {{- if eq $adminConsoleValues.login.mode "basic" }}
- name: {{ $ocPrefix }}_LOGIN_USERNAME
  value: {{ $adminConsoleValues.login.username | quote }}
- name: {{ $ocPrefix }}_LOGIN_ENCODED_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "eddie.core.secretName" . }}
      key: adminConsolePassword
  {{- end }}
  {{- if eq $adminConsoleValues.login.mode "keycloak" }}
- name: {{ $ocPrefix }}_LOGIN_KEYCLOAK_CLIENT_ID
  value: {{ required "outboundConnectors.adminConsole.login.keycloakClientID is required for Keycloak login" $adminConsoleValues.login.keycloakClientID | quote }}
- name: {{ $ocPrefix }}_LOGIN_KEYCLOAK_CLIENT_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "eddie.core.secretName" . }}
      key: keycloakClientSecret
- name: {{ $ocPrefix }}_LOGIN_KEYCLOAK_ISSUER_URI
  value: {{ required "outboundConnectors.adminConsole.login.keycloakIssuerURI is required for Keycloak login" $adminConsoleValues.login.keycloakIssuerURI | quote }}
{{- end }}
{{- end }}
{{- end }}

{{- define "eddie.outbound-connectors.amqp.envs" }}
{{- $amqpValues := .Values.outboundConnectors.amqp }}
- name: OUTBOUND_CONNECTOR_AMQP_ENABLED
  value: {{ $amqpValues.enabled | quote }}
{{- if eq (toString $amqpValues.enabled) "true" }}
- name: OUTBOUND_CONNECTOR_AMQP_FORMAT
  value: {{ $amqpValues.format | quote }}
- name: OUTBOUND_CONNECTOR_AMQP_URI
  valueFrom:
    secretKeyRef:
      name: {{ include "eddie.core.secretName" . }}
      key: amqpUri
- name: OUTBOUND_CONNECTOR_AMQP_EDDIE_ID
  value: {{ default (include "eddie.eddieId" .) $amqpValues.eddieId | quote }}
{{- end }}
{{- end }}

{{- define "eddie.outbound-connectors.kafka.envs" }}
{{- $kafkaValues := .Values.outboundConnectors.kafka }}
- name: OUTBOUND_CONNECTOR_KAFKA_ENABLED
  value: {{ $kafkaValues.enabled | quote }}
{{- if eq (toString $kafkaValues.enabled) "true" }}
- name: OUTBOUND_CONNECTOR_KAFKA_FORMAT
  value: {{ $kafkaValues.format | quote }}
- name: OUTBOUND_CONNECTOR_KAFKA_EDDIE_ID
  value: {{ default (include "eddie.eddieId" .) $kafkaValues.eddieId | quote }}
- name: KAFKA_USER
  value: {{ include "eddie.kafka.coreUserName" . | quote }}
- name: KAFKA_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "eddie.kafka.coreUserName" . }}
      key: password
- name: KAFKA_BOOTSTRAP_SERVERS
  value: "{{ include "eddie.kafka.strimzi.clusterName" . }}-kafka-bootstrap:9094"
- name: KAFKA_SECURITY_PROTOCOL
  value: "SASL_PLAINTEXT"
- name: KAFKA_SASL_MECHANISM
  value: "SCRAM-SHA-512"
- name: KAFKA_SASL_JAAS_CONFIG
  value: "org.apache.kafka.common.security.scram.ScramLoginModule required username='$(KAFKA_USER)' password='$(KAFKA_PASSWORD)';"
{{- range $name, $value := $kafkaValues.properties }}
- name: {{ printf "KAFKA_%s" (regexReplaceAll "[^A-Za-z0-9]" $name "_" | upper) }}
  value: {{ $value | quote }}
{{- end }}
{{- end }}
{{- end }}

{{- define "eddie.outbound-connectors.management.envs" }}
- name: EDDIE_MANAGEMENT_URL
  value: "{{ include "eddie.publicUrl" . }}"
- name: EDDIE_MANAGEMENT_SERVER_URLPREFIX
  value: {{ include "eddie.management.urlPrefix" . | quote }}
{{- end }}

{{- define "eddie.outbound-connectors.metric.envs" }}
{{- $metricValues := .Values.outboundConnectors.metric }}
- name: OUTBOUND_CONNECTOR_METRIC_ENABLED
  value: {{ $metricValues.enabled | quote }}
{{- if eq (toString $metricValues.enabled) "true" }}
- name: OUTBOUND_CONNECTOR_METRIC_EDDIE_ID
  value: {{ default (include "eddie.eddieId" .) $metricValues.eddieId | quote }}
- name: OUTBOUND_CONNECTOR_METRIC_INTERVAL
  value: {{ $metricValues.interval | quote }}
- name: OUTBOUND_CONNECTOR_METRIC_ENDPOINT
  value: {{ required "outboundConnectors.metric.endpoint is required when outboundConnectors.metric.enabled is true" $metricValues.endpoint | quote }}
{{- end }}
{{- end }}

{{- define "eddie.outbound-connectors.rest.envs" }}
{{- $restValues := .Values.outboundConnectors.rest }}
- name: OUTBOUND_CONNECTOR_REST_ENABLED
  value: {{ $restValues.enabled | quote }}
{{- if eq (toString $restValues.enabled) "true" }}
- name: OUTBOUND_CONNECTOR_REST_RETENTION_TIME
  value: {{ $restValues.retentionTime | quote }}
- name: OUTBOUND_CONNECTOR_REST_RETENTION_REMOVAL
  value: {{ $restValues.retentionRemoval | quote }}
- name: OUTBOUND_CONNECTOR_REST_OAUTH2_ENABLED
  value: {{ $restValues.oauth2.enabled | quote }}
{{- if eq (toString $restValues.oauth2.enabled) "true" }}
- name: OUTBOUND_CONNECTOR_REST_OAUTH2_ISSUER_URL
  value: {{ required "outboundConnectors.rest.oauth2.issuerUrl is required when outboundConnectors.rest.oauth2.enabled is true" $restValues.oauth2.issuerUrl | quote }}
- name: OUTBOUND_CONNECTOR_REST_OAUTH2_SCOPES_ENABLED
  value: {{ $restValues.oauth2.scopes.enabled | quote }}
{{- end }}
{{- end }}
{{- end }}
