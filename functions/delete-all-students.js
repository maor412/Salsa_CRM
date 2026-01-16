/**
 * סקריפט למחיקת כל התלמידים מ-Firestore
 * ⚠️ שימוש זהיר! פעולה זו תמחק את כל התלמידים!
 */

const admin = require('firebase-admin');

// אתחול Firebase Admin
try {
  const serviceAccount = require('./serviceAccountKey.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
  console.log('✅ מחובר ל-Firebase');
} catch (error) {
  console.error('❌ שגיאה באתחול Firebase:', error.message);
  process.exit(1);
}

const db = admin.firestore();

async function deleteAllStudents() {
  try {
    console.log('🔄 מוחק את כל התלמידים...');

    const studentsRef = db.collection('students');
    const snapshot = await studentsRef.get();

    if (snapshot.empty) {
      console.log('ℹ️  אין תלמידים למחוק');
      process.exit(0);
    }

    console.log(`📊 נמצאו ${snapshot.size} תלמידים למחיקה`);

    // מחיקה בבאצ'ים (מקסימום 500 בכל פעם)
    const batch = db.batch();
    let count = 0;

    snapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
      count++;
      console.log(`🗑️  ${count}. מוחק: ${doc.data().name}`);
    });

    await batch.commit();

    console.log(`\n✅ הסתיים בהצלחה!`);
    console.log(`✅ ${count} תלמידים נמחקו`);

  } catch (error) {
    console.error('❌ שגיאה:', error);
  } finally {
    process.exit(0);
  }
}

// אישור מהמשתמש
const readline = require('readline');
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

rl.question('⚠️  האם אתה בטוח שברצונך למחוק את כל התלמידים? (yes/no): ', (answer) => {
  rl.close();

  if (answer.toLowerCase() === 'yes' || answer.toLowerCase() === 'y') {
    deleteAllStudents();
  } else {
    console.log('❌ הפעולה בוטלה');
    process.exit(0);
  }
});
