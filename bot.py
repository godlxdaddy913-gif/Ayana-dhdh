import subprocess
import time
import os
import sys

def restart_bot():
    # Get the current directory and script path
    current_directory = os.path.dirname(os.path.abspath(__file__))
    script_path = os.path.join(current_directory, 'm.py')

    while True:
        try:
            print(f"Starting bot: {script_path}")
            # sys.executable uses the current Python interpreter
            subprocess.run([sys.executable, script_path], check=True)
        except subprocess.CalledProcessError as e:
            print(f'Bot crashed (Exit Code {e.returncode}). Restarting in 5s...')
            time.sleep(5)
        except KeyboardInterrupt:
            print("Restarter stopped by user.")
            break
        except Exception as e:
            print(f"Unexpected error: {e}")
            time.sleep(5)

if __name__ == "__main__":
    restart_bot()
