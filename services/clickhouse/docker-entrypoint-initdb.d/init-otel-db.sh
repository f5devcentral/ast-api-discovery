#!/bin/bash
set -e

clickhouse client <<-EOSQL
    CREATE DATABASE IF NOT EXISTS otel;
EOSQL

# Create the null log table for incoming otel data
clickhouse client <<-EOSQL
    CREATE TABLE IF NOT EXISTS otel.otel_logs_null
    (
        Timestamp DateTime64(9) CODEC(Delta(8), ZSTD(1)),
        TraceId String CODEC(ZSTD(1)),
        SpanId String CODEC(ZSTD(1)),
        TraceFlags UInt8,
        SeverityText LowCardinality(String) CODEC(ZSTD(1)),
        SeverityNumber UInt8,
        ServiceName LowCardinality(String) CODEC(ZSTD(1)),
        Body String CODEC(ZSTD(1)),
        ResourceSchemaUrl LowCardinality(String) CODEC(ZSTD(1)),
        ResourceAttributes Map(LowCardinality(String), String) CODEC(ZSTD(1)),
        ScopeSchemaUrl LowCardinality(String) CODEC(ZSTD(1)),
        ScopeName String CODEC(ZSTD(1)),
        ScopeVersion LowCardinality(String) CODEC(ZSTD(1)),
        ScopeAttributes Map(LowCardinality(String), String) CODEC(ZSTD(1)),
        LogAttributes Map(LowCardinality(String), String) CODEC(ZSTD(1)),
    )
    ENGINE = Null;
EOSQL

# Create the actual table which logs will be stored in
clickhouse client <<-EOSQL
    CREATE TABLE IF NOT EXISTS otel.cbip_access_logs
    (
        Timestamp DateTime,
        path String CODEC(ZSTD(1)),
        hasAuthorization Bool,
        hasSensitiveHeaders Bool,
        hasSensitivePayload Bool,
        httpv LowCardinality(String) CODEC(ZSTD(1)),
        reqCType LowCardinality(String) CODEC(ZSTD(1)),
        resCType LowCardinality(String) CODEC(ZSTD(1)),
        host LowCardinality(String) CODEC(ZSTD(1)),
        hostname LowCardinality(String) CODEC(ZSTD(1)),
        method LowCardinality(String) CODEC(ZSTD(1)),
        sensitiveDataTypes LowCardinality(String) CODEC(ZSTD(1)),
        statusCode UInt16,
    )
    ENGINE = MergeTree
    ORDER BY (Timestamp)
    TTL Timestamp + INTERVAL 3 HOUR;
EOSQL

# Create the Materialized View that populates the access log table from incoming
# null logs.
clickhouse client <<-EOSQL
    CREATE MATERIALIZED VIEW IF NOT EXISTS otel.cbip_access_log_mv TO otel.cbip_access_logs AS
    SELECT  Timestamp::DateTime AS Timestamp,
    LogAttributes['hostname'] AS hostname,
    path(LogAttributes['uri']) AS path,
    LogAttributes['host'] AS host,
    LogAttributes['hasAuthorization'] AS hasAuthorization,
    LogAttributes['sensitiveInHeaders'] AS hasSensitiveHeaders,
    LogAttributes['sensitiveInPayload'] AS hasSensitivePayload,
    LogAttributes['sensitiveDataTypes'] AS sensitiveDataTypes,
    LogAttributes['method'] AS method,
    LogAttributes['statusCode'] AS statusCode,
    LogAttributes['reqCType'] AS reqCType,
    LogAttributes['resCType'] AS resCType,
    LogAttributes['httpv'] AS httpv
    FROM otel.otel_logs_null;
EOSQL