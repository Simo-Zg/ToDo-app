const jwt = require("jsonwebtoken");

function signAccessToken(user) {
  return jwt.sign(
    {
      id: user._id,
      username: user.username,
      role: user.role,
    },
    process.env.JWT_SECRET,
    {
      expiresIn: "15m",
      issuer: "DocsVault",
    }
  );
}

function signRefreshToken(user) {
  return jwt.sign(
    {
      id: user._id,
      username: user.username,
      role: user.role,
    },
    process.env.JWT_REFRESH_SECRET,
    {
      expiresIn: "7d",
      issuer: "DocsVault",
    }
  );
}

function getRequestToken(req) {
  const cookieToken = req.cookies?.access_token;
  const header = req.headers.authorization;
  const headerToken =
    header && header.startsWith("Bearer ") ? header.slice(7) : null;

  return cookieToken || headerToken || null;
}

module.exports = {
  signAccessToken,
  signRefreshToken,
  getRequestToken
};
