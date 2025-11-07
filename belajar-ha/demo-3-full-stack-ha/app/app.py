#!/usr/bin/env python3

import os
import socket
import psycopg
from flask import Flask, jsonify, request
from datetime import datetime
import time

app = Flask(__name__)

# Configuration - Connect via HAProxy
DB_WRITE_HOST = os.getenv('DB_WRITE_HOST', 'haproxy1')
DB_WRITE_PORT = os.getenv('DB_WRITE_PORT', '6432')
DB_READ_HOST = os.getenv('DB_READ_HOST', 'haproxy1')
DB_READ_PORT = os.getenv('DB_READ_PORT', '6433')
DB_NAME = os.getenv('DB_NAME', 'demodb')
DB_USER = os.getenv('DB_USER', 'postgres')
DB_PASSWORD = os.getenv('DB_PASSWORD', 'postgres')
APP_NAME = socket.gethostname()

def get_instance_color():
    """Get unique gradient colors based on instance hostname"""
    colors = {
        'app1': ('667eea', '764ba2'),  # Purple
        'app2': ('f093fb', '4facfe'),  # Pink to Blue
        'app3': ('43e97b', '38f9d7'),  # Green to Cyan
    }
    # Default gradient if hostname not in map
    default = ('fa709a', 'fee140')  # Pink to Yellow

    # Extract base hostname (app1, app2, etc)
    base_name = APP_NAME.split('.')[0] if '.' in APP_NAME else APP_NAME
    color1, color2 = colors.get(base_name, default)

    return f"linear-gradient(135deg, #{color1} 0%, #{color2} 100%)"

def get_db_connection(for_write=False):
    """
    Get database connection via HAProxy
    - Write operations: route to HAProxy postgres_write (primary)
    - Read operations: route to HAProxy postgres_read (load balanced)
    """
    try:
        host = DB_WRITE_HOST if for_write else DB_READ_HOST
        port = DB_WRITE_PORT if for_write else DB_READ_PORT

        conn = psycopg.connect(
            host=host,
            port=port,
            dbname=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD,
            connect_timeout=3
        )

        return conn, f"{host}:{port}"
    except Exception as e:
        # Fallback to write endpoint if read fails
        if not for_write:
            conn = psycopg.connect(
                host=DB_WRITE_HOST,
                port=DB_WRITE_PORT,
                dbname=DB_NAME,
                user=DB_USER,
                password=DB_PASSWORD,
                connect_timeout=3
            )
            return conn, f"{DB_WRITE_HOST}:{DB_WRITE_PORT} (fallback)"
        raise e

