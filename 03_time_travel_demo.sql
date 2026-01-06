-- ============================================================================
-- SCRIPT 3: Snowflake Time Travel Demo
-- ============================================================================
-- Purpose: Demonstrate Snowflake's Time Travel feature for data recovery
-- Prerequisites: Run 01_setup_healthcare_data.sql first
-- Documentation: https://docs.snowflake.com/en/user-guide/data-time-travel
-- ============================================================================

USE DATABASE healthcare_demo;
USE SCHEMA patient_data;

-- ============================================================================
-- PART 1: UNDERSTANDING TIME TRAVEL
-- ============================================================================
-- Time Travel allows you to access historical data that has been:
--   - Updated (old values before UPDATE)
--   - Deleted (rows before DELETE)
--   - Dropped (entire tables, schemas, or databases)
--
-- Key Features:
--   - Query data as it existed at a specific point in time
--   - Restore deleted or modified data
--   - Clone tables from a historical point
--   - Audit data changes
--
-- Retention Periods (DATA_RETENTION_TIME_IN_DAYS):
--   - Standard Edition: 1 day (default), up to 1 day (max)
--   - Enterprise Edition: 1 day (default), up to 90 days (max)
--   - Business Critical: 1 day (default), up to 90 days (max)
--
-- After Time Travel period expires, data enters Fail-safe (7 additional days)
-- Fail-safe is for disaster recovery by Snowflake Support only
-- ============================================================================

-- ============================================================================
-- PART 2: CONFIGURE TIME TRAVEL RETENTION
-- ============================================================================

-- View current retention settings for our tables
SHOW TABLES LIKE '%' IN SCHEMA patient_data;

-- Set Time Travel retention to maximum for our tables
-- (Requires Enterprise Edition or higher for > 1 day)
-- For this demo, we'll set to 7 days (adjust based on your edition)

ALTER TABLE patients 
    SET DATA_RETENTION_TIME_IN_DAYS = 7;

ALTER TABLE medical_records 
    SET DATA_RETENTION_TIME_IN_DAYS = 7;

ALTER TABLE prescriptions 
    SET DATA_RETENTION_TIME_IN_DAYS = 7;

ALTER TABLE lab_results 
    SET DATA_RETENTION_TIME_IN_DAYS = 7;

-- You can also set retention at database or schema level
-- This applies to all objects within that database/schema
ALTER SCHEMA patient_data 
    SET DATA_RETENTION_TIME_IN_DAYS = 7;

-- View updated retention settings
SELECT 
    table_catalog,
    table_schema,
    table_name,
    retention_time
FROM information_schema.tables
WHERE table_schema = 'PATIENT_DATA'
    AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- ============================================================================
-- PART 3: SCENARIO 1 - QUERY HISTORICAL DATA
-- ============================================================================
-- Time Travel lets you query data as it existed in the past

-- First, let's capture the current state and timestamp
SELECT 'Current State - Step 1' AS step, 
       COUNT(*) AS patient_count,
       CURRENT_TIMESTAMP()::TIMESTAMP_NTZ AS current_time
FROM patients;

-- Store this timestamp for later use
SET timestamp_before_changes = (SELECT CURRENT_TIMESTAMP());

-- Wait a moment to ensure timestamp separation
CALL SYSTEM$WAIT(2);

-- Now let's make some changes to our data
UPDATE patients 
SET address = '999 Updated Street', city = 'Springfield'
WHERE patient_id = 5;

INSERT INTO patients (first_name, last_name, date_of_birth, gender, email, phone, address, city, state, zip_code, insurance_provider)
VALUES ('New', 'Patient', '1995-01-01', 'Male', 'new.patient@email.com', '555-9999', '111 New St', 'Boston', 'MA', '02101', 'Blue Cross');

DELETE FROM patients WHERE patient_id = 10;

-- View current state (after changes)
SELECT 'Current State - Step 2' AS step, * 
FROM patients 
WHERE patient_id IN (5, 10) OR last_name = 'Patient'
ORDER BY patient_id;

-- Now let's use Time Travel to see how the data looked BEFORE our changes
-- Method 1: Query using TIMESTAMP
SELECT 'Historical State (using TIMESTAMP)' AS step, * 
FROM patients AT(TIMESTAMP => $timestamp_before_changes)
WHERE patient_id IN (5, 10)
ORDER BY patient_id;

