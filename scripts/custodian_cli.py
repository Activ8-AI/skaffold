import argparse
from custody.incident_logger import log_incident

def main():
    parser = argparse.ArgumentParser(description="Custodian CLI")
    parser.add_argument("--incident", help="Description to log")
    args = parser.parse_args()
    if args.incident:
        iid = log_incident("CLI_TRIGGER", args.incident)
        print(f"Incident logged: {iid}")

if __name__ == "__main__":
    main()
