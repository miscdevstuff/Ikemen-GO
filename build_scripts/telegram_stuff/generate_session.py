from telethon.sync import TelegramClient
from telethon.sessions import StringSession

api_id = 1234567  # Replace with your api_id from my.telegram.org
api_hash = "your_api_hash_here"  # Replace with your api_hash

with TelegramClient(StringSession(), api_id, api_hash) as client:
    print("\nSession string (copy this exactly):")
    print(client.session.save())
