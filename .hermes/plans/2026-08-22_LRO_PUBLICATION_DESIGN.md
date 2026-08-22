# LRO Publication Feature — Text-Only Design Plan (Payments Section)

> **Mode:** Design plan only. No code, pseudocode, or technical syntax. Pure description, workflows, UI layouts, and business logic.
> **Scope:** The "LRO Publication" button on each Member row in the Payments (Admin Only) screen, the Personal Public Notice form it opens, the Publish flow, and the downstream updates.

---

## 1. "LRO Publication" Button

**Location**
- The button lives on the row for Step 4_LRO, in the expandable Member section of the Payments screen.
- Recommended placement: **immediately to the right of the Step 4_LRO text** (inline on the same line), as a compact outlined button with a small document icon. This keeps it visually tied to the step it publishes, so an Admin sees "Step 4_LRO — [LRO Publication]" together.
- Fallback (narrow widths): if the screen is too narrow for the inline button, it drops to a second line directly beneath the Step 4_LRO row, still right-aligned. It is never moved to the bottom near the Manual/Card Payment buttons, because those are payment actions, not publication actions.

**Appearance**
- Label: "LRO Publication".
- Style: a subtle outlined button (thin border, neutral/admin accent colour), with a document/page icon to the left of the label.
- Size: small, matching the row's checkbox/text height so it does not dominate the step list.

**Behavior & Visibility**
- Visible only to Admin users. Regular members and Recording Secretaries (RS) do not see it.
- Opens the Member's Personal Public Notice form (see Section 2) in a modal overlay or dedicated panel.
- Clicking it does NOT publish — it only opens the form for review.
- The button is always clickable to *open and review* the form, even before payment. However, the Publish action inside the form is disabled until Step 4_LRO payment is completed (see Section 4).

---

## 2. Personal Public Notice Form (Full Layout)

**When it opens**
- Tapping "LRO Publication" opens the form pre-filled with the Member's actual data (name, recording number, payment date, county, seal, status corrections, notice text). If Step 4_LRO payment has not yet been received, the form still opens but shows the placeholders / "pending" state and the Publish button is disabled.

**Field-by-field source (what the form displays)**

| # | Element | Where the value comes from |
|---|---------|----------------------------|
| 1 | Member's Full Name (with the "(C)" marker) | The Member Application Form |
| 2 | 16-digit Recording Number | System-generated number held in LRO Settings for that county |
| 3 | Date of Registration | The date Step 4_LRO payment was received |
| 4 | County Name | County Settings (the active county) |
| 5 | "Land Recording Office" | Fixed, unchanging label |
| 6 | Status Corrections | The list configured by Admin in LRO Settings (only the checked ones show) |
| 7 | County Seal | The seal image uploaded in LRO Settings |
| 8 | Public Notice Text | The template designed in LRO Settings |

**Visual layout (form)**

```
+-----------------------------------------------------------------------+
|                                                                       |
|   +---------------------------------------------------------------+   |
|   |                                                               |   |
|   |                      PUBLIC NOTICE                           |   |
|   |                                                               |   |
|   |                      {COUNTY NAME}                           |   |
|   |                Land Recording Office                         |   |
|   |                                                               |   |
|   |   This is to confirm that:                                   |   |
|   |                                                               |   |
|   |   Member: {FULL NAME} (C)                                     |   |
|   |   Recording Number: {16-DIGIT NUMBER}                        |   |
|   |   Date of Registration: {PAYMENT DATE}                       |   |
|   |                                                               |   |
|   |   Is Status Corrected - 528:                                |   |
|   |   [check] Voter Deregistration                               |   |
|   |   [check] BIO Pages                                          |   |
|   |   [check] 2 x Witness Testimonies                            |   |
|   |   [check] Universal Declaration                              |   |
|   |                                                               |   |
|   |                 [ COUNTY SEAL IMAGE ]                        |   |
|   |                                                               |   |
|   +---------------------------------------------------------------+   |
|                                                                       |
|   +---------------------------------------------------------------+   |
|   |  [ Publish ]  (disabled grey until Step 4_LRO paid)          |   |
|   +---------------------------------------------------------------+   |
|                                                                       |
+-----------------------------------------------------------------------+
```

