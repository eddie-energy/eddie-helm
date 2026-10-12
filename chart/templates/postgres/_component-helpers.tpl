{{/* postgres component helpers. */}}
{{- define "eddie.postgres.labels" }}
labels:
  app: {{ .Release.Name }}-postgres
{{- include "eddie.labels" . }}
{{- end }}

{{- define "eddie.postgres-url" -}}
{{- printf "jdbc:postgresql://%s:%v/%s%s" (include "eddie.postgres.host" .) .Values.postgres.port .Values.postgres.database (include "eddie.postgres.sslQuery" .) | quote -}}
{{- end }}

{{- define "eddie.postgres.host" -}}
{{- if eq (toString .Values.postgres.enabled) "true" -}}{{ .Release.Name }}-postgres
{{- else -}}{{ required "postgres.host is required when postgres.enabled=false" .Values.postgres.host }}{{- end -}}
{{- end -}}

{{- define "eddie.postgres.secretName" -}}
{{ default (printf "%s-postgres-secret" .Release.Name) .Values.postgres.existingSecret }}
{{- end -}}

{{/* Bundled PostgreSQL has no TLS listener; external databases require TLS by default. */}}
{{- define "eddie.postgres.sslMode" -}}
{{- $ssl := .Values.postgres.ssl | default dict -}}
{{- if $ssl.mode -}}
{{- $ssl.mode -}}
{{- else if eq (toString .Values.postgres.enabled) "true" -}}disable
{{- else -}}require
{{- end -}}
{{- end -}}

{{- define "eddie.postgres.sslRootCertPath" -}}
{{- $ssl := .Values.postgres.ssl | default dict -}}
{{- $rootCert := $ssl.rootCert | default dict -}}
{{- if $rootCert.existingSecret -}}/etc/postgres-tls/ca.crt{{- end -}}
{{- end -}}

{{- define "eddie.postgres.sslQuery" -}}
{{- printf "?sslmode=%s" (include "eddie.postgres.sslMode" . | urlquery) -}}
{{- if include "eddie.postgres.sslRootCertPath" . -}}
{{- printf "&sslrootcert=%s" (include "eddie.postgres.sslRootCertPath" . | urlquery) -}}
{{- end -}}
{{- end -}}

{{- define "eddie.postgres.sslRootCertMount" }}
{{- if include "eddie.postgres.sslRootCertPath" . }}
- name: postgres-root-cert
  mountPath: /etc/postgres-tls
  readOnly: true
{{- end }}
{{- end }}

{{- define "eddie.postgres.sslRootCertVolume" }}
{{- if include "eddie.postgres.sslRootCertPath" . }}
- name: postgres-root-cert
  secret:
    secretName: {{ .Values.postgres.ssl.rootCert.existingSecret }}
    items:
      - key: {{ .Values.postgres.ssl.rootCert.key | default "ca.crt" | quote }}
        path: ca.crt
{{- end }}
{{- end }}
