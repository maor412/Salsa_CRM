const {onSchedule} = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const {logger} = require("firebase-functions/v2");

admin.initializeApp();

// תזכורת רביעי ב-9:30
exports.wednesdayReminder = onSchedule(
    {
      schedule: "30 9 * * 3", // כל רביעי ב-9:30
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

// תזכורת שבת ב-9:30
exports.saturdayReminder = onSchedule(
    {
      schedule: "30 9 * * 6", // כל שבת ב-9:30
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

// בדיקת ימי הולדת - כל יום ב-9:00
exports.birthdayCheck = onSchedule(
    {
      schedule: "0 9 * * *", // כל יום ב-9:00
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
        const today = new Date();
        const todayMonth = today.getMonth() + 1; // 1-12
        const todayDay = today.getDate(); // 1-31

        const birthdayStudents = [];
        studentsSnapshot.forEach((doc) => {
          const student = doc.data();
          if (student.birthday) {
            const birthday = student.birthday.toDate();
            const birthdayMonth = birthday.getMonth() + 1;
            const birthdayDay = birthday.getDate();

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
