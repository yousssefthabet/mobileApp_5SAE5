# Chargi: AI Reservation Chatbot, server-side reservations, advanced password recovery

## What is implemented and how it is verified

| Feature | State | Verified by |
|---|---|---|
| Advanced forgot password (email, "Check your email", resend countdown, reset page, strength meter) | Implemented | Unit + widget tests with a fake auth service. **Not tested against a real Firebase project.** |
| Transactional reservations (create / cancel / reschedule / search) as Cloud Functions | Implemented | Firestore **emulator** tests, including 8 concurrent bookings of one slot |
| Locked Firestore rules | Implemented | Rules tests in the emulator |
| Chat assistant, rule-based engine (EN + FR) | Implemented | Unit tests + emulator dialogue tests |
| Chat assistant, LLM understanding (Anthropic) | Implemented, **off by default** | Tested only with a fake client. **Never run against the real API.** |
| Payment | **Still simulated** (`paymentStatus: "demo"`) | n/a |

Nothing has been deployed to Firebase, and the app has not been run on a device.

## Architecture

```
Flutter app
  lib/features/auth/          domain (validators, failures) / data (AuthService, AuthRepository) / presentation
  lib/features/reservations/  ReservationRepository -> callable functions
  lib/features/chatbot/       domain (models) / data (ChatRepository, position) / logic (ChatbotController) / presentation
Cloud Functions (functions/src)
  domain.ts                   pure rules: overlap, pricing, validation, connector resolution
  reservations.ts             transactional create / cancel / reschedule / search
  chatbot/                    nlu_rules, nlu_llm, engine, dialog, i18n, time, types
  index.ts                    createReservation, cancelReservation, rescheduleReservation,
                              searchAvailableChargers, chatAssistant
Firestore                     reservations, users/{uid}/reservations (mirror), connector_locks,
                              notifications, ev_chargers, kiosk
```

### Chatbot design (five separated steps)

1. **Understanding**: `nlu_rules.ts` (deterministic) or `nlu_llm.ts` (LLM). Output is only `{intent, date, time, duration, ...}`.
2. **Conversation context**: a small `ChatState` kept by the app and sent every turn (treated as untrusted; sanitised server-side).
3. **Validation**: `domain.ts` (`validateWindow`, connector resolution, ownership checks).
4. **Business actions**: the assistant only **proposes** (`pending`). The app executes after the user taps **Confirm**, through the same secure callable functions as the rest of the app.
5. **Reply generation**: built from real Firestore data and fixed templates (EN/FR). The LLM never writes replies and never runs actions.

The app labels the mode ("Basic mode (rule-based)" vs "AI-powered") using the `engine` field of each response. If the LLM call fails, the turn falls back to rules and is labelled `rules`.

Supported intents: find chargers (optionally near me / for a time window), book (multi-step: date, time, duration, then pick station + connector, then confirm), list reservations, cancel, reschedule, and questions about prices, connector types, power, conditions, statuses, how it works.

### Reservation rules (server)

- 15 min to 8 h, start no more than 15 min in the past, up to 90 days ahead.
- Overlap check per connector inside a Firestore transaction (plus a `connector_locks` document bumped in the same transaction). Back-to-back slots are allowed.
- Only the owner can cancel/reschedule, and only a `confirmed` reservation that has not started. Another user's reservation answers `not-found`.
- Price is computed on the server: `power x hours x pricePerKwh + reservationFee`.
- Statuses written today: `confirmed`, `cancelled`. `completed` / `expired` are defined but **nothing sets them yet** (needs a scheduled function).

### Password recovery flow

Forgot screen -> `sendPasswordResetEmail` -> "Check your email" (neutral message, 60 s resend countdown, change email, back to login) -> link from the email -> new password page (`verifyPasswordResetCode`, strength meter, `confirmPasswordReset`) -> success page. An unknown email looks identical to a known one. Raw Firebase messages are never shown.

## Files

Created: `lib/features/{auth,reservations,chatbot}/**`, `functions/**`, `firestore.indexes.json`, `test/features/**`, `docs/FEATURES.md`.

Modified: `firestore.rules`, `firebase.json`, `analysis_options.yaml` (excludes `functions/`), `pubspec.yaml` (+`cloud_functions`), `lib/screens/auth/forgot_password_screen.dart` (rewritten), `lib/screens/pages/payment_page.dart` (books through the server), `lib/screens/pages/my_reservations_page.dart` (no listing without a user), `lib/screens/pages/main_navigation_page.dart` and `lib/widgets/BottomNavigationBar.dart` (new "Assistant" tab, appended last so existing indices are unchanged).

