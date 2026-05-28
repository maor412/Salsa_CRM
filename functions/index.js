const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const {logger} = require("firebase-functions/v2");

admin.initializeApp();

const GEMINI_MODEL = process.env.GEMINI_MODEL || "gemini-2.5-flash";
const GEMINI_API_URL =
  `https://generativelanguage.googleapis.com/v1beta/models/` +
  `${GEMINI_MODEL}:generateContent`;

const CATEGORY_LABELS = {
  regular: "היום ביילה",
  pace: "שיעור קצב",
  afro: "שיעור אפרו",
  pachanga: "שיעור פצ'אנגה",
  laPrep: "הכנה ל-LA",
  shines: "הפלות",
};

/**
 * Normalizes a short string passed from the client.
 * @param {*} value Raw value from the callable payload.
 * @param {string} fallback Value to use when the raw value is not a string.
 * @return {string} Trimmed and length-limited string.
 */
function cleanString(value, fallback = "") {
  if (typeof value !== "string") {
    return fallback;
  }
  return value.trim().slice(0, 200);
}

/**
 * Normalizes birthday names passed from the client.
 * @param {*} value Raw birthday names value from the callable payload.
 * @return {string[]} Up to five non-empty names.
 */
function cleanBirthdayNames(value) {
  if (!Array.isArray(value)) {
    return [];
  }
  return value
      .filter((name) => typeof name === "string")
      .map((name) => name.trim())
      .filter(Boolean)
      .slice(0, 5);
}

/**
 * Builds the Hebrew prompt used for WhatsApp salsa message generation.
 * @param {Object} data Callable payload from the Flutter app.
 * @param {string} retryReason Optional retry instruction when output was short.
 * @return {string} Prompt for Gemini.
 */
function buildSalsaPrompt(data, retryReason = "") {
  const category = cleanString(data.category, "regular");
  const categoryName =
    cleanString(data.categoryName) ||
    CATEGORY_LABELS[category] ||
    CATEGORY_LABELS.regular;
  const senderName = cleanString(data.senderName, "הצוות");
  const tone = cleanString(data.tone, "קליל, אנרגטי, חברי");
  const maxLength = Number.isInteger(data.maxLength) ?
    Math.min(Math.max(data.maxLength, 120), 900) :
    550;
  const minLength = Number.isInteger(data.minLength) ?
    Math.min(Math.max(data.minLength, 120), maxLength) :
    260;
  const birthdayNames = cleanBirthdayNames(data.birthdayNames);
  const today = new Intl.DateTimeFormat("he-IL", {
    timeZone: "Asia/Jerusalem",
    weekday: "long",
  }).format(new Date());

  const birthdayLine = birthdayNames.length > 0 ?
    birthdayNames.join(", ") :
    "אין";

  return [
    "אתה כותב הודעות WhatsApp קצרות בעברית לקבוצת תלמידי סלסה.",
    "",
    "כתוב הודעה אחת בלבד, אבל מלאה ומוכנה לשליחה.",
    `סגנון: ${tone}.`,
    `אורך רצוי: בין ${minLength} ל-${maxLength} תווים.`,
    "מבנה רצוי: פתיחה חמה, משפט על השיעור, הזמנה להגיע לרקוד, וסיום קצר.",
    "כתוב 3 עד 5 שורות קצרות שמתאימות ל-WhatsApp.",
    "הטקסט חייב להיות הודעה שלמה, לא התחלה של משפט ולא ציטוט קצר.",
    "אל תעצור אחרי שורה אחת.",
    "אל תכתוב הסברים, כותרות או כמה אפשרויות.",
    "אל תמציא שעה, מיקום, מחיר או שם סטודיו אם הם לא נמסרו.",
    "אפשר להשתמש באימוג'ים במידה, אבל לא להגזים.",
    "ההודעה צריכה להרגיש טבעית לקבוצת WhatsApp.",
    "אל תענה במילים בודדות. אל תכתוב רק סלוגן.",
    "",
    "פרטים:",
    `יום: ${today}`,
    `סוג שיעור: ${categoryName}`,
    `שם שולח: ${senderName}`,
    `ימי הולדת לציון: ${birthdayLine}`,
    birthdayNames.length > 0 ?
      "אם יש ימי הולדת לציון, חובה לשלב בהודעה משפט יום הולדת " +
      "טבעי עם השמות שמופיעים למעלה." :
      "אין ימי הולדת לציון, אל תכתוב ברכת יום הולדת.",
    "אל תכתוב placeholders או משתנים כמו {{BIRTHDAY_BLOCK}}.",
    "ניסוח יום ההולדת חייב להיות ניטרלי מגדרית וללא סימן / בכלל.",
    "אל תכתוב חוגג/ת, רוקד/ת, בא/ה או כל צורה עם לוכסן.",
    "השתמש בניסוח כמו: \"היום חוגגים יום הולדת ל___\".",
    "אפשר להזכיר שעושים מעגל ושכולם יבואו בכל הכוח, " +
      "אבל בלי ניסוח שמניח זכר או נקבה.",
    "",
    "דוגמה לאורך ולמבנה בלבד, אל תעתיק אותה:",
    "היי כולם 💃",
    "היום נפגשים לעוד ערב של סלסה, אנרגיות טובות ורחבה מלאה.",
    "נמשיך לעבוד על התנועה, הקצב והחיבור בין כולם.",
    "תגיעו עם מצב רוח לרקוד, נתראה על הרחבה!",
    "",
    retryReason ? `שים לב: ${retryReason}` : "",
    retryReason ? "" : "",
    "אם יש ימי הולדת, שלב ברכה קצרה בסוף ההודעה.",
    "סיים בקריאה טבעית להגיע לרקוד.",
  ].join("\n");
}

