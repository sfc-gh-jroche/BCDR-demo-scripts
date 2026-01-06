-- ============================================================================
-- SCRIPT 2: Snowflake Backups Demo
-- ============================================================================
-- Purpose: Demonstrate Snowflake's backup feature for disaster recovery
-- Prerequisites: Run 01_setup_healthcare_data.sql first
-- Documentation: https://docs.snowflake.com/en/user-guide/backups
-- ============================================================================

USE DATABASE healthcare_demo;
USE SCHEMA patient_data;

-- ============================================================================
-- PART 1: UNDERSTANDING BACKUPS
-- ============================================================================
-- Snowflake backups provide:
--   1. Point-in-time snapshots of databases, schemas, or tables
--   2. Protection against accidental deletion or modification
--   3. Regulatory compliance with retention locks (Business Critical Edition)
--   4. Cyber resilience against ransomware attacks
--
-- Key Concepts:
--   - BACKUP SET: Container for multiple backups of a specific object
--   - BACKUP POLICY: Defines schedule, retention period, and rules
--   - BACKUP: Individual point-in-time snapshot
--   - RETENTION LOCK: Prevents deletion (immutable storage)
-- ============================================================================

-- ============================================================================
-- PART 2: CREATE A BACKUP POLICY
-- ============================================================================
-- A backup policy defines when backups are created and how long they're kept
-- Let's create a policy for our critical patient data

-- Policy 1: Daily backups with 30-day retention (without retention lock)
-- This is suitable for general disaster recovery
CREATE OR REPLACE BACKUP POLICY daily_backup_policy
    BACKUP_SCHEDULE = 'USING CRON 0 2 * * * America/New_York'  -- Daily at 2 AM ET
    BACKUP_EXPIRATION_TIME = 30;  -- Keep backups for 30 days

-- View the policy we just created
SHOW BACKUP POLICIES;

-- Policy 2: Hourly backups with 7-day retention for high-frequency changes
-- Useful for tables that change frequently
CREATE OR REPLACE BACKUP POLICY hourly_backup_policy
    BACKUP_SCHEDULE = '60 MINUTES'  -- Every 60 minutes
    BACKUP_EXPIRATION_TIME = 7;     -- Keep backups for 7 days

-- Policy 3: Weekly backups with 365-day retention for long-term compliance
-- This demonstrates a policy without a schedule (manual backups only)
CREATE OR REPLACE BACKUP POLICY annual_backup_policy
    BACKUP_EXPIRATION_TIME = 365;   -- Keep backups for 1 year

-- NOTE: To enable RETENTION LOCK (immutable backups), you need Business Critical Edition
-- Example syntax (commented out):
-- CREATE OR REPLACE BACKUP POLICY compliance_backup_policy
--     BACKUP_SCHEDULE = 'USING CRON 0 1 * * * America/New_York'
--     BACKUP_EXPIRATION_TIME = 2555  -- 7 years for regulatory compliance
--     BACKUP_RETENTION_LOCK = TRUE;  -- Makes backups immutable

-- ============================================================================
-- PART 3: CREATE BACKUP SETS
-- ============================================================================
-- Backup sets are containers that hold actual backups
-- You apply policies to backup sets to automate backup creation

-- Backup Set 1: Protect the entire patients table
CREATE OR REPLACE BACKUP SET patients_backup_set
    AS COPY OF TABLE patients
    BACKUP_POLICY = daily_backup_policy;

-- Backup Set 2: Protect medical records with hourly backups
CREATE OR REPLACE BACKUP SET medical_records_backup_set
    AS COPY OF TABLE medical_records
    BACKUP_POLICY = hourly_backup_policy;

-- Backup Set 3: Protect prescriptions table
CREATE OR REPLACE BACKUP SET prescriptions_backup_set
    AS COPY OF TABLE prescriptions
    BACKUP_POLICY = daily_backup_policy;

