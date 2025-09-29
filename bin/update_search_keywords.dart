import 'dart:io';

void main() async {
  // Script để tự động cập nhật search keywords cho pets
  print('=== Script cập nhật Search Keywords cho Pets ===');
  print('');
  print('Chức năng này sẽ tạo ra code Firestore để cập nhật search keywords');
  print('cho từng pet dựa trên name, breed, category');
  print('');
  
  // Tạo ví dụ code Firestore
  final updateCode = '''
// Code Firebase Functions để cập nhật search keywords
const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();

async function updateSearchKeywords() {
  const petsSnapshot = await db.collection('Pets').get();
  const batch = db.batch();
  
  petsSnapshot.docs.forEach(doc => {
    const data = doc.data();
    const name = (data.name || '').toLowerCase();
    const breed = (data.breed || '').toLowerCase();
    const category = (data.category || '').toLowerCase();
    
    const keywords = new Set();
    
    // Thêm keywords từ name
    name.split(' ').forEach(word => {
      if (word.trim()) keywords.add(word.trim());
    });
    keywords.add(name); // Thêm tên đầy đủ
    
    // Thêm keywords từ breed
    breed.split(' ').forEach(word => {
      if (word.trim()) keywords.add(word.trim());
    });
    keywords.add(breed); // Thêm breed đầy đủ
    
    // Thêm keywords từ category
    category.split(' ').forEach(word => {
      if (word.trim()) keywords.add(word.trim());
    });
    keywords.add(category); // Thêm category đầy đủ
    
    // Thêm từ đồng nghĩa tiếng Việt
    if (category === 'dogs' || category === 'dog') {
      keywords.add('chó');
      keywords.add('cún');
    }
    if (category === 'cats' || category === 'cat') {
      keywords.add('mèo');
    }
    if (category === 'fish') {
      keywords.add('cá');
    }
    
    // Cập nhật document
    batch.update(doc.ref, {
      searchKeywords: Array.from(keywords).filter(k => k !== '')
    });
  });
  
  await batch.commit();
  console.log('Updated search keywords for all pets');
}

updateSearchKeywords().catch(console.error);
''';

  // Ghi code vào file
  final file = File('firebase_update_keywords.js');
  await file.writeAsString(updateCode);
  
  print('✅ Đã tạo file firebase_update_keywords.js');
  print('');
  print('=== Các cải thiện đã thực hiện ===');
  print('1. ✅ Gợi ý theo thời gian thực khi gõ (debounce 500ms)');
  print('2. ✅ Tìm kiếm theo tên thú cưng');
  print('3. ✅ Tìm kiếm theo breed (giống)');
  print('4. ✅ Tìm kiếm theo category (danh mục)');
  print('5. ✅ Tìm kiếm trong breeds của Categories collection');
  print('6. ✅ Hiển thị icon và màu sắc khác nhau cho từng loại gợi ý');
  print('7. ✅ Sắp xếp kết quả theo độ ưu tiên (tên -> breed -> category)');
  print('8. ✅ Giới hạn số lượng gợi ý (10 items)');
  print('9. ✅ Lưu lịch sử tìm kiếm');
  print('10. ✅ Cải thiện UI/UX tương tự Shopee');
}