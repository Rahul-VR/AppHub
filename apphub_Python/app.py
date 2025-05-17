from flask import Flask, request, session, jsonify, render_template, redirect, url_for
import mysql.connector
import os

app = Flask(__name__)
#app.secret_key = 'supersecret123'
# Database connection
def create_connection():
    return mysql.connector.connect(
        host="localhost",
        user="root",
        password="",
        database="apphub"
    )

# @app.route('/')
# def index():
#     return render_template('login.html')

# @app.route('/admin', methods=['POST'])
# def admin():
#     email = request.form.get('email').strip()
#     password = request.form.get('password').strip()

#     connection = create_connection()
#     cursor = connection.cursor(dictionary=True)

#     query = "SELECT email, password FROM admin WHERE email = %s"
#     cursor.execute(query, (email,))
#     user = cursor.fetchone()

#     cursor.close()
#     connection.close()

#     if user and user['password'] == password:
#         session['user'] = email
#         return redirect(url_for('admin_dashboard'))
#     else:
#         return render_template('login.html', error="Invalid email or password")

@app.route('/admin_dashboard')
def admin_dashboard():
     return render_template('admin_approve.html')

# @app.route('/logout')
# def logout():
#     session.clear()
#     return redirect(url_for('index'))

UPLOAD_FOLDER = 'uploads'
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

@app.route('/uploads/<filename>')
def serve_uploaded_file(filename):
    return send_from_directory(UPLOAD_FOLDER, filename)

@app.route('/uploads/<path:filename>')
def download_file(filename):
    return send_from_directory('uploads', filename, as_attachment=True)

# # ---------------------- USER AUTHENTICATION ----------------------

# User Login API
@app.route('/login', methods=['POST'])
def login():
    data = request.json
    email = data.get('email')
    password = data.get('password')
    user_type = data.get('type')  # Get the user type (student or faculty)

    connection = create_connection()
    try:
        cursor = connection.cursor(dictionary=True)
        query = "SELECT username, email, password, type FROM users WHERE email = %s AND type = %s"
        cursor.execute(query, (email, user_type))
        user = cursor.fetchone()

        if user and user['password'] == password:
            return jsonify({
                "success": True,
                "message": f"{user_type.capitalize()} login successful",
                "username": user['username'],
                "email": user['email'],
                "type": user['type']
            })
        else:
            return jsonify({"success": False, "message": "Invalid email, password, or user type"})
    except Exception as e:
        return jsonify({"success": False, "message": f"Error during login: {e}"})
    finally:
        connection.close()


# User Registration API
@app.route('/register', methods=['POST'])
def register():
    data = request.json
    username = data.get('username')
    email = data.get('email')
    password = data.get('password')
    user_type = data.get('type')

    connection = create_connection()
    try:
        cursor = connection.cursor(dictionary=True)
        cursor.execute("SELECT * FROM users WHERE email = %s", (email,))
        existing_user = cursor.fetchone()
        if existing_user:
            return jsonify({"success": False, "message": "Email already exists"})

        query = "INSERT INTO users (username, email, password, type) VALUES (%s, %s, %s, %s)"
        cursor.execute(query, (username, email, password, user_type))
        connection.commit()
        return jsonify({"success": True, "message": "Registration successful"})
    except Exception as e:
        return jsonify({"success": False, "message": f"Error during registration: {e}"})
    finally:
        connection.close()


# Fetch User Profile
@app.route('/profile', methods=['POST'])
def profile():
    data = request.json
    email = data.get('email')

    connection = create_connection()
    try:
        cursor = connection.cursor(dictionary=True)
        cursor.execute("SELECT username, email FROM users WHERE email = %s", (email,))
        user = cursor.fetchone()

        if user:
            return jsonify({"success": True, "username": user['username'], "email": user['email']})
        else:
            return jsonify({"success": False, "message": "User not found"})
    except Exception as e:
        return jsonify({"success": False, "message": f"Error fetching profile: {e}"})
    finally:
        connection.close()

# ---------------------- APP UPLOAD & MANAGEMENT ----------------------

