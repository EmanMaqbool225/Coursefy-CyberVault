# Coursefy CyberVault

An offline Windows desktop application built with Flutter for organizing, securing, and playing specialized courses in cybersecurity and software development.

## Overview

Coursefy CyberVault provides a self-contained learning environment designed to work completely offline. It protects local video files from unauthorized extraction and binds application access to the host device's hardware identity.

## Key Features

- Encrypted Video Playback: Video files are stored on disk using AES-CBC encryption and decrypted on the fly into temporary storage during playback, with automatic cache cleanup.
- Hardware-Bound Licensing: Restricts access using a unique hardware fingerprint generated from the host machine and overlays a subtle device ID watermark on the player.
- Portable Data Structure: Stores course metadata (`courses.json`), thumbnails, and encrypted vaults locally alongside the executable for straightforward deployment across authorized machines.
- Built-in Media Player: Includes playback speed controls (`0.75x` to `2.0x`), keyboard navigation shortcuts, screen brightness adjustment, and progress tracking.
- Search and Organization: Supports instant filtering by lesson title, course track, or lesson number, alongside completion tracking and a favorites list.
- Admin Management: Includes a PIN-protected interface for adding, editing, and organizing courses.

## Tech Stack

- Framework: Flutter (Windows Desktop)
- Language: Dart
- Security & Storage: `encrypt` (AES-CBC), `flutter_secure_storage`, local JSON storage
- Media: `video_player`

## Project Structure

```text
lib/
├── core/
│   ├── config/          # App edition settings and vault configuration
│   ├── security/        # Hardware fingerprinting and device identity
│   └── theme/           # Dark UI styling and typography
└── features/
    └── courses/         # Course models, storage service, UI screens, and secure player
