#!/usr/bin/env python3
"""Installs Learn Sphere's Android tracking code into a Flutter project.

Run once, from the project root, AFTER `flutter create --platforms=android,web .`:

    python3 tools/apply_android.py

It
  1. copies the Kotlin files from android_native/ into the app's Kotlin folder
     (using your project's package name),
  2. adds the permissions, the monitor service and the boot receiver to
     AndroidManifest.xml,
  3. allows plain-http calls for local development (skip with --no-cleartext).

Safe to run again: nothing is added twice.
"""
import argparse
import re
import shutil
import sys
from pathlib import Path

KOTLIN_FILES = [
    "MainActivity.kt",
    "UsageReader.kt",
    "LimitStore.kt",
    "MonitorService.kt",
    "BootReceiver.kt",
]

PERMISSIONS = [
    ("android.permission.INTERNET", None),
    ("android.permission.PACKAGE_USAGE_STATS", 'tools:ignore="ProtectedPermissions"'),
    ("android.permission.SYSTEM_ALERT_WINDOW", None),
    ("android.permission.FOREGROUND_SERVICE", None),
    ("android.permission.FOREGROUND_SERVICE_SPECIAL_USE", None),
    ("android.permission.POST_NOTIFICATIONS", None),
    ("android.permission.RECEIVE_BOOT_COMPLETED", None),
]

QUERIES = """    <queries>
        <intent>
            <action android:name="android.intent.action.MAIN" />
            <category android:name="android.intent.category.LAUNCHER" />
        </intent>
    </queries>
"""

COMPONENTS = """        <service
            android:name=".MonitorService"
            android:exported="false"
            android:foregroundServiceType="specialUse">
            <property
                android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE"
                android:value="Watches the app on screen against the daily limits the user set" />
        </service>
        <receiver
            android:name=".BootReceiver"
            android:exported="false">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
            </intent-filter>
        </receiver>
"""


def find_package(app_dir: Path) -> str:
    """The package of the existing MainActivity (what Flutter generated)."""
    kotlin_root = app_dir / "src" / "main" / "kotlin"
    for f in sorted(kotlin_root.rglob("MainActivity.kt")) if kotlin_root.exists() else []:
        m = re.search(r"^\s*package\s+([\w.]+)", f.read_text(), re.M)
        if m:
            return m.group(1)
    for name in ("build.gradle.kts", "build.gradle"):
        g = app_dir / name
        if g.exists():
            text = g.read_text()
            m = re.search(r'namespace\s*=?\s*"([\w.]+)"', text) or re.search(
                r'applicationId\s*=?\s*"([\w.]+)"', text
            )
            if m:
                return m.group(1)
    sys.exit("Could not work out the package name. Is this a Flutter project with an android/ folder?")


def install_kotlin(root: Path, app_dir: Path, package: str) -> None:
    src = root / "android_native"
    dest = app_dir / "src" / "main" / "kotlin" / Path(*package.split("."))
    dest.mkdir(parents=True, exist_ok=True)

    # Remove any other MainActivity.kt (e.g. flutter create put it in a different folder).
    kotlin_root = app_dir / "src" / "main" / "kotlin"
    for old in kotlin_root.rglob("MainActivity.kt"):
        if old.parent != dest:
            old.unlink()

    for name in KOTLIN_FILES:
        text = (src / name).read_text().replace("__PACKAGE__", package)
        target = dest / name
        if target.exists() and name == "MainActivity.kt" and "learnsphere/native" not in target.read_text():
            shutil.copy(target, target.with_suffix(".kt.bak"))
        target.write_text(text)
        print(f"  wrote {target.relative_to(root)}")


def patch_manifest(app_dir: Path, cleartext: bool) -> None:
    path = app_dir / "src" / "main" / "AndroidManifest.xml"
    if not path.exists():
        sys.exit(f"{path} not found.")
    xml = path.read_text()

    # tools namespace
    if "xmlns:tools=" not in xml:
        xml = re.sub(
            r"<manifest\b",
            '<manifest xmlns:tools="http://schemas.android.com/tools"',
            xml,
            count=1,
        )

    # permissions + queries, placed right before <application
    additions = ""
    for name, extra in PERMISSIONS:
        if f'android:name="{name}"' not in xml:
            attr = f" {extra}" if extra else ""
            additions += f'    <uses-permission android:name="{name}"{attr} />\n'
    if "<queries>" not in xml:
        additions += QUERIES
    if additions:
        xml = re.sub(r"(\s*)<application\b", lambda m: "\n" + additions.rstrip("\n") + "\n" + m.group(0).lstrip("\n"), xml, count=1)

    # service + receiver, placed right before </application>
    if ".MonitorService" not in xml:
        xml = xml.replace("</application>", COMPONENTS + "    </application>", 1)

    # plain http for local development
    if cleartext and "usesCleartextTraffic" not in xml:
        xml = re.sub(r"<application\b", '<application\n        android:usesCleartextTraffic="true"', xml, count=1)

    path.write_text(xml)
    print(f"  patched {path}")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("project", nargs="?", default=".", help="Flutter project root (default: current folder)")
    ap.add_argument("--no-cleartext", action="store_true", help="do not allow plain http (use for https-only servers)")
    args = ap.parse_args()

    root = Path(args.project).resolve()
    app_dir = root / "android" / "app"
    if not app_dir.exists():
        sys.exit("No android/app folder. Run `flutter create --platforms=android,web .` first.")
    if not (root / "android_native").exists():
        sys.exit("android_native/ folder not found next to this script's project root.")

    package = find_package(app_dir)
    print(f"Package: {package}")
    install_kotlin(root, app_dir, package)
    patch_manifest(app_dir, cleartext=not args.no_cleartext)
    print("Done. Run `flutter run` on an Android device.")


if __name__ == "__main__":
    main()
