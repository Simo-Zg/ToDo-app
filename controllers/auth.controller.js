const bcrypt = require("bcrypt");
const Model = require("../Model/Model");
const jwt = require("jsonwebtoken");
const { signAccessToken, signRefreshToken } = require("../utils/jwt.utils");
const { getClientIp, getGeoLocationFromIp } = require("../utils/geo.utils");
const { checkLoginRateLimit, getLockDurationMinutes } = require("../middleware/security.middleware");

async function signin(req, res) {
  try {
    const { username, password, role, secretPassword } = req.body;
    const ipAddress = getClientIp(req);
    const geoLocation = getGeoLocationFromIp(ipAddress);

    if (!username || !password || !role) {
      await Model.createSecurityLog({
        username: username || "anonymous",
        action: "login",
        method: "POST",
        path: req.originalUrl,
        ipAddress,
        geoLocation,
        status: "failure",
        auditStatus: true,
        details: "Missing username, password, or role",
      });

      return res.status(400).json({ errorTitle: "Missing fields", errorBody: "Username, password, and role are required.", errorType: "error" });
    }

    const rateKey = `${username}:${ipAddress}`;
    const rateCheck = checkLoginRateLimit(rateKey);

    if (!rateCheck.allowed) {
      await Model.createSecurityLog({
        username,
        action: "login",
        method: "POST",
        path: req.originalUrl,
        ipAddress,
        geoLocation,
        status: "blocked",
        auditStatus: true,
        details: "Rate limit exceeded for login attempts",
      });

      return res.status(429).json({ errorTitle: "Too many attempts", errorBody: "Too many login attempts in one minute. Please wait and retry.", errorType: "error" });
    }

    if (role === "Admin" && secretPassword !== process.env.SECRET_PASSWORD) {
      await Model.createSecurityLog({
        username,
        action: "login",
        method: "POST",
        path: req.originalUrl,
        ipAddress,
        geoLocation,
        status: "failure",
        auditStatus: true,
        details: "Invalid admin secret password",
      });

      return res.status(401).json({ errorTitle: "Invalid credentials", errorBody: "The secret password is incorrect. Please retry.", errorType: "error" });
    }

    let user = await Model.findUser(username);

    if (!user) {
      await Model.createSecurityLog({
        username,
        action: "login",
        method: "POST",
        path: req.originalUrl,
        ipAddress,
        geoLocation,
        status: "failure",
        auditStatus: true,
        details: "Username not found",
      });

      return res.status(401).json({ errorTitle: "Invalid credentials", errorBody: "This username is not found. Please use an existing username or sign up.", errorType: "error" });
    }

    user = await Model.unlockUserIfExpired(user);

    if (user.state === "locked" && user.lockUntil && user.lockUntil > new Date()) {
      await Model.createSecurityLog({
        username,
        action: "login",
        method: "POST",
        path: req.originalUrl,
        ipAddress,
        geoLocation,
        status: "blocked",
        auditStatus: true,
        details: `Account locked until ${user.lockUntil.toISOString()}`,
      });

      return res.status(423).json({ errorTitle: "Account locked", errorBody: `Your account is locked until ${user.lockUntil.toLocaleString()}.`, errorType: "error" });
    }

    const ok = await bcrypt.compare(password, user.password);

    if (!ok) {
      const nextAttemptCount = (user.failedLoginAttempts || 0) + 1;

      if (nextAttemptCount >= 10) {
        const nextStreak = (user.failedLoginStreak || 0) + 1;
        const lockMinutes = getLockDurationMinutes(nextStreak);

        user = await Model.markLoginFailure(user._id, lockMinutes);

        await Model.createSecurityLog({
          username,
          action: "login",
          method: "POST",
          path: req.originalUrl,
          ipAddress,
          geoLocation,
          status: "blocked",
          auditStatus: true,
          details: `Too many failed attempts. Account locked for ${lockMinutes} minutes.`,
        });

        return res.status(423).json({ errorTitle: "Account locked", errorBody: `Too many failed attempts. Your account is locked for ${lockMinutes} minutes.`, errorType: "error" });
      }

      await Model.incrementFailedAttempt(user._id);

      await Model.createSecurityLog({
        username,
        action: "login",
        method: "POST",
        path: req.originalUrl,
        ipAddress,
        geoLocation,
        status: "failure",
        auditStatus: true,
        details: `Wrong password. Failed count: ${nextAttemptCount}`,
      });

      return res.status(401).json({ errorTitle: "Invalid credentials", errorBody: "The username or password is incorrect. Please retry.", errorType: "error" });
    }

    user = await Model.markLoginSuccess(user._id);

    const accessToken = signAccessToken(user);
    const refreshToken = signRefreshToken(user);

    const cookie = {
      httpOnly: true,
      sameSite: "Lax",
      secure: false, // set true in HTTPS production
    };

    res.cookie("access_token", accessToken, { ...cookie, maxAge: 15 * 60 * 1000 });
    res.cookie("refresh_token", refreshToken, { ...cookie, path: "/refresh", maxAge: 7 * 24 * 60 * 60 * 1000 });

    await Model.createSecurityLog({
      username,
      action: "login",
      method: "POST",
      path: req.originalUrl,
      ipAddress,
      geoLocation,
      status: "success",
      auditStatus: true,
      details: "Login successful",
    });

    return res.status(200).json({ ok: true, redirectTo: "/notes" });
  } catch (e) {
    console.log(e);
    await Model.createSecurityLog({
      username: req.body?.username || "anonymous",
      action: "login",
      method: "POST",
      path: req.originalUrl,
      ipAddress: getClientIp(req),
      geoLocation: getGeoLocationFromIp(getClientIp(req)),
      status: "failure",
      auditStatus: false,
      details: "Server-side login exception",
    });
    return res.status(500).json({ errorTitle: "Internal Server Error", errorBody: "Login failed due to a server error.", errorType: "error" });
  }
}

