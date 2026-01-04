# הנחיות ליצירת לוגו האפליקציה

## קבצים שיש ליצור:

### 1. app_icon.png
- **גודל**: 1024x1024 פיקסלים (מומלץ)
- **פורמט**: PNG עם רקע שקוף או לבן
- **תוכן**:
  - אייקון תו מוזיקלי (🎵) בצבע סגול (#673AB7 - deepPurple)
  - רקע: לבן (#FFFFFF)
  - מרכז את התו במרכז הקנבס
- **שימוש**: אייקון עיקרי לאפליקציה (iOS)

### 2. app_icon_foreground.png
- **גודל**: 1024x1024 פיקסלים
- **פורמט**: PNG עם רקע שקוף
- **תוכן**:
  - רק התו המוזיקלי בצבע סגול (#673AB7)
  - ללא רקע (שקוף)
  - עם Safe Zone של 20% מכל צד (התו צריך להיות במרכז 60% מהקנבס)
- **שימוש**: Adaptive Icon Foreground ל-Android

### 3. splash_logo.png
- **גודל**: 1200x1200 פיקסלים (מומלץ)
- **פורמט**: PNG עם רקע שקוף
- **תוכן**:
  - תו מוזיקלי בצבע סגול (#673AB7)
  - רקע שקוף (הרקע הלבן יוגדר ב-flutter_native_splash)
- **שימוש**: Splash Screen

## כלים מומלצים ליצירת הלוגו:

### אופציה 1: Figma / Adobe Illustrator
1. צור קנבס בגודל 1024x1024
2. הוסף אייקון תו מוזיקלי מ-Material Icons
3. צבע אותו בסגול #673AB7
4. ייצא כ-PNG

### אופציה 2: אתרים מקוונים
- **Canva**: https://www.canva.com/
- **Flaticon**: https://www.flaticon.com/ (חפש "music note")
- **Material Design Icons**: https://fonts.google.com/icons

### אופציה 3: שימוש ב-Flutter Icon Generator
- **App Icon Generator**: https://appicon.co/
- **Icon Kitchen**: https://icon.kitchen/

### אופציה 4: שימוש ב-AI
- **DALL-E / Midjourney**: "purple music note icon on white background, simple, minimalist, flat design"
- **Canva AI**: צור לוגו פשוט עם תו מוזיקלי סגול

## דוגמה לקוד צבע:
```
צבע סגול: #673AB7 (RGB: 103, 58, 183)
צבע רקע: #FFFFFF (RGB: 255, 255, 255)
```

## לאחר יצירת הקבצים:
1. שמור את הקבצים בתיקייה הזו: `assets/icon/`
2. ודא שהשמות זהים:
   - `app_icon.png`
   - `app_icon_foreground.png`
   - `splash_logo.png`
3. הרץ את הפקודות המופיעות ב-README הראשי

## הערות חשובות:
- ודא שהתמונות בעלות איכות גבוהה (לא מטושטשות)
- השתמש בפורמט PNG (לא JPG)
- עבור app_icon_foreground.png - חובה רקע שקוף
- השאר Safe Zone מספק ב-foreground (Android חותך את האייקון למעגל/מרובע מעוגל)
