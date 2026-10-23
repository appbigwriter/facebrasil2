import gzip
import re

schemas = set()
tables = []
search_paths = []

with gzip.open(r"f:\Projetos\_FBR\2FBR-NovaFacebrasil\supabase\db_cluster-19-10-2026@01-13-52.backup.gz", "rt", encoding="utf-8", errors="ignore") as f:
    for line in f:
        m_schema = re.match(r"^CREATE SCHEMA (?:IF NOT EXISTS )?\"?([a-zA-Z0-9_-]+)\"?;", line)
        if m_schema:
            schemas.add(m_schema.group(1))
        m_table = re.match(r"^CREATE TABLE (?:IF NOT EXISTS )?\"?([a-zA-Z0-9_.-]+)\"?\s*\(", line)
        if m_table:
            tables.append(m_table.group(1))

print("SCHEMAS:", sorted(list(schemas)))
print(f"Total tables found: {len(tables)}")
print("\nTABLES:")
for t in tables:
    print("  -", t)
