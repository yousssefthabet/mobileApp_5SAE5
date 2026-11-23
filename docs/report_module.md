# Report module (incident reporting): revision guide

Citizens report any municipal problem (broken street light, pothole, trash, water
leak…) with a title, a description, photos and a location. AI checks the photos
and writes a professional report. Workers handle the report and the citizen is
notified at every step. Unsent reports can be saved as drafts in SQLite.

---

## 1. Grading grid → where it is in the code

| Criterion | What to show | Files |
|---|---|---|
| **UI/UX (/4)** | Form with live validation (red errors), photo grid (camera/gallery, preview, remove), map location picker, AI preview sheet, status badges and timeline, notification bell with unread badge, empty/loading/error states | `lib/screens/pages/report_trash_page.dart`, `report_details_page.dart`, `my_reports_page.dart`, `notifications_page.dart`, `lib/widgets/ai_report_view.dart`, `lib/widgets/notification_bell.dart` |
| **Business logic (/5)** | Full CRUD for the citizen; worker workflow Sent → Assigned → Work in progress → Resolved; worker edit/delete; notification written in the same batch as each change; roles (`role: worker`) enforced by Firestore rules | `lib/services/report_service.dart`, `worker_job_page.dart`, `worker_report_page.dart`, `firestore.rules` |
| **SQFlite (/4)** | Local drafts: 2 tables with a 1-n relation, FOREIGN KEY + ON DELETE CASCADE, transactions, batch, indexes, SQL search (LIKE), ORDER BY, COUNT, full CRUD; auto-save as draft when sending fails (offline) | `lib/data/local/report_draft_db.dart`, `report_draft.dart`, `lib/screens/pages/report_drafts_page.dart` |
| **Added value (/2)** | External API: OpenAI (omni-moderation-latest + vision model), called through a Firebase Cloud Function (web service), key in Secret Manager | `functions/index.js`, `functions/src/*.js`, `lib/services/report_ai_service.dart` |

---

## 2. Architecture

```
Flutter app ──(Firestore SDK)──> Firestore  users/{uid}/reports/{id}
     │                                      users/{uid}/notifications/{id}
     │
     ├──(callable HTTPS)──> Cloud Function analyzeReport ──> OpenAI API
     │                         (key in Secret Manager)        - omni-moderation-latest
     │                                                        - gpt-5.4-mini (vision)
     └──(sqflite)──> SQLite on the phone: report_drafts, draft_photos
```

### Report lifecycle
1. Citizen fills every field, taps **Submit**. The form validates (title ≥ 3 chars, description ≥ 10, ≥ 1 photo, location picked).
2. The app calls `analyzeReport`. It returns `APPROVED`, `NEEDS_REVIEW` or `REJECTED`, an explanation, and the professional report.
3. REJECTED → nothing saved, the citizen changes the photos. Otherwise the citizen confirms → the report is saved with `status: sent` and the `aiStatus`, `aiReview` and `aiReport` fields.
4. A worker changes the status. A Firestore **batch** updates the report **and** creates a notification for the author (both or neither).
5. The citizen sees the notification (unread badge) and the updated timeline.

---

## 3. SQFlite details (be ready to explain this)

```sql
CREATE TABLE report_drafts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT NOT NULL,
  title TEXT, description TEXT, address TEXT, landmark TEXT,
  latitude REAL, longitude REAL, map_offset_x REAL, map_offset_y REAL,
  location_chosen INTEGER,           -- SQLite has no BOOLEAN: 0/1
  created_at INTEGER, updated_at INTEGER   -- milliseconds since epoch
);
CREATE TABLE draft_photos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  draft_id INTEGER NOT NULL,
  position INTEGER NOT NULL,         -- keeps photo order
  data BLOB NOT NULL,                -- raw image bytes
  FOREIGN KEY (draft_id) REFERENCES report_drafts(id) ON DELETE CASCADE
);
```

