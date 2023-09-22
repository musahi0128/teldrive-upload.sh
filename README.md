# teldrive-upload.sh

An alternative to [Teldrive Upload](https://github.com/divyam234/teldrive-upload)

This script upload files via api call to a locally running `telegram-bot-api` so it should upload faster than uploading directly to telegram api server.

Prerequisite
---
1. Run `telegram-bot-api` locally
```
docker run -p 8081:8081 ghcr.io/bots-house/docker-telegram-bot-api:latest --local --api-id="$API_ID" --api-hash="$API_HASH" --max-webhook-connections=100000 --verbosity=2
```
Read [this](https://core.telegram.org/api/obtaining_api_id#obtaining-api-id) to get your API_ID and API_HASH

2. Install required package
```
sudo apt-get update
sudo apt-get install postgresql-client parallel
```
3. Adjust variables inside the script
```
TG_API_SERVER="http://localhost:8081"
TG_BOT_TOKEN="${2:-xxx:abcd}" # xxx:abcd being your bot token
TG_CHAT_ID="-1001234" # see notes
MAX_PART_SIZE=2097152000 # 2GB in bytes
DB_CONNECTION_STRING="postgres://username:password@host:port/database" # use the same as Teldrive
TELDRIVE_USER_ID="12345" # see notes
TELDRIVE_PARENT_ID="1a2b3c4d" # see notes
LOG_FILE="upload.sh.log"
```
Note: run following SQL statement on your Teldrive database to get `TG_CHAT_ID` (channel_id), `TELDRIVE_USER_ID` (user_id) and `TELDRIVE_PARENT_ID` (parent_id).
This will help you get the values needed to upload to the root directory. Make sure you have at least one file in the root directory. 
```
SELECT distinct concat(-100, channel_id), user_id, parent_id FROM files WHERE TYPE = 'file' and parent_id = (SELECT id FROM files WHERE parent_id = 'root')
```

Usage
---
- Upload single file
  ```
  teldrive-upload.sh '/path/to/file'
  ```
- Upload multiple file within a directory recursively. The directory structure WILL NOT be perserved
  ```
  find /path/to/directory -type f | parallel -j 4 teldrive-upload.sh "{}"
  ```
- If you supply `TG_BOT_TOKEN` as the second argument to the script, it will be used instead of the one you specify inside the script. You can use it to upload using multiple bot token to avoid getting a failed upload.

  Example: command.txt
  ```
  teldrive-upload.sh '/path/to/file1' BOT:TOKEN1
  teldrive-upload.sh '/path/to/file2' BOT:TOKEN2
  teldrive-upload.sh '/path/to/file3' BOT:TOKEN3
  teldrive-upload.sh '/path/to/file4' BOT:TOKEN4
  ```
  Run it like this
  ```
  cat command.txt | parallel -j 4 {}
  ```
Tested on `Ubuntu 22.04.2 LTS` running on Google Colab

Thanks to @[divyam234](https://github.com/divyam234) for his creation of [Teldrive](https://github.com/divyam234/teldrive).

Join Discord channel for Teldrive [here](https://discord.gg/J2gVAZnHfP).
