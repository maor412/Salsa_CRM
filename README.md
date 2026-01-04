# Salsa CRM - מערכת CRM לצוות מדריכי סלסה

אפליקציה פנימית לניהול צוות מדריכי סלסה, כולל ניהול תלמידים, נוכחות, תרגילים ושליחת הודעות WhatsApp.

## טכנולוגיות

- **Framework**: Flutter
- **Backend**: Firebase (Firestore, Authentication, Cloud Functions, FCM)
- **State Management**: Provider
- **Platform**: Android + iOS
- **שפה**: עברית (RTL)

## תכונות עיקריות

### 1. דשבורד CRM
- גרפים ונתונים סטטיסטיים
- אחוז הגעה לשיעור האחרון
- מעקב אחר תלמידים עם 3 היעדרויות רצופות
- התקדמות בתרגילים
- התראות חכמות
- רשימת ימי הולדת

### 2. שליחת הודעות WhatsApp
- מערכת תבניות הודעות
- בחירה רנדומלית מתבניות
- עריכה ידנית של הודעות
- מנגנון נעילה (Lock) לאירועי הודעה
- הוספה אוטומטית של ברכות יום הולדת
- Placeholders דינמיים: `{{BIRTHDAY_BLOCK}}`, `{{SENDER_NAME}}`
- התראות אוטומטיות לימי רביעי ומוצ"ש

### 3. ניהול תרגילים
- רשימת 15 תרגילי סלסה מוגדרים מראש
- מעקב אחר התקדמות
- תצוגת "תרגילים לשיעור הבא"
- חזרה על תרגילים קודמים
- עדכון אוטומטי של אחוז ההתקדמות

### 4. רישום נוכחות
- רישום נוכחות מהיר
- חיפוש תלמידים
- בחירת סוג שיעור (רגיל, קצב, אפרו, פצ'אנגה, LA, הפלות)
- סטטיסטיקה בזמן אמת
- חישוב אחוזי נוכחות ורצפי היעדרויות

### 5. ניהול הודעות (Admin)
- הוספה, עריכה והשבתה של תבניות
- ניהול קטגוריות הודעות
- שמירה במאגר נתונים (לא Excel)

## דרישות מקדימות

### כלים נדרשים
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.0.0+)
- [Firebase CLI](https://firebase.google.com/docs/cli)
- [FlutterFire CLI](https://firebase.flutter.dev/docs/cli)
- Android Studio / VS Code
- Git

### התקנת כלים

```bash
# התקנת Flutter - עקוב אחרי ההוראות באתר הרשמי
# https://flutter.dev/docs/get-started/install

# התקנת Firebase CLI
npm install -g firebase-tools

# התקנת FlutterFire CLI
dart pub global activate flutterfire_cli
```

## התקנה והגדרה

### 1. שכפול הפרויקט

```bash
git clone <repository-url>
cd Salsa_managment_app
```

### 2. התקנת תלויות

```bash
flutter pub get
```

### 3. הגדרת Firebase

#### א. יצירת פרויקט Firebase

1. היכנס ל-[Firebase Console](https://console.firebase.google.com/)
2. צור פרויקט חדש
3. הפעל את השירותים הבאים:
   - **Authentication** (Email/Password)
   - **Cloud Firestore**
   - **Cloud Functions**
   - **Cloud Messaging** (FCM)

#### ב. הגדרת Firestore Security Rules

העתק את הכללים הבאים ב-Firestore Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }

    function isAdmin() {
      return isAuthenticated() &&
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }

    // Users collection
    match /users/{userId} {
      allow read: if isAuthenticated();
      allow write: if isAdmin();
    }

    // Students collection
    match /students/{studentId} {
      allow read, write: if isAuthenticated();
    }

    // Attendance collections
    match /attendanceSessions/{sessionId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated();
      allow update, delete: if isAdmin();
    }

    match /attendanceRecords/{recordId} {
      allow read, write: if isAuthenticated();
    }

    // Exercises collection
    match /exercises/{exerciseId} {
      allow read, write: if isAuthenticated();
    }

    // Message templates
    match /messageTemplates/{templateId} {
      allow read: if isAuthenticated();
      allow write: if isAdmin();
    }

    // Message events
    match /messageEvents/{eventId} {
      allow read, write: if isAuthenticated();
    }

    // Settings
    match /settings/{doc} {
      allow read: if isAuthenticated();
      allow write: if isAdmin();
    }
  }
}
```

#### ג. הגדרת האפליקציה ב-Firebase

```bash
# התחבר ל-Firebase
firebase login

