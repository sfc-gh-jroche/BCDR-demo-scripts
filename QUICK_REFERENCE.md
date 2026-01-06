## Snowflake BCDR Quick Reference Guide

## 🔐 Required Privileges

### ACCOUNTADMIN Approach (Simplest)
```sql
USE ROLE ACCOUNTADMIN;
```

### Delegated Permissions Approach
Have ACCOUNTADMIN grant these to your role:

```sql
-- For backups
GRANT CREATE BACKUP POLICY ON SCHEMA schema_name TO ROLE your_role;
GRANT CREATE BACKUP SET ON SCHEMA schema_name TO ROLE your_role;
GRANT APPLY BACKUP POLICY ON ACCOUNT TO ROLE your_role;

-- For Time Travel (ownership is usually sufficient)
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE table_name TO ROLE your_role;
GRANT OWNERSHIP ON TABLE table_name TO ROLE your_role;
```

## 💾 Backup Commands

### Create Backup Policies

```sql
-- Daily backups with CRON schedule
CREATE BACKUP POLICY daily_backup_policy
    SCHEDULE = 'USING CRON 0 2 * * * America/New_York'  -- Daily at 2 AM
    EXPIRE_AFTER_DAYS = 30;  -- Keep for 30 days

-- Interval-based schedule
CREATE BACKUP POLICY hourly_backup_policy
    SCHEDULE = '60 MINUTES'
    EXPIRE_AFTER_DAYS = 7;

-- Manual backups only (no schedule)
CREATE BACKUP POLICY manual_backup_policy
    EXPIRE_AFTER_DAYS = 90;

-- With retention lock (Business Critical Edition - IRREVERSIBLE!)
CREATE BACKUP POLICY compliance_backup_policy
    SCHEDULE = 'USING CRON 0 1 * * 0 America/New_York'  -- Weekly
    EXPIRE_AFTER_DAYS = 2555  -- 7 years
    RETENTION_LOCK = TRUE;  -- Makes backups immutable!

-- Modify policy
ALTER BACKUP POLICY policy_name
    SET EXPIRE_AFTER_DAYS = 60;

-- Drop policy
DROP BACKUP POLICY policy_name;
```

**Important Syntax Notes**:
- Use `SCHEDULE` (not `BACKUP_SCHEDULE`)
- Use `EXPIRE_AFTER_DAYS` (not `BACKUP_EXPIRATION_TIME`)
- CRON expression stays as a complete string inside quotes

### Create Backup Sets

```sql
-- Table backup with policy
CREATE BACKUP SET backup_set_name
    FOR TABLE table_name
    WITH BACKUP_POLICY policy_name;

-- Schema backup
CREATE BACKUP SET backup_set_name
    FOR SCHEMA schema_name
    WITH BACKUP_POLICY policy_name;

-- Database backup
CREATE BACKUP SET backup_set_name
    FOR DATABASE database_name
    WITH BACKUP_POLICY policy_name;

-- Backup set without policy (manual backups only)
CREATE BACKUP SET backup_set_name
    FOR TABLE table_name;
```

**Important Syntax Notes**:
- Use `FOR TABLE` (not `AS COPY OF TABLE`)
- Use `WITH BACKUP_POLICY` (WITH keyword required)

### Manage Backups

```sql
-- Create manual backup
ALTER BACKUP SET backup_set_name
    ADD BACKUP
    COMMENT = 'Pre-migration backup';

-- Delete specific backup (if no retention lock)
ALTER BACKUP SET backup_set_name
    DROP BACKUP '<backup_id>';

-- Suspend automatic backups
ALTER BACKUP SET backup_set_name
    SUSPEND;

-- Resume automatic backups
ALTER BACKUP SET backup_set_name
    RESUME;

-- Drop backup set
DROP BACKUP SET backup_set_name;
```

### View Backups

```sql
-- Show all backup policies
SHOW BACKUP POLICIES;

-- Show all backup sets
SHOW BACKUP SETS;

-- Show backups in a specific set
SHOW BACKUPS IN BACKUP SET backup_set_name;

-- Describe backup set details
DESCRIBE BACKUP SET backup_set_name;

-- Query backup information
SELECT * FROM INFORMATION_SCHEMA.BACKUP_POLICIES;
SELECT * FROM INFORMATION_SCHEMA.BACKUP_SETS;
SELECT * FROM INFORMATION_SCHEMA.BACKUPS;
```

### Restore from Backup

```sql
-- Restore table (must use NEW table name)
CREATE TABLE table_restored
    FROM BACKUP SET backup_set_name
    BACKUP_ID => '<backup_id>';

-- Restore schema
CREATE SCHEMA schema_restored
    FROM BACKUP SET backup_set_name
    BACKUP_ID => '<backup_id>';

-- Restore database
CREATE DATABASE database_restored
    FROM BACKUP SET backup_set_name
    BACKUP_ID => '<backup_id>';

-- After restore, replace original table
TRUNCATE TABLE original_table;
INSERT INTO original_table SELECT * FROM table_restored;
DROP TABLE table_restored;
```

