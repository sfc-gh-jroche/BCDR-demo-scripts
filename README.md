## Snowflake BCDR Demo Scripts

This repository contains streamlined demo scripts showcasing Snowflake's **Business Continuity and Disaster Recovery (BCDR)** features using a synthetic healthcare dataset.

## 📋 Overview

These scripts demonstrate two critical Snowflake features:
1. **Backups** - Long-term, immutable storage for compliance and ransomware protection
2. **Time Travel** - Short-term recovery for quick rollback of recent changes

**Note**: These demos assume **Business Critical Edition** for full feature access, though most features work on all editions.

## 🗂️ Script Files

### 1. `01_setup_healthcare_data.sql`
**Purpose**: Create the foundational synthetic healthcare dataset

**What it creates**:
- `healthcare_demo` database
- `patient_data` schema
- 2 tables with realistic healthcare data:
  - `patients` - 10 patient demographic records
  - `medical_records` - 11 visit records with diagnoses and foreign key relationship

**Lines**: ~135 lines  
**Run time**: ~15 seconds

### 2. `02_backup_demo.sql`
**Purpose**: Demonstrate Snowflake's backup capabilities

**Key concepts covered**:
- Creating backup policies with schedules and retention
- Creating backup sets for tables and schemas
- Manual backup creation before critical operations
- Simulating data corruption and recovery workflow
- Managing and monitoring backups
- Understanding retention locks and legal holds

**Features demonstrated**:
- ✅ Scheduled backups with CRON expressions
- ✅ Manual on-demand backups
- ✅ Table and schema-level backups
- ✅ Complete disaster recovery workflow
- ✅ Retention locks for immutable storage (Business Critical)
- ✅ Legal holds for compliance (Business Critical)

**Lines**: ~290 lines  
**Run time**: ~2-3 minutes

### 3. `03_time_travel_demo.sql`
**Purpose**: Demonstrate Snowflake's Time Travel feature

**Key concepts covered**:
- Configuring Time Travel retention (1-90 days)
- Querying historical data using AT(TIMESTAMP)
- Restoring deleted rows
- Undropping accidentally deleted tables
- Creating audit trails by comparing current vs historical data
- Rolling back unwanted changes
- Recovering from mass deletions

**Features demonstrated**:
- ✅ Point-in-time queries with AT(TIMESTAMP)
- ✅ UNDROP for deleted objects
- ✅ Historical data comparison for auditing
- ✅ Zero-copy cloning from historical points
- ✅ Mass data recovery techniques

**Lines**: ~315 lines  
**Run time**: ~2-3 minutes

## 🚀 Getting Started

### Prerequisites

**Snowflake Account**:
- **Business Critical Edition** (recommended for full feature access)
- Enterprise Edition works for most features (except retention locks and legal holds)
- Standard Edition works with limited Time Travel (1 day only)

**Permissions**:
- **ACCOUNTADMIN role** (simplest approach for demos), OR
- Your role needs these privileges (granted by ACCOUNTADMIN):
  ```sql
  GRANT CREATE DATABASE ON ACCOUNT TO ROLE your_role;
  GRANT CREATE BACKUP POLICY ON SCHEMA TO ROLE your_role;
  GRANT CREATE BACKUP SET ON SCHEMA TO ROLE your_role;
  GRANT APPLY BACKUP POLICY ON ACCOUNT TO ROLE your_role;
  ```

**SQL Client**:
- Snowflake Web UI (Snowsight)
- SnowSQL CLI
- Any SQL IDE with Snowflake connector

### Edition Requirements

| Feature | Standard | Enterprise | Business Critical |
|---------|----------|------------|-------------------|
| Backups (Basic) | ✅ | ✅ | ✅ |
| Time Travel (1 day) | ✅ | ✅ | ✅ |
| Time Travel (up to 90 days) | ❌ | ✅ | ✅ |
| Retention Locks | ❌ | ❌ | ✅ |
| Legal Holds | ❌ | ❌ | ✅ |

### Running the Scripts

Execute the scripts **in order**:

```sql
-- Step 1: Create the healthcare dataset
@01_setup_healthcare_data.sql

-- Step 2: Learn about backups
@02_backup_demo.sql

-- Step 3: Learn about Time Travel
@03_time_travel_demo.sql
```

**Alternative**: Copy and paste sections into your SQL worksheet and run interactively for better understanding.

## 📖 Learning Objectives

After completing these demos, you'll understand:

