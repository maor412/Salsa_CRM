# 🚀 Quick Start - App Icon & Splash Setup

## לוח זמנים מהיר - 3 שלבים בלבד!

### ⏱ שלב 1: יצירת לוגו (5 דקות)

**אופציה A - מהירה (Emoji):**
1. פתח: [`assets/icon/logo_preview.html`](assets/icon/logo_preview.html) בדפדפן
2. לחץ על 3 כפתורי "הורד PNG"
3. שמור ב-`assets/icon/`

**אופציה B - מקצועית (מומלץ):**
1. 🔗 פתח: https://icon.kitchen/
2. העלה תמונת תו מוזיקלי או השתמש ב-Material Icon "music_note"
3. בחר צבע: `#673AB7` (סגול)
4. הורד את כל הקבצים

---

### ⏱ שלב 2: הרצת סקריפט (2 דקות)

**Windows:**
```powershell
.\setup_icons.ps1
```

**Mac/Linux:**
```bash
./setup_icons.sh
```

**או ידנית:**
```bash
flutter pub get && flutter pub run flutter_launcher_icons && flutter pub run flutter_native_splash:create
```

---

### ⏱ שלב 3: בנייה והתקנה (3 דקות)

```bash
flutter clean
flutter run
```

---

## ✅ Checklist

- [ ] 3 קבצי PNG נוצרו ב-`assets/icon/`
- [ ] הרצת `flutter pub get`
- [ ] הרצת `flutter_launcher_icons`
- [ ] הרצת `flutter_native_splash:create`
- [ ] הרצת `flutter clean`
- [ ] התקנת האפליקציה מחדש
- [ ] בדיקת אייקון ב-Home Screen
- [ ] בדיקת Splash Screen

---

## 🔗 קישורים מהירים

| מסמך | תיאור |
|------|--------|
| [`ICON_SETUP_SUMMARY.md`](ICON_SETUP_SUMMARY.md) | סיכום מלא של כל השינויים |
| [`SETUP_APP_ICON_AND_SPLASH.md`](SETUP_APP_ICON_AND_SPLASH.md) | מדריך מפורט שלב-אחר-שלב |
| [`assets/icon/README_LOGO_CREATION.md`](assets/icon/README_LOGO_CREATION.md) | הנחיות ליצירת לוגו |
| [`assets/icon/logo_preview.html`](assets/icon/logo_preview.html) | תצוגה מקדימה והורדה |

---

## 🎨 עיצוב

- **צבע לוגו**: `#673AB7` (deepPurple)
- **רקע אייקון**: `#FFFFFF` (לבן)
- **רקע Splash**: `#FFFFFF` (לבן)
- **אייקון**: תו מוזיקלי 🎵

---

## ❓ שאלות נפוצות

**Q: כמה זמן זה לוקח?**
A: 10-15 דקות בסך הכל

**Q: צריך להיות מעצב?**
A: לא! השתמש בכלים אוטומטיים או ב-emoji

**Q: מה אם האייקון לא מתעדכן?**
A: מחק את האפליקציה ← `flutter clean` ← `flutter run`

---

**זה הכל!** 🎉

פתח את [`SETUP_APP_ICON_AND_SPLASH.md`](SETUP_APP_ICON_AND_SPLASH.md) למדריך המלא.
