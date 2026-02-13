# 🛠 Render & Notification Troubleshooting

If you are not receiving notifications, please follow these steps:

## 1. Check Render Logs
1. Go to your **Render Dashboard**.
2. Click on your **Web Service**.
3. Click on **Logs**.
4. Look for the startup messages I just added:
   - `🕒 Server Time`: Is this your local time?
   - `⚠️ No TZ variable detected!`: If you see this, the server is running on UTC time.

## 2. Fix Timezone (Most Common Issue)
Render servers run on **UTC time** by default.
- If it is **8:00 PM** in India, it is **2:30 PM** on the server.
- Your daily reminder (set for 20:00) will not run until it is 20:00 UTC (which is 1:30 AM next day in India).

**Solution:**
1. Go to Render Dashboard > **Environment**.
2. Add a new variable:
   - **Key**: `TZ`
   - **Value**: `Asia/Kolkata`
3. Save changes. Render will restart your server.
4. Check logs again to confirm `Server Time` matches your watch.

## 3. Verify Database Connection
If the logs say `Using local serviceAccountKey.json file` or `Using SERVICE_ACCOUNT_JSON env variable`, your connection is good.
- If you see `Falling back to applicationDefault`, ensure you have added the `SERVICE_ACCOUNT_JSON` environment variable in Render.

## 4. Test Notification
You can manually trigger a notification verification by checking if your `fcm_tokens` collection in Firestore has documents.
