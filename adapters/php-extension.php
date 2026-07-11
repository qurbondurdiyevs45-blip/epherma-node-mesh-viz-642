<?php

/**
 * EphemeralNode Mesh Viz - PHP Failure Adapter
 * 
 * This adapter captures fatal runtime errors and uncaught exceptions,
 * streaming them to the EphemeralNode observability collector.
 */

declare(strict_types=1);

namespace EphemeralNode;

class FailureReporter
{
    private string $endpoint;
    private string $serviceName;
    private string $nodeId;

    public function __construct(string $endpoint, string $serviceName)
    {
        $this->endpoint = $endpoint;
        $this->serviceName = $serviceName;
        $this->nodeId = gethostname() ?: 'unknown-php-node';
        
        $this->registerHandlers();
    }

    private function registerHandlers(): void
    {
        // Handle fatal errors that bypass standard try/catch blocks
        register_shutdown_function([$this, 'handleShutdown']);

        // Handle uncaught exceptions
        set_exception_handler([$this, 'handleException']);
    }

    public function handleException(\Throwable $exception): void
    {
        $payload = [
            'timestamp' => microtime(true),
            'service'   => $this->serviceName,
            'node_id'   => $this->nodeId,
            'type'      => get_class($exception),
            'message'   => $exception->getMessage(),
            'file'      => $exception->getFile(),
            'line'      => $exception->getLine(),
            'severity'  => 'FATAL',
            'stack'     => $exception->getTraceAsString(),
            'runtime'   => 'PHP ' . PHP_VERSION
        ];

        $this->dispatch($payload);
    }

    public function handleShutdown(): void
    {
        $error = error_get_last();
        
        // Check if the script stopped due to a fatal error types
        $fatalTypes = [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR, E_USER_ERROR];
        
        if ($error !== null && in_array($error['type'], $fatalTypes)) {
            $payload = [
                'timestamp' => microtime(true),
                'service'   => $this->serviceName,
                'node_id'   => $this->nodeId,
                'type'      => 'FatalError',
                'message'   => $error['message'],
                'file'      => $error['file'],
                'line'      => $error['line'],
                'severity'  => 'CRITICAL',
                'runtime'   => 'PHP ' . PHP_VERSION
            ];

            $this->dispatch($payload);
        }
    }

    private function dispatch(array $data): void
    {
        $json = json_encode($data);
        
        $ch = curl_init($this->endpoint);
        curl_setopt($ch, CURLOPT_POSTFIELDS, $json);
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'Content-Type: application/json',
            'X-Ephemeral-Source: php-adapter'
        ]);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_TIMEOUT_MS, 500); // Non-blocking as possible
        curl_setopt($ch, CURLOPT_CONNECTTIMEOUT_MS, 200);

        curl_exec($ch);
        curl_close($ch);
    }
}

// Global initialization using environment variables for configuration
(function() {
    $endpoint = getenv('EPHEMERAL_NODE_COLLECTOR_URL') ?: 'http://localhost:8080/ingest';
    $service = getenv('EPHEMERAL_NODE_SERVICE_NAME') ?: 'php-app';

    new FailureReporter($endpoint, $service);
})();