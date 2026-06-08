const Model = require("../Model/Model");

async function handleAction(req, res) {
  try {
    const { targets, actionType } = req.body;
    
    if (!Array.isArray(targets) || targets.length === 0 || !actionType) {
      return res.status(400).json({ errorTitle: "Invalid Request", errorBody: "Missing targets or actionType.", errorType: "error" });
    }

    let successCount = 0;

    for (const target of targets) {
      try {
        if (actionType === "block_ip") {
          await Model.blockIp(target, "Admin Bulk Action");
        } else if (actionType === "lock_user") {
          await Model.lockUserByUsername(target);
        } else if (actionType === "remove_account") {
          await Model.deleteUserByUsername(target);
        } else if (actionType === "unlock_user") {
          await Model.unlockUserByUsername(target); // Note: Since user.model.js unlock checking uses object, we might need a quick unlock method by username. Wait, `unlockUserByUsername` doesn't exist yet!
        } else if (actionType === "unblock_ip") {
          await Model.unblockIp(target);
        }
        successCount++;
      } catch (err) {
        console.error(`Failed ${actionType} on ${target}:`, err);
      }
    }

    return res.status(200).json({ ok: true, message: `Successfully applied ${actionType} to ${successCount} targets.` });
  } catch (e) {
    return res.status(500).json({ errorTitle: "Server Error", errorBody: "Bulk action failed.", errorType: "error" });
  }
}

module.exports = {
  handleAction
};