async function signup(req, res) {
  try {
    const { username, password, role, secretPassword } = req.body;
    const ipAddress = getClientIp(req);
    const geoLocation = getGeoLocationFromIp(ipAddress);

    if (!username || !password || !role) {
      await Model.createSecurityLog({
        username: username || "anonymous",
        action: "signup",
        method: "POST",
        path: req.originalUrl,
        ipAddress,
        geoLocation,
        status: "failure",
        auditStatus: true,
        details: "Missing username, password, or role",
      });

      return res.status(400).json({ errorTitle: "Missing fields", errorBody: "Username, password, and role are required.", errorType: "error" });
    }

    if (role === "Admin" && secretPassword !== process.env.SECRET_PASSWORD) {
      await Model.createSecurityLog({
        username,
        action: "signup",
        method: "POST",
        path: req.originalUrl,
        ipAddress,
        geoLocation,
        status: "failure",
        auditStatus: true,
        details: "Invalid admin secret password during signup",
      });

      return res.status(401).json({ errorTitle: "Invalid credentials", errorBody: "The secret password is incorrect. Please retry.", errorType: "error" });
    }

    const users = await Model.getAllUsers();
    const existingUser = users.find((u) => u.username === username);

    if (existingUser) {
      await Model.createSecurityLog({
        username,
        action: "signup",
        method: "POST",
        path: req.originalUrl,
        ipAddress,
        geoLocation,
        status: "failure",
        auditStatus: true,
        details: "Username already exists",
      });

      return res.status(409).json({ errorTitle: "Username already used", errorBody: "This username is already used. Use another username or sign in.", errorType: "error" });
    }

    const result = await Model.addUserToDB(username, password, role.toLowerCase());

    if (!result.ok) {
      await Model.createSecurityLog({
        username,
        action: "signup",
        method: "POST",
        path: req.originalUrl,
        ipAddress,
        geoLocation,
        status: "failure",
        auditStatus: false,
        details: "User creation failed",
      });

      return res.status(500).json({ errorTitle: "Sign Up Failed", errorBody: "User was not created in the database. Please retry.", errorType: "error" });
    }

    const accessToken = signAccessToken(result.user);
    const refreshToken = signRefreshToken(result.user);

    const cookie = {
      httpOnly: true,
      sameSite: "Lax",
      secure: false,
    };

    res.cookie("access_token", accessToken, { ...cookie, maxAge: 15 * 60 * 1000 });
    res.cookie("refresh_token", refreshToken, { ...cookie, path: "/refresh", maxAge: 7 * 24 * 60 * 60 * 1000 });

    await Model.createSecurityLog({
      username,
      action: "signup",
      method: "POST",
      path: req.originalUrl,
      ipAddress,
      geoLocation,
      status: "success",
      auditStatus: true,
      details: "Signup successful",
    });

    return res.status(201).json({ ok: true, redirectTo: "/notes" });
  } catch (e) {
    console.log(e);
    return res.status(500).json({ errorTitle: "Internal Server Error", errorBody: "The server encountered an internal error and could not complete sign up.", errorType: "error" });
  }
}

function logout(req, res) {
  const cookieOptions = {
    httpOnly: true,
    sameSite: "Lax",
    secure: false, // set true in HTTPS production
  };

  res.clearCookie("access_token", cookieOptions);
  res.clearCookie("refresh_token", { ...cookieOptions, path: "/refresh" });

  return res.status(200).json({ ok: true, redirectTo: "/signin" });
}

function me(req, res) {
  return res.status(200).json({
    ok: true,
    user: {
      id: req.user.id,
      username: req.user.username,
      role: req.user.role,
    },
  });
}

function refresh(req, res) {
  try {
    const token = req.cookies?.refresh_token;

    if (!token) {
      return res.status(401).json({ errorTitle: "Unauthorized", errorBody: "Missing refresh token.", errorType: "error" });
    }

    const payload = jwt.verify(token, process.env.JWT_REFRESH_SECRET);

    const accessToken = jwt.sign(
      { id: payload.id, username: payload.username, role: payload.role },
      process.env.JWT_SECRET,
      { expiresIn: "15m", issuer: "DocsVault" }
    );

    res.cookie("access_token", accessToken, {
      httpOnly: true,
      sameSite: "Lax",
      secure: false,
      maxAge: 15 * 60 * 1000,
    });

    return res.status(200).json({ ok: true });
  } catch (e) {
    return res.status(401).json({ errorTitle: "Unauthorized", errorBody: "Invalid or expired refresh token.", errorType: "error" });
  }
}

module.exports = {
  signin,
  signup,
  logout,
  me,
  refresh
};
