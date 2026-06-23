import os
from dotenv import load_dotenv
import mysql.connector
from mysql.connector import errorcode

load_dotenv("config.env")
cfg = dict(
    host=os.getenv("MYSQL_HOST"),
    port=int(os.getenv("MYSQL_PORT", 3306)),
    database=os.getenv("MYSQL_DB"),
    user=os.getenv("MYSQL_USER"),
    password=os.getenv("MYSQL_PASSWORD"),
)

def get_connection():
    return mysql.connector.connect(**cfg)

get_connection()

def schedule_appointment(caid, iid, staff_id, dep_id, date_str, time_str, reason):
    ins_ca = """
    INSERT INTO ClinicalActivity(CAID, IID, STAFF_ID, DEP_ID, Date, Time)
    VALUES (%s , %s , %s , %s , %s , %s )
    """
    ins_appt = """
    INSERT INTO Appointment(CAID, Reason, Status)
    VALUES (%s , %s , 'Scheduled')
    """
    with get_connection() as cnx:
        try:
            with cnx.cursor() as cur:
                cur.execute(ins_ca, (caid, iid, staff_id, dep_id, date_str, time_str))
                cur.execute(ins_appt, (caid, reason))
            cnx.commit()
        except Exception:
            cnx.rollback()
            raise


def list_patients_ordered_by_last_name(limit=20):
    sql = """
    SELECT IID, FullName
    FROM Patient
    ORDER BY SUBSTRING_INDEX(FullName, ' ', -1), FullName
    LIMIT %s
    """
    with get_connection() as cnx:
        with cnx.cursor(dictionary=True) as cur:
            cur.execute(sql, (limit,))
            return cur.fetchall()
        
def low_stock():
    sql = """
    SELECT
        H.Name AS HospitalName,
        M.Name AS MedicationName,
        S.Qty,
        S.ReorderLevel
    FROM Hospital H
    CROSS JOIN Medication M
    LEFT JOIN Stock S ON S.HID = H.HID AND S.MID = M.MID
    WHERE S.Qty < S.ReorderLevel OR S.Qty IS NULL
    ORDER BY H.Name, M.Name;
    """
    
    with get_connection() as cnx:  
        with cnx.cursor(dictionary=True) as cur:
            cur.execute(sql)
            results = cur.fetchall()
            return results

def staff_share():
    sql="""
SELECT S.STAFF_ID,
       S.FullName,
       COUNT(A.CAID) AS TotalAppointments,
       COUNT(A.CAID) * 100.0 /
           (SELECT COUNT(A2.CAID)
            FROM ClinicalActivity CA2
            JOIN Appointment A2 ON CA2.CAID = A2.CAID
            JOIN Department D2 ON CA2.DEP_ID = D2.DEP_ID
            WHERE D2.HID = D.HID) AS PercentageShare
        FROM Staff S
        JOIN ClinicalActivity CA ON S.STAFF_ID = CA.STAFF_ID
        JOIN Appointment A ON CA.CAID = A.CAID
        JOIN Department D ON D.DEP_ID = CA.DEP_ID
        GROUP BY S.STAFF_ID,S.FullName, D.HID
        ORDER BY TotalAppointments DESC;"""
    with get_connection() as cnx:  
        with cnx.cursor(dictionary=True) as cur:  
            cur.execute(sql)
            return cur.fetchall()
