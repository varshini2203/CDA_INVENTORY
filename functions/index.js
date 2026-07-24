const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// ============================================================
// Listens to "notification_requests" collection (written by
// NotificationService.sendStockAlert / sendLowStockAlert in Flutter)
// and pushes FCM notification to ALL admins + employees.
// ============================================================
exports.onNotificationRequest = onDocumentCreated(
  "notification_requests/{requestId}",
  async (event) => {
    const data = event.data.data();
    if (!data) return;

    const { title, body, module, action, itemName, quantity } = data;

    // 1. Get all admin + employee tokens
    const usersSnap = await db
      .collection("users")
      .where("role", "in", ["admin", "employee"])
      .get();

    const tokens = [];
    usersSnap.forEach((doc) => {
      const token = doc.data().fcmToken;
      if (token) tokens.push(token);
    });

    if (!tokens.length) {
      console.log("No tokens found, skipping push.");
      return;
    }

    // 2. Send push notification
    const message = {
      tokens,
      notification: {
        title: title || "CDA Inventory",
        body: body || "",
      },
      data: {
        module: module || "",
        action: action || "",
        itemName: itemName || "",
        quantity: quantity != null ? String(quantity) : "",
      },
      android: {
        priority: "high",
        notification: {
          sound: "default",
          channelId: "cda_stock_channel",
        },
      },
      apns: {
        payload: { aps: { sound: "default" } },
      },
    };

    const response = await messaging.sendEachForMulticast(message);
    console.log(`Sent: ${response.successCount}, Failed: ${response.failureCount}`);

    response.responses.forEach((res, idx) => {
      if (!res.success) {
     console.log(`Token failed: ${tokens[idx]} - ${res.error && res.error.message}`);
      }
    });

    // 3. Mark request as processed (optional, keeps collection clean)
    await event.data.ref.update({ processed: true });
  }
);