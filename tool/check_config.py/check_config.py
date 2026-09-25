"""Validate the same public configuration supplied to Flutter, without logging keys."""
import json
import os
import pathlib
import re
import sys
import urllib.error
import urllib.request

URL = 'https://iiaxbriosudkmhsqvksn.supabase.co'

def main():
    url = os.environ.get('SUPABASE_URL', '').strip()
    key = os.environ.get('SUPABASE_PUBLISHABLE_KEY', '').strip()
    if url != URL:
        sys.exit('SUPABASE_URL must identify the TURNEO project.')
    if not re.fullmatch(r'sb_publishable_[A-Za-z0-9_-]+', key):
        sys.exit('SUPABASE_PUBLISHABLE_KEY is missing or has an invalid format.')
    for path in ['/auth/v1/settings', '/rest/v1/services?select=code&limit=1',
                 '/rest/v1/app_users?select=local_user_id&limit=1',
                 '/rest/v1/planning?select=work_date&limit=1',
                 '/rest/v1/holidays?select=holiday_date&limit=1']:
        request = urllib.request.Request(url + path, headers={'apikey': key})
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                json.load(response)
        except (urllib.error.URLError, ValueError):
            sys.exit('Supabase configuration preflight failed. No build was published.')
    target = pathlib.Path('build-config.json')
    target.write_text(json.dumps({'SUPABASE_URL': url, 'SUPABASE_PUBLISHABLE_KEY': key}))
    target.chmod(0o600)
    print('Supabase Auth and four REST endpoints accepted the public configuration. RLS remains enabled.')

if __name__ == '__main__':
    main()
