const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendGeofenceNotification = functions.firestore
  .document("geofence_events/{eventId}")
  .onCreate(async (snap, context) => {
    const event = snap.data();
    const userId = event.userId;
    const geofenceId = event.geofenceId;
    const eventType = event.event;

    // Get the user's device token from Firestore
    const userDoc = await admin.firestore().collection("users").doc(userId).get();
    const deviceToken = userDoc.data().deviceToken;

    // Get the geofence data from Firestore
    const geofenceDoc = await admin.firestore().collection("HeatPoints").doc(geofenceId).get();
    const geofence = geofenceDoc.data();

    // Create the notification payload
    const payload = {
      notification: {
        title: `You have ${eventType === "enter" ? "entered" : "exited"} an area`,
        body: `You are near ${geofence.description}`,
      },
    };

    // Send the notification
    try {
      await admin.messaging().sendToDevice(deviceToken, payload);
      console.log("Notification sent successfully");
    } catch (error) {
      console.error("Error sending notification:", error);
    }
  });