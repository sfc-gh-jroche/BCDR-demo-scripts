-- ============================================================================
-- SCRIPT 2: Snowflake Backups Demo
-- ============================================================================
-- Purpose: Demonstrate Snowflake's backup feature for disaster recovery
-- Prerequisites: Run 01_setup_healthcare_data.sql first
-- Documentation: https://docs.snowflake.com/en/user-guide/backups
-- ============================================================================

-- NOTE: This demo assumes Business Critical Edition
-- - Basic backups are available in all Snowflake editions
-- - Retention locks and legal holds require Business Critical Edition or higher

-- ============================================================================
-- PERMISSIONS REQUIRED
-- ============================================================================
-- Option 1: Use ACCOUNTADMIN role (recommended for demos)
USE ROLE ACCOUNTADMIN;

-- Option 2: Grant specific privileges to your current role
-- Have an ACCOUNTADMIN run these commands to delegate permissions:
--   GRANT CREATE BACKUP POLICY ON SCHEMA patient_data TO ROLE your_role;
--   GRANT CREATE BACKUP SET ON SCHEMA patient_data TO ROLE your_role;
--   GRANT APPLY BACKUP POLICY ON ACCOUNT TO ROLE your_role;
--   GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA patient_data TO ROLE your_role;

USE DATABASE healthcare_demo;
USE SCHEMA patient_data;

-- ============================================================================
-- PART 1: UNDERSTANDING BACKUPS
-- ============================================================================
-- Snowflake backups provide:
--   1. Point-in-time snapshots of databases, schemas, or tables
--   2. Protection against accidental deletion or modification
--   3. Regulatory compliance with retention locks (immutable storage)
--   4. Cyber resilience against ransomware attacks
--
-- Key Concepts:
--   - BACKUP POLICY: Defines schedule and retention period
--   - BACKUP SET: Container for multiple backups of a specific object
--   - BACKUP: Individual point-in-time snapshot
--   - RETENTION LOCK: Prevents deletion (Business Critical only)
--
-- Use Cases:
--   - Disaster recovery from accidental changes
--   - Regulatory compliance (SEC 17a-4, FINRA, HIPAA)
--   - Ransomware protection with retention locks
-- ============================================================================

-- ============================================================================
-- PART 2: CREATE BACKUP POLICIES
-- ============================================================================
-- A backup policy defines WHEN backups are created and HOW LONG they're kept

-- Policy 1: Automated daily backups with 30-day retention
CREATE OR REPLACE BACKUP POLICY daily_backup_policy
    SCHEDULE = 'USING CRON 0 2 * * * America/New_York'  -- Daily at 2 AM ET
    EXPIRE_AFTER_DAYS = 30;  -- Keep backups for 30 days

-- Policy 2: Manual backup policy (no schedule, for on-demand backups)
CREATE OR REPLACE BACKUP POLICY manual_backup_policy
    EXPIRE_AFTER_DAYS = 90;  -- Keep backups for 90 days

-- View the policies we just created
SHOW BACKUP POLICIES;

-- Example: Backup policy with RETENTION LOCK (Business Critical Edition only)
-- RETENTION LOCK is IRREVERSIBLE - backups cannot be deleted even by ACCOUNTADMIN
-- Uncomment to enable (requires Business Critical Edition):
CREATE OR REPLACE BACKUP POLICY compliance_backup_policy
     SCHEDULE = 'USING CRON 0 1 * * 0 America/New_York'  -- Weekly on Sunday at 1 AM
     EXPIRE_AFTER_DAYS = 2555  -- 7 years for regulatory compliance
     RETENTION_LOCK = TRUE;  -- Makes backups immutable!

-- ============================================================================
-- PART 3: CREATE BACKUP SETS
-- ============================================================================
-- Backup sets are containers that hold actual backups
-- You attach a policy to a backup set to automate backup creation

-- Backup Set 1: Table-level backup for patients table
CREATE OR REPLACE BACKUP SET patients_backup_set
    FOR TABLE patients
    WITH BACKUP POLICY daily_backup_policy;

-- Backup Set 2: Schema-level backup (captures all objects in the schema)
-- This backs up all tables, views, and other schema objects together
CREATE OR REPLACE BACKUP SET patient_data_schema_backup
    FOR SCHEMA patient_data
    WITH BACKUP POLICY manual_backup_policy;

-- View all backup sets we created
SHOW BACKUP SETS;

