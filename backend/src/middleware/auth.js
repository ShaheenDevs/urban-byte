const jwt = require('jsonwebtoken');
function authenticate(req, res, next) {
  const header = req.headers.authorization || '';
  const [scheme, token] = header.split(' ');
  if (scheme !== 'Bearer' || !token) return res.status(401).json({ success: false, message: 'Authentication required', code: 'UNAUTHENTICATED', data: null });
  try {
    req.auth = jwt.verify(token, process.env.JWT_ACCESS_SECRET, { algorithms: ['HS256'], issuer: 'urban-byte-api', audience: 'urban-byte-app' });
    return next();
  } catch (_) { return res.status(401).json({ success: false, message: 'Invalid or expired access token', code: 'INVALID_TOKEN', data: null }); }
}
module.exports = { authenticate };