# Fetch User Uploaded Apps (Dropdown)
@app.route('/user_apps', methods=['POST'])
def user_apps():
    data = request.json
    email = data['email']

    connection = create_connection()
    try:
        cursor = connection.cursor(dictionary=True)
        query = "SELECT * FROM apps WHERE email = %s"
        cursor.execute(query, (email,))
        apps = cursor.fetchall()
        
        # ✅ Return the fetched app data directly
        return jsonify({"success": True, "apps": apps})
    except Exception as e:
        return jsonify({"success": False, "message": f"Error fetching user apps: {e}"})
    finally:
        connection.close()

# Upload App (New or Update)
@app.route('/upload_app', methods=['POST'])
def upload_app():
    email = request.form.get('email')
    app_name = request.form.get('app_name')
    category = request.form.get('category')
    description = request.form.get('description')
    features = request.form.get('features')
    is_update = request.form.get('is_update') == 'true'
    existing_app = request.form.get('existing_app')
    new_features = request.form.get('new_features') if is_update else None

    # File handling
    screenshot1 = request.files.get('screenshot1')
    screenshot2 = request.files.get('screenshot2')
    certificate = request.files.get('certificate')
    apk_file = request.files.get('apk_file')
    icon = request.files.get('icon')  # Handling the new icon field

    file_paths = {}
    for file, key in [
        (screenshot1, 'screenshot1'), (screenshot2, 'screenshot2'), 
        (certificate, 'certificate'), (apk_file, 'apk_file'), (icon, 'icon')
    ]:
        if file:
            filename = f"{app_name}_{key}.png" if key != 'apk_file' else f"{app_name}.apk"
            file_path = os.path.join(UPLOAD_FOLDER, filename)
            file.save(file_path)
            file_paths[key] = filename

    connection = create_connection()
    try:
        cursor = connection.cursor()

        # Insert into temp_apps for admin verification
        query = """INSERT INTO temp_apps 
            (email, app_name, icon, description, features, new_features, apk_file, 
             screenshot1, screenshot2, certificate, is_update, status, category) 
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)"""
        cursor.execute(query, (email, app_name, file_paths.get('icon'), description, 
                       features, new_features, file_paths.get('apk_file'), 
                       file_paths.get('screenshot1'), file_paths.get('screenshot2'), 
                       file_paths.get('certificate'), is_update, 'Pending', category))
        connection.commit()

        return jsonify({"success": True, "message": "App uploaded for verification"})
    except Exception as e:
        print(f"Error: {e}")  # Add this line to print the error
        return jsonify({"success": False, "message": f"Error uploading app: {e}"})
    finally:
        connection.close()


# Admin Approval - Move to Main Table
@app.route('/approve_app', methods=['POST'])
def approve_app():
    data = request.get_json()  # Get JSON data
    print("Received data:", data)  # Debugging print statement
    
    if not data or 'app_id' not in data:
        return jsonify({"error": "Missing app_id"}), 400  
    app_id = data['app_id']

    connection = create_connection()
    try:
        cursor = connection.cursor(dictionary=True)
        
        # Fetch app details from temp_apps
        cursor.execute("SELECT * FROM temp_apps WHERE id = %s", (app_id,))
        app = cursor.fetchone()

        if app:
            cursor.execute("""INSERT INTO apps (email, app_name, icon, description, features, apk_file, 
                                                screenshot1, screenshot2, certificate, category) 
                              VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)""",
                           (app['email'], app['app_name'], app['icon'], app['description'], app['features'], 
                            app['apk_file'], app['screenshot1'], app['screenshot2'], app['certificate'], app['category']))
            
            # If updating, delete old app from main table
            if app['is_update']:
                cursor.execute("DELETE FROM apps WHERE app_name = %s", (app['app_name'],))
                old_apk = os.path.join(UPLOAD_FOLDER, f"{app['app_name']}.apk")
                if os.path.exists(old_apk):
                    os.remove(old_apk)

            # Remove from temp_apps
            cursor.execute("DELETE FROM temp_apps WHERE id = %s", (app_id,))
            connection.commit()


        return jsonify({"success": True, "message": "App approved & moved to main table"})
    except Exception as e:
        return jsonify({"success": False, "message": f"Error during approval: {e}"})
    finally:
        connection.close()

