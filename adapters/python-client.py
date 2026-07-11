import asyncio
import json
import socket
import time
import signal
import sys
import logging
from typing import Dict, Any, Optional
from datetime import datetime

logging.basicConfig(level=logging.INFO, format='%(asctime)s - EPHERMANODE - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class EphemeraNodeClient:
    """
    Asynchronous Python client for EphemeraNode Mesh Viz.
    Reports process health, transient failures, and heartbeat metrics via UDP
    to ensure non-blocking, high-performance observability.
    """

    def __init__(self, 
                 service_name: str, 
                 collector_host: str = "127.0.0.1", 
                 collector_port: int = 8888,
                 node_id: Optional[str] = None):
        self.service_name = service_name
        self.collector_host = collector_host
        self.collector_port = collector_port
        self.node_id = node_id or f"{service_name}-{socket.gethostname()}-{id(self)}"
        self.running = False
        self._sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self._loop = asyncio.get_event_loop()

    def _send_payload(self, event_type: str, data: Dict[str, Any]):
        payload = {
            "v": "1.0",
            "ts": datetime.utcnow().isoformat() + "Z",
            "node_id": self.node_id,
            "service": self.service_name,
            "type": event_type,
            "payload": data
        }
        try:
            message = json.dumps(payload).encode('utf-8')
            self._sock.sendto(message, (self.collector_host, self.collector_port))
        except Exception as e:
            logger.error(f"Failed to emit metrics: {e}")

    def report_error(self, error_code: str, severity: float = 1.0, metadata: Dict = None):
        """Reports a transient failure for the heat-map."""
        self._send_payload("FAILURE", {
            "code": error_code,
            "severity": severity,
            "meta": metadata or {}
        })

    async def _heartbeat_loop(self, interval: int = 5):
        logger.info(f"EphemeraNode Heartbeat started for {self.node_id}")
        while self.running:
            self._send_payload("HEARTBEAT", {
                "uptime": time.process_time(),
                "mem_usage": sys.getsizeof(self) 
            })
            await asyncio.sleep(interval)

    def _handle_exit(self, sig, frame):
        logger.info(f"Received signal {sig}. Reporting node shutdown...")
        self._send_payload("SHUTDOWN", {"reason": "signal", "signal": sig})
        self.running = False
        sys.exit(0)

    def start(self):
        """Registers signal handlers and starts the heartbeat background task."""
        self.running = True
        
        # Register standard library signals for process health reporting
        for sig in (signal.SIGINT, signal.SIGTERM):
            signal.signal(sig, self._handle_exit)

        self._send_payload("STARTUP", {
            "pid": sys.executable,
            "platform": sys.platform,
            "version": sys.version
        })
        
        self._loop.create_task(self._heartbeat_loop())

async def example_usage():
    # Initialize the client
    client = EphemeraNodeClient(
        service_name="payment-processor-py",
        collector_host="127.0.0.1",
        collector_port=8888
    )
    
    # Start the async monitoring
    client.start()

    # Simulate application logic with transient failures
    try:
        count = 0
        while True:
            await asyncio.sleep(2)
            count += 1
            if count % 5 == 0:
                client.report_error("ECONNRESET", 0.8, {"target": "auth-db-cluster"})
            if count % 12 == 0:
                client.report_error("TIMEOUT", 0.5, {"path": "/api/v1/verify"})
    except KeyboardInterrupt:
        pass

if __name__ == "__main__":
    try:
        asyncio.run(example_usage())
    except KeyboardInterrupt:
        pass