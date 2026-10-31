"""Render checks for preserving populated installations during a chart migration."""
import unittest
from test_external_kafka import render, resource, core


class MigrationSupportTests(unittest.TestCase):
    def test_local_mqtt_telemetry_is_opt_in(self):
        default = resource(render(), 'ConfigMap', '-mosquitto-config')['data']
        self.assertNotIn('topic read $SYS/#', default['start.sh'])
        self.assertIn('queue_qos0_messages false\n', default['mosquitto.conf'])
        self.assertIn('autosave_interval 1800\n', default['mosquitto.conf'])
        for enabled in (True, 'true'):
            docs = render({'mqtt': {'mosquitto': {'allowLocalSysRead': enabled}}})
            self.assertIn('topic read $SYS/#', resource(docs, 'ConfigMap', '-mosquitto-config')['data']['start.sh'])
        docs = render({'mqtt': {'mosquitto': {'allowLocalSysRead': 'false'}}})
        self.assertNotIn('topic read $SYS/#', resource(docs, 'ConfigMap', '-mosquitto-config')['data']['start.sh'])

    def test_mqtt_queue_budget_uses_decimal_bytes(self):
        docs = render({'mqtt': {'mosquitto': {'maxQueuedBytes': 67108864, 'queueQos0Messages': True,
                                             'autosaveInterval': 5}}})
        config = resource(docs, 'ConfigMap', '-mosquitto-config')['data']['mosquitto.conf']
        self.assertIn('max_queued_bytes 67108864\n', config)
        self.assertIn('queue_qos0_messages true\n', config)
        self.assertIn('autosave_interval 5\n', config)

    def test_listener_names_and_ports_cannot_collide(self):
        listener = {'name': 'legacy', 'port': 19094, 'type': 'internal', 'tls': True}
        for overrides in ([dict(listener, name='internal')], [dict(listener, port=9094)],
                          [listener, listener], [dict(listener, port=70000)]):
            with self.subTest(overrides=overrides):
                result = render({'kafka': {'strimzi': {'additionalListeners': overrides}}}, check=False)
                self.assertNotEqual(result.returncode, 0)
        result = render({'kafka': {'externalAccess': {'enabled': True},
                                  'strimzi': {'additionalListeners': [dict(listener, name='external')]}}}, check=False)
        self.assertNotEqual(result.returncode, 0)

    def test_response_buffer_is_optional_and_validated(self):
        def env(values):
            return {e['name']: e for e in core(render(values))['spec']['template']['spec']['containers'][0]['env']}
        self.assertNotIn('SPRING_HTTP_CODECS_MAX_IN_MEMORY_SIZE', env({}))
        self.assertEqual(env({'core': {'httpCodecsMaxInMemorySize': '20MB'}})
                         ['SPRING_HTTP_CODECS_MAX_IN_MEMORY_SIZE']['value'], '20MB')
        self.assertNotEqual(render({'core': {'httpCodecsMaxInMemorySize': '0MB'}}, check=False).returncode, 0)

    def test_certificate_mode_uses_no_client_secret(self):
        values = {'regionConnectors': {'beFluvius': {'enabled': True,
                  'oauth': {'authenticationMethod': 'certificate'},
                  'tls': {'existingSecret': 'client-certificate'}}}}
        docs = render(values)
        env = {e['name']: e for e in core(docs)['spec']['template']['spec']['containers'][0]['env']}
        self.assertEqual(env['REGION_CONNECTOR_BE_FLUVIUS_OAUTH_AUTHENTICATION_METHOD']['value'], 'certificate')
        self.assertNotIn('REGION_CONNECTOR_BE_FLUVIUS_OAUTH_CLIENT_SECRET', env)
        secret = resource(docs, 'Secret', '-region-connector-secrets')
        self.assertNotIn('fluviusOAuthClientSecret', secret['stringData'])
        values['regionConnectors']['beFluvius']['tls']['existingSecret'] = ''
        self.assertNotEqual(render(values, check=False).returncode, 0)

    def test_existing_postgres_and_ponton_claims_are_referenced(self):
        docs = render({'postgres': {'persistence': {'existingClaim': 'populated-postgres'}},
                       'regionConnectors': {'ponton': {'enabled': True,
                         'persistence': {'existingClaim': 'populated-ponton'}}}})
        pg = resource(docs, 'StatefulSet', '-postgres')['spec']
        self.assertNotIn('volumeClaimTemplates', pg)
        self.assertEqual(pg['template']['spec']['volumes'][0]['persistentVolumeClaim']['claimName'], 'populated-postgres')
        pod = core(docs)['spec']['template']['spec']
        self.assertEqual(next(v for v in pod['volumes'] if v['name'] == 'ponton')
                         ['persistentVolumeClaim']['claimName'], 'populated-ponton')
        self.assertFalse(any(d['kind'] == 'PersistentVolumeClaim' and d['metadata']['name'].endswith('-core-ponton-pvc') for d in docs))

    def test_application_volume_and_listener_survive_rendering(self):
        listener = {'name': 'legacy', 'port': 19094, 'type': 'internal', 'tls': True,
                    'authentication': {'type': 'scram-sha-512'},
                    'configuration': {'brokers': [{'broker': 0, 'advertisedHost': 'legacy.test', 'advertisedPort': 443}]}}
        values = {'core': {'extraVolumes': [{'name': 'patched-core', 'configMap': {'name': 'patched-core'}}],
                           'extraVolumeMounts': [{'name': 'patched-core', 'mountPath': '/opt/core/lib/core.jar', 'subPath': 'core.jar'}]},
                  'kafka': {'strimzi': {'jvmOptions': {'-Xmx': '384m'}, 'additionalListeners': [listener],
                            'entityOperator': {'topicOperator': {'resources': {'limits': {'memory': '192Mi'}}}}}}}
        docs = render(values)
        pod = core(docs)['spec']['template']['spec']
        self.assertIn(values['core']['extraVolumes'][0], pod['volumes'])
        self.assertIn(values['core']['extraVolumeMounts'][0], pod['containers'][0]['volumeMounts'])
        kafka = resource(docs, 'Kafka', '-kafka')['spec']
        self.assertIn(listener, kafka['kafka']['listeners'])
        self.assertEqual(kafka['kafka']['jvmOptions']['-Xmx'], '384m')
        self.assertEqual(kafka['entityOperator']['topicOperator']['resources']['limits']['memory'], '192Mi')
        for name in ('ponton', 'postgres-root-cert', 'aansluiting-keystore'):
            values['core']['extraVolumes'][0]['name'] = name
            self.assertNotEqual(render(values, check=False).returncode, 0)


if __name__ == '__main__':
    unittest.main()