### Backups
- ✅ Creating backup policies with CRON schedules
- ✅ Creating backup sets for tables and schemas
- ✅ When to use backups vs Time Travel
- ✅ Protecting against ransomware with retention locks
- ✅ Restoring tables from backups after disasters
- ✅ Meeting regulatory compliance requirements (SEC 17a-4, FINRA, HIPAA)

### Time Travel
- ✅ Querying data as it existed in the past
- ✅ Quick recovery from accidental changes
- ✅ Building audit trails with historical comparisons
- ✅ Creating point-in-time clones for dev/test
- ✅ Undropping accidentally deleted objects
- ✅ Understanding storage implications

## 🎯 Real-World Use Cases

### Healthcare Industry (this demo)
- **Compliance**: HIPAA requires 6-year retention of medical records
- **Audit Trail**: Track all changes to patient data
- **Error Recovery**: Quickly restore accidentally modified prescriptions
- **Testing**: Clone production data for testing without impacting patients

### Financial Services
- **Regulatory**: SEC 17a-4(f) requires immutable storage
- **Ransomware Protection**: Retention locks prevent attackers from deleting backups
- **Fraud Investigation**: Time Travel enables forensic analysis

### General Business
- **Data Governance**: Maintain change history for compliance
- **Dev/Test**: Create isolated environments from production snapshots
- **Disaster Recovery**: Rapid recovery from human error or system failures

## 🔑 Key Takeaways

### When to Use Backups
- ✅ Long-term retention (months to years)
- ✅ Regulatory compliance requiring immutable storage
- ✅ Protection against ransomware
- ✅ Cross-region disaster recovery (with replication)
- ✅ Selective protection of critical tables only

### When to Use Time Travel
- ✅ Quick recovery from recent mistakes (hours to days)
- ✅ Auditing recent data changes
- ✅ Creating point-in-time clones
- ✅ Development and testing workflows
- ✅ Automated, zero-configuration protection

### Best Practice: Use Both!
- **Time Travel**: Day-to-day operations, quick recovery (automatic)
- **Backups**: Compliance, long-term retention, immutable storage (scheduled)
- **Together**: Complete BCDR strategy

## 📊 Cost Considerations

### Time Travel Storage
- Stores changed/deleted data within retention period
- Automatically managed by Snowflake
- Minimal overhead for small changes
- Consider reducing retention on large, frequently-changing tables

### Backup Storage
- Full snapshots stored separately
- Storage costs based on data size and retention period
- Use `BACKUP_STORAGE_USAGE` view to monitor costs
- Balance retention needs with budget

## 🧹 Cleanup

To remove all demo objects after completion:

```sql
-- Drop the entire database (includes all tables and backup sets)
DROP DATABASE healthcare_demo;

-- Backup policies exist at schema level, so they're dropped with the database
```

If you want to keep the database but remove backups:

```sql
USE DATABASE healthcare_demo;
USE SCHEMA patient_data;

DROP BACKUP SET patients_backup_set;
DROP BACKUP SET patient_data_schema_backup;
DROP BACKUP POLICY daily_backup_policy;
DROP BACKUP POLICY manual_backup_policy;
```

## 📚 Additional Resources

- [Snowflake Backups Documentation](https://docs.snowflake.com/en/user-guide/backups)
- [Snowflake Time Travel Documentation](https://docs.snowflake.com/en/user-guide/data-time-travel)
- [Fail-safe Documentation](https://docs.snowflake.com/en/user-guide/data-failsafe)
- [Storage Costs for Historical Data]((https://docs.snowflake.com/en/user-guide/data-cdp-storage-costs))
- [Replication and Failover](https://docs.snowflake.com/en/user-guide/replication-intro)

## 💡 Tips

1. **Read the comments**: Each script is heavily commented to explain concepts
2. **Run interactively**: Execute sections one at a time to see results
3. **Experiment**: Modify queries and scenarios to deepen understanding
4. **Test regularly**: Practice recovery procedures quarterly
5. **Monitor costs**: Review storage usage regularly in production

## 🤝 Feedback

This is a demo repository designed for learning. Feel free to:
- Adapt for your industry (finance, retail, manufacturing, etc.)
- Add additional scenarios
- Extend with more complex data relationships
- Integrate with other Snowflake features (Streams, Tasks, Replication, etc.)

---

**Questions or Issues?** Review the inline comments in each script for detailed explanations.

**Ready to learn?** Start with `01_setup_healthcare_data.sql`! 🚀
