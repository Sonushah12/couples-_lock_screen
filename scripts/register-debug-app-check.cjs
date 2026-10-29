// Development only. Stores the generated token in an ignored local config, never stdout.
const path = require('node:path');
const fs = require('node:fs');
const crypto = require('node:crypto');
const root = path.join(process.env.APPDATA, 'npm/node_modules/firebase-tools/lib');
const auth = require(path.join(root, 'auth'));
const { requireAuth } = require(path.join(root, 'requireAuth'));
const { Client } = require(path.join(root, 'apiv2'));
(async () => {
  const file = path.resolve('firebase-config.android.json');
  const config = JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
  const project = config.FIREBASE_PROJECT_ID;
  const account = auth.getGlobalDefaultAccount();
  await requireAuth({project,user:account.user,tokens:account.tokens,nonInteractive:true});
  const token = crypto.randomUUID();
  const client = new Client({urlPrefix:'https://firebaseappcheck.googleapis.com'});
  await client.post(`/v1/projects/${config.FIREBASE_SENDER_ID}/apps/${config.FIREBASE_APP_ID}/debugTokens`, {displayName:'Pairlight local development',token});
  fs.writeFileSync(path.resolve('firebase-config.android.debug.json'), JSON.stringify({...config,FIREBASE_APP_CHECK_DEBUG_TOKEN:token},null,2));
  console.log('Development App Check registered. Config saved to firebase-config.android.debug.json (ignored by Git).');
})().catch(e => { console.error(e.message); process.exitCode=1; });
