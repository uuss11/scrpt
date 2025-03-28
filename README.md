#ممشفر لأن راح يرفعه شخص أمان اسمه محمد 🙂❤️‍

from flask import Flask, render_template_string, request, redirect, url_for, session
from flask_socketio import SocketIO, emit
import sqlite3
import os

app = Flask(__name__)
app.secret_key = "supersecretkey"

socketio = SocketIO(app)

if not os.path.exists("users.db"):
    conn = sqlite3.connect("users.db")
    c = conn.cursor()
    c.execute('''CREATE TABLE users (id INTEGER PRIMARY KEY, username TEXT UNIQUE, password TEXT, profile_pic TEXT)''')
    conn.commit()
    conn.close()

login_page = """
<!DOCTYPE html>
<html>
<head>
    <title>Login</title>
</head>
<body>
    <h1>Login</h1>
    <form method="POST" action="{{ url_for('login') }}">
        <input type="text" name="username" placeholder="Username" required><br>
        <input type="password" name="password" placeholder="Password" required><br>
        <button type="submit">Login</button>
    </form>
    <p>Don't have an account? <a href="{{ url_for('register') }}">Register here</a></p>
    {% if error %}
    <p style="color:red;">{{ error }}</p>
    {% endif %}
</body>
</html>
"""

register_page = """
<!DOCTYPE html>
<html>
<head>
    <title>Register</title>
</head>
<body>
    <h1>Register</h1>
    <form method="POST" action="{{ url_for('register') }}" enctype="multipart/form-data">
        <input type="text" name="username" placeholder="Username" required><br>
        <input type="password" name="password" placeholder="Password" required><br>
        <input type="file" name="profile_pic" accept="image/*" required><br>
        <button type="submit">Register</button>
    </form>
    <p>Already have an account? <a href="{{ url_for('login') }}">Login here</a></p>
    {% if error %}
    <p style="color:red;">{{ error }}</p>
    {% endif %}
</body>
</html>
"""

chat_page = """
<!DOCTYPE html>
<html>
<head>
    <title>Chat</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background-color: #f4f4f9;
            margin: 0;
            padding: 0;
        }
        #chat-container {
            max-width: 600px;
            margin: 50px auto;
            padding: 20px;
            background: #fff;
            border-radius: 8px;
            box-shadow: 0 0 10px rgba(0, 0, 0, 0.1);
        }
        #messages {
            list-style: none;
            padding: 0;
            height: 300px;
            overflow-y: scroll;
            border: 1px solid #ddd;
            border-radius: 8px;
            padding: 10px;
            margin-bottom: 10px;
        }
        #messages li {
            display: flex;
            align-items: center;
            padding: 10px;
            margin-bottom: 5px;
            border-radius: 8px;
            background-color: #d6eaff;
        }
        .self {
            background-color: #d1ffd6;
            text-align: right;
            justify-content: flex-end;
        }
        .profile-pic {
            width: 40px;
            height: 40px;
            border-radius: 50%;
            margin-right: 10px;
        }
        form {
            display: flex;
            gap: 10px;
        }
        input {
            flex: 1;
            padding: 10px;
            border: 1px solid #ddd;
            border-radius: 8px;
        }
        button {
            padding: 10px 20px;
            border: none;
            background-color: #5cb85c;
            color: #fff;
            border-radius: 8px;
            cursor: pointer;
        }
    </style>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/socket.io/4.0.1/socket.io.js"></script>
    <script>
        document.addEventListener("DOMContentLoaded", () => {
            const socket = io();
            const messages = document.getElementById("messages");
            const form = document.getElementById("chat-form");
            const input = document.getElementById("message");

            form.addEventListener("submit", (e) => {
                e.preventDefault();
                const msg = input.value;
                if (msg) {
                    socket.emit("send_message", { username: "{{ session['username'] }}", profile_pic: "{{ session['profile_pic'] }}", message: msg });
                    input.value = "";
                }
            });

            socket.on("receive_message", (data) => {
                const item = document.createElement("li");
                item.className = data.username === "{{ session['username'] }}" ? "self" : "other";
                item.innerHTML = `<img src="${data.profile_pic}" class="profile-pic"> <b>${data.username}:</b> ${data.message}`;
                messages.appendChild(item);
                messages.scrollTop = messages.scrollHeight;
            });
        });
    </script>
</head>
<body>
    <div id="info-bar">
    <p id="changing-text">رضا تلي: @lJJ2l | محمد تلي: @M_82S | شراكة</p>
</div>
<style>
    #info-bar {
        text-align: center;
        font-size: 18px;
        font-weight: bold;
        padding: 10px;
        animation: colorChange 1s infinite;
    }
    @keyframes colorChange {
        0% { color: red; }
        25% { color: blue; }
        50% { color: green; }
        75% { color: orange; }
        100% { color: purple; }
    }
</style>
        <h1>Chat Room</h1>
        <ul id="messages"></ul>
        <form id="chat-form">
            <input id="message" placeholder="Type your message here..." autocomplete="off">
            <button type="submit">Send</button>
        </form>
    </div>
</body>
</html>
"""

@app.route("/", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        username = request.form["username"]
        password = request.form["password"]
        conn = sqlite3.connect("users.db")
        c = conn.cursor()
        c.execute("SELECT * FROM users WHERE username = ? AND password = ?", (username, password))
        user = c.fetchone()
        conn.close()

        if user:
            session["username"] = username
            session["profile_pic"] = user[3]
            return redirect(url_for("chat"))
        else:
            return render_template_string(login_page, error="Invalid username or password.")

    return render_template_string(login_page, error=None)

@app.route("/register", methods=["GET", "POST"])
def register():
    if request.method == "POST":
        username = request.form["username"]
        password = request.form["password"]
        profile_pic = request.files["profile_pic"]
        
        if profile_pic:
            pic_path = f"static/{username}.png"
            profile_pic.save(pic_path)
        else:
            pic_path = "static/default.png"

        try:
            conn = sqlite3.connect("users.db")
            c = conn.cursor()
            c.execute("INSERT INTO users (username, password, profile_pic) VALUES (?, ?, ?)", (username, password, pic_path))
            conn.commit()
            conn.close()
            return redirect(url_for("login"))
        except sqlite3.IntegrityError:
            return render_template_string(register_page, error="Username already exists.")

    return render_template_string(register_page, error=None)

@app.route("/chat")
def chat():
    if "username" not in session:
        return redirect(url_for("login"))
    return render_template_string(chat_page)

@socketio.on("send_message")
def handle_message(data):
    emit("receive_message", data, broadcast=True)

if __name__ == "__main__":
    if not os.path.exists("static"):
        os.mkdir("static")
    socketio.run(app, debug=False)
