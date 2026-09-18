// End-to-end API test against the linked Supabase project.
//
//   node tool/api_test.mjs
//
// Reads .env (SUPABASE_URL, SUPABASE_ANON_KEY) so keys never appear on a
// command line. No dependencies — Node 18+ built-ins only.
//
// Covers: reachability, schema presence, password auth, RLS isolation, a full
// create/read/update/delete round trip, and the raw_emails dedupe constraint.
// Everything it writes, it deletes.

import fs from 'node:fs';

const env = Object.fromEntries(
  fs.readFileSync('.env', 'utf8')
    .split(/\r?\n/)
    .filter((l) => l.includes('=') && !l.trim().startsWith('#'))
    .map((l) => {
      const i = l.indexOf('=');
      return [l.slice(0, i).trim(), l.slice(i + 1).trim()];
    }),
);

const URL_ = env.SUPABASE_URL?.replace(/\/$/, '');
const ANON = env.SUPABASE_ANON_KEY;
const DEMO_EMAIL = 'demo@uangku.app';
const DEMO_PASSWORD = 'demo1234';

let passed = 0;
let failed = 0;
let blocked = 0;
const ok = (m) => { passed++; console.log(`PASS   ${m}`); };
const bad = (m) => { failed++; console.log(`FAIL   ${m}`); };
const todo = (m) => { blocked++; console.log(`BLOCK  ${m}`); };

if (!URL_ || !ANON || URL_.includes('your-project-ref')) {
  console.log('MISSING_CREDENTIALS — set SUPABASE_URL and SUPABASE_ANON_KEY in .env');
  process.exit(0);
}
console.log(`project: ${URL_}\n`);

const anonHeaders = { apikey: ANON, Authorization: `Bearer ${ANON}` };
const jsonHeaders = { ...anonHeaders, 'Content-Type': 'application/json' };

// ---------------------------------------------------------------- reachability
{
  // /rest/v1/ (the OpenAPI root) is service_role-only, so a 401 there proves
  // reachability but is not a failure. /auth/v1/health is public.
  const r = await fetch(`${URL_}/auth/v1/health`, { headers: anonHeaders });
  r.ok ? ok(`reachability: auth service healthy (${r.status})`)
       : bad(`reachability: auth service ${r.status}`);
}

// --------------------------------------------------------------------- schema
for (const table of ['profiles', 'transactions', 'raw_emails', 'accounts']) {
  const r = await fetch(`${URL_}/rest/v1/${table}?limit=1`, { headers: anonHeaders });
  if (r.ok) ok(`schema: ${table} exists`);
  else todo(`schema: ${table} missing — apply supabase/apply_all.sql (${r.status})`);
}

// Columns the app writes that a table check alone would not catch: the accounts
// feature lives in two places, and one of them silently shipped without the
// other because this file never learned about it.
for (const col of ['account_id', 'transfer_to_account_id', 'source']) {
  const r = await fetch(`${URL_}/rest/v1/transactions?select=${col}&limit=1`, {
    headers: anonHeaders,
  });
  if (r.ok) ok(`schema: transactions.${col} exists`);
  else todo(`schema: transactions.${col} missing — apply supabase/apply_all.sql (${r.status})`);
}

// -------------------------------------------------- auth: reject a bad password
{
  const r = await fetch(`${URL_}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: jsonHeaders,
    body: JSON.stringify({ email: DEMO_EMAIL, password: 'definitely-wrong' }),
  });
  r.status === 400
    ? ok('auth: wrong password is rejected (400)')
    : bad(`auth: wrong password returned ${r.status}, expected 400`);
}

// -------------------------------------------------------- auth: demo sign-in
let session = null;
{
  const r = await fetch(`${URL_}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: jsonHeaders,
    body: JSON.stringify({ email: DEMO_EMAIL, password: DEMO_PASSWORD }),
  });
  const body = await r.json().catch(() => ({}));
  if (r.ok && body.access_token) {
    session = body;
    ok(`auth: ${DEMO_EMAIL} signed in`);
  } else {
    todo(`auth: demo sign-in failed — ${r.status} ${body.error_description ?? body.msg ?? ''}`);
  }
}

if (!session) {
  console.log(`\n${passed} passed, ${failed} failed, ${blocked} blocked (stopping: no session)`);
  process.exit(failed > 0 ? 1 : 0);
}

const authHeaders = {
  apikey: ANON,
  Authorization: `Bearer ${session.access_token}`,
  'Content-Type': 'application/json',
};

// ------------------------------------------------------------- seeded data read
{
  const r = await fetch(`${URL_}/rest/v1/transactions?select=id,total,type&limit=5`, {
    headers: authHeaders,
  });
  const rows = await r.json().catch(() => null);
  if (r.ok && Array.isArray(rows)) {
    rows.length > 0
      ? ok(`read: ${rows.length} seeded transaction(s) visible to the demo user`)
      : todo('read: 0 transactions — demo seed not applied');
  } else {
    bad(`read: transactions ${r.status}`);
  }
}

// ------------------------------------------------------- RLS: anon sees nothing
{
  // The anon key carries no user identity, so RLS must hide every row.
  const r = await fetch(`${URL_}/rest/v1/transactions?select=id`, { headers: anonHeaders });
  const rows = await r.json().catch(() => null);
  if (Array.isArray(rows) && rows.length === 0) {
    ok('rls: anonymous read of transactions returns 0 rows');
  } else if (Array.isArray(rows)) {
    bad(`rls: anonymous read returned ${rows.length} rows — RLS is not protecting transactions`);
  } else {
    todo(`rls: inconclusive (${r.status})`);
  }
}

