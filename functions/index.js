const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

// Use the new onDocumentCreated trigger
exports.sendGeofenceNotification = onDocumentCreated("geofence_events/{eventId}", async (event) => {
  // The event.data contains the document snapshot.
  const snap = event.data;
  if (!snap) {
    logger.log("No data associated with the event");
    return;
  }
  
  const eventData = snap.data();
  const userId = eventData.userId;
  const geofenceId = eventData.geofenceId;
  const eventType = eventData.event;

  try {
    // Get the user's device token from Firestore
    const userDoc = await admin.firestore().collection("users").doc(userId).get();
    if (!userDoc.exists) {
        logger.log("User document not found for userId:", userId);
        return;
    }
    const deviceToken = userDoc.data().deviceToken;
    if (!deviceToken) {
        logger.log("No deviceToken found for user:", userId);
        return;
    }

    // Get the geofence data from Firestore
    const geofenceDoc = await admin.firestore().collection("HeatPoints").doc(geofenceId).get();
     if (!geofenceDoc.exists) {
        logger.log("Geofence document not found for geofenceId:", geofenceId);
        return;
    }
    const geofence = geofenceDoc.data();

    // Create the notification payload
    const payload = {
      data: {
        // Send IDs and types, not display text
        geofenceId: geofenceId,
        type: geofence.type, // e.g., 'fire', 'theft'
        description: geofence.description, // Can be useful for the notification body
        eventType: eventType // 'enter' or 'exit'
      },
    };

    // Send the notification
    logger.log("Sending notification to token:", deviceToken);
    await admin.messaging().sendToDevice(deviceToken, payload);
    logger.log("Notification sent successfully to user:", userId);

  } catch (error) {
    logger.error("Error sending notification:", error);
  }
});