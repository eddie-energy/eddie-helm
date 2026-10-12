{{- define "eddie.postgres.provisionInitContainer" }}
{{- if eq (toString .Values.mqtt.provisioning.enabled) "true" }}
- name: provision-mqtt-role
  image: "{{ .Values.postgres.image }}:{{ .Values.postgres.version }}"
  imagePullPolicy: {{ .Values.postgres.imagePullPolicy }}
  securityContext:
    runAsNonRoot: true
    runAsUser: 999
    allowPrivilegeEscalation: false
    capabilities:
      drop: ["ALL"]
    seccompProfile:
      type: RuntimeDefault
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      memory: 256Mi
  command: ["sh", "-ec"]
  args:
    - |
      exec timeout {{ .Values.mqtt.provisioning.timeoutSeconds }} sh -ec '
        until pg_isready -h "$PGHOST" -p "$PGPORT"; do sleep 2; done
        exec psql -X -v ON_ERROR_STOP=1 -f /provision/provision.sql
      '
  env:
    - name: PGHOST
      value: {{ include "eddie.postgres.host" . | quote }}
    - name: PGPORT
      value: {{ .Values.postgres.port | quote }}
    - name: PGDATABASE
      value: {{ .Values.postgres.database | quote }}
    - name: PGCONNECT_TIMEOUT
      value: "5"
    - name: PGSSLMODE
      value: {{ include "eddie.postgres.sslMode" . | quote }}
    {{- if include "eddie.postgres.sslRootCertPath" . }}
    - name: PGSSLROOTCERT
      value: {{ include "eddie.postgres.sslRootCertPath" . | quote }}
    {{- end }}
    - name: PGOPTIONS
      value: "-c statement_timeout=60000 -c lock_timeout=30000"
    - name: PGUSER
      valueFrom:
        secretKeyRef:
          name: {{ include "eddie.postgres.secretName" . }}
          key: username
    - name: PGPASSWORD
      valueFrom:
        secretKeyRef:
          name: {{ include "eddie.postgres.secretName" . }}
          key: password
    - name: MQTT_DB_USER
      value: {{ .Values.mqtt.db.username | quote }}
    - name: MQTT_DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: {{ include "eddie.mqtt.secretName" . }}
          key: dbPassword
  volumeMounts:
    - name: postgres-provision
      mountPath: /provision
      readOnly: true
    {{- include "eddie.postgres.sslRootCertMount" . | nindent 4 }}
{{- end }}
{{- end }}
