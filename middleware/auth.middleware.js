const jwt = require("jsonwebtoken");
const { getRequestToken } = require("../utils/jwt.utils");

function requireAuthApi(req, res, next) {
  const token = getRequestToken(req);

  if (!token) {
    return res.status(401).json({
      errorTitle: "Unauthorized",
      errorBody: "You must sign in first.",
      errorType: "error",
    });
  }

  try {
    req.user = jwt.verify(token, process.env.JWT_SECRET);
    return next();
  } catch (e) {
    return res.status(401).json({
      errorTitle: "Unauthorized",
      errorBody: "Invalid or expired token.",
      errorType: "error",
    });
  }
}

function requireAuthPage(req, res, next) {
  const token = getRequestToken(req);

  if (!token) {
    return res.redirect("/signin");
  }

  try {
    req.user = jwt.verify(token, process.env.JWT_SECRET);
    return next();
  } catch (e) {
    return res.redirect("/signin");
  }
}

function guestOnly(req, res, next) {
  const token = getRequestToken(req);

  if (!token) {
    return next();
  }

  try {
    jwt.verify(token, process.env.JWT_SECRET);
    return res.redirect("/");
  } catch (e) {
    return next();
  }
}

function requireAdmin(req, res, next) {
  const token = getRequestToken(req);

  if (!token) {
    return res.status(401).json({ errorTitle: "Unauthorized", errorBody: "You must sign in.", errorType: "error" });
  }

  try {
    const user = jwt.verify(token, process.env.JWT_SECRET);
    if (user.role !== "admin") {
      return res.status(403).json({ errorTitle: "Forbidden", errorBody: "Admin only.", errorType: "error" });
    }
    req.user = user;
    return next();
  } catch (e) {
    return res.status(401).json({ errorTitle: "Unauthorized", errorBody: "Invalid token.", errorType: "error" });
  }
}

function requireAdminPage(req, res, next) {
  const token = getRequestToken(req);

  if (!token) {
    return res.redirect("/signin");
  }

  try {
    const user = jwt.verify(token, process.env.JWT_SECRET);
    if (user.role !== "admin") {
      return res.redirect("/");
    }
    req.user = user;
    return next();
  } catch (e) {
    return res.redirect("/signin");
  }
}

module.exports = {
  requireAuthApi,
  requireAuthPage,
  guestOnly,
  requireAdmin,
  requireAdminPage
};
