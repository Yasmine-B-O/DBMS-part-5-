import db_utils
import argparse

def main():
    parser = argparse.ArgumentParser(description="MNHS CLI")
    sub = parser.add_subparsers(dest="cmd", required=True)

    lst_pt = sub.add_parser("list_patients")
    
    appt = sub.add_parser("schedule_appt")
    appt.add_argument("--caid", type=int, required=True)
    appt.add_argument("--iid", type=int, required=True)
    appt.add_argument("--staff", type=int, required=True)
    appt.add_argument("--dep", type=int, required=True)
    appt.add_argument("--date", required=True)
    appt.add_argument("--time", required=True)
    appt.add_argument("--reason", required=True)

    sub.add_parser("staff_share",help="show staff total number of appointments and percentage share within his hospital ")

    sub.add_parser("low_stock", help="List medications below reorder level")

    args = parser.parse_args()
    if args.cmd == "schedule_appt":
        db_utils.schedule_appointment(args.caid, args.iid, args.staff, args.dep,
        args.date, args.time, args.reason)

        print("Appointment scheduled")
    elif args.cmd == "list_patients":
        for r in db_utils.list_patients_ordered_by_last_name():
            print(f"{ r['IID']} { r['FullName']} ")
    elif args.cmd == "low_stock":
        results = db_utils.low_stock() 
        for med in results:
            print(f"{med['MedicationName']:<20} | {med['HospitalName']:<30} | Stock: {str(med['Qty']) if med['Qty'] is not None else "None"} (reorder: {med['ReorderLevel']})")
    elif args.cmd=="staff_share":
        print(f"{'Staff ID':<10} {'Staff Name':<20} {'TotalAppointments':<12} {'PercentageShare %':<10}")
        for r in db_utils.staff_share():
            print(f"{r['STAFF_ID']:<10} {r['FullName']:<30} "
                  f"{r['TotalAppointments']:<12} {r['PercentageShare']:<10}")
            

main()

