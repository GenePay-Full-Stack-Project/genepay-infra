#!/bin/bash

# Exit on any error
set -e

ADMIN_EMAIL="sysadmin@genepay.com"
ADMIN_PASSWORD="admin123"

BANK_USERNAMES=("banktestuser" "bankuser2" "bankuser3")
BANK_PASSWORDS=("bankuser123" "bankuser456" "bankuser789")

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

declare -a BANK_HASHES
for i in "${!BANK_USERNAMES[@]}"; do
  pw="${BANK_PASSWORDS[$i]}"
  hash=$(kubectl exec -i -n genepay deploy/banking-system -- node -e \
    "const b=require('bcryptjs'); b.hash('${pw}',10).then(h=>process.stdout.write(h))")
  if [[ -z "$hash" ]]; then
    echo "ERROR: Failed to generate hash for ${BANK_USERNAMES[$i]}. Aborting." >&2
    exit 1
  fi
  BANK_HASHES[$i]="$hash"
  echo "  Hash generated for ${BANK_USERNAMES[$i]}."
done

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
# 3) Seed 3 banking users in Banking System (MongoDB), each with a card
# ---------------------------------------------------------------------------
echo ""
echo "2) Seeding 3 banking users in Banking System (MongoDB)..."

declare -a STORED_BANK_HASHES

for i in "${!BANK_USERNAMES[@]}"; do
  username="${BANK_USERNAMES[$i]}"
  bank_hash="${BANK_HASHES[$i]}"
  user_num=$((i + 1))

  echo "  [${user_num}/3] Seeding ${username}..."

  kubectl exec -i -n genepay deploy/banking-system -- node << JSEOF
  const mongoose = require('mongoose');

  mongoose.connect(process.env.MONGO_URI)
    .then(async () => {
      await mongoose.connection.db.collection('users').updateOne(
        { username: '${username}' },
        {
          \$set: {
            username:     '${username}',
            passwordHash: '${bank_hash}',
            role:         'user',
            isFirstLogin: false
          }
        },
        { upsert: true }
      );
      const userDoc = await mongoose.connection.db.collection('users').findOne({ username: '${username}' });

      const CryptoJS = require('crypto-js');
      const fakeCardNum = Math.floor(Math.random() * 1e16).toString().padStart(16, '0');
      const fakeCvv = Math.floor(Math.random() * 1e3).toString().padStart(3, '0');

      const secret = process.env.CARD_SECRET || 'default_secret';
      const encCard = CryptoJS.AES.encrypt(fakeCardNum, secret).toString();
      const encCvv  = CryptoJS.AES.encrypt(fakeCvv, secret).toString();

      await mongoose.connection.db.collection('cards').updateOne(
        { userId: userDoc._id },
        {
          \$set: {
            userId:              userDoc._id,
            encryptedCardNumber: encCard,
            cvv:                 encCvv,
            expiry:              '12/30',
            balance:             100000,
            createdAt:           new Date(),
            updatedAt:           new Date()
          }
        },
        { upsert: true }
      );

      console.log('  User ${username} upserted with a Virtual Card.');
      process.exit(0);
    })
    .catch(err => {
      console.error('  Mongo error for ${username}:', err);
      process.exit(1);
    });
JSEOF

  stored=$(kubectl exec -i -n genepay deploy/banking-system -- node << JSEOF2 | grep '^BANK_STORED_HASH=' | cut -d'=' -f2-
  const mongoose = require('mongoose');
  mongoose.connect(process.env.MONGO_URI).then(async () => {
    const doc = await mongoose.connection.db.collection('users').findOne({ username: '${username}' });
    process.stdout.write('BANK_STORED_HASH=' + doc.passwordHash + '\n');
    process.exit(0);
  }).catch(err => { console.error(err); process.exit(1); });
JSEOF2
)

  if [[ -z "$stored" ]]; then
    echo "ERROR: Could not read back hash for ${username} from MongoDB. Aborting." >&2
    exit 1
  fi
  STORED_BANK_HASHES[$i]="$stored"
  echo "  ${username} hash verified: ${stored:0:30}..."
done

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

## 2. Banking System Accounts (MongoDB)

| # | Username                        | Password                        | Hash (first 30)                  |
|---|---------------------------------|---------------------------------|----------------------------------|
| 1 | \`${BANK_USERNAMES[0]}\`        | \`${BANK_PASSWORDS[0]}\`        | \`${STORED_BANK_HASHES[0]:0:30}\`|
| 2 | \`${BANK_USERNAMES[1]}\`        | \`${BANK_PASSWORDS[1]}\`        | \`${STORED_BANK_HASHES[1]:0:30}\`|
| 3 | \`${BANK_USERNAMES[2]}\`        | \`${BANK_PASSWORDS[2]}\`        | \`${STORED_BANK_HASHES[2]:0:30}\`|

URL: http://bank.genepay.local/login

Each account has a virtual card provisioned with a starting balance of 100,000.

EOF

echo ""
echo "All done! Credentials written to: ${OUTPUT_FILE}"
echo ""
echo "Quick smoke-test:"
echo "  curl -s -X POST http://api.genepay.local/api/v1/admin/login \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"email\":\"${ADMIN_EMAIL}\",\"password\":\"${ADMIN_PASSWORD}\"}'"
