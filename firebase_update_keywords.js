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
