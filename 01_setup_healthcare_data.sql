-- ============================================================================
-- SCRIPT 1: Setup Healthcare Data for BCDR Demo
-- ============================================================================
-- Purpose: Create synthetic healthcare dataset for demonstrating Snowflake's
--          Business Continuity and Disaster Recovery (BCDR) features
-- Author: Snowflake Demo
-- Date: 2026-01-06
-- ============================================================================

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
-- TABLE 3: PRESCRIPTIONS
-- ============================================================================
-- This table stores prescription medication information

CREATE OR REPLACE TABLE prescriptions (
    prescription_id INT AUTOINCREMENT PRIMARY KEY,
    patient_id INT,
    record_id INT,
    medication_name VARCHAR(200),
    dosage VARCHAR(50),
    frequency VARCHAR(100),
    start_date DATE,
    end_date DATE,
    prescribing_physician VARCHAR(100),
    refills_remaining INT,
    pharmacy VARCHAR(100),
    status VARCHAR(20),
    created_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id),
    FOREIGN KEY (record_id) REFERENCES medical_records(record_id)
);

-- Insert synthetic prescription records
INSERT INTO prescriptions (patient_id, record_id, medication_name, dosage, frequency, start_date, end_date, prescribing_physician, refills_remaining, pharmacy, status)
VALUES
    (1, 1, 'Lisinopril', '10mg', 'Once daily', '2025-12-15', '2026-06-15', 'Dr. Amanda Chen', 5, 'CVS Pharmacy - Boston', 'Active'),
    (1, 2, 'Metformin', '500mg', 'Twice daily with meals', '2025-11-20', '2026-05-20', 'Dr. Robert Park', 3, 'CVS Pharmacy - Boston', 'Active'),
    (2, 3, 'Amoxicillin', '500mg', 'Three times daily', '2025-12-28', '2026-01-08', 'Dr. Sarah Williams', 0, 'Walgreens - Cambridge', 'Active'),
    (3, 4, 'Ibuprofen', '600mg', 'Every 6 hours as needed', '2025-12-10', '2026-01-10', 'Dr. James Kumar', 0, 'Rite Aid - Somerville', 'Active'),
    (5, 6, 'Furosemide', '40mg', 'Once daily in morning', '2025-11-30', '2026-05-30', 'Dr. Amanda Chen', 5, 'Stop & Shop Pharmacy - Newton', 'Active'),
    (5, 6, 'Carvedilol', '12.5mg', 'Twice daily', '2025-11-30', '2026-05-30', 'Dr. Amanda Chen', 5, 'Stop & Shop Pharmacy - Newton', 'Active'),
    (6, 7, 'Prenatal Vitamins', '1 tablet', 'Once daily', '2025-12-18', '2026-09-18', 'Dr. Maria Santos', 8, 'CVS Pharmacy - Waltham', 'Active'),
    (8, 9, 'Sertraline', '50mg', 'Once daily', '2025-12-20', '2026-06-20', 'Dr. Lisa Patterson', 5, 'Walgreens - Medford', 'Active'),
    (9, 10, 'Albuterol Inhaler', '90mcg', '2 puffs every 4-6 hours as needed', '2025-12-29', '2026-06-29', 'Dr. Robert Park', 3, 'CVS Pharmacy - Arlington', 'Active');

-- ============================================================================
-- TABLE 4: LAB_RESULTS
-- ============================================================================
-- This table stores laboratory test results

CREATE OR REPLACE TABLE lab_results (
    lab_id INT AUTOINCREMENT PRIMARY KEY,
    patient_id INT,
    record_id INT,
    test_name VARCHAR(200),
    test_code VARCHAR(20),
    result_value VARCHAR(50),
    unit_of_measure VARCHAR(20),
    reference_range VARCHAR(50),
    status VARCHAR(20),
    abnormal_flag BOOLEAN,
    test_date TIMESTAMP_LTZ,
    result_date TIMESTAMP_LTZ,
    performing_lab VARCHAR(100),
    created_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id),
    FOREIGN KEY (record_id) REFERENCES medical_records(record_id)
);

