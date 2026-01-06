-- ============================================================================
-- SCRIPT 3: Snowflake Time Travel Demo
-- ============================================================================
-- Purpose: Demonstrate Snowflake's Time Travel feature for data recovery
-- Prerequisites: Run 01_setup_healthcare_data.sql first
-- Documentation: https://docs.snowflake.com/en/user-guide/data-time-travel
-- ============================================================================

-- NOTE: This demo assumes Business Critical Edition
-- - Time Travel (1 day) is available in all Snowflake editions
-- - Time Travel > 1 day requires Enterprise or Business Critical Edition

-- ============================================================================
-- PERMISSIONS REQUIRED
-- ============================================================================
-- Time Travel is enabled by default for all tables
-- Requires ACCOUNTADMIN or ownership of objects to:
--   - Configure retention periods
--   - Restore data from historical versions

USE ROLE ACCOUNTADMIN;
USE DATABASE healthcare_demo;
USE SCHEMA patient_data;

-- ============================================================================
-- PART 1: UNDERSTANDING TIME TRAVEL
-- ============================================================================
-- Time Travel allows you to access historical data:
--   - Query data as it existed at a specific point in time
--   - Restore deleted or modified data
--   - Undrop deleted tables, schemas, or databases
--   - Create audit trails of data changes
--
-- Retention Periods (DATA_RETENTION_TIME_IN_DAYS):
--   - Standard Edition: 1 day (default and maximum)
--   - Enterprise/Business Critical: 1 day (default), up to 90 days (max)
--
-- After Time Travel expires, data enters Fail-safe for 7 additional days
-- Fail-safe recovery requires contacting Snowflake Support
--
-- Time Travel vs Backups:
--   - Time Travel: Quick recovery (hours to days), automatic, no setup
--   - Backups: Long-term retention (years), selective, immutable storage
-- ============================================================================

-- ============================================================================
-- PART 2: CONFIGURE TIME TRAVEL RETENTION
-- ============================================================================

-- View current retention settings
SHOW TABLES IN SCHEMA patient_data;

-- Set Time Travel retention for our tables
-- 7 days is a good balance for demo purposes (requires Enterprise+)
ALTER TABLE patients 
    SET DATA_RETENTION_TIME_IN_DAYS = 7;

ALTER TABLE medical_records 
    SET DATA_RETENTION_TIME_IN_DAYS = 7;

-- You can also set retention at schema level (applies to all tables)
ALTER SCHEMA patient_data 
    SET DATA_RETENTION_TIME_IN_DAYS = 7;

-- View updated retention settings
SELECT 
    table_name,
    retention_time
FROM information_schema.tables
WHERE table_schema = 'PATIENT_DATA'
    AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- ============================================================================
-- PART 3: QUERY HISTORICAL DATA
-- ============================================================================
-- Time Travel lets you query data as it existed in the past

-- Capture current state
SELECT 'Current State' AS step, 
       COUNT(*) AS patient_count,
       CURRENT_TIMESTAMP() AS current_time
FROM patients;

-- Store timestamp for later use
SET timestamp_before_changes = (SELECT CURRENT_TIMESTAMP());

-- Make some changes to the data
UPDATE patients 
SET address = '999 Updated Street', city = 'Springfield'
WHERE patient_id = 5;

INSERT INTO patients (first_name, last_name, date_of_birth, gender, email, phone, address, city, state, zip_code, insurance_provider)
VALUES ('Test', 'Patient', '1995-01-01', 'Male', 'test@email.com', '555-9999', '111 Test St', 'Boston', 'MA', '02101', 'Test Insurance');

DELETE FROM patients WHERE patient_id = 10;

-- View current state (after changes)
SELECT 'After Changes' AS step, patient_id, first_name, last_name, address, city
FROM patients 
WHERE patient_id IN (5, 10) OR last_name = 'Patient'
ORDER BY patient_id;

-- Use Time Travel to query data BEFORE our changes
SELECT 'Before Changes (Time Travel)' AS step, patient_id, first_name, last_name, address, city
FROM patients AT(TIMESTAMP => $timestamp_before_changes)
WHERE patient_id IN (5, 10)
ORDER BY patient_id;

-- ============================================================================
-- PART 4: RESTORE DELETED ROWS
-- ============================================================================
-- Restore patient 10 who was accidentally deleted