@app.route('/pending_apps', methods=['GET'])
def pending_apps():
    connection = create_connection()
    try:
        cursor = connection.cursor(dictionary=True)
        query = """
            SELECT id, app_name, description, features, new_features, is_update, 
                   screenshot1, screenshot2, certificate, apk_file, email, uploaded_at, category
            FROM temp_apps
            WHERE status = 'pending'
        """
        cursor.execute(query)
        apps = cursor.fetchall()
        return jsonify({"success": True, "apps": apps})
    except Exception as e:
        return jsonify({"success": False, "message": f"Error fetching pending apps: {e}"})
    finally:
        connection.close()



@app.route('/reject_app', methods=['POST'])
def reject_app():
    data = request.json
    app_id = data['id']

    connection = create_connection()
    try:
        cursor = connection.cursor()

        # Update status to 'rejected'
        update_query = "UPDATE temp_apps SET status = 'rejected' WHERE id = %s"
        cursor.execute(update_query, (app_id,))

        connection.commit()
        return jsonify({"success": True, "message": "App rejected!"})
    except Exception as e:
        return jsonify({"success": False, "message": f"Error rejecting app: {e}"})
    finally:
        connection.close()
from flask import send_from_directory


@app.route('/all_apps_with_ratings', methods=['GET'])
def get_all_apps_with_ratings():
    connection = create_connection()
    try:
        cursor = connection.cursor(dictionary=True)
        cursor.execute("""
            SELECT 
                a.id,
                a.app_name,
                a.icon,
                a.description,
                a.screenshot1,
                a.screenshot2,
                a.apk_file,
                ROUND(AVG(r.rating), 1) AS average_rating
            FROM apps a
            LEFT JOIN rateAndReview r ON a.id = r.app_id
            GROUP BY a.id
        """)
        apps = cursor.fetchall()

        for app in apps:
            # Add full icon URL
            app['icon_url'] = f"http://192.168.243.11:5000/uploads/{app['icon']}"  # adjust folder as needed

            # APK size
            apk_path = os.path.join('uploads', app['apk_file'])  # replace with actual apk folder
            if os.path.exists(apk_path):
                app['apk_size'] = round(os.path.getsize(apk_path) / (1024 * 1024), 2)
            else:
                app['apk_size'] = 0.0

        return jsonify({'success': True, 'apps': apps})
    
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})
    
    finally:
        cursor.close()
        connection.close()

@app.route('/get_reviews', methods=['GET'])
def get_reviews():
    app_id = request.args.get('app_id')
    connection = create_connection()
    try:
        cursor = connection.cursor()
        cursor.execute(
            "SELECT email, rating, review, created_at FROM rateandreview WHERE app_id = %s",
            (app_id,)
        )
        reviews = cursor.fetchall()

        review_list = []
        for row in reviews:
            review_list.append({
                'email': row[0],
                'rating': row[1],
                'review': row[2],
                'created_at': row[3].strftime('%Y-%m-%d %H:%M:%S') if row[3] else ''
            })

        return jsonify(review_list)
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})
    finally:
        cursor.close()
        connection.close()

@app.route('/submit_review', methods=['POST'])
def submit_review():
    data = request.json
    app_id = data.get('app_id')
    email = data.get('email')
    rating = data.get('rating')
    review = data.get('review')

    connection = create_connection()
    try:
        cursor = connection.cursor()
        cursor.execute("""
            INSERT INTO rateandreview (app_id, email, rating, review)
            VALUES (%s, %s, %s, %s)
        """, (app_id, email, rating, review))
        connection.commit()
        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})
    finally:
        cursor.close()
        connection.close()




@app.route('/get_user_id', methods=['GET'])
def get_user_id():
    email = request.args.get('email')
    if not email:
        return jsonify({'error': 'Email is required'}), 400

    try:
        conn = create_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT id FROM users WHERE email = %s", (email,))
        result = cursor.fetchone()
        return jsonify({'user_id': result['id']} if result else {'user_id': None})

    except Exception as e:
        return jsonify({'error': str(e)}), 500

    finally:
        if cursor: cursor.close()
        if conn: conn.close()


