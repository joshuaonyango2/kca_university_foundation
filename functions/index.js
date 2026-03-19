// functions/index.js
// Firebase Cloud Functions — KCA University Foundation
//
// Functions included:
//   1. onDonationCreated      — creates recurring_schedules doc on donation write
//   2. processRecurringDonations — scheduled daily, charges due recurring donations
//   3. cancelRecurringSchedule   — callable, donor/admin can cancel
//   4. sendThankYouEmail         — callable, sends Mailjet thank-you email

const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onSchedule }        = require('firebase-functions/v2/scheduler');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { initializeApp }     = require('firebase-admin/app');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');
const fetch = (...args) =>
  import('node-fetch').then(({ default: f }) => f(...args));

initializeApp();
const db = getFirestore();

// ─────────────────────────────────────────────────────────────────────────────
// HELPER
// ─────────────────────────────────────────────────────────────────────────────
function nextPaymentDate(frequency, fromDate = new Date()) {
  const d = new Date(fromDate);
  if (frequency === 'monthly') d.setMonth(d.getMonth() + 1);
  else if (frequency === 'yearly') d.setFullYear(d.getFullYear() + 1);
  else if (frequency === 'weekly') d.setDate(d.getDate() + 7);
  else return null;
  return Timestamp.fromDate(d);
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. CREATE RECURRING SCHEDULE on new completed donation
// ─────────────────────────────────────────────────────────────────────────────
exports.onDonationCreated = onDocumentCreated(
  'donations/{donationId}',
  async (event) => {
    const donation   = event.data.data();
    const donationId = event.params.donationId;

    if (!donation) return null;
    if (!donation.frequency || donation.frequency === 'one-time') return null;
    if (donation.status !== 'completed') return null;

    const npd = nextPaymentDate(donation.frequency);
    if (!npd) return null;

    await db.collection('recurring_schedules').add({
      donation_id:    donationId,
      donor_id:       donation.donor_id        ?? '',
      donor_name:     donation.donor_name      ?? '',
      donor_email:    donation.donor_email     ?? '',
      donor_phone:    donation.donor_phone     ?? '',
      campaign_id:    donation.campaign_id     ?? '',
      campaign_title: donation.campaign_title  ?? '',
      amount:         donation.amount,
      frequency:      donation.frequency,
      payment_method: donation.payment_method  ?? 'M-Pesa',
      purpose:        donation.purpose         ?? 'General Fund',
      is_anonymous:   donation.is_anonymous    ?? false,
      next_payment_date: npd,
      is_active:      true,
      failure_count:  0,
      last_charged_at: null,
      created_at:     FieldValue.serverTimestamp(),
    });

    console.log(`[Recurring] Schedule created for donation ${donationId}`);
    return null;
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// 2. PROCESS DUE RECURRING DONATIONS — runs daily at 08:00 EAT (05:00 UTC)
// ─────────────────────────────────────────────────────────────────────────────
exports.processRecurringDonations = onSchedule(
  { schedule: '0 5 * * *', timeZone: 'Africa/Nairobi' },
  async () => {
    const now = Timestamp.now();

    const snap = await db.collection('recurring_schedules')
      .where('is_active', '==', true)
      .where('next_payment_date', '<=', now)
      .get();

    if (snap.empty) {
      console.log('[Recurring] No donations due today.');
      return;
    }

    const batch = db.batch();

    snap.docs.forEach((doc) => {
      const s = doc.data();

      // Create new pending donation
      const donRef = db.collection('donations').doc();
      batch.set(donRef, {
        donor_id:       s.donor_id,
        donor_name:     s.donor_name,
        donor_email:    s.donor_email,
        donor_phone:    s.donor_phone,
        campaign_id:    s.campaign_id,
        campaign_title: s.campaign_title,
        amount:         s.amount,
        payment_method: s.payment_method,
        payment_type:   'recurring',
        frequency:      s.frequency,
        purpose:        s.purpose,
        is_anonymous:   s.is_anonymous,
        status:         'pending',
        transaction_id: `REC-${Date.now()}-${Math.random()
          .toString(36).slice(2, 7).toUpperCase()}`,
        recurring_schedule_id: doc.id,
        created_at:     FieldValue.serverTimestamp(),
      });

      // Advance next_payment_date
      const next = nextPaymentDate(
        s.frequency,
        s.next_payment_date.toDate()
      );
      batch.update(doc.ref, {
        next_payment_date: next,
        last_charged_at:   now,
        failure_count:     0,
      });
    });

    await batch.commit();
    console.log(`[Recurring] Processed ${snap.docs.length} donation(s).`);
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// 3. CANCEL RECURRING SCHEDULE — callable by donor or admin
// ─────────────────────────────────────────────────────────────────────────────
exports.cancelRecurringSchedule = onCall(async (request) => {
  const { scheduleId } = request.data;
  if (!scheduleId) throw new HttpsError('invalid-argument', 'scheduleId required.');

  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Must be authenticated.');

  const ref  = db.collection('recurring_schedules').doc(scheduleId);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError('not-found', 'Schedule not found.');

  const data = snap.data();

  // Allow only the owning donor OR an admin
  const staffSnap = await db.collection('staff').doc(uid).get();
  const isAdmin   = staffSnap.exists && staffSnap.data().is_admin === true;
  if (data.donor_id !== uid && !isAdmin) {
    throw new HttpsError('permission-denied', 'Not authorised.');
  }

  await ref.update({
    is_active:    false,
    cancelled_at: FieldValue.serverTimestamp(),
    cancelled_by: uid,
  });

  return { success: true };
});

// ─────────────────────────────────────────────────────────────────────────────
// 4. SEND THANK-YOU EMAIL — callable, uses Mailjet free tier
//    Set secrets before deploy:
//      firebase functions:secrets:set MAILJET_API_KEY
//      firebase functions:secrets:set MAILJET_SECRET_KEY
//      firebase functions:secrets:set SENDER_EMAIL
// ─────────────────────────────────────────────────────────────────────────────
exports.sendThankYouEmail = onCall(async (request) => {
  const { donorName, donorEmail, amount, campaignTitle, transactionId } =
    request.data;

  if (!donorEmail || !donorName || !amount) {
    throw new HttpsError('invalid-argument', 'Missing required fields.');
  }

  const apiKey      = process.env.MAILJET_API_KEY;
  const secretKey   = process.env.MAILJET_SECRET_KEY;
  const senderEmail = process.env.SENDER_EMAIL ?? 'noreply@kcau.ac.ke';

  if (!apiKey || !secretKey) {
    throw new HttpsError('internal', 'Email service not configured.');
  }

  const amountFmt = Number(amount).toLocaleString('en-KE');
  const dateFmt   = new Date().toLocaleDateString('en-KE', { dateStyle: 'long' });

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width,initial-scale=1.0">
  <style>
    body{font-family:Arial,sans-serif;background:#f5f6fa;margin:0;padding:0}
    .wrap{max-width:600px;margin:32px auto;background:#fff;border-radius:12px;
          overflow:hidden;box-shadow:0 4px 20px rgba(0,0,0,.08)}
    .hdr{background:#1B2263;padding:32px 24px;text-align:center}
    .hdr h1{color:#F5A800;font-size:22px;margin:0 0 4px}
    .hdr p{color:rgba(255,255,255,.7);margin:0;font-size:13px}
    .body{padding:32px 24px}
    .amt{background:linear-gradient(135deg,#1B2263,#2a3580);border-radius:12px;
         padding:24px;text-align:center;margin:24px 0}
    .amt .lbl{color:rgba(255,255,255,.7);font-size:13px;margin-bottom:4px}
    .amt .val{color:#F5A800;font-size:36px;font-weight:bold}
    .row{display:flex;justify-content:space-between;padding:10px 0;
         border-bottom:1px solid #f0f0f0;font-size:14px}
    .row:last-child{border-bottom:none}
    .lbl2{color:#888}.val2{color:#1B2263;font-weight:600}
    .btn{display:inline-block;background:#F5A800;color:#1B2263;padding:12px 28px;
         border-radius:8px;text-decoration:none;font-weight:bold;font-size:14px;
         margin-top:20px}
    .ftr{background:#f8f9fc;padding:20px 24px;text-align:center;
         font-size:12px;color:#aaa}
    .ftr a{color:#1B2263}
  </style>
</head>
<body>
  <div class="wrap">
    <div class="hdr">
      <h1>🎓 KCA University Foundation</h1>
      <p>Transforming lives through education</p>
    </div>
    <div class="body">
      <p style="font-size:16px;color:#1B2263;font-weight:bold">Dear ${donorName},</p>
      <p style="color:#555;line-height:1.7">
        Thank you for your generous contribution to the KCA University Foundation.
        Your donation makes a real difference in the lives of students and our community.
      </p>
      <div class="amt">
        <div class="lbl">Donation Amount</div>
        <div class="val">KES ${amountFmt}</div>
      </div>
      <div style="background:#f8f9fc;border-radius:10px;padding:16px">
        <div class="row">
          <span class="lbl2">Campaign</span>
          <span class="val2">${campaignTitle ?? 'General Fund'}</span>
        </div>
        <div class="row">
          <span class="lbl2">Transaction ID</span>
          <span class="val2">${transactionId ?? 'N/A'}</span>
        </div>
        <div class="row">
          <span class="lbl2">Date</span>
          <span class="val2">${dateFmt}</span>
        </div>
      </div>
      <p style="color:#555;font-size:13px;line-height:1.7;margin-top:20px">
        Your support enables us to provide scholarships, develop infrastructure,
        and fund research that shapes tomorrow's leaders.
      </p>
      <center>
        <a href="https://kca-university-foundation.web.app" class="btn">
          View My Donations
        </a>
      </center>
    </div>
    <div class="ftr">
      KCA University Foundation · P.O. Box 56808-00200, Nairobi, Kenya<br>
      📞 0710 888 022 · ✉️ <a href="mailto:kcauf@kcau.ac.ke">kcauf@kcau.ac.ke</a>
    </div>
  </div>
</body>
</html>`;

  const payload = {
    Messages: [{
      From: { Email: senderEmail, Name: 'KCA University Foundation' },
      To:   [{ Email: donorEmail, Name: donorName }],
      Subject: `Thank you for your donation, ${donorName}! 🎓`,
      HTMLPart: html,
      TextPart: `Dear ${donorName}, thank you for your KES ${amountFmt} donation to ` +
                `${campaignTitle ?? 'KCA University Foundation'}. TXN: ${transactionId}.`,
    }],
  };

  const resp = await fetch('https://api.mailjet.com/v3.1/send', {
    method: 'POST',
    headers: {
      'Content-Type':  'application/json',
      Authorization:
        'Basic ' + Buffer.from(`${apiKey}:${secretKey}`).toString('base64'),
    },
    body: JSON.stringify(payload),
  });

  if (!resp.ok) {
    const err = await resp.text();
    console.error('[Email] Mailjet error:', err);
    throw new HttpsError('internal', 'Failed to send email.');
  }

  console.log(`[Email] Thank-you sent to ${donorEmail}`);
  return { success: true };
});