-- Verify patient 10 is missing
SELECT 'Patient 10 Status' AS check_type, 
       COUNT(*) AS exists_count 
FROM patients 
WHERE patient_id = 10;

-- Restore the deleted row using Time Travel
INSERT INTO patients
SELECT * 
FROM patients AT(TIMESTAMP => $timestamp_before_changes)
WHERE patient_id = 10;

-- Verify restoration
SELECT 'After Restore' AS status, patient_id, first_name, last_name, email
FROM patients 
WHERE patient_id = 10;

-- ============================================================================
-- PART 5: COMPARE DATA CHANGES (AUDIT TRAIL)
-- ============================================================================
-- Time Travel is powerful for auditing data changes

-- Compare current vs historical data for patient 5
SELECT 
    'BEFORE UPDATE' AS data_state,
    patient_id,
    first_name,
    last_name,
    address,
    city
FROM patients AT(TIMESTAMP => $timestamp_before_changes)
WHERE patient_id = 5

UNION ALL

SELECT 
    'AFTER UPDATE' AS data_state,
    patient_id,
    first_name,
    last_name,
    address,
    city
FROM patients
WHERE patient_id = 5;

-- Find all changes to patients table
SELECT 
    PRESENT.patient_id,
    PRESENT.first_name || ' ' || PRESENT.last_name AS patient_name,
    HISTORICAL.address AS old_address,
    PRESENT.address AS new_address,
    HISTORICAL.city AS old_city,
    PRESENT.city AS new_city
FROM patients PRESENT
LEFT JOIN patients AT(TIMESTAMP => $timestamp_before_changes) HISTORICAL
    ON PRESENT.patient_id = HISTORICAL.patient_id
WHERE 
    PRESENT.address != HISTORICAL.address 
    OR PRESENT.city != HISTORICAL.city
    OR HISTORICAL.patient_id IS NULL;  -- New patients

-- ============================================================================
-- PART 6: UNDROP DELETED OBJECTS
-- ============================================================================
-- Time Travel can restore dropped tables, schemas, and databases

-- Create a test table
CREATE OR REPLACE TABLE test_table AS 
SELECT * FROM patients LIMIT 5;

-- Verify it exists
SELECT 'Test Table Created' AS status, COUNT(*) AS row_count 
FROM test_table;

-- Store timestamp before drop
SET timestamp_before_drop = (SELECT CURRENT_TIMESTAMP());

-- Accidentally drop the table
DROP TABLE test_table;

-- Try to query it - this will fail (commented out to avoid error)
SELECT * FROM test_table;

-- View dropped tables
SHOW TABLES HISTORY LIKE 'test_table' IN SCHEMA patient_data;

-- UNDROP the table
UNDROP TABLE test_table;

-- Verify restoration
SELECT 'Table Undropped' AS status, COUNT(*) AS row_count 
FROM test_table;

-- Clean up
DROP TABLE test_table;

-- ============================================================================
-- PART 7: CLONE FROM HISTORICAL POINT
-- ============================================================================
-- Zero-copy cloning with Time Travel enables powerful workflows

-- Create a clone of patients table as it was before our changes
CREATE OR REPLACE TABLE patients_historical 
    CLONE patients 
    AT(TIMESTAMP => $timestamp_before_changes);

-- Compare record counts
SELECT 'Current Table' AS table_type, COUNT(*) AS record_count FROM patients
UNION ALL
SELECT 'Historical Clone' AS table_type, COUNT(*) AS record_count FROM patients_historical;

-- Cloning is a zero-copy operation initially
-- Great for creating dev/test environments from production

-- Clean up
DROP TABLE patients_historical;

-- ============================================================================
-- PART 8: ROLLBACK MULTIPLE CHANGES
-- ============================================================================
-- Rollback unwanted changes to an entire table

-- Make multiple problematic changes
UPDATE medical_records 
SET notes = 'DATA CORRUPTED - ERROR' 
WHERE record_id IN (1, 2, 3);

-- View the corrupted data
SELECT 'Corrupted Data' AS status, record_id, diagnosis_description, notes 
FROM medical_records 
WHERE record_id IN (1, 2, 3);

-- Rollback using Time Travel - replace entire table with historical version
CREATE OR REPLACE TABLE medical_records AS
SELECT * FROM medical_records 
AT(TIMESTAMP => $timestamp_before_changes);

-- Verify rollback
SELECT 'After Rollback' AS status, record_id, diagnosis_description, notes 
FROM medical_records 
WHERE record_id IN (1, 2, 3);

