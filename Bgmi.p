#!/usr/bin/python3

import telebot
import subprocess
import requests
import datetime
import os
import re

# insert your Telegram bot token here
bot = telebot.TeleBot("8652411411:AAEd2NjVOSAPUcfRMMp02MgXv76Kznb6VU4")

# Admin user IDs
admin_id = ["7178871598"]

# File to store allowed user IDs
USER_FILE = "users.txt"
LOG_FILE = "log.txt"
FREE_USER_FILE = "free_users.txt"

# Initialize global dictionaries
free_user_credits = {}
user_approval_expiry = {}
bgmi_cooldown = {}
COOLDOWN_TIME = 60 # Set a default cooldown in seconds

def read_users():
    try:
        if os.path.exists(USER_FILE):
            with open(USER_FILE, "r") as file:
                return file.read().splitlines()
    except Exception as e:
        print(f"Error reading users: {e}")
    return []

def read_free_users():
    global free_user_credits
    try:
        if os.path.exists(FREE_USER_FILE):
            with open(FREE_USER_FILE, "r") as file:
                for line in file:
                    if line.strip():
                        user_info = line.split()
                        if len(user_info) == 2:
                            user_id, credits = user_info
                            free_user_credits[user_id] = int(credits)
    except Exception as e:
        print(f"Error reading free users: {e}")

# Load data at startup
allowed_user_ids = read_users()
read_free_users()

def log_command(user_id, target, port, time):
    try:
        user_info = bot.get_chat(user_id)
        username = "@" + user_info.username if user_info.username else f"UserID: {user_id}"
        with open(LOG_FILE, "a") as file:
            file.write(f"Username: {username}\nTarget: {target}\nPort: {port}\nTime: {time}\n\n")
    except Exception as e:
        print(f"Logging error: {e}")

def record_command_logs(user_id, command, target=None, port=None, time=None):
    log_entry = f"UserID: {user_id} | Time: {datetime.datetime.now()} | Command: {command}"
    if target: log_entry += f" | Target: {target}"
    if port: log_entry += f" | Port: {port}"
    if time: log_entry += f" | Time: {time}"
    with open(LOG_FILE, "a") as file:
        file.write(log_entry + "\n")

def get_remaining_approval_time(user_id):
    expiry_date = user_approval_expiry.get(user_id)
    if expiry_date:
        remaining_time = expiry_date - datetime.datetime.now()
        return "Expired" if remaining_time.total_seconds() < 0 else str(remaining_time).split('.')[0]
    return "N/A"

def set_approval_expiry_date(user_id, duration, time_unit):
    current_time = datetime.datetime.now()
    units = {
        'hour': 'hours', 'hours': 'hours',
        'day': 'days', 'days': 'days',
        'week': 'weeks', 'weeks': 'weeks',
        'month': 'days', 'months': 'days'
    }
    
    if time_unit not in units:
        return False
    
    val = 30 * duration if "month" in time_unit else duration
    delta = datetime.timedelta(**{units[time_unit]: val})
    user_approval_expiry[user_id] = current_time + delta
    return True

@bot.message_handler(commands=['add'])
def add_user(message):
    user_id = str(message.chat.id)
    if user_id in admin_id:
        command = message.text.split()
        if len(command) > 2:
            user_to_add = command[1]
            duration_raw = command[2]
            
            # Robust parsing using regex
            match = re.match(r"(\d+)([a-zA-Z]+)", duration_raw)
            if not match:
                bot.reply_to(message, "Invalid format. Use e.g., 1hour, 2days.")
                return
                
            duration = int(match.group(1))
            time_unit = match.group(2).lower()

            if user_to_add not in allowed_user_ids:
                allowed_user_ids.append(user_to_add)
                with open(USER_FILE, "a") as file:
                    file.write(f"{user_to_add}\n")
                
                if set_approval_expiry_date(user_to_add, duration, time_unit):
                    response = f"User {user_to_add} added. Expires: {user_approval_expiry[user_to_add].strftime('%Y-%m-%d %H:%M:%S')}"
                else:
                    response = "Invalid time unit."
            else:
                response = "User already exists."
        else:
            response = "Usage: /add <userid> <duration>"
    else:
        response = "Only Admins can use this."
    bot.reply_to(message, response)

@bot.message_handler(commands=['attack'])
def handle_attack(message):
    user_id = str(message.chat.id)
    if user_id in allowed_user_ids:
        if user_id not in admin_id:
            if user_id in bgmi_cooldown:
                time_passed = (datetime.datetime.now() - bgmi_cooldown[user_id]).total_seconds()
                if time_passed < COOLDOWN_TIME:
                    bot.reply_to(message, f"Wait {int(COOLDOWN_TIME - time_passed)}s.")
                    return
            bgmi_cooldown[user_id] = datetime.datetime.now()
        
        command = message.text.split()
        if len(command) == 4:
            target, port, time = command[1], command[2], int(command[3])
            if time > 1000:
                response = "Time must be < 1000."
            else:
                record_command_logs(user_id, '/attack', target, port, time)
                log_command(user_id, target, port, time)
                bot.reply_to(message, f"Attack Started on {target}:{port}")
                # subprocess.run(...) logic here
                response = f"Attack Finished."
        else:
            response = "Usage: /attack <target> <port> <time>"
    else:
        response = "Unauthorized."
    bot.reply_to(message, response)

@bot.message_handler(commands=['help'])
def show_help(message):
    help_text = "Available commands:\n"
    # Logic to filter admin commands for normal users
    commands = [
        "/attack - Start attack",
        "/myinfo - Check info",
        "/rules - View rules",
        "/plan - View plans"
    ]
    if str(message.chat.id) in admin_id:
        commands.append("/admincmd - Admin commands")
    
    bot.reply_to(message, "\n".join(commands))

# Keep the rest of your handlers (remove, clearlogs, etc.) 
# ensuring they check 'if user_id in admin_id'

bot.infinity_polling(skip_pending=True)
