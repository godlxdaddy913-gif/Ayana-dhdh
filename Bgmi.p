import telebot
import subprocess
import requests
import datetime
import os
import re

bot = telebot.TeleBot("8652411411:AAEd2NjVOSAPUcfRMMp02MgXv76Kznb6VU4")

ADMIN_IDS = ["7178871598"]
USER_FILE = "users.txt"
LOG_FILE = "log.txt"
FREE_USER_FILE = "free_users.txt"

# Initialize global storage
free_user_credits = {}
user_approval_expiry = {}

def read_users():
    if os.path.exists(USER_FILE):
        with open(USER_FILE, "r") as file:
            return file.read().splitlines()
    return []

def read_free_users():
    if os.path.exists(FREE_USER_FILE):
        with open(FREE_USER_FILE, "r") as file:
            for line in file:
                parts = line.split()
                if len(parts) == 2:
                    free_user_credits[parts[0]] = int(parts[1])

allowed_user_ids = read_users()
read_free_users()

def set_approval_expiry_date(user_id, duration, unit):
    current_time = datetime.datetime.now()
    units = {
        'hour': 'hours', 'hours': 'hours',
        'day': 'days', 'days': 'days',
        'week': 'weeks', 'weeks': 'weeks',
        'month': 'days' # Handled separately
    }
    
    unit = unit.lower()
    if unit not in units:
        return False
    
    if 'month' in unit:
        expiry_date = current_time + datetime.timedelta(days=30 * duration)
    else:
        delta_kwargs = {units[unit]: duration}
        expiry_date = current_time + datetime.timedelta(**delta_kwargs)
    
    user_approval_expiry[user_id] = expiry_date
    
    # Persist to users.txt
    if user_id not in allowed_user_ids:
        allowed_user_ids.append(user_id)
        with open(USER_FILE, "a") as f:
            f.write(f"{user_id}\n")
    return True

@bot.message_handler(commands=['add'])
def add_user(message):
    user_id = str(message.chat.id)
    if user_id not in ADMIN_IDS:
        bot.reply_to(message, "❌ Unauthorized access.")
        return

    command = message.text.split()
    if len(command) < 3:
        bot.reply_to(message, "Usage: /add <user_id> <duration><unit>\nExample: /add 12345 2days")
        return

    target_user_id = command[1]
    duration_raw = command[2]

    # Improved parsing using regex
    match = re.match(r"(\d+)([a-zA-Z]+)", duration_raw)
    if not match:
        bot.reply_to(message, "Invalid format. Use e.g., '1hour', '2days'.")
        return

    duration = int(match.group(1))
    unit = match.group(2).lower()

    if set_approval_expiry_date(target_user_id, duration, unit):
        expiry_str = user_approval_expiry[target_user_id].strftime('%Y-%m-%d %H:%M:%S')
        bot.reply_to(message, f"✅ User {target_user_id} added.\nExpiry: {expiry_str}")
    else:
        bot.reply_to(message, "Invalid time unit. Use hour, day, week, or month.")

@bot.message_handler(commands=['clearlogs'])
def clear_logs_handler(message):
    if str(message.chat.id) in ADMIN_IDS:
        if os.path.exists(LOG_FILE):
            open(LOG_FILE, 'w').close()
            bot.reply_to(message, "Logs cleared successfully ✅")
        else:
            bot.reply_to(message, "No logs found.")
    else:
        bot.reply_to(message, "❌ Admin only command.")

if __name__ == "__main__":
    bot.polling(none_stop=True)