-- ============================================================================
-- PART 9: RECOVER FROM MASS DELETE
-- ============================================================================
-- Demonstrate recovery from catastrophic deletion

-- Create a backup timestamp
SET timestamp_before_mass_delete = (SELECT CURRENT_TIMESTAMP());

-- Simulate accidental mass deletion
DELETE FROM medical_records WHERE record_id > 0;  -- Deletes ALL rows

-- Verify the disaster
SELECT 'After Mass Delete' AS status, COUNT(*) AS remaining_rows 
FROM medical_records;

-- Recover all data using Time Travel
INSERT INTO medical_records
SELECT * FROM medical_records AT(TIMESTAMP => $timestamp_before_mass_delete);

-- Verify recovery
SELECT 'After Recovery' AS status, COUNT(*) AS recovered_rows 
FROM medical_records;

-- ============================================================================
-- PART 10: MONITORING TIME TRAVEL
-- ============================================================================

-- View query history to see what changed
SELECT *
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY())
WHERE execution_status = 'SUCCESS'
    AND database_name = 'HEALTHCARE_DEMO'
ORDER BY start_time DESC
LIMIT 10;

-- View Time Travel storage costs (requires ACCOUNTADMIN)
SELECT 
     table_name,
     active_bytes / 1024 / 1024 / 1024 AS active_gb,
     time_travel_bytes / 1024 / 1024 / 1024 AS time_travel_gb,
     failsafe_bytes / 1024 / 1024 / 1024 AS failsafe_gb
 FROM snowflake.account_usage.table_storage_metrics
 WHERE table_catalog = 'HEALTHCARE_DEMO'
     AND table_schema = 'PATIENT_DATA'
 ORDER BY time_travel_bytes DESC;

-- ============================================================================
-- PART 11: BEST PRACTICES
-- ============================================================================
-- 1. Set appropriate retention periods:
--    - Critical tables: Maximum retention (90 days with Enterprise+)
--    - Temporary/staging tables: Minimal retention (0 or 1 day)
--    - Balance recovery needs with storage costs
--
-- 2. Use Time Travel for:
--    - Quick recovery from recent mistakes (hours/days ago)
--    - Auditing recent data changes
--    - Creating point-in-time clones for dev/test
--    - Querying historical data for analysis
--
-- 3. Use Backups (not Time Travel) for:
--    - Long-term retention (> 90 days)
--    - Regulatory compliance requiring immutable storage
--    - Protection against ransomware
--    - Selective backups of only critical tables
--
-- 4. Test recovery procedures:
--    - Practice Time Travel queries regularly
--    - Document recovery runbooks
--    - Train team on recovery commands
--
-- 5. Monitor storage costs:
--    - Review TIME_TRAVEL_BYTES in TABLE_STORAGE_METRICS
--    - Reduce retention for frequently changing tables
--    - Consider data lifecycle carefully
--
-- 6. Understand limitations:
--    - Time Travel doesn't prevent deletion by ACCOUNTADMIN
--    - Data permanently deleted after retention + fail-safe period
--    - Fail-safe requires Snowflake Support intervention
--    - GDPR deletion requests may require retention adjustment
--
-- 7. Combine features for complete BCDR:
--    - Time Travel: Day-to-day recovery (automatic)
--    - Backups: Long-term protection (scheduled)
--    - Replication: Geographic redundancy
--    - Failover Groups: Automated disaster recovery
-- ============================================================================

-- ============================================================================
-- DEMO COMPLETE!
-- ============================================================================
-- You've learned how to:
--   ✓ Configure Time Travel retention periods
--   ✓ Query historical data using AT(TIMESTAMP)
--   ✓ Restore deleted rows from historical versions
--   ✓ Create audit trails by comparing data over time
--   ✓ Undrop accidentally deleted tables
--   ✓ Clone tables from specific points in time
--   ✓ Rollback unwanted changes
--   ✓ Recover from mass deletions
--   ✓ Monitor Time Travel usage
--
-- You've completed the full BCDR demo series:
--   ✓ Script 1: Created healthcare dataset
--   ✓ Script 2: Learned Snowflake backups
--   ✓ Script 3: Learned Time Travel
--
-- For production use, combine Time Travel + Backups + Replication
-- for comprehensive business continuity and disaster recovery!
-- ============================================================================
