const { IpBlock } = require("./Schemas");

async function isIpBlocked(ipAddress) {
  if (!ipAddress) return false;
  const block = await IpBlock.findOne({ ipAddress }).exec();
  return !!block;
}

async function blockIp(ipAddress, reason = "Manual Admin Block") {
  try {
    return await IpBlock.create({ ipAddress, reason });
  } catch (e) {
    if (e.code === 11000) return null; // already blocked
    throw e;
  }
}

async function unblockIp(ipAddress) {
  return IpBlock.findOneAndDelete({ ipAddress }).exec();
}

async function getAllBlockedIps() {
  return IpBlock.find().sort({ createdAt: -1 }).exec();
}

module.exports = {
  isIpBlocked,
  blockIp,
  unblockIp,
  getAllBlockedIps,
};