-- Method 2: Query using OFFSET (seconds ago)
-- This queries data as it was 30 seconds ago
SELECT 'Historical State (30 seconds ago)' AS step, * 
FROM patients AT(OFFSET => -30)
WHERE patient_id IN (5, 10)
ORDER BY patient_id;

-- Method 3: Query using STATEMENT (query ID)
-- First, get the query ID of a previous query
SET query_id_before_changes = (
    SELECT query_id 
    FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY())
    WHERE query_text LIKE '%Current State - Step 1%'
    ORDER BY start_time DESC
    LIMIT 1
);

-- Query data as it was when that statement was executed
SELECT 'Historical State (using QUERY_ID)' AS step, * 
FROM patients BEFORE(STATEMENT => $query_id_before_changes)
WHERE patient_id IN (5, 10)
ORDER BY patient_id;

-- ============================================================================
-- PART 4: SCENARIO 2 - RESTORE DELETED ROWS
-- ============================================================================
-- Let's restore patient 10 who was accidentally deleted

-- Verify patient 10 is currently missing
SELECT COUNT(*) AS patient_10_exists 
FROM patients 
WHERE patient_id = 10;

-- Restore the deleted row using Time Travel
INSERT INTO patients
SELECT * 
FROM patients AT(TIMESTAMP => $timestamp_before_changes)
WHERE patient_id = 10;

-- Verify restoration
SELECT 'Restored Patient' AS status, * 
FROM patients 
WHERE patient_id = 10;

-- ============================================================================
-- PART 5: SCENARIO 3 - COMPARE DATA CHANGES (AUDIT TRAIL)
-- ============================================================================
-- Time Travel is powerful for auditing - see exactly what changed

-- Compare current vs historical data for patient 5
SELECT 
    'BEFORE' AS data_state,
    patient_id,
    first_name,
    last_name,
    address,
    city,
    updated_at
FROM patients AT(TIMESTAMP => $timestamp_before_changes)
WHERE patient_id = 5

UNION ALL

SELECT 
    'AFTER' AS data_state,
    patient_id,
    first_name,
    last_name,
    address,
    city,
    updated_at
FROM patients
WHERE patient_id = 5;

-- Advanced: Find all changes to patients in the last hour
-- This query identifies which patients were modified
SELECT 
    CURRENT.patient_id,
    CURRENT.first_name || ' ' || CURRENT.last_name AS patient_name,
    HISTORICAL.address AS old_address,
    CURRENT.address AS new_address,
    HISTORICAL.city AS old_city,
    CURRENT.city AS new_city,
    CURRENT.updated_at AS change_timestamp
FROM patients CURRENT
LEFT JOIN patients AT(OFFSET => -3600) HISTORICAL  -- 3600 seconds = 1 hour ago
    ON CURRENT.patient_id = HISTORICAL.patient_id
WHERE 
    CURRENT.address != HISTORICAL.address 
    OR CURRENT.city != HISTORICAL.city
    OR HISTORICAL.patient_id IS NULL;  -- New patients

-- ============================================================================
-- PART 6: SCENARIO 4 - RESTORE ENTIRE TABLE (UNDROP)
-- ============================================================================
-- Time Travel can restore dropped tables

-- First, let's create a test table and populate it
CREATE OR REPLACE TABLE test_prescriptions AS 
SELECT * FROM prescriptions;

-- Verify it exists
SELECT 'Test table exists' AS status, COUNT(*) AS record_count 
FROM test_prescriptions;

-- Store timestamp before drop
SET timestamp_before_drop = (SELECT CURRENT_TIMESTAMP());

CALL SYSTEM$WAIT(2);

-- OOPS! Accidentally drop the table
DROP TABLE test_prescriptions;

-- Try to query it - this will fail
-- SELECT * FROM test_prescriptions;  -- Uncomment to see error

-- RESTORE using UNDROP command
UNDROP TABLE test_prescriptions;

-- Verify restoration
SELECT 'Table restored via UNDROP' AS status, COUNT(*) AS record_count 
FROM test_prescriptions;

-- Alternative: Clone from a specific point in time before the drop
-- First, drop it again to demonstrate this method
DROP TABLE test_prescriptions;