### Legal Holds (Business Critical)

```sql
-- Add legal hold to backup
ALTER BACKUP SET backup_set_name
    ADD LEGAL HOLD TO BACKUP '<backup_id>'
    COMMENT = 'Legal case #2026-001';

-- Show legal holds
SHOW LEGAL HOLDS ON BACKUP SET backup_set_name;

-- Remove legal hold
ALTER BACKUP SET backup_set_name
    DROP LEGAL HOLD FROM BACKUP '<backup_id>';
```

## 🔄 Time Travel Commands

### Configure Retention

```sql
-- Set retention at table level (1-90 days, Enterprise+)
ALTER TABLE table_name 
    SET DATA_RETENTION_TIME_IN_DAYS = 7;

-- Set retention at schema level
ALTER SCHEMA schema_name 
    SET DATA_RETENTION_TIME_IN_DAYS = 30;

-- Set retention at database level
ALTER DATABASE db_name 
    SET DATA_RETENTION_TIME_IN_DAYS = 90;

-- Check retention settings
SELECT table_name, retention_time 
FROM INFORMATION_SCHEMA.TABLES 
WHERE table_schema = 'SCHEMA_NAME';
```

### Query Historical Data

```sql
-- Using timestamp
SELECT * FROM table_name 
AT(TIMESTAMP => '2026-01-01 10:00:00'::TIMESTAMP_LTZ);

-- Using timestamp variable
SET my_timestamp = (SELECT CURRENT_TIMESTAMP());
SELECT * FROM table_name AT(TIMESTAMP => $my_timestamp);

-- Using offset (seconds ago)
SELECT * FROM table_name AT(OFFSET => -3600);  -- 1 hour ago

-- Using query ID
SELECT * FROM table_name BEFORE(STATEMENT => '<query_id>');
```

### Restore Deleted Rows

```sql
-- Restore specific rows
INSERT INTO table_name
SELECT * FROM table_name AT(TIMESTAMP => '<timestamp>')
WHERE condition;

-- Restore all deleted rows
SET before_delete = (SELECT CURRENT_TIMESTAMP());
-- ... deletion happens ...
INSERT INTO table_name
SELECT * FROM table_name AT(TIMESTAMP => $before_delete);
```

### Undrop Objects

```sql
-- Undrop table
UNDROP TABLE table_name;

-- Undrop schema
UNDROP SCHEMA schema_name;

-- Undrop database
UNDROP DATABASE database_name;

-- List dropped objects
SHOW TABLES HISTORY;
SHOW SCHEMAS HISTORY;
SHOW DATABASES HISTORY;
```

### Clone from History

```sql
-- Clone table from historical point
CREATE TABLE table_clone 
    CLONE original_table 
    AT(TIMESTAMP => '<timestamp>');

-- Clone schema
CREATE SCHEMA schema_clone 
    CLONE original_schema 
    AT(TIMESTAMP => '<timestamp>');

-- Clone database
CREATE DATABASE db_clone 
    CLONE original_db 
    AT(TIMESTAMP => '<timestamp>');
```

### Rollback Changes

```sql
-- Replace entire table with historical version
CREATE OR REPLACE TABLE table_name 
    CLONE table_name 
    AT(TIMESTAMP => '<timestamp>');

-- Alternative: Truncate and insert
TRUNCATE TABLE table_name;
INSERT INTO table_name 
SELECT * FROM table_name AT(TIMESTAMP => '<timestamp>');
```

## 📊 Monitoring & Reporting

### Storage Usage

```sql
-- Table storage breakdown (Account Usage)
SELECT 
    table_name,
    active_bytes / 1024 / 1024 / 1024 AS active_gb,
    time_travel_bytes / 1024 / 1024 / 1024 AS time_travel_gb,
    failsafe_bytes / 1024 / 1024 / 1024 AS failsafe_gb
FROM SNOWFLAKE.ACCOUNT_USAGE.TABLE_STORAGE_METRICS
WHERE table_catalog = 'DATABASE_NAME'
ORDER BY time_travel_bytes DESC;

-- Backup storage usage
SELECT *
FROM SNOWFLAKE.ACCOUNT_USAGE.BACKUP_STORAGE_USAGE
ORDER BY date DESC
LIMIT 30;
```

### Query History

```sql
-- Find queries that modified data
SELECT 
    query_id,
    query_text,
    user_name,
    start_time,
    rows_inserted,
    rows_updated,
    rows_deleted
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE (rows_inserted > 0 OR rows_updated > 0 OR rows_deleted > 0)
    AND execution_status = 'SUCCESS'
ORDER BY start_time DESC
LIMIT 50;
```

### Backup Operations

```sql
-- Backup operation history
SELECT *
FROM SNOWFLAKE.ACCOUNT_USAGE.BACKUP_OPERATION_HISTORY
WHERE database_name = 'DATABASE_NAME'
ORDER BY start_time DESC
LIMIT 20;
```