-- Get detailed information about a specific backup set
DESCRIBE BACKUP SET patients_backup_set;

-- ============================================================================
-- PART 4: MANUAL BACKUP CREATION
-- ============================================================================
-- Create backups on-demand before critical operations

-- Create a manual backup of the patients table
ALTER BACKUP SET patients_backup_set
    ADD BACKUP;

-- Create a schema-level backup
ALTER BACKUP SET patient_data_schema_backup
    ADD BACKUP;

-- View all backups in a backup set
SHOW BACKUPS IN BACKUP SET patients_backup_set;

-- The output shows for each backup:
--   - BACKUP_ID: Unique identifier
--   - CREATED_ON: Timestamp of creation
--   - EXPIRES_ON: When it will be auto-deleted
--   - IS_UNDER_LEGAL_HOLD

-- ============================================================================
-- PART 5: DISASTER SCENARIO - ACCIDENTAL DATA CORRUPTION
-- ============================================================================
-- Let's simulate a real-world disaster and recovery

-- First, view the current (correct) data
SELECT 'BEFORE - Correct Data' AS status, 
       patient_id, first_name, last_name, email, phone, address
FROM patients 
WHERE patient_id = 1;

-- Store current timestamp for later reference
SET disaster_timestamp = (SELECT CURRENT_TIMESTAMP()::STRING);

-- DISASTER STRIKES! Accidental data corruption
UPDATE patients 
SET 
    email = 'CORRUPTED@error.com',
    phone = '000-0000',
    address = 'DATA LOST DUE TO ERROR'
WHERE patient_id = 1;

-- Even worse - someone accidentally deleted medical records!
DELETE FROM medical_records WHERE patient_id = 1;

-- View the damage
SELECT 'AFTER - Corrupted Data' AS status,
       patient_id, first_name, last_name, email, phone, address
FROM patients 
WHERE patient_id = 1;

SELECT 'Medical Records Lost' AS status, 
       COUNT(*) AS remaining_records 
FROM medical_records 
WHERE patient_id = 1;

-- ============================================================================
-- PART 6: RESTORE FROM BACKUP
-- ============================================================================
-- Now let's recover our data using backups!

-- Step 1: Find the backup we want to restore from
SHOW BACKUPS IN BACKUP SET patients_backup_set;

-- Step 2: Get the BACKUP_ID from the output above

SET backup_to_restore = '894d72ed-9b44-4019-98c4-d791b645758e';--INSERT backup_id FROM LAST QUERY'S RESULTS HERE

-- Step 3: Restore the table from backup
-- IMPORTANT: Must restore to a NEW table name (cannot overwrite existing table)
CREATE TABLE patients_restored
    FROM BACKUP SET patients_backup_set
    IDENTIFIER $backup_to_restore;

-- Step 4: Verify the restored data
SELECT 'RESTORED - Clean Data' AS status,
       patient_id, first_name, last_name, email, phone, address
FROM patients_restored 
WHERE patient_id = 1;

-- Step 5: Compare corrupted vs restored data side-by-side
SELECT 
    'CURRENT (Corrupted)' AS source,
    patient_id, email, phone, address
FROM patients WHERE patient_id = 1
UNION ALL
SELECT 
    'RESTORED (Clean)' AS source,
    patient_id, email, phone, address
FROM patients_restored WHERE patient_id = 1;

-- Step 6: Replace corrupted table with clean data
-- Option A: Drop and rename
-- DROP TABLE patients;
-- ALTER TABLE patients_restored RENAME TO patients;

-- Option B: Truncate and insert (preserves foreign key relationships)
TRUNCATE TABLE patients;
INSERT INTO patients SELECT * FROM patients_restored;

-- Step 7: Verify the recovery
SELECT 'FINAL - Recovered Data' AS status,
       patient_id, first_name, last_name, email, phone, address
FROM patients 
WHERE patient_id = 1;

-- Clean up temporary restored table
DROP TABLE patients_restored;

-- Note: Medical records are still missing!
-- We could restore those from the schema-level backup or use Time Travel
-- (See 03_time_travel_demo.sql for Time Travel recovery)

-- ============================================================================
-- PART 7: MANAGING BACKUPS
-- ============================================================================

-- Suspend automatic backups on a backup set (stops scheduled backups)
ALTER BACKUP SET patients_backup_set
    SUSPEND BACKUP POLICY;

-- Resume automatic backups
ALTER BACKUP SET patients_backup_set
    RESUME BACKUP POLICY;

