-- =====================================================================
-- CarGo Rentals — Car Rental Management System
-- DBMS Open-Ended Lab Assignment
-- Compatible with: MySQL 8.0+ / MariaDB 10.4+ (phpMyAdmin / XAMPP)
-- =====================================================================
-- CONTENTS:
--   1. Database & Table Creation (with PK, FK, constraints)
--   2. Sample Data (Customers, Vehicles, Rentals, Payments)
--   3. Task 3: JOIN Queries (1-4)
--   4. Task 4: VIEW
--   5. Task 5: TRIGGERS (availability guard + auto status update)
--   6. Task 6: STORED PROCEDURE (sp_register_rental)
--   7. Task 7: Optimization (Indexes) + demonstration
-- =====================================================================

DROP DATABASE IF EXISTS car_rental_db;
CREATE DATABASE car_rental_db;
USE car_rental_db;

-- =====================================================================
-- 1. TABLE CREATION
-- =====================================================================

-- ---------------------------------------------------------------------
-- Table: Customers
-- ---------------------------------------------------------------------
CREATE TABLE Customers (
    CustomerID      INT AUTO_INCREMENT PRIMARY KEY,
    FullName        VARCHAR(100)    NOT NULL,
    Phone           VARCHAR(20)     NOT NULL UNIQUE,
    Email           VARCHAR(100)    UNIQUE,
    Address         VARCHAR(255),
    CNIC            VARCHAR(20)     NOT NULL UNIQUE,          -- national ID / license number
    DateRegistered  DATE            NOT NULL DEFAULT (CURRENT_DATE)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Table: Vehicles
-- Status is maintained automatically by triggers (Task 5) so that a
-- vehicle can never be shown as Available while it has an active rental.
-- ---------------------------------------------------------------------
CREATE TABLE Vehicles (
    VehicleID       INT AUTO_INCREMENT PRIMARY KEY,
    VehicleNumber   VARCHAR(20)     NOT NULL UNIQUE,          -- number plate
    Make            VARCHAR(50)     NOT NULL,
    Model           VARCHAR(50)     NOT NULL,
    Category        VARCHAR(30)     NOT NULL DEFAULT 'Sedan',
    DailyRate       DECIMAL(10,2)   NOT NULL CHECK (DailyRate > 0),
    Status          ENUM('Available','Rented','Maintenance') NOT NULL DEFAULT 'Available'
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Table: Rentals
-- Core business rule enforced here + via trigger:
--   a vehicle cannot be booked again while an existing rental on that
--   vehicle has not been returned (ActualReturnDate IS NULL).
-- ---------------------------------------------------------------------
CREATE TABLE Rentals (
    RentalID            INT AUTO_INCREMENT PRIMARY KEY,
    CustomerID          INT             NOT NULL,
    VehicleID           INT             NOT NULL,
    RentalDate          DATE            NOT NULL,
    ScheduledReturnDate DATE            NOT NULL,
    ActualReturnDate    DATE            NULL,                 -- NULL = still out / active
    DailyRateApplied    DECIMAL(10,2)   NOT NULL,
    TotalAmount         DECIMAL(10,2)   NOT NULL CHECK (TotalAmount >= 0),
    RentalStatus        ENUM('Active','Completed','Cancelled') NOT NULL DEFAULT 'Active',
    CONSTRAINT fk_rentals_customer
        FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_rentals_vehicle
        FOREIGN KEY (VehicleID) REFERENCES Vehicles(VehicleID)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_return_after_rental
        CHECK (ScheduledReturnDate >= RentalDate),
    CONSTRAINT chk_actual_return_valid
        CHECK (ActualReturnDate IS NULL OR ActualReturnDate >= RentalDate)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Table: Payments
-- A rental can (in principle) have more than one payment (advance +
-- final settlement), so this is a 1-to-many relationship with Rentals.
-- ---------------------------------------------------------------------
CREATE TABLE Payments (
    PaymentID       INT AUTO_INCREMENT PRIMARY KEY,
    RentalID        INT             NOT NULL,
    PaymentDate     DATE            NOT NULL DEFAULT (CURRENT_DATE),
    AmountPaid      DECIMAL(10,2)   NOT NULL CHECK (AmountPaid > 0),
    PaymentMethod   ENUM('Cash','Card','Bank Transfer','Mobile Wallet') NOT NULL DEFAULT 'Cash',
    PaymentStatus   ENUM('Pending','Completed','Refunded') NOT NULL DEFAULT 'Completed',
    CONSTRAINT fk_payments_rental
        FOREIGN KEY (RentalID) REFERENCES Rentals(RentalID)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;


-- =====================================================================
-- 2. SAMPLE DATA
-- =====================================================================

-- ---------------- Customers (5) ----------------
INSERT INTO Customers (FullName, Phone, Email, Address, CNIC) VALUES
('Ali Khan',        '0300-1234567', 'ali.khan@example.com',      'Street 12, F-8, Islamabad',   '37405-1234567-1'),
('Sara Ahmed',      '0311-2345678', 'sara.ahmed@example.com',    'House 45, DHA Phase 5, Lahore','35202-2345678-2'),
('Bilal Hussain',   '0333-3456789', 'bilal.h@example.com',       'Flat 3B, Gulshan, Karachi',    '42101-3456789-3'),
('Ayesha Malik',    '0345-4567890', 'ayesha.malik@example.com',  'Model Town, Lahore',           '35201-4567890-4'),
('Usman Tariq',     '0321-5678901', 'usman.tariq@example.com',   'G-9 Markaz, Islamabad',        '37405-5678901-5');

-- ---------------- Vehicles (6, so at least one stays Available) ----------------
INSERT INTO Vehicles (VehicleNumber, Make, Model, Category, DailyRate, Status) VALUES
('ABC-123', 'Toyota',   'Corolla',   'Sedan',   5000.00, 'Available'),
('XYZ-789', 'Honda',    'Civic',     'Sedan',   5500.00, 'Available'),
('LEA-456', 'Suzuki',   'Alto',      'Hatchback',3000.00, 'Available'),
('KHI-321', 'Toyota',   'Hilux',     'Pickup',   8000.00, 'Available'),
('LHR-654', 'Honda',    'City',      'Sedan',    4800.00, 'Available'),
('ISB-987', 'Kia',      'Sportage',  'SUV',      7500.00, 'Available');

-- ---------------- Rentals (5) ----------------
-- Rentals 1-2: Completed (returned). Rentals 3-4: Active (currently out).
-- Rental 5: Completed. This leaves 2 vehicles Available and 2 Rented
-- once the triggers below fire retroactively via the stored logic.

-- Completed rental 1: Ali Khan rented the Corolla, already returned
INSERT INTO Rentals (CustomerID, VehicleID, RentalDate, ScheduledReturnDate, ActualReturnDate, DailyRateApplied, TotalAmount, RentalStatus)
VALUES (1, 1, '2026-09-01', '2026-09-04', '2026-09-04', 5000.00, 15000.00, 'Completed');

-- Completed rental 2: Sara Ahmed rented the Alto, already returned
INSERT INTO Rentals (CustomerID, VehicleID, RentalDate, ScheduledReturnDate, ActualReturnDate, DailyRateApplied, TotalAmount, RentalStatus)
VALUES (2, 3, '2026-08-20', '2026-08-22', '2026-08-22', 3000.00, 6000.00, 'Completed');

-- Active rental 3: Bilal Hussain currently has the Civic (not yet returned)
INSERT INTO Rentals (CustomerID, VehicleID, RentalDate, ScheduledReturnDate, ActualReturnDate, DailyRateApplied, TotalAmount, RentalStatus)
VALUES (3, 2, '2026-09-15', '2026-09-22', NULL, 5500.00, 38500.00, 'Active');

-- Active rental 4: Ayesha Malik currently has the Hilux (not yet returned)
INSERT INTO Rentals (CustomerID, VehicleID, RentalDate, ScheduledReturnDate, ActualReturnDate, DailyRateApplied, TotalAmount, RentalStatus)
VALUES (4, 4, '2026-09-18', '2026-09-25', NULL, 8000.00, 56000.00, 'Active');

-- Completed rental 5: Usman Tariq rented the City, already returned
INSERT INTO Rentals (CustomerID, VehicleID, RentalDate, ScheduledReturnDate, ActualReturnDate, DailyRateApplied, TotalAmount, RentalStatus)
VALUES (5, 5, '2026-09-05', '2026-09-07', '2026-09-07', 4800.00, 9600.00, 'Completed');

-- Manually align vehicle status with the sample data above
-- (in normal operation the triggers in Section 5 do this automatically)
UPDATE Vehicles SET Status = 'Rented' WHERE VehicleID IN (2, 4);

-- ---------------- Payments (5) ----------------
INSERT INTO Payments (RentalID, PaymentDate, AmountPaid, PaymentMethod, PaymentStatus) VALUES
(1, '2026-09-04', 15000.00, 'Cash',           'Completed'),
(2, '2026-08-22',  6000.00, 'Card',           'Completed'),
(3, '2026-09-15', 20000.00, 'Mobile Wallet',  'Pending'),    -- advance payment, rental still active
(4, '2026-09-18', 56000.00, 'Bank Transfer',  'Completed'),
(5, '2026-09-07',  9600.00, 'Cash',           'Completed');


-- =====================================================================
-- 3. TASK 3 — JOIN QUERIES
-- =====================================================================

-- ---------------------------------------------------------------------
-- Query 1 (INNER JOIN)
-- Customer name, vehicle number, vehicle model, rental date, return date
-- for every rental that exists.
-- ---------------------------------------------------------------------
SELECT
    c.FullName            AS CustomerName,
    v.VehicleNumber        AS VehicleNumber,
    v.Model                AS VehicleModel,
    r.RentalDate,
    r.ActualReturnDate     AS ReturnDate
FROM Rentals r
INNER JOIN Customers c ON r.CustomerID = c.CustomerID
INNER JOIN Vehicles  v ON r.VehicleID  = v.VehicleID
ORDER BY r.RentalDate;

-- ---------------------------------------------------------------------
-- Query 2 (LEFT JOIN)
-- All customers and the vehicles they have rented; customers who have
-- never rented a vehicle must still appear (with NULL vehicle info).
-- ---------------------------------------------------------------------
SELECT
    c.CustomerID,
    c.FullName,
    v.VehicleNumber,
    v.Model                AS VehicleModel,
    r.RentalDate
FROM Customers c
LEFT JOIN Rentals  r ON c.CustomerID = r.CustomerID
LEFT JOIN Vehicles v ON r.VehicleID  = v.VehicleID
ORDER BY c.FullName;

-- ---------------------------------------------------------------------
-- Query 3 (LEFT JOIN, driven from Vehicles)
-- All vehicles and their current (active) rental info; vehicles that
-- are not currently rented must still appear (with NULL rental info).
-- ---------------------------------------------------------------------
SELECT
    v.VehicleID,
    v.VehicleNumber,
    v.Model                AS VehicleModel,
    v.Status                AS VehicleStatus,
    c.FullName              AS CurrentRenter,
    r.RentalDate,
    r.ScheduledReturnDate
FROM Vehicles v
LEFT JOIN Rentals   r ON v.VehicleID = r.VehicleID AND r.RentalStatus = 'Active'
LEFT JOIN Customers c ON r.CustomerID = c.CustomerID
ORDER BY v.VehicleNumber;

-- ---------------------------------------------------------------------
-- Query 4 (LEFT JOIN + GROUP BY + COUNT)
-- Total number of rentals made by each customer, including customers
-- who have made zero rentals.
-- ---------------------------------------------------------------------
SELECT
    c.CustomerID,
    c.FullName,
    COUNT(r.RentalID)      AS TotalRentals
FROM Customers c
LEFT JOIN Rentals r ON c.CustomerID = r.CustomerID
GROUP BY c.CustomerID, c.FullName
ORDER BY TotalRentals DESC;


-- =====================================================================
-- 4. TASK 4 — VIEW
-- =====================================================================
-- Business utility: management can query a single object to see, for
-- every rental, who rented what, for how long, how much was charged,
-- and how much has actually been paid — without writing a 4-table JOIN
-- every time. This supports quick reporting on outstanding balances,
-- customer history, and vehicle usage, and can safely be exposed to a
-- reporting/BI tool without granting direct access to base tables.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_consolidated_rental_report AS
SELECT
    r.RentalID,
    c.CustomerID,
    c.FullName              AS CustomerName,
    c.Phone                 AS CustomerPhone,
    v.VehicleID,
    v.VehicleNumber,
    v.Model                 AS VehicleModel,
    v.DailyRate,
    r.RentalDate,
    r.ScheduledReturnDate,
    r.ActualReturnDate,
    r.RentalStatus,
    r.TotalAmount,
    COALESCE(SUM(p.AmountPaid), 0)               AS TotalPaid,
    r.TotalAmount - COALESCE(SUM(p.AmountPaid), 0) AS BalanceDue
FROM Rentals r
JOIN Customers c ON r.CustomerID = c.CustomerID
JOIN Vehicles  v ON r.VehicleID  = v.VehicleID
LEFT JOIN Payments p ON r.RentalID = p.RentalID
GROUP BY r.RentalID, c.CustomerID, c.FullName, c.Phone, v.VehicleID,
         v.VehicleNumber, v.Model, v.DailyRate, r.RentalDate,
         r.ScheduledReturnDate, r.ActualReturnDate, r.RentalStatus, r.TotalAmount;

-- Test the view
SELECT * FROM vw_consolidated_rental_report ORDER BY RentalID;


-- =====================================================================
-- 5. TASK 5 — TRIGGERS
-- =====================================================================

DELIMITER $$

-- ---------------------------------------------------------------------
-- Trigger 1: trg_check_vehicle_availability
-- Fires BEFORE a new rental row is inserted. Blocks the insert if the
-- chosen vehicle is already marked 'Rented' (i.e. currently out on an
-- active rental). This is the primary enforcement of the core rule:
-- "a vehicle must not be available for another rental while it is
-- currently rented."
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_check_vehicle_availability
BEFORE INSERT ON Rentals
FOR EACH ROW
BEGIN
    DECLARE v_status VARCHAR(20);

    SELECT Status INTO v_status
    FROM Vehicles
    WHERE VehicleID = NEW.VehicleID;

    IF v_status = 'Rented' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Booking rejected: this vehicle is already rented.';
    ELSEIF v_status = 'Maintenance' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Booking rejected: this vehicle is under maintenance.';
    END IF;
END$$

-- ---------------------------------------------------------------------
-- Trigger 2: trg_update_vehicle_status (on INSERT)
-- Fires AFTER a new rental is successfully inserted and flips the
-- vehicle's status to 'Rented' automatically, so Vehicles.Status is
-- always kept in sync without relying on the application layer.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_update_vehicle_status
AFTER INSERT ON Rentals
FOR EACH ROW
BEGIN
    UPDATE Vehicles
    SET Status = 'Rented'
    WHERE VehicleID = NEW.VehicleID;
END$$

-- ---------------------------------------------------------------------
-- Trigger 3: trg_update_vehicle_status_on_return (on UPDATE)
-- Fires AFTER a rental row is updated. When a return is recorded
-- (ActualReturnDate goes from NULL to a real date), the vehicle is
-- automatically released back to 'Available'.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_update_vehicle_status_on_return
AFTER UPDATE ON Rentals
FOR EACH ROW
BEGIN
    IF OLD.ActualReturnDate IS NULL AND NEW.ActualReturnDate IS NOT NULL THEN
        UPDATE Vehicles
        SET Status = 'Available'
        WHERE VehicleID = NEW.VehicleID;

        UPDATE Rentals
        SET RentalStatus = 'Completed'
        WHERE RentalID = NEW.RentalID;
    END IF;
END$$

DELIMITER ;

-- ---------------- Test the triggers ----------------
-- This should FAIL because VehicleID 2 (Civic) is currently 'Rented':
-- INSERT INTO Rentals (CustomerID, VehicleID, RentalDate, ScheduledReturnDate, DailyRateApplied, TotalAmount)
-- VALUES (1, 2, CURRENT_DATE, CURRENT_DATE + INTERVAL 2 DAY, 5500.00, 11000.00);

-- This should SUCCEED because VehicleID 3 (Alto) is 'Available',
-- and Vehicles.Status should flip to 'Rented' automatically afterward:
-- INSERT INTO Rentals (CustomerID, VehicleID, RentalDate, ScheduledReturnDate, DailyRateApplied, TotalAmount)
-- VALUES (2, 3, CURRENT_DATE, CURRENT_DATE + INTERVAL 3 DAY, 3000.00, 9000.00);
-- SELECT VehicleID, VehicleNumber, Status FROM Vehicles WHERE VehicleID = 3;

-- Recording a return should flip status back to 'Available':
-- UPDATE Rentals SET ActualReturnDate = CURRENT_DATE WHERE RentalID = 3;
-- SELECT VehicleID, VehicleNumber, Status FROM Vehicles WHERE VehicleID = 2;


-- =====================================================================
-- 6. TASK 6 — STORED PROCEDURE
-- =====================================================================
-- sp_register_rental: registers a new rental end-to-end.
--   1. Verifies the vehicle exists and is Available (defensive check;
--      the trigger above is the hard safety net).
--   2. Calculates TotalAmount = DailyRate * number of days.
--   3. Inserts the Rentals row (the triggers then mark the vehicle
--      'Rented' automatically).
--   4. Inserts a matching Payments row.
-- =====================================================================

DELIMITER $$

CREATE PROCEDURE sp_register_rental (
    IN  p_CustomerID           INT,
    IN  p_VehicleID            INT,
    IN  p_RentalDate           DATE,
    IN  p_ScheduledReturnDate  DATE,
    IN  p_PaymentMethod        VARCHAR(20),
    OUT p_RentalID             INT,
    OUT p_TotalAmount          DECIMAL(10,2)
)
sp_body: BEGIN
    DECLARE v_status    VARCHAR(20);
    DECLARE v_dailyRate DECIMAL(10,2);
    DECLARE v_days      INT;

    -- Validate vehicle
    SELECT Status, DailyRate INTO v_status, v_dailyRate
    FROM Vehicles
    WHERE VehicleID = p_VehicleID;

    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Vehicle does not exist.';
    END IF;

    IF v_status <> 'Available' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Vehicle is not available for rental.';
    END IF;

    IF p_ScheduledReturnDate < p_RentalDate THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Return date cannot be before rental date.';
    END IF;

    -- Calculate charge (minimum 1 day)
    SET v_days = GREATEST(DATEDIFF(p_ScheduledReturnDate, p_RentalDate), 1);
    SET p_TotalAmount = v_days * v_dailyRate;

    -- Insert rental (trigger will mark the vehicle 'Rented')
    INSERT INTO Rentals (CustomerID, VehicleID, RentalDate, ScheduledReturnDate,
                          DailyRateApplied, TotalAmount, RentalStatus)
    VALUES (p_CustomerID, p_VehicleID, p_RentalDate, p_ScheduledReturnDate,
            v_dailyRate, p_TotalAmount, 'Active');

    SET p_RentalID = LAST_INSERT_ID();

    -- Record the payment (advance/full payment made at booking time)
    INSERT INTO Payments (RentalID, PaymentDate, AmountPaid, PaymentMethod, PaymentStatus)
    VALUES (p_RentalID, CURRENT_DATE, p_TotalAmount, p_PaymentMethod, 'Completed');

END$$

DELIMITER ;

-- ---------------- Test the stored procedure ----------------
-- Register a rental for Customer 1 (Ali Khan) on Vehicle 3 (Alto):
CALL sp_register_rental(1, 3, '2026-09-20', '2026-09-23', 'Card', @newRentalID, @newTotal);
SELECT @newRentalID AS NewRentalID, @newTotal AS TotalCharged;

-- Confirm the vehicle was auto-marked as Rented and the report reflects it:
SELECT VehicleID, VehicleNumber, Status FROM Vehicles WHERE VehicleID = 3;
SELECT * FROM vw_consolidated_rental_report WHERE RentalID = @newRentalID;


-- =====================================================================
-- 7. TASK 7 — OPTIMIZATION ANALYSIS
-- =====================================================================
-- IDENTIFIED INEFFICIENCY:
--   Rentals.CustomerID and Rentals.VehicleID are foreign keys but were
--   not explicitly indexed beyond what InnoDB may add automatically.
--   More importantly, availability checks and reports repeatedly filter
--   on (VehicleID, RentalStatus) and on date ranges (RentalDate /
--   ActualReturnDate) — e.g. "is this vehicle currently rented?" or
--   "which rentals are active between these dates?". Without a
--   composite index covering these columns, MySQL falls back to a full
--   table scan of Rentals for every such lookup, which will degrade
--   noticeably as rental history grows (thousands/millions of rows),
--   and slows down the very trigger (trg_check_vehicle_availability)
--   that enforces the no-double-booking business rule, and the
--   reporting queries in Task 3/4.
--
-- PERFORMANCE / CONSISTENCY IMPACT:
--   - Slower INSERTs on Rentals, because the availability trigger
--     effectively performs a lookup for every row inserted.
--   - Slower JOIN/GROUP BY queries (Task 3 Query 3, Task 4 view) as
--     the Rentals table grows.
--   - Under concurrent bookings, a slow availability check widens the
--     race-condition window for double-booking the same vehicle.
--
-- PROPOSED IMPROVEMENT:
--   Add a composite index on (VehicleID, RentalStatus) to make
--   "is vehicle X currently active?" an index lookup instead of a scan,
--   plus a supporting index on RentalDate for date-range reporting, and
--   an index on CustomerID for the customer-history queries.
-- =====================================================================

-- Demonstrate the scan before optimization (uncomment to run in phpMyAdmin):
-- EXPLAIN SELECT * FROM Rentals WHERE VehicleID = 2 AND RentalStatus = 'Active';

CREATE INDEX idx_rentals_vehicle_status ON Rentals (VehicleID, RentalStatus);
CREATE INDEX idx_rentals_customer       ON Rentals (CustomerID);
CREATE INDEX idx_rentals_rentaldate     ON Rentals (RentalDate);
CREATE INDEX idx_payments_rentalid      ON Payments (RentalID);

-- Demonstrate the (much cheaper) lookup after optimization:
EXPLAIN SELECT * FROM Rentals WHERE VehicleID = 2 AND RentalStatus = 'Active';

-- =====================================================================
-- END OF SCRIPT
-- =====================================================================
