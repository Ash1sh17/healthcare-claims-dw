import csv
import random
from datetime import date, timedelta
import os

random.seed(42)

PLANS = [
    ("PLN001", "Alignment Gold HMO",    "HMO", "CA"),
    ("PLN002", "Alignment Silver PPO",  "PPO", "CA"),
    ("PLN003", "Alignment Bronze HMO",  "HMO", "TX"),
    ("PLN004", "Alignment Premium PPO", "PPO", "FL"),
]

PROVIDERS = [
    ("PRV001", "Dr. Sarah Kim",       "Primary Care",  "Los Angeles", "CA"),
    ("PRV002", "Dr. James Okafor",    "Cardiology",    "Houston",     "TX"),
    ("PRV003", "Dr. Maria Lopez",     "Oncology",      "Miami",       "FL"),
    ("PRV004", "Dr. David Chen",      "Neurology",     "San Diego",   "CA"),
    ("PRV005", "Dr. Linda Patel",     "Primary Care",  "Dallas",      "TX"),
    ("PRV006", "Dr. Robert Walsh",    "Orthopedics",   "Orlando",     "FL"),
    ("PRV007", "Dr. Priya Nair",      "Endocrinology", "Sacramento",  "CA"),
    ("PRV008", "Dr. Michael Torres",  "Emergency Med", "Austin",      "TX"),
    ("PRV009", "Dr. Angela Brown",    "Psychiatry",    "Tampa",       "FL"),
    ("PRV010", "Dr. Kevin Nguyen",    "Pulmonology",   "Long Beach",  "CA"),
]

DIAGNOSES = [
    ("E11.9",  "Type 2 Diabetes without complications",  "Endocrine"),
    ("I10",    "Essential Hypertension",                 "Circulatory"),
    ("J44.1",  "COPD with acute exacerbation",           "Respiratory"),
    ("M17.11", "Primary osteoarthritis right knee",      "Musculoskeletal"),
    ("F32.1",  "Major depressive disorder moderate",     "Mental Health"),
    ("I25.10", "Atherosclerotic heart disease",          "Circulatory"),
    ("N18.3",  "Chronic kidney disease stage 3",         "Genitourinary"),
    ("C34.10", "Malignant neoplasm of bronchus",         "Neoplasms"),
    ("E78.5",  "Hyperlipidemia unspecified",             "Endocrine"),
    ("Z00.00", "General adult medical exam",             "Preventive"),
]

CLAIM_STATUS = ["Approved", "Approved", "Approved", "Denied", "Pending"]

def rand_date(start, end):
    return start + timedelta(days=random.randint(0, (end - start).days))

START = date(2023, 1, 1)
END   = date(2024, 12, 31)

members = []
for i in range(1, 501):
    plan = random.choice(PLANS)
    dob  = rand_date(date(1940, 1, 1), date(1975, 12, 31))
    members.append({
        "member_id":       f"MBR{str(i).zfill(5)}",
        "first_name":      random.choice(["James","Mary","John","Patricia","Robert","Jennifer",
                                           "Michael","Linda","David","Susan","Ashish","Priya",
                                           "Raj","Anita","Carlos","Rosa","Kevin","Angela"]),
        "last_name":       random.choice(["Smith","Johnson","Williams","Brown","Jones","Garcia",
                                           "Miller","Davis","Martinez","Patel","Kim","Nguyen",
                                           "Chen","Lopez","Wilson","Anderson","Thomas","Harris"]),
        "dob":             dob,
        "gender":          random.choice(["M","F","M","F","U"]),
        "state":           plan[3],
        "plan_id":         plan[0],
        "enrollment_date": rand_date(date(2022,1,1), date(2023,6,30)),
        "risk_score":      round(random.uniform(0.5, 3.5), 2),
    })

claims      = []
claim_lines = []
line_id     = 1

for i in range(1, 3001):
    member   = random.choice(members)
    provider = random.choice(PROVIDERS)
    diag     = random.choice(DIAGNOSES)
    svc_date = rand_date(START, END)
    billed   = round(random.uniform(150, 18000), 2)
    allowed  = round(billed * random.uniform(0.55, 0.85), 2)
    status   = random.choice(CLAIM_STATUS)
    paid     = round(allowed * random.uniform(0.75, 1.0), 2) if status != "Denied" else 0

    claim_id = f"CLM{str(i).zfill(7)}"
    claims.append({
        "claim_id":        claim_id,
        "member_id":       member["member_id"],
        "provider_id":     provider[0],
        "plan_id":         member["plan_id"],
        "diagnosis_code":  diag[0],
        "claim_type":      random.choice(["Medical","Pharmacy","Lab","Radiology","Emergency"]),
        "bill_type":       random.choice(["Inpatient","Outpatient","Professional"]),
        "service_date":    svc_date,
        "submission_date": svc_date + timedelta(days=random.randint(1, 30)),
        "billed_amount":   billed,
        "allowed_amount":  allowed,
        "paid_amount":     paid,
        "claim_status":    status,
        "denial_reason":   random.choice(["Not Covered","Prior Auth Required",
                                           "Duplicate","Out of Network",""]) if status == "Denied" else "",
    })

    for ln in range(1, random.randint(2, 4)):
        lb = round(billed / random.randint(1, 3), 2)
        claim_lines.append({
            "line_id":        line_id,
            "claim_id":       claim_id,
            "line_number":    ln,
            "procedure_code": random.choice(["99213","99214","93000","80053","71046",
                                              "45378","27447","90837","99285","94640"]),
            "billed_amount":  lb,
            "allowed_amount": round(lb * random.uniform(0.5, 0.9), 2),
            "units":          random.randint(1, 5),
        })
        line_id += 1

os.makedirs("data", exist_ok=True)

def write_csv(path, rows):
    with open(path, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=rows[0].keys())
        w.writeheader()
        w.writerows(rows)
    print(f"  Created: {path}  ({len(rows)} rows)")

write_csv("data/members.csv",      members)
write_csv("data/claims.csv",       claims)
write_csv("data/claim_lines.csv",  claim_lines)
write_csv("data/dim_plans.csv",    [{"plan_id":p[0],"plan_name":p[1],"plan_type":p[2],"state":p[3]} for p in PLANS])
write_csv("data/dim_providers.csv",[{"provider_id":p[0],"provider_name":p[1],"specialty":p[2],"city":p[3],"state":p[4]} for p in PROVIDERS])
write_csv("data/dim_diagnoses.csv",[{"diagnosis_code":d[0],"description":d[1],"category":d[2]} for d in DIAGNOSES])

print("\nDone. 6 CSV files ready in /data")