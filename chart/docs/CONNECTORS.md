# Connector configuration

This guide describes chart settings which connect EDDIE to other applications and data administrators. The [chart README](../README.md) covers installation and Kubernetes operation. The [EDDIE Framework operation manual](https://architecture.eddie.energy/framework/1-running/OPERATION.html) supplies application requirements and registration instructions.

Enable only the connectors used by the deployment. Disabled connectors do not require credentials. The regional defaults in [values-advanced.yaml](../values-advanced.yaml) include API endpoints and schedules. Some are integration or acceptance endpoints. Confirm the correct environment with the data administrator before enabling a production connector.

## MQTT brokers

Both supported brokers use the EDDIE MQTT authentication tables in PostgreSQL. They read bcrypt hashes from `aiida.aiida_mqtt_user` and topic permissions from `aiida.aiida_mqtt_acl`. EDDIE's schema initialisation requires the MQTT database role named `emqx`. This database role name does not select a broker.

Mosquitto uses `mosquitto-go-auth`. The chart creates a local account using `regionConnectors.aiida.mqtt.username` and the `mqttPassword` credential. The default username is `eddie`. EDDIE core uses the same username. Keep the account and the core client credentials aligned.

Select HiveMQ with:

```yaml
mqtt:
  broker: hivemq
  imagePullSecrets:
    - name: ghcr-pull
```

HiveMQ requires the EDDIE PostgreSQL authentication extension image configured through `mqtt.hivemq.image.repository`. The default repository is `ghcr.io/flexidata-at/eddie-mqtt-auth-hivemq`. The default image requires authenticated registry access. Provide a registry Secret with access to that image, or supply an accessible compatible extension image. Confirm access to the selected tag before installation. Making the chart repository public does not make that separate image public.

HiveMQ supports the shared plain and TLS listeners and a persistent claim. It has no chart managed dashboard. Configure registry credentials through `mqtt.imagePullSecrets`.

Authentication and ACL caches reduce database load but delay revocation until entries expire. `mqtt.cache.authSeconds` and `aclSeconds` default to 300 seconds, with configurable jitter. Disable caches with `mqtt.cache.enabled: false` when the revocation requirement needs immediate database evaluation. `reset` and `refresh` apply to Mosquitto. HiveMQ starts with empty caches and refreshes entries after expiry.

Queue and connection limits are configured under the chosen broker. HiveMQ also exposes connection pool sizing, query timeouts, callback timeouts, cache capacity, and credential size limits. Configure these through the documented defaults after assessing the workload.

### MQTT SQL queries

| Broker values path | Query keys | Parameters and returned data |
| --- | --- | --- |
| `mqtt.mosquitto.queries` | `password`, `superuser`, `acl` | `$1` is username. ACL `$2` is access, with 1 or 4 for subscribe and 2 for publish |
| `mqtt.hivemq.queries` | `password`, `superuser`, `acl` | JDBC `?` parameters. ACL actions use `publishAction` and `subscribeAction` |

The password query returns the password hash. The superuser query returns a count. The ACL query returns allowed topics. Use prepared parameter placeholders rather than constructing SQL from credentials.

For example, a Mosquitto query can be folded onto one configuration line:

```yaml
mqtt:
  mosquitto:
    queries:
      password: >-
        SELECT password_hash FROM custom.mqtt_users
        WHERE username = $1 LIMIT 1
```

Query values are SQL strings. They are not Helm templates. Mosquitto query changes trigger a rollout through its ConfigMap checksum. HiveMQ queries are environment settings, so changing them changes the pod specification and triggers a rollout. See the [mosquitto-go-auth PostgreSQL reference](https://github.com/iegomez/mosquitto-go-auth#postgresql) for its query result contract.

## Admin console and management access

The admin console is an outbound connector served at `/eddie/outbound-connectors/admin-console`. Its UI also calls the data needs management and core management APIs. Those APIs require independent protection at the ingress or proxy boundary.

The default chart configuration uses Traefik basic authentication for the admin console and management ingress:

```yaml
core:
  auth:
    enabled: true
    provider: traefik
    existingSecret: eddie-management-auth
outboundConnectors:
  adminConsole:
    access:
      auth:
        enabled: true
        provider: traefik
    login:
      enabled: false
```

The auth Secret needs a `users` key containing bcrypt htpasswd records. `core.auth.htpasswd` accepts the records inline. Plaintext `core.auth.users[].password` is also supported, but its random bcrypt salts cause different Secret output on each render. Existing Secrets or precomputed hashes give deterministic GitOps output.

For another ingress controller, select `external` for `core.auth.provider` and `outboundConnectors.adminConsole.access.auth.provider`. Configure authentication under `core.dataNeedsConfig.management.ingress.annotations` and `outboundConnectors.adminConsole.access.ingress.annotations`, or through an external proxy.

### Application login

EDDIE provides application basic login and Keycloak login for the admin console path. To use application login, select `outboundConnectors.adminConsole.access.auth.provider: app` and enable `login.enabled`.

Basic login requires `login.mode: basic`, `login.username`, and a BCrypt password hash through `login.encodedPassword`. An existing core Secret can instead supply the hash through `adminConsolePassword`. Generate a hash through `htpasswd` or a compatible BCrypt tool and store only the hash in the selected credential field.

Keycloak login requires `login.mode: keycloak`, `keycloakClientID`, `keycloakIssuerURI`, and `keycloakClientSecret`. The secret can be supplied through the existing core Secret. Configure the external realm and client before enabling this mode.

Application login protects the admin console path. It does not secure the data needs management and core management APIs used by the UI. Retain their Traefik protection or an equivalent external proxy when using application login.

### Data needs APIs

`core.dataNeedsConfig.datasource: config` loads data needs from a JSON file and does not enable the data needs management API. `datasource: database` stores data needs in PostgreSQL and enables that API.

The read API is at `/eddie/data-needs/api`. With database mode and management ingress enabled, the management API is exposed at `/eddie/data-needs/management`. `exposeCoreManagement: true` also exposes `/eddie/management`, which the admin console needs for regional connector management calls.

Paths include `ingress.basePath` when configured. The management `urlPrefix` defaults to `management`. Review generated ingress paths when changing either prefix.

## Outbound connectors

| Connector | Main configuration and requirement |
| --- | --- |
| Kafka | `outboundConnectors.kafka`, output format, EDDIE identifier, producer properties |
| AMQP | `outboundConnectors.amqp`, an AMQP 1.0 broker URI |
| REST | `outboundConnectors.rest`, retention settings and optional OAuth2 issuer and scopes |
| Metrics | `outboundConnectors.metric`, recipient endpoint and Spring cron schedule |
| Admin console | `outboundConnectors.adminConsole`, access and application login settings |

The MQTT deployment cannot serve as the AMQP broker. Supply a separate AMQP 1.0 service. When using an existing core Secret, put the AMQP URI in its `amqpUri` key.

REST adds an ingress path under `/eddie/outbound-connectors/rest` when HTTP ingress is enabled. Enable its OAuth2 configuration when access requires JWT authentication, with the correct issuer and scope settings. AMQP and metrics do not create ingress paths.

The global EDDIE identifier can be overridden independently for Kafka, AMQP, and metrics. Cron settings use Spring's six field expressions. Retention times use ISO 8601 duration strings, for example `PT48H`.

## Region connector Secrets

Set `regionConnectors.existingSecret` to use an externally managed Secret for connector credentials. Only the keys required by enabled connectors are needed.

| Connector | Required keys in the shared connector Secret |
| --- | --- |
| Ponton | `pontonUsername`, `pontonPassword` |
| Datadis | `datadisUsername`, `datadisPassword` |
| Enedis | `enedisClientId`, `enedisClientSecret` |
| Fingrid | `fingridOrganisationUser`, `fingridKeystorePassword`, `fingridKeyAlias`, `fingridKeyPassword` |
| Mijn Aansluiting | `mijnAansluitingContinuousKeyId`, `mijnAansluitingCodeboekApiToken`, `mijnAansluitingKeystorePassword`, `mijnAansluitingKeyAlias`, `mijnAansluitingKeyPassword` |
| Green Button | `greenButtonWebhookSecret`, and `greenButton<name>Id`, `greenButton<name>ClientSecret`, `greenButton<name>Token` for each configured client |
| Fluvius | `fluviusOAuthClientId`, `fluviusOAuthClientSecret`, `fluviusSubscriptionKey` |
| ETA+ | `etaApiClientId`, `etaApiClientSecret`, `etaAuthClientId`, `etaAuthClientSecret` |

For Green Button, `<name>` is the exact value of the client's `name` in `regionConnectors.usGreenButton.clients`. Replacing the clients list replaces all entries.

AIIDA uses the broker Secret's `mqttPassword` key. It does not use the shared regional credential Secret.

TLS material and Java keystores are mounted from separate Secrets:

| Values path | Required files |
| --- | --- |
| `regionConnectors.fiFingrid.keystore.existingSecret` | `fingrid.jks` |
| `regionConnectors.nlMijnAansluiting.keystore.existingSecret` | `aansluiting.jks` |
| `regionConnectors.beFluvius.tls.existingSecret` | Files named by `certificateFile` and `privateKeyFile`, normally `certificate.cer` and `certificate.key` |

Supply the required Secret through `existingSecret` and confirm its permissions before enabling a connector.

## Ponton XP messenger

The Ponton connector can require a private CA which is absent from the JVM trust bundle. When that CA is needed, the chart can create a dedicated truststore. Enable the connector and truststore together:

```yaml
regionConnectors:
  ponton:
    enabled: true
    hostname: "XP.MESSENGER.HOST"
    port: 2600
    apiEndpoint: "XP.MESSENGER.HOST:2600/api"
    tls:
      truststore:
        enabled: true
        caCertificate: ""
```

### Conversation routing

Set the optional `regionConnectors.ponton.conversationIdPrefix` when several adapters share one eligible party and Messenger routes responses by conversation ID:

```yaml
core:
  version: "v1.52.4"
regionConnectors:
  ponton:
    enabled: true
    eligiblePartyId: "EP123456"
    conversationIdPrefix: "D4G"
```

The chart passes a nonempty prefix as `REGION_CONNECTOR_AT_EDA_CONVERSATION_ID_PREFIX` only when the Ponton connector is enabled. The default is an empty string. Omitting the setting or keeping it empty emits no prefix environment variable and preserves the application's default ID generation. Prefixes may contain only ASCII letters and digits. EDDIE validates the complete generated ID against the EDA length limit.

Use an EDDIE image that supports `region-connector.at.eda.conversation-id.prefix`, such as `v1.51.4` or `v1.52.4`. The chart's default image remains `v1.43.0` and does not support this property. Configure the corresponding Messenger routing rule separately. See the [Austrian connector documentation](https://architecture.eddie.energy/framework/1-running/region-connectors/region-connector-at-eda.html).

### TLS trust

Configure the eligible party identifier, adapter identifier, and credentials for the XP messenger deployment. An empty `caCertificate` selects the bundled Ponton XP Root CA. For another CA, set the PEM certificate directly:

```yaml
regionConnectors:
  ponton:
    tls:
      truststore:
        caCertificate: |
          -----BEGIN CERTIFICATE-----
          <CA certificate provided by the operator>
          -----END CERTIFICATE-----
```

The chart creates `<release>-ponton-trust-config` with `ponton-ca.pem`. An init container copies the JVM CA store and imports the Ponton certificate into `/opt/ponton-truststore/ponton-truststore.p12`. Core then uses that store through the Java truststore settings.

Inspect an endpoint's certificate chain with:

```sh
openssl s_client -connect XP.MESSENGER.HOST:9443 \
  -servername XP.MESSENGER.HOST -showcerts </dev/null
```

An untrusted private CA can cause a `self-signed certificate in certificate chain` error. Use the CA certificate rather than the leaf certificate as truststore input. Inspect its subject, issuer, validity, SHA256 fingerprint, and `basicConstraints`:

```sh
openssl x509 -in ponton-ca.pem -noout \
  -subject -issuer -dates -fingerprint -sha256 -ext basicConstraints
```

Confirm the CA fingerprint with the XP messenger operator through a trusted channel before importing a certificate obtained from the endpoint. A matching common name alone does not establish trust.

To inspect the running truststore:

```sh
kubectl -n <namespace> exec deploy/<release>-core -- \
  keytool -list -keystore /opt/ponton-truststore/ponton-truststore.p12 \
  -storetype PKCS12 -storepass changeit
```

`changeit` is Java's conventional CA store tooling password. It is not an application login credential. The Ponton data folder uses its own persistent claim. Preserve and back up its files when changing connector configuration or upgrading the application.

## Regional integration checklist

The chart exposes configuration for CDS, AIIDA, Ponton EDA, Datadis, Fingrid, Enedis, Mijn Aansluiting, Green Button, Energinet, Fluvius, ETA+, and Moj Elektro. Connector registration and account provisioning happen outside Helm.

For each enabled connector, establish the correct API environment, account or OAuth client, callback URLs, TLS material, eligible party identifiers, polling schedule, and required data permissions. Consult that connector's documentation through the [official operation manual](https://architecture.eddie.energy/framework/1-running/OPERATION.html#configuring-region-connectors). Validate a representative permission and data retrieval flow before accepting the integration.
