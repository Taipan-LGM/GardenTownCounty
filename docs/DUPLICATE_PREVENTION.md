# Duplicate Prevention — Deploy notes

## Flutter (client)
- Real-time SA ID / Global Record validation on Member Info form
- Local SQLite UNIQUE + pre-save checks
- Firestore query check when online

## Firebase (cloud)
```bash
cd functions && npm install
firebase deploy --only firestore:rules,firestore:indexes,functions
```

### Collections
- `members` — member documents
- `members_unique_sa_id/{saId}` — uniqueness locks
- `members_unique_global_record/{globalRecordNo}` — uniqueness locks
- `notifications` — duplicate alerts from Cloud Function

Admin UI: drawer → **Duplicate Management**
