const express = require('express');
const admin = require('firebase-admin');
const cron = require('node-cron');
require('dotenv').config();

const app = express();
const port = process.env.PORT || 8000;

// Debugging: Log server time and timezone on startup
const now = new Date();
console.log(`🚀 Server starting...`);
console.log(`🕒 Server Time: ${now.toString()}`);
console.log(`🌍 Server ISO Time: ${now.toISOString()}`);
console.log(`📅 Server Timezone Offset: ${now.getTimezoneOffset()}`);
if (process.env.TZ) {
  console.log(`🌐 Configured TZ Variable: ${process.env.TZ}`);
} else {
  console.log(`⚠️ No TZ variable detected! Server might look for UTC time.`);
}

const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin with better local development fallbacks
function initializeFirebase() {
  // Option 1: Env variable with full JSON content (Koyeb/Render)
  if (process.env.SERVICE_ACCOUNT_JSON) {
    console.log('Initializing Firebase: Using SERVICE_ACCOUNT_JSON env variable.');
    return admin.initializeApp({
      credential: admin.credential.cert(JSON.parse(process.env.SERVICE_ACCOUNT_JSON)),
    });
  }

  // Option 2: Local file check (Local development)
  const localKeyPath = path.join(__dirname, 'serviceAccountKey.json');
  if (fs.existsSync(localKeyPath)) {
    console.log('Initializing Firebase: Using local serviceAccountKey.json file.');
    return admin.initializeApp({
      credential: admin.credential.cert(localKeyPath),
    });
  }

  // Option 3: Fallback to standard Google Environment Variable (GOOGLE_APPLICATION_CREDENTIALS)
  console.log('Initializing Firebase: Falling back to applicationDefault (GOOGLE_APPLICATION_CREDENTIALS).');
  return admin.initializeApp({
    credential: admin.credential.applicationDefault(),
  });
}

initializeFirebase();

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

// 1. Scheduled Daily Reminders (Runs every hour)
cron.schedule('0 * * * *', async () => {
  const now = new Date();
  const currentHour = now.getHours().toString().padStart(2, '0') + ':00';
  
  console.log(`[${new Date().toISOString()}] Checking for users with reminder preference: ${currentHour}`);

  try {
    const usersSnapshot = await db.collection('users')
      .where('preferredNotificationTime', '==', currentHour)
      .get();
    
    if (usersSnapshot.empty) {
      console.log('No users to remind this hour.');
      return;
    }

    const promises = [];
    usersSnapshot.forEach(userDoc => {
      const userId = userDoc.id;
      const message = reminderMessages[Math.floor(Math.random() * reminderMessages.length)];
      
      const tokenPromise = db.collection('users').doc(userId).collection('fcm_tokens').get()
        .then(async (tokenSnapshot) => {
          const tokens = [];
          tokenSnapshot.forEach(doc => tokens.push(doc.data().token));

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
        });
      promises.push(tokenPromise);
    });

    await Promise.all(promises);
    console.log(`Sent reminders to ${promises.length} users.`);
  } catch (error) {
    console.error('Error sending daily reminders:', error);
  }
});

// 2. Budget Alerts (Real-time listener)
console.log('👀 Listening for new expenses across all users...');
db.collectionGroup('expenses').onSnapshot(snapshot => {
  snapshot.docChanges().forEach(async (change) => {
    if (change.type === 'added') {
      const expenseData = change.doc.data();
      const expenseRef = change.doc.ref;
      const userId = expenseRef.parent.parent.id; 
      const category = expenseData.category;
      const amount = expenseData.amount;
      
      console.log(`📝 New expense detected: $${amount} for ${category} (User: ${userId})`);

      if (!category || !userId) return;

      try {
        const budgetSnapshot = await db.collection('users').doc(userId).collection('budgets')
          .where('category', '==', category)
          .where('isActive', '==', true)
          .limit(1)
          .get();

        if (budgetSnapshot.empty) {
            console.log(`   ⚠️ No active budget found for category: ${category}`);
            return;
        }

        const budgetDoc = budgetSnapshot.docs[0];
        const budgetData = budgetDoc.data();
        const limit = budgetData.limit;
        const spent = (budgetData.spent || 0) + amount;
        
        console.log(`   📊 Budget found: ${category} | Limit: ${limit} | New Spent: ${spent}`);

        // Update spent amount in Firestore
        await budgetDoc.ref.update({
          spent: spent,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Send notification if alert threshold reached
        let title = "";
        let body = "";

        console.log(`   🧮 Checking limits: Spent: ${spent} vs Limit: ${limit}`);

        if (spent >= limit) {
          title = "Budget Exhausted! ⚠️";
          body = `You've exceeded your budget for ${category}. Total spent: ${spent.toFixed(2)} / ${limit.toFixed(2)}`;
          console.log('   🚨 Logic: Budget Exhausted!');
        } else if (spent >= limit * 0.9) {
          title = "Budget Alert! 🔔";
          body = `You've reached 90% of your budget for ${category}. Staying within limits?`;
          console.log('   🚨 Logic: Budget Alert (90%)!');
        } else {
            console.log('   ✅ Within safe limits.');
        }

        if (title && body) {
          const tokenSnapshot = await db.collection('users').doc(userId).collection('fcm_tokens').get();
          console.log(`   🔍 Found ${tokenSnapshot.size} tokens for user.`);
          const tokens = [];
          tokenSnapshot.forEach(doc => tokens.push(doc.data().token));

          if (tokens.length > 0) {
            const payload = {
              notification: { title, body },
              data: {
                click_action: "FLUTTER_NOTIFICATION_CLICK",
                screen: "/budget",
              },
            };
            try {
              const response = await admin.messaging().sendToDevice(tokens, payload);
              console.log(`[ALERT] Sent to ${tokens.length} devices. Success: ${response.successCount}, Failure: ${response.failureCount}`);
              if (response.failureCount > 0) {
                  response.results.forEach((result, idx) => {
                      if (result.error) console.log(`   -> Error for token ${idx}: ${result.error}`);
                  });
              }
            } catch(e) {
                console.error("Error sending message:", e);
            }
          }
        }
      } catch (error) {
        console.error('Error handling budget alert:', error);
      }
    }
  });
}, error => {
  console.error('Firestore listener error:', error);
});

app.get('/', (req, res) => {
  res.send('Expense Tracker Notification Server is Running 🚀');
});

app.listen(port, () => {
  console.log(`Server listening on port ${port}`);
});
