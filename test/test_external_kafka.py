"""Regression tests for explicit external Kafka selection and existing values."""
import copy
import json
import os
from pathlib import Path
import re
import subprocess
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[1]
CHART = ROOT / "chart"
RENDER_VALUES = yaml.safe_load((ROOT / "test/values.render.yaml").read_text())


class UniqueLoader(yaml.SafeLoader):
    pass


def unique_mapping(loader, node, deep=False):
    result = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if key in result:
            raise ValueError(f"Duplicate YAML key: {key}")
        result[key] = loader.construct_object(value_node, deep=deep)
    return result


UniqueLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, unique_mapping)


def merge(base, updates):
    result = copy.deepcopy(base)
    for key, value in updates.items():
        if isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = merge(result[key], value)
        else:
            result[key] = copy.deepcopy(value)
    return result


def render(values=None, release="review", extra=(), check=True, chart=CHART):
    """Supply test credentials; explicit overrides still exercise invalid inputs."""
    proc = subprocess.run(
        [os.environ.get("HELM", "helm"), "template", release, str(chart), "--namespace", "test", "-f", "-", *extra],
        input=yaml.safe_dump(merge(RENDER_VALUES, values or {})), text=True, encoding="utf-8", capture_output=True, cwd=ROOT,
    )
    if not check:
        return proc
    if proc.returncode:
        raise AssertionError(proc.stderr)
    return [doc for doc in yaml.load_all(proc.stdout, Loader=UniqueLoader) if doc]


def resource(docs, kind, suffix):
    return next(d for d in docs if d["kind"] == kind and d["metadata"]["name"].endswith(suffix))


def core(docs):
    return resource(docs, "Deployment", "-core")