-- Restore by creating a clone from history
CREATE TABLE test_prescriptions 
    CLONE prescriptions 
    AT(TIMESTAMP => $timestamp_before_drop);

-- Verify this method also works
SELECT 'Table restored via CLONE' AS status, COUNT(*) AS record_count 
FROM test_prescriptions;

-- Clean up
DROP TABLE test_prescriptions;

-- ============================================================================
-- PART 7: SCENARIO 5 - CLONE HISTORICAL DATA FOR ANALYSIS
-- ============================================================================
-- Zero-copy cloning with Time Travel enables powerful workflows

-- Create a clone of the medical records as they were yesterday
-- This is useful for: audits, testing, analysis, reporting
CREATE OR REPLACE TABLE medical_records_yesterday 
    CLONE medical_records 
    AT(OFFSET => -86400);  -- 86400 seconds = 24 hours

-- You can also clone entire schemas or databases
-- CREATE SCHEMA patient_data_yesterday 
--     CLONE patient_data 
--     AT(TIMESTAMP => $timestamp_before_changes);

-- The clone is a zero-copy operation - it doesn't duplicate data initially
-- Data is only physically copied when either the original or clone is modified
-- This makes it very efficient for creating development/test environments

-- Verify the clone
SELECT 'Clone created' AS status, COUNT(*) AS record_count 
FROM medical_records_yesterday;

-- ============================================================================
-- PART 8: SCENARIO 6 - ROLLBACK MULTIPLE CHANGES
-- ============================================================================
-- Use Time Travel to roll back multiple unwanted changes at once

-- Let's make multiple problematic changes
UPDATE medical_records 
SET notes = 'DATA ERROR - CORRUPTED' 
WHERE record_id IN (1, 2, 3);

UPDATE prescriptions 
SET status = 'CANCELLED' 
WHERE status = 'Active';

-- Store timestamp before rollback
SET timestamp_for_rollback = $timestamp_before_changes;

-- View the damage
SELECT 'Corrupted Records' AS status, record_id, diagnosis_description, notes 
FROM medical_records 
WHERE notes LIKE '%CORRUPTED%';

SELECT 'Cancelled Prescriptions' AS status, COUNT(*) AS cancelled_count 
FROM prescriptions 
WHERE status = 'CANCELLED';

-- ROLLBACK Method 1: Use CREATE OR REPLACE with AT clause
-- This replaces the entire table with its historical version
CREATE OR REPLACE TABLE medical_records 
    CLONE medical_records 
    AT(TIMESTAMP => $timestamp_for_rollback);

-- ROLLBACK Method 2: TRUNCATE and INSERT from history
-- This preserves table structure and foreign key relationships
TRUNCATE TABLE prescriptions;
INSERT INTO prescriptions 
SELECT * FROM prescriptions AT(TIMESTAMP => $timestamp_for_rollback);

-- Verify rollback success
SELECT 'After Rollback' AS status, record_id, diagnosis_description, notes 
FROM medical_records 
WHERE record_id IN (1, 2, 3);

SELECT 'After Rollback' AS status, status, COUNT(*) AS count 
FROM prescriptions 
GROUP BY status;

-- ============================================================================
-- PART 9: SCENARIO 7 - RECOVER FROM MASS DELETE
-- ============================================================================
-- Demonstrate recovering from a catastrophic deletion

-- Store current state
SET timestamp_before_mass_delete = (SELECT CURRENT_TIMESTAMP());

CALL SYSTEM$WAIT(2);

-- Simulate accidental mass deletion
DELETE FROM lab_results WHERE 1=1;  -- Deletes ALL rows

-- Verify the disaster
SELECT 'After Mass Delete' AS status, COUNT(*) AS remaining_rows 
FROM lab_results;

-- Recover using INSERT from Time Travel
INSERT INTO lab_results
SELECT * FROM lab_results AT(TIMESTAMP => $timestamp_before_mass_delete);

-- Verify recovery
SELECT 'After Recovery' AS status, COUNT(*) AS recovered_rows 
FROM lab_results;

-- ============================================================================
-- PART 10: MONITORING TIME TRAVEL USAGE
-- ============================================================================

-- View Time Travel storage costs
-- Time Travel storage includes bytes changed/deleted within retention period
-- This query shows storage breakdown (requires ACCOUNTADMIN role)

