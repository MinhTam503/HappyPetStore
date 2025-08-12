import os
import numpy as np
from keras.preprocessing import image
from tensorflow.keras.applications.resnet50 import ResNet50, preprocess_input
import pickle
import sys
import io

# Set the default encoding to UTF-8
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

# Load the pre-trained ResNet50 model
model = ResNet50(weights='imagenet', include_top=False, pooling='avg')

# Function to extract features from an image using the pre-trained model
def extract_features(img_path):
    img = image.load_img(img_path, target_size=(224, 224))
    img_array = image.img_to_array(img)
    img_array = np.expand_dims(img_array, axis=0)
    img_array = preprocess_input(img_array)
    
    features = model.predict(img_array)
    return features.flatten()

# Extract and save features of the entire dataset
def extract_and_save_features(dataset_dir, output_file):
    features_dict = {}
    
    for root, _, files in os.walk(dataset_dir):
        for file in files:
            img_path = os.path.join(root, file)
            try:
                features = extract_features(img_path)
                features_dict[img_path] = features
            except Exception as e:
                print(f"Error processing {img_path}: {e}")
    
    # Save the features to a file
    with open(output_file, 'wb') as f:
        pickle.dump(features_dict, f)

# Path to the dataset directory
# Đổi thành 'data/' để đồng bộ với script download
# data_directory = 'data/train'  # Thay thế bằng đường dẫn dataset của bạn
data_directory = 'data/'
output_file = 'features.pkl'  # File lưu trữ các đặc trưng

# Extract and save features
if __name__ == '__main__':
    extract_and_save_features(data_directory, output_file)