class ExternalKafkaTests(unittest.TestCase):
    def test_bundled_kafka_connection_remains_the_default(self):
        docs = render()
        env = {e["name"]: e for e in core(docs)["spec"]["template"]["spec"]["containers"][0]["env"]}
        self.assertEqual(env["KAFKA_BOOTSTRAP_SERVERS"]["value"], "review-kafka-kafka-bootstrap:9094")
        self.assertEqual(env["KAFKA_SECURITY_PROTOCOL"]["value"], "SASL_PLAINTEXT")
        self.assertEqual(env["KAFKA_PASSWORD"]["valueFrom"]["secretKeyRef"],
                         {"name": "review-kafka-core-user", "key": "password"})
        self.assertEqual(len([d for d in docs if d["kind"] == "Kafka"]), 1)

    def test_external_kafka_requires_explicit_opt_in(self):
        bundled = render()
        for external in (None, {}, {"enabled": False}, {"enabled": "false"},
                         {"bootstrapServers": "unused.test:9093"},
                         {"enabled": False, "bootstrapServers": "unused.test:9093",
                          "tls": {"existingSecret": "unused-ca"}}):
            with self.subTest(external=external):
                self.assertEqual(render({"kafka": {"external": external}}), bundled)
        # Merely specifying the endpoint must not disable the bundled operator either.
        self.assertEqual(render({"strimziOperator": {"enabled": True}}),
                         render({"strimziOperator": {"enabled": True},
                                 "kafka": {"external": {"bootstrapServers": "unused.test:9093"}}}))

    def test_existing_kafka_property_overrides_remain_accepted(self):
        properties = {"bootstrap.servers": "legacy.test:9092", "security.protocol": "PLAINTEXT",
                      "sasl.mechanism": "PLAIN", "sasl.jaas.config": "test-only-jaas",
                      "client.id": "first", "client-id": "second"}
        # A existing override file has no kafka.external block. Keep its environment order,
        # including legacy overrides after the chart-generated connection settings.
        docs = render({"outboundConnectors": {"kafka": {"properties": properties}}})
        env = core(docs)["spec"]["template"]["spec"]["containers"][0]["env"]
        for key, expected in (("KAFKA_BOOTSTRAP_SERVERS", "legacy.test:9092"),
                              ("KAFKA_SECURITY_PROTOCOL", "PLAINTEXT"),
                              ("KAFKA_SASL_MECHANISM", "PLAIN"),
                              ("KAFKA_SASL_JAAS_CONFIG", "test-only-jaas")):
            entries = [e for e in env if e["name"] == key]
            self.assertEqual(len(entries), 2)
            self.assertEqual(entries[-1]["value"], expected)
        self.assertEqual([e["value"] for e in env if e["name"] == "KAFKA_CLIENT_ID"], ["second", "first"])
        self.assertEqual(len([d for d in docs if d["kind"] == "Kafka"]), 1)

    def test_external_kafka_protocols_and_secret_references(self):
        for protocol in ("PLAINTEXT", "SSL", "SASL_PLAINTEXT", "SASL_SSL"):
            mechanisms = ("SCRAM-SHA-512", "SCRAM-SHA-256", "PLAIN") if protocol.startswith("SASL_") else ("PLAIN",)
            for mechanism in mechanisms:
                with self.subTest(protocol=protocol, mechanism=mechanism):
                    external = {"bootstrapServers": "broker-1.test:9093,broker-2.test:9093",
                                "enabled": True,
                                "securityProtocol": protocol,
                                "sasl": {"mechanism": mechanism, "existingSecret": "client", "jaasConfigKey": "jaas"}}
                    if protocol.endswith("SSL"):
                        external["tls"] = {"existingSecret": "ca", "caCertificateKey": "bundle.pem"}
                    docs = render({"kafka": {"external": external},
                                   "networkPolicy": {"enabled": True}})
                    self.assertFalse(any(d["apiVersion"].startswith("kafka.strimzi.io/") for d in docs))
                    self.assertFalse(any(d["kind"] in ("Certificate", "CustomResourceDefinition") for d in docs))
                    self.assertFalse(any("kafka" in d["metadata"]["name"] for d in docs))
                    self.assertNotIn("strimzi.io/cluster", json.dumps(resource(docs, "NetworkPolicy", "-workloads")))
                    entries = core(docs)["spec"]["template"]["spec"]["containers"][0]["env"]
                    env = {e["name"]: e for e in entries}
                    self.assertEqual(len(entries), len(env))
                    self.assertEqual(env["KAFKA_BOOTSTRAP_SERVERS"]["value"], external["bootstrapServers"])
                    self.assertEqual(env["KAFKA_SECURITY_PROTOCOL"]["value"], protocol)
                    self.assertNotIn("KAFKA_PASSWORD", env)
                    self.assertNotIn("KAFKA_USER", env)
                    self.assertEqual("KAFKA_SASL_JAAS_CONFIG" in env, protocol.startswith("SASL_"))
                    self.assertEqual("KAFKA_SSL_TRUSTSTORE_CERTIFICATES" in env, protocol.endswith("SSL"))
                    if protocol.startswith("SASL_"):
                        self.assertEqual(env["KAFKA_SASL_MECHANISM"]["value"], mechanism)
                        self.assertEqual(env["KAFKA_SASL_JAAS_CONFIG"]["valueFrom"]["secretKeyRef"],
                                         {"name": "client", "key": "jaas"})
                    if protocol.endswith("SSL"):
                        self.assertEqual(env["KAFKA_SSL_TRUSTSTORE_TYPE"]["value"], "PEM")
                        self.assertEqual(env["KAFKA_SSL_TRUSTSTORE_CERTIFICATES"]["valueFrom"]["secretKeyRef"],
                                         {"name": "ca", "key": "bundle.pem"})

    def test_external_kafka_mtls_and_public_ca(self):
        refs = {"ssl.keystore.key": {"name": "mtls", "key": "tls.key"},
                "ssl.keystore.certificate.chain": {"name": "mtls", "key": "tls.crt"}}
        docs = render({"kafka": {"external": {"enabled": "true",
            "bootstrapServers": "broker.test:9093,[2001:db8::1]:9093", "securityProtocol": "SSL", "propertiesFromSecret": refs}},
            "outboundConnectors": {"kafka": {"properties": {"ssl.keystore.type": "PEM", "client.id": "my-client"}}}})
        entries = core(docs)["spec"]["template"]["spec"]["containers"][0]["env"]
        env = {e["name"]: e for e in entries}
        self.assertEqual(len(entries), len(env))
        self.assertEqual(env["KAFKA_SSL_KEYSTORE_TYPE"]["value"], "PEM")
        self.assertEqual(env["KAFKA_BOOTSTRAP_SERVERS"]["value"], "broker.test:9093,[2001:db8::1]:9093")
        self.assertEqual(env["KAFKA_SSL_KEYSTORE_KEY"]["valueFrom"]["secretKeyRef"], refs["ssl.keystore.key"])
        self.assertEqual(env["KAFKA_SSL_KEYSTORE_CERTIFICATE_CHAIN"]["valueFrom"]["secretKeyRef"],
                         refs["ssl.keystore.certificate.chain"])
        self.assertNotIn("KAFKA_SSL_TRUSTSTORE_CERTIFICATES", env)
        self.assertEqual(env["KAFKA_CLIENT_ID"]["value"], "my-client")

    def test_external_kafka_with_disabled_connector_and_bundled_replication(self):
        for enabled in (False, "false"):
            docs = render({"kafka": {"external": {"enabled": True}},
                           "outboundConnectors": {"kafka": {"enabled": enabled}}})
            self.assertFalse(any(d["apiVersion"].startswith("kafka.strimzi.io/") for d in docs))
            env = core(docs)["spec"]["template"]["spec"]["containers"][0]["env"]
            self.assertFalse(any(e["name"].startswith("KAFKA_") for e in env))
        render({"kafka": {"external": {"enabled": True,
            "bootstrapServers": "broker.test:9093", "sasl": {"existingSecret": "client"}},
            "strimzi": {"defaultReplicationFactor": 3},
            "topics": [{"name": "external-topic", "partitions": 2, "replicationFactor": 3}]}})

    def test_external_kafka_invalid_configuration_fails_early(self):
        base = {"kafka": {"external": {"enabled": True,
            "bootstrapServers": "broker.test:9093", "sasl": {"existingSecret": "client"}}}}
        cases = [
            ({"kafka": {"external": {"bootstrapServers": value}}}, "bootstrapServers")
            for value in ("", "broker.test", "https://broker.test:9093", "broker.test:0", "broker.test:65536", "broker.test:9093,")
        ] + [
            ({"kafka": {"external": {"sasl": {"existingSecret": ""}}}}, "existingSecret"),
            ({"strimziOperator": {"enabled": True}}, "strimziOperator.enabled"),
            ({"kafka": {"externalAccess": {"enabled": True}}}, "externalAccess"),
            ({"kafka": {"external": {"securityProtocol": "typo"}}}, "securityProtocol"),
            ({"kafka": {"external": {"sasl": {"mechanism": "GSSAPI"}}}}, "mechanism"),
            ({"kafka": {"external": {"securityProtocol": "PLAINTEXT", "tls": {"existingSecret": "ca"}}}}, "requires securityProtocol"),
            ({"kafka": {"external": {"propertiesFromSecret": {"ssl.keystore.key": {"name": "mtls"}}}}}, "key"),
            ({"outboundConnectors": {"kafka": {"properties": {"bootstrap.servers": "other:9092"}}}}, "duplicates"),
            ({"outboundConnectors": {"kafka": {"properties": {"client.id": "one", "client-id": "two"}}}}, "duplicates"),
            ({"kafka": {"external": {"propertiesFromSecret": {"client.id": {"name": "s", "key": "k"}}}},
              "outboundConnectors": {"kafka": {"properties": {"client.id": "inline"}}}}, "duplicates"),
            ({"kafka": {"external": {"tls": {"existingSecret": "ca"}}},
              "outboundConnectors": {"kafka": {"properties": {"ssl.truststore.type": "JKS"}}}}, "duplicates"),
        ]
        for override, message in cases:
            with self.subTest(override=override):
                result = render(merge(base, override), check=False)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(message, result.stderr)

    def test_external_kafka_documentation_matches_bundled_connector_topics(self):
        text = (CHART / "docs/KAFKA.md").read_text()
        documented = {name.replace("<id>", "custom-id") for name in re.findall(r"`((?:ep|fw)\.<id>\.[^`]+)`", text)}
        docs = render({"global": {"eddieId": "fallback"}, "outboundConnectors": {"kafka": {"eddieId": "custom-id"}}})
        topics = {d["spec"]["topicName"] for d in docs if d["kind"] == "KafkaTopic"
                  and d["spec"]["topicName"].startswith(("ep.custom-id.", "fw.custom-id."))}
        self.assertEqual(len(topics), 18)
        self.assertEqual(documented, topics)


if __name__ == "__main__":
    unittest.main()
