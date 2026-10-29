# Use an existing Kafka cluster

Set `kafka.external.enabled: true` and configure its connection settings. Start with
[values.kafka-external.yaml](../examples/values.kafka-external.yaml), combined with
your application values. The Kafka outbound connector remains enabled.

Existing 1.x values require no changes. The new flag defaults to false, preserving
the bundled cluster and legacy Kafka property overrides. Neither an external block
nor a bootstrap address alone selects external Kafka. Helm merges chart defaults
into user values, so testing whether a block exists cannot reliably express intent.
The explicit flag makes a change of cluster ownership visible in values and diffs.

## Coupling and ownership

By default this chart creates a Strimzi `Kafka`, `KafkaNodePool`, administrator and
application `KafkaUser` resources, and `KafkaTopic` resources. Core connects to the
generated bootstrap Service on port 9094 using SCRAM SHA 512 without TLS and reads
the application password from a Strimzi generated Secret. `kafka.externalAccess`
exposes that bundled broker to other clients. It does not select an existing cluster.

With `kafka.external.enabled: true`, the chart creates none of those resources, Kafka
certificates or Kafka Services. Strimzi and its CRDs are unnecessary for this mode.
Keep `strimziOperator.enabled: false` and `kafka.externalAccess.enabled: false`.
The existing cluster may be managed by Strimzi, another operator, or a Kafka service.
Its administrator owns brokers, storage, certificates, users, topics and ACLs.
`kafka.topics`, `kafka.users`, replication and storage settings only affect the
bundled cluster. They do not provision anything on an existing cluster.

