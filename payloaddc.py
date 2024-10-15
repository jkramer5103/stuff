import sys
import subprocess
import discord
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
import hashlib

password_right = False

def derive_key(password, salt):
    kdf = Scrypt(
        salt=salt,
        length=32,
        n=2**14,
        r=8,
        p=1,
        backend=default_backend()
    )
    key = kdf.derive(password.encode())
    return key



def hash_string(input_string):
    # SHA-256 Hash erzeugen
    sha256_hash = hashlib.sha256()
    sha256_hash.update(input_string.encode('utf-8'))
    return sha256_hash.hexdigest()

hashed_passwd = "58739f701f1f3b0f135e8a9e2c4a450eb180ceb0aab301c9bb21e23ec4abcebf"

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
    global password_right
    if password_right:
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
    global password_right
    if password_right:
        await interaction.response.send_message("Fahre den Computer herunter...")
        system("shutdown /s /t 0 /f")

# Command zum Entsperren der Commands mit Passworteingabe
@tree.command(
    name="password",
    description="Passworteingabe zum Entsperren der Commands",
    guild=discord.Object(id=1220080097370046607)
)
async def password_command(interaction, password: str): # hier habe ich die Benutzereingabe hinzugefügt
    if hash_string(password) == hashed_passwd:
        await interaction.response.send_message("Passwort Richtig")
        global password_right
        password_right = True
    else:
        await interaction.response.send_message("Falsches Passwort!")

# Command zum Herunterfahren des Computers
@tree.command(
    name="resetpassword",
    description="Resettet das Passwort",
    guild=discord.Object(id=1220080097370046607)
)
async def resetpasswd(interaction):
    await interaction.response.send_message("Passwort Resettet")
    global password_right
    password_right = False

if len(sys.argv) > 1:
    argument = sys.argv[1]
    print(f"Das übergebene Argument ist: {argument}")
else:
    sys.exit()
token = decrypt_string(argument, "pEt0ACzUovE+6Jcxb5idaoU6kOMaYzWzd8R6VGoU3UhimrGfRU+rdqTBMLgVcWVdJpFJr1xx0n8xGtTPLX3xbsF2BsZowt4x53RYeofblYZmwEq+4gOCqbXLPIVBQKzg4M2JLD1J4GHBqTPcp6Qmcw==")
if token == "err":
    sys.exit()

# Bot starten
client.run(token)
