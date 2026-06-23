-- TRIGGER 1
DELIMITER $$

CREATE TRIGGER Reject_Double_Update
BEFORE UPDATE ON appointment
FOR EACH ROW
BEGIN

    DECLARE newDate DATE;
    DECLARE newTime TIME;
    DECLARE newStaff INT;

    SELECT Date, Time, STAFF_ID
    INTO newDate, newTime, newStaff
    FROM clinicalactivity
    WHERE CAID = NEW.CAID;


    IF EXISTS (
        SELECT 1
        FROM clinicalactivity C
        JOIN appointment A ON C.CAID = A.CAID
        WHERE C.Date = newDate
          AND C.Time = newTime
          AND C.STAFF_ID = newStaff
          AND A.CAID <> NEW.CAID
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'This appointment conflicts with an existing one.';
    END IF;
END$$

DELIMITER ;
DELIMITER $$

CREATE TRIGGER Reject_Double_Insert
BEFORE INSERT ON appointment
FOR EACH ROW
BEGIN
    DECLARE newDate DATE;
    DECLARE newTime TIME;
    DECLARE newStaff INT;

    SELECT Date, Time, STAFF_ID
    INTO newDate, newTime, newStaff
    FROM clinicalactivity
    WHERE CAID = NEW.CAID;


    IF EXISTS (
        SELECT 1
        FROM clinicalactivity C
        JOIN appointment A ON C.CAID = A.CAID
        WHERE C.Date = newDate
          AND C.Time = newTime
          AND C.STAFF_ID = newStaff
          AND A.CAID <> NEW.CAID
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'This appointment conflicts with an existing one.';
    END IF;
END$$
DELIMITER ;



/*------------------------------------------------------------*/
-- TRIGGER 2



DELIMITER //
CREATE TRIGGER RecomputeExpenseAfterInsert
AFTER INSERT ON Includes
FOR EACH ROW
BEGIN
	DECLARE new_total DECIMAL(10,2);
    DECLARE missing_price INT;

    SELECT COUNT(*) INTO missing_price
        FROM Includes I
        JOIN Prescription PR ON I.PID = PR.PID
        JOIN ClinicalActivity CA ON PR.CAID = CA.CAID
        JOIN Department D ON CA.DEP_ID = D.DEP_ID
        LEFT JOIN Stock S ON S.MID = I.MID AND S.HID = D.HID
        WHERE I.PID = NEW.PID AND (S.UnitPrice IS NULL OR S.UnitPrice <= 0);

    IF missing_price > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Cannot compute expense, medication price is missing or invalid   in stock.';
    END IF;

    SELECT SUM(S.UnitPrice) INTO new_total
        FROM Includes I
        JOIN Prescription PR ON I.PID = PR.PID
        JOIN ClinicalActivity CA ON PR.CAID = CA.CAID
        JOIN Department D ON CA.DEP_ID = D.DEP_ID
        JOIN Stock S ON S.MID = I.MID AND S.HID = D.HID
        WHERE I.PID = NEW.PID;

    UPDATE Expense E
        JOIN Prescription PR ON E.CAID = PR.CAID
        SET E.Total = IFNULL(new_total, 0)
        WHERE PR.PID = NEW.PID;
END//

DELIMITER ;

DELIMITER //

CREATE TRIGGER RecomputeExpenseAfterUpdate
AFTER UPDATE ON Includes
FOR EACH ROW
BEGIN

	DECLARE new_total DECIMAL(10,2);
    DECLARE missing_price INT;

    SELECT COUNT(*) INTO missing_price
        FROM Includes I
        JOIN Prescription PR ON I.PID = PR.PID
        JOIN ClinicalActivity CA ON PR.CAID = CA.CAID
        JOIN Department D ON CA.DEP_ID = D.DEP_ID
        LEFT JOIN Stock S ON S.MID = I.MID AND S.HID = D.HID
        WHERE I.PID = NEW.PID AND (S.UnitPrice IS NULL OR S.UnitPrice <= 0);

    IF missing_price > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Cannot compute expense, medication price is missing or invalid   in stock.';
    END IF;

    SELECT SUM(S.UnitPrice ) INTO new_total
        FROM Includes I
        JOIN Prescription PR ON I.PID = PR.PID
        JOIN ClinicalActivity CA ON PR.CAID = CA.CAID
        JOIN Department D ON CA.DEP_ID = D.DEP_ID
        JOIN Stock S ON S.MID = I.MID AND S.HID = D.HID
        WHERE I.PID = NEW.PID;

    UPDATE Expense E
        JOIN Prescription PR ON E.CAID = PR.CAID
        SET E.Total = IFNULL(new_total, 0)
        WHERE PR.PID = NEW.PID;

END//
DELIMITER ;

DELIMITER //

CREATE TRIGGER RecomputeExpenseAfterDelete
AFTER DELETE ON Includes
FOR EACH ROW
BEGIN

	DECLARE new_total DECIMAL(10,2);

	SELECT SUM(S.UnitPrice) INTO new_total
        FROM Includes I
        JOIN Prescription PR ON I.PID = PR.PID
        JOIN ClinicalActivity CA ON PR.CAID = CA.CAID
        JOIN Department D ON CA.DEP_ID = D.DEP_ID
        JOIN Stock S ON S.MID = I.MID AND S.HID = D.HID
        WHERE I.PID = OLD.PID;

	UPDATE Expense E
        JOIN Prescription PR ON E.CAID = PR.CAID
        SET E.Total = IFNULL(new_total, 0)
        WHERE PR.PID = OLD.PID;
END//

DELIMITER ;



/*------------------------------------------------------------*/
-- TRIGGER 3



DELIMITER $$
CREATE TRIGGER PreventNegativeInconsistentStock_INSERT
BEFORE INSERT ON Stock
FOR EACH ROW
BEGIN
    IF NEW.Qty<0 then
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERORR: Quantity cannot be Qty<0 or any change decreasing Qty cannot drop below zero';
    END IF;
    IF NEW.UnitPrice<=0 then
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERORR: UnitPrice cannot be <-0';
    END IF;
    IF NEW.ReorderLevel < 0 then
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERORR: ReorderLevel cannot be <0';
    END IF;
END$$

DELIMITER ;


DELIMITER $$
CREATE TRIGGER PreventNegativeInconsistentStock_UPDATE
BEFORE UPDATE ON Stock
FOR EACH ROW
BEGIN
    IF NEW.Qty<0 then
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERORR: Quantity cannot be Qty<0 or any change decreasing Qty cannot drop below zero';
    END IF;
    IF NEW.UnitPrice<=0 then
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERORR: UnitPrice cannot be <-0';
    END IF;
    IF NEW.ReorderLevel < 0 then
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERORR: ReorderLevel cannot be <0';
    END IF;
END$$
DELIMITER ;




/*------------------------------------------------------------*/
-- TRIGGER 4





DELIMITER //
CREATE TRIGGER PreventPatientDelete
BEFORE DELETE ON Patient
FOR EACH ROW
BEGIN
    DECLARE activity_count INT;
    SELECT COUNT(*) INTO activity_count
        FROM ClinicalActivity
     WHERE IID = OLD.IID;
    IF activity_count > 0 THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Error: Cannot delete patient with existing clinical activities. Please reassign or delete dependent activities first.';
    END IF;
END//

DELIMITER ;