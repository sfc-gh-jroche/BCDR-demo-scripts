-- ============================================================================
-- SCRIPT 1: Setup Healthcare Data for BCDR Demo
-- ============================================================================
-- Purpose: Create synthetic healthcare dataset for demonstrating Snowflake's
--          Business Continuity and Disaster Recovery (BCDR) features
-- Documentation: https://docs.snowflake.com/en/user-guide/backups
--                https://docs.snowflake.com/en/user-guide/data-time-travel
-- ============================================================================

-- NOTE: This demo assumes Business Critical Edition for full feature access
-- Backups are available in all editions
-- Time Travel > 1 day requires Enterprise or Business Critical Edition

-- Create a dedicated database for our demo
CREATE OR REPLACE DATABASE healthcare_demo;

-- Switch to our new database
USE DATABASE healthcare_demo;

-- Create a schema to organize our objects
CREATE OR REPLACE SCHEMA patient_data;

-- Switch to our new schema
USE SCHEMA patient_data;

-- ============================================================================
-- TABLE 1: PATIENTS
-- ============================================================================
-- This table stores basic patient demographic information

CREATE OR REPLACE TABLE patients (
    patient_id INT AUTOINCREMENT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    date_of_birth DATE,
    gender VARCHAR(10),
    email VARCHAR(100),
    phone VARCHAR(20),
    address VARCHAR(200),
    city VARCHAR(50),
    state VARCHAR(2),
    zip_code VARCHAR(10),
    insurance_provider VARCHAR(100),
    created_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Insert synthetic patient records
INSERT INTO patients (first_name, last_name, date_of_birth, gender, email, phone, address, city, state, zip_code, insurance_provider)
VALUES
    ('John', 'Smith', '1975-03-15', 'Male', 'john.smith@email.com', '555-0101', '123 Main St', 'Boston', 'MA', '02101', 'Blue Cross Blue Shield'),
    ('Sarah', 'Johnson', '1982-07-22', 'Female', 'sarah.j@email.com', '555-0102', '456 Oak Ave', 'Cambridge', 'MA', '02138', 'Aetna'),
    ('Michael', 'Williams', '1968-11-08', 'Male', 'mwilliams@email.com', '555-0103', '789 Pine St', 'Somerville', 'MA', '02143', 'United Healthcare'),
    ('Emily', 'Brown', '1990-05-30', 'Female', 'emily.brown@email.com', '555-0104', '321 Elm St', 'Brookline', 'MA', '02445', 'Cigna'),
    ('David', 'Jones', '1955-12-12', 'Male', 'djones@email.com', '555-0105', '654 Maple Dr', 'Newton', 'MA', '02458', 'Medicare'),
    ('Lisa', 'Garcia', '1978-09-25', 'Female', 'lisa.garcia@email.com', '555-0106', '987 Cedar Ln', 'Waltham', 'MA', '02451', 'Blue Cross Blue Shield'),
    ('Robert', 'Martinez', '1985-02-14', 'Male', 'rmartinez@email.com', '555-0107', '147 Birch Rd', 'Quincy', 'MA', '02169', 'Aetna'),
    ('Jennifer', 'Davis', '1973-06-18', 'Female', 'jdavis@email.com', '555-0108', '258 Spruce St', 'Medford', 'MA', '02155', 'United Healthcare'),
    ('William', 'Rodriguez', '1992-04-03', 'Male', 'wrodriguez@email.com', '555-0109', '369 Willow Way', 'Arlington', 'MA', '02474', 'Harvard Pilgrim'),
    ('Amanda', 'Wilson', '1987-08-27', 'Female', 'awilson@email.com', '555-0110', '741 Ash Blvd', 'Lexington', 'MA', '02420', 'Tufts Health Plan');

-- ============================================================================
-- TABLE 2: MEDICAL_RECORDS
-- ============================================================================
-- This table stores patient medical visit records and diagnoses

CREATE OR REPLACE TABLE medical_records (
    record_id INT AUTOINCREMENT PRIMARY KEY,
    patient_id INT,
    visit_date DATE,
    diagnosis_code VARCHAR(10),
    diagnosis_description VARCHAR(500),
    treating_physician VARCHAR(100),
    department VARCHAR(50),
    visit_type VARCHAR(50),
    notes TEXT,
    created_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id)
);

