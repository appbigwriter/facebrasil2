import glob
import re

found = 0
for f in sorted(glob.glob(r"f:\Projetos\_FBR\2FBR-NovaFacebrasil\supabase\sql_editor_custom_facebrasil\*.sql")):
    with open(f, "r", encoding="utf-8") as sql:
        for idx, line in enumerate(sql, 1):
            if line.startswith("INSERT INTO"):
                m = re.search(r"\((.*?)\)\s+VALUES", line)
                if m:
                    cols = m.group(1)
                    if '""' in cols:
                        print(f"{os.path.basename(f)}:{idx}: {cols}")
                        found += 1

print(f"Verificação concluída. Total de erros de aspas duplas em colunas: {found}")
