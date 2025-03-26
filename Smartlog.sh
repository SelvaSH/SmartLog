#!/bin/bash
# smart_log_analysis.sh

# Define log file path
log_file="/var/log/syslog"

# Check if the log file exists
if [ ! -f "$log_file" ]; then
    echo "Error: Log file not found! Make sure the path is correct."
    exit 1
fi

# Output CSV file names
log_summary="log_summary.csv"
error_logs="error_logs.csv"
warning_logs="warning_logs.csv"

# Write CSV headers
echo "Timestamp,Source,Message" > "$log_summary"
echo "Timestamp,Source,Message" > "$error_logs"
echo "Timestamp,Source,Message" > "$warning_logs"

# Declare associative array for counting sources
declare -A source_counts

# Initialize counters
total=0
errors=0
warnings=0

# Read the log file line by line
while IFS= read -r line; do
    # Use a regex to extract: Timestamp, Host, Source, and Message.
    # Pattern explanation:
    # ^([A-Za-z]{3}\ [0-9]{1,2}\ [0-9]{2}:[0-9]{2}:[0-9]{2}) matches the timestamp (e.g., "Aug 10 14:23:45")
    # \ ([^[:space:]]+) matches the host
    # \ ([^:]+): matches the source (up to the colon)
    # \ (.+)$ matches the rest as the message.
    if [[ $line =~ ^([A-Za-z]{3}\ [0-9]{1,2}\ [0-9]{2}:[0-9]{2}:[0-9]{2})\ ([^[:space:]]+)\ ([^:]+):\ (.+)$ ]]; then
        timestamp="${BASH_REMATCH[1]}"
        host="${BASH_REMATCH[2]}"
        source="${BASH_REMATCH[3]}"
        message="${BASH_REMATCH[4]}"
        
        # Append to log summary CSV (values are quoted)
        echo "\"$timestamp\",\"$source\",\"$message\"" >> "$log_summary"
        
        # Count the occurrence of each source
        ((source_counts["$source"]++))
        ((total++))
        
        # Convert message to lowercase for case-insensitive search
        message_lower=$(echo "$message" | tr '[:upper:]' '[:lower:]')
        if [[ $message_lower == *"error"* ]]; then
            echo "\"$timestamp\",\"$source\",\"$message\"" >> "$error_logs"
            ((errors++))
        elif [[ $message_lower == *"warning"* ]]; then
            echo "\"$timestamp\",\"$source\",\"$message\"" >> "$warning_logs"
            ((warnings++))
        fi
    fi
done < "$log_file"

# Print summary for top 5 sources
echo -e "\n🔹 **Top Log Sources:**"
# Output each source and count, then sort them numerically in descending order, show top 5
for src in "${!source_counts[@]}"; do
    echo "$src,${source_counts[$src]}"
done | sort -t, -k2 -nr | head -n 5 | while IFS=, read -r src count; do
    echo "   ${src}: ${count} entries"
done

# Print overall summary
echo -e "\n🔹 **Total Logs Analyzed:** ${total}"
echo "🔴 Errors Found: ${errors}"
echo "🟡 Warnings Found: ${warnings}"

# Inform user of the CSV files
echo -e "\n✅ Log summary saved to '${log_summary}'"
echo "✅ Error logs saved to '${error_logs}'"
echo "✅ Warning logs saved to '${warning_logs}'"
