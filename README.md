# EDDIE Helm chart

This chart deploys [EDDIE](https://architecture.eddie.energy/architecture/), the European Distributed Data Infrastructure for Energy, on Kubernetes. It includes EDDIE core, PostgreSQL, Kafka managed through Strimzi, and a choice of Mosquitto or HiveMQ for MQTT.

FlexiData GmbH developed this chart. The chart is a separate project from the [upstream EDDIE framework](https://github.com/eddie-energy/eddie).

**Current chart version: <!-- CHART_VERSION_START -->`1.0.0`<!-- CHART_VERSION_END -->.**

[The chart guide](chart/README.md) is the authoritative installation and configuration documentation. It includes an installation using existing Secrets, public access, storage, network policies, workload controls, and verification commands. Start there and create a small private values file.

Public HTTP, Kafka, and MQTT access is disabled by default. The bundled PostgreSQL and MQTT workloads each support one replica. The default EDDIE image is `v1.43.0`. Review the enabled connectors and replace the example configuration before using the deployment for production.

| Documentation | Purpose |
| --- | --- |
| [Chart guide](chart/README.md) | Install and operate the chart |
| [Change log](chart/CHANGELOG.md) | Initial release features and release notes |
| [Connector guide](chart/docs/CONNECTORS.md) | Configure MQTT queries, admin access, and regional connectors |
| [Release guide](RELEASE.md) | Prepare and publish immutable chart packages |
| [Contributing](CONTRIBUTING.md) | Report chart issues and propose changes |
| [Security policy](SECURITY.md) | Report vulnerabilities privately |

Source: [eddie-energy/eddie-helm](https://github.com/eddie-energy/eddie-helm). Follow the source installation in the chart guide. For a published OCI package, use the registry reference announced for that release.

The [EDDIE Framework operation manual](https://architecture.eddie.energy/framework/1-running/OPERATION.html) explains application behaviour, integration requirements, and registration with regional data administrators. This chart supplies Kubernetes configuration. External registrations and the configuration of an eligible party application remain the operator's responsibility.

The chart was developed by FlexiData GmbH and is distributed under the [Apache License 2.0](LICENSE). The deployed applications and their dependencies retain their own licences. See [NOTICE](NOTICE) for attribution.

[FlexiData GmbH](https://www.flexidata.at)

Hammerschmidtgasse 5, 1190 Vienna, Austria

[office@flexidata.at](mailto:office@flexidata.at)
