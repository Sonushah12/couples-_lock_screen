"use strict";
const { initializeApp, getApps } = require("firebase-admin/app");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");
const { getStorage } = require("firebase-admin/storage");
const { getMessaging } = require("firebase-admin/messaging");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated, onDocumentDeleted } = require("firebase-functions/v2/firestore");
const v = require("./validation");
if (!getApps().length) initializeApp();
const db = getFirestore();
const region = "asia-south1";
const emulator = process.env.FUNCTIONS_EMULATOR === "true";
const options = { region, enforceAppCheck: !emulator, maxInstances: 10, timeoutSeconds: 120 };
const stamp = () => FieldValue.serverTimestamp();
function callable(handler) {
  return onCall(options, async request => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Sign in to continue.");
    try {
      const account = await getAuth().getUser(request.auth.uid);
      if (account.disabled) throw new HttpsError("permission-denied", "This account is disabled.");
      return await handler(request.auth.uid, request.data || {}, request);
    }
    catch (e) {
      if (e instanceof v.InputError) throw new HttpsError("invalid-argument", e.message);
      if (e instanceof HttpsError) throw e;
      if (e.code === 'auth/user-not-found') throw new HttpsError('unauthenticated', 'This account no longer exists.');
      console.error("Pairlight operation failed", e.code || e.name);
      throw new HttpsError("internal", "Something went wrong. Please retry.");
    }
  });
}
async function membership(tx, uid) {
  const userRef = db.doc(`users/${uid}`);
  const user = (await tx.get(userRef)).data();
  if (!user || user.deleting) throw new HttpsError("failed-precondition", "Set up your profile first.");
  if (!user.spaceId) throw new HttpsError("failed-precondition", "Create or join a partner invitation first.");
  const spaceRef = db.doc(`spaces/${user.spaceId}`);
  const space = (await tx.get(spaceRef)).data();
  if (!space || !space.memberIds.includes(uid)) throw new HttpsError("permission-denied", "This connection has ended.");
  return { user, userRef, space, spaceRef };
}
async function limit(tx, uid, key, max, windowMs = 60000) {
  const ref = db.doc(`rateLimits/${uid}_${key}`);
  const old = (await tx.get(ref)).data();
  const active = old && old.start > Date.now() - windowMs;
  const count = active ? old.count : 0;
  if (count >= max) throw new HttpsError("resource-exhausted", "Please wait a little before trying again.");
  // Return the write so callers finish ALL transaction reads before writing.
  return () => tx.set(ref, { count: count + 1, start: active ? old.start : Date.now() });
}
exports.saveProfile = callable(async (uid, data) => {
  const name = v.text(data.name, "Name", 30);
  const relationship = v.text(data.relationship, "Connection", 20);
  if (!["Couple", "Friends", "Family"].includes(relationship)) throw new v.InputError("Choose a connection type.");
  const anniversary = v.date(data.anniversary);
  if (anniversary > new Date().toISOString().slice(0, 10)) throw new v.InputError("The anniversary cannot be in the future.");
  await db.runTransaction(async tx => {
    const ref = db.doc(`users/${uid}`);
    const old = (await tx.get(ref)).data();
    if (old?.deleting) throw new HttpsError("failed-precondition", "Account deletion is in progress.");
    let shared;
    if (old?.spaceId) shared = await membership(tx, uid);
    const commitLimit = await limit(tx, uid, "profile", 20);
    commitLimit();
    tx.set(ref, { name, relationship, anniversary, onboarded: true, updatedAt: stamp(),
      ...(!old ? { spaceId: null, notifications: false, createdAt: stamp() } : {}) }, { merge: true });
    if (shared) tx.update(shared.spaceRef, { [`names.${uid}`]: name, relationship, anniversary });
  });
  return { ok: true };
});
exports.createInvite = callable(async (uid, _data, request) => {
  if (!emulator && !request.auth.token.email_verified) throw new HttpsError("failed-precondition", "Verify your email before pairing.");
  const code = v.inviteCode();
  const inviteRef = db.doc(`invites/${v.hash(code)}`);
  const newSpaceRef = db.collection("spaces").doc();
  const expiresAt = Timestamp.fromMillis(Date.now() + 24 * 60 * 60 * 1000);
  await db.runTransaction(async tx => {
    const userRef = db.doc(`users/${uid}`);
    const user = (await tx.get(userRef)).data();
    if (!user?.onboarded || user.deleting) throw new HttpsError("failed-precondition", "Set up your profile first.");
    let spaceRef = newSpaceRef, space;
    if (user.spaceId) {
      ({ spaceRef, space } = await membership(tx, uid));
      if (space.memberIds.length === 2) throw new HttpsError("already-exists", "You are already connected.");
    }
    const commitLimit = await limit(tx, uid, "invite", 5, 3600000);
    commitLimit();
    if (!space) tx.create(spaceRef, { memberIds: [uid], names: { [uid]: user.name },
      relationship: user.relationship, anniversary: user.anniversary, createdAt: stamp() });
    // Only the latest invitation can be used, even if an old code has not expired.
    tx.set(userRef, { spaceId: spaceRef.id, activeInvite: inviteRef.id }, { merge: true });
    tx.create(inviteRef, { ownerId: uid, spaceId: spaceRef.id, expiresAt, used: false });
  });
  return { code, expiresAt: expiresAt.toDate().toISOString() };
});
exports.acceptInvite = callable(async (uid, data, request) => {
  if (!emulator && !request.auth.token.email_verified) throw new HttpsError("failed-precondition", "Verify your email before pairing.");
  const code = v.text(data.code, "Invitation code", 12).toUpperCase();
  if (!/^[0-9A-F]{12}$/.test(code)) throw new v.InputError("Enter the 12-character invitation code.");
  // Persist failed attempt accounting separately: an aborted join must not undo the throttle.
  await db.runTransaction(async tx => { const commit = await limit(tx, uid, "join", 10, 3600000); commit(); });
  await db.runTransaction(async tx => {
    const inviteRef = db.doc(`invites/${v.hash(code)}`);
    const userRef = db.doc(`users/${uid}`);
    const invite = (await tx.get(inviteRef)).data();
    const user = (await tx.get(userRef)).data();
    if (!user?.onboarded || user.deleting) throw new HttpsError("failed-precondition", "Set up your profile first.");
    if (invite?.acceptedBy === uid && user.spaceId === invite.spaceId) return;
    if (!invite || invite.used || invite.expiresAt.toMillis() < Date.now()) throw new HttpsError("not-found", "This invitation has expired or is unavailable.");
    if (invite.ownerId === uid) throw new HttpsError("invalid-argument", "Ask your partner to enter this code on their phone.");
    if (user.spaceId === invite.spaceId) return; // Retried accepted invitation is handled below via used state otherwise.
    if (user.spaceId) throw new HttpsError("failed-precondition", "Disconnect your current space before joining another.");
    const ownerRef = db.doc(`users/${invite.ownerId}`);
    const owner = (await tx.get(ownerRef)).data();
    const spaceRef = db.doc(`spaces/${invite.spaceId}`);
    const space = (await tx.get(spaceRef)).data();
    if (!owner || owner.deleting || owner.activeInvite !== inviteRef.id || !space ||
        space.memberIds.length !== 1 || space.memberIds[0] !== invite.ownerId) {
      throw new HttpsError("failed-precondition", "This invitation is no longer available.");
    }
    tx.update(spaceRef, { memberIds: [invite.ownerId, uid], [`names.${uid}`]: user.name });
    tx.update(userRef, { spaceId: spaceRef.id });
    tx.update(ownerRef, { activeInvite: FieldValue.delete() });
    tx.update(inviteRef, { used: true, acceptedBy: uid });
  });
  return { ok: true };
});
exports.sendMoment = callable(async (uid, data) => {
  const id = v.id(data.id);
  const kind = v.text(data.kind, "Moment type", 12);
  if (!["moment", "note", "doodle", "photo"].includes(kind)) throw new v.InputError("Unknown moment type.");
  const content = v.text(data.content, "Message", 500);
  const points = kind === "doodle" ? v.drawing(data.drawing) : null;
  const photoPath = kind === "photo" ? v.text(data.photoPath, "Photo path", 250) : null;
  const user = (await db.doc(`users/${uid}`).get()).data();
  if (photoPath) {
    if (photoPath !== `spaces/${user?.spaceId}/photos/${uid}/${id}`) throw new v.InputError("Invalid photo path.");
    const [metadata] = await getStorage().bucket().file(photoPath).getMetadata();
    if (Number(metadata.size) >= 5 * 1024 * 1024 || !/^image\/(jpeg|png|webp)$/.test(metadata.contentType)) throw new v.InputError("Choose an image smaller than 5 MB.");
  }
  await db.runTransaction(async tx => {
    const { spaceRef, user } = await membership(tx, uid);
    const ref = spaceRef.collection("moments").doc(id);
    const existing = await tx.get(ref);
    if (existing.exists) {
      if (existing.data().senderId !== uid) throw new HttpsError("already-exists", "Request ID already used.");
      return;
    }
    if (photoPath && !photoPath.startsWith(`spaces/${spaceRef.id}/`)) throw new HttpsError("failed-precondition", "Your connection changed. Choose the photo again.");
    const commit = await limit(tx, uid, "moment", 30);
    commit();
    tx.create(ref, { id, kind, content, drawing: points, photoPath, senderId: uid,
      senderName: user.name, createdAt: stamp() });
  });
  return { ok: true, id };
});
exports.saveAnswer = callable(async (uid, data) => {
  const day = v.date(data.day);
  // UTC makes both partners answer the same question across time zones.
  if (day !== new Date().toISOString().slice(0, 10)) throw new v.InputError("Today’s question has changed. Reopen it to answer.");
  const answer = v.text(data.answer, "Answer", 500);
  await db.runTransaction(async tx => {
    const { spaceRef, user } = await membership(tx, uid);
    const commit = await limit(tx, uid, "answer", 20);
    commit();
    tx.set(spaceRef.collection("questions").doc(day).collection("answers").doc(uid), {
      answer, senderName: user.name, updatedAt: stamp()
    });
  });
  return { ok: true };
});
exports.addCountdown = callable(async (uid, data) => {
  const id = v.id(data.id), title = v.text(data.title, "Event name", 60), date = v.date(data.date);
  if (date < new Date().toISOString().slice(0, 10) || date > new Date(Date.now() + 3660 * 86400000).toISOString().slice(0, 10)) throw new v.InputError("Choose a future date within ten years.");
  await db.runTransaction(async tx => {
    const { spaceRef } = await membership(tx, uid);
    const ref = spaceRef.collection("countdowns").doc(id);
    if ((await tx.get(ref)).exists) return;
    const commit = await limit(tx, uid, "countdown", 20);
    commit(); tx.create(ref, { id, title, date, createdBy: uid, createdAt: stamp() });
  });
  return { ok: true };
});
exports.removeItem = callable(async (uid, data) => {
  const id = v.id(data.id), collection = v.text(data.collection, "Collection", 20);
  if (!["moments", "countdowns"].includes(collection)) throw new v.InputError("Invalid item.");
  await db.runTransaction(async tx => {
    const { spaceRef } = await membership(tx, uid);
    const ref = spaceRef.collection(collection).doc(id);
    const item = (await tx.get(ref)).data();
    if (!item) return;
    if (collection === "moments" && item.senderId !== uid) throw new HttpsError("permission-denied", "You can only delete moments you sent.");
    tx.delete(ref);
  });
  return { ok: true };
});
exports.notificationSettings = callable(async (uid, data) => {
  if (typeof data.enabled !== "boolean") throw new v.InputError("Choose a notification preference.");
  await db.doc(`users/${uid}`).update({ notifications: data.enabled });
  return { ok: true };
});
exports.registerDevice = callable(async (uid, data) => {
  const token = v.text(data.token, "Device token", 4096);
  await db.doc(`users/${uid}/devices/${v.hash(token)}`).set({ token, updatedAt: stamp() });
  return { ok: true };
});
exports.unregisterDevice = callable(async (uid, data) => {
  const token = v.text(data.token, "Device token", 4096);
  await db.doc(`users/${uid}/devices/${v.hash(token)}`).delete();
  return { ok: true };
});
exports.discardPhoto = callable(async (uid, data) => {
  const path = v.text(data.path, "Photo path", 250);
  const match = /^spaces\/([A-Za-z0-9_-]+)\/photos\/([^/]+)\/([A-Za-z0-9_-]{8,80})$/.exec(path);
  if (!match || match[2] !== uid) throw new HttpsError("permission-denied", "This photo is not yours.");
  // Never remove a photo if its moment committed, even if the client timed out.
  if ((await db.doc(`spaces/${match[1]}/moments/${match[3]}`).get()).exists) return { ok: true };
  await getStorage().bucket().file(path).delete({ ignoreNotFound: true });
  return { ok: true };
});
async function disconnect(uid) {
  let emptySpace;
  await db.runTransaction(async tx => {
    const ref = db.doc(`users/${uid}`);
    const user = (await tx.get(ref)).data();
    if (!user?.spaceId) return;
    const spaceRef = db.doc(`spaces/${user.spaceId}`);
    const space = (await tx.get(spaceRef)).data();
    const remaining = (space?.memberIds || []).filter(id => id !== uid);
    // Removing membership FIRST immediately revokes database and storage reads.
    tx.update(ref, { spaceId: null, activeInvite: FieldValue.delete(), formerSpaceIds: FieldValue.arrayUnion(user.spaceId) });
    if (space) {
      tx.update(spaceRef, { memberIds: remaining, [`names.${uid}`]: FieldValue.delete() });
      if (!remaining.length) emptySpace = spaceRef.id;
    }
  });
  if (emptySpace) {
    await db.recursiveDelete(db.doc(`spaces/${emptySpace}`));
    await getStorage().bucket().deleteFiles({ prefix: `spaces/${emptySpace}/` });
  }
}
exports.disconnectPartner = callable(async uid => { await disconnect(uid); return { ok: true }; });
exports.exportData = callable(async uid => {
  const profile = (await db.doc(`users/${uid}`).get()).data() || {};
  let space = null, moments = [], countdowns = [], answers = [];
  if (profile.spaceId) {
    const ref = db.doc(`spaces/${profile.spaceId}`);
    space = (await ref.get()).data();
    if (space?.memberIds.includes(uid)) {
      moments = (await ref.collection("moments").get()).docs.map(d => ({ ...d.data(), drawing: d.data().drawing }));
      countdowns = (await ref.collection("countdowns").get()).docs.map(d => d.data());
      const questions = await ref.collection("questions").listDocuments();
      for (const day of questions) {
        const own = await day.collection("answers").doc(uid).get();
        if (own.exists) answers.push({ day: day.id, answers: (await day.collection("answers").get()).docs.map(d => ({ uid: d.id, ...d.data() })) });
      }
    }
  }
  return { profile, space, moments, countdowns, answers };
});
exports.deleteAccount = callable(async (uid, _data, request) => {
  if (Date.now() / 1000 - request.auth.token.auth_time > 300) throw new HttpsError("unauthenticated", "Sign in again before deleting your account.");
  const ref = db.doc(`users/${uid}`);
  await ref.set({ deleting: true }, { merge: true });
  const old = (await ref.get()).data();
  const spaceIds = new Set([...(old?.formerSpaceIds || []), ...(old?.spaceId ? [old.spaceId] : [])]);
  await disconnect(uid);
  // Erase this person's contributions while retaining the partner's own contributions.
  for (const spaceId of spaceIds) {
    const spaceRef = db.doc(`spaces/${spaceId}`);
    const ownMoments = await spaceRef.collection("moments").where("senderId", "==", uid).get();
    for (const doc of ownMoments.docs) await doc.ref.delete();
    const ownDates = await spaceRef.collection("countdowns").where("createdBy", "==", uid).get();
    for (const doc of ownDates.docs) await doc.ref.delete();
    for (const day of await spaceRef.collection("questions").listDocuments()) await day.collection("answers").doc(uid).delete();
    await getStorage().bucket().deleteFiles({ prefix: `spaces/${spaceId}/photos/${uid}/` });
  }
  const invites = await db.collection("invites").where("ownerId", "==", uid).get();
  for (const doc of invites.docs) await doc.ref.delete();
  for (const key of ['profile', 'invite', 'join', 'moment', 'answer', 'countdown']) await db.doc(`rateLimits/${uid}_${key}`).delete();
  await db.recursiveDelete(ref);
  await getAuth().deleteUser(uid);
  return { ok: true };
});
exports.notifyMoment = onDocumentCreated({ document: "spaces/{space}/moments/{moment}", region, maxInstances: 10 }, async event => {
  if (emulator || !event.data) return;
  const moment = event.data.data();
  const space = (await db.doc(`spaces/${event.params.space}`).get()).data();
  if (!space?.memberIds.includes(moment.senderId)) return;
  for (const uid of space.memberIds.filter(id => id !== moment.senderId)) {
    const user = (await db.doc(`users/${uid}`).get()).data();
    if (!user || user.deleting || user.spaceId !== event.params.space || user.notifications !== true) continue;
    const devices = (await db.collection(`users/${uid}/devices`).get()).docs;
    if (!devices.length) continue;
    // Private content is never included in the notification or lock-screen payload.
    const response = await getMessaging().sendEachForMulticast({ tokens: devices.map(d => d.data().token),
      notification: { title: "A little moment for you", body: "Open Pairlight to see what your person shared." },
      data: { spaceId: event.params.space, momentId: event.params.moment },
      android: { priority: "high", notification: { channelId: "pairlight_moments" } },
      apns: { payload: { aps: { sound: "default" } } }
    });
    await Promise.all(response.responses.map((r, i) => !r.success &&
      ["messaging/registration-token-not-registered", "messaging/invalid-registration-token"].includes(r.error?.code)
      ? devices[i].ref.delete() : Promise.resolve()));
  }
});
exports.cleanPhoto = onDocumentDeleted({ document: "spaces/{space}/moments/{moment}", region, maxInstances: 5 }, async event => {
  const path = event.data?.data().photoPath;
  if (path?.startsWith(`spaces/${event.params.space}/photos/`)) await getStorage().bucket().file(path).delete({ ignoreNotFound: true });
});
