#!/usr/bin/env python3
"""
Pupil Codebase Semantic Embeddings & Knowledge Generator
Generates structured semantic chunks, symbol registries, and metadata index
for AI agent self-tracking and retrieval.
"""

import os
import re
import json
import hashlib
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DOCS_DIR = REPO_ROOT / "docs"
EMBEDDINGS_DIR = DOCS_DIR / "embeddings"
EMBEDDINGS_DIR.mkdir(parents=True, exist_ok=True)

TARGET_FILES = [
    "Package.swift",
    "scripts/bundle-app.sh",
    "scripts/build-dmg.sh",
    "scripts/generate-icon.swift",
    "Sources/Pupil/PupilApp.swift",
    "Sources/Pupil/Core/SecurityCoordinator.swift",
    "Sources/Pupil/Core/PowerAndLidMonitor.swift",
    "Sources/Pupil/Core/LockMonitor.swift",
    "Sources/Pupil/Core/SirenSynthesizer.swift",
    "Sources/Pupil/Core/KeychainManager.swift",
    "Sources/Pupil/Vision/VisionGazeDetector.swift",
    "Sources/Pupil/Vision/VisionMotionDetector.swift",
    "Sources/Pupil/Vision/CameraManager.swift",
    "Sources/Pupil/NotchOverlay/NotchGeometry.swift",
    "Sources/Pupil/NotchOverlay/NotchShape.swift",
    "Sources/Pupil/NotchOverlay/NotchWindow.swift",
    "Sources/Pupil/NotchOverlay/NotchOverlayView.swift",
    "Sources/Pupil/NotchOverlay/NotchOverlayController.swift",
    "Sources/Pupil/ScreenShield/ScreenShieldWindow.swift",
    "Sources/Pupil/ScreenShield/ScreenShieldView.swift",
    "Sources/Pupil/ScreenShield/ScreenShieldController.swift",
    "Sources/Pupil/MenuBar/MenuBarIconFactory.swift",
    "Sources/Pupil/Settings/PupilSettings.swift",
    "Sources/Pupil/Settings/SettingsMetrics.swift",
    "Sources/Pupil/Settings/SettingsControls.swift",
    "Sources/Pupil/Settings/SettingsTab.swift",
    "Sources/Pupil/Settings/SettingsTabBar.swift",
    "Sources/Pupil/Settings/ProgressiveHeaderBlur.swift",
    "Sources/Pupil/Settings/HeaderStatusButton.swift",
    "Sources/Pupil/Settings/SettingsWindowView.swift",
    "Sources/Pupil/Settings/Pages/GeneralSettingsPage.swift",
    "Sources/Pupil/Settings/Pages/GazeSettingsPage.swift",
    "Sources/Pupil/Settings/Pages/SensorsSettingsPage.swift",
    "Sources/Pupil/Settings/Pages/AlarmSettingsPage.swift",
    "Sources/Pupil/Settings/Pages/AboutSettingsPage.swift",
    "Tests/PupilTests/PupilSecurityTests.swift",
]

MODULE_MAP = {
    "PupilApp.swift": "App Lifecycle & Menu Bar",
    "SecurityCoordinator.swift": "Core Security State Machine",
    "PowerAndLidMonitor.swift": "IOKit Hardware Power & Lid Monitoring",
    "LockMonitor.swift": "macOS Screen Lock & Wake Monitoring",
    "SirenSynthesizer.swift": "AVAudioEngine Real-time Audio Synthesis",
    "KeychainManager.swift": "macOS Keychain & Touch ID Security",
    "VisionGazeDetector.swift": "Apple Vision Gaze & Iris Estimation",
    "CameraManager.swift": "AVFoundation 10 FPS Camera Capture",
    "NotchGeometry.swift": "MacBook Notch & Dynamic Island Geometry",
    "NotchShape.swift": "Concave Flare Notch Shape",
    "NotchWindow.swift": "Shielding-Level Non-activating NSPanel",
    "NotchOverlayView.swift": "Biometric Eye & Interactive Notch UI",
    "NotchOverlayController.swift": "Notch Window Lifecycle Controller",
    "ScreenShieldWindow.swift": "Shielding-Level Privacy Blur NSPanel",
    "ScreenShieldView.swift": "Full-Screen Blur & Central Biometric Card",
    "ScreenShieldController.swift": "Multi-Display Screen Shield Manager",
    "MenuBarIconFactory.swift": "Resolution-independent Vector Menu Bar Template",
    "PupilSettings.swift": "Observable Settings Store",
    "SettingsMetrics.swift": "Design System Tokens & Metrics",
    "SettingsControls.swift": "System Settings Components & Vibrancy",
    "SettingsTab.swift": "Settings Tab Enumeration",
    "SettingsTabBar.swift": "Floating Capsule Tab Bar",
    "ProgressiveHeaderBlur.swift": "Progressive Gradient Header Blur",
    "HeaderStatusButton.swift": "Live Header Status Pill & Popover",
    "SettingsWindowView.swift": "Settings Root View & Trackpad Gestures",
    "GeneralSettingsPage.swift": "General Settings Page",
    "GazeSettingsPage.swift": "Gaze Settings & Live Calibration Page",
    "SensorsSettingsPage.swift": "Hardware Sensors & Relay Settings Page",
    "AlarmSettingsPage.swift": "Alarm Synthesis & Audit Log Page",
    "AboutSettingsPage.swift": "About & Privacy Page",
    "PupilSecurityTests.swift": "Deterministic Security Test Suite",
    "Package.swift": "Swift Package Manager Definition",
    "bundle-app.sh": "App Bundle Packaging Script",
    "build-dmg.sh": "Single Downloadable DMG & ZIP Packaging Script",
    "generate-icon.swift": "Retina AppIcon.icns Generator",
}

