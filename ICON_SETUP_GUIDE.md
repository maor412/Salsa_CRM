# מדריך הגדרת אייקון אפליקציה

## 📱 אופציה 1: שימוש באייקון קיים (מומלץ)

### שלב 1: יצירת תמונת אייקון

צור תמונת PNG בגודל **1024x1024 פיקסלים** עם:
- זוג רוקד בסגול (Deep Purple: #673AB7)
- רקע לבן נקי
- שמור את הקובץ בשם: `app_icon.png`

**כלים מומלצים**:
- Canva (חינם)
- Figma (חינם)
- Photoshop
- GIMP (חינם)

### שלב 2: הכנת הקבצים

1. צור תיקיות:
```bash
mkdir assets
mkdir assets\icon
```

2. שים את תמונת האייקון ב:
```
assets/icon/app_icon.png
```

3. צור גרסה עבור Adaptive Icon (אופציונלי):
```
assets/icon/app_icon_foreground.png
```

### שלב 3: הרצת הסקריפט

```bash
# התקנת התלויות
flutter pub get

# יצירת האייקונים
flutter pub run flutter_launcher_icons
```

---

## 🎨 אופציה 2: שימוש בכלי אונליין

### Canva (מומלץ למתחילים)

1. עבור ל-[Canva](https://www.canva.com)
2. צור עיצוב חדש: **1024x1024px**
3. הוסף אלמנט "זוג רוקד" או "ריקוד"
4. שנה צבע לסגול (#673AB7)
5. רקע לבן
6. הורד כ-PNG
7. שמור ב-`assets/icon/app_icon.png`

### Flaticon

1. עבור ל-[Flaticon](https://www.flaticon.com)
2. חפש: "dancing couple" או "salsa"
3. בחר אייקון
4. הורד ב-PNG 1024x1024
5. שנה צבע לסגול בעורך תמונות
6. שמור ב-`assets/icon/app_icon.png`

---

## 🚀 אופציה 3: שימוש ב-AI (מומלץ לאיכות גבוהה)

### DALL-E / Midjourney

פרומפט מוצע:
```
"Simple, minimalist icon of a dancing couple in deep purple color (#673AB7)
on white background, flat design, vector style, professional, app icon"
```

---

## 🔧 הגדרות מתקדמות

### Adaptive Icon (Android 8.0+)

אם ברצונך Adaptive Icon מותאם:

1. צור 2 תמונות:
   - `app_icon.png` - אייקון מלא (1024x1024)
   - `app_icon_foreground.png` - רק החלק המרכזי (1024x1024)

2. עדכן ב-`pubspec.yaml`:
```yaml
flutter_launcher_icons:
  android: true
  ios: false
  image_path: "assets/icon/app_icon.png"
  adaptive_icon_background: "#FFFFFF"
  adaptive_icon_foreground: "assets/icon/app_icon_foreground.png"
```

---

## ✅ בדיקה

לאחר הרצת הסקריפט, בדוק:

### Android
```
android/app/src/main/res/
  └── mipmap-hdpi/ic_launcher.png
  └── mipmap-mdpi/ic_launcher.png
  └── mipmap-xhdpi/ic_launcher.png
  └── mipmap-xxhdpi/ic_launcher.png
  └── mipmap-xxxhdpi/ic_launcher.png
```

### בניה והרצה
```bash
flutter clean
flutter pub get
flutter run
```

בדוק את האייקון במגירת האפליקציות של Android.

---

## 🎨 עיצוב מומלץ

### צבעים
- **סגול ראשי**: `#673AB7` (Deep Purple)
- **רקע**: `#FFFFFF` (לבן)
- **אופציונלי**: גוונים בהירים של סגול לצללים

### סגנון
- מינימליסטי
- וקטורי/שטוח
- ברור וקריא בגדלים קטנים
- ללא טקסט (רק אייקון)

### דוגמאות לאייקונים טובים
- זוג רוקד בצללית
- איש ואישה בתנוחת ריקוד
- זוג עם צללית דינמית
- סמל מופשט של ריקוד

---

## 🐛 פתרון בעיות

### שגיאה: "Cannot find image_path"
**פתרון**: ודא שהקובץ `assets/icon/app_icon.png` קיים.

### האייקון לא מתעדכן
**פתרון**:
```bash
flutter clean
flutter pub get
flutter pub run flutter_launcher_icons
flutter run
```

### גודל קובץ גדול מדי
**פתרון**: דחוס את התמונה ל-PNG עם איכות 80-90%.

---

## 📋 Checklist

- [ ] יצירת תמונת אייקון (1024x1024px)
- [ ] יצירת תיקייה `assets/icon/`
- [ ] שמירת `app_icon.png` בתיקייה
- [ ] הרצת `flutter pub get`
- [ ] הרצת `flutter pub run flutter_launcher_icons`
- [ ] בדיקת קבצי האייקון שנוצרו
- [ ] בניה והרצה של האפליקציה
- [ ] בדיקת האייקון במגירת האפליקציות

---

**בהצלחה! 🎨**