-- USE ROLE ACCOUNTADMIN;
-- SELECT 
--     table_catalog,
--     table_schema,
--     table_name,
--     active_bytes / 1024 / 1024 / 1024 AS active_gb,
--     time_travel_bytes / 1024 / 1024 / 1024 AS time_travel_gb,
--     failsafe_bytes / 1024 / 1024 / 1024 AS failsafe_gb,
--     retained_for_clone_bytes / 1024 / 1024 / 1024 AS clone_gb
-- FROM snowflake.account_usage.table_storage_metrics
-- WHERE table_catalog = 'HEALTHCARE_DEMO'
--     AND table_schema = 'PATIENT_DATA'
-- ORDER BY time_travel_bytes DESC;

-- Query history to see what changed
SELECT 
    query_id,
    query_text,
    user_name,
    role_name,
    start_time,
    end_time,
    rows_inserted,
    rows_updated,
    rows_deleted
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY())
WHERE execution_status = 'SUCCESS'
    AND (rows_inserted > 0 OR rows_updated > 0 OR rows_deleted > 0)
    AND query_text NOT LIKE '%INFORMATION_SCHEMA%'
ORDER BY start_time DESC
LIMIT 20;

-- ============================================================================
-- PART 11: TIME TRAVEL VS BACKUPS - WHEN TO USE EACH
-- ============================================================================

-- TIME TRAVEL is best for:
--   ✓ Quick recovery from recent mistakes (hours/days ago)
--   ✓ Auditing recent data changes
--   ✓ Creating point-in-time clones for dev/test
--   ✓ Querying historical data for analysis
--   ✓ Lightweight, automatic (no setup required)
--   ✓ Short-term retention (up to 90 days)
--   ✗ Limited retention period
--   ✗ Cannot prevent deletion by ACCOUNTADMIN
--   ✗ Data can still be purged after retention expires

-- BACKUPS are best for:
--   ✓ Long-term retention (years) for compliance
--   ✓ Immutable storage with retention locks
--   ✓ Protection against ransomware/malicious deletion
--   ✓ Selective backups of critical tables only
--   ✓ Scheduled, policy-driven backups
--   ✓ Cross-region disaster recovery (with replication)
--   ✗ Requires setup (policies, backup sets)
--   ✗ Additional storage costs
--   ✗ Requires manual restore process

-- BEST PRACTICE: Use both together!
--   - Time Travel: Daily operations, quick recovery
--   - Backups: Compliance, ransomware protection, long-term retention

-- ============================================================================
-- PART 12: UNDROP SCENARIOS
-- ============================================================================
-- Snowflake keeps dropped objects for the retention period

-- Drop a table
CREATE OR REPLACE TABLE temp_patients AS SELECT * FROM patients LIMIT 5;
DROP TABLE temp_patients;

-- List dropped tables
SHOW TABLES HISTORY LIKE 'temp_%' IN SCHEMA patient_data;

-- UNDROP the table
UNDROP TABLE temp_patients;

-- Verify
SELECT 'Undropped table' AS status, COUNT(*) AS row_count FROM temp_patients;

-- Drop and undrop a schema
CREATE SCHEMA temp_schema;
CREATE TABLE temp_schema.test_table (id INT);
DROP SCHEMA temp_schema;

-- Undrop schema (this also restores all tables within it)
UNDROP SCHEMA temp_schema;

-- Verify
SHOW TABLES IN SCHEMA temp_schema;

-- Clean up
DROP SCHEMA temp_schema CASCADE;
DROP TABLE temp_patients;
DROP TABLE medical_records_yesterday;

-- ============================================================================
-- PART 13: ADVANCED TIME TRAVEL PATTERNS
-- ============================================================================

-- Pattern 1: Daily comparison report
-- Compare today's data with yesterday's to identify changes
CREATE OR REPLACE VIEW daily_patient_changes AS
SELECT 
    COALESCE(today.patient_id, yesterday.patient_id) AS patient_id,
    CASE 
        WHEN yesterday.patient_id IS NULL THEN 'NEW'
        WHEN today.patient_id IS NULL THEN 'DELETED'
        WHEN today.address != yesterday.address THEN 'MODIFIED'
        ELSE 'UNCHANGED'
    END AS change_type,
    yesterday.address AS old_address,
    today.address AS new_address
