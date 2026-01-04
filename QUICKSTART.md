# Quick Start - התחלה מהירה

מדריך התחלה מהיר ל-Salsa CRM.

## ⚡ התקנה מהירה (5 דקות)

### 1. דרישות
```bash
# ודא שיש לך Flutter
flutter --version

# אם אין, התקן מ:
# https://flutter.dev/docs/get-started/install
```

### 2. הורד את הפרויקט
```bash
cd path/to/Salsa_managment_app
flutter pub get
```

### 3. הגדר Firebase

```bash
# התקן CLI
npm install -g firebase-tools
dart pub global activate flutterfire_cli

# התחבר
firebase login

# הגדר
flutterfire configure
```

בחר פרויקט קיים או צור חדש.

### 4. הגדר Firestore

1. פתח [Firebase Console](https://console.firebase.google.com/)
2. בחר את הפרויקט שלך
3. **Authentication** > הפעל Email/Password
4. **Firestore Database** > Create database > Production mode
5. **Rules** > העתק מ-[README.md](README.md#ב-הגדרת-firestore-security-rules)

### 5. הוסף משתמש אדמין

Firebase Console:
1. **Authentication** > Add user
   - Email: `admin@test.com`
   - Password: `admin123`
2. העתק את ה-**UID**
3. **Firestore** > Create collection `users`
4. Add document (ה-UID):
```json
{
  "email": "admin@test.com",
  "name": "Admin",
  "role": "admin",
  "createdAt": <now>,
  "isActive": true
}
```

### 6. הרץ

```bash
flutter run
```

התחבר עם:
- Email: `admin@test.com`
- Password: `admin123`

---

## 🚀 שימוש מהיר

### הוספת תבנית הודעה

1. התחבר כאדמין
2. לחץ **ניהול** (למטה)
3. **הוסף תבנית חדשה**
4. הזן:
   ```
   היי! 🎵

   {{BIRTHDAY_BLOCK}}

   היום ביילה בשעה 21:00

   {{SENDER_NAME}}
   ```
5. שמור

### שליחת הודעה

1. לחץ **הודעות**
2. לחץ **צור הודעה חדשה**
3. ערוך לפי הצורך
4. **העתק** או **פתח WhatsApp**

### רישום נוכחות

1. לחץ **נוכחות**
2. בחר סוג שיעור
3. סמן מי הגיע
4. **סיום ושמירה**

### ניהול תרגילים

1. לחץ **תרגילים**
2. סמן V על תרגילים שבוצעו
3. האפליקציה תעדכן אוטומטית

---

## 📱 בנייה להפצה

### Android APK
```bash
flutter build apk --release
```
הקובץ: `build/app/outputs/flutter-apk/app-release.apk`

### שתף עם הצוות
1. העלה ל-Google Drive
2. שתף קישור
3. התקן על המכשירים

---

## 🔧 פתרון בעיות מהיר

### Firebase Error
```bash
flutterfire configure
```

### Build Error
```bash
flutter clean
flutter pub get
flutter run
```

### אין הרשאות
- ודא שיצרת document ב-`users` collection
- בדוק ש-ה-UID תואם ל-Authentication

---

## 📚 מסמכים נוספים

- [README.md](README.md) - מדריך מלא
- [SETUP_GUIDE.md](SETUP_GUIDE.md) - הגדרה מפורטת
- [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) - סיכום הפרויקט

---

**זה הכל! מוכנים לרקוד 💃🕺**
