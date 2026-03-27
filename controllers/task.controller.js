const Model = require("../Model/Model");

async function getTasks(req, res) {
  try {
    const tasks = await Model.getAllTasks();
    const formatted = tasks.map(t => ({
      id: t._id,
      title: t.title,
      content: t.content,
      date: t.date ? t.date.getTime() : Date.now(),
      owner: t.owner
    }));
    return res.status(200).json(formatted);
  } catch (e) {
    return res.status(500).json({ error: "Server error" });
  }
}

async function getTaskById(req, res) {
  try {
    const task = await Model.getTaskById(req.params.id);
    if (!task) return res.status(404).json({ error: "Task not found" });
    return res.status(200).json({
      id: task._id,
      title: task.title,
      content: task.content,
      date: task.date ? task.date.getTime() : Date.now(),
      owner: task.owner
    });
  } catch (e) {
    return res.status(404).json({ error: "Task not found" });
  }
}

async function createTask(req, res) {
  try {
    const { title, content } = req.body;
    if (!title || !content) {
      return res.status(400).json({ error: "Title and content required" });
    }
    const task = await Model.createTask({
      title,
      content,
      owner: req.user ? req.user.username : "anonymous"
    });
    return res.status(201).json({
      id: task._id,
      title: task.title,
      content: task.content,
      date: task.date ? task.date.getTime() : Date.now(),
      owner: task.owner
    });
  } catch (e) {
    console.log(e);
    return res.status(500).json({ error: "Server error" });
  }
}

async function deleteTask(req, res) {
  try {
    const task = await Model.getTaskById(req.params.id);
    if (!task) return res.status(404).json({ error: "Task not found" });

    if (req.user && req.user.role !== "admin" && task.owner !== req.user.username && task.owner !== "anonymous") {
      return res.status(403).json({ error: "Forbidden: You can only delete your own tasks." });
    }

    await Model.deleteTask(req.params.id);
    return res.status(200).json({ success: true });
  } catch (e) {
    return res.status(500).json({ error: "Server error" });
  }
}

module.exports = {
  getTasks,
  getTaskById,
  createTask,
  deleteTask
};