Notes:
- All header text (PUBLIC NOTICE, County Name, Land Recording Office) is centred.
- All body text below "Land Recording Office" (the confirmation sentence, member lines, status corrections) is left-aligned.
- The status corrections render with a green check mark, no dates.
- The seal sits in its configured position (default bottom-right) and never overlaps the text.
- Everything on the form is drawn from the **active county's** LRO Settings — so if the Admin is viewing Garden Town County, the notice uses Garden Town County's name, seal, and template.

---

## 3. Form Creation Logic

**Creation is a two-stage lifecycle:**

**Stage A — Created with placeholders (draft)**
- The moment a Member's Application Form is completed, the system automatically creates that Member's Personal Public Notice form as a draft.
- At this point the form exists but holds placeholders: the name may be known, but the recording number, payment date, and "completed" status are not yet filled. The form is essentially a template shell waiting for payment data.

**Stage B — Filled in on payment**
- When Step 4_LRO payment is received (manual or card), the system fills the placeholders with the real Member data:
  - Recording Number is set from LRO Settings.
  - Date of Registration becomes the Step 4_LRO payment date.
  - County name, seal, status corrections, and notice text are pulled from the active county's LRO Settings.
- After this, the form is "complete" and the Publish action becomes available.

**Important:** The form is NOT created only at payment time. It is created at Application Form completion (as a draft) and completed at payment. This matches the requirement that publishing can only happen after payment, while the draft already exists for review.

**Per-county behaviour:** Because LRO Settings are per-county, the draft and the filled form always reflect the active county the Admin is working in.

---

## 4. Publish Button

**Availability (gating)**
- The Publish button inside the form is **disabled** until Step 4_LRO payment is marked completed.
- When disabled, it appears greyed with a short hint such as "Complete Step 4_LRO payment to publish."
- The form can still be opened and reviewed before payment; only the Publish action is blocked.

**Confirmation**
- Clicking the (enabled) Publish button opens a confirmation dialog before anything is sent.
- The dialog states: "Are you sure you want to publish this Public Notice?" and lists the three destinations:
  - County Facebook page
  - LRO Publications (in-app)
  - Member's Application Form
- Two actions: "Cancel" and "Confirm Publish".
- This prevents accidental external posting and gives the RS a final review checkpoint.

**Success feedback**
- After confirmation, a success overlay appears:
  - "Published successfully!"
  - A checklist of the three destinations, each marked done (or "skipped" if a destination was not available — see Section 5).
- The form then closes (or returns to the Payments screen) and the Member's Step 4_LRO status updates as described in Section 7.

---

## 5. Publishing Destinations (Detailed Flow)

**Destination 1 — County Facebook Page**
- Content: the generated Public Notice image.
- Caption: "Public Notice for {FULL NAME} – {RECORDING NUMBER}".
- Requirement: a configured Facebook Page access token in LRO Settings.
- If not configured (or the post fails due to no token / no internet): the system **skips** Facebook gracefully, writes a log entry, and shows "County Facebook page (skipped)" in the success checklist. The other two destinations still publish.

**Destination 2 — LRO Publications (in-app)**
- Location: the existing LRO Publications section of the app.
- Content: the Public Notice image.
- Metadata stored with it: Member name, Recording Number, Publication date, publishing RS.
- Visibility: visible to all app users.
- This destination always succeeds (it is local to the app).

**Destination 3 — Member's Application Form**
- Location: next to / to the right of the Member's photo on their Application Form.
- Content: the Public Notice image.
- Format: a thumbnail that opens a full, zoomable view on tap (see Section 9 Q6).
- This destination always succeeds.

