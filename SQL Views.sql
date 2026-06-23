-- VIEW 1
CREATE OR REPLACE VIEW UpcomingByHospital AS
SELECT
    H.Name AS HospitalName,
    CA.Date AS ApptDate,
    COUNT(*) AS ScheduledCount
FROM Appointment A
JOIN ClinicalActivity CA
    ON A.CAID = CA.CAID
JOIN Department D
    ON CA.DEP_ID = D.DEP_ID
JOIN Hospital H
    ON D.HID = H.HID
WHERE
    A.Status = 'Scheduled'
    AND CA.Date BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 14 DAY)
GROUP BY
    H.Name, CA.Date;

-- VIEW 2
CREATE OR REPLACE VIEW MedicationPricingSummary AS
SELECT
    s.HID,
    h.Name as HospitalName,
    s.MID,
    m.Name as MedicationName,
    AVG(s.UnitPrice) AS AvgUnitPrice,
    MIN(s.UnitPrice) AS MinUnitPrice,
    MAX(s.UnitPrice) AS MaxUnitPrice,
    MAX(s.StockTimestamp) AS LastStockTimestamp
FROM Stock s
JOIN Hospital h ON s.HID = h.HID
JOIN Medication m ON s.MID = m.MID
GROUP BY s.HID, h.Name, s.MID, m.Name;

-- VIEW 3
CREATE OR REPLACE VIEW StaffWorkloadThirty AS
SELECT
    S.STAFF_ID,
    S.FullName,
    COUNT(A.CAID) AS TotalAppointments,
    SUM(IF(A.Status = 'Scheduled', 1, 0)) AS ScheduledCount,
    SUM(IF(A.Status = 'Completed', 1, 0)) AS CompletedCount,
    SUM(IF(A.Status = 'Cancelled', 1, 0)) AS CancelledCount
FROM Staff S
LEFT JOIN ClinicalActivity CA ON S.STAFF_ID = CA.STAFF_ID
LEFT JOIN Appointment A ON CA.CAID = A.CAID
WHERE CA.Date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
    OR CA.Date IS NULL
GROUP BY S.STAFF_ID, S.FullName;

-- VIEW 4
CREATE OR REPLACE VIEW PatientNextVisit AS
SELECT P.IID,P.FullName,MIN(C.Date) AS NextAppDate,D.Name AS DepartmentName,H.Name AS HospitalName,H.City
FROM Patient P
JOIN ClinicalActivity C on P.IID=C.IID
JOIN Appointment A on A.CAID=C.CAID
JOIN Department D on D.DEP_ID=C.DEP_ID
JOIN Hospital H on H.HID=D.HID
WHERE A.status='Scheduled' AND C.Date>CURDATE()
GROUP BY P.IID,D.Name,H.Name,H.City;