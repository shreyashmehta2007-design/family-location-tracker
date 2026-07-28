import os
import uuid
import shutil
import hashlib
import math
import sqlite3
from datetime import datetime, timedelta
from pathlib import Path

from flask import (
    Flask, render_template, request, redirect, url_for,
    send_from_directory, abort, jsonify, flash, session
)
from flask_login import (
    LoginManager, UserMixin, login_user, logout_user,
    login_required, current_user
)
from werkzeug.security import generate_password_hash, check_password_hash
from werkzeug.utils import secure_filename


app = Flask(__name__)
app.secret_key = os.urandom(64)
app.config['MAX_CONTENT_LENGTH'] = 10 * 1024 * 1024 * 1024  # 10GB
app.config['UPLOAD_FOLDER'] = os.path.join(os.path.dirname(__file__), 'data', 'files')
os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)

DB_PATH = os.path.join(os.path.dirname(__file__), 'data', 'cloud.db')

login_manager = LoginManager()
login_manager.init_app(app)
login_manager.login_view = 'login'


def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    conn = get_db()
    conn.executescript('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            storage_quota INTEGER DEFAULT 1073741824,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
        CREATE TABLE IF NOT EXISTS files (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            filename TEXT NOT NULL,
            original_name TEXT NOT NULL,
            path TEXT NOT NULL,
            size INTEGER DEFAULT 0,
            mime_type TEXT DEFAULT 'application/octet-stream',
            is_folder INTEGER DEFAULT 0,
            parent_id INTEGER DEFAULT NULL,
            share_token TEXT UNIQUE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id),
            FOREIGN KEY (parent_id) REFERENCES files(id)
        );
        CREATE TABLE IF NOT EXISTS share_links (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            file_id INTEGER NOT NULL,
            token TEXT UNIQUE NOT NULL,
            password TEXT,
            expires_at TIMESTAMP,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (file_id) REFERENCES files(id)
        );
        CREATE TABLE IF NOT EXISTS families (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            invite_code TEXT UNIQUE NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
        CREATE TABLE IF NOT EXISTS family_members (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            family_id INTEGER NOT NULL,
            user_id INTEGER NOT NULL UNIQUE,
            role TEXT DEFAULT 'member',
            nickname TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (family_id) REFERENCES families(id),
            FOREIGN KEY (user_id) REFERENCES users(id)
        );
        CREATE TABLE IF NOT EXISTS places (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            family_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            radius_meters INTEGER DEFAULT 100,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (family_id) REFERENCES families(id)
        );
        CREATE TABLE IF NOT EXISTS locations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            accuracy REAL DEFAULT 0,
            timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id)
        );
        CREATE TABLE IF NOT EXISTS geofence_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            place_id INTEGER NOT NULL,
            event_type TEXT NOT NULL,
            message TEXT DEFAULT '',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id),
            FOREIGN KEY (place_id) REFERENCES places(id)
        );
    ''')
    conn.commit()
    conn.close()


init_db()


class User(UserMixin):
    def __init__(self, id, username, storage_quota):
        self.id = id
        self.username = username
        self.storage_quota = storage_quota


@login_manager.user_loader
def load_user(user_id):
    conn = get_db()
    user = conn.execute('SELECT * FROM users WHERE id = ?', (user_id,)).fetchone()
    conn.close()
    if user:
        return User(user['id'], user['username'], user['storage_quota'])
    return None


def get_user_storage_used(user_id):
    conn = get_db()
    result = conn.execute(
        'SELECT COALESCE(SUM(size), 0) as total FROM files WHERE user_id = ? AND is_folder = 0',
        (user_id,)
    ).fetchone()
    conn.close()
    return result['total']


def format_size(size):
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if size < 1024:
            return f"{size:.1f} {unit}"
        size /= 1024
    return f"{size:.1f} PB"


def get_file_tree(user_id, parent_id=None):
    conn = get_db()
    files = conn.execute(
        'SELECT * FROM files WHERE user_id = ? AND parent_id IS ? ORDER BY is_folder DESC, filename ASC',
        (user_id, parent_id)
    ).fetchall()
    conn.close()
    return files


@app.route('/')
def index():
    if current_user.is_authenticated:
        return redirect(url_for('dashboard'))
    return redirect(url_for('login'))


@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        conn = get_db()
        user = conn.execute('SELECT * FROM users WHERE username = ?', (username,)).fetchone()
        conn.close()
        if user and check_password_hash(user['password_hash'], password):
            login_user(User(user['id'], user['username'], user['storage_quota']))
            return redirect(url_for('dashboard'))
        flash('Invalid username or password', 'error')
    return render_template('login.html')


@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        username = request.form['username'].strip()
        password = request.form['password']
        if len(username) < 3:
            flash('Username must be at least 3 characters', 'error')
            return render_template('register.html')
        if len(password) < 6:
            flash('Password must be at least 6 characters', 'error')
            return render_template('register.html')
        conn = get_db()
        existing = conn.execute('SELECT id FROM users WHERE username = ?', (username,)).fetchone()
        if existing:
            conn.close()
            flash('Username already exists', 'error')
            return render_template('register.html')
        conn.execute(
            'INSERT INTO users (username, password_hash) VALUES (?, ?)',
            (username, generate_password_hash(password))
        )
        conn.commit()
        conn.close()
        flash('Registration successful! Please log in.', 'success')
        return redirect(url_for('login'))
    return render_template('register.html')


@app.route('/logout')
@login_required
def logout():
    logout_user()
    return redirect(url_for('login'))


@app.route('/dashboard')
@login_required
def dashboard():
    current_path = request.args.get('path', '')
    parent_id = None
    if current_path:
        parent_id = int(current_path)
    files = get_file_tree(current_user.id, parent_id)

    breadcrumbs = []
    if parent_id:
        conn = get_db()
        pid = parent_id
        crumbs = []
        while pid:
            row = conn.execute('SELECT id, filename, parent_id FROM files WHERE id = ? AND user_id = ?',
                             (pid, current_user.id)).fetchone()
            if row:
                crumbs.append({'id': row['id'], 'name': row['filename']})
                pid = row['parent_id']
            else:
                break
        conn.close()
        breadcrumbs = list(reversed(crumbs))

    used = get_user_storage_used(current_user.id)
    quota = current_user.storage_quota
    pct = min(100, int((used / quota) * 100)) if quota else 0

    return render_template('dashboard.html', files=files, breadcrumbs=breadcrumbs,
                         used=used, quota=quota, pct=pct,
                         format_size=format_size, current_path=parent_id)


@app.route('/upload', methods=['POST'])
@login_required
def upload():
    parent_id = request.form.get('parent_id')
    if parent_id == '':
        parent_id = None
    parent_id = int(parent_id) if parent_id else None

    if 'files' not in request.files:
        return jsonify({'error': 'No files provided'}), 400

    files = request.files.getlist('files')
    results = []

    for file in files:
        if file.filename == '':
            continue

        original_name = secure_filename(file.filename)
        size = 0
        file.seek(0, os.SEEK_END)
        size = file.tell()
        file.seek(0)

        used = get_user_storage_used(current_user.id)
        if used + size > current_user.storage_quota:
            results.append({'name': original_name, 'error': 'Storage quota exceeded'})
            continue

        unique_name = f"{uuid.uuid4().hex}_{original_name}"
        filepath = os.path.join(app.config['UPLOAD_FOLDER'], unique_name)
        file.save(filepath)

        mime = file.content_type or 'application/octet-stream'

        conn = get_db()
        conn.execute(
            'INSERT INTO files (user_id, filename, original_name, path, size, mime_type, parent_id) '
            'VALUES (?, ?, ?, ?, ?, ?, ?)',
            (current_user.id, unique_name, original_name, filepath, size, mime, parent_id)
        )
        conn.commit()
        conn.close()
        results.append({'name': original_name, 'size': size, 'status': 'ok'})

    return jsonify({'files': results})


@app.route('/download/<int:file_id>')
@login_required
def download(file_id):
    conn = get_db()
    file = conn.execute(
        'SELECT * FROM files WHERE id = ? AND user_id = ? AND is_folder = 0',
        (file_id, current_user.id)
    ).fetchone()
    conn.close()

    if not file:
        abort(404)

    return send_from_directory(
        os.path.dirname(file['path']),
        os.path.basename(file['path']),
        download_name=file['original_name'],
        as_attachment=True
    )


@app.route('/shared/<token>')
def shared_download(token):
    conn = get_db()
    link = conn.execute('SELECT * FROM share_links WHERE token = ?', (token,)).fetchone()
    if not link:
        conn.close()
        abort(404)

    if link['expires_at']:
        expires = datetime.strptime(link['expires_at'], '%Y-%m-%d %H:%M:%S')
        if datetime.now() > expires:
            conn.close()
            abort(410)

    file = conn.execute('SELECT * FROM files WHERE id = ?', (link['file_id'],)).fetchone()
    conn.close()

    if not file:
        abort(404)

    return send_from_directory(
        os.path.dirname(file['path']),
        os.path.basename(file['path']),
        download_name=file['original_name'],
        as_attachment=True
    )


@app.route('/share/<int:file_id>', methods=['POST'])
@login_required
def share_file(file_id):
    conn = get_db()
    file = conn.execute(
        'SELECT * FROM files WHERE id = ? AND user_id = ?',
        (file_id, current_user.id)
    ).fetchone()
    if not file:
        conn.close()
        abort(404)

    token = uuid.uuid4().hex[:12]
    expires_days = request.json.get('expires_days', 7)
    expires_at = (datetime.now() + timedelta(days=int(expires_days))).strftime('%Y-%m-%d %H:%M:%S')

    conn.execute(
        'INSERT INTO share_links (file_id, token, expires_at) VALUES (?, ?, ?)',
        (file_id, token, expires_at)
    )
    conn.commit()
    conn.close()

    return jsonify({'token': token, 'url': url_for('shared_download', token=token, _external=True)})


@app.route('/delete', methods=['POST'])
@login_required
def delete():
    data = request.get_json()
    file_ids = data.get('file_ids', [])
    conn = get_db()
    for fid in file_ids:
        file = conn.execute(
            'SELECT * FROM files WHERE id = ? AND user_id = ?',
            (fid, current_user.id)
        ).fetchone()
        if file:
            if file['is_folder']:
                children = conn.execute(
                    'SELECT id FROM files WHERE parent_id = ? AND user_id = ?',
                    (fid, current_user.id)
                ).fetchall()
                for child in children:
                    file2 = conn.execute(
                        'SELECT * FROM files WHERE id = ? AND user_id = ?',
                        (child['id'], current_user.id)
                    ).fetchone()
                    if file2 and not file2['is_folder'] and os.path.exists(file2['path']):
                        os.remove(file2['path'])
                    conn.execute('DELETE FROM files WHERE id = ? AND user_id = ?',
                               (child['id'], current_user.id))
                conn.execute('DELETE FROM files WHERE id = ? AND user_id = ?',
                           (fid, current_user.id))
            else:
                if os.path.exists(file['path']):
                    os.remove(file['path'])
                conn.execute('DELETE FROM share_links WHERE file_id = ?', (fid,))
                conn.execute('DELETE FROM files WHERE id = ? AND user_id = ?',
                           (fid, current_user.id))
    conn.commit()
    conn.close()
    return jsonify({'status': 'ok'})


@app.route('/mkdir', methods=['POST'])
@login_required
def mkdir():
    data = request.get_json()
    name = secure_filename(data.get('name', ''))
    parent_id = data.get('parent_id')
    parent_id = int(parent_id) if parent_id else None

    if not name:
        return jsonify({'error': 'Folder name required'}), 400

    conn = get_db()
    existing = conn.execute(
        'SELECT id FROM files WHERE user_id = ? AND filename = ? AND parent_id IS ? AND is_folder = 1',
        (current_user.id, name, parent_id)
    ).fetchone()
    if existing:
        conn.close()
        return jsonify({'error': 'Folder already exists'}), 400

    conn.execute(
        'INSERT INTO files (user_id, filename, original_name, path, is_folder, parent_id) '
        'VALUES (?, ?, ?, ?, 1, ?)',
        (current_user.id, name, name, '', parent_id)
    )
    conn.commit()
    conn.close()
    return jsonify({'status': 'ok', 'name': name})


@app.route('/preview/<int:file_id>')
@login_required
def preview(file_id):
    conn = get_db()
    file = conn.execute(
        'SELECT * FROM files WHERE id = ? AND user_id = ? AND is_folder = 0',
        (file_id, current_user.id)
    ).fetchone()
    conn.close()
    if not file:
        abort(404)
    ext = os.path.splitext(file['original_name'])[1].lower()
    previewable = ext in ('.jpg', '.jpeg', '.png', '.gif', '.svg', '.webp', '.txt', '.md', '.pdf')
    if previewable:
        return send_from_directory(
            os.path.dirname(file['path']),
            os.path.basename(file['path'])
        )
    return redirect(url_for('download', file_id=file_id))


# --- Family Location Tracker ---

def haversine(lat1, lon1, lat2, lon2):
    R = 6371000
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi/2)**2 + math.cos(phi1)*math.cos(phi2)*math.sin(dlambda/2)**2
    return 2 * R * math.atan2(math.sqrt(a), math.sqrt(1-a))


def check_geofences(user_id, latitude, longitude):
    conn = get_db()
    user = conn.execute('SELECT username FROM users WHERE id = ?', (user_id,)).fetchone()
    member = conn.execute('SELECT family_id, nickname FROM family_members WHERE user_id = ?', (user_id,)).fetchone()
    if not member:
        conn.close()
        return
    family_id = member['family_id']
    nickname = member['nickname'] or user['username']
    places = conn.execute('SELECT * FROM places WHERE family_id = ?', (family_id,)).fetchall()
    for place in places:
        dist = haversine(latitude, longitude, place['latitude'], place['longitude'])
        last_event = conn.execute(
            'SELECT event_type FROM geofence_events WHERE user_id = ? AND place_id = ? ORDER BY created_at DESC LIMIT 1',
            (user_id, place['id'])
        ).fetchone()
        was_inside = last_event is not None and last_event['event_type'] == 'enter'
        is_inside = dist <= place['radius_meters']
        events = []
        if is_inside and not was_inside:
            message = f"{nickname} has reached {place['name']}"
            conn.execute(
                'INSERT INTO geofence_events (user_id, place_id, event_type, message) VALUES (?, ?, ?, ?)',
                (user_id, place['id'], 'enter', message)
            )
            events.append(message)
        elif not is_inside and was_inside:
            message = f"{nickname} has left {place['name']}"
            conn.execute(
                'INSERT INTO geofence_events (user_id, place_id, event_type, message) VALUES (?, ?, ?, ?)',
                (user_id, place['id'], 'leave', message)
            )
            events.append(message)
    conn.commit()
    conn.close()


@app.route('/family')
@login_required
def family_page():
    member = None
    conn = get_db()
    member = conn.execute(
        'SELECT fm.*, f.name as family_name, f.invite_code FROM family_members fm JOIN families f ON f.id = fm.family_id WHERE fm.user_id = ?',
        (current_user.id,)
    ).fetchone()
    conn.close()
    if not member:
        return render_template('family_settings.html')
    return render_template('family_dashboard.html', member=member)


@app.route('/family/settings')
@login_required
def family_settings():
    conn = get_db()
    member = conn.execute(
        'SELECT fm.*, f.name as family_name, f.invite_code FROM family_members fm JOIN families f ON f.id = fm.family_id WHERE fm.user_id = ?',
        (current_user.id,)
    ).fetchone()
    members = []
    if member:
        members = conn.execute(
            'SELECT fm.*, u.username FROM family_members fm JOIN users u ON u.id = fm.user_id WHERE fm.family_id = ?',
            (member['family_id'],)
        ).fetchall()
    conn.close()
    return render_template('family_settings.html', member=member, members=members)


@app.route('/api/family/create', methods=['POST'])
@login_required
def create_family():
    conn = get_db()
    existing = conn.execute('SELECT id FROM family_members WHERE user_id = ?', (current_user.id,)).fetchone()
    if existing:
        conn.close()
        return jsonify({'error': 'Already in a family'}), 400
    name = request.json.get('name', '').strip()
    if not name:
        return jsonify({'error': 'Family name required'}), 400
    invite_code = uuid.uuid4().hex[:6].upper()
    conn.execute('INSERT INTO families (name, invite_code) VALUES (?, ?)', (name, invite_code))
    family_id = conn.execute('SELECT last_insert_rowid()').fetchone()[0]
    conn.execute(
        'INSERT INTO family_members (family_id, user_id, role) VALUES (?, ?, ?)',
        (family_id, current_user.id, 'admin')
    )
    conn.commit()
    conn.close()
    return jsonify({'status': 'ok', 'invite_code': invite_code})


@app.route('/api/family/join', methods=['POST'])
@login_required
def join_family():
    conn = get_db()
    existing = conn.execute('SELECT id FROM family_members WHERE user_id = ?', (current_user.id,)).fetchone()
    if existing:
        conn.close()
        return jsonify({'error': 'Already in a family'}), 400
    invite_code = request.json.get('invite_code', '').strip().upper()
    family = conn.execute('SELECT id, name FROM families WHERE invite_code = ?', (invite_code,)).fetchone()
    if not family:
        conn.close()
        return jsonify({'error': 'Invalid invite code'}), 404
    conn.execute(
        'INSERT INTO family_members (family_id, user_id, nickname) VALUES (?, ?, ?)',
        (family['id'], current_user.id, current_user.username)
    )
    conn.commit()
    conn.close()
    return jsonify({'status': 'ok', 'family_name': family['name']})


@app.route('/api/family/leave', methods=['POST'])
@login_required
def leave_family():
    conn = get_db()
    member = conn.execute(
        'SELECT * FROM family_members WHERE user_id = ?', (current_user.id,)
    ).fetchone()
    if not member:
        conn.close()
        return jsonify({'error': 'Not in a family'}), 400
    conn.execute('DELETE FROM family_members WHERE id = ?', (member['id'],))
    remaining = conn.execute(
        'SELECT COUNT(*) as cnt FROM family_members WHERE family_id = ?',
        (member['family_id'],)
    ).fetchone()['cnt']
    if remaining == 0:
        conn.execute('DELETE FROM places WHERE family_id = ?', (member['family_id'],))
        conn.execute('DELETE FROM families WHERE id = ?', (member['family_id'],))
    conn.commit()
    conn.close()
    return jsonify({'status': 'ok'})


@app.route('/api/family/members')
@login_required
def get_family_members():
    conn = get_db()
    member = conn.execute('SELECT family_id FROM family_members WHERE user_id = ?', (current_user.id,)).fetchone()
    if not member:
        conn.close()
        return jsonify({'members': []})
    members = conn.execute(
        'SELECT fm.user_id, fm.nickname, fm.role, u.username FROM family_members fm JOIN users u ON u.id = fm.user_id WHERE fm.family_id = ?',
        (member['family_id'],)
    ).fetchall()
    conn.close()
    return jsonify({'members': [dict(m) for m in members]})


@app.route('/api/places', methods=['GET', 'POST'])
@login_required
def manage_places():
    conn = get_db()
    member = conn.execute('SELECT family_id FROM family_members WHERE user_id = ?', (current_user.id,)).fetchone()
    if not member:
        conn.close()
        return jsonify({'error': 'Not in a family'}), 400
    if request.method == 'GET':
        places = conn.execute(
            'SELECT * FROM places WHERE family_id = ? ORDER BY created_at DESC',
            (member['family_id'],)
        ).fetchall()
        conn.close()
        return jsonify({'places': [dict(p) for p in places]})
    data = request.json
    name = data.get('name', '').strip()
    if not name:
        return jsonify({'error': 'Place name required'}), 400
    try:
        lat = float(data['latitude'])
        lng = float(data['longitude'])
        radius = int(data.get('radius_meters', 100))
    except (TypeError, ValueError, KeyError):
        return jsonify({'error': 'Invalid coordinates'}), 400
    conn.execute(
        'INSERT INTO places (family_id, name, latitude, longitude, radius_meters) VALUES (?, ?, ?, ?, ?)',
        (member['family_id'], name, lat, lng, radius)
    )
    conn.commit()
    place_id = conn.execute('SELECT last_insert_rowid()').fetchone()[0]
    conn.close()
    return jsonify({'status': 'ok', 'id': place_id})


@app.route('/api/places/<int:place_id>', methods=['PUT', 'DELETE'])
@login_required
def update_place(place_id):
    conn = get_db()
    member = conn.execute('SELECT family_id FROM family_members WHERE user_id = ?', (current_user.id,)).fetchone()
    if not member:
        conn.close()
        return jsonify({'error': 'Not in a family'}), 400
    place = conn.execute(
        'SELECT * FROM places WHERE id = ? AND family_id = ?',
        (place_id, member['family_id'])
    ).fetchone()
    if not place:
        conn.close()
        return jsonify({'error': 'Place not found'}), 404
    if request.method == 'DELETE':
        conn.execute('DELETE FROM geofence_events WHERE place_id = ?', (place_id,))
        conn.execute('DELETE FROM places WHERE id = ?', (place_id,))
        conn.commit()
        conn.close()
        return jsonify({'status': 'ok'})
    data = request.json
    if 'name' in data:
        conn.execute('UPDATE places SET name = ? WHERE id = ?', (data['name'], place_id))
    if 'latitude' in data and 'longitude' in data:
        conn.execute('UPDATE places SET latitude = ?, longitude = ? WHERE id = ?',
                    (float(data['latitude']), float(data['longitude']), place_id))
    if 'radius_meters' in data:
        conn.execute('UPDATE places SET radius_meters = ? WHERE id = ?',
                    (int(data['radius_meters']), place_id))
    conn.commit()
    conn.close()
    return jsonify({'status': 'ok'})


@app.route('/api/location', methods=['POST'])
@login_required
def report_location():
    data = request.json
    try:
        lat = float(data['latitude'])
        lng = float(data['longitude'])
        acc = float(data.get('accuracy', 0))
    except (TypeError, ValueError, KeyError):
        return jsonify({'error': 'Invalid location data'}), 400
    conn = get_db()
    conn.execute(
        'INSERT INTO locations (user_id, latitude, longitude, accuracy) VALUES (?, ?, ?, ?)',
        (current_user.id, lat, lng, acc)
    )
    conn.commit()
    conn.close()
    check_geofences(current_user.id, lat, lng)
    return jsonify({'status': 'ok'})


@app.route('/api/locations')
@login_required
def get_family_locations():
    conn = get_db()
    member = conn.execute('SELECT family_id FROM family_members WHERE user_id = ?', (current_user.id,)).fetchone()
    if not member:
        conn.close()
        return jsonify({'locations': []})
    members = conn.execute(
        'SELECT user_id FROM family_members WHERE family_id = ?', (member['family_id'],)
    ).fetchall()
    results = []
    for m in members:
        loc = conn.execute(
            'SELECT latitude, longitude, accuracy, timestamp FROM locations WHERE user_id = ? ORDER BY timestamp DESC LIMIT 1',
            (m['user_id'],)
        ).fetchone()
        user = conn.execute('SELECT username FROM users WHERE id = ?', (m['user_id'],)).fetchone()
        nm = conn.execute(
            'SELECT nickname FROM family_members WHERE user_id = ? AND family_id = ?',
            (m['user_id'], member['family_id'])
        ).fetchone()
        if loc:
            now = datetime.now()
            loc_time = datetime.strptime(loc['timestamp'], '%Y-%m-%d %H:%M:%S')
            age = (now - loc_time).total_seconds()
            results.append({
                'user_id': m['user_id'],
                'username': user['username'] if user else '',
                'nickname': nm['nickname'] if nm else '',
                'latitude': loc['latitude'],
                'longitude': loc['longitude'],
                'accuracy': loc['accuracy'],
                'timestamp': loc['timestamp'],
                'age_seconds': age,
                'online': age < 120
            })
    conn.close()
    return jsonify({'locations': results})


@app.route('/api/events')
@login_required
def get_events():
    conn = get_db()
    member = conn.execute('SELECT family_id FROM family_members WHERE user_id = ?', (current_user.id,)).fetchone()
    if not member:
        conn.close()
        return jsonify({'events': []})
    events = conn.execute(
        '''SELECT e.*, p.name as place_name FROM geofence_events e
           JOIN places p ON p.id = e.place_id
           WHERE p.family_id = ?
           ORDER BY e.created_at DESC LIMIT 50''',
        (member['family_id'],)
    ).fetchall()
    conn.close()
    return jsonify({'events': [dict(e) for e in events]})


@app.route('/track')
@login_required
def track_page():
    return render_template('track.html')


@app.route('/family/places')
@login_required
def family_places_page():
    return render_template('manage_places.html')


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
