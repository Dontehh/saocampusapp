/*
 * CampusPulse — Cloud Functions
 *
 * Sends an FCM push to the newly-assigned leader whenever a new
 * `assignments` document is created. The iOS client subscribes to a
 * per-user topic (`user_<userId>`) on sign-in; this function targets
 * that topic so the push arrives on the leader's device regardless of
 * which admin created the assignment.
 *
 * Deploy:
 *   cd functions && npm install
 *   firebase deploy --only functions:notifyOnAssign
 */

const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {initializeApp}     = require("firebase-admin/app");
const {getFirestore}      = require("firebase-admin/firestore");
const {getMessaging}      = require("firebase-admin/messaging");

initializeApp();

exports.notifyOnAssign = onDocumentCreated(
  "assignments/{assignmentId}",
  async (event) => {
    const data = event.data && event.data.data();
    if (!data) return;

    const leaderId = data.leaderId;
    const eventId  = data.eventId;
    if (!leaderId || !eventId) return;

    const db = getFirestore();
    const [eventSnap, userSnap] = await Promise.all([
      db.doc(`events/${eventId}`).get(),
      db.doc(`users/${leaderId}`).get(),
    ]);

    const evt  = eventSnap.exists ? eventSnap.data()  : {};
    const user = userSnap.exists  ? userSnap.data()   : {};

    const title = "New event assignment";
    const body  = `${user.name || "You've been"} assigned to ${evt.title || "an event"}.`;

    await getMessaging().send({
      topic: `user_${leaderId}`,
      notification: {title, body},
      apns: {
        headers: {"apns-priority": "10"},
        payload: {aps: {sound: "default", badge: 1}},
      },
    });
  }
);
