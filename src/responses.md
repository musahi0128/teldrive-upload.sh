Certainly! Below is a Bash script that performs the tasks you described:

```bash
#!/bin/bash

# Set variables
CHAT_ID="##########"
TG_API_SERVER="http://localhost:8081"
TG_BOT_TOKEN="##############################################"
FILE_PATH="$1"
MAX_PART_SIZE=10485760  # 10MB
DB_HOST="your_db_host"
DB_PORT="your_db_port"
DB_USER="your_db_user"
DB_PASSWORD="your_db_password"
DB_NAME="your_db_name"
DB_TABLE="your_db_table"
USER_ID="your_user_id"
PARENT_ID="your_parent_id"
LOG_FILE="upload_log.txt"

# Function to upload a file and get the message ID
upload_file() {
  local FILE="$1"
  local PART_NUMBER="$2"
  local RESPONSE_FILE="response.json"
  
  echo "Uploading part $PART_NUMBER of the file: $FILE" >> "$LOG_FILE"
  
  curl_response=$(curl -X POST -H "Content-Type: multipart/form-data" -F "CHAT_ID=$CHAT_ID" -F "document=@$FILE" "$TG_API_SERVER/bot$TG_BOT_TOKEN/sendDocument" 2>> "$LOG_FILE")
  
  # Extract and store the message ID
  message_id=$(echo "$curl_response" | jq -r '.result.message_id')
  echo "{\"id\":\"$PART_NUMBER\",\"message_id\":\"$message_id\"}" > "$RESPONSE_FILE"
}

# Function to insert information into PostgreSQL
insert_into_db() {
  local FILE_NAME="$1"
  local MIME_TYPE="$2"
  local FILE_SIZE="$3"
  
  echo "Inserting information into the database" >> "$LOG_FILE"
  
  psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<EOF
  INSERT INTO "$DB_TABLE" (name, type, mime_type, path, size, starred, depth, user_id, parent_id, status, channel_id, parts, created_at, updated_at)
  VALUES ('$FILE_NAME', 'file', '$MIME_TYPE', '/', $FILE_SIZE, 'f', 0, '$USER_ID', '$PARENT_ID', 'active', '$CHAT_ID', '$PARTS', NOW(), NOW());
EOF
}

# Create a temporary directory for split files
temp_dir=$(mktemp -d)

# Split the file if it exceeds MAX_PART_SIZE
if [ $(stat -c %s "$FILE_PATH") -gt $MAX_PART_SIZE ]; then
  echo "Splitting the file into smaller parts" >> "$LOG_FILE"
  
  split -b $MAX_PART_SIZE "$FILE_PATH" "$temp_dir/part"

  PARTS="["

  for part_file in "$temp_dir"/*; do
    part_number=$(basename "$part_file")
    upload_file "$part_file" "$part_number"
    PARTS="$PARTS$(cat response.json),"
    rm "$part_file"
  done

  PARTS="${PARTS%,}]"
  
else
  PARTS="["
  upload_file "$FILE_PATH" "1"
  PARTS="$PARTS$(cat response.json)"
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
insert_into_db "$FILE_NAME" "$MIME_TYPE" "$FILE_SIZE"

# Cleanup
rm -rf "$temp_dir"

echo "Upload and database insertion completed" >> "$LOG_FILE"
```

Make sure to replace the placeholders for your PostgreSQL database credentials and other custom values as needed. Save this script to a file, give it execute permission (`chmod +x script.sh`), and then you can run it with the file path as an argument:

```bash
./script.sh /path/to/your/file.extension
```

The script will upload the file, split it if necessary, insert information into the PostgreSQL database, and log all the verbose output to the specified `LOG_FILE`.
