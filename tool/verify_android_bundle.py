"""Check an AAB's signing, package ID and 64-bit ELF load alignment."""
from pathlib import Path
import os
import shutil
import struct
import subprocess
import sys
import zipfile

root = Path(__file__).resolve().parents[1]
bundle = Path(sys.argv[1]) if len(sys.argv) > 1 else root / 'build/app/outputs/bundle/release/app-release.aab'
if not bundle.is_file():
    raise SystemExit('Build the release AAB first, or pass its path as the first argument.')
java_home = os.environ.get('JAVA_HOME')
signer = Path(java_home) / 'bin/jarsigner.exe' if java_home else None
if signer is None or not signer.exists():
    located = shutil.which('jarsigner')
    signer = Path(located) if located else Path('C:/Program Files/Android/Android Studio/jbr/bin/jarsigner.exe')
result = subprocess.run([str(signer), '-verify', str(bundle)], capture_output=True, text=True, check=True)
if 'jar verified' not in result.stdout.lower():
    raise SystemExit('The bundle did not pass JAR signature verification.')
checked = 0
with zipfile.ZipFile(bundle) as archive:
    if any(Path(name).name == 'key.properties' or name.endswith(('.jks', '.keystore'))
           for name in archive.namelist()):
        raise SystemExit('Private signing material must not be packaged in the bundle.')
    manifest = archive.read('base/manifest/AndroidManifest.xml')
    if b'com.charlie22dev.lingoblob' not in manifest:
        raise SystemExit('Expected application ID missing from the bundle manifest.')
    for name in archive.namelist():
        if not name.endswith('.so') or not any('/'+abi+'/' in name for abi in ['arm64-v8a','x86_64']):
            continue
        binary = archive.read(name)
        if binary[:4] != b'\x7fELF' or binary[4] != 2:
            raise SystemExit(f'Expected a 64-bit ELF library: {name}')
        endian = '<' if binary[5] == 1 else '>'
        offset = struct.unpack_from(endian+'Q',binary,32)[0]
        size,count = struct.unpack_from(endian+'HH',binary,54)
        for index in range(count):
            start = offset + index*size
            if struct.unpack_from(endian+'I',binary,start)[0] != 1:
                continue
            file_offset,address = struct.unpack_from(endian+'QQ',binary,start+8)
            alignment = struct.unpack_from(endian+'Q',binary,start+48)[0]
            if alignment < 16384 or file_offset % 16384 != address % 16384:
                raise SystemExit(f'16 KiB ELF load alignment failed: {name}')
        checked += 1
if not checked:
    raise SystemExit('No 64-bit native libraries were found.')
print(f'PASS: signed AAB, expected package ID, and 16 KiB ELF load alignment for {checked} native libraries.')
print('APK ZIP alignment and physical-device behavior still need Play/bundletool validation.')
