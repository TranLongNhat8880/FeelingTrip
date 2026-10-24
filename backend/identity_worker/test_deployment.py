"""Deployment health must work without opening identity endpoints to probes."""
import importlib.util
import os
from pathlib import Path
import unittest
from unittest.mock import patch


class DeploymentTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location(
            'identity_deployment_test_app', Path(__file__).with_name('app.py'))
        cls.worker = importlib.util.module_from_spec(spec)
        # These tests cover HTTP/server wiring without requiring model weights.
        with patch.dict(os.environ, {'EKYC_WORKER_KEY': 'test-only-key-' * 4}), \
                patch('engine.Engine'):
            spec.loader.exec_module(cls.worker)

    def setUp(self):
        self.client = self.worker.app.test_client()

    def test_railway_probe_is_minimal_and_needs_no_key(self):
        response = self.client.get('/ready')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.get_json(), {'ready': True})
        self.assertEqual(self.client.head('/ready').status_code, 200)

    def test_probe_exception_does_not_open_identity_endpoints(self):
        self.assertEqual(self.client.get('/health').status_code, 401)
        self.assertEqual(self.client.post('/verify').status_code, 401)
        self.assertEqual(self.client.post('/ready').status_code, 401)
        self.assertEqual(self.client.get('/health', headers={
            'X-Worker-Key': 'wrong-key'}).status_code, 401)
        response = self.client.get('/health', headers={
            'X-Worker-Key': self.worker.key})
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.get_json()['ready'])

    def test_railway_and_local_bindings_use_configured_port(self):
        for host, expected in [('*', '*:54321'),
                               ('::', '[::]:54321'),
                               ('127.0.0.1', '127.0.0.1:54321')]:
            with self.subTest(host=host), \
                    patch.dict(os.environ, {'HOST': host, 'PORT': '54321'}), \
                    patch('waitress.serve') as serve:
                self.worker.run()
                self.assertEqual(serve.call_args.kwargs['listen'], expected)

    def test_waitress_wildcard_opens_ipv4_and_ipv6(self):
        import socket
        from waitress import create_server
        if not socket.has_ipv6:
            self.skipTest('IPv6 unavailable on this host')
        server = create_server(self.worker.app, listen='*:0')
        try:
            hosts = {host for host, _ in server.effective_listen}
            self.assertIn('0.0.0.0', hosts)
            self.assertIn('::', hosts)
        finally:
            server.close()
            server.task_dispatcher.shutdown()


if __name__ == '__main__':
    unittest.main()