## ⚡ Common Scenarios

### Scenario 1: Accidental DELETE
```sql
-- 1. Store timestamp before
SET before_change = (SELECT CURRENT_TIMESTAMP());

-- 2. Check data is gone
SELECT COUNT(*) FROM table_name WHERE condition;

-- 3. Restore from Time Travel
INSERT INTO table_name
SELECT * FROM table_name AT(TIMESTAMP => $before_change)
WHERE condition;
```

### Scenario 2: Accidental UPDATE
```sql
-- 1. Compare current vs historical
SELECT * FROM table_name WHERE id = 123;
SELECT * FROM table_name AT(OFFSET => -600) WHERE id = 123;

-- 2. Restore specific columns
UPDATE table_name t
SET column = (
    SELECT column 
    FROM table_name AT(OFFSET => -600) 
    WHERE id = t.id
)
WHERE id = 123;
```

### Scenario 3: Dropped Table
```sql
-- Option 1: UNDROP (simplest)
UNDROP TABLE table_name;

-- Option 2: Restore from backup
CREATE TABLE table_name_restored
    FROM BACKUP SET backup_set_name
    BACKUP_ID => '<backup_id>';
```

### Scenario 4: Audit Trail
```sql
-- Compare changes over time
SELECT 
    'CURRENT' AS version,
    id, status, updated_at 
FROM table_name
UNION ALL
SELECT 
    'YESTERDAY' AS version,
    id, status, updated_at
FROM table_name AT(OFFSET => -86400)
ORDER BY id, version;
```

## 🎯 Decision Matrix

### Time Travel vs Backups

| Need | Time Travel | Backups |
|------|-------------|---------|
| Quick recovery (< 24 hours) | ✅ Best | ⚠️ Possible |
| Long-term retention (> 90 days) | ❌ No | ✅ Best |
| Regulatory compliance | ⚠️ Limited | ✅ Best |
| Immutable storage | ❌ No | ✅ Yes (BC Edition) |
| Ransomware protection | ⚠️ Limited | ✅ Best |
| Audit trails | ✅ Best | ⚠️ Manual |
| Zero setup | ✅ Yes | ❌ No |
| Point-in-time clones | ✅ Best | ⚠️ Possible |
| Storage efficiency | ✅ Best | ⚠️ Full snapshots |

## 📋 CRON Schedule Examples

```sql
-- Every hour
SCHEDULE = '60 MINUTES'

-- Daily at 2 AM ET
SCHEDULE = 'USING CRON 0 2 * * * America/New_York'

-- Every Sunday at midnight
SCHEDULE = 'USING CRON 0 0 * * 0 America/New_York'

-- First day of every month at 1 AM
SCHEDULE = 'USING CRON 0 1 1 * * America/New_York'

-- Weekdays at 6 PM
SCHEDULE = 'USING CRON 0 18 * * 1-5 America/New_York'

-- Every 4 hours
SCHEDULE = '240 MINUTES'
```

## 🔒 Retention Guidelines by Industry

| Industry | Typical Retention | Snowflake Feature |
|----------|------------------|-------------------|
| Healthcare (HIPAA) | 6 years | Backups with retention lock |
| Financial (SEC 17a-4) | 6-7 years | Backups with retention lock |
| Financial (FINRA 4511) | 6 years | Backups with retention lock |
| General Business | 30-90 days | Time Travel |
| Development/Testing | 1-7 days | Time Travel |
| Compliance Data | 2555 days (7 years) | Backups with retention lock |

## ⚠️ Important Gotchas

### Time Travel
- ⚠️ Data permanently deleted after retention + 7 day fail-safe
- ⚠️ ACCOUNTADMIN can drop tables even with Time Travel
- ⚠️ Enterprise Edition required for > 1 day retention
- ⚠️ Storage costs increase with retention period

### Backups
- ⚠️ Retention locks are **IRREVERSIBLE** - plan carefully!
- ⚠️ Cannot drop schema/database with unexpired locked backups
- ⚠️ Must restore to NEW object name (cannot overwrite)
- ⚠️ Business Critical Edition required for retention locks
- ⚠️ Storage costs accumulate over retention period

## 🚀 Quick Start Checklist

- [ ] Determine retention requirements (regulatory, business)
- [ ] Verify edition (Business Critical for full features)
- [ ] Configure Time Travel on critical tables (7-90 days)
- [ ] Create backup policies with appropriate schedules
- [ ] Create backup sets for critical data
- [ ] Test restore procedures
- [ ] Document recovery runbooks
- [ ] Set up monitoring alerts
- [ ] Review storage costs monthly
- [ ] Train team on recovery procedures
- [ ] Schedule quarterly disaster recovery drills

---

**Pro Tip**: Always test your recovery process before you need it! 🛡️

**Documentation**: 
- [Backups](https://docs.snowflake.com/en/user-guide/backups)
- [Time Travel](https://docs.snowflake.com/en/user-guide/data-time-travel)
