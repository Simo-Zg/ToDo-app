const Model = require("../Model/Model");
const { getClientIp } = require("../utils/geo.utils");

async function ipBlockMiddleware(req, res, next) {
  try {
    const ip = getClientIp(req);
    const isBlocked = await Model.isIpBlocked(ip);
    if (isBlocked) {
      return res.status(403).json({ errorTitle: "Access Denied", errorBody: "Your IP address has been heavily restricted by administrators.", errorType: "error" });
    }
  } catch (e) {
    console.error("IP Block middleware error:", e);
  }
  next();
}

module.exports = { ipBlockMiddleware };
