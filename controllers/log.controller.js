const Model = require("../Model/Model");

async function getLogs(req, res) {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const sort = req.query.sort || "latest";

    const data = await Model.getLogs(page, limit, sort);
    return res.status(200).json(data);
  } catch (e) {
    return res.status(500).json({ error: "Server error" });
  }
}

module.exports = {
  getLogs
};
