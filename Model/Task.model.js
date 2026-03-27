const { Task } = require("./Schemas");
const { encryptText, decryptText } = require("../utils/crypto.utils");

function decryptTaskProps(doc) {
  if (!doc) return doc;
  if (doc.title) doc.title = decryptText(doc.title);
  if (doc.content) doc.content = decryptText(doc.content);
  return doc;
}

async function getAllTasks() {
  const tasks = await Task.find().sort({ date: -1 }).lean().exec();
  return tasks.map(t => decryptTaskProps(t));
}

async function getTaskById(id) {
  const task = await Task.findById(id).lean().exec();
  return decryptTaskProps(task);
}

async function createTask(data) {
  const payload = { ...data };
  
  if (payload.title) payload.title = encryptText(payload.title);
  if (payload.content) payload.content = encryptText(payload.content);
  
  const doc = await Task.create(payload);
  
  const plainDoc = doc.toObject ? doc.toObject() : { ...doc };
  plainDoc.title = data.title;
  plainDoc.content = data.content;
  return plainDoc;
}

async function deleteTask(id) {
  return Task.findByIdAndDelete(id).exec();
}

module.exports = {
  getAllTasks,
  getTaskById,
  createTask,
  deleteTask,
};
