# Snowflake BCDR Demo Scripts

This repository contains comprehensive demo scripts showcasing Snowflake's **Business Continuity and Disaster Recovery (BCDR)** features using a synthetic healthcare dataset.

## 📋 Overview

These scripts demonstrate two critical Snowflake features:
1. **Backups** - Long-term, immutable storage for compliance and ransomware protection
2. **Time Travel** - Short-term recovery for quick rollback of recent changes

## 🗂️ Script Files

### 1. `01_setup_healthcare_data.sql`
**Purpose**: Create the foundational synthetic healthcare dataset

**What it creates**:
- `healthcare_demo` database
- `patient_data` schema
- 4 tables with realistic healthcare data:
  - `patients` - 10 patient demographic records
  - `medical_records` - 11 visit records with diagnoses
  - `prescriptions` - 9 active prescriptions
  - `lab_results` - 9 laboratory test results
- 2 views for reporting and analytics

**Run time**: ~30 seconds

### 2. `02_backup_demo.sql`
**Purpose**: Demonstrate Snowflake's backup capabilities

**Key concepts covered**:
- Creating backup policies (daily, hourly, weekly schedules)
- Creating backup sets for tables, schemas, and databases
- Manual and automated backup creation
- Simulating data corruption scenarios
- Restoring from backups
- Managing backup retention and expiration
- Legal holds (Business Critical Edition feature)
- Monitoring backup storage and operations

**Features demonstrated**:
- ✅ Scheduled backups with cron expressions
- ✅ Retention policies (30-365 days)
- ✅ Disaster recovery workflows
- ✅ Backup storage management
- ✅ Retention locks for immutable storage
- ✅ Database, schema, and table-level backups

**Run time**: ~3-5 minutes

### 3. `03_time_travel_demo.sql`
**Purpose**: Demonstrate Snowflake's Time Travel feature

**Key concepts covered**:
- Configuring Time Travel retention (1-90 days)
- Querying historical data using TIMESTAMP, OFFSET, and STATEMENT
- Restoring deleted rows
- Undropping tables and schemas
- Creating audit trails by comparing current vs historical data
- Rolling back multiple changes at once
- Zero-copy cloning from historical points
- Recovering from mass deletions

**Features demonstrated**:
- ✅ Point-in-time queries (AT, BEFORE)
- ✅ UNDROP for deleted objects
- ✅ Historical data comparison for auditing
- ✅ Cloning from specific timestamps
- ✅ Mass data recovery techniques
- ✅ Automated recovery testing

**Run time**: ~3-5 minutes

## 🚀 Getting Started

### Prerequisites

- Snowflake account (any edition)
- ACCOUNTADMIN role or equivalent privileges to:
  - Create databases and schemas
  - Create backup policies and sets
  - Configure Time Travel retention
- SQL client (SnowSQL, Snowflake Web UI, or any SQL IDE)

### Edition Requirements

| Feature | Standard | Enterprise | Business Critical |
|---------|----------|------------|-------------------|
| Backups | ✅ | ✅ | ✅ |
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

**Alternative**: Copy and paste sections into your SQL worksheet and run interactively.

## 📖 Learning Objectives

After completing these demos, you'll understand:

### Backups
- ✅ When to use backups vs Time Travel
- ✅ How to protect against ransomware with retention locks
- ✅ Creating automated backup schedules
- ✅ Restoring tables, schemas, and databases
- ✅ Meeting regulatory compliance requirements (SEC 17a-4, FINRA, HIPAA)
- ✅ Monitoring backup storage costs

### Time Travel
- ✅ Querying data as it existed in the past
- ✅ Quick recovery from accidental changes
- ✅ Building audit trails
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
- ✅ Cross-region disaster recovery
- ✅ Selective protection of critical tables only

### When to Use Time Travel
- ✅ Quick recovery from recent mistakes (hours to days)
- ✅ Auditing recent data changes
- ✅ Creating point-in-time clones
- ✅ Development and testing workflows
- ✅ Automated, zero-configuration protection

### Best Practice: Use Both!
- **Time Travel**: Day-to-day operations, quick recovery
- **Backups**: Compliance, long-term retention, immutable storage

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
-- Drop the entire database (includes all tables, backups, and backup sets)
DROP DATABASE healthcare_demo;

-- Or keep the database and just remove backups
DROP BACKUP SET patients_backup_set;
DROP BACKUP SET medical_records_backup_set;
DROP BACKUP SET prescriptions_backup_set;
DROP BACKUP SET patient_data_schema_backup_set;
DROP BACKUP SET healthcare_db_backup_set;
DROP BACKUP POLICY daily_backup_policy;
DROP BACKUP POLICY hourly_backup_policy;
DROP BACKUP POLICY annual_backup_policy;
DROP BACKUP POLICY database_backup_policy;
```

## 📚 Additional Resources

- [Snowflake Backups Documentation](https://docs.snowflake.com/en/user-guide/backups)
- [Snowflake Time Travel Documentation](https://docs.snowflake.com/en/user-guide/data-time-travel)
- [Fail-safe Documentation](https://docs.snowflake.com/en/user-guide/data-failsafe)
- [Storage Costs for Historical Data](https://docs.snowflake.com/en/user-guide/storage-costs)
- [Replication and Failover](https://docs.snowflake.com/en/user-guide/replication-intro)

## 💡 Tips

1. **Read the comments**: Each script is heavily commented to explain concepts
2. **Run interactively**: Execute sections one at a time to see results
3. **Experiment**: Modify queries and scenarios to deepen understanding
4. **Test regularly**: Practice recovery procedures quarterly
5. **Monitor costs**: Review storage usage regularly in production

## 🤝 Contributing

This is a demo repository. Feel free to:
- Adapt for your industry (finance, retail, manufacturing, etc.)
- Add additional scenarios
- Extend with more complex data relationships
- Integrate with other Snowflake features (Streams, Tasks, etc.)

## 📄 License

These scripts are provided as educational examples for Snowflake BCDR features.

---

**Questions or Issues?** Review the inline comments in each script for detailed explanations.

**Ready to learn?** Start with `01_setup_healthcare_data.sql`! 🚀
