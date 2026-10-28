# TV Guard release keystore

`agent-release.jks` and `keystore.properties` are **not committed** (see
`boretube-agent/.gitignore`). The phone pins the signing certificate's SHA-256
(`boretube-mobile/assets/agent/manifest.json` → `certSha256`), so a new keystore
means a new pin: the phone will refuse to update an agent signed with the old
key, and the TV will refuse `pm install -r` over an install signed with a
different key (uninstall the agent first).

Keep a private backup of both files. Losing them means every TV needs the agent
uninstalled and reinstalled.

## Regenerate

From `boretube-agent/` (JDK 17 `keytool`):

```sh
P=$(head -c 24 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 28)
keytool -genkeypair -v -keystore keystore/agent-release.jks -storetype PKCS12 \
  -alias boretube-agent -keyalg RSA -keysize 4096 -validity 10950 \
  -storepass "$P" -keypass "$P" -dname "CN=boretube TV Guard, O=boretube"
cat > keystore/keystore.properties <<EOF
storeFile=keystore/agent-release.jks
storePassword=$P
keyAlias=boretube-agent
keyPassword=$P
EOF
chmod 600 keystore/agent-release.jks keystore/keystore.properties
```

Then rebuild (`./gradlew assembleRelease`), and update the phone's
`assets/agent/manifest.json` (`sha256`, `certSha256`):

```sh
apksigner verify --print-certs app/build/outputs/apk/release/app-release.apk  # SHA-256 digest
sha256sum app/build/outputs/apk/release/app-release.apk
```

Without `keystore.properties`, `assembleRelease` produces an unsigned APK.