**Fail-graceful rule:** If any single destination fails, the others continue. Only the failed destination is marked skipped/failed in the result; the overall publish is still considered successful for the destinations that worked.

---

## 6. Payment Integration

**Trigger chain:**
1. A Member's Step 4_LRO payment is recorded — either via "Manual Payment" or "Card Payment" on the Payments screen.
2. On payment confirmation, the system fills the Personal Public Notice placeholders (Section 3, Stage B).
3. The RS then taps "LRO Publication" next to Step 4_LRO, reviews the now-filled form, and clicks Publish.
4. Publishing is **manual and deliberate** — it is NOT automatic on payment. The RS must open the form and confirm Publish. This protects against publishing an unverified notice.

**Why manual:** Payment confirms the fee; publishing is a separate editorial/legal act (posting to Facebook and the member record) that an RS should review first.

---

## 7. Status Updates After Successful Publishing

Once publishing completes successfully, the system updates the following:

| Item | Update |
|------|--------|
| Member's Step 4_LRO status | Marked "Completed" |
| Member's Recording Number | Already set from payment (no change, just confirmed) |
| LRO Publication flag | Set to true (published) |
| Publication date | Set to current date/time |
| Payment status | Updated to "Completed" |
| Publication audit | A history record is written (who published, when, which destinations) — see Section 9 Q8 |

These updates are reflected immediately on the Payments screen (the Step 4_LRO row shows Completed/Locked) and on the Member's Application Form (the published notice now appears by the photo).

---

## 8. RS Remuneration Settings Connection

- The five steps shown in the Payments section (Step 1_Global 528, Step 2_Global 528, Step 3_Global 928, Step 4_LRO, Step 5_Credential Card) are **not hard-coded** — they are defined in RS Remuneration Settings.
- Admin can rename steps, change amounts, enable/disable steps, and reorder them.
- The Payments screen reads the step definitions from those Settings at display time, so when an Admin changes a name, amount, order, or visibility, the Payments list updates to match (on next load / refresh).
- **Special guard for Step 4_LRO:** Because the LRO Publication feature depends on it, Step 4_LRO should remain present even if an Admin tries to disable it. Recommended rule: Step 4_LRO cannot be fully disabled; if an Admin disables it in Settings, the LRO Publication button is hidden and publishing is blocked, with a note that Step 4_LRO must be enabled. This prevents an orphaned publication flow.

---

## 9. Answers to Part 9 Questions

**Q1 — Button location: right of Step 4_LRO text, or bottom near payment buttons?**
Recommendation: **To the right of the Step 4_LRO text** (inline on the same row). It is contextual to that step and more discoverable there. Keep it off the bottom payment row. If width is tight, drop it to a line directly under Step 4_LRO, still right-aligned — never at the bottom.

**Q2 — Form creation timing: full placeholders at Application Form completion, or only at payment?**
Recommendation: **Create at Application Form completion with placeholders** (draft), then fill the real data when Step 4_LRO payment is received. This lets the RS review the draft early and ensures publishing is only enabled after payment.

**Q3 — Publish disabled until Step 4_LRO payment completed?**
Recommendation: **Yes.** Disable Publish until Step 4_LRO payment is confirmed. The form can be opened for review earlier, but publishing an unpaid member's notice must be blocked.

**Q4 — If Facebook publishing fails, should other destinations continue?**
Recommendation: **Yes — fail gracefully.** Publish the in-app and Member Form destinations, mark Facebook as skipped with a log entry, and show it as "skipped" in the success checklist. Do not roll back the successful destinations.

**Q5 — How do the 5 steps connect to RS Remuneration Settings; should they update dynamically?**
Recommendation: The Payments screen sources its steps from RS Remuneration Settings, so renames/amounts/reorder/visibility changes propagate to the Payments list. Yes, they should update dynamically. Guard Step 4_LRO from being disabled (see Section 8).

