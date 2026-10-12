# EDDIE Helm chart

This chart deploys EDDIE core, a bundled PostgreSQL database, Kafka resources managed through Strimzi, and one MQTT broker. Mosquitto is the default broker. HiveMQ is an optional integration whose default EDDIE authentication extension image currently requires registry access.

FlexiData GmbH developed this chart as a separate project from the [EDDIE framework](https://github.com/eddie-energy/eddie). Read the [EDDIE Framework operation manual](https://architecture.eddie.energy/framework/1-running/OPERATION.html) for product concepts, external registrations, and application integration.

## Versions and deployment scope

| Component | Chart default or requirement |
| --- | --- |
| Chart | `1.0.0` |
| EDDIE core | `v1.43.0` |
| Kubernetes | `1.30` or later |
| Strimzi operator | Locked dependency `1.1.0`, or a compatible separately installed operator |
| Kafka | `4.3.0` |
| Helm | Helm 3 or Helm 4 |

The default EDDIE image is `v1.43.0`. Changing `core.version` requires an application compatibility assessment and verification of the intended deployment.

Public HTTP, Kafka, and MQTT access is disabled by default. PostgreSQL and the selected MQTT broker each support one replica. Multiple internal Kafka brokers are supported when replication and ISR settings fit the broker count. External Kafka access currently requires one broker.

The defaults enable the simulation and AIIDA region connectors, the Kafka outbound connector, and the admin console. Simulation data and the demo page are intended for evaluation. Review these features before using the deployment for production.

## Install with existing Secrets

The following installation provides an internal deployment with a local demo URL. It uses existing Secrets so that credentials are not stored in Helm values. Commands use Bash and require `helm`, `kubectl`, `openssl`, and `htpasswd`. Operators using a secret management system can create equivalent Secrets with the keys listed below.

Use the same release name and namespace throughout. The examples use `eddie`.

### 1. Check the cluster

You need permission to create namespaced workloads and persistent volumes through an available StorageClass. Installing Strimzi also requires its cluster resources, including CRDs and RBAC.

```sh
kubectl cluster-info
kubectl get storageclass
kubectl create namespace eddie --dry-run=client -o yaml | kubectl apply -f -
```

A default StorageClass is sufficient. Set the PostgreSQL, MQTT, and Kafka storage classes explicitly when the cluster has no suitable default.

### 2. Select the Strimzi operator

A Strimzi operator must watch the `eddie` namespace. If a compatible operator is already present, leave `strimziOperator.enabled: false`.

To install the pinned operator separately:

```sh
helm upgrade --install strimzi oci://quay.io/strimzi-helm/strimzi-kafka-operator \
  --version 1.1.0 --namespace eddie --wait --timeout 5m
```

Alternatively, set `strimziOperator.enabled: true` in the EDDIE values file. This installs the locked dependency as part of the EDDIE release. The bundled operator normally creates cluster resources. Keep it disabled when a shared Strimzi installation already owns those resources.

### 3. Create the credential Secrets

Generate a signing key and separate passwords for the database, MQTT database role, MQTT client, and management access:

```sh
JWT_HMAC_SECRET="$(openssl rand -base64 32)"
POSTGRES_PASSWORD="$(openssl rand -base64 24)"
MQTT_DB_PASSWORD="$(openssl rand -base64 24)"
AIIDA_MQTT_PASSWORD="$(openssl rand -base64 24)"
MANAGEMENT_PASSWORD="$(openssl rand -base64 24)"
AUTH_USERS="$(printf '%s\n' "$MANAGEMENT_PASSWORD" | htpasswd -niB admin)"

kubectl -n eddie create secret generic eddie-core-credentials \
  --from-literal=jwtHmacSecret="$JWT_HMAC_SECRET"
kubectl -n eddie create secret generic eddie-postgres-credentials \
  --from-literal=username=eddie --from-literal=password="$POSTGRES_PASSWORD"
kubectl -n eddie create secret generic eddie-mqtt-credentials \
  --from-literal=dbPassword="$MQTT_DB_PASSWORD" \
  --from-literal=mqttPassword="$AIIDA_MQTT_PASSWORD"
kubectl -n eddie create secret generic eddie-management-auth \
  --from-literal=users="$AUTH_USERS"
```

Store the generated passwords in your password manager, including `MANAGEMENT_PASSWORD` for the `admin` user. The commands above create new Secrets. They are not a password rotation procedure for an existing database.

The decoded `jwtHmacSecret` Secret value is the Base64 encoding of exactly 32 random bytes. Kubernetes applies its own encoding when storing a Secret. `kubectl --from-literal` handles that storage encoding.

### 4. Create a small private values file

Create `values.local.yaml`:

```yaml
global:
  host: "localhost:8080"
ingress:
  enabled: false
  tls:
    enabled: false
core:
  existingSecret: eddie-core-credentials
  auth:
    existingSecret: eddie-management-auth
postgres:
  existingSecret: eddie-postgres-credentials
mqtt:
  existingSecret: eddie-mqtt-credentials
regionConnectors:
  aiida:
    mqtt:
      username: eddie
```

This URL is suitable for a local demo through port forwarding. Before enabling public access, replace it with the public DNS hostname and enable the required TLS configuration. The internal MQTT address is suitable for core access within the cluster. External AIIDA clients require the public MQTT configuration described below.

All referenced Secrets must exist in the release namespace before installation. Keep private values and rendered manifests outside version control.

### 5. Validate and install from source

Obtain the chart repository and enter its root directory:

```sh
git clone https://github.com/eddie-energy/eddie-helm.git
cd eddie-helm
```

Create or move `values.local.yaml` into that checkout before continuing. For a reproducible installation, check out the selected source commit or an available release tag before building dependencies. From the repository root, run:

```sh
helm dependency build ./chart
helm lint ./chart --strict -f values.local.yaml
helm template eddie ./chart -n eddie -f values.local.yaml > rendered.local.yaml
helm upgrade --install eddie ./chart --namespace eddie \
  -f values.local.yaml --wait --timeout 10m
```

Review the rendered resources before installation. A rendered manifest can contain Secret values when inline credentials are used. Keep `rendered.local.yaml` private and remove it after review.

### Optional: install a published OCI package

Use the complete registry reference announced for the selected release. Replace the placeholder in `CHART_REF` with that published location:

```sh
CHART_REF="oci://<registry>/<namespace>/eddie"
helm show chart "$CHART_REF" --version 1.0.0
helm template eddie "$CHART_REF" --version 1.0.0 \
  -n eddie -f values.local.yaml > rendered.local.yaml
helm upgrade --install eddie "$CHART_REF" --version 1.0.0 \
  --namespace eddie -f values.local.yaml --wait --timeout 10m
```

The published package includes its dependency. Confirm that the selected version is available and that a public package can be retrieved without registry credentials.

### 6. Verify the deployment

Helm reporting `STATUS: deployed` does not establish that application dependencies and integrations are healthy. Inspect workloads, persistent storage, and Strimzi resources:

```sh
helm status eddie -n eddie
kubectl -n eddie get pods,pvc,service,ingress
kubectl -n eddie get kafka,kafkanodepool,kafkauser
kubectl -n eddie wait kafka/eddie-kafka --for=condition=Ready --timeout=10m
kubectl -n eddie rollout status deployment/eddie-core --timeout=10m
kubectl -n eddie rollout status statefulset/eddie-postgres --timeout=10m
kubectl -n eddie rollout status statefulset/eddie-mosquitto --timeout=10m
kubectl -n eddie port-forward service/eddie-core 8080:8080
```

Open `http://localhost:8080/eddie/demo`. The MQTT StatefulSet is named `eddie-hivemq` when HiveMQ is selected. Inspect connector logs and exercise the intended permission and data flow before accepting a deployment.

This port forward exposes the demo and public API on port 8080. It does not provide the admin console and management API routing. Those surfaces use the management port 9090 and require the ingress or proxy routing described below.

## Public access

### HTTP and management APIs

A public HTTP deployment needs DNS, an ingress controller, and a TLS certificate. The default authentication provider uses Traefik and requires its `Middleware` CRD. Chart managed certificates require cert-manager and a `ClusterIssuer` such as `letsencrypt-prod`.

Update the private values file:

```yaml
global:
  host: eddie.example.com
ingress:
  enabled: true
  className: traefik
  tls:
    enabled: true
    clusterIssuer: letsencrypt-prod
```

Check the relevant prerequisites:

```sh
kubectl get ingressclass
kubectl get crd middlewares.traefik.io
kubectl get crd certificates.cert-manager.io
kubectl get clusterissuer letsencrypt-prod
```

To use an existing certificate instead, create a TLS Secret in the release namespace and set `ingress.tls.existingSecret`. That Secret needs `tls.crt` and `tls.key`. The chart then omits the cert-manager issuer annotation.

Setting an ingress class alone does not provide authentication. For another controller, set `core.auth.provider: external`, configure authentication through the appropriate ingress annotations or proxy, and select `external` for the admin console authentication provider. Both management APIs and the admin console need protection. See [the connector guide](docs/CONNECTORS.md#admin-console-and-management-access).

### MQTT and AIIDA

Enable external MQTT only when external clients need it. Public MQTT uses TLS unless plaintext access is explicitly enabled:

```yaml
mqtt:
  externalAccess:
    enabled: true
    plaintext:
      enabled: false
    tls:
      enabled: true
      existingSecret: eddie-mqtt-tls
regionConnectors:
  aiida:
    mqtt:
      server:
        uri: "ssl://mqtt.example.com:8883"
      username: eddie
```

Create the matching `eddie-mqtt-tls` Secret with `tls.crt` and `tls.key`, point DNS at the MQTT LoadBalancer, and confirm that the certificate covers the MQTT hostname. An empty MQTT TLS Secret name reuses the effective ingress TLS Secret. This requires that the Secret actually exists and covers the hostname clients use.

EDDIE distributes the configured MQTT server URI to external AIIDA clients and also uses it from core. The URI therefore needs to be reachable from both the cluster and those clients. Leaving it empty selects the cluster service address, which external clients normally cannot resolve.

Plain MQTT remains available inside the cluster on port 1883. Setting `mqtt.externalAccess.plaintext.enabled: true` additionally exposes the plain listener through the public LoadBalancer. Credentials and data then travel without transport encryption.

### Kafka

Set `kafka.externalAccess.enabled: true` to expose the external SASL/TLS listener. The advertised hostname resolves from `kafka.externalAccess.host`, then `ingress.host`, then `global.host`. DNS and LoadBalancer reachability must match that hostname.

By default, cert-manager creates a Kafka certificate using `ingress.tls.clusterIssuer`. Override the issuer through `kafka.externalAccess.certManager.clusterIssuer`, or supply `kafka.externalAccess.tls.existingSecret` to use an externally managed certificate. The Secret must contain `tls.crt` and an unencrypted PKCS#8 `tls.key`.

External clients use:

```properties
bootstrap.servers=<kafka-host>:9095
security.protocol=SASL_SSL
sasl.mechanism=SCRAM-SHA-512
```

Core uses the dedicated `<release>-kafka-core-user`. The `<release>-kafka-admin-user` account is reserved for administration. Strimzi creates a Secret with the same name as each user. Configure additional users under `kafka.users` explicitly. Each additional user also receives read and write access to this EDDIE instance's `ep.<eddieId>.` and `fw.<eddieId>.` topic prefixes. Provision a separate Strimzi user externally when a consumer needs access to only a single topic.

For example, this configuration creates an additional integration account:

```yaml
kafka:
  users:
    - name: integration
```

With release name `eddie`, the KafkaUser, SCRAM username, and generated Secret are named `eddie-integration`. Use the rendered KafkaUser name for authentication, since long names are shortened. Consumer group permissions use the configured name `integration` as a prefix, plus any exact groups specified in `consumeTopics[].group`. Choose a client group such as `integration-reader`. Once Strimzi has created the Secret, retrieve its password with:

```sh
kubectl -n eddie get secret eddie-integration -o jsonpath='{.data.password}' | base64 -d
```

## Values and credentials

[values.yaml](values.yaml) contains the common settings. [values-advanced.yaml](values-advanced.yaml) supplies defaults for security contexts, probes, broker queries, Kafka topics and users, and regional connector options. Advanced defaults load automatically. No additional `-f` argument is needed.

Copy only the keys you want to change. Nested maps normally merge. Lists replace the complete default list. `kafka.users` and `kafka.topics` are additional entries and are empty by default. The chart always creates its application topics and dedicated core and admin users. Probe overrides replace the complete probe rather than merging its handler.

`helm show values` shows the common file. Consult the packaged advanced file when overriding options absent from that output. Use YAML booleans such as `enabled: false`.

| Example | Purpose |
| --- | --- |
| [Internal installation](examples/values.internal.yaml) | Existing credentials and a local demo URL |
| [Public HTTP](examples/values.public.yaml) | Traefik access with existing credential Secrets |
| [Public MQTT](examples/values.mqtt-public.yaml) | TLS endpoint for external AIIDA clients |
| [External database](examples/values.database-external.yaml) | PostgreSQL certificate verification and external role management |
| [Network policy](examples/values.network-policy.yaml) | Permit the ingress controller explicitly |
| [Workload controls](examples/values.workload.yaml) | Resource, scheduling, and probe override shapes |

| Setting | Precedence |
| --- | --- |
| HTTP hostname | `ingress.host`, then `global.host` |
| Kafka advertised hostname | `kafka.externalAccess.host`, then HTTP hostname |
| LoadBalancer IP | Component `externalIP`, then `global.externalIP` |
| Outbound EDDIE identifier | Connector `eddieId`, then `global.eddieId`, then `eddie` |
| Broker pull Secrets | `mqtt.imagePullSecrets` applies to the selected broker |

An empty external IP lets the cluster allocate one. Keep component overrides when their endpoints or identities differ.

### Existing Secrets

The chart omits its generated credential Secret when the corresponding `existingSecret` is set. The referenced Secret must exist in the release namespace.

| Values path | Required Secret keys |
| --- | --- |
| `core.existingSecret` | `jwtHmacSecret`. Add `adminConsolePassword` for application basic login, `keycloakClientSecret` for Keycloak login, and `amqpUri` when AMQP is enabled |
| `postgres.existingSecret` | `username`, `password` |
| `mqtt.existingSecret` | `dbPassword`, `mqttPassword` |
| `core.auth.existingSecret` | `users` containing bcrypt htpasswd records |
| `regionConnectors.existingSecret` | Keys required by the enabled connector, listed in [the connector guide](docs/CONNECTORS.md#region-connector-secrets) |
| `postgres.ssl.rootCert.existingSecret` | The key selected by `postgres.ssl.rootCert.key`, normally `ca.crt` |

For inline `core.jwtHmacSecret`, provide exactly 32 UTF8 bytes. The chart encodes that value for the application. A 32 character ASCII value is 32 bytes. For example, `openssl rand -base64 24` produces 32 ASCII characters. For an existing Secret, use the Base64 encoding of 32 random bytes as shown in the installation instructions.

Inline credentials and hashes are retained in Helm release records. Prefer existing Secrets for production. Plaintext `core.auth.users[].password` values remain supported for edge authentication, but each render generates new bcrypt salts. Use `core.auth.htpasswd` or an existing auth Secret for deterministic GitOps output.

Application basic login requires a BCrypt value through `outboundConnectors.adminConsole.login.encodedPassword`, or the `adminConsolePassword` key in an existing core Secret.

Changing an external Secret does not restart workloads automatically. Coordinate the change and restart the affected workloads, for example by changing a pod annotation.

## Database operation

The core init container provisions or rotates the MQTT PostgreSQL role before application schema initialisation. Its database account needs permission to create or alter that role. EDDIE's schema initialisation requires the database named `eddie` and the role named `emqx`. Use `postgres.database: eddie` and `mqtt.db.username: emqx` unless you manage compatible schema initialisation and grants. The role name is a database requirement and does not select the MQTT broker.

For an externally managed database:

```yaml
postgres:
  enabled: false
  host: postgres.database.example.com
  existingSecret: eddie-postgres-credentials
  ssl:
    mode: verify-full
    rootCert:
      existingSecret: eddie-postgres-ca
      key: ca.crt
mqtt:
  provisioning:
    enabled: false
```

Disable MQTT provisioning only when the role and its password are managed externally. Otherwise retain provisioning and grant the required database privileges.

An empty `postgres.ssl.mode` resolves to `disable` for the bundled database and `require` for an external database. Explicit modes are `disable`, `require`, `verify-ca`, and `verify-full`. Use `verify-full` with a trusted CA and the correct database hostname when the database supports it. The CA is mounted at `/etc/postgres-tls/ca.crt`.

Changing the bootstrap PostgreSQL password does not rotate the administrator password inside an initialised database volume. Rotate it in PostgreSQL and coordinate the matching Secret change. MQTT role rotation can briefly interrupt broker authentication.

## Security and workload controls

| Component | Default persistence | Default memory request and limit |
| --- | --- | --- |
| PostgreSQL | `1Gi` | `256Mi`, `2Gi` |
| MQTT | `1Gi` | `512Mi`, `2Gi` |
| Kafka node | `5Gi` | `512Mi`, `4Gi` |
| Core | No general data PVC | `256Mi`, `2Gi` |

These defaults are initial settings rather than capacity guidance for a particular workload. Adjust CPU, memory, persistent storage, and broker queue limits based on the expected data volume.

Resource `min` and `max` map to Kubernetes `requests` and `limits`:

```yaml
core:
  resources:
    memory: { min: "512Mi", max: "2Gi" }
```

PostgreSQL and MQTT use `persistence.storageClass`. `null` uses the cluster default and `""` explicitly requests no storage class. Kafka uses `kafka.persistence.storageClass` for the Strimzi volume class.

Kafka claims are retained through `deleteClaim: false`. Back up persistent data before upgrades. Existing volume expansion depends on the storage provider and controller. Changing a StatefulSet claim template is not a general procedure for resizing an existing PVC.

Core, PostgreSQL, and MQTT support pod annotations, node selectors, tolerations, affinity, and pod/container security contexts. Core and MQTT also support topology spread constraints. Registry credentials are configured through `core.imagePullSecrets` and `mqtt.imagePullSecrets`. Security overrides must match the image and volume permissions.

Core runs as user and group 1000 by default, with `runAsNonRoot: true`. AIIDA MQTT client file persistence and the generated Ponton truststore use ephemeral volumes which do not survive deletion of the pod. The Ponton data folder uses a persistent claim. Other persistent data belongs in PostgreSQL and the broker claims.

Core and PostgreSQL expose startup, readiness, and liveness probe objects. A configured probe replaces the complete default probe. An empty map disables it. MQTT additionally uses `null` to select its broker defaults. TCP probes check listener availability. Use an application health endpoint when it represents the required readiness condition.

See [the workload example](examples/values.workload.yaml) for override shapes. Mosquitto uses `mqtt.mosquitto.image.repository` and `pullPolicy`, with its tag under `mqtt.versions.mosquitto`. HiveMQ uses the equivalent `mqtt.hivemq.image` settings and `mqtt.versions.hivemq`. [The connector guide](docs/CONNECTORS.md#mqtt-brokers) describes the HiveMQ image dependency.

## Network policies

`networkPolicy.enabled` restricts ingress to release workloads and the Kafka cluster. The cluster networking provider must enforce NetworkPolicy. Add ingress controller access explicitly, for example:

```yaml
networkPolicy:
  enabled: true
  extraIngress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: traefik
      ports:
        - protocol: TCP
          port: 8080
        - protocol: TCP
          port: 9090
```

Use the actual namespace of your controller. Add separate ingress rules for public MQTT clients and monitoring access. Egress is unrestricted by default because connectors call external APIs. When replacing `networkPolicy.egress` with narrower rules, allow DNS, Kafka, the database, the configured public MQTT endpoint, and required external APIs. Standard NetworkPolicy rules select pods, namespaces, or IP ranges rather than DNS hostnames.

## Data needs and connectors

`core.dataNeedsConfig.datasource: config` loads the configured data needs file. Supply data through `core.dataNeedsConfig.data`, or set `existingConfigMap` to a ConfigMap containing `data-needs.json`. An empty data list selects the bundled examples. Changes to a chart managed ConfigMap roll core. Changes to an external ConfigMap require a restart.

Set `datasource: database` to store data needs in PostgreSQL and enable the data needs management API. Protect that API and the core management API before exposing them.

Regional connectors requiring external registration are disabled by default. Set their `enabled` value and supply the required credentials and external resources. [The connector guide](docs/CONNECTORS.md) covers Secret keys, MQTT queries, admin authentication, Ponton trust, and references to the upstream registration instructions.

## Troubleshooting and upgrades

| Symptom | First check |
| --- | --- |
| Missing Strimzi kinds or Kafka user Secret | Operator installation, CRDs, and the watched namespace |
| Missing Traefik `Middleware` kind | Traefik CRDs and the configured auth provider |
| Missing TLS Secret | cert-manager events, DNS, issuer readiness, or the referenced existing Secret |
| Pending PostgreSQL, MQTT, or Kafka pod | PVC events and StorageClass provisioning |
| `ImagePullBackOff` | Repository availability, image tag, and registry pull Secrets |
| Signing key validation failure | Exactly 32 UTF8 bytes inline, or Base64 encoding of 32 random bytes in the existing Secret |
| AIIDA cannot connect to MQTT | Matching username/password, broker logs, and a URI reachable by both core and the client |
| Database TLS failure | SSL mode, CA Secret, certificate hostname, and database TLS configuration |

Before an upgrade, read the target release notes, back up data, inspect the current values with `helm get values`, and review a rendered resource diff. Repeat the workload and application verification afterwards. Helm rollback does not restore volume data or reverse application database schema changes.

## Licence and project contact

The chart was developed by FlexiData GmbH and is distributed under the [Apache License 2.0](LICENSE). Applications and dependencies retain their own licences. See [NOTICE](NOTICE) for attribution.

Source and chart issues: [eddie-energy/eddie-helm](https://github.com/eddie-energy/eddie-helm).

Developer: [FlexiData GmbH](https://www.flexidata.at), Hammerschmidtgasse 5, 1190 Vienna, Austria.

Contact: [office@flexidata.at](mailto:office@flexidata.at). Report vulnerabilities privately to this address. Developer attribution and contact information do not establish a maintenance or support commitment.
