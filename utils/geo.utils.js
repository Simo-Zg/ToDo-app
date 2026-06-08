const geoip = require('geoip-lite');

function getClientIp(req) {
  const forwarded = req.headers['x-forwarded-for'];
  if (forwarded) {
    return forwarded.split(',')[0].trim();
  }
  return req.ip || req.socket.remoteAddress || null;
}

function getGeoLocationFromIp(ip) {
  if (!ip || typeof ip !== 'string') return null;
  if (ip === '::1') return { note: 'localhost' };
  if (ip.includes('::ffff:')) ip = ip.replace('::ffff:', '');
  const geo = geoip.lookup(ip);
  if (!geo) return null;
  return {
    country: geo.country || null,
    region: geo.region || null,
    city: geo.city || null,
    timezone: geo.timezone || null,
    latitude: geo.ll ? geo.ll[0] : null,
    longitude: geo.ll ? geo.ll[1] : null
  };
}

module.exports = {
  getClientIp,
  getGeoLocationFromIp
};
