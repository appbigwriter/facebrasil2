import gzip

with gzip.open(r"f:\Projetos\_FBR\2FBR-NovaFacebrasil\supabase\db_cluster-19-10-2026@01-13-52.backup.gz", "rt", encoding="utf-8", errors="ignore") as gz:
    for line in gz:
        if line.startswith("COPY ") and '"' in line:
            print(line.strip())
