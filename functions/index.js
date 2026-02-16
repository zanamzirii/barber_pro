const {onUserDeleted} = require("firebase-functions/v2/identity");
const {logger} = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

exports.cleanupDeletedUserData = onUserDeleted(async (event) => {
  const user = event.data;
  if (!user || !user.uid) return;

  const uid = user.uid;
  logger.info("Starting cleanup for deleted auth user", {uid});

  try {
    const userRef = db.collection("users").doc(uid);
    const userSnap = await userRef.get();
    const userData = userSnap.exists ? userSnap.data() || {} : {};

    // Owner-owned shops cleanup
    const ownedShops = await db.collection("shops").where("ownerId", "==", uid).get();
    for (const shopDoc of ownedShops.docs) {
      await cleanupShopTree(shopDoc.id);
    }

    // Remove barber membership if user had branch link.
    const branchId = pickBranchId(userData);
    if (branchId) {
      await safeDeleteDoc(db.collection("shops").doc(branchId).collection("barbers").doc(uid));
    }

    // Remove top-level user-linked docs (best-effort broad cleanup).
    await deleteTopLevelByUser("appointments", uid);
    await deleteTopLevelByUser("commissions", uid);
    await deleteTopLevelByUser("barber_services", uid);
    await deleteTopLevelByUser("barber_schedules", uid);

    await safeDeleteDoc(userRef);
    logger.info("Cleanup completed for deleted auth user", {uid});
  } catch (e) {
    logger.error("Cleanup failed for deleted auth user", {uid, error: String(e)});
  }
});

function pickBranchId(data) {
  const branchId = typeof data.branchId === "string" ? data.branchId.trim() : "";
  if (branchId) return branchId;
  const shopId = typeof data.shopId === "string" ? data.shopId.trim() : "";
  if (shopId) return shopId;
  return "";
}

async function cleanupShopTree(shopId) {
  const shopRef = db.collection("shops").doc(shopId);

  // Detach and downgrade branch barbers to customer-only link-wise.
  const barbersSnap = await safeGet(shopRef.collection("barbers"));
  for (const barberDoc of barbersSnap.docs) {
    const barberUid = barberDoc.id;
    await detachBarberRoleFromUser(barberUid);
    await safeDeleteDoc(barberDoc.ref);
  }

  await deleteCollectionInBatches(shopRef.collection("services"));
  await deleteCollectionInBatches(shopRef.collection("appointments"));
  await deleteCollectionInBatches(shopRef.collection("barbers"));

  await deleteTopLevelByShop("appointments", shopId);
  await deleteTopLevelByShop("services", shopId);
  await deleteTopLevelByShop("invites", shopId);
  await deleteTopLevelByShop("owner_invites", shopId);
  await deleteTopLevelByShop("barber_invites", shopId);
  await deleteTopLevelByShop("commissions", shopId);
  await deleteTopLevelByShop("barber_services", shopId);
  await deleteTopLevelByShop("barber_schedules", shopId);

  await safeDeleteDoc(shopRef);
}

async function detachBarberRoleFromUser(uid) {
  const userRef = db.collection("users").doc(uid);
  const snap = await safeGetDoc(userRef);
  if (!snap.exists) return;

  const data = snap.data() || {};
  const update = {
    branchId: admin.firestore.FieldValue.delete(),
    shopId: admin.firestore.FieldValue.delete(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  if (Array.isArray(data.roles)) {
    update.roles = data.roles.filter((r) => String(r).toLowerCase() !== "barber");
    if (!update.roles.includes("customer")) update.roles.push("customer");
  } else if (data.roles && typeof data.roles === "object") {
    update["roles.barber"] = false;
    update["roles.customer"] = true;
  } else {
    update.roles = ["customer"];
  }

  const active = typeof data.activeRole === "string" ? data.activeRole.toLowerCase() : "";
  if (active === "barber") {
    update.activeRole = "customer";
    update.role = "customer";
  }

  await safeSet(userRef, update, {merge: true});
}

async function deleteTopLevelByShop(collection, shopId) {
  const byShopId = await safeQueryGet(
      db.collection(collection).where("shopId", "==", shopId).limit(500),
  );
  await deleteDocsInBatches(byShopId.docs.map((d) => d.ref));

  const byBranchId = await safeQueryGet(
      db.collection(collection).where("branchId", "==", shopId).limit(500),
  );
  await deleteDocsInBatches(byBranchId.docs.map((d) => d.ref));
}

async function deleteTopLevelByUser(collection, uid) {
  const keys = ["userId", "customerId", "barberId", "ownerId", "claimedBy"];
  for (const key of keys) {
    const snap = await safeQueryGet(
        db.collection(collection).where(key, "==", uid).limit(500),
    );
    await deleteDocsInBatches(snap.docs.map((d) => d.ref));
  }
}

async function deleteCollectionInBatches(colRef) {
  while (true) {
    const snap = await safeGet(colRef.limit(300));
    if (snap.docs.length === 0) break;
    await deleteDocsInBatches(snap.docs.map((d) => d.ref));
    if (snap.docs.length < 300) break;
  }
}

async function deleteDocsInBatches(refs) {
  if (!refs || refs.length === 0) return;
  let i = 0;
  while (i < refs.length) {
    const batch = db.batch();
    const slice = refs.slice(i, i + 300);
    for (const ref of slice) batch.delete(ref);
    try {
      await batch.commit();
    } catch (e) {
      logger.warn("Batch delete warning", {error: String(e)});
      return;
    }
    i += 300;
  }
}

async function safeDeleteDoc(ref) {
  try {
    await ref.delete();
  } catch (e) {
    logger.warn("safeDeleteDoc warning", {path: ref.path, error: String(e)});
  }
}

async function safeSet(ref, data, options) {
  try {
    await ref.set(data, options);
  } catch (e) {
    logger.warn("safeSet warning", {path: ref.path, error: String(e)});
  }
}

async function safeGet(queryOrCollection) {
  try {
    return await queryOrCollection.get();
  } catch (e) {
    logger.warn("safeGet warning", {error: String(e)});
    return {docs: []};
  }
}

async function safeQueryGet(query) {
  try {
    return await query.get();
  } catch (e) {
    logger.warn("safeQueryGet warning", {error: String(e)});
    return {docs: []};
  }
}

async function safeGetDoc(ref) {
  try {
    return await ref.get();
  } catch (e) {
    logger.warn("safeGetDoc warning", {path: ref.path, error: String(e)});
    return {exists: false, data: () => ({})};
  }
}

