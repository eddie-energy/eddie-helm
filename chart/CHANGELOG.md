# Change log

## 1.3.0

Add opt in existing PostgreSQL and Ponton claims, extra core volumes, a response
buffer setting for compatible applications, Strimzi listener and resource
options, and Fluvius certificate mode for a separately supplied compatible image.
Existing application images and Kafka ownership remain unchanged.

Render Mosquitto queue budgets as decimal integers. Add configurable QoS 0
queuing, persistence autosave and optional core access to broker telemetry.
Defaults retain disabled QoS 0 queuing and no core access to `$SYS/#`.

Document storage handover, application requirements and migration boundaries.
These options do not transfer existing data or make an upgrade safe by themselves.

## 1.2.0

Add existing Kafka support through the explicit `kafka.external.enabled: true` setting. Existing values retain bundled Kafka and property overrides. External connections support TLS, SCRAM, PLAIN and sensitive properties from existing Secrets. Document topic names, ACLs, fixed consumer groups, message limits and migration requirements.

Validate conflicting settings in external mode and skip bundled replication checks there. A block or endpoint alone never changes cluster ownership. Switching an existing installation requires a planned data and offset migration.

## 1.1.0

- Add optional `regionConnectors.ponton.conversationIdPrefix` for routing conversations between adapters that share an eligible party.
- Leave the prefix empty by default and emit its environment variable only for an enabled Ponton connector with a nonempty prefix.
- Validate prefix characters and document the application version requirement. The default EDDIE image remains unchanged.

## 1.0.0

Initial release of the EDDIE Helm chart.

### Deployment

- EDDIE core `v1.43.0` with configurable regional and outbound connectors.
- Bundled PostgreSQL, or an external database with TLS modes and a referenced CA certificate.
- Kafka managed through Strimzi, with a locked optional operator dependency.
- Mosquitto as the default MQTT broker and an optional HiveMQ integration with its EDDIE authentication extension.
- Release scoped resources, explicit StorageClass settings, workload controls, and configurable health probes.

### Credentials and access

- Existing Secret references for application, database, broker, and connector credentials.
- An explicitly configured signing key containing exactly 32 bytes for the application.
- Traefik or external proxy authentication for management surfaces, with application basic and Keycloak login options for the admin console.
- A dedicated core Kafka user, a separate admin account, and configurable additional users and topics.
- Public HTTP, Kafka, and MQTT access disabled by default, with TLS as the default public MQTT transport.
- Optional NetworkPolicy rules for deployment ingress and egress.

### Documentation and distribution

- Complete installation instructions in the packaged chart guide.
- Small examples for internal and public access, external PostgreSQL, network policies, and workload settings.
- Connector configuration, Secret keys, and Ponton truststore guidance.
- Apache License 2.0 with FlexiData developer attribution.
- Chart contribution guidance, private security reporting, and immutable OCI release publishing.

Publication and runtime deployment verification are separate release activities. HiveMQ's default extension image requires registry access or an accessible compatible image.