## Dependencies

Flutter: `cloud_functions`. Functions: `firebase-admin`, `firebase-functions`, `@anthropic-ai/sdk`, `zod`; dev: `typescript`, `firebase-tools`, `@firebase/rules-unit-testing`, `firebase`.

## Firebase configuration required (not done)

1. Access to project `chargi-b044b` (owner/editor) and the **Blaze** plan (Cloud Functions).
2. Deploy **in this order**: `firebase deploy --only functions,firestore:indexes`, then `firebase deploy --only firestore:rules`. Old app builds can no longer write reservations once the new rules are live.
3. Password reset: optional redirect URL via `--dart-define=PASSWORD_RESET_CONTINUE_URL=<url>` (the domain must be in **Authorized domains**); email template is edited in the console. The in-app reset page opens from "I have a reset code" (paste the link); a deep link needs a verified domain (App Links).
4. Existing reservation documents created before this change lack `status`, `end`, `connectorKey`: they do not block slots until migrated.

### Enabling the LLM (optional)

In `functions/.env`: `CHATBOT_USE_LLM=true` (optional `CHATBOT_MODEL=<model id>`, default `claude-opus-5-5`). Then `firebase functions:secrets:set ANTHROPIC_API_KEY`. The key lives only in Secret Manager, never in the app. This costs money per message and should be tried on a few messages first.

## Running and testing

```bash
flutter pub get
flutter analyze
flutter test
```

```bash
cd functions
npm install
npm test                      # pure unit tests (no emulator)
```