# הגדר את הפרויקט
flutterfire configure
```

הפקודה תיצור אוטומטית את הקובץ `lib/firebase_options.dart` עם כל ההגדרות הנדרשות.

### 4. הוספת משתמש אדמין ראשון

לאחר הרצת האפליקציה בפעם הראשונה, צור משתמש אדמין ב-Firebase Console:

1. היכנס ל-**Authentication** > **Users**
2. הוסף משתמש חדש עם אימייל וסיסמה
3. העתק את ה-UID
4. היכנס ל-**Firestore Database**
5. צור document חדש ב-collection `users` עם ה-UID כמזהה:

```json
{
  "email": "admin@example.com",
  "name": "Admin",
  "role": "admin",
  "createdAt": <timestamp>,
  "isActive": true
}
```

### 5. הוספת תבניות הודעות ראשוניות

לאחר התחברות עם משתמש אדמין:

1. לחץ על **ניהול** בתפריט התחתון
2. לחץ על **הוסף תבנית חדשה**
3. בחר קטגוריה והזן תוכן הודעה

דוגמה לתבנית:

```
היי חברים! 🎵

{{BIRTHDAY_BLOCK}}

היום ביילה בשעה 21:00!
מחכים לכם עם אנרגיות 🔥

נתראה,
{{SENDER_NAME}}
```

## הרצת האפליקציה

### בפיתוח

```bash
# בדיקת מכשירים זמינים
flutter devices

# הרצה על Android
flutter run

# הרצה על iOS
flutter run

# הרצה עם hot reload
flutter run --debug
```

### בנייה לפרסום

#### Android (APK)

```bash
flutter build apk --release
```

הקובץ יהיה ב: `build/app/outputs/flutter-apk/app-release.apk`

#### Android (App Bundle)

```bash
flutter build appbundle --release
```

#### iOS

```bash
flutter build ios --release
```

### התקנה ישירה (בלי חנויות)

#### Android
1. העבר את קובץ ה-APK למכשיר
2. אפשר התקנה מ-"מקורות לא ידועים" בהגדרות
3. פתח את הקובץ והתקן

#### iOS
1. השתמש ב-[TestFlight](https://developer.apple.com/testflight/) לחלוקה פנימית
2. או השתמש ב-Apple Developer Enterprise Program

## הגדרות נוספות

### התראות Push

#### Android
1. הורד את `google-services.json` מ-Firebase Console
2. העתק ל-`android/app/`

#### iOS
1. הורד את `GoogleService-Info.plist` מ-Firebase Console
2. העתק ל-`ios/Runner/`
3. הגדר capabilities ב-Xcode:
   - Push Notifications
   - Background Modes > Remote notifications

### קישורי WhatsApp לקבוצות

כרגע, קישורי הקבוצות צריכים להיות מוגדרים ידנית בקוד או ב-Firestore.

אפשרות להוסיף ב-Firestore:

```javascript
// Collection: settings
// Document: whatsapp
{
  "groupLink": "https://chat.whatsapp.com/YOUR_GROUP_INVITE_LINK"
}
```

## מבנה הפרויקט

```
lib/
├── config/           # הגדרות Firebase
├── models/           # מודלי נתונים
├── providers/        # State management (Provider)
├── screens/          # מסכי האפליקציה
│   ├── admin/       # מסכי אדמין
│   ├── dashboard_screen.dart
│   ├── message_builder_screen.dart
│   ├── exercises_screen.dart
│   └── attendance_screen.dart
├── services/         # שירותים (Firebase, Notifications)
├── widgets/          # ווידג'טים משותפים
├── utils/            # פונקציות עזר
└── main.dart         # נקודת כניסה
```

## שימוש באפליקציה

### התחברות
1. הזן אימייל וסיסמה של משתמש רשום
2. לחץ על "התחבר"

### דשבורד
- צפה בסטטיסטיקות עדכניות
- קבל התראות על בעיות
- בדוק ימי הולדת קרובים

### שליחת הודעה
1. בימי רביעי ומוצ"ש תופיע התראה
2. לחץ על "אני שולח!" לנעילת האירוע
3. תיווצר הודעה רנדומלית
4. ערוך את ההודעה לפי הצורך
5. לחץ על "העתק" או "פתח WhatsApp"
6. שלח בקבוצה

### ניהול תרגילים
1. סמן תרגילים כמושלמים
2. צפה בתרגילים הבאים לשיעור
3. עקוב אחר אחוז ההתקדמות

### רישום נוכחות
1. בחר סוג שיעור
2. סמן תלמידים שהגיעו
3. לחץ על "סיום ושמירה"

### ניהול תבניות (Admin)
1. הוסף תבניות חדשות
2. ערוך תבניות קיימות
3. השבת תבניות לא רלוונטיות

## פתרון בעיות נפוצות

### שגיאת Firebase initialization
```
הרץ: flutterfire configure
```

### בעיות עם Gradle (Android)
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
```

### בעיות עם Pods (iOS)
```bash
cd ios
pod deintegrate
pod install
cd ..
flutter clean
flutter pub get
```

### שגיאת הרשאות
- ודא שהגדרת את Firestore Security Rules
- בדוק שהמשתמש קיים ב-collection `users`

## תמיכה ופידבק

לבעיות, שאלות או הצעות לשיפור - צור Issue בגיטהאב או פנה לצוות הפיתוח.

## רישיון

פרויקט פנימי לשימוש הצוות בלבד.

---

**Built with ❤️ for the Salsa Team**
