import firebase_admin
from firebase_admin import credentials, storage
import os

# Đường dẫn tới file serviceAccountKey.json (bạn cần tải từ Firebase Console)
SERVICE_ACCOUNT_PATH = 'serviceAccountKey.json'  # Đặt file này vào TrainImagePet/
BUCKET_NAME = 'adopt-pet-d1c88.appspot.com'  # Thay bằng tên bucket của bạn
LOCAL_FOLDER = 'data/'

def init_firebase():
    if not firebase_admin._apps:
        cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
        firebase_admin.initialize_app(cred, {
            'storageBucket': BUCKET_NAME
        })

def download_all_images():
    init_firebase()
    bucket = storage.bucket()
    blobs = bucket.list_blobs()
    os.makedirs(LOCAL_FOLDER, exist_ok=True)
    for blob in blobs:
        # Kiểm tra content_type để nhận diện file ảnh (kể cả khi không có đuôi .png)
        is_image = False
        if blob.content_type and blob.content_type.startswith('image/'):
            is_image = True
        elif blob.name.lower().endswith(('.jpg', '.jpeg', '.png', '.bmp', '.gif', '.webp')):
            is_image = True
        if is_image:
            local_path = os.path.join(LOCAL_FOLDER, blob.name)
            os.makedirs(os.path.dirname(local_path), exist_ok=True)
            print(f"Downloading {blob.name} to {local_path}")
            blob.download_to_filename(local_path)

if __name__ == '__main__':
    download_all_images()
    print('Download completed!')
