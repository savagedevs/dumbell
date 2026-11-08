#!/usr/bin/env python3
"""Validate actual signed binaries and package only public release artifacts."""
from pathlib import Path
import hashlib
import html
import json
import os
import re
import shutil
import struct
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
config = json.loads((ROOT / 'config/release.json').read_text())
version = re.search(r'^version:\s*([\d.]+)\+(\d+)\s*$', (ROOT / 'pubspec.yaml').read_text(), re.M)
if not version:
    raise SystemExit('Set a numeric version and build number in pubspec.yaml.')
version_name, version_code = version.groups()
slug = config['APP_SLUG']
if not re.fullmatch(r'[A-Za-z0-9_-]+', slug):
    raise SystemExit('APP_SLUG must contain only letters, numbers, underscores or hyphens.')
sdk = Path(os.environ.get('ANDROID_SDK_ROOT') or os.environ.get('ANDROID_HOME') or Path.home() / 'Library/Android/sdk')
tools = max((sdk / 'build-tools').iterdir(), key=lambda path: tuple(int(v) for v in path.name.split('.') if v.isdigit()))
apk = ROOT / 'build/app/outputs/flutter-apk/app-release.apk'
aab = ROOT / 'build/app/outputs/bundle/release/app-release.aab'
if not aab.is_file():
    aab = ROOT / 'build/app/outputs/bundle/release/app.aab'
for artifact in (apk, aab):
    if not artifact.is_file():
        raise SystemExit(f'Missing build output: {artifact}')

def command(arguments):
    runtime = os.environ.copy()
    java_home = Path('/Applications/Android Studio.app/Contents/jbr/Contents/Home')
    if java_home.is_dir():
        runtime['JAVA_HOME'] = str(java_home)
    result = subprocess.run([str(value) for value in arguments], text=True, capture_output=True, env=runtime)
    if result.returncode:
        raise SystemExit(result.stdout + result.stderr)
    return result.stdout + result.stderr

badging = command([tools / 'aapt2', 'dump', 'badging', apk])
identity = re.search(r"package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'", badging)
if not identity or identity.groups() != ('com.savagecarol.dumbbell', version_code, version_name):
    raise SystemExit('Release identity/version mismatch.')
if 'application-debuggable' in badging:
    raise SystemExit('Refusing to distribute a debuggable APK.')
if "application-label:'Dumbbell'" not in badging:
    raise SystemExit('Release launcher label must be Dumbbell.')
target_sdk = int(re.search(r"targetSdkVersion:'(\d+)'", badging)[1])
minimum_sdk = int(re.search(r"(?:minSdkVersion|sdkVersion):'(\d+)'", badging)[1])
if target_sdk < 36:
    raise SystemExit('Release must target Android API 36 or newer.')
permissions = sorted(set(re.findall(r"uses-permission[^:]*: name='([^']+)'", badging)))
allowed_permissions = {'android.permission.POST_NOTIFICATIONS', 'com.savagecarol.dumbbell.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION'}
if set(permissions) - allowed_permissions:
    raise SystemExit(f'Review unexpected release permissions: {set(permissions) - allowed_permissions}')
signature = command([tools / 'apksigner', 'verify', '--verbose', '--print-certs', apk])
if 'Android Debug' in signature:
    raise SystemExit('Refusing to distribute an APK signed with a debug certificate.')
fingerprint = re.search(r'Signer #1 certificate SHA-256 digest: ([0-9a-f]+)', signature)[1]
command([tools / 'zipalign', '-c', '-P', '16', '-v', '4', apk])
manifest = command([tools / 'aapt2', 'dump', 'xmltree', apk, '--file', 'AndroidManifest.xml'])
for attribute in ('allowBackup', 'usesCleartextTraffic'):
    match = re.search(rf'android:{attribute}[^\n]*', manifest)
    if not match or not re.search(r'=(?:false|\(type 0x12\)0x0)$', match[0]):
        raise SystemExit(f'{attribute} must be false in the release manifest.')

