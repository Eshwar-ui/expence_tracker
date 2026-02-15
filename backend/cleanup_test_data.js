const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');
require('dotenv').config();

const lkp = path.join(__dirname, 'serviceAccountKey.json');
if (fs.existsSync(lkp)) {
  admin.initializeApp({ credential: admin.credential.cert(lkp) });
}
const db = admin.firestore();

const TARGET_USER_ID = "7odLywgTZpSJnpiqlzqap6pRnhO2";

async function removeTestExpenses() {
  console.log('🧹 Scanning for test expenses...\n');

  const snapshot = await db.collection('users').doc(TARGET_USER_ID).collection('expenses').get();
  
  const testDocs = [];
  const realDocs = [];

  snapshot.forEach(doc => {
    const data = doc.data();
    const isTest = 
      !data.title ||                                     // Missing title (test script didn't set it)
      !data.id ||                                        // Missing id field
      (data.category && data.category.startsWith('TestCategory_')) || // Test categories
      (data.description && data.description.startsWith('Test Expense')); // Test descriptions

    if (isTest) {
      testDocs.push({ id: doc.id, category: data.category, amount: data.amount, description: data.description || '' });
    } else {
      realDocs.push({ id: doc.id, title: data.title, amount: data.amount });
    }
  });

  console.log(`📊 Total expenses: ${snapshot.size}`);
  console.log(`🧪 Test expenses to DELETE: ${testDocs.length}`);
  console.log(`✅ Real expenses to KEEP: ${realDocs.length}\n`);

  if (testDocs.length > 0) {
    console.log('--- Test expenses being deleted: ---');
    testDocs.forEach(d => console.log(`   ❌ ${d.id} | ${d.category} | $${d.amount} | ${d.description}`));
    
    console.log('\n--- Real expenses being kept: ---');
    realDocs.slice(0, 5).forEach(d => console.log(`   ✅ ${d.id} | ${d.title} | $${d.amount}`));
    if (realDocs.length > 5) console.log(`   ... and ${realDocs.length - 5} more`);

    // Delete test expenses
    console.log('\n🗑️  Deleting test expenses...');
    const batch = db.batch();
    for (const doc of testDocs) {
      batch.delete(db.collection('users').doc(TARGET_USER_ID).collection('expenses').doc(doc.id));
    }
    await batch.commit();
    console.log(`✅ Deleted ${testDocs.length} test expenses. ${realDocs.length} real expenses remain.`);
  } else {
    console.log('No test expenses found. Nothing to delete.');
  }
}

removeTestExpenses();
