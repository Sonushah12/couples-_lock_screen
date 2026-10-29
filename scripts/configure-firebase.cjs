// Uses the signed-in Firebase CLI account in memory. Never prints or saves its tokens.
const path = require('node:path');
const root = path.join(process.env.APPDATA, 'npm/node_modules/firebase-tools/lib');
const auth = require(path.join(root, 'auth'));
const { requireAuth } = require(path.join(root, 'requireAuth'));
const { ensure } = require(path.join(root, 'ensureApiEnabled'));
const { Client } = require(path.join(root, 'apiv2'));
const project = process.argv[2];
if (!project || !/^[a-z][a-z0-9-]+$/.test(project)) throw new Error('Pass a Firebase project ID.');
(async () => {
  const account = auth.getGlobalDefaultAccount();
  if (!account) throw new Error('Run firebase login first.');
  await requireAuth({ project, user: account.user, tokens: account.tokens, nonInteractive: true });
  for (const api of ['firestore.googleapis.com', 'identitytoolkit.googleapis.com', 'firebaseappcheck.googleapis.com']) {
    await ensure(project, api, 'pairlight', true);
    console.log(`${api} enabled.`);
  }
  const client = new Client({ urlPrefix: 'https://identitytoolkit.googleapis.com' });
  // Firebase Auth can be enabled through config without upgrading to Identity Platform.
  await client.patch(`/admin/v2/projects/${project}/config`, {
    signIn: { email: { enabled: true, passwordRequired: true } },
    emailPrivacyConfig: { enableImprovedEmailPrivacy: true }
  }, { queryParams: { updateMask: 'signIn.email,emailPrivacyConfig' } });
  console.log('Email/password authentication enabled with email privacy.');
})().catch(error => { console.error(error.message); process.exitCode = 1; });