// -------------------------------------------------------------- CRUD round trip
{
  const created = await fetch(`${URL_}/rest/v1/transactions`, {
    method: 'POST',
    headers: { ...authHeaders, Prefer: 'return=representation' },
    body: JSON.stringify({
      user_id: session.user.id,
      type: 'expense',
      date: '2026-09-14',
      total: 12345,
      notes: 'api-test-row',
      items: [{ name: 'api test', price: '12345' }],
      source: 'manual',
    }),
  });
  const createdRows = await created.json().catch(() => []);
  const row = Array.isArray(createdRows) ? createdRows[0] : null;

  if (created.status === 201 && row?.id) {
    ok(`create: inserted transaction (source=manual)`);

    const updated = await fetch(`${URL_}/rest/v1/transactions?id=eq.${row.id}`, {
      method: 'PATCH',
      headers: { ...authHeaders, Prefer: 'return=representation' },
      body: JSON.stringify({ total: 54321, notes: 'api-test-row-updated' }),
    });
    const updatedRows = await updated.json().catch(() => []);
    const newTotal = Number(updatedRows[0]?.total);
    newTotal === 54321 ? ok('update: total changed to 54321')
                       : bad(`update: got ${JSON.stringify(updatedRows[0]?.total)}`);

    const del = await fetch(`${URL_}/rest/v1/transactions?id=eq.${row.id}`, {
      method: 'DELETE', headers: authHeaders,
    });
    del.status === 204 ? ok('delete: test row removed') : bad(`delete: ${del.status}`);

    const gone = await fetch(`${URL_}/rest/v1/transactions?select=id&id=eq.${row.id}`, {
      headers: authHeaders,
    });
    const goneRows = await gone.json().catch(() => []);
    Array.isArray(goneRows) && goneRows.length === 0
      ? ok('delete: confirmed gone')
      : bad('delete: row still present');
  } else {
    bad(`create: ${created.status} ${JSON.stringify(createdRows).slice(0, 160)}`);
  }
}

// ------------------------------------------------- accounts write round trip
// The schema check above proves the table is there; this proves the app can
// actually use it — an insert refused by a missing table or by RLS is exactly
// the failure that used to look like "my new account didn't appear".
{
  const created = await fetch(`${URL_}/rest/v1/accounts`, {
    method: 'POST',
    headers: { ...authHeaders, Prefer: 'return=representation' },
    body: JSON.stringify({
      user_id: session.user.id,
      name: 'api-test-account',
      kind: 'other',
      icon: 'other',
      color: '#7C5CFF',
    }),
  });
  const createdRows = await created.json().catch(() => []);
  const row = Array.isArray(createdRows) ? createdRows[0] : null;

  if (created.status === 201 && row?.id) {
    ok('accounts: create works (icon stored as an identifier key)');

    const del = await fetch(`${URL_}/rest/v1/accounts?id=eq.${row.id}`, {
      method: 'DELETE', headers: authHeaders,
    });
    del.status === 204 ? ok('accounts: test row removed')
                       : bad(`accounts: delete ${del.status}`);
  } else {
    bad(`accounts: create ${created.status} ${JSON.stringify(createdRows).slice(0, 160)}`);
  }
}

// ------------------------------------------- raw_emails insert + dedupe
{
  const msgId = 'api-test-' + Date.now();
  const row = { user_id: session.user.id, message_id: msgId, body: 'Pembayaran Rp 25.000 pada 14/09/2026' };

  const first = await fetch(`${URL_}/rest/v1/raw_emails`, {
    method: 'POST',
    headers: { ...authHeaders, Prefer: 'return=representation' },
    body: JSON.stringify(row),
  });
  first.status === 201 ? ok('raw_emails: insert works')
                       : bad(`raw_emails: insert ${first.status}`);

  // A bare duplicate must be refused by the (user_id, message_id) constraint.
  const dup = await fetch(`${URL_}/rest/v1/raw_emails`, {
    method: 'POST',
    headers: authHeaders,
    body: JSON.stringify(row),
  });
  dup.status === 409
    ? ok('raw_emails: duplicate rejected with 409 — re-sync cannot double-insert')
    : bad(`raw_emails: duplicate returned ${dup.status}, expected 409`);

  // The way the sync layer should write: explicit conflict target, ignore.
  const ignored = await fetch(
    `${URL_}/rest/v1/raw_emails?on_conflict=user_id,message_id`,
    {
      method: 'POST',
      headers: { ...authHeaders, Prefer: 'return=representation,resolution=ignore-duplicates' },
      body: JSON.stringify({ ...row, body: 'changed' }),
    },
  );
  const ignoredRows = await ignored.json().catch(() => []);
  ignored.ok && ignoredRows.length === 0
    ? ok('raw_emails: on_conflict + ignore-duplicates is silently ignored')
    : bad(`raw_emails: on_conflict insert ${ignored.status} ${JSON.stringify(ignoredRows).slice(0, 120)}`);

  const cleanup = await fetch(
    `${URL_}/rest/v1/raw_emails?message_id=eq.${encodeURIComponent(msgId)}`,
    { method: 'DELETE', headers: authHeaders },
  );
  cleanup.status === 204 ? ok('raw_emails: probe rows cleaned up')
                         : bad(`raw_emails: cleanup ${cleanup.status}`);
}

console.log(`\n${passed} passed, ${failed} failed, ${blocked} blocked`);
process.exit(failed > 0 ? 1 : 0);
