import pickle
import numpy as np
from sklearn.metrics.pairwise import cosine_similarity
from keras.preprocessing import image
from tensorflow.keras.applications import ResNet50
from tensorflow.keras.applications.resnet50 import preprocess_input
import sys

# Đặt mã hóa UTF-8 cho đầu ra
sys.stdout.reconfigure(encoding='utf-8')

# Load pre-trained ResNet50 model
model = ResNet50(weights='imagenet', include_top=False, pooling='avg')

# Function to extract features from an image using the pre-trained model
def extract_features(img_path):
    img = image.load_img(img_path, target_size=(224, 224))
    img_array = image.img_to_array(img)
    img_array = np.expand_dims(img_array, axis=0)
    img_array = preprocess_input(img_array)
    
    features = model.predict(img_array)
    return features.flatten()

# Function to load saved features
def load_saved_features(features_file):
    with open(features_file, 'rb') as f:
        features_dict = pickle.load(f)
    return features_dict

# Function to find all similar images with a similarity score >= threshold (0.65 by default)
def find_similar_images(query_image_path, features_dict, threshold=0.6):
    query_features = extract_features(query_image_path)
    
    similar_images = []
    
    for img_path, data_features in features_dict.items():
        similarity = cosine_similarity([query_features], [data_features])[0][0]
        # Chuyển similarity từ float32 sang float
        similarity = float(similarity)  # Chuyển đổi float32 sang float
        if similarity >= threshold:
            similar_images.append({
                "image_path": img_path,
                "similarity": similarity
            })
    
    # Sắp xếp theo độ tương đồng giảm dần
    similar_images.sort(key=lambda x: x["similarity"], reverse=True)
    
    return similar_images