-- Backup Set 4: Schema-level backup (backs up entire schema)
-- This captures all tables, views, and other objects in the schema
CREATE OR REPLACE BACKUP SET patient_data_schema_backup_set
    AS COPY OF SCHEMA patient_data
    BACKUP_POLICY = annual_backup_policy;

-- View all backup sets we created
SHOW BACKUP SETS;

-- Get detailed information about a specific backup set
DESCRIBE BACKUP SET patients_backup_set;

-- ============================================================================
-- PART 4: MANUAL BACKUP CREATION
-- ============================================================================
-- While policies automate backups, you can also create manual backups
-- This is useful before major changes or migrations

-- Create a manual backup of the patients table
-- This adds a backup to an existing backup set
ALTER BACKUP SET patients_backup_set
    ADD BACKUP;

-- Create a backup with a descriptive comment
ALTER BACKUP SET medical_records_backup_set
    ADD BACKUP
    COMMENT = 'Pre-system-upgrade backup - 2026-01-06';

-- Wait a moment for backups to be created...
CALL SYSTEM$WAIT(5);  -- Wait 5 seconds

-- View all backups in a specific backup set
SHOW BACKUPS IN BACKUP SET patients_backup_set;

-- The output shows:
--   - BACKUP_ID: Unique identifier for each backup
--   - CREATED_ON: When the backup was created
--   - EXPIRES_ON: When the backup will be automatically deleted
--   - BACKUP_SIZE: Storage used by the backup

-- ============================================================================
-- PART 5: SIMULATE AN ACCIDENTAL DATA MODIFICATION
-- ============================================================================
-- Let's simulate a scenario where data gets accidentally modified
-- This demonstrates why backups are critical

-- First, let's see the current state of our data
SELECT 'Before Modification' AS scenario, * 
FROM patients 
WHERE patient_id = 1;

-- Store the current timestamp for reference
SET backup_timestamp = (SELECT CURRENT_TIMESTAMP()::STRING);

-- Wait a moment to ensure timestamp separation
CALL SYSTEM$WAIT(2);

-- OOPS! Accidental UPDATE that modifies critical data
-- This simulates a human error or application bug
UPDATE patients 
SET 
    email = 'CORRUPTED@error.com',
    phone = '000-0000',
    address = 'DATA CORRUPTED'
WHERE patient_id = 1;

-- DISASTER! Let's also accidentally delete some medical records
DELETE FROM medical_records WHERE patient_id = 1;

-- Check the damage
SELECT 'After Accidental Modification' AS scenario, * 
FROM patients 
WHERE patient_id = 1;

SELECT 'Medical records deleted' AS status, 
       COUNT(*) AS records_remaining 
FROM medical_records 
WHERE patient_id = 1;

-- ============================================================================
-- PART 6: RESTORE FROM BACKUP
-- ============================================================================
-- Now let's recover our data using backups!

-- Step 1: Find the backup we want to restore from
-- We'll get the most recent backup before our accident
SHOW BACKUPS IN BACKUP SET patients_backup_set;

