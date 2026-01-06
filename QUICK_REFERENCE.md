# Snowflake BCDR Quick Reference Guide

## 🔄 Time Travel Commands

### Query Historical Data

```sql
-- Using timestamp
SELECT * FROM table_name AT(TIMESTAMP => '2026-01-01 10:00:00'::TIMESTAMP_LTZ);

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
-- Clone table
CREATE TABLE table_clone 
    CLONE original_table 
    AT(TIMESTAMP => '<timestamp>');

-- Clone schema
CREATE SCHEMA schema_clone 
    CLONE original_schema 
    AT(OFFSET => -86400);  -- 24 hours ago

-- Clone database
CREATE DATABASE db_clone 
    CLONE original_db 
    BEFORE(STATEMENT => '<query_id>');
```

### Configure Retention

```sql
-- Set retention at table level (1-90 days, Enterprise+)
ALTER TABLE table_name SET DATA_RETENTION_TIME_IN_DAYS = 7;

-- Set retention at schema level
ALTER SCHEMA schema_name SET DATA_RETENTION_TIME_IN_DAYS = 30;

-- Set retention at database level
ALTER DATABASE db_name SET DATA_RETENTION_TIME_IN_DAYS = 90;

-- Check retention settings
SHOW TABLES;
SELECT table_name, retention_time 
FROM information_schema.tables 
WHERE table_schema = 'SCHEMA_NAME';
```

## 💾 Backup Commands

### Create Backup Policies

```sql
-- Backup policy with schedule and retention
CREATE BACKUP POLICY policy_name
    BACKUP_SCHEDULE = 'USING CRON 0 2 * * * America/New_York'  -- Daily at 2 AM
    BACKUP_EXPIRATION_TIME = 30;  -- Keep for 30 days

-- Backup policy with interval
CREATE BACKUP POLICY policy_name
    BACKUP_SCHEDULE = '60 MINUTES'
    BACKUP_EXPIRATION_TIME = 7;

-- Backup policy with retention lock (Business Critical)
CREATE BACKUP POLICY policy_name
    BACKUP_SCHEDULE = 'USING CRON 0 0 * * 0 America/New_York'  -- Weekly
    BACKUP_EXPIRATION_TIME = 2555  -- 7 years
    BACKUP_RETENTION_LOCK = TRUE;  -- Immutable!

-- Modify policy
ALTER BACKUP POLICY policy_name
    SET BACKUP_EXPIRATION_TIME = 60;

-- Drop policy
DROP BACKUP POLICY policy_name;
```

### Create Backup Sets

```sql
-- Table backup with policy
CREATE BACKUP SET backup_set_name
    AS COPY OF TABLE table_name
    BACKUP_POLICY = policy_name;

-- Schema backup
CREATE BACKUP SET backup_set_name
    AS COPY OF SCHEMA schema_name
    BACKUP_POLICY = policy_name;

-- Database backup
CREATE BACKUP SET backup_set_name
    AS COPY OF DATABASE database_name
    BACKUP_POLICY = policy_name;

-- Backup set without policy (manual backups only)
CREATE BACKUP SET backup_set_name
    AS COPY OF TABLE table_name;
```

### Manage Backups

```sql
-- Create manual backup
ALTER BACKUP SET backup_set_name
    ADD BACKUP
    COMMENT = 'Pre-migration backup';

-- Delete specific backup
ALTER BACKUP SET backup_set_name
    DELETE BACKUP '<backup_id>';

-- Suspend automatic backups
ALTER BACKUP SET backup_set_name
    SUSPEND BACKUP POLICY;

-- Resume automatic backups
ALTER BACKUP SET backup_set_name
    RESUME BACKUP POLICY;

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
```

### Restore from Backup

```sql
-- Restore table (must use new name)
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
    DELETE LEGAL HOLD FROM BACKUP '<backup_id>';
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
FROM snowflake.account_usage.table_storage_metrics
WHERE table_catalog = 'DATABASE_NAME'
ORDER BY time_travel_bytes DESC;

-- Backup storage usage
SELECT *
FROM snowflake.account_usage.backup_storage_usage
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
FROM snowflake.account_usage.query_history
WHERE (rows_inserted > 0 OR rows_updated > 0 OR rows_deleted > 0)
    AND execution_status = 'SUCCESS'
ORDER BY start_time DESC
LIMIT 50;
```

