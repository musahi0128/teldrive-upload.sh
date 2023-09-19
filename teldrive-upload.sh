#!/bin/bash

# Set variables
TG_API_SERVER="http://localhost:8081"
TG_BOT_TOKEN="${2:-##########:###################################}"
TG_CHAT_ID="##########"
MAX_PART_SIZE=2097152000 # 2GB in bytes
DB_CONNECTION_STRING="postgres://##########:############@#################################################/######"
TELDRIVE_USER_ID="##########"
TELDRIVE_PARENT_ID="################"
LOG_FILE="upload.sh.log"

# Constants
FILE_PATH="$1"
RESPONSE_FILE=$(mktemp)
UPLOAD_UID=$(cat /proc/sys/kernel/random/uuid | cut -d- -f5)

echo "$UPLOAD_UID: $(date --rfc-3339='seconds'): Working on $FILE_PATH" >> "$LOG_FILE"

# Function to upload a file and get the message ID
upload_file() {
  local FILE="$1"

  echo "$UPLOAD_UID: $(date --rfc-3339='seconds'): Uploading files: $FILE" >> "$LOG_FILE"
  
  curl_response=$(curl -s -X POST -H "Content-Type: multipart/form-data" -F "chat_id=$TG_CHAT_ID" -F "document=@$FILE" "$TG_API_SERVER/bot$TG_BOT_TOKEN/sendDocument" 2>> "$LOG_FILE")
  
  # Extract and store the message ID
  message_id=$(echo "$curl_response" | jq -r '.result.message_id')
  while [ "$message_id" == 'null' ]; do echo "$UPLOAD_UID: $(date --rfc-3339='seconds'): Upload for $FILE is failed. Retrying"; sleep 5; message_id=$(echo "$curl_response" | jq -r '.result.message_id'); done
  echo "{\"id\": $message_id}" > "$RESPONSE_FILE"
}

# Function to insert information into PostgreSQL
insert_into_db() {
  local FILE_NAME="$1"
  local MIME_TYPE="$2"
  local FILE_SIZE="$3"
  
  psql "$DB_CONNECTION_STRING" <<EOF
  INSERT INTO teldrive.files (name, type, mime_type, path, size, starred, depth, user_id, parent_id, status, channel_id, parts, created_at, updated_at)
  VALUES ('$FILE_NAME', 'file', '$MIME_TYPE', '/', $FILE_SIZE, 'f', 0, '$TELDRIVE_USER_ID', '$TELDRIVE_PARENT_ID', 'active', '$TG_CHAT_ID', '$PARTS', NOW(), NOW());
EOF
}

# Create a temporary directory for split files
temp_dir=$(mktemp -d)

# Split the file if it exceeds MAX_PART_SIZE
if [ $(stat -c %s "$FILE_PATH") -gt $MAX_PART_SIZE ]; then
  echo "$UPLOAD_UID: $(date --rfc-3339='seconds'): Splitting the file into smaller parts" >> "$LOG_FILE"
  
  split -d -b $MAX_PART_SIZE "$FILE_PATH" "$temp_dir/$(basename "$FILE_PATH").0"

  PARTS="["

  SAVEIFS=$IFS
  IFS=$(echo -en "\n\b")
  for part_file in "$temp_dir"/*; do
    upload_file "$part_file"
    PARTS="$PARTS$(cat $RESPONSE_FILE),"
    rm "$part_file"
  done
  IFS=$SAVEIFS
  
  PARTS="${PARTS%,}]"
  
else
  PARTS="["
  upload_file "$FILE_PATH" "1"
  PARTS="$PARTS$(cat $RESPONSE_FILE)"
  PARTS="$PARTS]"
fi

# Determine MIME type
file_extension="${FILE_PATH##*.}"
case $file_extension in
  gz) MIME_TYPE="application/gzip";;
  pdf) MIME_TYPE="application/pdf";;
  zip) MIME_TYPE="application/zip";;
  mp3) MIME_TYPE="audio/mpeg";;
  sub) MIME_TYPE="image/vnd.dvb.subtitle";;
  txt|log|env|conf|srt|ass|vtt) MIME_TYPE="text/plain";;
  mp4) MIME_TYPE="video/mp4";;
  mkv) MIME_TYPE="video/webm";;
  *) MIME_TYPE="application/octet-stream";;
esac

# Get file information
FILE_NAME=$(basename "$FILE_PATH")
FILE_SIZE=$(stat -c %s "$FILE_PATH")

# Insert information into the database
echo "$UPLOAD_UID: $(date --rfc-3339='seconds'): Updating database $(insert_into_db "$FILE_NAME" "$MIME_TYPE" "$FILE_SIZE")" >> "$LOG_FILE"

# Cleanup
rm -rf "$temp_dir" "$RESPONSE_FILE"

echo "$UPLOAD_UID: $(date --rfc-3339='seconds'): File upload and database update for $FILE_PATH has been completed." >> "$LOG_FILE"
