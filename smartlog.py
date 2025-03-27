import re
import pandas as pd
import numpy as np
import joblib
from collections import Counter
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score
import nltk
from nltk.tokenize import word_tokenize

nltk.download("punkt")

# Define log file path
log_file = "/var/log/syslog"

# Read log file
try:
    with open(log_file, "r") as f:
        logs = f.readlines()
except FileNotFoundError:
    print("Error: Log file not found! Make sure the path is correct.")
    exit()

# Extract timestamps, sources, and messages
log_data = []
for log in logs:
    match = re.match(r"(\w+ \d+ \d+:\d+:\d+) (\S+) (\S+): (.+)", log)
    if match:
        timestamp, host, source, message = match.groups()
        log_data.append([timestamp, source, message])

# Convert logs to a DataFrame
df = pd.DataFrame(log_data, columns=["Timestamp", "Source", "Message"])

# Sample log categories (Training Data)
log_samples = [
    ("System boot successful", "INFO"),
    ("Network disconnected", "WARNING"),
    ("Disk space running low", "WARNING"),
    ("Authentication failed for user root", "ERROR"),
    ("System crash detected", "CRITICAL"),
    ("Firewall detected suspicious activity", "ALERT"),
]

# Convert training data into a DataFrame
train_df = pd.DataFrame(log_samples, columns=["Message", "Category"])

# Feature Extraction using TF-IDF
vectorizer = TfidfVectorizer(tokenizer=word_tokenize, stop_words="english")
X = vectorizer.fit_transform(train_df["Message"])
y = train_df["Category"]

# Train Machine Learning Model (RandomForest for classification)
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
model = RandomForestClassifier(n_estimators=100, random_state=42)
model.fit(X_train, y_train)

# Save trained model
joblib.dump((model, vectorizer), "log_classifier.pkl")

# Load model for prediction
model, vectorizer = joblib.load("log_classifier.pkl")

# Classify log messages
df["Category"] = model.predict(vectorizer.transform(df["Message"]))

# Count log occurrences
top_sources = Counter(df["Source"]).most_common(5)

# Print summary
print("\n🔹 **Top Log Sources:**")
for src, count in top_sources:
    print(f"   {src}: {count} entries")

print(f"\n🔹 **Total Logs Analyzed:** {len(df)}")
print(f"🔴 Errors Found: {len(df[df['Category'] == 'ERROR'])}")
print(f"🟡 Warnings Found: {len(df[df['Category'] == 'WARNING'])}")
print(f"🚨 Critical Alerts: {len(df[df['Category'] == 'CRITICAL'])}")

# Save results to CSV
df.to_csv("ai_log_summary.csv", index=False)

print("\n✅ AI Log Summary saved to 'ai_log_summary.csv'")
