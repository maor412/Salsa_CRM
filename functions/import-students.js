/**
 * סקריפט להעלאת תלמידים מקובץ Excel ל-Firestore
 *
 * דרישות:
 * 1. קובץ Excel עם העמודות הבאות:
 *    - שם מלא (name)
 *    - תאריך לידה (birthday) - פורמט: DD/MM/YYYY או YYYY-MM-DD
 *    - טלפון (phone)
 *
 * 2. התקנת חבילות:
 *    npm install xlsx firebase-admin
 *
 * שימוש:
 *    node import-students.js path/to/students.xlsx
 */

const admin = require('firebase-admin');
const XLSX = require('xlsx');
const path = require('path');

// אתחול Firebase Admin
// ניסיון 1: עם serviceAccountKey.json אם קיים
// ניסיון 2: עם Application Default Credentials
let initialized = false;

// ניסיון ראשון: קובץ Service Account
try {
  const serviceAccount = require('./serviceAccountKey.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
  console.log('✅ מחובר ל-Firebase עם Service Account Key');
  initialized = true;
} catch (error) {
  // זה בסדר, ננסה דרך אחרת
}

// ניסיון שני: Firebase CLI credentials
if (!initialized && admin.apps.length === 0) {
  try {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
      projectId: 'salsa-crew-assistant'
    });
    console.log('✅ מחובר ל-Firebase עם Application Default Credentials');
    initialized = true;
  } catch (error) {
    console.error('⚠️ שגיאה באתחול Firebase:', error.message);
  }
}

const db = admin.firestore();

/**
 * פונקציה להמרת תאריך מ-Excel
 * Excel שומר תאריכים כמספרים סידוריים מאז 1/1/1900
 */
function parseExcelDate(excelDate) {
  if (!excelDate) return null;

  // בדיקה אם זה ערך ריק או לא תקין
  if (typeof excelDate === 'string') {
    const trimmed = excelDate.trim();
    if (trimmed === '' || trimmed === '-' || trimmed.toLowerCase() === 'null') {
      return null;
    }
  }

  // אם זה כבר תאריך
  if (excelDate instanceof Date) {
    // בדיקה שהתאריך תקין
    if (isNaN(excelDate.getTime())) {
      return null;
    }
    return excelDate;
  }

  // אם זה מספר סידורי מ-Excel (כמו 44661)
  if (typeof excelDate === 'number' && excelDate > 1) {
    const millisecondsPerDay = 24 * 60 * 60 * 1000;
    const excelEpoch = new Date(1899, 11, 30); // Excel epoch is 30/12/1899
    const date = new Date(excelEpoch.getTime() + excelDate * millisecondsPerDay);
    return date;
  }

  // אם זה מחרוזת בפורמט DD/MM/YYYY
  if (typeof excelDate === 'string') {
    const ddmmyyyy = excelDate.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/);
    if (ddmmyyyy) {
      const day = parseInt(ddmmyyyy[1]);
      const month = parseInt(ddmmyyyy[2]) - 1; // חודשים מתחילים מ-0
      const year = parseInt(ddmmyyyy[3]);
      return new Date(year, month, day);
    }

    // ניסיון לפורמט YYYY-MM-DD
    const yyyymmdd = excelDate.match(/^(\d{4})-(\d{1,2})-(\d{1,2})$/);
    if (yyyymmdd) {
      const year = parseInt(yyyymmdd[1]);
      const month = parseInt(yyyymmdd[2]) - 1;
      const day = parseInt(yyyymmdd[3]);
      return new Date(year, month, day);
    }
  }

  return null;
}

/**
 * פונקציה לניקוי מספר טלפון
 */
