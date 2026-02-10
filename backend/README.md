# Expense Tracker Standalone Backend Setup

This backend handles scheduled daily reminders and real-time budget alerts without using Firebase Functions.

## 🛠 Prerequisites

1.  **Node.js**: Installed on your system or server.
2.  **Firebase Service Account**:
    -   Go to **Firebase Console** > **Project Settings** > **Service Accounts**.
    -   Click **Generate new private key**.
    -   Download the JSON file.
    -   Rename it to `serviceAccountKey.json` and place it in the `backend/` directory.

## 🚀 Local Setup

1.  Open terminal in the `backend` folder:
    ```powershell
    cd backend
    npm install
    ```
2.  Run the server:
    ```powershell
    node server.js
    ```

## 🌐 Deployment (Free Alternatives)

### 1. Koyeb (Recommended - Always On)
-   Create a free account at [Koyeb.com](https://www.koyeb.com/).
-   Connect your GitHub repository.
-   Choose **Web Service** and select the **Nano** (Free) instance.
-   **Region**: Select the one closest to you (e.g., Mumbai, Singapore).
-   **Environment Variables**:
    -   `PORT`: `3000`
    -   `GOOGLE_APPLICATION_CREDENTIALS`: `/path/to/serviceAccountKey.json`
-   **Note**: You can also use [Koyeb Secrets](https://www.koyeb.com/docs/configuration/secrets) to store your service account JSON safely.

### 2. Render (Easy but sleeps)
-   Connect GitHub to [Render.com](https://render.com/).
-   Select **Web Service**.
-   **Trick**: To prevent sleeping, use [cron-job.org](https://cron-job.org/) to ping your service URL every 10 minutes.

## 🔒 Security Note
Never commit `serviceAccountKey.json` to GitHub. Add it to `.gitignore`.