@app.route('/')
def home():
    """Home page with instance info"""
    bg_gradient = get_instance_color()
    return f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>Full Stack HA Demo</title>
        <style>
            body {{
                font-family: Arial, sans-serif;
                max-width: 1200px;
                margin: 50px auto;
                padding: 20px;
                background: {bg_gradient};
                color: white;
            }}
            .container {{
                background: rgba(255,255,255,0.1);
                padding: 30px;
                border-radius: 10px;
                backdrop-filter: blur(10px);
            }}
            h1 {{ margin-top: 0; }}
            .info {{ margin: 15px 0; font-size: 18px; }}
            .endpoint {{
                background: rgba(0,0,0,0.2);
                padding: 10px;
                margin: 10px 0;
                border-radius: 5px;
                font-family: monospace;
            }}
            .button {{
                display: inline-block;
                padding: 10px 20px;
                margin: 10px 5px;
                background: rgba(255,255,255,0.2);
                border: 1px solid white;
                border-radius: 5px;
                color: white;
                text-decoration: none;
                cursor: pointer;
            }}
            .button:hover {{ background: rgba(255,255,255,0.3); }}
            #stats {{ margin-top: 20px; }}
        </style>
        <script>
            function loadStats() {{
                fetch('/api/stats')
                    .then(r => r.json())
                    .then(data => {{
                        document.getElementById('stats').innerHTML =
                            '<pre>' + JSON.stringify(data, null, 2) + '</pre>';
                    }});
            }}
            function addUser() {{
                const name = prompt('Enter name:');
                if (name) {{
                    fetch('/api/users', {{
                        method: 'POST',
                        headers: {{'Content-Type': 'application/json'}},
                        body: JSON.stringify({{name: name, email: name + '@example.com'}})
                    }})
                    .then(r => r.json())
                    .then(data => alert('User added: ' + JSON.stringify(data)))
                    .then(() => loadStats());
                }}
            }}
            setInterval(loadStats, 2000);
            window.onload = loadStats;
        </script>
    </head>
    <body>
        <div class="container">
            <h1>🚀 Full Stack High Availability Demo</h1>
            <div class="info">📦 Application Instance: <strong>{APP_NAME}</strong></div>
            <div class="info">⏰ Server Time: <strong>{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</strong></div>

            <h2>Available Endpoints:</h2>
            <div class="endpoint">GET  /health - Health check</div>
            <div class="endpoint">GET  /api/stats - Database statistics</div>
            <div class="endpoint">GET  /api/users - List all users</div>
            <div class="endpoint">POST /api/users - Create new user</div>

            <div>
                <button class="button" onclick="loadStats()">Refresh Stats</button>
                <button class="button" onclick="addUser()">Add User</button>
                <a href="/api/users" class="button" target="_blank">View Users</a>
            </div>

            <div id="stats">Loading...</div>
        </div>
    </body>
    </html>
    """

@app.route('/health')
def health():
    """Health check endpoint for HAProxy"""
    try:
        # Check database connectivity
        conn, db_host = get_db_connection()
        cur = conn.cursor()
        cur.execute('SELECT 1')
        cur.close()

        return jsonify({
            'status': 'healthy',
            'instance': APP_NAME,
            'timestamp': datetime.now().isoformat(),
            'database': db_host
        }), 200
    except Exception as e:
        return jsonify({
            'status': 'unhealthy',
            'instance': APP_NAME,
            'error': str(e),
            'timestamp': datetime.now().isoformat()
        }), 503

@app.route('/api/stats')
def stats():
    """Get database statistics (read operation)"""
    try:
        conn, db_host = get_db_connection(for_write=False)
        cur = conn.cursor()

        # Get user count
        cur.execute('SELECT COUNT(*) FROM users')
        user_count = cur.fetchone()[0]

        # Check if this is primary or replica
        cur.execute('SELECT pg_is_in_recovery()')
        is_replica = cur.fetchone()[0]

        # Get replication lag if replica
        lag = None
        if is_replica:
            cur.execute("SELECT EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp())) AS lag")
            result = cur.fetchone()
            lag = float(result[0]) if result[0] else 0

        cur.close()
        conn.close()

        return jsonify({
            'app_instance': APP_NAME,
            'database_endpoint': db_host,
            'database_role': 'replica' if is_replica else 'primary',
            'total_users': user_count,
            'replication_lag_seconds': lag,
            'timestamp': datetime.now().isoformat()
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/users', methods=['GET'])
def get_users():
    """Get all users (read from read endpoint)"""
    try:
        conn, db_host = get_db_connection(for_write=False)
        cur = conn.cursor()
        cur.execute('SELECT id, name, email, created_at FROM users ORDER BY id DESC LIMIT 50')
        users = []
        for row in cur.fetchall():
            # psycopg3 returns VARCHAR as bytes, need to decode
            users.append({
                'id': int(row[0]),
                'name': row[1].decode('utf-8') if isinstance(row[1], bytes) else str(row[1]),
                'email': row[2].decode('utf-8') if isinstance(row[2], bytes) else str(row[2]),
                'created_at': row[3].isoformat() if row[3] else None
            })
        cur.close()
        conn.close()

        return jsonify({
            'app_instance': APP_NAME,
            'database_endpoint': db_host,
            'count': len(users),
            'users': users
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/users', methods=['POST'])
def create_user():
    """Create new user (write to write endpoint)"""
    try:
        data = request.get_json()
        name = data.get('name')
        email = data.get('email')

        if not name or not email:
            return jsonify({'error': 'name and email required'}), 400

        conn, db_host = get_db_connection(for_write=True)
        cur = conn.cursor()
        cur.execute(
            'INSERT INTO users (name, email) VALUES (%s, %s) RETURNING id, name, email, created_at',
            (name, email)
        )
        result = cur.fetchone()
        conn.commit()
        cur.close()
        conn.close()

        return jsonify({
            'app_instance': APP_NAME,
            'database_endpoint': db_host,
            'user': {
                'id': int(result[0]),
                'name': result[1].decode('utf-8') if isinstance(result[1], bytes) else str(result[1]),
                'email': result[2].decode('utf-8') if isinstance(result[2], bytes) else str(result[2]),
                'created_at': result[3].isoformat()
            }
        }), 201
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
