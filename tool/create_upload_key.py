"""Create local Android upload signing files once, without printing passwords."""
from pathlib import Path
import os
import secrets
import shutil
import subprocess

root = Path(__file__).resolve().parents[1]
keystore = root / 'android/app/lingoblob-upload.jks'
properties = root / 'android/key.properties'
if keystore.exists() or properties.exists():
    raise SystemExit('Signing files already exist. Preserve them; this tool never overwrites keys.')

java_home = os.environ.get('JAVA_HOME')
keytool = (Path(java_home) / 'bin/keytool.exe' if java_home else None)
if keytool is None or not keytool.exists():
    located = shutil.which('keytool')
    keytool = Path(located) if located else Path('C:/Program Files/Android/Android Studio/jbr/bin/keytool.exe')
if not keytool.exists():
    raise SystemExit('Set JAVA_HOME to your JDK or put keytool on PATH before running this tool.')

store_password, key_password = secrets.token_urlsafe(32), secrets.token_urlsafe(32)
child_env = dict(os.environ, LINGOBLOB_STORE_PASSWORD=store_password, LINGOBLOB_KEY_PASSWORD=key_password)
subprocess.run([
    str(keytool), '-genkeypair', '-keystore', str(keystore), '-storetype', 'JKS',
    '-alias', 'upload', '-keyalg', 'RSA', '-keysize', '2048', '-validity', '10000',
    '-dname', 'CN=LingoBlob', '-storepass:env', 'LINGOBLOB_STORE_PASSWORD',
    '-keypass:env', 'LINGOBLOB_KEY_PASSWORD', '-noprompt',
], env=child_env, check=True)
properties.write_text(
    f'storeFile=app/lingoblob-upload.jks\nstorePassword={store_password}\n'
    f'keyAlias=upload\nkeyPassword={key_password}\n', encoding='utf-8')
for path in (keystore, properties):
    path.chmod(0o600)
print('Created ignored Android upload signing files. Back up the keystore and key.properties securely.')
