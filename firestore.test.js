const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const { test, before, after, beforeEach } = require("node:test");
const fs = require("node:fs");

let testEnv;
const PROJECT_ID = "demo-rules-test";
const ALICE_UID = "alice_123";
const BOB_UID = "bob_456";

const [emulatorHost, emulatorPortStr] = (process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8085").split(":");
const emulatorPort = parseInt(emulatorPortStr, 10);

before(async () => {
  const rules = fs.readFileSync("./firestore.rules", "utf8");
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules,
      host: emulatorHost,
      port: emulatorPort,
    },
  });
});

after(async () => {
  if (testEnv) {
    await testEnv.cleanup();
  }
});

beforeEach(async () => {
  if (testEnv) {
    await testEnv.clearFirestore();
  }
});

// --- SECURITY BOUNDS TESTS ---

test("Unauthenticated user: cannot read user profiles or bookings", async () => {
  const unauthDb = testEnv.unauthenticatedContext().firestore();
  await assertFails(unauthDb.collection("users").doc(ALICE_UID).get());
  await assertFails(unauthDb.collection("bookings").doc("bk_1").get());
});

test("Authenticated user: cannot read another user's profile or booking", async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const adminDb = context.firestore();
    await adminDb.collection("users").doc(BOB_UID).set({
      userId: BOB_UID,
      fullName: "Bob Builder",
      email: "bob@example.com",
      createdAt: new Date(),
    });
    await adminDb.collection("bookings").doc("bk_bob").set({
      bookingId: "bk_bob",
      userId: BOB_UID,
      venueId: "vn_1",
      venueTitle: "Badminton Hub",
      totalPrice: 800,
      status: "CONFIRMED",
      createdAt: new Date(),
    });
  });

  const aliceDb = testEnv.authenticatedContext(ALICE_UID).firestore();
  await assertFails(aliceDb.collection("users").doc(BOB_UID).get());
  await assertFails(aliceDb.collection("bookings").doc("bk_bob").get());
});

// --- USER OPERATIONS ---

test("Authenticated user: can create and read their own profile", async () => {
  const aliceDb = testEnv.authenticatedContext(ALICE_UID).firestore();
  await assertSucceeds(
    aliceDb.collection("users").doc(ALICE_UID).set({
      userId: ALICE_UID,
      fullName: "Alice Wonderland",
      email: "alice@example.com",
      role: "USER",
      walletBalance: 500,
      createdAt: new Date(),
    })
  );

  await assertSucceeds(aliceDb.collection("users").doc(ALICE_UID).get());
});

// --- BOOKINGS & QUERIES ---

test("Authenticated user: can create booking and query own bookings with filter", async () => {
  const aliceDb = testEnv.authenticatedContext(ALICE_UID).firestore();
  await assertSucceeds(
    aliceDb.collection("bookings").doc("bk_alice_1").set({
      bookingId: "bk_alice_1",
      userId: ALICE_UID,
      venueId: "vn_badminton",
      venueTitle: "Pro Smash Arena",
      slotTime: "06:00 AM - 07:00 AM",
      bookingDate: "2026-08-25",
      totalPrice: 650,
      status: "CONFIRMED",
      paymentMethod: "UPI",
      createdAt: new Date(),
    })
  );

  // Scoped query succeeds
  await assertSucceeds(
    aliceDb.collection("bookings").where("userId", "==", ALICE_UID).get()
  );

  // Unfiltered list query without where fails (enforcing security)
  await assertFails(aliceDb.collection("bookings").get());
});

// --- SAVED VENUES & REVIEWS ---

test("Authenticated user: can save venue and add review", async () => {
  const aliceDb = testEnv.authenticatedContext(ALICE_UID).firestore();
  await assertSucceeds(
    aliceDb.collection("saved_venues").doc("sv_1").set({
      savedId: "sv_1",
      userId: ALICE_UID,
      venueId: "vn_cricket",
      venueTitle: "Champions Turf",
      createdAt: new Date(),
    })
  );

  await assertSucceeds(
    aliceDb.collection("reviews").doc("rev_1").set({
      reviewId: "rev_1",
      userId: ALICE_UID,
      userName: "Alice",
      venueId: "vn_cricket",
      rating: 5,
      comment: "Excellent artificial turf and lighting!",
      createdAt: new Date(),
    })
  );

  // Public can read reviews
  const unauthDb = testEnv.unauthenticatedContext().firestore();
  await assertSucceeds(unauthDb.collection("reviews").doc("rev_1").get());
});
