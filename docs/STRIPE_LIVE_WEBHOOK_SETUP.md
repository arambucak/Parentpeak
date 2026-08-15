# Stripe Live Webhook Setup Guide

**Status:** Ready for Live Mode Transition  
**Created:** 2026-06-18  
**Last Updated:** 2026-06-18  
**Environment:** Render Production (parentpeak.onrender.com)

---

## Phase 1: Test Mode ✅ COMPLETE

### Completed Tasks:
- ✅ Backend webhook endpoint deployed: `POST /payments/stripe/webhook`
- ✅ Stripe test webhook created in Sandbox mode
- ✅ Test webhook secret configured in the deployment environment (value intentionally omitted)
- ✅ Signature verification working (HMAC-SHA256)
- ✅ Smoke tests passing (3/3 assertions)
- ✅ Production auto-deployment verified (Render)

### Validated Behavior:
```bash
# Invalid signature returns 400
curl -X POST https://parentpeak.onrender.com/payments/stripe/webhook \
  -H 'Content-Type: application/json' \
  -d '{}' 
# → 400 Bad Request: "Ungueltige Stripe-Signatur"

# Valid signature returns 202 Accepted
# (when signed with test secret)
```

---

## Phase 2: Live Mode Setup (IN PROGRESS)

### Step 1: Get Live Webhook Secret from Stripe ⚠️ USER ACTION REQUIRED

**Location:** Stripe Dashboard → Live Mode → Webhooks

