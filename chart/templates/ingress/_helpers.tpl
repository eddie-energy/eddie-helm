{{- define "eddie.ingress.annotations" }}
{{- $annotations := mergeOverwrite (deepCopy (.root.Values.ingress.annotations | default dict)) (.annotations | default dict) }}
{{- if .auth }}
{{- $authMiddleware := printf "%s-%s@kubernetescrd" .root.Release.Namespace (include "eddie.management.basicAuthMiddlewareName" .root) }}
{{- $middlewares := list $authMiddleware }}
{{- range $middleware := splitList "," (get $annotations "traefik.ingress.kubernetes.io/router.middlewares" | default "") }}
{{- $middleware = trim $middleware }}
{{- if and $middleware (ne $middleware $authMiddleware) }}
{{- $middlewares = append $middlewares $middleware }}
{{- end }}
{{- end }}
{{- $_ := set $annotations "traefik.ingress.kubernetes.io/router.middlewares" (join "," $middlewares) }}
{{- end }}
{{- if $annotations }}
annotations:
  {{- toYaml $annotations | nindent 2 }}
{{- end }}
{{- end }}

{{- define "eddie.ingress.tls" }}
{{- if eq (toString .Values.ingress.tls.enabled) "true" }}
tls:
  - hosts:
      - {{ include "eddie.publicHost" . | quote }}
    secretName: {{ include "eddie.ingress.tlsSecretName" . }}
{{- end }}
{{- end }}

{{- define "eddie.ingress.tlsSecretName" -}}
{{- default (printf "%s-tls" .Release.Name) .Values.ingress.tls.existingSecret -}}
{{- end -}}

{{/* A shared Middleware/Secret is needed if either management surface uses Traefik auth. */}}
{{- define "eddie.auth.managed" -}}
{{- $auth := .Values.core.auth -}}
{{- $admin := .Values.outboundConnectors.adminConsole -}}
{{- $protectCore := false -}}
{{- if and
  (eq (toString $auth.enabled) "true")
  (eq (default "traefik" $auth.provider) "traefik")
-}}
  {{- $protectCore = or
    (eq (include "eddie.management.ingress.exposeCoreManagement" .) "true")
    (and
      (eq .Values.core.dataNeedsConfig.datasource "database")
      (eq (include "eddie.management.ingress.enabled" .) "true"))
  -}}
{{- end -}}
{{- $protectAdmin := and
  (eq (toString $admin.enabled) "true")
  (eq (toString $admin.access.ingress.enabled) "true")
  (eq (toString $admin.access.auth.enabled) "true")
  (eq (default "traefik" $admin.access.auth.provider) "traefik")
-}}
{{- and (eq (toString .Values.ingress.enabled) "true") (or $protectCore $protectAdmin) -}}
{{- end -}}

{{- define "eddie.adminConsole.path" -}}
{{ include "eddie.contextPath" . }}/outbound-connectors/admin-console
{{- end -}}

{{- define "eddie.management.basicAuthMiddlewareName" -}}
{{- printf "%s-management-basic-auth" .Release.Name -}}
{{- end -}}

{{- define "eddie.management.urlPrefix" -}}
{{- trimPrefix "/" (default "management" .Values.core.dataNeedsConfig.management.urlPrefix) -}}
{{- end -}}

{{- define "eddie.management.ingress.enabled" -}}
{{- if hasKey .Values.core.dataNeedsConfig "management" -}}
{{- toString .Values.core.dataNeedsConfig.management.ingress.enabled -}}
{{- else -}}
true
{{- end -}}
{{- end -}}

{{- define "eddie.management.ingress.exposeCoreManagement" -}}
{{- if hasKey .Values.core.dataNeedsConfig "management" -}}
{{- toString .Values.core.dataNeedsConfig.management.ingress.exposeCoreManagement -}}
{{- else -}}
true
{{- end -}}
{{- end -}}
