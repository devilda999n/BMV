#!/usr/bin/env bash
set -euo pipefail

echo "Applying Ashish Browser customizations..."

python3 - <<'PY'
from pathlib import Path
import re

# -----------------------------
# APP NAME
# -----------------------------
p = Path("app/src/main/res/values/static_strings.xml")
s = p.read_text()

s = s.replace(
    '<string name="app_name" translatable="false">Iceraven Fenix</string>',
    '<string name="app_name" translatable="false">Ashish</string>'
)

s = s.replace(
    '<string name="firefox" translatable="false">Iceraven</string>',
    '<string name="firefox" translatable="false">Ashish</string>'
)

p.write_text(s)

# -----------------------------
# UNIQUE ASHISH PACKAGE
# + WIREGUARD
# -----------------------------
p = Path("app/build.gradle")
s = p.read_text()

# Make Ashish a separate app instead of the old Iceraven/BMW package.
pattern = (
    r'(forkRelease releaseTemplate >> \{.*?applicationIdSuffix )"\.iceraven"'
    r'(.*?def deepLinkSchemeValue = )"iceraven"'
    r'(.*?"sharedUserId": )"io\.github\.forkmaintainers\.iceraven\.sharedID"'
)

replacement = (
    r'\1".ashish"'
    r'\2"ashish"'
    r'\3"io.github.forkmaintainers.ashish.sharedID"'
)

s, count = re.subn(pattern, replacement, s, count=1, flags=re.S)

if count != 1:
    raise SystemExit("Could not create unique Ashish package")

# WireGuard Android library
if 'com.wireguard.android:tunnel:1.0.20260102' not in s:
    target = """dependencies {
    implementation project('longfox')"""

    replacement = """dependencies {
    implementation "com.wireguard.android:tunnel:1.0.20260102"
    coreLibraryDesugaring "com.android.tools:desugar_jdk_libs:2.1.5"
    implementation project('longfox')"""

    if target not in s:
        raise SystemExit("Main dependencies block not found")

    s = s.replace(target, replacement, 1)

# WireGuard Java compatibility
if "coreLibraryDesugaringEnabled true" not in s:
    target = """android {
    project.maybeConfigForJetpackBenchmark(it)"""

    replacement = """android {
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
        coreLibraryDesugaringEnabled true
    }

    project.maybeConfigForJetpackBenchmark(it)"""

    if target not in s:
        raise SystemExit("Android block not found")

    s = s.replace(target, replacement, 1)

p.write_text(s)

# -----------------------------
# START ASHISH VPN
# -----------------------------
p = Path("app/src/main/java/org/mozilla/fenix/HomeActivity.kt")
s = p.read_text()

if "AshishVpn.ensureStarted(this)" not in s:
    target = """override fun onResume() {
        super.onResume()"""

    replacement = """override fun onResume() {
        super.onResume()
        org.mozilla.fenix.ashish.AshishVpn.ensureStarted(this)"""

    if target not in s:
        raise SystemExit("HomeActivity onResume not found")

    s = s.replace(target, replacement, 1)

p.write_text(s)
PY

mkdir -p app/src/main/java/org/mozilla/fenix/ashish

cat > app/src/main/java/org/mozilla/fenix/ashish/AshishVpn.kt <<'KOTLIN'
package org.mozilla.fenix.ashish

import android.app.Activity
import com.wireguard.android.backend.GoBackend
import com.wireguard.android.backend.Tunnel
import com.wireguard.config.Config
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.mozilla.fenix.R
import java.io.ByteArrayInputStream
import java.nio.charset.StandardCharsets

object AshishVpn {

    private var backend: GoBackend? = null
    private var permissionAsked = false

    private val tunnel = object : Tunnel {
        override fun getName(): String = "ashish-vpn"

        override fun onStateChange(newState: Tunnel.State) {
            // No UI action required.
        }
    }

    fun ensureStarted(activity: Activity) {
        val permissionIntent = GoBackend.VpnService.prepare(activity)

        if (permissionIntent != null) {
            if (!permissionAsked) {
                permissionAsked = true
                activity.startActivity(permissionIntent)
            }
            return
        }

        CoroutineScope(Dispatchers.IO).launch {
            try {
                val original = activity.resources
                    .openRawResource(R.raw.ashish_wg)
                    .bufferedReader()
                    .use { it.readText() }

                val scopedConfig =
                    if (
                        original.contains("IncludedApplications", ignoreCase = true) ||
                        original.contains("ExcludedApplications", ignoreCase = true)
                    ) {
                        original
                    } else {
                        original.replaceFirst(
                            "[Interface]",
                            "[Interface]\nIncludedApplications = ${activity.packageName}",
                        )
                    }

                val config = Config.parse(
                    ByteArrayInputStream(
                        scopedConfig.toByteArray(StandardCharsets.UTF_8),
                    ),
                )

                val currentBackend =
                    backend ?: GoBackend(activity.applicationContext).also {
                        backend = it
                    }

                currentBackend.setState(
                    tunnel,
                    Tunnel.State.UP,
                    config,
                )
            } catch (_: Throwable) {
                // Browser remains usable if the VPN server/config is unavailable.
            }
        }
    }
}
KOTLIN

echo "Ashish Browser customizations complete."
