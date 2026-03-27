const mongoose = require("mongoose");

/* ----------------------------- User Schema ----------------------------- */

const userSchema = new mongoose.Schema(
  {
    username: {
      type: String,
      required: true,
      unique: true,
      trim: true,
      minlength: 3,
      maxlength: 64,
      index: true,
    },
    password: {
      type: String,
      required: true,
    },
    role: {
      type: String,
      enum: ["user", "admin"],
      default: "user",
      index: true,
    },
    lastLoginAt: {
      type: Date,
      default: null,
    },
    failedLoginAttempts: {
      type: Number,
      default: 0,
      min: 0,
    },
    failedLoginStreak: {
      type: Number,
      default: 0,
      min: 0,
    },
    lockUntil: {
      type: Date,
      default: null,
    },
    state: {
      type: String,
      enum: ["open", "locked"],
      default: "open",
      index: true,
    },
  },
  {
    timestamps: true,
    versionKey: false,
  }
);

/* --------------------------- Security Log Schema --------------------------- */

const securityLogSchema = new mongoose.Schema(
  {
    username: {
      type: String,
      default: "anonymous",
      trim: true,
      index: true,
    },
    timestamp: {
      type: Date,
      default: Date.now,
      index: true,
    },
    action: {
      type: String,
      required: true,
      trim: true,
      index: true,
    },
    method: {
      type: String,
      default: null,
    },
    path: {
      type: String,
      default: null,
    },
    ipAddress: {
      type: String,
      default: null,
      index: true,
    },
    geoLocation: {
      type: String,
      default: "unknown",
    },
    status: {
      type: String,
      enum: ["success", "failure", "blocked", "warning"],
      required: true,
      index: true,
    },
    severity: {
      type: String,
      enum: ["low", "medium", "high", "critical"],
      required: true,
      index: true,
    },
    auditStatus: {
      type: Boolean,
      default: true,
      index: true,
    },
    details: {
      type: String,
      default: null,
    },
  },
  {
    versionKey: false,
  }
);

/* ------------------------------- Task Schema ------------------------------- */

const taskSchema = new mongoose.Schema(
  {
    title: {
      type: String,
      required: true,
      trim: true,
    },
    content: {
      type: String,
      required: true,
      trim: true,
    },
    date: {
      type: Date,
      default: Date.now,
      index: true,
    },
    owner: {
      type: String,
      default: "anonymous",
      index: true,
    }
  },
  {
    versionKey: false,
  }
);

/* ------------------------------- IpBlock Schema ------------------------------- */

const ipBlockSchema = new mongoose.Schema(
  {
    ipAddress: {
      type: String,
      required: true,
      unique: true,
      index: true,
    },
    reason: {
      type: String,
      default: "Manual Admin Block",
    },
  },
  {
    timestamps: true,
    versionKey: false,
  }
);

/* ------------------------------- Models ------------------------------- */

const User = mongoose.models.User || mongoose.model("User", userSchema);
const SecurityLog = mongoose.models.SecurityLog || mongoose.model("SecurityLog", securityLogSchema);
const Task = mongoose.models.Task || mongoose.model("Task", taskSchema);
const IpBlock = mongoose.models.IpBlock || mongoose.model("IpBlock", ipBlockSchema);

module.exports = {
  User,
  SecurityLog,
  Task,
  IpBlock,
  userSchema,
  securityLogSchema,
  taskSchema,
  ipBlockSchema,
};