/**
 * Reads the desired minimum message length from callable payload.
 * @param {Object} data Callable payload from the Flutter app.
 * @return {number} Minimum accepted generated message length.
 */
function getMinLength(data) {
  return Number.isInteger(data.minLength) ?
    Math.min(Math.max(data.minLength, 120), 900) :
    260;
}

/**
 * Extracts the first text answer from a Gemini generateContent response.
 * @param {Object} responseJson Parsed Gemini API response.
 * @return {string} Generated message text, or an empty string.
 */
function extractGeminiText(responseJson) {
  const candidates = responseJson && responseJson.candidates;
  const firstCandidate = Array.isArray(candidates) && candidates[0];
  const content = firstCandidate && firstCandidate.content;
  const parts = content && content.parts;
  if (!Array.isArray(parts)) {
    return "";
  }
  return parts
      .map((part) => typeof part.text === "string" ? part.text : "")
      .join("")
      .trim();
}

/**
 * Removes template leftovers and guarantees birthday text when needed.
 * @param {string} message Generated message.
 * @param {Object} payload Callable payload.
 * @return {string} Safe message to return to the app.
 */
function finalizeSalsaMessage(message, payload) {
  const cleanMessage = String(message || "")
      .replace(/\{\{BIRTHDAY_BLOCK\}\}/g, "")
      .trim();
  const birthdayNames = cleanBirthdayNames(payload.birthdayNames);
  if (birthdayNames.length === 0) {
    return cleanMessage;
  }

  const mentionsBirthday = cleanMessage.includes("יום הולדת");
  if (mentionsBirthday) {
    return cleanMessage;
  }

  const birthdayText = birthdayNames.length === 1 ?
    `היום חוגגים יום הולדת ל${birthdayNames[0]}, ` +
      `עושים מעגל ומרימים באנרגיות. תבואו בכל הכוח!` :
    `היום חוגגים יום הולדת ל${birthdayNames.join(", ")}, ` +
      `עושים מעגלים ומרימים באנרגיות. תבואו בכל הכוח!`;

  return `${cleanMessage}\n\n${birthdayText}`.trim();
}

