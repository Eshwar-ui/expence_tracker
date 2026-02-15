const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');
require('dotenv').config();

// --- 1. Initialize Firebase --------------------------------------------------
function initializeFirebase() {
  if (process.env.SERVICE_ACCOUNT_JSON) {
    admin.initializeApp({
      credential: admin.credential.cert(JSON.parse(process.env.SERVICE_ACCOUNT_JSON)),
    });
  } else {
    const localKeyPath = path.join(__dirname, 'serviceAccountKey.json');
    if (fs.existsSync(localKeyPath)) {
      admin.initializeApp({
        credential: admin.credential.cert(localKeyPath),
      });
    } else {
      admin.initializeApp({
        credential: admin.credential.applicationDefault(),
      });
    }
  }
}

initializeFirebase();
const db = admin.firestore();

// --- 2. Configuration for Testing --------------------------------------------
// REPLACE THIS WITH YOUR REAL USER ID TO RECEIVE NOTIFICATIONS ON YOUR PHONE
const TEST_USER_ID = "7odLywgTZpSJnpiqlzqap6pRnhO2"; 
// OR leave blank to create a dummy user (won't send real notification but tests logic)
// const TEST_USER_ID = null; 

async function runTests() {
  console.log('🧪 Starting Backend Edge Case Tests...\n');

  try {
    let userId = TEST_USER_ID;

    // A. Create Dummy User if needed
    if (!userId) {
      console.log('👤 Creating temporary test user...');
      const userRef = await db.collection('users').add({
        email: 'test@example.com',
        preferredNotificationTime: new Date().getHours().toString().padStart(2, '0') + ':00',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      userId = userRef.id;
      console.log(`   -> Created User ID: ${userId}`);
      
      // Add a dummy FCM token
      await db.collection('users').doc(userId).collection('fcm_tokens').doc('dummy_token').set({
        token: 'dummy_token_123',
        platform: 'test',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
        console.log(`👤 Using existing User ID: ${userId}`);
    }

    // --- B. Test Daily Reminder Logic -----------------------------------------
    console.log('\n⏰ Testing Daily Reminder Logic...');
    const now = new Date();
    const currentHour = now.getHours().toString().padStart(2, '0') + ':00';
    console.log(`   -> Current Server Hour: ${currentHour}`);

    // Update or Create user to match current time
    await db.collection('users').doc(userId).set({
        preferredNotificationTime: currentHour
    }, { merge: true });
    console.log(`   -> Set user preference to: ${currentHour}`);

    const usersSnapshot = await db.collection('users')
      .where('preferredNotificationTime', '==', currentHour)
      .get();
    
    if (usersSnapshot.empty) {
        console.log('   ❌ No users found matching time (Fail)');
    } else {
        const found = usersSnapshot.docs.some(doc => doc.id === userId);
        if(found) console.log('   ✅ Query successfully found the test user!');
        else console.log('   ⚠️ Query matched users but not our test user.');
    }


    // --- C. Test Budget Logic -------------------------------------------------
    console.log('\n💰 Testing Budget Alerts...');
    const category = 'TestCategory_' + Math.floor(Math.random() * 1000);
    const budgetLimit = 1000;

    // 1. Create Budget
    await db.collection('users').doc(userId).collection('budgets').add({
        category: category,
        limit: budgetLimit,
        spent: 0,
        isActive: true, // Should monitor this
    });
    console.log(`   -> Created budget for ${category}: Limit ${budgetLimit}`);

    // 2. Simulate Adding Expense (50% - No Alert)
    console.log('   -> Simulating $500 expense (50%)...');
    await db.collection('users').doc(userId).collection('expenses').add({
        category: category,
        amount: 500,
        date: admin.firestore.FieldValue.serverTimestamp(),
        description: 'Test Expense 1'
    });
    // Manually check logic (Server usually does this via listener)
    // We can verify if 'spent' updated by reading back
    await new Promise(r => setTimeout(r, 2000)); // Wait for server to process
    let budgetCheck = await db.collection('users').doc(userId).collection('budgets')
        .where('category', '==', category).get();
    console.log(`      Current Spent: ${budgetCheck.docs[0].data().spent}`);

    // 3. Simulate Adding Expense (90% - Alert)
    console.log('   -> Simulating $400 expense (Total 900 - 90%)...');
    // NOTE: This script just writes data. Your RUNNING SERVER needs to pick this up 
    // to actually send the notification.
    await db.collection('users').doc(userId).collection('expenses').add({
        category: category,
        amount: 400,
        date: admin.firestore.FieldValue.serverTimestamp(),
        description: 'Test Expense 2'
    });
    console.log('      (Check your app/logs for "Budget Alert! 🔔")');

    // 4. Simulate Adding Expense (110% - Exhausted)
    console.log('   -> Simulating $200 expense (Total 1100 - 110%)...');
    await db.collection('users').doc(userId).collection('expenses').add({
        category: category,
        amount: 200,
        date: admin.firestore.FieldValue.serverTimestamp(),
        description: 'Test Expense 3'
    });
    console.log('      (Check your app/logs for "Budget Exhausted! ⚠️")');

  } catch (error) {
    console.error('❌ Test Failed:', error);
  } finally {
    console.log('\n🏁 Tests Finished. (Note: This script only simulated DATA changes. Ensure your server.js is running to process them!)');
    process.exit();
  }
}

runTests();
