from flask import Flask, request, jsonify
from flask_cors import CORS
from result import load_saved_features, find_similar_images
import os
from PIL import Image
from dactrung import extract_and_save_features
import subprocess

app = Flask(__name__)
CORS(app, resources={r"/search": {"origins": "*"}}) 
features_dict = load_saved_features('features.pkl')

@app.route('/search', methods=['POST'])
def search_image():
    try:
        if 'file' not in request.files:
            return jsonify({"error": "No file uploaded"}), 400

        file = request.files['file']
        print("Received file:", file.filename)  # In ra tên file nhận được
        file_path = 'temp_image.jpg'
        file.save(file_path)

        # Kiểm tra file đã được lưu không
        if not os.path.isfile(file_path):
            return jsonify({"error": "File not saved"}), 500

        # Kiểm tra ảnh
        try:
            img = Image.open(file_path)
            img.verify()  # Kiểm tra tính hợp lệ của file ảnh
            print(f"Image {file.filename} verified successfully.")
        except Exception as e:
            return jsonify({"error": f"Image verification failed: {str(e)}"}), 500

        # Tìm các ảnh tương đồng
        similar_images = find_similar_images(file_path, features_dict)

        # Kiểm tra nếu không tìm thấy ảnh tương tự
        if similar_images:
            return jsonify({
                "similar_images": similar_images  # Trả về toàn bộ danh sách ảnh tương tự
            })
        else:
            return jsonify({"message": "No similar images found"}), 404
    
    except Exception as e:
        print("Error occurred:", str(e))  # In ra thông báo lỗi
        return jsonify({"error": str(e)}), 500

@app.route('/train', methods=['POST'])
def train_features():
    try:
        # Tải toàn bộ ảnh mới nhất từ Firebase Storage về trước khi train
        subprocess.run(['python', 'firebase_download.py'], check=True)
        # Train lại đặc trưng cho toàn bộ ảnh trong data/
        extract_and_save_features('data/', 'features.pkl')
        global features_dict
        features_dict = load_saved_features('features.pkl')
        return jsonify({'message': 'Training completed!'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
