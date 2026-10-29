const { test } = require('node:test');
const assert = require('node:assert/strict');
const v = require('../src/validation');
test('reject malformed calendar dates and path IDs', () => {
  assert.throws(() => v.date('2026-02-30'));
  assert.throws(() => v.id('../private'));
  assert.equal(v.date('2026-10-09'), '2026-10-09');
});
test('Firestore drawing representation validates bounds and colors', () => {
  assert.deepEqual(v.drawing([[.1, .2, 4294967295], [-1, -1, 0]]), [{x:.1,y:.2,color:4294967295}, {x:-1,y:-1,color:0}]);
  for (const points of [[[2, .2, 0]], [[NaN, .2, 0]], [[.1, .2, -1]], []]) assert.throws(() => v.drawing(points));
});
test('invitation codes have strong randomness and only hashes are stored', () => {
  const codes = new Set(Array.from({length: 1000}, () => v.inviteCode()));
  assert.equal(codes.size, 1000);
  for (const code of codes) { assert.match(code, /^[0-9A-F]{12}$/); assert.equal(v.hash(code).length, 64); }
});