function cleanPhoneNumber(phone) {
  if (!phone) return '';

  // המרה למחרוזת
  let phoneStr = phone.toString().trim();

  // הסרת תווים מיוחדים (חוץ מ + ו -)
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
 * פונקציה להעלאת תלמידים מ-Excel ל-Firestore
 */
async function importStudents(filePath) {
  try {
    console.log('🔄 קורא את קובץ Excel...');

    // קריאת קובץ Excel
    const workbook = XLSX.readFile(filePath);
    const sheetName = workbook.SheetNames[0]; // הגיליון הראשון
    const worksheet = workbook.Sheets[sheetName];

    // המרה ל-JSON
    const data = XLSX.utils.sheet_to_json(worksheet);

    console.log(`📊 נמצאו ${data.length} תלמידים בקובץ`);

    if (data.length === 0) {
      console.log('⚠️  הקובץ ריק או אין בו נתונים');
      return;
    }

    // הצגת העמודות הזמינות
    console.log('📋 עמודות זמינות:', Object.keys(data[0]));

    // זיהוי אוטומטי של שמות העמודות
    const firstRow = data[0];
    const columnMapping = {};
    const availableColumns = Object.keys(firstRow);

    // פונקציה לחיפוש עמודה (מתעלמת מרווחים)
    function findColumn(possibleNames) {
      // חיפוש התאמה מדויקת
      for (const name of possibleNames) {
        if (availableColumns.includes(name)) {
          return name;
        }
      }

      // חיפוש עם התעלמות מרווחים
      for (const col of availableColumns) {
        const normalizedCol = col.trim().toLowerCase();
        for (const name of possibleNames) {
          if (normalizedCol === name.trim().toLowerCase()) {
            return col;
          }
        }
      }

      // חיפוש חלקי (אם העמודה מכילה את המילה)
      for (const col of availableColumns) {
        const normalizedCol = col.trim().toLowerCase();
        for (const name of possibleNames) {
          if (normalizedCol.includes(name.trim().toLowerCase())) {
            return col;
          }
        }
      }

      return null;
    }

    // חיפוש עמודת שם
    const nameColumns = ['שם מלא', 'שם', 'name', 'full name', 'fullName'];
    columnMapping.name = findColumn(nameColumns);

    // חיפוש עמודת תאריך לידה
    const birthdayColumns = ['תאריך לידה', 'יום הולדת', 'birthday', 'birth date', 'birthDate'];
    columnMapping.birthday = findColumn(birthdayColumns);

    // חיפוש עמודת טלפון
    const phoneColumns = ['טלפון נייד', 'טלפון', 'נייד', 'phone', 'mobile', 'phoneNumber'];
    columnMapping.phone = findColumn(phoneColumns);

    console.log('🔍 מיפוי עמודות:', columnMapping);

    if (!columnMapping.name) {
      console.error('❌ לא נמצאה עמודת שם! העמודות הזמינות:', Object.keys(data[0]));
      return;
    }

    // עיבוד התלמידים
    const batch = db.batch();
    let successCount = 0;
    let errorCount = 0;

    const studentsCollection = db.collection('students');

    for (let i = 0; i < data.length; i++) {
      const row = data[i];

      try {
        const name = row[columnMapping.name];

        // דילוג על שורות ריקות
        if (!name || name.toString().trim() === '') {
          console.log(`⏭️  מדלג על שורה ${i + 1} (ריקה)`);
          continue;
        }

        const phoneNumber = columnMapping.phone ? cleanPhoneNumber(row[columnMapping.phone]) : '';
        const birthday = columnMapping.birthday ? parseExcelDate(row[columnMapping.birthday]) : null;

        // יצירת מסמך חדש
        const studentRef = studentsCollection.doc();

        const studentData = {
          name: name.toString().trim(),
          phoneNumber: phoneNumber,
          birthday: birthday ? admin.firestore.Timestamp.fromDate(birthday) : null,
          joinedAt: admin.firestore.Timestamp.now(),
          isActive: true,
          notes: null,
        };

        batch.set(studentRef, studentData);
        successCount++;

        console.log(`✅ ${i + 1}. ${studentData.name} - ${phoneNumber} - ${birthday ? birthday.toLocaleDateString('he-IL') : 'ללא תאריך לידה'}`);

      } catch (error) {
        errorCount++;
        console.error(`❌ שגיאה בשורה ${i + 1}:`, error.message);
      }
    }

    // שמירה ב-Firestore
    if (successCount > 0) {
      console.log('\n🔄 שומר תלמידים ב-Firestore...');
      await batch.commit();
      console.log(`\n✅ הסתיים בהצלחה!`);
      console.log(`✅ ${successCount} תלמידים נוספו`);
      if (errorCount > 0) {
        console.log(`⚠️  ${errorCount} שגיאות`);
      }
    } else {
      console.log('⚠️  לא נמצאו תלמידים להעלאה');
    }

  } catch (error) {
    console.error('❌ שגיאה כללית:', error);
  } finally {
    process.exit(0);
  }
}

// קבלת נתיב הקובץ מה-command line
const filePath = process.argv[2];

if (!filePath) {
  console.error('❌ נא לספק נתיב לקובץ Excel');
  console.log('\nשימוש:');
  console.log('  node import-students.js path/to/students.xlsx');
  process.exit(1);
}

// בדיקה שהקובץ קיים
const fs = require('fs');
if (!fs.existsSync(filePath)) {
  console.error(`❌ הקובץ ${filePath} לא נמצא`);
  process.exit(1);
}

// הרצת הייבוא
importStudents(filePath);