@app.route('/search_apps', methods=['GET'])
def search_apps():
    query = request.args.get('query')
    user_id = request.args.get('user_id')

    if not query:
        return jsonify([])

    try:
        conn = create_connection()
        cursor = conn.cursor(dictionary=True)

        # Query to fetch app details with average rating from the rateAndReview table
        cursor.execute("""
            SELECT 
                a.id,
                a.app_name,
                a.icon,
                a.description,
                a.screenshot1,
                a.screenshot2,
                a.apk_file,
                ROUND(AVG(r.rating), 1) AS average_rating,
                a.category  -- Assuming category exists in the apps table
            FROM apps a
            LEFT JOIN rateAndReview r ON a.id = r.app_id
            WHERE a.app_name LIKE %s
            GROUP BY a.id
        """, ('%' + query + '%',))

        apps = cursor.fetchall()

        for app in apps:
            # Construct the full icon URL (assuming the icon images are stored in the 'uploads' folder)
            app['icon_url'] = f"http://192.168.243.11:5000/uploads/{app['icon']}"  # adjust folder as needed

            # Calculate APK size (assuming APK files are stored in the 'uploads' folder)
            apk_path = os.path.join('uploads', app['apk_file'])  # Replace with actual APK file folder
            if os.path.exists(apk_path):
                app['apk_size'] = round(os.path.getsize(apk_path) / (1024 * 1024), 2)  # size in MB
            else:
                app['apk_size'] = 0.0

        # Save to search_history only if results are found
        if apps and user_id:
            first_category = apps[0].get('category', 'Unknown')  # Default to 'Unknown' if category is missing
            cursor.execute("""
                INSERT INTO search_history (user_id, search_query, app_category, search_date)
                VALUES (%s, %s, %s, NOW())
            """, (user_id, query, first_category))
            conn.commit()

        return jsonify({'success': True, 'apps': apps})

    except Exception as e:
        print("Error during search:", e)
        return jsonify({'error': str(e)}), 500

    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()



@app.route('/get_category_from_history', methods=['GET'])
def get_category_from_history():
    user_id = request.args.get('user_id')

    if not user_id:
        return jsonify({'error': 'User ID is required'}), 400

    try:
        conn = create_connection()
        cursor = conn.cursor(dictionary=True)

        cursor.execute("""
            SELECT app_category FROM search_history
            WHERE user_id = %s
            ORDER BY search_date DESC LIMIT 1
        """, (user_id,))
        
        category = cursor.fetchone()
        
        if category:
            return jsonify({'category': category['app_category']})
        else:
            return jsonify({'category': None})
    
    except Exception as e:
        print("Error fetching category:", e)
        return jsonify({'error': str(e)}), 500
    
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()


@app.route('/get_apps_by_category', methods=['GET'])
def get_apps_by_category():
    category = request.args.get('category')

    if not category:
        return jsonify({'error': 'Category is required'}), 400

    try:
        conn = create_connection()
        cursor = conn.cursor(dictionary=True)

        cursor.execute("""
            SELECT 
                a.id,
                a.app_name,
                a.icon,
                a.description,
                a.screenshot1,
                a.screenshot2,
                a.apk_file,
                ROUND(AVG(r.rating), 1) AS average_rating
            FROM apps a
            LEFT JOIN rateAndReview r ON a.id = r.app_id
            WHERE a.category = %s
            GROUP BY a.id
        """, (category,))
        
        apps = cursor.fetchall()

        for app in apps:
            # Add full icon URL
            app['icon_url'] = f"http://192.168.243.11:5000/uploads/{app['icon']}"
            
            # APK size calculation
            apk_path = os.path.join('uploads', app['apk_file'])
            if os.path.exists(apk_path):
                app['apk_size'] = round(os.path.getsize(apk_path) / (1024 * 1024), 2)
            else:
                app['apk_size'] = 0.0

        return jsonify({'success': True, 'apps': apps})
    
    except Exception as e:
        print("Error fetching apps by category:", e)
        return jsonify({'error': str(e)}), 500
    
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()


if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
