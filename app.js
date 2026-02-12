const fs = require("fs/promises");
const express = require("express");
const path = require("path");
const crypto = require("crypto");

const app = express();
const DB_PATH = path.join(__dirname, "DB", "Tasks.json");

app.use(express.json());
app.use(express.static(path.join(__dirname, "public")));

/* ---------- Helpers ---------- */

async function getAllTasks() {
  const data = await fs.readFile(DB_PATH, "utf-8");
  return JSON.parse(data || "[]");
}

async function saveTasks(tasks) {
  await fs.writeFile(DB_PATH, JSON.stringify(tasks, null, 2));
}

/* ---------- Routes ---------- */

app.get("/", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "index.html"));
});

app.get("/api/tasks", async (req, res) => {
  try {
    const tasks = await getAllTasks();
    res.json(tasks);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.get("/api/task/:id", async (req, res) => {
  try {
    const tasks = await getAllTasks();
    const task = tasks.find(t => t.id === req.params.id);

    if (!task) return res.status(404).json({ error: "Task not found" });
    res.json(task);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post("/api/task", async (req, res) => {
  try {
    const { title, content } = req.body;
    if (!title || !content) {
      return res.status(400).json({ error: "Title and content required" });
    }

    const tasks = await getAllTasks();
    const newTask = {
      id: crypto.randomUUID(),
      title,
      content,
      date: Date.now()
    };

    tasks.push(newTask);
    await saveTasks(tasks);

    res.status(201).json(newTask);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.delete("/api/task/:id", async (req, res) => {
  try {
    const tasks = await getAllTasks();
    const newTasks = tasks.filter(t => t.id !== req.params.id);

    if (tasks.length === newTasks.length) {
      return res.status(404).json({ error: "Task not found" });
    }

    await saveTasks(newTasks);
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

module.exports = app;

if (require.main === module) {
  app.listen(5000, () => {
    console.log("Server running on http://127.0.0.1:5000");
  });
}