native_alignment = []
with zipfile.ZipFile(apk) as archive:
    for name in archive.namelist():
        if not name.startswith(('lib/arm64-v8a/', 'lib/x86_64/')) or not name.endswith('.so'):
            continue
        data = archive.read(name)
        if data[:6] != b'\x7fELF\x02\x01':
            raise SystemExit(f'Unexpected native ELF format: {name}')
        phoff = struct.unpack_from('<Q', data, 32)[0]
        phsize, phcount = struct.unpack_from('<HH', data, 54)
        aligns = [struct.unpack_from('<Q', data, phoff + i * phsize + 48)[0]
                  for i in range(phcount) if struct.unpack_from('<I', data, phoff + i * phsize)[0] == 1]
        if not aligns or min(aligns) < 16384:
            raise SystemExit(f'Native library lacks 16 KB LOAD alignment: {name}')
        native_alignment.append(name)
    license_count = sum(name.startswith('assets/flutter_assets/assets/exercises/licenses/') for name in archive.namelist())
    illustrations = sum(name.startswith('assets/flutter_assets/assets/exercises/repdb/flat/') and name.endswith('.webp') for name in archive.namelist())
    if license_count < 1 or illustrations != 1217:
        raise SystemExit('Exercise illustrations or bundled attribution are missing.')

java_bin = Path('/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin')
jarsigner = java_bin / 'jarsigner' if (java_bin / 'jarsigner').is_file() else 'jarsigner'
keytool = java_bin / 'keytool' if (java_bin / 'keytool').is_file() else 'keytool'
bundle_signature = command([jarsigner, '-verify', aab])
if 'jar verified.' not in bundle_signature:
    raise SystemExit('App bundle signature verification failed.')
bundle_certificate = command([keytool, '-printcert', '-jarfile', aab])
bundle_fingerprint = re.search(r'SHA256:\s*([0-9A-F:]+)', bundle_certificate)[1].replace(':', '').lower()
if bundle_fingerprint != fingerprint:
    raise SystemExit('APK and AAB were signed by different identities.')

output = ROOT / 'releases' / f'{version_name}+{version_code}'
output.mkdir(parents=True, exist_ok=True)
names = []
for source, extension in ((apk, 'apk'), (aab, 'aab')):
    name = f'{slug}-{version_name}-{version_code}.{extension}'
    shutil.copy2(source, output / name)
    names.append(name)
with (output / 'SHA256SUMS.txt').open('w') as file:
    for name in names:
        digest = hashlib.sha256((output / name).read_bytes()).hexdigest()
        file.write(f'{digest}  {name}\n')
report = {
    'app': 'Dumbbell', 'applicationId': identity[1], 'version': version_name,
    'versionCode': int(version_code), 'minSdk': minimum_sdk, 'targetSdk': target_sdk,
    'debuggable': False, 'permissions': permissions, 'certificateSHA256': fingerprint,
    'apkZipAlignment16KB': True, 'nativeLibraries16KB': native_alignment,
    'illustrations': illustrations, 'apkAndBundleCertificatesMatch': True,
    'files': {name: (output / name).stat().st_size for name in names},
}
(output / 'verification.json').write_text(json.dumps(report, indent=2) + '\n')
policy = (ROOT / 'assets/legal/privacy-policy.md').read_text().replace('{{CONTACT}}', f'For support and privacy questions about Dumbbell, contact {config["SUPPORT_EMAIL"]}.')
body = []
for paragraph in policy.split('\n\n'):
    paragraph = paragraph.strip()
    tag = 'h2' if paragraph.startswith('## ') else 'h1' if paragraph.startswith('# ') else 'p'
    body.append(f'<{tag}>{html.escape(paragraph.lstrip("# "))}</{tag}>')
document = '<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Dumbbell Privacy Policy</title><style>body{font:18px/1.6 system-ui;max-width:760px;margin:48px auto;padding:0 24px;color:#202020}h1,h2{line-height:1.2}</style><main>' + '\n'.join(body) + '</main></html>'
store = ROOT.parent / 'docs/store'
store.mkdir(parents=True, exist_ok=True)
(store / 'privacy-policy.html').write_text(document)
(output / 'README.txt').write_text(
    f'Dumbbell {version_name} ({version_code})\n\nShare the .apk file for direct Android installation. The .aab is for Play Console, not direct installation.\n'
    'Android 7.0 or newer is required. Allow installation from the app used to open the APK when Android asks.\n'
    f'Package: com.savagecarol.dumbbell\nSupport: {config["SUPPORT_EMAIL"]}\n\n'
    'Your previous LiftLog development installation is separate. Export a Backup CSV there and import it in Dumbbell to transfer workouts. Photos and profile are not in CSV backups.\n'
    'Keep the same release signing identity for APK updates. Play App Signing must be configured to use this signing identity if Play updates should replace these sideloaded APKs without uninstalling.\n'
    'Do not distribute .signing/ or android/key.properties.\n')
print(json.dumps(report, indent=2))
print(f'Validated release artifacts: {output}')