-- Step 2: Get the backup ID (in a real scenario, you'd copy this from the output above)
-- For automation, let's query the backup information
SET backup_id = (
    SELECT backup_id 
    FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
    WHERE created_on <= $backup_timestamp
    ORDER BY created_on DESC 
    LIMIT 1
);

-- Step 3: Restore the table from backup
-- IMPORTANT: You must restore to a NEW table name
-- The original table continues to exist, allowing you to compare before replacing
CREATE OR REPLACE TABLE patients_restored
FROM BACKUP SET patients_backup_set
BACKUP_ID => IDENTIFIER($backup_id);

-- Step 4: Verify the restored data
SELECT 'Restored Data' AS scenario, * 
FROM patients_restored 
WHERE patient_id = 1;

-- Compare original (corrupted) vs restored (clean) data
SELECT 
    'CURRENT (Corrupted)' AS source,
    patient_id, email, phone, address
FROM patients
WHERE patient_id = 1
UNION ALL
SELECT 
    'RESTORED (Clean)' AS source,
    patient_id, email, phone, address
FROM patients_restored
WHERE patient_id = 1;

-- Step 5: Once verified, replace the corrupted table with restored data
-- Option A: Drop and rename
-- DROP TABLE patients;
-- ALTER TABLE patients_restored RENAME TO patients;

-- Option B: Truncate and insert (preserves table structure and dependencies)
TRUNCATE TABLE patients;
INSERT INTO patients SELECT * FROM patients_restored;

-- Verify the fix
SELECT 'Final Restored State' AS scenario, * 
FROM patients 
WHERE patient_id = 1;

-- Clean up the temporary restored table
DROP TABLE patients_restored;

-- ============================================================================
-- PART 7: DATABASE-LEVEL BACKUP AND RESTORE
-- ============================================================================
-- You can also backup entire databases for comprehensive protection

-- Create a backup policy for database-level backups
CREATE OR REPLACE BACKUP POLICY database_backup_policy
    BACKUP_SCHEDULE = 'USING CRON 0 0 * * 0 America/New_York'  -- Weekly on Sunday at midnight
    BACKUP_EXPIRATION_TIME = 90;  -- Keep for 90 days

-- Create a backup set for the entire database
CREATE OR REPLACE BACKUP SET healthcare_db_backup_set
    AS COPY OF DATABASE healthcare_demo
    BACKUP_POLICY = database_backup_policy;

-- Create an immediate database backup
ALTER BACKUP SET healthcare_db_backup_set
    ADD BACKUP
    COMMENT = 'Complete database snapshot for disaster recovery';

CALL SYSTEM$WAIT(5);  -- Wait for backup to complete

-- View database backups
SHOW BACKUPS IN BACKUP SET healthcare_db_backup_set;

-- To restore an entire database from backup:
-- CREATE DATABASE healthcare_demo_restored
-- FROM BACKUP SET healthcare_db_backup_set
-- BACKUP_ID => '<backup_id_from_show_backups>';

-- ============================================================================
-- PART 8: MANAGING BACKUPS
-- ============================================================================

-- Suspend a backup policy on a specific backup set (stops automatic backups)
ALTER BACKUP SET medical_records_backup_set
    SUSPEND BACKUP POLICY;

-- Resume the backup policy
ALTER BACKUP SET medical_records_backup_set
    RESUME BACKUP POLICY;

-- Modify a backup policy to change retention or schedule
ALTER BACKUP POLICY daily_backup_policy
    SET BACKUP_EXPIRATION_TIME = 60;  -- Increase retention to 60 days

-- Delete a specific backup manually (useful for managing storage costs)
-- First, get the backup ID you want to delete
SHOW BACKUPS IN BACKUP SET prescriptions_backup_set;

-- Delete the oldest backup (replace with actual backup_id)
-- ALTER BACKUP SET prescriptions_backup_set
--     DELETE BACKUP '<backup_id>';

-- ============================================================================
-- PART 9: MONITORING AND REPORTING
-- ============================================================================

-- View backup storage usage (Account Usage)
-- Note: Account Usage views have latency (up to 45 minutes)
-- USE SCHEMA SNOWFLAKE.ACCOUNT_USAGE;
-- SELECT * FROM BACKUP_STORAGE_USAGE ORDER BY DATE DESC LIMIT 10;

-- View backup operation history
-- SELECT * FROM BACKUP_OPERATION_HISTORY 
-- WHERE DATABASE_NAME = 'HEALTHCARE_DEMO'
-- ORDER BY START_TIME DESC 
-- LIMIT 20;

-- Query Information Schema for real-time backup information
USE SCHEMA patient_data;

-- Show all backup policies in the current database
SELECT * FROM TABLE(
    INFORMATION_SCHEMA.BACKUP_POLICIES(
        DATABASE_NAME => 'HEALTHCARE_DEMO'
    )
);

-- Show all backup sets in the current schema
SELECT * FROM TABLE(
    INFORMATION_SCHEMA.BACKUP_SETS(
        DATABASE_NAME => 'HEALTHCARE_DEMO',
        SCHEMA_NAME => 'PATIENT_DATA'
    )
);

-- Show all backups across all backup sets
SELECT * FROM TABLE(
    INFORMATION_SCHEMA.BACKUPS(
        DATABASE_NAME => 'HEALTHCARE_DEMO',
        SCHEMA_NAME => 'PATIENT_DATA'
    )
);

-- ============================================================================
-- PART 10: LEGAL HOLDS (Business Critical Edition)
-- ============================================================================
-- Legal holds prevent backups from being deleted, even after expiration
-- This is used for litigation or regulatory investigations

-- NOTE: This requires Business Critical Edition or higher
-- Example syntax (commented out):

-- Add a legal hold to a specific backup
-- ALTER BACKUP SET patients_backup_set
--     ADD LEGAL HOLD TO BACKUP '<backup_id>'
--     COMMENT = 'Legal hold for case #2026-001';

-- View legal holds
-- SHOW LEGAL HOLDS ON BACKUP SET patients_backup_set;

-- Remove a legal hold (when the legal requirement is lifted)
-- ALTER BACKUP SET patients_backup_set
--     DELETE LEGAL HOLD FROM BACKUP '<backup_id>';

-- ============================================================================
-- PART 11: BEST PRACTICES
-- ============================================================================
-- 1. Choose appropriate backup frequency based on data criticality
--    - High-value, frequently changing data: Hourly backups
--    - Standard business data: Daily backups
--    - Archive/compliance data: Weekly or monthly backups
--
-- 2. Set retention periods based on:
--    - Regulatory requirements (e.g., HIPAA requires 6 years for healthcare)
--    - Business continuity needs
--    - Storage cost considerations
--
-- 3. Use retention locks for:
--    - Regulatory compliance (SEC, FINRA, HIPAA, etc.)
--    - Ransomware protection
--    - Critical business data that must be immutable
--
-- 4. Test your restore process regularly
--    - Practice restoring from backups quarterly
--    - Document recovery procedures
--    - Measure Recovery Time Objective (RTO)
--
-- 5. Monitor backup storage costs
--    - Review BACKUP_STORAGE_USAGE regularly
--    - Balance retention needs with storage costs
--    - Clean up unnecessary backup sets
--
-- 6. Combine backups with other BCDR features:
--    - Time Travel: For short-term recovery (up to 90 days)
--    - Fail-safe: For emergency recovery (7 days after Time Travel)
--    - Replication: For geographic redundancy
--    - Failover Groups: For automated failover
-- ============================================================================

-- ============================================================================
-- CLEANUP (Optional - uncomment to remove demo objects)
-- ============================================================================
-- DROP BACKUP SET patients_backup_set;
-- DROP BACKUP SET medical_records_backup_set;
-- DROP BACKUP SET prescriptions_backup_set;
-- DROP BACKUP SET patient_data_schema_backup_set;
-- DROP BACKUP SET healthcare_db_backup_set;
-- DROP BACKUP POLICY daily_backup_policy;
-- DROP BACKUP POLICY hourly_backup_policy;
-- DROP BACKUP POLICY annual_backup_policy;
-- DROP BACKUP POLICY database_backup_policy;

-- ============================================================================
-- DEMO COMPLETE!
-- ============================================================================
-- You've learned how to:
--   ✓ Create backup policies with schedules and retention periods
--   ✓ Create backup sets for tables, schemas, and databases
--   ✓ Manually create backups before critical operations
--   ✓ Restore data from backups after accidental modifications
--   ✓ Manage and monitor backups
--   ✓ Understand legal holds and retention locks
--
-- Next: Run 03_time_travel_demo.sql to learn about Time Travel
-- ============================================================================

