const Model = require("../Model/Model");
const { getClientIp, getGeoLocationFromIp } = require("../utils/geo.utils");

async function securityLogMiddleware(req, res, next) {
  res.on("finish", async () => {
    try {
      if (req.path === "/signin" || req.path === "/signup") return;

      const username =
        req.user?.username ||
        req.body?.username ||
        "anonymous";

      const status =
        res.statusCode >= 500
          ? "failure"
          : res.statusCode >= 400
          ? "warning"
          : "success";

      await Model.createSecurityLog({
        username,
        action: req.method.toLowerCase(),
        method: req.method,
        path: req.originalUrl,
        ipAddress: getClientIp(req),
        geoLocation: getGeoLocationFromIp(getClientIp(req)),
        status,
        auditStatus: true,
        details: `HTTP ${res.statusCode}`,
      });
    } catch (e) {
      console.log("Security log middleware error:", e.message);
    }
  });

  next();
}

function getLockDurationMinutes(streak) {
  return Math.max(5, streak * 5);
}

const loginAttemptWindow = new Map();
const MAX_LOGIN_ATTEMPTS_PER_MINUTE = 10;
const LOGIN_WINDOW_MS = 60 * 1000;

function checkLoginRateLimit(key) {
  const now = Date.now();
  const entry = loginAttemptWindow.get(key) || { count: 0, windowStart: now };

  if (now - entry.windowStart > LOGIN_WINDOW_MS) {
    entry.count = 0;
    entry.windowStart = now;
  }

  entry.count += 1;
  loginAttemptWindow.set(key, entry);

  return {
    allowed: entry.count <= MAX_LOGIN_ATTEMPTS_PER_MINUTE,
    remaining: Math.max(0, MAX_LOGIN_ATTEMPTS_PER_MINUTE - entry.count),
    retryAfterMs: Math.max(0, LOGIN_WINDOW_MS - (now - entry.windowStart)),
  };
}

module.exports = {
  securityLogMiddleware,
  getLockDurationMinutes,
  checkLoginRateLimit
};
