{{/* kafka component helpers. */}}
{{- define "eddie.kafka.labels" }}
labels:
  app: {{ .Release.Name }}-kafka
{{- include "eddie.labels" . }}
{{- end }}

{{- define "eddie.kafka.strimzi.clusterName" -}}
{{- default (printf "%s-kafka" .Release.Name) .Values.kafka.strimzi.clusterName -}}
{{- end -}}

{{- define "eddie.kafka.adminUserName" -}}
{{- default (printf "%s-kafka-admin-user" .Release.Name) .Values.kafka.controllerUser.name -}}
{{- end -}}

{{- define "eddie.kafka.coreUserName" -}}
{{- default (printf "%s-kafka-core-user" .Release.Name) .Values.kafka.coreUser.name -}}
{{- end -}}

{{- define "eddie.kafka.externalHost" -}}
{{- if .Values.kafka.externalAccess.host -}}
{{- .Values.kafka.externalAccess.host -}}
{{- else -}}
{{- include "eddie.publicHost" . -}}
{{- end -}}
{{- end -}}

{{- define "eddie.kafka.externalIP" -}}
{{- default (include "eddie.externalIP" .) .Values.kafka.externalIP -}}
{{- end -}}

{{- define "eddie.kafka.externalTlsSecretName" -}}
{{- default (printf "%s-kafka-tls" .Release.Name) .Values.kafka.externalAccess.tls.existingSecret -}}
{{- end -}}

{{- define "eddie.kafka.externalTlsClusterIssuer" -}}
{{- default .Values.ingress.tls.clusterIssuer .Values.kafka.externalAccess.certManager.clusterIssuer -}}
{{- end -}}

{{- define "eddie.kafka.poolName" -}}
{{- include "eddie.resourceName" (dict "root" . "suffix" "pool") -}}
{{- end -}}

{{- define "eddie.kafka.userName" -}}
{{- include "eddie.resourceName" (dict "root" .root "suffix" .name) -}}
{{- end -}}

{{- define "eddie.kafka.topicResourceName" -}}
{{- $suffix := printf "topic-%s-%s" (.name | replace "." "-" | replace "_" "-") (sha256sum .name | trunc 8) -}}
{{ include "eddie.resourceName" (dict "root" .root "suffix" $suffix) }}
{{- end -}}
