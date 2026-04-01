# 首先安装：pip install flask

from flask import Flask

app = Flask(__name__)

@app.route('/')
def hello():
    return 'Hello, World!<br>你好，世界！'

@app.route('/user/<name>')
def greet_user(name):
    return f'Hello, {name}!'

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5009, debug=True)