-- Insert synthetic lab results
INSERT INTO lab_results (patient_id, record_id, test_name, test_code, result_value, unit_of_measure, reference_range, status, abnormal_flag, test_date, result_date, performing_lab)
VALUES
    (1, 1, 'Hemoglobin A1C', 'HBA1C', '6.8', '%', '4.0-5.6', 'Final', TRUE, '2025-11-20 08:30:00', '2025-11-20 14:45:00', 'Quest Diagnostics'),
    (1, 1, 'Fasting Glucose', 'GLU', '125', 'mg/dL', '70-100', 'Final', TRUE, '2025-11-20 08:30:00', '2025-11-20 14:45:00', 'Quest Diagnostics'),
    (1, 1, 'Total Cholesterol', 'CHOL', '198', 'mg/dL', '<200', 'Final', FALSE, '2025-11-20 08:30:00', '2025-11-20 14:45:00', 'Quest Diagnostics'),
    (1, 1, 'LDL Cholesterol', 'LDL', '115', 'mg/dL', '<100', 'Final', TRUE, '2025-11-20 08:30:00', '2025-11-20 14:45:00', 'Quest Diagnostics'),
    (4, 5, 'Complete Blood Count', 'CBC', 'Normal', 'N/A', 'Normal ranges', 'Final', FALSE, '2025-12-22 09:00:00', '2025-12-22 16:30:00', 'LabCorp'),
    (4, 5, 'Thyroid Stimulating Hormone', 'TSH', '2.1', 'mIU/L', '0.4-4.0', 'Final', FALSE, '2025-12-22 09:00:00', '2025-12-22 16:30:00', 'LabCorp'),
    (5, 6, 'B-type Natriuretic Peptide', 'BNP', '425', 'pg/mL', '<100', 'Final', TRUE, '2025-11-30 10:15:00', '2025-11-30 18:00:00', 'Quest Diagnostics'),
    (5, 6, 'Creatinine', 'CREAT', '1.3', 'mg/dL', '0.7-1.3', 'Final', FALSE, '2025-11-30 10:15:00', '2025-11-30 18:00:00', 'Quest Diagnostics'),
    (6, 7, 'hCG Quantitative', 'HCG', '15240', 'mIU/mL', 'Varies by trimester', 'Final', FALSE, '2025-12-18 11:00:00', '2025-12-18 19:30:00', 'LabCorp');

-- ============================================================================
-- Create some useful views for reporting
-- ============================================================================

-- View: Complete patient summary with latest visit information
CREATE OR REPLACE VIEW patient_summary AS
SELECT 
    p.patient_id,
    p.first_name || ' ' || p.last_name AS patient_name,
    p.date_of_birth,
    DATEDIFF('year', p.date_of_birth, CURRENT_DATE()) AS age,
    p.gender,
    p.insurance_provider,
    COUNT(DISTINCT mr.record_id) AS total_visits,
    MAX(mr.visit_date) AS last_visit_date,
    COUNT(DISTINCT pr.prescription_id) AS active_prescriptions
FROM patients p
LEFT JOIN medical_records mr ON p.patient_id = mr.patient_id
LEFT JOIN prescriptions pr ON p.patient_id = pr.patient_id AND pr.status = 'Active'
GROUP BY p.patient_id, p.first_name, p.last_name, p.date_of_birth, p.gender, p.insurance_provider;

-- View: Patients with chronic conditions requiring ongoing monitoring
CREATE OR REPLACE VIEW chronic_care_patients AS
SELECT 
    p.patient_id,
    p.first_name || ' ' || p.last_name AS patient_name,
    mr.diagnosis_description,
    mr.treating_physician,
    mr.visit_date AS last_visit,
    COUNT(pr.prescription_id) AS medication_count
FROM patients p
JOIN medical_records mr ON p.patient_id = mr.patient_id
LEFT JOIN prescriptions pr ON mr.record_id = pr.record_id
WHERE mr.diagnosis_code IN ('I10', 'E11.9', 'I50.9', 'J45.909', 'F41.1')
GROUP BY p.patient_id, p.first_name, p.last_name, mr.diagnosis_description, mr.treating_physician, mr.visit_date;

-- ============================================================================
-- Verify data creation
-- ============================================================================

-- Show record counts
SELECT 'Patients' AS table_name, COUNT(*) AS record_count FROM patients
UNION ALL
SELECT 'Medical Records', COUNT(*) FROM medical_records
UNION ALL
SELECT 'Prescriptions', COUNT(*) FROM prescriptions
UNION ALL
SELECT 'Lab Results', COUNT(*) FROM lab_results;

-- Display sample data from patient summary view
SELECT * FROM patient_summary
ORDER BY patient_id
LIMIT 5;

-- ============================================================================
-- SETUP COMPLETE!
-- ============================================================================
-- You now have a synthetic healthcare dataset with:
--   - 10 patients with demographic information
--   - 11 medical records with diagnoses and visit notes
--   - 9 active prescriptions
--   - 9 lab test results
--   - 2 reporting views
--
-- Next steps:
--   1. Run script 02_backup_demo.sql to learn about Snowflake backups
--   2. Run script 03_time_travel_demo.sql to learn about Time Travel
-- ============================================================================

