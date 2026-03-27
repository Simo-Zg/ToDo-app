const bcrypt = require("bcrypt");
const { User } = require("./Schemas");

async function findUser(username) {
  return User.findOne({ username }).exec();
}

async function getAllUsers() {
  return User.find({}).lean().exec();
}

async function addUserToDB(username, plainPassword, role = "user") {
  try {
    const hashedPassword = await bcrypt.hash(plainPassword, 12);

    const user = await User.create({
      username,
      password: hashedPassword,
      role,
      state: "open",
      failedLoginAttempts: 0,
      failedLoginStreak: 0,
      lastLoginAt: null,
      lockUntil: null,
    });

    return { ok: true, user };
  } catch (e) {
    if (e && e.code === 11000) {
      return { ok: false, error: "duplicate_username" };
    }
    throw e;
  }
}

async function markLoginSuccess(userId) {
  return User.findByIdAndUpdate(
    userId,
    {
      $set: {
        lastLoginAt: new Date(),
        state: "open",
        lockUntil: null,
        failedLoginAttempts: 0,
        failedLoginStreak: 0,
      },
    },
    { new: true }
  ).exec();
}

async function markLoginFailure(userId, lockMinutes) {
  const now = new Date();
  const lockUntil = new Date(now.getTime() + lockMinutes * 60 * 1000);

  return User.findByIdAndUpdate(
    userId,
    {
      $inc: { failedLoginAttempts: 1, failedLoginStreak: 1 },
      $set: { state: "locked", lockUntil },
    },
    { new: true }
  ).exec();
}

async function incrementFailedAttempt(userId) {
  return User.findByIdAndUpdate(
    userId,
    { $inc: { failedLoginAttempts: 1 } },
    { new: true }
  ).exec();
}

async function unlockUserIfExpired(user) {
  if (!user) return null;
  const now = new Date();
  if (user.state === "locked" && user.lockUntil && user.lockUntil <= now) {
    return User.findByIdAndUpdate(
      user._id,
      { $set: { state: "open", lockUntil: null, failedLoginAttempts: 0 } },
      { new: true }
    ).exec();
  }
  return user;
}

async function deleteUserByUsername(username) {
  return User.findOneAndDelete({ username }).exec();
}

async function lockUserByUsername(username) {
  return User.findOneAndUpdate(
    { username },
    { $set: { state: "locked", lockUntil: new Date("2099-01-01T00:00:00Z") } },
    { new: true }
  ).exec();
}

module.exports = {
  findUser,
  getAllUsers,
  addUserToDB,
  markLoginSuccess,
  markLoginFailure,
  incrementFailedAttempt,
  unlockUserIfExpired,
  deleteUserByUsername,
  lockUserByUsername,
};
