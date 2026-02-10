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

// Scheduled function: Every hour to check user preferences
exports.dailyReminder = functions.pubsub
  .schedule("0 * * * *")
  .timeZone("Asia/Kolkata")
  .onRun(async (context) => {
    const now = new Date();
    // Format current hour as "HH:00" to match our hourly schedule
    const currentHour = now.getHours().toString().padStart(2, "0") + ":00";
    
    // Also check for user's specific minutes if needed, but for now we'll match by hour
    // A better approach is to store the hour as an integer or string "HH:00"
    
    console.log(`Checking for users with reminder preference: ${currentHour}`);

    const usersSnapshot = await db.collection("users")
      .where("preferredNotificationTime", "==", currentHour)
      .get();
    
    if (usersSnapshot.empty) {
      console.log("No users to remind this hour.");
      return null;
    }

    const promises = [];

    usersSnapshot.forEach((userDoc) => {
      const userId = userDoc.id;
      const message = reminderMessages[Math.floor(Math.random() * reminderMessages.length)];

      const tokenPromise = db
        .collection("users")
        .doc(userId)
        .collection("fcm_tokens")
        .get()
        .then(async (tokenSnapshot) => {
          const tokens = [];
          tokenSnapshot.forEach((doc) => tokens.push(doc.data().token));

          if (tokens.length > 0) {
            const payload = {
              notification: {
                title: "Daily Expense Reminder",
                body: message,
              },
              data: {
                click_action: "FLUTTER_NOTIFICATION_CLICK",
                screen: "/transactions",
              },
            };
            return admin.messaging().sendToDevice(tokens, payload);
          }
          return null;
        });

      promises.push(tokenPromise);
    });

    await Promise.all(promises);
    return console.log(`${promises.length} Daily reminders sent successfully.`);
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
      const tokenSnapshot = await db
        .collection("users")
        .doc(userId)
        .collection("fcm_tokens")
        .get();

      const tokens = [];
      tokenSnapshot.forEach((doc) => tokens.push(doc.data().token));

      if (tokens.length > 0) {
        const payload = {
          notification: {
            title: title,
            body: body,
          },
          data: {
            click_action: "FLUTTER_NOTIFICATION_CLICK",
            screen: "/budget",
          },
        };
        await admin.messaging().sendToDevice(tokens, payload);
        console.log(`Notification sent for category ${category}`);
      }
    }

    return null;
  });