Emulator tests need **JDK 21+** (the machine's default JDK 17 is too old; JDK 23 is in `C:\Users\ousse\.jdks\openjdk-23`) and a free port 8185:

```bash
cd functions
npx firebase emulators:exec --only firestore --project demo-chargi --config ../firebase.json "npm run test:all"
```

Run the app against the deployed project: `flutter run`.

## Local testing without deploying (Firebase emulators)

Use this when you cannot deploy to `chargi-b044b`. Functions and Firestore run on your PC; sign-in still uses the real project. Needs JDK 21+ and Node 20.

1. Start the emulators (keep this terminal open):

```bash
cd functions
npm install
npm run emulators
```

On this machine, run `export JAVA_HOME=/c/Users/ousse/.jdks/openjdk-23` first (the default JDK 17 is too old). Ports: functions 5001, Firestore 8185.

2. In a second terminal, load the sample stations and kiosks (the script refuses to run against a real project):

```bash
cd functions
FIRESTORE_EMULATOR_HOST=localhost:8185 npm run seed
```

3. Run the app pointing at the emulators:

```bash
flutter run --dart-define=USE_EMULATOR=true
```

Android emulator uses `10.0.2.2` automatically; Chrome/Windows use `localhost`. On a physical phone add `--dart-define=EMULATOR_HOST=YOUR_PC_IP` (same Wi-Fi). The flag is ignored in release builds. Emulator data is lost when the emulators stop.

## User roles (`user`, `worker`, `admin`)

The role lives in `users/{uid}.role` and is **never chosen by the user**.

| Rule | Where |
|---|---|
| Sign-up creates the profile with `role: "user"` | `lib/screens/auth/SignUpPage.dart` |
| Creation must set `role == "user"`; an update can never add, change or remove `role`; profiles cannot be deleted from the app | `firestore.rules` (`match /users/{userId}`) |
| A profile with no `role` (older accounts) is a plain `user` | `lib/features/users/domain/user_role.dart` |
| The role is read live from Firestore after sign-in; if it cannot be read, the user gets **no** privileges | `lib/features/users/data/user_role_repository.dart`, used by `main_navigation_page.dart` |
| "Worker portal" only appears for `worker` / `admin`; `WorkerJobPage` opens only if the role allows it, even if the flag is set; losing the role while in worker mode leaves it immediately | `lib/screens/pages/main_navigation_page.dart` |

`admin` currently has the same access as `worker` (no admin screen exists yet).

**Honest scope note:** `WorkerJobPage` shows demo data only, so hiding it is a UX control. The real protection is the rule above (nobody can give themselves a role). When real worker data exists, protect it in `firestore.rules` by checking the caller's role, for example with `get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role`.

**Compatibility:** once these rules are deployed, an old app build that does not send `role` at sign-up can no longer create a profile. Ship the updated app first, or accept the rule change for new sign-ups only.

### Giving someone the worker (or admin) role

Only an admin can do this, by hand, from the Firebase console (it bypasses the security rules by design). No redeploy and no app update is needed: the app listens to the role live.

1. Console -> **Authentication -> Users**: find the account and copy its **User UID**.
2. Console -> **Firestore Database -> `users`**: open the document whose ID is that UID.
3. **Add field** (or edit it): name `role`, type **string**, value `worker` (or `admin`). Save.
4. The user sees "Worker portal" in their profile right away. To remove access, set the value back to `user`.

If the document does not exist yet, the person has never completed sign-up in this version: ask them to sign up/sign in first.

Locally (emulators), do the same in the **Emulator UI** at `http://localhost:4000` -> **Firestore** -> `users`. Restart the emulators after changing `firebase.json`.

### Testing the role flow step by step

1. Start the emulators (`npm run emulators` in `functions/`), then the app with `flutter run --dart-define=USE_EMULATOR=true`.
2. Sign up a new account. In the Emulator UI, `users/<uid>` has `role: "user"`. In the app, **Profile** shows no "Worker portal".
3. In the Emulator UI, change `role` to `worker`. Within a second the "Worker portal" entry appears; opening it shows the technician page.
4. Set `role` back to `user`: you are taken out of worker mode and the entry disappears.
5. Delete the `role` field (older account): the app behaves as `user`.
6. Rules tests: `npx firebase emulators:exec --only firestore --project demo-chargi --config ../firebase.json "node --test lib/test/rules.emulator.test.js"` from `functions/` (a user cannot make themselves worker; they can still edit name and phone).

## Fixes after code review

| Fix | Where |
|---|---|
| French "a 14 heures" is read as a clock time (not a 14-hour duration); "pendant/pour 2 heures" stays a duration | `functions/src/chatbot/nlu_rules.ts` |
| Reservations created by the first app version can be listed, cancelled and rescheduled (no more internal error); rescheduling upgrades them to the current format. Documents too incomplete to read give a clear `failed-precondition` | `functions/src/domain.ts` (`normalizeReservation`), `functions/src/reservations.ts` |
| Migration script for old reservations (dry run by default; `--apply` to write; refuses to run on a real project unless `--project` is given) | `functions/scripts/migrate-reservations.js` |
| The Assistant tab starts its conversation (first server call) only when it is opened, not at app launch | `chatbot_page.dart` (`isActive`), `main_navigation_page.dart` |
| Location is never read in the background: it is requested only when the assistant asks (e.g. "nearest station"), reused for that conversation, and forgotten on "New conversation" | `chatbot_controller.dart` |
| Per-user cap on LLM-backed messages (15 per minute, 300 per day, stored in `chat_rate/{uid}`, closed to clients). Over the cap, the rule-based engine answers and the app shows "Basic mode" | `functions/src/chatbot/quota.ts`, `engine.ts`, `index.ts` |

Migration script, locally (build first with `npm run build`):

```bash
FIRESTORE_EMULATOR_HOST=localhost:8185 node scripts/migrate-reservations.js          # dry run
FIRESTORE_EMULATOR_HOST=localhost:8185 node scripts/migrate-reservations.js --apply  # write
```

Not done: App Check is not enforced (it needs setup in the app), and the default LLM model is `claude-opus-5-5` (set `CHATBOT_MODEL` to use a cheaper one).

### Role badge and who assigns roles

- The profile shows the signed-in user's role as a small badge (User / Worker / Admin) under the e-mail: `lib/features/users/presentation/role_badge.dart`, passed to `ProfilePage` from `main_navigation_page.dart`.
- **Nobody can assign a role from the app.** The security rules reject any change to `role` coming from a user, including an admin using the app. Roles are assigned **by hand, in the Firebase console, by a project member with edit access** (Firestore Database -> `users` -> the user's document -> field `role`).
- Today that means the project owner and collaborators with an Editor role in the console. To keep control tight, only give console access to people who may promote others.
- Later, if admins must promote people from inside the app, do it with a Cloud Function that first checks that the caller is an `admin` (never with a client-side write).
