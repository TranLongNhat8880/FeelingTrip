const env = require('../../config/env');
const apiError = require('../../shared/utils/apiError.util');

// Injectable transport keeps tests offline; secrets never leave the backend.
const createClient = (config, transport = (...args) => fetch(...args)) => {
  const base = config.environment === 'production'
    ? 'https://bankhub-api.sepay.vn/v1' : 'https://bankhub-api-sandbox.sepay.vn/v1';
  let token;
  const request = async (path, body, authorization) => {
    try {
      const response = await transport(base + path, {
        method: body === undefined ? 'GET' : 'POST',
        headers: { Authorization: authorization, 'Content-Type': 'application/json' },
        ...(body === undefined ? {} : { body: JSON.stringify(body) }),
        redirect: 'error', signal: AbortSignal.timeout(10000),
      });
      if (!response.ok) {
        const error = apiError(502, 'SePay Bank Hub tạm thời không xử lý được yêu cầu');
        error.providerStatus = response.status;
        throw error;
      }
      return await response.json();
    } catch (error) {
      if (error.status) throw error;
      throw apiError(502, 'Không kết nối được SePay Bank Hub');
    }
  };
  const authorize = async () => {
    if (!config.clientId || !config.clientSecret ||
        !['sandbox', 'production'].includes(config.environment)) {
      throw apiError(503, 'Chưa cấu hình SePay Bank Hub');
    }
    const credentials = Buffer.from(`${config.clientId}:${config.clientSecret}`).toString('base64');
    const response = await request('/token', {}, `Basic ${credentials}`);
    if (!response.access_token) throw apiError(502, 'Phản hồi Bank Hub không hợp lệ');
    token = response.access_token;
  };
  return {
    async call(path, body) {
      if (!token) await authorize();
      try { return await request(path, body, `Bearer ${token}`); }
      catch (error) {
        // Retry only an explicit authentication rejection, never an ambiguous mutation.
        if (error.providerStatus !== 401) throw error;
        await authorize();
        return request(path, body, `Bearer ${token}`);
      }
    },
  };
};
module.exports = createClient(env.bankhub);
module.exports.createClient = createClient;
