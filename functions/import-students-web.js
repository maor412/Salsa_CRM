/**
 * סקריפט להעלאת תלמידים מקובץ Excel ל-Firestore
 * גרסה עם Firebase Web SDK
 */

const { initializeApp } = require('firebase/app');
const { getFirestore, collection, doc, setDoc, Timestamp } = require('firebase/firestore');
const XLSX = require('xlsx');

// הגדרות Firebase - מתוך google-services.json או Firebase console
const firebaseConfig = {
  apiKey: "AIzaSyDCIE7GEhXL9QCJKy_zCK25mfhgU2Wjl1A",
  authDomain: "salsa-crew-assistant.firebaseapp.com",
  projectId: "salsa-crew-assistant",
  storageBucket: "salsa-crew-assistant.firebasestorage.app",
  messagingSenderId: "489355690311",
  appId: "1:489355690311:web:f4bc6b84652a1c5f73c858"
};

// אתחול Firebase
const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

console.log('✅ מחובר ל-Firebase');

/**
 * פונקציה להמרת תאריך מ-Excel
 */
function parseExcelDate(excelDate) {
  if (!excelDate) return null;

  // אם זה כבר תאריך
  if (excelDate instanceof Date) {
    return excelDate;
  }

  // אם זה מחרוזת בפורמט DD/MM/YYYY או YYYY-MM-DD
  if (typeof excelDate === 'string') {
    const trimmed = excelDate.trim();

    // דילוג על תאריכים ריקים או לא תקינים
    if (trimmed === '' || trimmed === '-' || trimmed === 'לא צויין') {
      return null;
    }

    // ניסיון לפרמט DD/MM/YYYY
    const ddmmyyyy = trimmed.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/);
    if (ddmmyyyy) {
      const day = parseInt(ddmmyyyy[1]);
      const month = parseInt(ddmmyyyy[2]) - 1;
      const year = parseInt(ddmmyyyy[3]);
      return new Date(year, month, day);
    }

    // ניסיון לפורמט YYYY-MM-DD
    const yyyymmdd = trimmed.match(/^(\d{4})-(\d{1,2})-(\d{1,2})$/);
    if (yyyymmdd) {
      const year = parseInt(yyyymmdd[1]);
      const month = parseInt(yyyymmdd[2]) - 1;
      const day = parseInt(yyyymmdd[3]);
      return new Date(year, month, day);
    }
  }

  // אם זה מספר סידורי מ-Excel
  if (typeof excelDate === 'number' && excelDate > 0) {
    const millisecondsPerDay = 24 * 60 * 60 * 1000;
    const excelEpoch = new Date(1899, 11, 30);
    return new Date(excelEpoch.getTime() + excelDate * millisecondsPerDay);
  }

  return null;
}

/**
 * פונקציה לניקוי מספר טלפון
 */
function cleanPhoneNumber(phone) {
  if (!phone) return '';

  let phoneStr = phone.toString().trim();

  // דילוג על טלפונים ריקים
  if (phoneStr === '' || phoneStr === '-' || phoneStr === 'לא צויין') {
    return '';
  }

  // הסרת תווים מיוחדים
  phoneStr = phoneStr.replace(/[^\d+\-]/g, '');

  // אם המספר מתחיל ב-0, נוסיף +972
  if (phoneStr.startsWith('0')) {
    phoneStr = '+972' + phoneStr.substring(1);
  }

  // אם המספר לא מתחיל ב-+, נוסיף +972
  if (!phoneStr.startsWith('+')) {
    phoneStr = '+972' + phoneStr;
  }

  return phoneStr;
}

/**
 * פונקציה להעלאת תלמידים
 */
async function importStudents(filePath) {
  try {
    console.log('🔄 קורא את קובץ Excel...');

    const workbook = XLSX.readFile(filePath);
    const sheetName = workbook.SheetNames[0];
    const worksheet = workbook.Sheets[sheetName];
    const data = XLSX.utils.sheet_to_json(worksheet);

    console.log(`📊 נמצאו ${data.length} תלמידים בקובץ`);

    if (data.length === 0) {
      console.log('⚠️  הקובץ ריק או אין בו נתונים');
      return;
    }

    console.log('📋 עמודות זמינות:', Object.keys(data[0]));

    // זיהוי עמודות
    const firstRow = data[0];
    const columnMapping = {};

    const nameColumns = ['שם מלא', 'שם', 'name', 'Name', 'full name'];
    for (const col of nameColumns) {
      if (firstRow[col] !== undefined) {
        columnMapping.name = col;
        break;
      }
    }

    const birthdayColumns = ['תאריך לידה', 'תאריך לידה ', 'יום הולדת', 'birthday'];
    for (const col of birthdayColumns) {
      if (firstRow[col] !== undefined) {
        columnMapping.birthday = col;
        break;
      }
    }

    const phoneColumns = ['טלפון', 'טלפון נייד', 'נייד', 'phone', 'mobile'];
    for (const col of phoneColumns) {
      if (firstRow[col] !== undefined) {
        columnMapping.phone = col;
        break;
      }
    }

    console.log('🔍 מיפוי עמודות:', columnMapping);

    if (!columnMapping.name) {
      console.error('❌ לא נמצאה עמודת שם!');
      return;
    }

    let successCount = 0;
    let errorCount = 0;

    // עיבוד תלמידים אחד אחד
    for (let i = 0; i < data.length; i++) {
      const row = data[i];

      try {
        const name = row[columnMapping.name];

        if (!name || name.toString().trim() === '') {
          console.log(`⏭️  מדלג על שורה ${i + 1} (ריקה)`);
          continue;
        }

        const phoneNumber = columnMapping.phone ? cleanPhoneNumber(row[columnMapping.phone]) : '';
        const birthday = columnMapping.birthday ? parseExcelDate(row[columnMapping.birthday]) : null;

        const studentData = {
          name: name.toString().trim(),
          phoneNumber: phoneNumber,
          birthday: birthday ? Timestamp.fromDate(birthday) : null,
          joinedAt: Timestamp.now(),
          isActive: true,
          notes: null,
        };

        // שמירה ל-Firestore
        const studentRef = doc(collection(db, 'students'));
        await setDoc(studentRef, studentData);

        successCount++;
        const birthdayStr = birthday ? birthday.toLocaleDateString('he-IL') : 'ללא תאריך לידה';
        console.log(`✅ ${i + 1}. ${studentData.name} - ${phoneNumber || 'ללא טלפון'} - ${birthdayStr}`);

      } catch (error) {
        errorCount++;
        console.error(`❌ שגיאה בשורה ${i + 1}:`, error.message);
      }
    }

    console.log(`\n✅ הסתיים בהצלחה!`);
    console.log(`✅ ${successCount} תלמידים נוספו`);
    if (errorCount > 0) {
      console.log(`⚠️  ${errorCount} שגיאות`);
    }

  } catch (error) {
    console.error('❌ שגיאה כללית:', error);
  } finally {
    process.exit(0);
  }
}

const filePath = process.argv[2];

if (!filePath) {
  console.error('❌ נא לספק נתיב לקובץ Excel');
  console.log('\nשימוש:');
  console.log('  node import-students-web.js path/to/students.xlsx');
  process.exit(1);
}

const fs = require('fs');
if (!fs.existsSync(filePath)) {
  console.error(`❌ הקובץ ${filePath} לא נמצא`);
  process.exit(1);
}

importStudents(filePath);
