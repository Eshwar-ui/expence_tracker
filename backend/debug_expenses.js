const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');
require('dotenv').config();

const lkp = path.join(__dirname, 'serviceAccountKey.json');
if (fs.existsSync(lkp)) {
  admin.initializeApp({ credential: admin.credential.cert(lkp) });
}
const db = admin.firestore();

(async () => {
  const s = await db.collection('users').doc('7odLywgTZpSJnpiqlzqap6pRnhO2').collection('expenses').limit(5).get();
  const lines = [];
  s.forEach(d => {
    const data = d.data();
    const dt = data.date;
    let tp = 'unknown';
    if (typeof dt === 'string') tp = 'STRING';
    else if (dt && dt.toDate) tp = 'TIMESTAMP';
    lines.push(`DOC_ID: ${d.id} | DATE_TYPE: ${tp} | TITLE: ${data.title || 'NONE'} | HAS_ID_FIELD: ${!!data.id} | AMOUNT: ${data.amount}`);
  });
  fs.writeFileSync(path.join(__dirname, 'expense_report.txt'), lines.join('\n'));
  console.log('DONE - wrote expense_report.txt');
})();