/**
 * Builds a deterministic WhatsApp message when Gemini is unavailable.
 * @param {Object} payload Callable payload.
 * @return {string} Ready-to-send fallback message.
 */
function buildFallbackSalsaMessage(payload) {
  const category = cleanString(payload.category, "regular");
  const categoryName =
    cleanString(payload.categoryName) ||
    CATEGORY_LABELS[category] ||
    CATEGORY_LABELS.regular;
  const today = new Intl.DateTimeFormat("he-IL", {
    timeZone: "Asia/Jerusalem",
    weekday: "long",
  }).format(new Date());

  const message = [
    "היי כולם 💃",
    `היום ${today} נפגשים לשיעור ${categoryName},`,
    "עם אנרגיות טובות והרבה תנועה.",
    "נמשיך לעבוד על הקצב, החיבור והכיף של הסלסה.",
    "תבואו עם מצב רוח לרקוד, נתראה על הרחבה!",
  ].join("\n");

  return finalizeSalsaMessage(message, payload);
}

/**
 * Calls Gemini and returns the raw generated message text.
 * @param {string} apiKey Gemini API key.
 * @param {string} prompt Prompt to send.
 * @return {Promise<string>} Generated text.
 */
async function callGemini(apiKey, prompt) {
  const response = await fetch(GEMINI_API_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-goog-api-key": apiKey,
    },
    body: JSON.stringify({
      contents: [
        {
          role: "user",
          parts: [{text: prompt}],
        },
      ],
      generationConfig: {
        temperature: 0.9,
        topP: 0.95,
        maxOutputTokens: 700,
        thinkingConfig: {
          thinkingBudget: 0,
        },
      },
    }),
  });

  const responseJson = await response.json();
  if (!response.ok) {
    logger.error("Gemini API error", {
      status: response.status,
      body: responseJson,
    });
    throw new HttpsError(
        "resource-exhausted",
        "Gemini could not generate a message right now.",
    );
  }

  const message = extractGeminiText(responseJson);
  const finishReason = responseJson &&
    responseJson.candidates &&
    responseJson.candidates[0] &&
    responseJson.candidates[0].finishReason;

  logger.info("Gemini message generated", {
    length: message.length,
    finishReason: finishReason || "UNKNOWN",
    model: GEMINI_MODEL,
  });

  return message;
}

exports.generateSalsaMessage = onCall(
    {
      region: "us-central1",
      timeoutSeconds: 45,
      memory: "256MiB",
      secrets: ["GEMINI_API_KEY"],
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError(
            "unauthenticated",
            "You must be signed in to generate a message.",
        );
      }

      const apiKey = process.env.GEMINI_API_KEY;
      if (!apiKey) {
        throw new HttpsError(
            "failed-precondition",
            "GEMINI_API_KEY is not configured for Firebase Functions.",
        );
      }

      const payload = request.data || {};
      const minLength = getMinLength(payload);
      const prompt = buildSalsaPrompt(payload);

      try {
        let message = await callGemini(apiKey, prompt);
        if (message.length < minLength) {
          const retryPrompt = buildSalsaPrompt(
              payload,
              `התגובה הקודמת היתה קצרה מדי (${message.length} תווים). ` +
              `כתוב הודעה מלאה של לפחות ${minLength} תווים.`,
          );
          message = await callGemini(apiKey, retryPrompt);
        }

        if (!message) {
          logger.error("Gemini returned an empty response");
          throw new HttpsError(
              "internal",
              "Gemini returned an empty message.",
          );
        }
        message = finalizeSalsaMessage(message, payload);

        return {
          message,
          model: GEMINI_MODEL,
        };
      } catch (error) {
        logger.error("Failed to generate Gemini message", error);
        const fallbackMessage = buildFallbackSalsaMessage(payload);
        return {
          message: fallbackMessage,
          model: `${GEMINI_MODEL}-fallback`,
          fallback: true,
        };
      }
    },
);