The application uses standard Kafka producer and consumer clients. It does not call
the Strimzi API. This assessment follows the chart's pinned EDDIE `v1.43.0`, including
its [Kafka client configuration](https://github.com/eddie-energy/eddie/blob/v1.43.0/outbound-connectors/outbound-kafka/src/main/java/energy/eddie/outbound/kafka/KafkaOutboundConnector.java),
[topic names](https://github.com/eddie-energy/eddie/blob/v1.43.0/outbound-connectors/outbound-shared/src/main/java/energy/eddie/outbound/shared/TopicConfiguration.java)
and Kafka listener annotations. A different application version needs its own topic
and compatibility review. Kafka 4.3.0 is the bundled broker default, not a verified
minimum version for an external service.

## Prepare connectivity and credentials

1. Provide a comma separated list of `host:port` bootstrap addresses without a URI
   scheme. Enclose IPv6 addresses in brackets, for example `[2001:db8::1]:9093`.
   EDDIE must resolve and reach these addresses and every broker returned
   in Kafka metadata through `advertised.listeners`. Reaching only the bootstrap
   address is insufficient. Allow DNS and broker ports in firewalls and NetworkPolicy,
   including the Kafka cluster's ingress policies. Chart egress is unrestricted by
   default. Eligible party clients also need their own reachable listener.
2. Configure `securityProtocol`: `SASL_SSL` (default), `SSL`, `SASL_PLAINTEXT`, or
   `PLAINTEXT`. Use TLS for connections across untrusted networks. For SASL select
   `SCRAM-SHA-512`, `SCRAM-SHA-256`, or `PLAIN` and create a broker user with that
   mechanism. The chart does not install provider specific authentication plugins.
3. Create the referenced Secrets in the EDDIE release namespace. For SASL,
   `sasl.existingSecret` must contain the complete JAAS configuration under
   `sasl.jaasConfigKey` (default `sasl.jaas.config`). The module must match the selected
   mechanism. Escape quotes and backslashes using JAAS syntax when constructing it.
4. The TLS certificate must match each advertised broker hostname. Java's default
   trust applies when `tls.existingSecret` is empty. For a private CA, put the PEM CA
   bundle in that Secret under `tls.caCertificateKey` (default `ca.crt`). It becomes
   Kafka's PEM truststore. Hostname verification remains enabled.

For example, create a local private file `sasl.jaas.config` with real credentials:

```text
org.apache.kafka.common.security.scram.ScramLoginModule required username="eddie" password="replace-with-real-password";
```

For SASL PLAIN use `org.apache.kafka.common.security.plain.PlainLoginModule` instead.
Create the Secrets without putting credentials in the Helm values:

```sh
kubectl --context <context> -n eddie create secret generic eddie-kafka-client \
  --from-file=sasl.jaas.config=./sasl.jaas.config
kubectl --context <context> -n eddie create secret generic eddie-kafka-ca \
  --from-file=ca.crt=./ca.crt
```

Secret values are read directly into environment variables. Changing an existing
Secret requires restarting core, for example with
`kubectl --context <context> -n eddie rollout restart deployment/eddie-core`.

For mutual TLS use `securityProtocol: SSL` and add PEM client credentials through
`propertiesFromSecret`. The certificate chain and an unencrypted PKCS#8 private key
are Secret **contents**, not file paths. The certificate must map to an authorised
Kafka principal. Keep the CA settings above when the broker uses a private CA.

```yaml
kafka:
  external:
    enabled: true
    bootstrapServers: "kafka.example.com:9093"
    securityProtocol: SSL
    propertiesFromSecret:
      ssl.keystore.certificate.chain: {name: eddie-kafka-mtls, key: tls.crt}
      ssl.keystore.key: {name: eddie-kafka-mtls, key: tls.key}
outboundConnectors:
  kafka:
    properties:
      ssl.keystore.type: PEM
```

Additional ordinary client properties belong in `outboundConnectors.kafka.properties`.
Use `kafka.external.propertiesFromSecret` for sensitive properties. Each property
maps to `{name: <Secret name>, key: <Secret key>}`. Connection settings and properties
must produce unique environment names in external mode. For example, `client.id` and `client-id`
both map to `KAFKA_CLIENT_ID` and cannot be supplied together. Configure bootstrap,
protocol and SASL through `kafka.external`, rather than repeating them as properties.
Bundled mode retains 1.x property override behaviour. The chart validates configuration
and references but cannot check Secret contents or broker connectivity during rendering.

## Prepare topics

Choose an EDDIE ID unique to this installation on a shared Kafka cluster. It resolves
from `outboundConnectors.kafka.eddieId`, then `global.eddieId` (default `eddie`).
Replacing the ID changes topic names and does not move existing messages or offsets.

Precreate these 18 topics, substituting that ID for `<id>`. The bundled chart uses
one partition per topic. Select a replication factor, minimum ISR and retention
appropriate for the external cluster. Precreation allows broker topic auto creation
to stay disabled and avoids relying on application startup topic provisioning.
There is no Schema Registry requirement. Payloads use the configured `xml` (chart
default) or `json` format, which eligible party clients must match.

| Direction | Topic |
| --- | --- |
| EDDIE produces | `ep.<id>.agnostic.raw-data-message` |
| EDDIE produces | `ep.<id>.agnostic.connection-status-message` |
| EDDIE produces | `ep.<id>.cim_0_82.permission-md` |
| EDDIE produces | `ep.<id>.cim_0_82.validated-historical-data-md` |
| EDDIE produces | `ep.<id>.cim_1_04.validated-historical-data-md` |
| EDDIE produces | `ep.<id>.cim_1_04.near-real-time-data-md` |
| EDDIE produces | `ep.<id>.cim_1_12.near-real-time-data-md` |
| EDDIE produces | `ep.<id>.cim_1_12.acknowledgement-md` |
| EDDIE produces | `ep.<id>.cim_0_82.accounting-point-md` |
| EDDIE produces | `ep.<id>.cim_1_12.min-max-envelope-md` |
| EDDIE produces | `ep.<id>.agnostic.opaque-envelope` |
| EDDIE produces | `ep.<id>.cim_1_12.energy-sharing-reference-data-md` |
| EDDIE produces | `ep.<id>.cim_1_12.request-permission-md` |
| EDDIE consumes | `fw.<id>.cim_0_82.termination-md` |
| EDDIE consumes | `fw.<id>.cim_0_91_08.redistribution-transaction-rd` |
| EDDIE consumes | `fw.<id>.agnostic.permission-command` |
| EDDIE consumes | `fw.<id>.cim_1_12.min-max-envelope-md` |
| EDDIE consumes | `fw.<id>.agnostic.opaque-envelope` |

The retransmission listener uses `redistribution-transaction-rd` in `v1.43.0`, even
though that version's operation guide calls it `retransmissions`. Follow the listener
and the table above. The six unprefixed legacy topics in `kafka.topics` are additional
bundled resources, not topics used by the pinned connector. Existing integrations
which use them must arrange their own provisioning.

## Prepare permissions and message limits

For precreated topics, grant the EDDIE principal these Kafka ACLs (or the provider's
equivalent). These permissions are narrower than the bundled user's combined read,
write and create access on both prefixes.

| Resource | Pattern | Operations |
| --- | --- | --- |
| Topic `ep.<id>.` | Prefix | Write, Describe |
| Topic `fw.<id>.` | Prefix | Read, Describe |
| Cluster | Literal | IdempotentWrite for the default idempotent producer |
| Each group below | Literal | Read |

The five group IDs are `termination-group`, `retransmission-group`,
`permission-command-group`, `min-max-envelope-group`, and `opaque-envelope-group`.
They are fixed by upstream listener annotations. Setting a generic `group.id` does
not rename them. Distinct EDDIE IDs separate topics, but do not isolate group
membership or group ACLs. Multiple installations on one cluster therefore share
these group identities and can cause rebalances for each other. Independent group
names require an application change or separate Kafka clusters.

If you allow automatic topic provisioning, also grant Create on the relevant topic
prefixes and configure broker defaults for partitions and replication. The chart's
`kafka.autocreateTopics` only controls the bundled broker. Eligible party applications
need separate credentials with Read and Describe on the desired `ep.<id>.` topics,
Read on their own consumer groups, and Write and Describe on the required `fw.<id>.`
command topics. They do not need the Kafka administrator account.

The chart configures the producer for requests up to 104857600 bytes (100 MiB).
The bundled broker sets `message.max.bytes`, `replica.fetch.max.bytes` and
`socket.request.max.bytes` to the same value. An external cluster's default 1 MiB
record limit may reject EDDIE data. Align topic `max.message.bytes` or broker
`message.max.bytes`, replication fetch limits, request limits and consumer fetch
limits with the actual maximum record size, allowing protocol overhead. Alternatively
reduce the producer limit to the service's supported size. A client property named
`message.max.bytes` does not change a broker setting.

See the [Kafka producer configuration](https://kafka.apache.org/40/configuration/producer-configs/)
for TLS, idempotence and request limits, and the
[broker configuration](https://kafka.apache.org/40/configuration/broker-configs/)
for server limits. Retention and replication are operational choices owned by the
Kafka administrator and must fit the application's delivery requirements.

## Verify before accepting the deployment

Render the chart with the example and your application values. The result must have
the external bootstrap addresses and Secret references in core, and no Strimzi
resources. Install using an explicit context and namespace:

```sh
helm upgrade --install eddie ./chart --kube-context <context> -n eddie \
  -f values.local.yaml -f chart/examples/values.kafka-external.yaml \
  --wait --timeout 10m
kubectl --context <context> -n eddie logs deployment/eddie-core
```

Check DNS and TLS from the workload network, authenticate using the same principal,
describe the topics, and check consumer group membership and offsets. Exercise an
EDDIE permission flow, consume its output, and send a valid termination or permission
command in the selected format. Check for authentication, authorisation and record
size errors. Core's TCP readiness probe alone does not establish Kafka health.
The chart regression tests verify rendered manifests, not a live external service.

Do not switch a populated bundled cluster off as an ordinary Helm upgrade. Helm can
remove the chart owned Kafka resources and users. Retained PVCs do not migrate data,
ACLs or consumer offsets. Plan and validate a separate Kafka migration first, as
described above. Preserve messages, consumer offsets and eligible party access during cutover.
