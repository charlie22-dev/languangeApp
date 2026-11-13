"""Generate the ignored dotenv asset used by plain Flutter launches."""
import base64
import json
from pathlib import Path
from urllib.parse import urlparse


def public_key(value):
    if value.startswith('sb_publishable_'):
        return len(value) > len('sb_publishable_')
    try:
        parts = value.split('.')
        if len(parts) != 3:
            return False
        payload = json.loads(base64.urlsafe_b64decode(parts[1] + '=' * (-len(parts[1]) % 4)))
        return isinstance(payload, dict) and payload.get('role') == 'anon'
    except (ValueError, TypeError, UnicodeError):
        return False


def prepare(root):
    source = root / 'config.local.json'
    if not source.exists():
        raise ValueError('Create config.local.json from config.example.json and fill in your public client settings.')
    config = json.loads(source.read_text(encoding='utf-8-sig'))
    url = config.get('SUPABASE_URL', '').strip()
    key = (config.get('SUPABASE_PUBLISHABLE_KEY') or config.get('SUPABASE_ANON_KEY') or '').strip()
    uri = urlparse(url)
    if uri.scheme not in ('http', 'https') or not uri.hostname:
        raise ValueError('SUPABASE_URL must be a valid project URL.')
    if not public_key(key):
        raise ValueError('Use a publishable or anon client key; secret/service-role keys are rejected.')
    values = {'SUPABASE_URL': url, 'SUPABASE_PUBLISHABLE_KEY': key}
    for name in ('AUTH_REDIRECT_URL', 'APP_NAME', 'TARGET_LANGUAGE', 'NATIVE_LANGUAGE'):
        if name in config:
            values[name] = config[name]
    lines = ['# Generated local public client settings. Never commit this file.']
    for name, value in values.items():
        if not isinstance(value, str) or '\n' in value or '\r' in value or value.endswith('\\'):
            raise ValueError(f'{name} must be a single-line string without a trailing backslash.')
        escaped = value.replace("'", "\\'")
        lines.append(f"{name}='{escaped}'")
    destination = root / 'assets/local/client.env'
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    return destination


if __name__ == '__main__':
    try:
        prepare(Path(__file__).resolve().parents[1])
        print('Prepared ignored local client configuration. Values were not printed.')
    except (ValueError, OSError) as error:
        raise SystemExit(str(error)) from error