// תזכורת רביעי ב-22:50 (לבדיקה)
exports.wednesdayReminder = onSchedule(
    {
      schedule: "50 22 * * 3", // כל רביעי ב-22:50
      timeZone: "Asia/Jerusalem",
    },
    async (event) => {
      logger.info("🔔 Running Wednesday reminder...");

      try {
        // שליפת כל המשתמשים עם FCM token
        const usersSnapshot = await admin.firestore()
            .collection("users")
            .where("fcmToken", "!=", null)
            .get();

        const tokens = [];
        usersSnapshot.forEach((doc) => {
          const token = doc.data().fcmToken;
          if (token) {
            tokens.push(token);
            logger.info(`Found token for user: ${doc.id}`);
          }
        });

        logger.info(`Total tokens found: ${tokens.length}`);

        if (tokens.length === 0) {
          logger.info("No FCM tokens found");
          return null;
        }

        // הודעת תזכורת
        const payload = {
          notification: {
            title: "תזכורת לשליחת הודעה בקבוצה",
            body: "אל תשכח לשלוח הודעה בקבוצת ה-WhatsApp",
          },
          data: {
            type: "weekly_reminder",
            day: "wednesday",
          },
          android: {
            priority: "high",
            notification: {
              channelId: "weekly_reminders",
              sound: "default",
              priority: "high",
              defaultSound: true,
              defaultVibrateTimings: true,
            },
          },
        };

        // שליחת ההודעה לכל המכשירים
        const response = await admin.messaging()
            .sendEachForMulticast({tokens, ...payload});

        const successMsg =
          `✅ Wednesday notifications sent: ` +
          `${response.successCount} successful, ` +
          `${response.failureCount} failed`;
        logger.info(successMsg);

        return null;
      } catch (error) {
        logger.error("❌ Error sending notifications:", error);
        return null;
      }
    },
);

// תזכורת שבת ב-22:50 (לבדיקה)
exports.saturdayReminder = onSchedule(
    {
      schedule: "50 22 * * 6", // כל שבת ב-22:50
      timeZone: "Asia/Jerusalem",
    },
    async (event) => {
      logger.info("🔔 Running Saturday reminder...");

      try {
        // שליפת כל המשתמשים עם FCM token
        const usersSnapshot = await admin.firestore()
            .collection("users")
            .where("fcmToken", "!=", null)
            .get();

        const tokens = [];
        usersSnapshot.forEach((doc) => {
          const token = doc.data().fcmToken;
          if (token) {
            tokens.push(token);
            logger.info(`Found token for user: ${doc.id}`);
          }
        });

        logger.info(`Total tokens found: ${tokens.length}`);

        if (tokens.length === 0) {
          logger.info("No FCM tokens found");
          return null;
        }

        // הודעת תזכורת
        const payload = {
          notification: {
            title: "תזכורת לשליחת הודעה בקבוצה",
            body: "אל תשכח לשלוח הודעה בקבוצת ה-WhatsApp",
          },
          data: {
            type: "weekly_reminder",
            day: "saturday",
          },
          android: {
            priority: "high",
            notification: {
              channelId: "weekly_reminders",
              sound: "default",
              priority: "high",
              defaultSound: true,
              defaultVibrateTimings: true,
            },
          },
        };

        // שליחת ההודעה לכל המכשירים
        const response = await admin.messaging()
            .sendEachForMulticast({tokens, ...payload});

        const successMsg =
          `✅ Saturday notifications sent: ` +
          `${response.successCount} successful, ` +
          `${response.failureCount} failed`;
        logger.info(successMsg);

        return null;
      } catch (error) {
        logger.error("❌ Error sending notifications:", error);
        return null;
      }
    },
);

