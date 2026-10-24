const {onDocumentCreated} = require(
    "firebase-functions/v2/firestore",
);
const {setGlobalOptions} = require("firebase-functions/v2");
const admin = require("firebase-admin");

setGlobalOptions({region: "me-west1"});
admin.initializeApp();

// פונקציה אוטומטית שרצה ברגע שנוצר שיבוץ חדש בקולקציית assign
exports.sendAssignmentNotification = onDocumentCreated(
    "assign/{assignId}",
    async (event) => {
      const snap = event.data;
      if (!snap) {
        return null;
      }
      const assignData = snap.data();
      const staffName = assignData.staffName;
      const postName = assignData.postName || "עמדת אבטחה";
      const date = assignData.date || "";

      if (!staffName) {
        return null;
      }

      try {
        // מחפש את איש הצוות בקולקציית staff כדי לשלוף את ה־fcmToken שלו
        const staffQuery = await admin.firestore()
            .collection("staff")
            .where("name", "==", staffName)
            .get();

        if (staffQuery.empty) {
          console.log("איש הצוות לא נמצא:", staffName);
          return null;
        }

        const staffDoc = staffQuery.docs[0];
        const staffData = staffDoc.data();
        const fcmToken = staffData.fcmToken;

        if (!fcmToken) {
          console.log("אין FCM Token רשום למשתמש:", staffName);
          return null;
        }

        // בניית הודעת הפוש
        const message = {
          token: fcmToken,
          notification: {
            title: "שיבוץ חדש ספורטיאדה 2026! 🚨",
            body: `שובצת לענף/עמדה: ${postName} בתאריך ${date}`,
          },
          android: {
            notification: {
              sound: "default",
              clickAction: "FLUTTER_NOTIFICATION_CLICK",
            },
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
              },
            },
          },
        };

        // שליחת ההודעה דרך שרתי FCM
        await admin.messaging().send(message);
        console.log("התראה נשלחה בהצלחה ל־:", staffName);
        return null;
      } catch (error) {
        console.error("שגיאה בשליחת התראת פוש:", error);
        return null;
      }
    },
);
