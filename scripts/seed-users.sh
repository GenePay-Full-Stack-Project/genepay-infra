#!/bin/bash

# Exit on any error
set -e

ADMIN_EMAIL="sysadmin@genepay.com"
ADMIN_PASSWORD="admin123"
BANK_USERNAME="banktestuser"
BANK_PASSWORD="bankuser123"

# ---------------------------------------------------------------------------
# 1) Generate bcrypt hashes dynamically using the banking-system pod
#    (avoids hardcoding hashes that may not match the intended plaintext)
# ---------------------------------------------------------------------------
echo "0) Pre-generating bcrypt hashes via banking-system pod..."

ADMIN_HASH=$(kubectl exec -i -n genepay deploy/banking-system -- node -e \
  "const b=require('bcryptjs'); b.hash('${ADMIN_PASSWORD}',10).then(h=>process.stdout.write(h))")

if [[ -z "$ADMIN_HASH" ]]; then
  echo "ERROR: Failed to generate hash for admin password. Aborting." >&2
  exit 1
fi
echo "  Admin hash generated."

BANK_HASH=$(kubectl exec -i -n genepay deploy/banking-system -- node -e \
  "const b=require('bcryptjs'); b.hash('${BANK_PASSWORD}',10).then(h=>process.stdout.write(h))")

if [[ -z "$BANK_HASH" ]]; then
  echo "ERROR: Failed to generate hash for bank user password. Aborting." >&2
  exit 1
fi
echo "  Bank user hash generated."

# ---------------------------------------------------------------------------
# 2) Seed Admin user in Payment Service (PostgreSQL)
# ---------------------------------------------------------------------------
echo ""
echo "1) Seeding Admin user in Payment Service (PostgreSQL)..."
kubectl exec -n genepay deploy/postgres -- psql -U postgres -d genepay_db -c "
  INSERT INTO admins (email, password, first_name, last_name, role, status, created_at)
  VALUES (
    '${ADMIN_EMAIL}',
    '${ADMIN_HASH}',
    'System',
    'Admin',
    'ADMIN',
    'ACTIVE',
    NOW()
  )
  ON CONFLICT (email) DO UPDATE SET
    password   = EXCLUDED.password,
    status     = 'ACTIVE';
"

# Verify the row was actually written
STORED_HASH=$(kubectl exec -n genepay deploy/postgres -- psql -U postgres -d genepay_db -t -A -c \
  "SELECT password FROM admins WHERE email='${ADMIN_EMAIL}';")

if [[ -z "$STORED_HASH" ]]; then
  echo "ERROR: Admin row not found in DB after insert. Aborting." >&2
  exit 1
fi
echo "  Admin user seeded. Stored hash: ${STORED_HASH:0:30}..."

# ---------------------------------------------------------------------------
# 3) Seed test user in Banking System (MongoDB)
# ---------------------------------------------------------------------------
echo ""
echo "2) Seeding test user in Banking System (MongoDB Atlas)..."
kubectl exec -i -n genepay deploy/banking-system -- node << JSEOF
  const mongoose = require('mongoose');

  console.log('  Connecting to MongoDB...');
  mongoose.connect(process.env.MONGO_URI)
    .then(async () => {
      await mongoose.connection.db.collection('users').updateOne(
        { username: '${BANK_USERNAME}' },
        {
          \$set: {
            username:     '${BANK_USERNAME}',
            passwordHash: '${BANK_HASH}',
            role:         'user',
            isFirstLogin: false
          }
        },
        { upsert: true }
      );
      const userDoc = await mongoose.connection.db.collection('users').findOne({ username: '${BANK_USERNAME}' });
      
      // Attempt to provision a virtual card as well, so it shows up in the UI
      const CryptoJS = require('crypto-js');
      const fakeCardNum = Math.floor(Math.random() * 1e16).toString().padStart(16, '0');
      const fakeCvv = Math.floor(Math.random() * 1e3).toString().padStart(3, '0');
      
      // Encrypt them exactly like the app does
      const secret = process.env.CARD_SECRET || 'default_secret';
      const encCard = CryptoJS.AES.encrypt(fakeCardNum, secret).toString();
      const encCvv = CryptoJS.AES.encrypt(fakeCvv, secret).toString();

      await mongoose.connection.db.collection('cards').updateOne(
        { userId: userDoc._id },
        {
          \$set: {
            userId: userDoc._id,
            encryptedCardNumber: encCard,
            cvv: encCvv,
            expiry: '12/30',
            balance: 100000,
            createdAt: new Date(),
            updatedAt: new Date()
          }
        },
        { upsert: true }
      );

      console.log('  User ${BANK_USERNAME} successfully upserted into MongoDB (with a Virtual Card!).');
      process.stdout.write('BANK_STORED_HASH=' + userDoc.passwordHash + '\n');
      process.exit(0);
    })
    .catch(err => {
      console.error('  Mongo connection or insertion failed:', err);
      process.exit(1);
    });
JSEOF

# Capture the hash line printed by Node and strip the prefix
STORED_BANK_HASH=$(kubectl exec -i -n genepay deploy/banking-system -- node << JSEOF2 | grep '^BANK_STORED_HASH=' | cut -d'=' -f2-
  const mongoose = require('mongoose');
  mongoose.connect(process.env.MONGO_URI).then(async () => {
    const doc = await mongoose.connection.db.collection('users').findOne({ username: '${BANK_USERNAME}' });
    process.stdout.write('BANK_STORED_HASH=' + doc.passwordHash + '\n');
    process.exit(0);
  }).catch(err => { console.error(err); process.exit(1); });
JSEOF2
)

if [[ -z "$STORED_BANK_HASH" ]]; then
  echo "ERROR: Could not read back bank user hash from MongoDB. Aborting." >&2
  exit 1
fi
echo "  Bank user hash verified: ${STORED_BANK_HASH:0:30}..."

# ---------------------------------------------------------------------------
# 4) Write credentials file
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
OUTPUT_FILE="${SCRIPT_DIR}/seeded-credentials.md"

echo ""
echo "3) Writing credentials to ${OUTPUT_FILE}..."

cat > "$OUTPUT_FILE" << EOF
# Development Seeded Credentials

*Generated on: $(date)*

Accounts inserted directly into active databases via \`kubectl exec\`.
Hashes were generated dynamically at seed time — not hardcoded.

---

## 1. Admin Dashboard Account (Payment Service — PostgreSQL)

| Field    | Value                                                                |
|----------|----------------------------------------------------------------------|
| Email    | \`${ADMIN_EMAIL}\`                                                   |
| Password | \`${ADMIN_PASSWORD}\`                                                |
| Hash     | \`${STORED_HASH}\`                                                   |
| URL      | http://app.genepay.local/                                            |

## 2. Banking System Account (MongoDB)

| Field    | Value                                                                |
|----------|----------------------------------------------------------------------|
| Username | \`${BANK_USERNAME}\`                                                 |
| Password | \`${BANK_PASSWORD}\`                                                 |
| Hash     | \`${STORED_BANK_HASH}\`                                              |
| URL      | http://bank.genepay.local/login                                      |

EOF

echo ""
echo "All done! Credentials written to: ${OUTPUT_FILE}"
echo ""
echo "Quick smoke-test:"
echo "  curl -s -X POST http://api.genepay.local/api/v1/admin/login \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"email\":\"${ADMIN_EMAIL}\",\"password\":\"${ADMIN_PASSWORD}\"}'"