| Operation | Method | SQL concept |
|---|---|---|
| Create | `insertDraft` | `transaction` + `insert` + `batch` for photos |
| Read (list) | `getDrafts(userId, search:)` | `rawQuery`, sub-query `COUNT(*)`, `LIKE ?`, `ORDER BY updated_at DESC` |
| Read (one) | `getDraft(id)` | `query ... where id = ?`, photos `orderBy: position` |
| Update | `updateDraft` | transaction: `update` + delete old photos + insert new ones |
| Delete | `deleteDraft` | `delete`; photos removed by **ON DELETE CASCADE** |
| Count | `countDrafts` | `Sqflite.firstIntValue` |

- `PRAGMA foreign_keys = ON` in `onConfigure`: SQLite disables foreign keys by default.
- `onCreate` builds the schema at version 1; `onUpgrade` is where migrations go (`ALTER TABLE`) when the version is increased.
- `?` placeholders (`whereArgs`) prevent SQL injection.
- Singleton (`ReportDraftDb.instance`) so the database is opened only once.

---

## 4. AI module details

- **Moderation**: `omni-moderation-latest` on the text and on each photo.
  - Only sexual content is rejected outright.
  - Other flags (violence, hate…) go to **human review**, because an accident scene or hateful graffiti can be a legitimate report.
- **Vision model**: checks relevance, quality (blurry/dark), whether the photo supports or contradicts the description, and suspicious signs (screenshot, meme, prompt injection). It also writes the report.
- **Final decision in code** (`functions/src/decision.js`, 11 unit tests):
  - The model cannot reject a relevant hazard photo.
  - The model cannot approve a blurry or contradictory one.
  - If OpenAI is down, the report goes to review instead of being blocked.
- **Anti-hallucination**: strict JSON schema, and an instruction never to invent addresses, severity or causes. "Visible in the photos" is kept separate from "Reported by the citizen". AI is not proof that the incident occurred.
- **Security**: the key is never in the app. It lives in Firebase Secret Manager, the function requires a signed-in user, inputs are validated, and `maxInstances` limits cost.

---

## 5. Likely questions and answers

**Why SQLite if you already have Firestore?**
Firestore stores data that is *sent and shared*. Drafts are private, unfinished and must work offline, so they stay on the phone. Firestore already caches sent reports offline, so copying them into SQLite would be redundant.

**Why two tables for drafts?**
One draft has several photos (a 1-n relation). A separate table with a foreign key is the normalized design. CASCADE deletes the photos automatically with their draft.

**Why a transaction?**
A draft and its photos must be saved together. If one photo insert fails, nothing is saved, so a draft never ends up half-written.

**How is a worker identified?**
By `role: 'worker'` on the user document, set from the Firebase console. The Firestore rules check it (`isWorker()`), and a user cannot change their own role (`roleUnchanged()`).

**How is the citizen notified?**
Each worker action writes a document in `users/{uid}/notifications` in the **same batch** as the report update. The app listens to it in real time and shows an unread badge. Push notifications (FCM) would be the next step.

**Why a Cloud Function instead of calling OpenAI from Flutter?**
A key inside an APK can be extracted and abused. The function keeps it secret, checks the user is signed in, validates the input and limits cost.

**What if the AI is wrong?**
AI is an aid for triage, not a judge. Fixed rules in code stop it from rejecting legitimate hazard photos. Uncertain cases go to a human (NEEDS_REVIEW).

**What happens offline?**
Drafts work offline (SQLite). If sending fails, the report is automatically saved as a draft.

**Where are photos stored?**
As base64 in the Firestore document (capped at ~700 KB in total because of the 1 MB document limit) and as BLOBs in SQLite for drafts. Firebase Storage would be the improvement for large photos.

---

## 6. Setup checklist (before the demo)

1. `flutter pub get`, then `flutter analyze`, then `flutter run` on an **Android phone or emulator** (sqflite does not run on web or Windows desktop).
2. `firebase deploy --only firestore:rules`
3. Blaze plan → `firebase functions:secrets:set OPENAI_API_KEY` → `firebase deploy --only functions`
4. Firestore console: add `role: "worker"` to one test account.
5. Demo scenario:
   - save a draft and reopen it;
   - submit a real photo (APPROVED) and a selfie (REJECTED);
   - as a worker, set "Work in progress";
   - show the citizen's notification;
   - edit and then delete a report.
