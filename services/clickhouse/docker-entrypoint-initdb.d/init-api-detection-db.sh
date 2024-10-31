#!/bin/bash
set -e

clickhouse client -nm <<-EOSQL
    CREATE DATABASE IF NOT EXISTS api_detection;
    CREATE TABLE IF NOT EXISTS api_detection.detected_api_endpoints 
    ( 
        Timestamp DateTime, 
        path String CODEC(ZSTD(1)), 
        host LowCardinality(String) CODEC(ZSTD(1)), 
        method LowCardinality(String) CODEC(ZSTD(1)), 
        isAuthenticated LowCardinality(String) CODEC(ZSTD(1)), 
        accesses UInt64,
        auth_headers_seen UInt64,
        auth_errors UInt64,
        sensitive_headers_seen UInt64,
        sensitive_payload_seen UInt64,
        ssn_seen UInt64,
        dob_seen UInt64,
        creditcard_seen UInt64,
        email_seen UInt64,
    ) 
    ENGINE = MergeTree 
    ORDER BY (accesses, Timestamp)
    TTL Timestamp + INTERVAL 4 HOUR;
    CREATE TABLE IF NOT EXISTS api_detection.stats 
    ( 
        lastProcessTime DateTime,
        nextProcesTime DateTime,
        lastProcessedRecords UInt64,
        lastProcessLogTableSize UInt64,
    ) 
    ENGINE = MergeTree 
    ORDER BY (lastProcessTime);
EOSQL
