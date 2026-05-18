const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

const db = admin.firestore();

// Unique daily reminder messages
const reminderMessages = [
  "Time to log those morning coffees and commute costs! ☕️🚗",
  "Keeping track of your spending is the first step to financial freedom! 💸✨",
  "Did you add today's expenses yet? Your future self will thank you! 📝📈",
  "Small expenses add up! Don't forget to record today's transactions. 🧾🔍",
  "Goal check: Are you staying within your budget today? 🎯💰",
  "Daily check-in: Log your income and expenses to keep your dashboard accurate! 📊🚀",
];

// Cron runs every minute (Asia/Kolkata). Matches users whose
// preferredNotificationTime == "HH:MM" right now, are opted-in, and haven't
// already logged today. Sends an FCM push with a randomized message.
exports.dailyReminder = functions.pubsub
  .schedule("* * * * *")
  .timeZone("Asia/Kolkata")
  .onRun(async () => {
    const now = new Date(
      new Date().toLocaleString("en-US", {timeZone: "Asia/Kolkata"}),
    );
    const hh = now.getHours().toString().padStart(2, "0");
    const mm = now.getMinutes().toString().padStart(2, "0");
    const currentTime = `${hh}:${mm}`;
    const todayKey =
      `${now.getFullYear()}-` +
      `${(now.getMonth() + 1).toString().padStart(2, "0")}-` +
      `${now.getDate().toString().padStart(2, "0")}`;

    const usersSnapshot = await db
      .collection("users")
      .where("preferredNotificationTime", "==", currentTime)
      .get();

    if (usersSnapshot.empty) return null;

    const sends = [];
    usersSnapshot.forEach((userDoc) => {
      const data = userDoc.data() || {};
      if (data.reminderEnabled !== true) return;
      if (data.reminderLastLoggedDate === todayKey) return;

      const token = data.fcmToken;
      if (!token || typeof token !== "string") return;

      const message =
        reminderMessages[Math.floor(Math.random() * reminderMessages.length)];

      sends.push(
        admin.messaging().send({
          token: token,
          notification: {
            title: "Daily Expense Reminder",
            body: message,
          },
          data: {
            click_action: "FLUTTER_NOTIFICATION_CLICK",
            screen: "/transactions",
          },
          android: {
            priority: "high",
            notification: {channelId: "daily_expense_reminder"},
          },
        }).catch(async (err) => {
          // Token rotated or unregistered — clear it so we stop retrying.
          if (
            err.code === "messaging/registration-token-not-registered" ||
            err.code === "messaging/invalid-registration-token"
          ) {
            await userDoc.ref.update({fcmToken: admin.firestore.FieldValue.delete()});
          } else {
            console.error(`send failed for ${userDoc.id}:`, err.message);
          }
        }),
      );
    });

    await Promise.all(sends);
    console.log(`dailyReminder@${currentTime}: sent ${sends.length}`);
    return null;
  });

// Firestore Trigger: When a new expense is added, check budget
exports.onExpenseCreated = functions.firestore
  .document("users/{userId}/expenses/{expenseId}")
  .onCreate(async (snapshot, context) => {
    const expenseData = snapshot.data();
    const userId = context.params.userId;
    const category = expenseData.category;
    const amount = expenseData.amount;

    if (!category) return null;

    // Get the budget for this category
    const budgetSnapshot = await db
      .collection("users")
      .doc(userId)
      .collection("budgets")
      .where("category", "==", category)
      .where("isActive", "==", true)
      .limit(1)
      .get();

    if (budgetSnapshot.empty) return null;

    const budgetDoc = budgetSnapshot.docs[0];
    const budgetData = budgetDoc.data();
    const limit = budgetData.limit;
    const spent = budgetData.spent + amount;

    // Update the budget's spent amount in Firestore
    await budgetDoc.ref.update({
      spent: spent,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Check if budget exceeded or near limit
    let title = "";
    let body = "";

    if (spent >= limit) {
      title = "Budget Exhausted! ⚠️";
      body = `You've exceeded your budget for ${category}. Total spent: ${spent.toFixed(2)} / ${limit.toFixed(2)}`;
    } else if (spent >= limit * 0.9) {
      title = "Budget Alert! 🔔";
      body = `You've reached 90% of your budget for ${category}. Staying within limits?`;
    }

    if (title && body) {
      const userDoc = await db.collection("users").doc(userId).get();
      const token = userDoc.exists ? userDoc.data().fcmToken : null;
      if (token && typeof token === "string") {
        try {
          await admin.messaging().send({
            token: token,
            notification: {title: title, body: body},
            data: {
              click_action: "FLUTTER_NOTIFICATION_CLICK",
              screen: "/budget",
            },
          });
          console.log(`Budget notification sent for category ${category}`);
        } catch (err) {
          if (
            err.code === "messaging/registration-token-not-registered" ||
            err.code === "messaging/invalid-registration-token"
          ) {
            await userDoc.ref.update({fcmToken: admin.firestore.FieldValue.delete()});
          } else {
            console.error(`Budget send failed for ${userId}:`, err.message);
          }
        }
      }
    }

    return null;
  });
