# -*- coding: utf-8 -*-
with open('supabase/sql_editor_custom_facebrasil/04_auth_and_storage.sql', 'r', encoding='utf-8') as f:
    lines = f.readlines()

users_lines = []
in_users = False
for l in lines:
    if 'INSERT INTO auth.users' in l:
        in_users = True
        continue
    if in_users:
        if 'ON CONFLICT' in l:
            break
        cleaned = l.strip().rstrip(',')
        if cleaned:
            users_lines.append(cleaned)

identities_lines = []
in_identities = False
for l in lines:
    if 'INSERT INTO auth.identities' in l:
        in_identities = True
        continue
    if in_identities:
        if 'ON CONFLICT' in l:
            break
        cleaned = l.strip().rstrip(',')
        if cleaned:
            identities_lines.append(cleaned)

cols_users = '("instance_id", "id", "aud", "role", "email", "encrypted_password", "email_confirmed_at", "invited_at", "confirmation_token", "confirmation_sent_at", "recovery_token", "recovery_sent_at", "email_change_token_new", "email_change", "email_change_sent_at", "last_sign_in_at", "raw_app_meta_data", "raw_user_meta_data", "is_super_admin", "created_at", "updated_at", "phone", "phone_confirmed_at", "phone_change", "phone_change_token", "phone_change_sent_at", "email_change_token_current", "email_change_confirm_status", "banned_until", "reauthentication_token", "reauthentication_sent_at", "is_sso_user", "deleted_at", "is_anonymous")'
cols_identities = '("provider_id", "user_id", "identity_data", "provider", "last_sign_in_at", "created_at", "updated_at", "id")'

out = ["DO $$", "BEGIN"]

for u in users_lines:
    out.append("  BEGIN")
    out.append(f"    INSERT INTO auth.users {cols_users} VALUES {u} ON CONFLICT DO NOTHING;")
    out.append("  EXCEPTION WHEN OTHERS THEN NULL;")
    out.append("  END;")

for ident in identities_lines:
    out.append("  BEGIN")
    out.append(f"    INSERT INTO auth.identities {cols_identities} VALUES {ident} ON CONFLICT DO NOTHING;")
    out.append("  EXCEPTION WHEN OTHERS THEN NULL;")
    out.append("  END;")

out.append("END $$;")
out.append("")
out.append("SELECT count(*) AS total_usuarios FROM auth.users;")

with open('supabase/vps_import_users.sql', 'w', encoding='utf-8') as f:
    f.write('\n'.join(out))

print('supabase/vps_import_users.sql gerado!')
