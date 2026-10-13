-- HOSTEL LUGGAGE MANAGEMENT & SLOT ALLOCATION SYSTEM
-- MySQL 8.4
-- IMPORTANT: This reset script drops and recreates hostel_luggage.
-- Back up anything important before running it.

DROP DATABASE IF EXISTS hostel_luggage;
CREATE DATABASE hostel_luggage;
USE hostel_luggage;

CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role ENUM('STUDENT','WARDEN','ADMIN') NOT NULL DEFAULT 'STUDENT',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE storage_slots (
    slot_id INT AUTO_INCREMENT PRIMARY KEY,
    slot_code VARCHAR(20) NOT NULL UNIQUE,
    location VARCHAR(100) NOT NULL,
    status ENUM('AVAILABLE','OCCUPIED','MAINTENANCE') NOT NULL DEFAULT 'AVAILABLE'
);

CREATE TABLE luggage_items (
    luggage_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    description VARCHAR(255) NOT NULL,
    tag_code VARCHAR(50) NOT NULL UNIQUE,
    status ENUM('REGISTERED','STORED','RETRIEVED') NOT NULL DEFAULT 'REGISTERED',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_luggage_user FOREIGN KEY (user_id) REFERENCES users(user_id)
);

CREATE TABLE allocations (
    allocation_id INT AUTO_INCREMENT PRIMARY KEY,
    luggage_id INT NOT NULL,
    slot_id INT NOT NULL,
    allocated_by INT NOT NULL,
    allocated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    released_at TIMESTAMP NULL,
    status ENUM('ACTIVE','RELEASED') NOT NULL DEFAULT 'ACTIVE',
    active_slot_id INT GENERATED ALWAYS AS
        (CASE WHEN status = 'ACTIVE' THEN slot_id ELSE NULL END) STORED,
    CONSTRAINT fk_alloc_luggage FOREIGN KEY (luggage_id) REFERENCES luggage_items(luggage_id),
    CONSTRAINT fk_alloc_slot FOREIGN KEY (slot_id) REFERENCES storage_slots(slot_id),
    CONSTRAINT fk_alloc_user FOREIGN KEY (allocated_by) REFERENCES users(user_id),
    CONSTRAINT uq_one_active_allocation_per_slot UNIQUE (active_slot_id)
);

INSERT INTO users (full_name, email, password_hash, role) VALUES
('Ritesh', 'ritesh@example.com', 'DEMO_ONLY_NOT_A_REAL_PASSWORD_HASH', 'STUDENT'),
('Tharini', 'tharini@example.com', 'DEMO_ONLY_NOT_A_REAL_PASSWORD_HASH', 'STUDENT'),
('Kaushik', 'kaushik@example.com', 'DEMO_ONLY_NOT_A_REAL_PASSWORD_HASH', 'STUDENT'),
('Hostel Warden', 'warden@example.com', 'DEMO_ONLY_NOT_A_REAL_PASSWORD_HASH', 'WARDEN');

INSERT INTO storage_slots (slot_code, location, status) VALUES
('A01','Storage Room A','AVAILABLE'),
('A02','Storage Room A','AVAILABLE'),
('A03','Storage Room A','AVAILABLE'),
('A04','Storage Room A','AVAILABLE'),
('A05','Storage Room A','AVAILABLE'),
('B01','Storage Room B','AVAILABLE'),
('B02','Storage Room B','AVAILABLE'),
('B03','Storage Room B','AVAILABLE'),
('B04','Storage Room B','AVAILABLE'),
('B05','Storage Room B','AVAILABLE');

DELIMITER //

CREATE TRIGGER check_luggage_limit
BEFORE INSERT ON luggage_items
FOR EACH ROW
BEGIN
    DECLARE active_count INT DEFAULT 0;
    SELECT COUNT(*) INTO active_count
    FROM luggage_items
    WHERE user_id = NEW.user_id AND status <> 'RETRIEVED';

    IF active_count >= 5 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Maximum 5 active luggage items allowed per student';
    END IF;
END//

CREATE TRIGGER sync_slot_occupied_after_allocation
AFTER INSERT ON allocations
FOR EACH ROW
BEGIN
    IF NEW.status = 'ACTIVE' THEN
        UPDATE storage_slots SET status = 'OCCUPIED'
        WHERE slot_id = NEW.slot_id;
        UPDATE luggage_items SET status = 'STORED'
        WHERE luggage_id = NEW.luggage_id;
    END IF;
END//

CREATE TRIGGER sync_slot_available_after_release
AFTER UPDATE ON allocations
FOR EACH ROW
BEGIN
    IF OLD.status = 'ACTIVE' AND NEW.status = 'RELEASED' THEN
        UPDATE storage_slots SET status = 'AVAILABLE'
        WHERE slot_id = NEW.slot_id
          AND NOT EXISTS (
              SELECT 1 FROM allocations
              WHERE slot_id = NEW.slot_id AND status = 'ACTIVE'
                AND allocation_id <> NEW.allocation_id
          );
        UPDATE luggage_items SET status = 'RETRIEVED'
        WHERE luggage_id = NEW.luggage_id;
    END IF;
END//

DELIMITER ;

-- Verification queries
SHOW TABLES;
SELECT * FROM users;
SELECT * FROM storage_slots;
SHOW TRIGGERS;
SHOW INDEX FROM allocations;