def extract_symbols(content: str):
    symbols = []
    # match class, struct, enum, protocol, actor
    type_matches = re.findall(r'(?:public\s+|final\s+|open\s+|private\s+)*(?:class|struct|enum|protocol|actor)\s+([A-Za-z0-9_]+)', content)
    symbols.extend(type_matches)
    # match public / internal methods
    func_matches = re.findall(r'(?:public\s+|static\s+|nonisolated\s+)*func\s+([A-Za-z0-9_]+)', content)
    symbols.extend(func_matches[:12])  # top 12 functions
    return list(dict.fromkeys(symbols))

def compute_content_hash(text: str) -> str:
    return hashlib.sha256(text.encode('utf-8')).hexdigest()[:16]

def main():
    chunks = []
    all_symbols = {}
    total_lines = 0

    for rel_path in TARGET_FILES:
        full_path = REPO_ROOT / rel_path
        if not full_path.exists():
            continue

        content = full_path.read_text(encoding='utf-8')
        lines = content.splitlines()
        total_lines += len(lines)
        file_name = Path(rel_path).name
        module_name = MODULE_MAP.get(file_name, "General")
        symbols = extract_symbols(content)
        all_symbols[rel_path] = symbols

        # Generate semantic summary
        summary = ""
        # look for top docstring or comments
        top_comments = []
        for line in lines[:20]:
            if line.startswith("//") or line.startswith("/*") or line.startswith("#"):
                clean = line.lstrip("/#* ").strip()
                if clean:
                    top_comments.append(clean)
        summary = " ".join(top_comments) if top_comments else f"Module implementing {file_name}"

        # Generate chunk representation
        chunk = {
            "chunk_id": f"pupil::{rel_path.replace('/', '::')}",
            "file_path": rel_path,
            "module_category": module_name,
            "line_count": len(lines),
            "content_hash": compute_content_hash(content),
            "symbols": symbols,
            "summary": summary,
            "semantic_text": f"File: {rel_path}\nModule: {module_name}\nSummary: {summary}\nKey Symbols: {', '.join(symbols)}\nContent Sample:\n" + "\n".join(lines[:40]),
            "keywords": [
                w.lower() for w in re.findall(r'[A-Za-z0-9]{3,}', f"{rel_path} {module_name} {summary} {' '.join(symbols)}")
                if w.lower() not in {"the", "and", "for", "with", "from", "that", "this", "var", "let", "func", "import"}
            ][:25]
        }
        chunks.append(chunk)

    output_data = {
        "repository": "pupil",
        "description": "Native macOS menu bar & notch security sentinel for solo study sessions",
        "platform": "macOS 15+ (Sequoia), Swift 6, AppKit + SwiftUI",
        "total_indexed_files": len(chunks),
        "total_source_lines": total_lines,
        "symbol_directory": all_symbols,
        "embeddings_chunks": chunks
    }

    out_file = EMBEDDINGS_DIR / "codebase_embeddings.json"
    with open(out_file, "w", encoding="utf-8") as f:
        json.dump(output_data, f, indent=2)

    print(f"Generated semantic index with {len(chunks)} chunks and {total_lines} lines -> {out_file}")

if __name__ == "__main__":
    main()
