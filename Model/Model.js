const { User, SecurityLog, Task, IpBlock } = require("./Schemas");
const { connectDB } = require("./db");
const userModel = require("./User.model");
const securityLogModel = require("./SecurityLog.model");
const taskModel = require("./Task.model");
const ipBlockModel = require("./IpBlock.model");

module.exports = {
  connectDB,
  User,
  SecurityLog,
  Task,
  IpBlock,

  ...userModel,
  ...securityLogModel,
  ...taskModel,
  ...ipBlockModel,
};