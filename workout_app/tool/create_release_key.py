#!/usr/bin/env python3
"""Create LiftLog's private local release identity once. Never prints secrets."""
from pathlib import Path
import os
import secrets
import shutil
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
private = root / '.signing'
store = private / 'liftlog-release.jks'
properties = root / 'android/key.properties'
if store.exists() or properties.exists():
    sys.exit('Signing material already exists. Restore/use the original key; nothing was changed.')
private.mkdir(mode=0o700, exist_ok=True)
private.chmod(0o700)
java_keytool = Path('/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool')
keytool = str(java_keytool) if java_keytool.is_file() else shutil.which('keytool')
if not keytool:
    sys.exit('Install a Java JDK with keytool before creating a release key.')
password = secrets.token_urlsafe(36)
environment = os.environ.copy()
environment['LIFTLOG_KEY_PASSWORD'] = password
old_mask = os.umask(0o077)
try:
    subprocess.run([
        keytool, '-genkeypair', '-noprompt', '-keystore', str(store),
        '-storetype', 'JKS', '-alias', 'liftlog-release', '-keyalg', 'RSA',
        '-keysize', '3072', '-validity', '10000', '-dname', 'CN=LiftLog Release',
        '-storepass:env', 'LIFTLOG_KEY_PASSWORD', '-keypass:env', 'LIFTLOG_KEY_PASSWORD',
    ], env=environment, check=True, capture_output=True)
    with properties.open('x') as output:
        output.write('storeFile=../.signing/liftlog-release.jks\n')
        output.write('keyAlias=liftlog-release\n')
        output.write(f'storePassword={password}\nkeyPassword={password}\n')
    store.chmod(0o600)
    properties.chmod(0o600)
finally:
    os.umask(old_mask)
print('Created private release signing files. Back up .signing/ and android/key.properties securely; never share them with the APK.')
