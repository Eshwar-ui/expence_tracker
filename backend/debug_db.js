const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');
require('dotenv').config();

// Initialize Firebase
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

const TARGET_USER_ID = "7odLywgTZpSJnpiqlzqap6pRnhO2"; 

async function inspectDatabase() {
  console.log('🕵️‍♂️ Starting Database Inspection...\n');

  try {
    // 1. List Root Collections
    console.log('1️⃣  Checking Root Collections...');
    const collections = await db.listCollections();
    if (collections.length === 0) {
      console.log('   ❌ No root collections found.');
    } else {
      collections.forEach(col => console.log(`   - ${col.id}`));
    }
    console.log('');

    // 2. Check Specific User Path
    console.log(`2️⃣  Checking User: ${TARGET_USER_ID}`);
    const userDoc = await db.collection('users').doc(TARGET_USER_ID).get();
    if (!userDoc.exists) {
      console.log('   ❌ User document does NOT exist.');
    } else {
      console.log('   ✅ User document exists.');
      console.log('   DATA:', JSON.stringify(userDoc.data(), null, 2));

      // Check Subcollections
      const userCollections = await db.collection('users').doc(TARGET_USER_ID).listCollections();
      if (userCollections.length === 0) {
        console.log('   ❌ No subcollections found for this user.');
      } else {
        console.log('   📂 Subcollections:');
        for (const col of userCollections) {
          const snapshot = await col.limit(5).get();
          console.log(`      - ${col.id} (Contains ${snapshot.size}${snapshot.size === 5 ? '+' : ''} docs)`);
          
          if (col.id === 'expenses') {
             console.log('        🔎 Recent Expenses:');
             snapshot.forEach(doc => {
                 const data = doc.data();
                 console.log(`           - ${data.amount} (${data.category}) [${data.description || 'No Desc'}]`);
             });
          }
        }
      }
    }
    console.log('');

    // 3. Search Globally for ANY Expenses
    console.log('3️⃣  Global Search for "expenses" (Collection Group)...');
    const expensesSnapshot = await db.collectionGroup('expenses').limit(10).get();
    if (expensesSnapshot.empty) {
        console.log('   ❌ No documents found in ANY "expenses" collection in the entire DB.');
    } else {
        console.log(`   ✅ Found ${expensesSnapshot.size} expenses globally.`);
        expensesSnapshot.forEach(doc => {
            console.log(`   - path: ${doc.ref.path} | Amount: ${doc.data().amount}`);
        });
    }

  } catch (error) {
    console.error('❌ Error during inspection:', error);
  }
}

inspectDatabase();
