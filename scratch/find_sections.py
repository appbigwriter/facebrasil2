import gzip
import re

with gzip.open(r"f:\Projetos\_FBR\2FBR-NovaFacebrasil\supabase\db_cluster-19-10-2026@01-13-52.backup.gz", "rt", encoding="utf-8", errors="ignore") as f:
    line_no = 0
    in_db = None
    for line in f:
        line_no += 1
        if line.startswith(r"\connect"):
            print(f"Line {line_no}: {line.strip()}")
            in_db = line.strip()
        if "CREATE TABLE public." in line:
            print(f"Line {line_no} [{in_db}]: {line.strip()}")
