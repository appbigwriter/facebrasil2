import gzip
import re

copy_tables = {}
current_table = None

with gzip.open(r"f:\Projetos\_FBR\2FBR-NovaFacebrasil\supabase\db_cluster-19-10-2026@01-13-52.backup.gz", "rt", encoding="utf-8", errors="ignore") as f:
    for line in f:
        m_copy = re.match(r"^COPY ([a-zA-Z0-9_.-]+) (?:.*) FROM stdin;", line)
        if m_copy:
            current_table = m_copy.group(1)
            copy_tables[current_table] = 0
            continue
        if current_table:
            if line.strip() == r"\.":
                current_table = None
            else:
                copy_tables[current_table] += 1

print("DADOS POR TABELA NO BACKUP:")
for t, count in sorted(copy_tables.items(), key=lambda x: -x[1]):
    print(f"  {t}: {count} linhas")