-- Modify a backup policy (affects all backup sets using this policy)
ALTER BACKUP POLICY daily_backup_policy
    SET EXPIRE_AFTER_DAYS = 60;  -- Increase retention to 60 days

-- Delete a specific backup manually (if no retention lock)
-- Get the backup ID first, then:
-- ALTER BACKUP SET patients_backup_set
--     DROP BACKUP '<backup_id>';

-- Drop a backup set (only works if no unexpired backups exist)
-- DROP BACKUP SET backup_set_name;

-- ============================================================================
-- PART 8: MONITORING BACKUPS
-- ============================================================================

-- View backup information using Information Schema
SELECT *
FROM INFORMATION_SCHEMA.BACKUP_SETS
WHERE backup_set_schema = 'PATIENT_DATA';

-- View individual backups
SELECT *
FROM INFORMATION_SCHEMA.BACKUPS
WHERE backup_set_schema = 'PATIENT_DATA'
ORDER BY created DESC;

-- View backup policies
SELECT *
FROM INFORMATION_SCHEMA.BACKUP_POLICIES
WHERE backup_policy_catalog = 'HEALTHCARE_DEMO';

-- Check backup storage usage (Account Usage - has latency up to 45 min)
 SELECT *
 FROM SNOWFLAKE.ACCOUNT_USAGE.BACKUP_STORAGE_USAGE;

-- ============================================================================
-- PART 9: LEGAL HOLDS (Business Critical Edition)
-- ============================================================================
-- Legal holds prevent backups from being deleted, even after expiration
-- Used for litigation, regulatory investigations, or compliance
-- Can only be removed by USERS with special APPLY LEGAL HOLD privileges
-- DO NOT run the following commands as part of this demo. They are here for educational purposes.

-- Add a legal hold to a specific backup
ALTER BACKUP SET <backup_set_name>
  MODIFY BACKUP IDENTIFIER '<backup_identifier>'
  ADD LEGAL HOLD;

-- View legal holds
SHOW BACKUPS IN BACKUP SET <backup_set_name>
  ->> SELECT * FROM $1 WHERE "is_under_legal_hold" = 'Y';

-- Remove a legal hold (when legal requirement is lifted) 
ALTER BACKUP SET <backup_set_name>
  MODIFY BACKUP IDENTIFIER '<backup_identifier>'
  REMOVE LEGAL HOLD;


-- ============================================================================
-- PART 10: BEST PRACTICES
-- ============================================================================
-- 1. Choose backup frequency based on data criticality:
--    - Critical data: Daily or more frequent
--    - Standard data: Weekly
--    - Archive data: Monthly
--
-- 2. Set retention based on:
--    - Regulatory requirements 
--    - Business continuity needs
--    - Storage cost considerations
--
-- 3. Use retention locks for:
--    - Regulatory compliance (SEC, FINRA, HIPAA)
--    - Ransomware protection
--    - Critical business data requiring immutability
--
-- 4. Test restore procedures regularly:
--    - Practice quarterly disaster recovery drills
--    - Document recovery runbooks
--    - Measure Recovery Time Objective (RTO)
--
-- 5. Monitor backup costs:
--    - Review BACKUP_STORAGE_USAGE regularly
--    - Balance retention needs with budget
--    - Consider Time Travel for short-term recovery needs
--
-- 6. Combine with other BCDR features:
--    - Time Travel: Quick recovery (hours to days)
--    - Backups: Long-term retention (months to years)
--    - Replication: Geographic redundancy
--    - Failover Groups: Automated disaster recovery
-- ============================================================================

-- ============================================================================
-- CLEANUP (Optional)
-- ============================================================================
-- To remove demo objects, uncomment and run:
DROP BACKUP SET patients_backup_set;
DROP BACKUP SET patient_data_schema_backup;
DROP BACKUP POLICY daily_backup_policy;
DROP BACKUP POLICY manual_backup_policy;

-- ============================================================================
-- DEMO COMPLETE!
-- ============================================================================
-- You've learned how to:
--   ✓ Create backup policies with schedules and retention periods
--   ✓ Create backup sets for tables and schemas
--   ✓ Manually create backups before critical operations
--   ✓ Restore data from backups after disasters
--   ✓ Manage and monitor backups
--   ✓ Understand retention locks and legal holds
--
-- Next: Run 03_time_travel_demo.sql to learn about Time Travel
-- ============================================================================