**Q6 — Member photo location: thumbnail or full-size image?**
Recommendation: **Thumbnail** next to / right of the Member's photo on the Application Form, which opens a **full, zoomable view** on tap. Thumbnail keeps the form compact; full view satisfies any need to read fine print.

**Q7 — Confirmation dialog before publishing, or publish immediately?**
Recommendation: **Confirmation dialog** (Cancel / Confirm Publish) listing the three destinations. Publishing posts externally (Facebook) and to the member record, so a deliberate confirmation is the safer choice.

**Q8 — Should the system log who published and when?**
Recommendation: **Yes.** Record the publishing RS identity, timestamp, Member, Recording Number, and which destinations succeeded/failed. Surface this in a Publication History view on the Member and in the LRO Publications metadata. This provides accountability and an audit trail.

---

## 10. Updated Wireframe — Payments Screen (with LRO Publication button)

```
+---------------------------------------------------------------------------+
| PAYMENTS                                                      CountyConnect|
| Garden Town County                                                         |
+---------------------------------------------------------------------------+
|                                                                           |
|  [Filter: View All]  [Clear]  [Export CSV]                                |
|                                                                           |
|  +------------------+--------------------------------------------------+   |
|  |  Step            |  Amount                                          |   |
|  +------------------+--------------------------------------------------+   |
|  |  1               |  Global 528  (12 Members)                        |   |
|  |  2               |  Global 528  (8 Members)                         |   |
|  |  3               |  Global 928  (7 Members)                         |   |
|  |  4               |  LRO        (5 Members)                         |   |
|  |  5               |  Credential Card  (3 Members)                  |   |
|  +------------------+--------------------------------------------------+   |
|                                                                           |
|  Total RS Amount: R 6900.00  |  Total Members: 35                         |
|                                                                           |
|  +---------------------------------------------------------------------+   |
|  |  Payment History · 35 record(s)                                    |   |
|  |  Total: R 6900.00                                                  |   |
|  +---------------------------------------------------------------------+   |
|                                                                           |
|  +---------------------------------------------------------------------+   |
|  |  v Mary Brown                                                      |   |
|  |  SA ID: 8512012345678                                              |   |
|  |  Assigned RS: Not assigned                                         |   |
|  |                                                                     |   |
|  |  [ ] Step 1_Global 528 - Completed - R 100.00 - Pending - Due     |   |
|  |  [x] Step 2_Global 528 - Completed - R 200.00 - Pending - Locked  |   |
|  |  [x] Step 3_Global 928 - Not Completed - R 300.00 - Pending - Lock|   |
|  |  [x] Step 4_LRO - Not Completed - R 250.00 - Pending - Locked      |   |
|  |       [ LRO Publication ]                                          |   |
|  |  [x] Step 5_Credential Card - Not Completed - R 250.00 - Pending  |   |
|  |                                                                     |   |
|  |  Total: R 1100.00                                                 |   |
|  |                                                                     |   |
|  |  [ Manual Payment ]  [ Card Payment ]                              |   |
|  +---------------------------------------------------------------------+   |
|                                                                           |
+---------------------------------------------------------------------------+
```

(Per Q1, the "LRO Publication" button sits on the Step 4_LRO row, shown here dropped to its own line beneath the step text for clarity; on wide screens it sits inline to the right of the step text.)

---

## 11. Assumptions & Open Items

- "Admin only" means the same role that already sees the Payments screen.
- The active county context drives all notice content (name, seal, template, recording number) — publishing always uses the county the Admin is currently viewing.
- The existing LRO Publications section and Member Application Form already exist in the app and will receive the published notice; this plan only describes the new button, form, and flow around them.
- "Completed" vs "Locked" states on steps follow the existing Payments screen conventions.
- Publication History is a new audit surface; its exact placement (Member detail vs a global log) can be confirmed later, but the data should be captured from day one.

END OF DESIGN PLAN
