/**
 * ElderBliss Admin — Firebase Cloud Functions
 *
 * Trigger: New document created in `panic_alerts` Firestore collection
 * Action : Send FCM push notification to ALL admin devices
 *
 * Firestore collections used:
 *   panic_alerts/{alertId}   — created by the user app (READ ONLY here)
 *   admin_fcm_tokens/{uid}   — written by the admin Flutter app
 */

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

// Initialise Firebase Admin SDK
initializeApp();

const db = getFirestore();
const messaging = getMessaging();

/**
 * sendPanicAlertNotification
 *
 * Fires whenever a new document is created in `panic_alerts`.
 * Reads all admin FCM tokens from `admin_fcm_tokens` and sends
 * a high-priority FCM notification to every admin device.
 */
exports.sendPanicAlertNotification = onDocumentCreated(
  "panic_alerts/{alertId}",
  async (event) => {
    const snapshot = event.data;

    if (!snapshot) {
      console.error("No data in event snapshot.");
      return null;
    }

    const alertData = snapshot.data();
    const alertId = event.params.alertId;

    // ── Extract alert details ──────────────────────────────────────────────
    const userName = alertData.userName || "Unknown User";
    const status = alertData.status || "active";

    // Support both ElderBliss app and Society app
    if (status !== "active" && status !== "triggered") {
      console.log(`Skipping alert with status: ${status}`);
      return null;
    }

    console.log(`New panic alert from: ${userName} (alertId: ${alertId})`);

    // ── Fetch all admin FCM tokens ─────────────────────────────────────────
    let tokenDocs;
    try {
      const tokensSnapshot = await db.collection("admin_fcm_tokens").get();
      tokenDocs = tokensSnapshot.docs;
    } catch (err) {
      console.error("Failed to fetch admin FCM tokens:", err);
      return null;
    }

    if (tokenDocs.length === 0) {
      console.warn("No admin FCM tokens found. No notifications sent.");
      return null;
    }

    const tokens = tokenDocs
      .map((doc) => doc.data().token)
      .filter((token) => typeof token === "string" && token.length > 0);

    if (tokens.length === 0) {
      console.warn("All token documents had empty/invalid tokens.");
      return null;
    }

    console.log(`Sending notification to ${tokens.length} admin device(s).`);

    // ── Build the FCM message ──────────────────────────────────────────────
      
    // Phone number supports both ElderBliss App and Society App
    const phone =
      alertData.phone ||
      alertData.userPhone ||
      "Unknown";
      
    // Notification title
    const notificationTitle = "🚨 Emergency Alert";
      
    // Notification body
    const notificationBody =
      `${userName}\nPhone: ${phone}`;
      
    // Send to each token individually (sendEachForMulticast handles batching)
    const multicastMessage = {
      tokens: tokens,

      // Notification payload (shown by system when app is background/terminated)
      notification: {
        title: notificationTitle,
        body: notificationBody,
      },

      // Android-specific config
      android: {
        priority: "high",
        notification: {
          channelId: "panic_alert_channel",
          sound: "panic_alert",       // matches res/raw/panic_alert.mp3
          priority: "max",
          defaultSound: false,
          defaultVibrateTimings: false,
          vibrateTimingsMillis: [0, 500, 200, 500, 200, 500],
          color: "#FF0000",
          icon: "ic_launcher",
          // Full-screen intent for locked screen
          notificationPriority: "PRIORITY_MAX",
          visibility: "PUBLIC",
        },
      },

      // Data payload — available in all app states, used for navigation
      data: {
        type: "panic_alert",
        alertId: alertId,
        userName: userName,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
    };

    // ── Send notifications ─────────────────────────────────────────────────
    try {
      const response = await messaging.sendEachForMulticast(multicastMessage);

      console.log(
        `FCM result — Success: ${response.successCount}, Failed: ${response.failureCount}`
      );

      // Clean up stale/invalid tokens from Firestore
      const staleTokenUids = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          const errorCode = resp.error?.code;
          console.error(`Token[${idx}] failed: ${errorCode}`);

          // These error codes mean the token is permanently invalid
          if (
            errorCode === "messaging/invalid-registration-token" ||
            errorCode === "messaging/registration-token-not-registered"
          ) {
            // Find the uid for this token and mark for deletion
            const staleToken = tokens[idx];
            const staleDoc = tokenDocs.find(
              (doc) => doc.data().token === staleToken
            );
            if (staleDoc) {
              staleTokenUids.push(staleDoc.id);
            }
          }
        }
      });

      // Delete stale token documents
      if (staleTokenUids.length > 0) {
        console.log(`Removing ${staleTokenUids.length} stale token(s).`);
        const deletePromises = staleTokenUids.map((uid) =>
          db.collection("admin_fcm_tokens").doc(uid).delete()
        );
        await Promise.all(deletePromises);
      }

      return { successCount: response.successCount };
    } catch (err) {
      console.error("Error sending FCM notifications:", err);
      return null;
    }
  }
);
