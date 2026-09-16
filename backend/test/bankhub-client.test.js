const { test } = require('node:test');
const assert = require('node:assert/strict');
const { createClient } = require('../src/features/bankhub/bankhub.client');
test('Bank Hub refreshes expired token once and uses sandbox by default', async () => {
  let tokenRequests = 0;
  let calls = 0;
  const client = createClient({environment:'sandbox',clientId:'id',clientSecret:'secret'},async (url,options) => {
    assert.ok(url.startsWith('https://bankhub-api-sandbox.sepay.vn/v1/'));
    if (url.endsWith('/token')) {
      tokenRequests++;
      assert.equal(options.headers.Authorization,'Basic aWQ6c2VjcmV0');
      return {ok:true,json:async()=>({access_token:`token${tokenRequests}`})};
    }
    calls++;
    return calls===1 ? {ok:false,status:401} : {ok:true,json:async()=>({data:[]})};
  });
  assert.deepEqual(await client.call('/company'),{data:[]});
  assert.equal(tokenRequests,2);
  assert.equal(calls,2);
});
test('Bank Hub does not retry ambiguous creates or leak provider errors', async () => {
  let calls = 0;
  const client = createClient({environment:'production',clientId:'id',clientSecret:'secret'},async (url) => {
    if (url.endsWith('/token')) return {ok:true,json:async()=>({access_token:'token'})};
    calls++;
    throw new Error('sensitive provider response');
  });
  await assert.rejects(client.call('/company/create',{}),(error)=>error.status===502 && !error.message.includes('sensitive'));
  assert.equal(calls,1);
});
