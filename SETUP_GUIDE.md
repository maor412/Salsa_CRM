# מדריך התקנה והגדרה מפורט - Salsa CRM

מדריך זה מספק הוראות צעד אחר צעד להתקנה, הגדרה והרצה של אפליקציית Salsa CRM.

## תוכן עניינים

1. [הכנת הסביבה](#1-הכנת-הסביבה)
2. [הגדרת Firebase](#2-הגדרת-firebase)
3. [הגדרת הפרויקט](#3-הגדרת-הפרויקט)
4. [יצירת משתמשים](#4-יצירת-משתמשים)
5. [הוספת תבניות](#5-הוספת-תבניות)
6. [בנייה והפצה](#6-בנייה-והפצה)

---

## 1. הכנת הסביבה

### Windows

1. התקן את Flutter:
   - הורד מ-https://flutter.dev/docs/get-started/install/windows
   - חלץ לתיקייה (למשל `C:\src\flutter`)
   - הוסף את הנתיב ל-PATH
   - הרץ `flutter doctor` לבדיקה

2. התקן Android Studio:
   - הורד מ-https://developer.android.com/studio
   - התקן Android SDK
   - צור Android Emulator

3. התקן Git:
   - הורד מ-https://git-scm.com/download/win

4. התקן Node.js (ל-Firebase CLI):
   - הורד מ-https://nodejs.org/

### macOS

1. התקן Flutter:
   ```bash
   cd ~/development
   unzip ~/Downloads/flutter_macos_*.zip
   export PATH="$PATH:`pwd`/flutter/bin"
   ```

2. התקן Xcode (ל-iOS):
   - הורד מה-App Store
   - הרץ:
   ```bash
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -runFirstLaunch
   ```

3. התקן CocoaPods:
   ```bash
   sudo gem install cocoapods
   ```

### בדיקת התקנה

```bash
flutter doctor
```

תוצאה מצופה:
```
[✓] Flutter (Channel stable, 3.x.x)
[✓] Android toolchain
[✓] Xcode (אם macOS)
[✓] VS Code / Android Studio
[✓] Connected device
```

---

## 2. הגדרת Firebase

### א. יצירת פרויקט Firebase

1. היכנס ל-https://console.firebase.google.com/
2. לחץ על "Add project"
3. הזן שם: `salsa-crm` (או שם אחר)
4. בחר אם להשתמש ב-Google Analytics (לא חובה)
5. לחץ "Create project"

### ב. הוספת אפליקציות

#### Android App

1. בקונסול Firebase, לחץ על "Add app" > Android
2. הזן:
   - **Package name**: `com.salsateam.crm`
   - **App nickname**: `Salsa CRM Android`
3. הורד את `google-services.json`
4. העתק ל-`android/app/google-services.json`

#### iOS App (אופציונלי)

1. לחץ על "Add app" > iOS
2. הזן:
   - **Bundle ID**: `com.salsateam.crm`
   - **App nickname**: `Salsa CRM iOS`
3. הורד את `GoogleService-Info.plist`
4. העתק ל-`ios/Runner/GoogleService-Info.plist`

### ג. הפעלת שירותים

#### Authentication

1. עבור ל-**Build** > **Authentication**
2. לחץ "Get started"
3. ב-**Sign-in method**, הפעל:
   - **Email/Password** ✓

#### Cloud Firestore

1. עבור ל-**Build** > **Firestore Database**
2. לחץ "Create database"
3. בחר **Production mode**
4. בחר מיקום (למשל `europe-west1`)

5. עבור ל-**Rules** והעתק:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isAuthenticated() {
      return request.auth != null;
    }

    function isAdmin() {
      return isAuthenticated() &&
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }

    match /users/{userId} {
      allow read: if isAuthenticated();
      allow write: if isAdmin();
    }

    match /students/{studentId} {
      allow read, write: if isAuthenticated();
    }

    match /attendanceSessions/{sessionId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated();
      allow update, delete: if isAdmin();
    }

    match /attendanceRecords/{recordId} {
      allow read, write: if isAuthenticated();
    }

    match /exercises/{exerciseId} {
      allow read, write: if isAuthenticated();
    }

    match /messageTemplates/{templateId} {
      allow read: if isAuthenticated();
      allow write: if isAdmin();
    }

    match /messageEvents/{eventId} {
      allow read, write: if isAuthenticated();
    }

    match /settings/{doc} {
      allow read: if isAuthenticated();
      allow write: if isAdmin();
    }
  }
}
```

6. לחץ "Publish"

#### Cloud Messaging (FCM)

1. עבור ל-**Build** > **Cloud Messaging**
2. ב-Android: לא נדרש שום דבר נוסף
3. ב-iOS: העלה APNs Key (ראה מדריך Firebase)

---

## 3. הגדרת הפרויקט

### א. התקנת CLI Tools

```bash
# Firebase CLI
npm install -g firebase-tools

# FlutterFire CLI
dart pub global activate flutterfire_cli
```

### ב. התחברות ל-Firebase

```bash
firebase login
```

### ג. הגדרת Flutter Project

```bash
cd Salsa_managment_app

# התקנת תלויות
flutter pub get

# הגדרת Firebase
flutterfire configure
```

בחר:
- הפרויקט שיצרת (`salsa-crm`)
- פלטפורמות: Android (ו-iOS אם רלוונטי)

זה ייצור אוטומטית את `lib/firebase_options.dart`.

---

## 4. יצירת משתמשים

### א. יצירת משתמש אדמין ראשון

**דרך 1: דרך הקונסול (מומלץ)**

1. עבור ל-**Authentication** > **Users**
2. לחץ "Add user"
3. הזן:
   - Email: `admin@salsateam.com`
   - Password: `Admin123!` (שנה אחר כך)
4. לחץ "Add user"
5. **העתק את ה-User UID**

6. עבור ל-**Firestore Database**
7. צור Collection חדש: `users`
8. צור Document עם ה-UID שהעתקת:

```javascript
{
  email: "admin@salsateam.com",
  name: "Admin",
  role: "admin",
  createdAt: [Timestamp - לחץ על השעון ובחר "now"],
  isActive: true
}
```

**דרך 2: דרך האפליקציה**

אפשר להוסיף בקוד פונקציה זמנית ליצירת אדמין בפעם הראשונה (לא מומלץ לפרודקשן).

### ב. הוספת מדריכים נוספים

לאחר התחברות כאדמין, ניתן ליצור משתמשים חדשים דרך האפליקציה (תכונה עתידית) או דרך הקונסול.

---

## 5. הוספת תבניות

### א. הוספת תבניות ראשוניות

התחבר כאדמין ועבור למסך "ניהול":

**תבנית 1 - היום ביילה (רגיל)**
```
היי חברים! 🎵

{{BIRTHDAY_BLOCK}}

היום ביילה בשעה 21:00! מחכים לכם עם אנרגיות טובות 🔥

הערה: מזג אויר מעולה לריקודים 😎

נתראה,
{{SENDER_NAME}}
```

**תבנית 2 - שיעור קצב**
```
שלום לכם! 🎶

{{BIRTHDAY_BLOCK}}

הערב שיעור קצב מיוחד!
נתרגל שמיעה, ספירה ותזמון 👂🕺

שעה: 21:00
מקום: הסטודיו

{{SENDER_NAME}}
```

**תבנית 3 - שיעור אפרו**
```
Hola amigos! 💃

{{BIRTHDAY_BLOCK}}

הערב - אפרו-קובני!
קצב, אנרגיה וכיף מובטח 🔥

21:00 בסטודיו

{{SENDER_NAME}}
```

### ב. כללים לכתיבת תבניות

- **חובה** להשתמש ב-`{{BIRTHDAY_BLOCK}}` ו-`{{SENDER_NAME}}`
- השתמש באימוג'ים בזהירות
- שמור על סגנון קצר וידידותי
- ודא שהשעה והמיקום נכונים

---

## 6. בנייה והפצה

### א. בדיקה לפני בנייה

```bash
# ניקוי
flutter clean
flutter pub get

# בדיקת שגיאות
flutter analyze

# הרצה במצב דבאג
flutter run --debug
```

### ב. בנייה ל-Release

#### Android APK

```bash
flutter build apk --release
```

הקובץ יהיה ב:
```
build/app/outputs/flutter-apk/app-release.apk
```

#### Android App Bundle (לחנות - לא רלוונטי כאן)

```bash
flutter build appbundle --release
```

#### iOS

```bash
flutter build ios --release
```

### ג. חתימה (Signing) - אופציונלי

#### Android

1. צור keystore:
```bash
keytool -genkey -v -keystore ~/salsa-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias salsa
```

2. צור `android/key.properties`:
```properties
storePassword=<password>
keyPassword=<password>
keyAlias=salsa
storeFile=<path-to-keystore>
```

3. ערוך `android/app/build.gradle` להשתמש ב-keystore.

#### iOS

- השתמש ב-Xcode לניהול Certificates ו-Provisioning Profiles
- או השתמש ב-fastlane

### ד. הפצה למכשירים

#### Android

**דרך USB:**
```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

**דרך קישור:**
1. העלה את ה-APK ל-Google Drive / Dropbox
2. שתף קישור עם הצוות
3. התקן מהמכשיר (אפשר "מקורות לא ידועים")

#### iOS

**דרך TestFlight:**
1. צור App ב-App Store Connect
2. העלה Build
3. הזמן את הצוות ב-TestFlight

**דרך Enterprise Distribution:**
- דורש Apple Developer Enterprise account

---

## שאלות נפוצות

### ש: מה עושים אם שכחתי סיסמת אדמין?

**תשובה:** איפוס דרך Firebase Console:
1. Authentication > Users
2. מצא את המשתמש
3. לחץ על ⋮ > Reset password
4. שלח לינק לאימייל

### ש: איך מוסיפים תלמידים?

**תשובה:** כרגע אין UI להוספת תלמידים. אפשר:
1. להוסיף ידנית ב-Firestore Console
2. לפתח מסך ניהול תלמידים (עדכון עתידי)

### ש: איך מגדירים קישור לקבוצת WhatsApp?

**תשובה:**
1. Firestore Console
2. Collection: `settings`
3. Document: `whatsapp`
4. שדה: `groupLink` = `https://chat.whatsapp.com/...`

### ש: ההתראות לא עובדות

**תשובה:**
- Android: ודא ש-`google-services.json` במקום
- iOS: ודא הגדרת APNs
- בדוק הרשאות במכשיר

---

## תמיכה טכנית

לבעיות ושאלות:
- צור Issue בגיטהאב
- פנה למפתח הראשי
- בדוק ב-Firebase Console > Usage לשגיאות

---

**בהצלחה! 🎉**
