// Read-only provisioning status using Firebase CLI authentication in memory.
const path = require('node:path');
const root = path.join(process.env.APPDATA, 'npm/node_modules/firebase-tools/lib');
const auth = require(path.join(root, 'auth'));
const { requireAuth } = require(path.join(root, 'requireAuth'));
const { Client } = require(path.join(root, 'apiv2'));
const project = process.argv[2];
if (!project || !/^[a-z][a-z0-9-]+$/.test(project)) throw new Error('Pass a Firebase project ID.');
(async () => {
  const account = auth.getGlobalDefaultAccount();
  if (!account) throw new Error('Run firebase login first.');
  await requireAuth({ project, user: account.user, tokens: account.tokens, nonInteractive: true });
  const check = async (urlPrefix, endpoint, read) => {
    try {
      const result = await new Client({ urlPrefix }).get(endpoint);
      return read(result.body);
    } catch (error) {
      return { available: false, status: error.status || error.context?.response?.statusCode || 'unavailable' };
    }
  };
  const billing = await check('https://cloudbilling.googleapis.com', `/v1/projects/${project}/billingInfo`, body => ({ enabled: body.billingEnabled === true }));
  const authentication = await check('https://identitytoolkit.googleapis.com', `/admin/v2/projects/${project}/config`, body => ({ initialized: true, emailPassword: body.signIn?.email?.enabled === true }));
  const storage = await check('https://storage.googleapis.com', `/storage/v1/b/${project}.firebasestorage.app`, body => ({ exists: true, location: body.location }));
  console.log(JSON.stringify({ project, billing, authentication, storage }, null, 2));
})().catch(() => { console.error('Could not check provisioning. Reauthenticate the Firebase CLI.'); process.exitCode = 1; });