### Backup Operations

```sql
-- Backup operation history
SELECT *
FROM snowflake.account_usage.backup_operation_history
WHERE database_name = 'DATABASE_NAME'
ORDER BY start_time DESC
LIMIT 20;
```

## ⚡ Common Scenarios

### Scenario 1: Accidental DELETE
```sql
-- 1. Check current state
SELECT COUNT(*) FROM table_name;

-- 2. Query before deletion
SELECT * FROM table_name AT(OFFSET => -300);  -- 5 minutes ago

-- 3. Restore deleted rows
INSERT INTO table_name
SELECT * FROM table_name AT(OFFSET => -300)
WHERE id NOT IN (SELECT id FROM table_name);
```

### Scenario 2: Accidental UPDATE
```sql
-- 1. Compare current vs historical
SELECT * FROM table_name WHERE id = 123;
SELECT * FROM table_name AT(OFFSET => -600) WHERE id = 123;

-- 2. Restore specific rows
UPDATE table_name
SET column = (SELECT column FROM table_name AT(OFFSET => -600) WHERE id = 123)
WHERE id = 123;
```

### Scenario 3: Dropped Table
```sql
-- Option 1: UNDROP
UNDROP TABLE table_name;

-- Option 2: Clone from backup
CREATE TABLE table_name_restored
FROM BACKUP SET backup_set_name
BACKUP_ID => '<backup_id>';
```

### Scenario 4: Full Table Rollback
```sql
-- Save current state (optional)
CREATE TABLE table_backup AS SELECT * FROM table_name;

-- Replace with historical version
CREATE OR REPLACE TABLE table_name 
    CLONE table_name 
    AT(TIMESTAMP => '2026-01-01 10:00:00'::TIMESTAMP_LTZ);
```

### Scenario 5: Audit Trail
```sql
-- Compare changes over time
SELECT 
    'CURRENT' AS version,
    id, 
    status, 
    updated_at 
FROM table_name
UNION ALL
SELECT 
    'YESTERDAY' AS version,
    id,
    status,
    updated_at
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
| Storage efficiency | ✅ Best | ⚠️ Full copies |

## 📋 Cron Schedule Examples

```sql
-- Every hour
'60 MINUTES'

-- Daily at 2 AM ET
'USING CRON 0 2 * * * America/New_York'

-- Every Sunday at midnight
'USING CRON 0 0 * * 0 America/New_York'

-- First day of every month at 1 AM
'USING CRON 0 1 1 * * America/New_York'

-- Weekdays at 6 PM
'USING CRON 0 18 * * 1-5 America/New_York'

-- Every 4 hours
'240 MINUTES'
```

## 🔒 Retention Guidelines by Industry

| Industry | Typical Retention | Feature |
|----------|------------------|---------|
| Healthcare (HIPAA) | 6 years | Backups |
| Financial (SEC 17a-4) | 6-7 years | Backups + Lock |
| Financial (FINRA 4511) | 6 years | Backups + Lock |
| General Business | 30-90 days | Time Travel |
| Development/Testing | 1-7 days | Time Travel |
| Sensitive Data | 2555 days (7 years) | Backups + Lock |

## ⚠️ Important Gotchas

### Time Travel
- ⚠️ Data permanently deleted after retention + 7 day fail-safe
- ⚠️ ACCOUNTADMIN can bypass Time Travel with DROP + PURGE
- ⚠️ Enterprise Edition required for > 1 day retention
- ⚠️ Storage costs increase with retention period

### Backups
- ⚠️ Retention locks are **irreversible** - plan carefully!
- ⚠️ Cannot drop schema/database with unexpired locked backups
- ⚠️ Must restore to NEW object name (not original)
- ⚠️ Business Critical Edition required for retention locks
- ⚠️ Storage costs accumulate over retention period

## 🚀 Quick Start Checklist

- [ ] Determine retention requirements (regulatory, business)
- [ ] Choose Enterprise Edition for Time Travel > 1 day
- [ ] Choose Business Critical for immutable backups
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

