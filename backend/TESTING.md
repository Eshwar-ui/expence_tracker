# Backend Testing Guide (Edge Cases)

Since manually waiting for hourly crons or real user actions is inefficient, we will create a **manual test script** (`test_trigger.js`) to simulate various scenarios.

## 🧪 Edge Cases to Test

1.  **Daily Reminder (Timezone)**:
    -   Does the server send a reminder when `preferredNotificationTime` matches?
    -   Does it **skip** when the time doesn't match?
    -   Does it handle users with *no* preference?

2.  **Budget Alerts**:
    -   **Normal**: Adding expense that is within budget. (No Notification)
    -   **Near Limit (90%)**: Adding expense that pushes total to 90%. (Should Alert "Budget Alert")
    -   **Exceeded (100%+)**: Adding expense that exceeds limit. (Should Alert "Budget Exhausted")
    -   **No Budget**: Adding expense for a category with no budget set. (No Notification)

3.  **Missing Data**:
    -   User has no FCM token. (Should fail gracefully)
    -   Budget document is missing. (Should not crash)

## 🚀 How to Run the Test Script

I have created a `backend/test_trigger.js` file for you.

1.  **Local Test**:
    ```powershell
    cd backend
    node test_trigger.js
    ```
    This script will:
    -   Create a dummy user and budget in Firestore.
    -   Add dummy expenses to trigger the budget logic.
    -   Force-run the daily reminder logic for the current hour.
    -   Clean up the dummy data afterwards.

2.  **Verify Results**:
    -   Check the console output for `✅ Success` or `❌ Error`.
    -   Check your physical device for the actual notification (if you use your real User ID).
