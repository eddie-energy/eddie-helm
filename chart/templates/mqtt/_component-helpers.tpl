{{/* mqtt component helpers. */}}
{{- define "eddie.mqtt.labels" }}
labels:
  app: {{ .Release.Name }}-mqtt
{{- include "eddie.labels" . }}
{{- end }}

{{- define "eddie.mqtt.broker" -}}
{{- $broker := default "mosquitto" .Values.mqtt.broker -}}
{{- if not (has $broker (list "mosquitto" "hivemq")) -}}
{{- fail (printf "mqtt.broker must be mosquitto or hivemq; got %q" $broker) -}}
{{- end -}}
{{- $broker -}}
{{- end -}}

{{- define "eddie.mqtt.serviceName" -}}
{{ .Release.Name }}-mqtt
{{- end -}}

{{- define "eddie.mqtt.externalTlsSecretName" -}}
{{- default (include "eddie.ingress.tlsSecretName" .) .Values.mqtt.externalAccess.tls.existingSecret -}}
{{- end -}}

{{/* Public TLS is inactive until external access is enabled. */}}
{{- define "eddie.mqtt.externalTlsEnabled" -}}
{{- and (eq (toString .Values.mqtt.externalAccess.enabled) "true") (eq (toString .Values.mqtt.externalAccess.tls.enabled) "true") -}}
{{- end -}}

{{- define "eddie.mqtt.secretName" -}}
{{ default (printf "%s-%s-secret" .Release.Name (include "eddie.mqtt.broker" .)) .Values.mqtt.existingSecret }}
{{- end -}}

{{/* The core client and the broker's local account share one username. */}}
{{- define "eddie.mqtt.localUsername" -}}
{{- $username := required "regionConnectors.aiida.mqtt.username is required for the broker's local account" .Values.regionConnectors.aiida.mqtt.username -}}
{{- if regexMatch "[:\\r\\n]" $username -}}
{{- fail "regionConnectors.aiida.mqtt.username must not contain colons or line breaks" -}}
{{- end -}}
{{- $username -}}
{{- end -}}

{{/* Registry credentials apply to the selected MQTT broker. */}}
{{- define "eddie.mqtt.imagePullSecrets" }}
{{- $mqtt := include "eddie.componentValues" (dict "root" . "component" "mqtt") | fromYaml }}
{{- with $mqtt.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}

{{/* Null means use defaults; an empty object explicitly disables that probe. */}}
{{- define "eddie.mqtt.probes" }}
{{- $defaults := fromYaml `startupProbe:
  tcpSocket:
    port: mqtt
  failureThreshold: 60
  periodSeconds: 5
readinessProbe:
  tcpSocket:
    port: mqtt
  periodSeconds: 10
livenessProbe:
  tcpSocket:
    port: mqtt
  periodSeconds: 20
` }}
{{- range $key := list "startupProbe" "readinessProbe" "livenessProbe" }}
  {{- if ne (index $ $key) nil }}
    {{- $_ := set $defaults $key (index $ $key) }}
  {{- end }}
{{- end }}
{{- include "eddie.probes" $defaults }}
{{- end }}

{{/* User overrides merge over the selected broker's container security defaults. */}}
{{- define "eddie.mqtt.securityContext" }}
{{- $mqtt := include "eddie.componentValues" (dict "root" . "component" "mqtt") | fromYaml }}
{{- $dropCapability := "NET_RAW" }}
{{- if eq (include "eddie.mqtt.broker" .) "hivemq" }}
  {{- $dropCapability = "ALL" }}
{{- end }}
{{- $defaults := dict
  "allowPrivilegeEscalation" false
  "capabilities" (dict "drop" (list $dropCapability))
  "seccompProfile" (dict "type" "RuntimeDefault")
}}
{{- toYaml (mergeOverwrite $defaults ($mqtt.securityContext | default dict)) }}
{{- end }}
