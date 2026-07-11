CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "timescaledb" CASCADE;

-- Core table for high-frequency transient error ingestion
CREATE TABLE node_failure_events (
    event_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    node_id VARCHAR(128) NOT NULL,
    service_name VARCHAR(128) NOT NULL,
    stack_type VARCHAR(64) NOT NULL, -- e.g., 'Rust', 'Go', 'Node.js'
    error_code VARCHAR(64) NOT NULL,
    error_message TEXT,
    severity INTEGER CHECK (severity BETWEEN 1 AND 5),
    metadata JSONB,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Optimize for time-series queries (24-hour retention focus)
SELECT create_hypertable('node_failure_events', 'occurred_at');

-- Materialized View for WebGL Heatmap Aggregation
-- Aggregates errors into 1-minute buckets for the 24-hour visualizer
CREATE MATERIALIZED VIEW heatmap_aggregation_1m
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 minute', occurred_at) AS bucket,
    service_name,
    stack_type,
    COUNT(*) AS failure_count,
    AVG(severity) AS avg_severity
FROM node_failure_events
GROUP BY bucket, service_name, stack_type
WITH NO DATA;

-- Materialized View for Node-specific density mapping
CREATE MATERIALIZED VIEW node_density_map_5m
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('5 minutes', occurred_at) AS bucket,
    node_id,
    COUNT(*) AS event_count
FROM node_failure_events
GROUP BY bucket, node_id
WITH NO DATA;

-- Indices for rapid UI filtering
CREATE INDEX idx_events_service_stack ON node_failure_events (service_name, stack_type, occurred_at DESC);
CREATE INDEX idx_events_node_lookup ON node_failure_events (node_id, occurred_at DESC);

-- Refresh policy to keep heatmap data up to date (every 2 minutes)
SELECT add_continuous_aggregate_policy('heatmap_aggregation_1m',
    start_offset => INTERVAL '2 days',
    end_offset => INTERVAL '1 minute',
    schedule_interval => INTERVAL '2 minutes');

-- Retention policy: Since this is an ephemeral visualization tool, 
-- we drop raw data after 24 hours to maintain hardware performance.
SELECT add_retention_policy('node_failure_events', INTERVAL '24 hours');

-- User permissions for the API layer
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'ephema_viz_user') THEN
        CREATE ROLE ephema_viz_user WITH LOGIN PASSWORD 'ephema_secure_pass';
    END IF;
END
$$;

GRANT SELECT ON ALL TABLES IN SCHEMA public TO ephema_viz_user;
GRANT INSERT ON node_failure_events TO ephema_viz_user;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO ephema_viz_user;

-- Helper function for API to fetch current heatmap state
CREATE OR REPLACE FUNCTION get_active_heatmap_data(lookback_hours INTEGER DEFAULT 24)
RETURNS TABLE (
    bucket TIMESTAMPTZ,
    service_name VARCHAR,
    stack_type VARCHAR,
    failure_count BIGINT,
    normalized_severity FLOAT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        h.bucket, 
        h.service_name, 
        h.stack_type, 
        h.failure_count,
        (h.avg_severity / 5.0) as normalized_severity
    FROM heatmap_aggregation_1m h
    WHERE h.bucket > NOW() - (lookback_hours * INTERVAL '1 hour')
    ORDER BY h.bucket ASC;
END;
$$ LANGUAGE plpgsql;