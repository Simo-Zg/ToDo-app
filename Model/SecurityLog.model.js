const { SecurityLog } = require("./Schemas");

function computeSeverity({ action, status, auditStatus = true }) {
  const a = String(action || "").toLowerCase();
  const s = String(status || "").toLowerCase();

  if (!auditStatus) return "high";
  if (s === "blocked") return "high";
  if (a === "login" && s === "failure") return "medium";
  if (a === "delete") return "high";
  if (a === "patch" || a === "put") return "medium";
  if (a === "post") return "medium";
  return "low";
}

async function createSecurityLog(log) {
  const severity = log.severity || computeSeverity({ action: log.action, status: log.status, auditStatus: log.auditStatus });
  return SecurityLog.create({
    username: log.username || "anonymous",
    timestamp: log.timestamp || new Date(),
    action: log.action,
    method: log.method || null,
    path: log.path || null,
    ipAddress: log.ipAddress || null,
    geoLocation: log.geoLocation || "unknown",
    status: log.status,
    severity,
    auditStatus: typeof log.auditStatus === "boolean" ? log.auditStatus : true,
    details: log.details || null,
  });
}

async function getLogs(page = 1, limit = 50, sortBy = "latest") {
  const skip = Number((page - 1) * limit);
  const size = Number(limit);

  let sortObj = { timestamp: -1 };
  
  if (sortBy === "oldest") sortObj = { timestamp: 1 };
  else if (sortBy === "name_asc") sortObj = { username: 1 };
  else if (sortBy === "name_desc") sortObj = { username: -1 };
  else if (sortBy === "most_severe" || sortBy === "least_severe") {
    const pipeline = [
      {
        $addFields: {
          sevWeight: {
            $switch: {
              branches: [
                { case: { $eq: ["$severity", "critical"] }, then: 4 },
                { case: { $eq: ["$severity", "high"] }, then: 3 },
                { case: { $eq: ["$severity", "medium"] }, then: 2 },
                { case: { $eq: ["$severity", "low"] }, then: 1 }
              ],
              default: 0
            }
          }
        }
      },
      { $sort: { sevWeight: sortBy === "most_severe" ? -1 : 1, timestamp: -1 } },
      { $skip: skip },
      { $limit: size },
      { $project: { sevWeight: 0 } }
    ];
    
    const [total, logs] = await Promise.all([
      SecurityLog.countDocuments(),
      SecurityLog.aggregate(pipeline)
    ]);
    return { logs, total, page: Number(page), limit: size };
  }

  const [total, logs] = await Promise.all([
    SecurityLog.countDocuments(),
    SecurityLog.find().sort(sortObj).skip(skip).limit(size).lean().exec()
  ]);

  return { logs, total, page: Number(page), limit: size };
}

module.exports = {
  computeSeverity,
  createSecurityLog,
  getLogs,
};
