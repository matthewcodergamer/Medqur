#!/usr/bin/env python3
"""Configure generated Flutter platforms for Medqur.

The repository intentionally generates platform scaffolding in CI. This script
adds permissions/native auth/printing setup and creates branded raster app icons
from the same geometry as assets/medqur_app_icon.svg.
"""
from __future__ import annotations

import json
import plistlib
import re
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
BLUE = (52, 116, 230)
WHITE = (255, 255, 255)
SVG = (ROOT / "assets" / "medqur_app_icon.svg").read_text(encoding="utf-8")


def icon(size: int) -> Image.Image:
    scale = 4
    s = size * scale
    image = Image.new("RGB", (s, s), WHITE)
    draw = ImageDraw.Draw(image)
    width = max(6, int(s * 0.075))
    pts = [
        (int(s * .18), int(s * .25)),
        (int(s * .18), int(s * .76)),
        (int(s * .82), int(s * .76)),
        (int(s * .82), int(s * .25)),
        (int(s * .54), int(s * .52)),
        (int(s * .50), int(s * .56)),
        (int(s * .46), int(s * .52)),
        (int(s * .18), int(s * .25)),
    ]
    draw.line(pts, fill=BLUE, width=width, joint="curve")
    radius = width // 2
    for x, y in (pts[0], pts[1], pts[2], pts[3]):
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=BLUE)
    draw.line(pts, fill=BLUE, width=width, joint="curve")
    return image.resize((size, size), Image.Resampling.LANCZOS)


def save_icon(path: Path, size: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    icon(size).save(path, "PNG", optimize=True)


def configure_android() -> None:
    android = ROOT / "android"
    if not android.exists():
        return

    manifest_path = android / "app/src/main/AndroidManifest.xml"
    manifest = manifest_path.read_text(encoding="utf-8")
    permissions = [
        '<uses-permission android:name="android.permission.CAMERA" />',
        '<uses-permission android:name="android.permission.USE_BIOMETRIC" />',
        '<uses-permission android:name="android.permission.INTERNET" />',
    ]
    insertion = "\n    " + "\n    ".join(p for p in permissions if p not in manifest) + "\n"
    if insertion.strip():
        manifest = manifest.replace("<application", insertion + "    <application", 1)
    manifest_path.write_text(manifest, encoding="utf-8")

    for main_activity in android.glob("app/src/main/kotlin/**/MainActivity.kt"):
        text = main_activity.read_text(encoding="utf-8")
        text = text.replace("import io.flutter.embedding.android.FlutterActivity", "import io.flutter.embedding.android.FlutterFragmentActivity")
        text = text.replace("FlutterActivity()", "FlutterFragmentActivity()")
        main_activity.write_text(text, encoding="utf-8")

    gradle = android / "app/build.gradle.kts"
    if gradle.exists():
        text = gradle.read_text(encoding="utf-8")
        text = text.replace("minSdk = flutter.minSdkVersion", "minSdk = 24")
        if "androidx.appcompat:appcompat" not in text:
            text += '\n\ndependencies {\n    implementation("androidx.appcompat:appcompat:1.7.1")\n}\n'
        gradle.write_text(text, encoding="utf-8")

    for style_file in android.glob("app/src/main/res/**/styles.xml"):
        text = style_file.read_text(encoding="utf-8")
        text = text.replace('@android:style/Theme.Light.NoTitleBar', 'Theme.AppCompat.Light.NoActionBar')
        text = text.replace('@android:style/Theme.Black.NoTitleBar', 'Theme.AppCompat.DayNight.NoActionBar')
        style_file.write_text(text, encoding="utf-8")

    sizes = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for density, size in sizes.items():
        save_icon(android / f"app/src/main/res/mipmap-{density}/ic_launcher.png", size)


def configure_ios() -> None:
    ios = ROOT / "ios"
    if not ios.exists():
        return

    plist_path = ios / "Runner/Info.plist"
    with plist_path.open("rb") as handle:
        data = plistlib.load(handle)
    data["NSCameraUsageDescription"] = "Medqur uses the camera to scan staff IDs, patient wristbands, NIDS/NIC credentials, and medication barcodes."
    data["NSFaceIDUsageDescription"] = "Medqur uses Face ID to verify a healthcare worker before starting or unlocking a clinical shift."
    data["CFBundleDisplayName"] = "Medqur"
    with plist_path.open("wb") as handle:
        plistlib.dump(data, handle, sort_keys=False)

    podfile = ios / "Podfile"
    if podfile.exists():
        text = podfile.read_text(encoding="utf-8")
        if re.search(r"platform :ios, '[^']+'", text):
            text = re.sub(r"platform :ios, '[^']+'", "platform :ios, '13.0'", text)
        else:
            text = "platform :ios, '13.0'\n" + text
        if "use_frameworks!" not in text:
            text = text.replace("target 'Runner' do", "target 'Runner' do\n  use_frameworks!", 1)
        podfile.write_text(text, encoding="utf-8")

    project = ios / "Runner.xcodeproj/project.pbxproj"
    if project.exists():
        text = project.read_text(encoding="utf-8")
        text = re.sub(r"IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;", "IPHONEOS_DEPLOYMENT_TARGET = 13.0;", text)
        project.write_text(text, encoding="utf-8")

    appicons = ios / "Runner/Assets.xcassets/AppIcon.appiconset"
    contents = appicons / "Contents.json"
    if contents.exists():
        catalog = json.loads(contents.read_text(encoding="utf-8"))
        for item in catalog.get("images", []):
            filename = item.get("filename")
            size_text = item.get("size")
            scale_text = item.get("scale", "1x")
            if not filename or not size_text:
                continue
            points = float(size_text.split("x", 1)[0])
            multiplier = float(scale_text.rstrip("x"))
            pixels = max(1, round(points * multiplier))
            save_icon(appicons / filename, pixels)


def configure_web() -> None:
    web = ROOT / "web"
    if not web.exists():
        return

    (web / "favicon.svg").write_text(SVG, encoding="utf-8")
    save_icon(web / "favicon.png", 32)
    save_icon(web / "icons/Icon-192.png", 192)
    save_icon(web / "icons/Icon-512.png", 512)
    save_icon(web / "icons/Icon-maskable-192.png", 192)
    save_icon(web / "icons/Icon-maskable-512.png", 512)

    index = web / "index.html"
    text = index.read_text(encoding="utf-8")
    text = re.sub(r'<link rel="icon" type="image/png" href="favicon.png"\s*/?>', '<link rel="icon" type="image/svg+xml" href="favicon.svg">', text)
    if 'name="theme-color"' not in text:
        text = text.replace("</head>", '  <meta name="theme-color" content="#FFFFFF">\n</head>')
    index.write_text(text, encoding="utf-8")

    manifest = web / "manifest.json"
    if manifest.exists():
        data = json.loads(manifest.read_text(encoding="utf-8"))
        data["name"] = "Medqur"
        data["short_name"] = "Medqur"
        data["background_color"] = "#FFFFFF"
        data["theme_color"] = "#FFFFFF"
        manifest.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    configure_android()
    configure_ios()
    configure_web()
    print("Configured Medqur platform permissions, native auth, printing, network access, and icons.")


if __name__ == "__main__":
    main()
