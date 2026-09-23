# CarGo Rentals — Car Rental Management System

A relational database solution for the DBMS Open-Ended Lab Assignment. It models customers, vehicles, rentals, and payments for a car rental company, and enforces the core business rule that **a vehicle cannot be booked while it is already rented**.

## 1. Project Overview

CarGo Rentals previously tracked customers, vehicles, rentals, and payments in spreadsheets, leading to duplicate data and inconsistent records. This project replaces that with a normalized MySQL/MariaDB database that:

- Stores customer, vehicle, rental, and payment records with proper keys and constraints.
- Prevents double-booking a vehicle via a trigger.
- Automatically keeps vehicle availability status in sync via triggers.
- Calculates rental charges and registers rentals through a stored procedure.
- Provides a consolidated reporting view.
- Is indexed for the availability and reporting queries the business runs most often.

## 2. Database Schema Overview

| Table | Purpose | Key Relationships |
|---|---|---|
| **Customers** | One row per customer (name, phone, email, CNIC/license, address). | Referenced by `Rentals.CustomerID`. |
| **Vehicles** | One row per vehicle in the fleet (plate number, make/model, daily rate, status). | Referenced by `Rentals.VehicleID`. `Status` is `Available`, `Rented`, or `Maintenance`. |
| **Rentals** | One row per rental transaction (who rented what, from/to when). | FK → `Customers`, FK → `Vehicles`. `ActualReturnDate IS NULL` marks a rental as still active. |
| **Payments** | One or more payments against a rental. | FK → `Rentals` (one rental can have multiple payments, e.g. advance + settlement). |

**Relationships:** `Customers 1—N Rentals`, `Vehicles 1—N Rentals`, `Rentals 1—N Payments`.

The core "no double booking" rule is enforced at the database level (not just the application layer) by `trg_check_vehicle_availability`, so it holds even if someone inserts data directly via SQL.

## 3. Local Setup & Execution Guide (XAMPP / phpMyAdmin / MySQL CLI)

### Step 1 — Start Apache and MySQL in XAMPP
1. Open the **XAMPP Control Panel**.
2. Click **Start** next to **Apache**.
3. Click **Start** next to **MySQL**.
4. Confirm both rows turn green.

### Step 2 — Import `car_rental.sql`

**Option A — phpMyAdmin (recommended for screenshots):**
1. Go to `http://localhost/phpmyadmin`.
2. Click the **Import** tab (you do *not* need to create the database first — the script does `DROP DATABASE IF EXISTS` / `CREATE DATABASE`).
3. Click **Choose File**, select `car_rental.sql`.
4. Scroll down and click **Go**.
5. Once it finishes, click on **car_rental_db** in the left sidebar to confirm the 4 tables (`Customers`, `Vehicles`, `Rentals`, `Payments`) were created.

**Option B — MySQL Command Line:**
```bash
mysql -u root -p < car_rental.sql
```
Then connect and verify:
```bash
mysql -u root -p
USE car_rental_db;
SHOW TABLES;
```

### Step 3 — Run each part of the assignment

The script runs top-to-bottom in one go (tables → data → queries → view → triggers → procedure → indexes). To demonstrate each task individually for your report/screenshots, open `car_rental.sql` in the phpMyAdmin **SQL** tab and run each labeled section separately:

1. **Task 3 (JOIN Queries):** Highlight and run Query 1, then Query 2, then Query 3, then Query 4 one at a time. Screenshot the **Showing rows** result grid after each.
2. **Task 4 (View):** Run the `CREATE OR REPLACE VIEW ...` statement, then run `SELECT * FROM vw_consolidated_rental_report ORDER BY RentalID;`. Screenshot the result.
3. **Task 5 (Triggers):** The three `CREATE TRIGGER` statements are already applied by the import. To demonstrate them:
   - Uncomment and run the **"should FAIL"** test insert (booking Vehicle 2 while it's Rented) — screenshot the error message phpMyAdmin shows.
   - Uncomment and run the **"should SUCCEED"** test insert on an Available vehicle, then the `SELECT ... Status` — screenshot the vehicle flipping to `Rented`.
   - Run the return `UPDATE` test and the following `SELECT` — screenshot the vehicle flipping back to `Available`.
4. **Task 6 (Stored Procedure):** Run the `CALL sp_register_rental(...)` line, then `SELECT @newRentalID, @newTotal;` — screenshot the output values, then screenshot the `vw_consolidated_rental_report` row it created.
5. **Task 7 (Optimization):** Run `EXPLAIN SELECT * FROM Rentals WHERE VehicleID = 2 AND RentalStatus = 'Active';` **before** creating the indexes (comment the `CREATE INDEX` lines out temporarily) and screenshot the `type: ALL` (full scan) row. Then create the indexes and re-run the same `EXPLAIN` — screenshot the improved `type: ref` row using `idx_rentals_vehicle_status`.

### Step 4 — What to screenshot for submission

- phpMyAdmin **Structure** tab showing all 4 tables with their columns/keys.
- Result grids for JOIN Queries 1–4.
- The `vw_consolidated_rental_report` view output.
- The trigger's rejection error message + the before/after `Vehicles.Status` values.
- The stored procedure's `CALL` output and the resulting rental/payment rows.
- The `EXPLAIN` output before and after adding the indexes in Task 7.

## 4. File Manifest

| File | Description |
|---|---|
| `car_rental.sql` | Full schema, sample data, queries, view, triggers, procedure, and indexes. |
| `README.md` | This file. |
| `Lab_Report.docx` | Written report: design justification, normalization (1NF–3NF), and optimization analysis. |