1. Go to [Stripe Dashboard - Live Webhooks](https://dashboard.stripe.com/live/workbench/webhooks)
2. Click **"Ziel hinzufügen"** (Add Endpoint)
3. Enter Webhook URL: `https://parentpeak.onrender.com/payments/stripe/webhook`
4. Select events to monitor:
   - `payment_intent.succeeded` ← Primary event
   - `charge.refunded` (optional, for refund handling)
   - Any other relevant payment events
5. Click **Create Endpoint**
6. Copy the **Webhook Signing Secret** (starts with `whsec_`)

**Example Secret Format:**
```
whsec_1AbCdEfGhIjKlMnOpQrStUvWxYz2AbCdEfGhIjKlMnOpQrStUvWxYz3...
```

### Step 2: Update Render Environment Variables

**Method A: Render Dashboard (Recommended)**
1. Go to [Render Dashboard - Environment Variables](https://dashboard.render.com/web/srv-d8q0p5j6sc1c73auvfa0/env)
2. Find `STRIPE_WEBHOOK_SECRET` variable
3. Update its value with the Live secret from Step 1
4. Click **Save** → Render auto-deploys

**Method B: CLI (if available)**
```bash
# Using Render CLI (if configured)
render env set STRIPE_WEBHOOK_SECRET=whsec_<YOUR_LIVE_SECRET>
```

### Step 3: Verify Live Secret Propagation

Wait 30 seconds for Render to redeploy, then verify:

```bash
# Test with invalid signature (should return 400)
curl -sS -w "\nHTTP %{http_code}\n" \
  -X POST https://parentpeak.onrender.com/payments/stripe/webhook \
  -H 'Content-Type: application/json' \
  -d '{}' 
# Expected: 400, "Ungueltige Stripe-Signatur"
```

---

## Phase 3: Production Validation

### Automated Test Suite (Optional)

Run smoke tests with Live credentials:
```bash
# Set Live environment variables
export STRIPE_WEBHOOK_SECRET="whsec_<YOUR_LIVE_SECRET>"
export BACKEND_BASE_URL="https://parentpeak.onrender.com"

# Run full test suite
bash scripts/release_smoke_suite.sh
```

### Manual Validation

1. **Send Real Test Payment** (using Live key):
   - Create test payment in Stripe Live Dashboard
   - Confirm webhook delivery in Stripe Events log
   - Verify your backend processed the event

2. **Check Webhook Deliveries**:
   - Stripe Dashboard → Live → Workbench → Webhooks → Your Endpoint
   - Click endpoint → View Recent Deliveries
   - Verify 200/202 responses for valid payments

3. **Monitor Backend Logs**:
   - Render Dashboard → Parentpeak Service → Logs
   - Look for webhook processing entries
   - Verify no signature errors (`Ungueltige Stripe-Signatur`)

---

## Current Environment Configuration

**Test Mode (Current):**
```env
STRIPE_WEBHOOK_SECRET=whsec_3Lp3U0gA2dseCCtKuSArnMqow75b9rqP  # TEST
BACKEND_BASE_URL=https://parentpeak.onrender.com
STRIPE_WEBHOOK_TOLERANCE_SEC=300
```

**Live Mode (To Be Updated):**
```env
STRIPE_WEBHOOK_SECRET=whsec_<LIVE_SECRET_FROM_STEP_1>        # LIVE
BACKEND_BASE_URL=https://parentpeak.onrender.com              # UNCHANGED
STRIPE_WEBHOOK_TOLERANCE_SEC=300                               # UNCHANGED
```

---

## Implementation Details

### Backend Endpoint
- **Route:** `POST /payments/stripe/webhook`
- **Signature Verification:** Stripe-Signature header with HMAC-SHA256
- **Success Response:** 202 Accepted
- **Error Response:** 400 Bad Request

### Stripe Event Processing
The backend is ready to handle:
- Payment intent events
- Charge events
- Customer events
- Subscription events
- Any webhook from Stripe Live

**No code changes required** - same endpoint works for both Test and Live.

---

## Rollback Plan (If Needed)

If Live webhooks have issues:

1. **Revert to Test Secret:**
   ```bash
   # In Render Dashboard, restore test secret
   STRIPE_WEBHOOK_SECRET=whsec_3Lp3U0gA2dseCCtKuSArnMqow75b9rqP
   ```

2. **Verify Rollback:**
   ```bash
   bash scripts/release_smoke_suite.sh
   ```

3. **Disable Live Webhook (Optional):**
   - Stripe Dashboard → Live → Workbench → Webhooks → Your Endpoint
   - Toggle "Enabled" OFF
   - Or delete endpoint and recreate later

---

## Troubleshooting

### Issue: 400 "Ungueltige Stripe-Signatur"
**Cause:** Webhook secret mismatch or missing Stripe-Signature header
**Solution:** Verify Live secret exactly matches Stripe dashboard value

### Issue: Webhooks not reaching endpoint
**Cause:** URL incorrect or network issue
**Solution:** 
- Verify endpoint URL in Stripe: `https://parentpeak.onrender.com/payments/stripe/webhook`
- Check Render deployment status (should be "Live")
- Review Render logs for connection errors

### Issue: 202 Response but no payment processing
**Cause:** Webhook received but business logic not triggered
**Solution:** Check backend logs for event processing errors

---

## Security Checklist

- [x] Webhook endpoint signature verification implemented
- [x] HMAC-SHA256 validation enabled
- [x] Environment variable separation (test vs live)
- [x] No test secrets in production code
- [x] Webhook tolerance configured (300s)
- [ ] Live secret stored in Render (PENDING)
- [ ] Fire Wall/WAF configured (if applicable)
- [ ] Rate limiting configured (if applicable)

---

## Next Steps

1. **User Action:** Get Live webhook secret from Stripe
2. **User Action:** Update STRIPE_WEBHOOK_SECRET in Render
3. **System:** Auto-deployment begins (30 seconds)
4. **System:** Live webhooks ready to receive events
5. **User Verification:** Monitor webhook deliveries in Stripe

---

## Reference Commands

```bash
# Quick test of endpoint
curl -X GET https://parentpeak.onrender.com/health

# Full webhook test with signature
set -a && source .env && set +a && bash scripts/release_smoke_suite.sh

# Check git log for webhook commits
git log --oneline --grep="webhook" -n 5

# View Render deployment status
echo "Visit: https://dashboard.render.com/web/srv-d8q0p5j6sc1c73auvfa0"
```

---

## Contact & Support

For issues during Live setup:
1. Review this guide
2. Check Stripe webhook event logs
3. Check Render service logs
4. Verify webhook secret matches exactly (no spaces, case-sensitive)

---

**Status Summary:**
- Test Mode: ✅ Complete & Validated
- Live Setup: ⏳ Awaiting Live Secret from Stripe
- Production Ready: ❌ (Requires Step 1 & 2 above)
