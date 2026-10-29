const { test, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, collection, getDocs } = require('firebase/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');
const projectId = 'demo-pairlight';
initializeApp({ projectId, storageBucket: `${projectId}.appspot.com` });
const direct = process.env.PAIRLIGHT_DIRECT_FUNCTION_TESTS === 'true';
const backend = direct ? require('../src/index') : null;
const db = getFirestore();
let environment;
const today = new Date().toISOString().slice(0,10);
async function signup(label) {
  const response = await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo', {
    method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({email:`${label}-${Date.now()}@example.test`, password:'Testing-only-123!', returnSecureToken:true})
  });
  const result = await response.json(); assert.ok(result.idToken, JSON.stringify(result.error)); return { uid:result.localId, token:result.idToken };
}
async function call(name, user, data = {}, expected) {
  if (direct) {
    try {
      const result = await backend[name].run({ data, auth: user ? { uid: user.uid, token: JSON.parse(Buffer.from(user.token.split('.')[1], 'base64url')) } : undefined });
      assert.ok(!expected, `Expected ${expected}`);
      return result;
    } catch (error) {
      if (!expected) throw error;
      assert.equal(error.code?.toUpperCase().replaceAll('-', '_'), expected);
      return;
    }
  }
  const response = await fetch(`http://127.0.0.1:5001/${projectId}/asia-south1/${name}`, {
    method:'POST', headers:{'Content-Type':'application/json', ...(user ? {Authorization:`Bearer ${user.token}`} : {})}, body:JSON.stringify({data})
  });
  const result = await response.json();
  if (expected) { assert.equal(result.error?.status, expected, JSON.stringify(result)); return; }
  assert.ok(!result.error, `${name}: ${JSON.stringify(result.error)}`); return result.result;
}
after(async () => { await environment?.cleanup(); });
// HTTP mode starts a separate cold worker for each function on Windows.
test('two partners, intruder isolation, reveal, idempotency, disconnect, deletion', {timeout:direct ? 120000 : 300000}, async () => {
  environment = await initializeTestEnvironment({projectId,
    firestore:{host:'127.0.0.1',port:8080,rules:fs.readFileSync('../firestore.rules','utf8')},
    storage:{host:'127.0.0.1',port:9199,rules:fs.readFileSync('../storage.rules','utf8')}
  });
  await environment.clearFirestore();
  const a = await signup('alex'), b = await signup('jamie'), intruder = await signup('intruder');
  await call('saveProfile', null, {}, 'UNAUTHENTICATED');
  for (const [user,name] of [[a,'Alex'],[b,'Jamie'],[intruder,'Other']]) await call('saveProfile',user,{name,relationship:'Couple',anniversary:'2025-02-14'});
  assert.equal((await db.doc(`users/${b.uid}`).get()).data().notifications, false, 'Notifications require explicit opt-in');
  const invite = await call('createInvite',a);
  assert.match(invite.code, /^[A-F0-9]{12}$/);
  await call('acceptInvite',a,{code:invite.code},'INVALID_ARGUMENT');
  await call('acceptInvite',b,{code:invite.code});
  await call('acceptInvite',b,{code:invite.code});
  await call('acceptInvite',intruder,{code:invite.code},'NOT_FOUND');
  const space = (await db.doc(`users/${a.uid}`).get()).data().spaceId;
  assert.equal((await db.doc(`users/${b.uid}`).get()).data().spaceId,space);
  const aDb = environment.authenticatedContext(a.uid).firestore(), bDb = environment.authenticatedContext(b.uid).firestore(), otherDb = environment.authenticatedContext(intruder.uid).firestore();
  await assertFails(getDoc(doc(otherDb,`spaces/${space}`)));
  await assertFails(getDoc(doc(bDb,`users/${a.uid}`)));
  await assertFails(getDoc(doc(otherDb,`invites/not-a-code`)));
  await assertFails(setDoc(doc(aDb,`spaces/${space}`),{memberIds:[a.uid,intruder.uid]}));
  const payload = {id:'moment_test_0001',kind:'note',content:'Hello partner'};
  await Promise.all([call('sendMoment',a,payload),call('sendMoment',a,payload),call('sendMoment',b,{id:'moment_test_0002',kind:'doodle',content:'A drawing',drawing:[[.1,.2,4280950589],[-1,-1,0]]})]);
  assert.equal((await db.collection(`spaces/${space}/moments`).get()).size,2);
  assert.equal((await assertSucceeds(getDoc(doc(bDb,`spaces/${space}/moments/moment_test_0001`)))).data().content,'Hello partner');
  await call('sendMoment',intruder,{...payload,id:'intruder_moment'},'FAILED_PRECONDITION');
  const aStore = environment.authenticatedContext(a.uid).storage(`gs://${projectId}.appspot.com`);
  const bStore = environment.authenticatedContext(b.uid).storage(`gs://${projectId}.appspot.com`);
  const otherStore = environment.authenticatedContext(intruder.uid).storage(`gs://${projectId}.appspot.com`);
  const photoPath = `spaces/${space}/photos/${a.uid}/photo_test_0001`;
  const photo = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aFf8AAAAASUVORK5CYII=', 'base64');
  await assertSucceeds(aStore.ref(photoPath).put(photo,{contentType:'image/png'}));
  await assertSucceeds(bStore.ref(photoPath).getMetadata());
  await assertFails(otherStore.ref(photoPath).getMetadata());
  await assertFails(bStore.ref(`spaces/${space}/photos/${a.uid}/forged_photo`).put(photo,{contentType:'image/png'}));
  await assertFails(aStore.ref(`spaces/${space}/photos/${a.uid}/invalid_file`).put(photo,{contentType:'text/plain'}));
  await call('sendMoment',a,{id:'photo_test_0001',kind:'photo',content:'Our memory',photoPath});
  await call('saveAnswer',a,{day:today,answer:'Our walk'});
  await assertFails(getDoc(doc(bDb,`spaces/${space}/questions/${today}/answers/${a.uid}`)));
  await call('saveAnswer',b,{day:today,answer:'Our picnic'});
  assert.equal((await assertSucceeds(getDoc(doc(bDb,`spaces/${space}/questions/${today}/answers/${a.uid}`)))).data().answer,'Our walk');
  assert.equal((await assertSucceeds(getDocs(collection(aDb,`spaces/${space}/questions/${today}/answers`)))).size,2);
  await call('addCountdown',a,{id:'countdown_test_1',title:'Our visit',date:today});
  assert.equal((await assertSucceeds(getDocs(collection(bDb,`spaces/${space}/countdowns`)))).size,1);
  await call('removeItem',b,{collection:'moments',id:payload.id},'PERMISSION_DENIED');
  const exported = await call('exportData',a); assert.equal(exported.moments.length,3); assert.equal(exported.answers.length,1);
  await call('notificationSettings',b,{enabled:true});
  assert.equal((await db.doc(`users/${b.uid}`).get()).data().notifications, true);
  await call('notificationSettings',b,{enabled:false});
  await call('registerDevice',b,{token:'test-only-device-token'});
  await call('unregisterDevice',b,{token:'test-only-device-token'});
  await call('disconnectPartner',b);
  await assertFails(bStore.ref(photoPath).getMetadata());
  await assertFails(getDoc(doc(bDb,`spaces/${space}/moments/${payload.id}`)));
  await call('sendMoment',b,{...payload,id:'after_disconnect'},'FAILED_PRECONDITION');
  await call('deleteAccount',b);
  await assert.rejects(getAuth().getUser(b.uid));
  await call('deleteAccount',a);
  await call('saveProfile',a,{name:'Resurrected',relationship:'Couple',anniversary:'2025-02-14'},'UNAUTHENTICATED');
  assert.equal((await db.doc(`spaces/${space}`).get()).exists,false);
  assert.equal((await db.doc(`users/${a.uid}`).get()).exists,false);
});
test('rotated and expired invitations are rejected; concurrent joins keep exactly two members', {timeout:60000}, async () => {
  const owner = await signup('owner'), one = await signup('one'), two = await signup('two');
  for (const user of [owner,one,two]) await call('saveProfile',user,{name:'Test',relationship:'Friends',anniversary:'2025-01-01'});
  const old = await call('createInvite',owner), expired = await call('createInvite',owner);
  await call('acceptInvite',one,{code:old.code},'FAILED_PRECONDITION');
  await db.doc(`invites/${require('../src/validation').hash(expired.code)}`).update({expiresAt:require('firebase-admin/firestore').Timestamp.fromMillis(Date.now()-1000)});
  await call('acceptInvite',one,{code:expired.code},'NOT_FOUND');
  const fresh = await call('createInvite',owner);
  const results = await Promise.allSettled([call('acceptInvite',one,{code:fresh.code}),call('acceptInvite',two,{code:fresh.code})]);
  assert.equal(results.filter(r => r.status === 'fulfilled').length,1);
  const space = (await db.doc(`users/${owner.uid}`).get()).data().spaceId;
  assert.equal((await db.doc(`spaces/${space}`).get()).data().memberIds.length,2);
});
