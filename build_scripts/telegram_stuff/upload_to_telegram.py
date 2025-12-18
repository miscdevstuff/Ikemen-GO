#!/usr/bin/env python3

import asyncio
import os
import argparse
from telethon import TelegramClient
from telethon.sessions import StringSession
from pathlib import Path


async def main():
    # Parse command-line arguments
    parser = argparse.ArgumentParser(
        description="Upload a file to Telegram channel using user session (supports >50MB files up to 2GB)"
    )
    parser.add_argument(
        "-f",
        "--file",
        type=str,
        required=True,
        help="Path to the file to upload (e.g., app-debug.zip)",
    )
    args = parser.parse_args()

    file_path = args.file.strip()

    # Basic validation
    if not Path(file_path).exists():
        print(f"ERROR: File not found at path: {file_path}")
        return

    file_size = Path(file_path).stat().st_size / (1024 * 1024)  # MB
    print(f"Uploading file: {file_path} (~{file_size:.1f} MB)")

    # Load from env vars (set in GitHub Actions)
    api_id = os.getenv("TELEGRAM_API_ID")
    api_hash = os.getenv("TELEGRAM_API_HASH")
    session_str = os.getenv("TELEGRAM_STRING_SESSION")
    chat_id_str = os.getenv("TELEGRAM_CHAT_ID")

    if not all([api_id, api_hash, session_str, chat_id_str]):
        print(
            "ERROR: Missing required env vars (TELEGRAM_API_ID, TELEGRAM_API_HASH, TELEGRAM_STRING_SESSION, or TELEGRAM_CHAT_ID)"
        )
        return

    try:
        api_id = int(api_id)
        chat_id = int(chat_id_str)
    except ValueError:
        print("ERROR: TELEGRAM_API_ID or TELEGRAM_CHAT_ID must be valid integers")
        return

    client = TelegramClient(StringSession(session_str), api_id, api_hash)
    await client.start()

    message = f"Build #{os.getenv('GITHUB_RUN_NUMBER', 'unknown')}: Latest Ikemen GO Android APK! (Debug, ~{file_size:.1f}MB zipped)"

    try:
        # Upload with progress logging
        await client.send_file(
            chat_id,
            file_path,
            caption=message,
            progress_callback=lambda sent, total: print(
                f"Progress: {sent}/{total} bytes ({(sent / total) * 100:.1f}%)"
            ),
        )
        print("Upload complete! Check your channel.")
    except Exception as e:
        print(f"Upload failed: {e}")
    finally:
        await client.disconnect()


asyncio.run(main())
