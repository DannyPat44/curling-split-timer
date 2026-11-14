#!/bin/bash
# Run the app in the simulator with your curling.dimmit.net sensor app key,
# so timed rocks really go to your practice session. The key comes from the
# macOS Keychain and is only written into bin/ (git-ignored), never source.
#     security add-generic-password -a "$USER" -s curling.dimmit.net-sensor-key -w
#     make sync-sim
set -e
cd "$(dirname "$0")/.."
key=$(security find-generic-password -a "$USER" -s curling.dimmit.net-sensor-key -w 2>/dev/null) || {
    echo "No key in the Keychain. Add it with:" >&2
    echo "  security add-generic-password -a \"\$USER\" -s curling.dimmit.net-sensor-key -w" >&2
    exit 1
}
mkdir -p bin/secrets/settings
umask 077
cat > bin/secrets/settings/properties.xml <<XML
<properties>
    <property id="dimmitSync" type="boolean">true</property>
    <property id="dimmitKey" type="string">$key</property>
</properties>
XML
# Every resource folder except resources/settings, whose empty key would win
cp resources/settings/settings.xml bin/secrets/settings/
cat > bin/secrets/sync.jungle <<'JUNGLE'
project.manifest = ../../manifest.xml
base.sourcePath = ../../source
base.resourcePath = ../../resources/strings;../../resources/drawables;../../resources/contributions;settings
base.excludeAnnotations = demo;video
JUNGLE
SDK=$(cat "$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg")
# The simulator keeps the app's settings from earlier runs (one file for the
# app id); clear it so this build's settings, with the key, are the ones used
rm -f "${TMPDIR}com.garmin.connectiq/GARMIN/APPS/SETTINGS/"CURLING*.SET
KEY=$(make -s -f - print-key <<'MK'
-include local.mk
KEY ?= developer_key.der
print-key: ; @echo $(KEY)
MK
)
"${SDK}bin/monkeyc" -f bin/secrets/sync.jungle -d fr265 -y "$KEY" -o bin/Sync-fr265.prg -w
pgrep -qf ConnectIQ.app || { "${SDK}bin/connectiq"; sleep 6; }
"${SDK}bin/monkeydo" bin/Sync-fr265.prg fr265