FROM patients today
FULL OUTER JOIN patients AT(OFFSET => -86400) yesterday
    ON today.patient_id = yesterday.patient_id
WHERE 
    yesterday.patient_id IS NULL 
    OR today.patient_id IS NULL 
    OR today.address != yesterday.address;

-- Pattern 2: Audit trail with timestamp
-- Create a table to track all changes
CREATE OR REPLACE TABLE patient_audit_trail AS
SELECT 
    patient_id,
    first_name,
    last_name,
    address,
    email,
    updated_at,
    CURRENT_TIMESTAMP() AS audit_timestamp
FROM patients;

-- This pattern can be scheduled to run daily to maintain change history

-- Pattern 3: Point-in-time recovery test
-- Regularly test your recovery process
CREATE OR REPLACE PROCEDURE test_recovery_process()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
    -- Create a test table
    CREATE OR REPLACE TABLE recovery_test AS SELECT * FROM patients LIMIT 1;
    
    -- Make changes
    LET ts := (SELECT CURRENT_TIMESTAMP());
    CALL SYSTEM$WAIT(2);
    DELETE FROM recovery_test;
    
    -- Attempt recovery
    INSERT INTO recovery_test SELECT * FROM recovery_test AT(TIMESTAMP => :ts);
    
    -- Validate
    LET row_count := (SELECT COUNT(*) FROM recovery_test);
    
    -- Cleanup
    DROP TABLE recovery_test;
    
    -- Return result
    IF (row_count = 1) THEN
        RETURN 'Recovery test PASSED';
    ELSE
        RETURN 'Recovery test FAILED';
    END IF;
END;
$$;

-- Run the recovery test
CALL test_recovery_process();

-- ============================================================================
-- PART 14: BEST PRACTICES
-- ============================================================================
-- 1. Set appropriate retention periods:
--    - Critical tables: Maximum retention (90 days with Enterprise+)
--    - Temporary/staging tables: Minimal retention (1 day or 0)
--    - Balance between recovery needs and storage costs
--
-- 2. Document recovery procedures:
--    - Create runbooks for common recovery scenarios
--    - Test recovery regularly (quarterly recommended)
--    - Train team members on Time Travel commands
--
-- 3. Monitor storage costs:
--    - Review TIME_TRAVEL_BYTES in TABLE_STORAGE_METRICS
--    - Consider reducing retention for infrequently changing tables
--    - Use backups for long-term retention instead
--
-- 4. Use Time Travel for auditing:
--    - Create views comparing current vs historical data
--    - Identify who made changes via QUERY_HISTORY
--    - Maintain audit trails for compliance
--
-- 5. Combine with other features:
--    - Zero-copy cloning for dev/test environments
--    - Streams to track changes in real-time
--    - Backups for long-term immutable storage
--
-- 6. Understand limitations:
--    - Time Travel doesn't prevent data loss by ACCOUNTADMIN
--    - Data is permanently deleted after retention + fail-safe period
--    - Fail-safe requires Snowflake Support intervention
--    - GDPR/data deletion requests may conflict with retention policies
-- ============================================================================

-- ============================================================================
-- CLEANUP DEMO OBJECTS (Optional)
-- ============================================================================
-- DROP VIEW daily_patient_changes;
-- DROP TABLE patient_audit_trail;
-- DROP PROCEDURE test_recovery_process();

-- ============================================================================
-- DEMO COMPLETE!
-- ============================================================================
-- You've learned how to:
--   ✓ Configure Time Travel retention periods
--   ✓ Query historical data using TIMESTAMP, OFFSET, and STATEMENT
--   ✓ Restore deleted rows and undrop tables
--   ✓ Create audit trails by comparing current vs historical data
--   ✓ Roll back multiple changes at once
--   ✓ Recover from mass deletions
--   ✓ Clone tables from historical points in time
--   ✓ Monitor Time Travel usage and storage
--   ✓ Understand when to use Time Travel vs Backups
--   ✓ Implement advanced Time Travel patterns
--
-- Complete BCDR Demo Series:
--   ✓ Script 1: Setup healthcare data
--   ✓ Script 2: Backups for long-term protection
--   ✓ Script 3: Time Travel for quick recovery
--
-- For production use, combine Time Travel + Backups + Replication
-- for comprehensive business continuity and disaster recovery!
-- ============================================================================