-- Insert synthetic medical records
INSERT INTO medical_records (patient_id, visit_date, diagnosis_code, diagnosis_description, treating_physician, department, visit_type, notes)
VALUES
    (1, '2025-12-15', 'I10', 'Essential (primary) hypertension', 'Dr. Amanda Chen', 'Cardiology', 'Follow-up', 'Patient responding well to medication. Blood pressure within normal range.'),
    (1, '2025-11-20', 'E11.9', 'Type 2 diabetes mellitus without complications', 'Dr. Robert Park', 'Endocrinology', 'Regular Visit', 'A1C levels improving. Continue current medication regimen.'),
    (2, '2025-12-28', 'J06.9', 'Acute upper respiratory infection', 'Dr. Sarah Williams', 'Primary Care', 'Urgent Care', 'Prescribed antibiotics. Follow up if symptoms persist beyond 7 days.'),
    (3, '2025-12-10', 'M54.5', 'Low back pain', 'Dr. James Kumar', 'Orthopedics', 'New Patient', 'Recommended physical therapy and pain management. Schedule MRI if no improvement.'),
    (4, '2025-12-22', 'Z00.00', 'Routine annual physical', 'Dr. Emily Thompson', 'Primary Care', 'Preventive', 'All vital signs normal. Patient in good health. Next annual exam in 12 months.'),
    (5, '2025-11-30', 'I50.9', 'Heart failure', 'Dr. Amanda Chen', 'Cardiology', 'Follow-up', 'Monitoring closely. Adjusted medication dosage. Weekly follow-ups recommended.'),
    (6, '2025-12-18', 'O09.00', 'Prenatal care - first trimester', 'Dr. Maria Santos', 'OB/GYN', 'Regular Visit', 'Mother and fetus healthy. Prescribed prenatal vitamins. Next visit in 4 weeks.'),
    (7, '2026-01-05', 'S93.40', 'Sprain of ankle', 'Dr. James Kumar', 'Orthopedics', 'Urgent Care', 'Applied brace. Rest and ice recommended. Follow up in 2 weeks.'),
    (8, '2025-12-20', 'F41.1', 'Generalized anxiety disorder', 'Dr. Lisa Patterson', 'Psychiatry', 'New Patient', 'Started on SSRI. Weekly therapy sessions scheduled. Monitor for side effects.'),
    (9, '2025-12-29', 'J45.909', 'Asthma', 'Dr. Robert Park', 'Pulmonology', 'Follow-up', 'Inhaler technique reviewed. Symptoms well-controlled with current treatment.'),
    (10, '2026-01-02', 'Z12.31', 'Screening mammogram', 'Dr. Maria Santos', 'Radiology', 'Preventive', 'Mammogram completed. Results normal. Next screening in 1 year.');

-- ============================================================================
-- Verify data creation
-- ============================================================================
-- Show record counts for both tables
SELECT 'Patients' AS table_name, COUNT(*) AS record_count FROM patients
UNION ALL
SELECT 'Medical Records', COUNT(*) FROM medical_records;
-- Display sample data
SELECT 
    p.patient_id,
    p.first_name || ' ' || p.last_name AS patient_name,
    p.date_of_birth,
    p.insurance_provider,
    COUNT(mr.record_id) AS total_visits
FROM patients p
LEFT JOIN medical_records mr ON p.patient_id = mr.patient_id
GROUP BY p.patient_id, p.first_name, p.last_name, p.date_of_birth, p.insurance_provider
ORDER BY p.patient_id
LIMIT 5;

-- ============================================================================
-- SETUP COMPLETE!
-- ============================================================================
-- You now have a synthetic healthcare dataset with:
--   - 10 patients with demographic information
--   - 11 medical records with diagnoses and visit notes
--
-- Next steps:
--   1. Run script 02_backup_demo.sql to learn about Snowflake backups
--   2. Run script 03_time_travel_demo.sql to learn about Time Travel
-- ============================================================================