// בדיקת ימי הולדת - כל יום ב-22:50 (לבדיקה)
exports.birthdayCheck = onSchedule(
    {
      schedule: "50 22 * * *", // כל יום ב-22:50
      timeZone: "Asia/Jerusalem",
    },
    async (event) => {
      logger.info("🎂 Running birthday check...");

      try {
        // שליפת כל התלמידים הפעילים
        const studentsSnapshot = await admin.firestore()
            .collection("students")
            .where("isActive", "==", true)
            .get();

        if (studentsSnapshot.empty) {
          logger.info("No students found");
          return null;
        }

        // בדיקת תלמידים עם יום הולדת היום
        // קבלת התאריך הנוכחי ב-timezone ישראל
        const now = new Date();
        const israelDateParts = new Intl.DateTimeFormat("en-US", {
          timeZone: "Asia/Jerusalem",
          year: "numeric",
          month: "2-digit",
          day: "2-digit",
        }).formatToParts(now);

        const todayMonth = parseInt(
            israelDateParts.find((p) => p.type === "month").value,
        );
        const todayDay = parseInt(
            israelDateParts.find((p) => p.type === "day").value,
        );

        logger.info(
            `🗓️ Checking birthdays for: ${todayDay}/${todayMonth} ` +
          `(Israel time)`,
        );

        const birthdayStudents = [];
        studentsSnapshot.forEach((doc) => {
          const student = doc.data();
          if (student.birthday) {
            const birthday = student.birthday.toDate();
            // המרת יום ההולדת ל-timezone ישראל
            const birthdayDateParts = new Intl.DateTimeFormat("en-US", {
              timeZone: "Asia/Jerusalem",
              month: "2-digit",
              day: "2-digit",
            }).formatToParts(birthday);
            const birthdayMonth = parseInt(
                birthdayDateParts.find((p) => p.type === "month").value,
            );
            const birthdayDay = parseInt(
                birthdayDateParts.find((p) => p.type === "day").value,
            );

            if (birthdayMonth === todayMonth && birthdayDay === todayDay) {
              birthdayStudents.push({
                id: doc.id,
                name: student.name,
              });
              logger.info(`🎉 Birthday today: ${student.name}`);
            }
          }
        });

        if (birthdayStudents.length === 0) {
          logger.info("No birthdays today");
          return null;
        }

        logger.info(`Found ${birthdayStudents.length} birthdays today`);

        // שליפת כל המשתמשים עם FCM token
        const usersSnapshot = await admin.firestore()
            .collection("users")
            .where("fcmToken", "!=", null)
            .get();

        const tokens = [];
        usersSnapshot.forEach((doc) => {
          const token = doc.data().fcmToken;
          if (token) {
            tokens.push(token);
          }
        });

        logger.info(`Total FCM tokens: ${tokens.length}`);

        if (tokens.length === 0) {
          logger.info("No FCM tokens found");
          return null;
        }

        // שליחת נוטיפיקציה לכל תלמיד עם יום הולדת
        let totalSuccess = 0;
        let totalFailure = 0;

        for (const student of birthdayStudents) {
          const payload = {
            notification: {
              title: `🎂 יום הולדת - ${student.name}`,
              body:
                `ל${student.name} יום הולדת היום! ` +
                `אל תשכח לשלוח ברכה בקבוצת WhatsApp 🎉`,
            },
            data: {
              type: "birthday",
              studentId: student.id,
              studentName: student.name,
            },
            android: {
              priority: "high",
              notification: {
                channelId: "birthdays",
                sound: "default",
                priority: "high",
                defaultSound: true,
                defaultVibrateTimings: true,
              },
            },
          };

          // שליחה לכל המכשירים
          const response = await admin.messaging()
              .sendEachForMulticast({tokens, ...payload});

          totalSuccess += response.successCount;
          totalFailure += response.failureCount;

          logger.info(
              `🎂 Birthday notification for ${student.name}: ` +
            `${response.successCount} sent, ${response.failureCount} failed`,
          );
        }

        logger.info(
            `✅ Total birthday notifications: ` +
          `${totalSuccess} successful, ${totalFailure} failed`,
        );

        return null;
      } catch (error) {
        logger.error("❌ Error in birthday check:", error);
        return null;
      }
    },
);
