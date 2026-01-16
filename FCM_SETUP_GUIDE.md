# 🔥 מדריך הגדרת Firebase Cloud Messaging (FCM)

## למה FCM?
נוטיפיקציות מתוזמנות רגילות לא עובדות כשהאפליקציה סגורה ב-Android מודרני.
FCM מאפשר לשלוח נוטיפיקציות מהשרת בזמנים מדויקים, גם כשהאפליקציה סגורה לחלוטין!

---

## שלב 1: הגדרת Firebase Functions

### 1.1 התקנת Firebase CLI
```bash
npm install -g firebase-tools
```

### 1.2 התחברות ל-Firebase
```bash
firebase login
```

### 1.3 אתחול Firebase בפרויקט
```bash
cd "c:\Users\Maor Moshe\Desktop\Bots\Salsa_managment_app"
firebase init functions
```

בחר:
- **Use an existing project** → בחר את הפרויקט שלך
- **JavaScript** (לא TypeScript)
- **Yes** להתקנת dependencies

### 1.4 התקנת Dependencies
```bash
cd functions
npm install
```

---

## שלב 2: פריסת ה-Functions לשרת

```bash
firebase deploy --only functions
```

זה יעלה את ה-Functions לשרת Firebase. הם ירוצו אוטומטית:
- **כל יום רביעי ב-9:30** - תזכורת ראשונה
- **כל יום שבת ב-9:30** - תזכורת שנייה

---

## שלב 3: בדיקה

### 3.1 הרץ את האפליקציה
```bash
flutter run
```

### 3.2 בדוק את הלוג
אמור לראות:
```
FCM Token: <token>
✅ FCM token saved successfully
```

### 3.3 בדוק ב-Firestore
1. פתח [Firebase Console](https://console.firebase.google.com/)
2. **Firestore Database** → אוסף `users`
3. וודא שיש שדה `fcmToken` למשתמש שלך

---

## שלב 4: שינוי זמני הנוטיפיקציות

אם אתה רוצה לשנות את הזמנים, ערוך את `functions/index.js`:

### רביעי ב-9:30
```javascript
exports.wednesdayReminder = functions.pubsub
  .schedule('30 9 * * 3') // 30 דקות, 9 שעות, כל רביעי
  .timeZone('Asia/Jerusalem')
```

### שבת ב-9:30
```javascript
exports.saturdayReminder = functions.pubsub
  .schedule('30 9 * * 6') // 30 דקות, 9 שעות, כל שבת
  .timeZone('Asia/Jerusalem')
```

### פורמט Cron:
```
* * * * *
│ │ │ │ │
│ │ │ │ └─ יום בשבוע (0-6, 0=ראשון, 6=שבת)
│ │ │ └─── חודש (1-12)
│ │ └───── יום בחודש (1-31)
│ └─────── שעה (0-23)
└───────── דקה (0-59)
```

דוגמאות:
- `30 9 * * 3` = כל רביעי ב-9:30
- `0 18 * * 5` = כל שישי ב-18:00
- `15 12 * * 1,4` = כל ראשון ורביעי ב-12:15

אחרי שינוי, הרץ שוב:
```bash
firebase deploy --only functions
```

---

## שלב 5: ניטור ולוגים

### צפייה בלוגים של Functions
```bash
firebase functions:log
```

או ב-[Firebase Console](https://console.firebase.google.com/):
- **Functions** → בחר function → **LOGS**

---

## שלב 6: בדיקה מיידית (לפני שמחכים ליום רביעי/שבת)

### 6.1 יצירת Function לבדיקה
הוסף ל-`functions/index.js`:

```javascript
exports.testNotification = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }

  const usersSnapshot = await admin.firestore()
    .collection('users')
    .where('fcmToken', '!=', null)
    .get();

  const tokens = [];
  usersSnapshot.forEach(doc => {
    const token = doc.data().fcmToken;
    if (token) tokens.push(token);
  });

  const payload = {
    notification: {
      title: 'בדיקת נוטיפיקציה',
      body: 'זו הודעת בדיקה מ-Firebase!',
      sound: 'default',
    },
  };

  const response = await admin.messaging().sendToDevice(tokens, payload);
  return { success: true, sent: response.successCount };
});
```

Deploy:
```bash
firebase deploy --only functions
```

### 6.2 קריאה ל-Function מהאפליקציה
הוסף כפתור בדשבורד:

```dart
import 'package:cloud_functions/cloud_functions.dart';

Future<void> _testFCMNotification() async {
  try {
    final functions = FirebaseFunctions.instance;
    final result = await functions.httpsCallable('testNotification').call();
    print('Sent notifications: ${result.data['sent']}');
  } catch (e) {
    print('Error: $e');
  }
}
```

---

## בעיות נפוצות

### 1. Token לא נשמר
- וודא שהמשתמש מחובר (`FirebaseAuth.instance.currentUser != null`)
- בדוק בלוג אם יש שגיאות

### 2. נוטיפיקציה לא מגיעה
- וודא שההרשאות ל-notifications מופעלות בטלפון
- בדוק ש-FCM token נשמר ב-Firestore
- צפה בלוגים של ה-Function

### 3. Functions לא רצים בזמן המתוזמן
- וודא ש-timezone נכון (`Asia/Jerusalem`)
- בדוק ב-Firebase Console → Functions שה-Functions deployed
- צפה בלוגים

---

## עלויות

- **Firebase Functions**: חינמי עד 125K קריאות/חודש
- **FCM**: חינמי לחלוטין ללא הגבלה
- לפרויקט קטן כמו שלך - **לא תשלם כלום**!

---

## סיכום

✅ נוטיפיקציות אמינות גם כשהאפליקציה סגורה
✅ תזמון מדויק ללא תלות במערכת ההפעלה
✅ קל לניהול ושינוי זמנים
✅ חינמי לחלוטין

**בהצלחה! 🚀**
