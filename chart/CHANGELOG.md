# Change log

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
