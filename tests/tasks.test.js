const request = require("supertest");
const app = require("../app");
const fs = require("fs/promises");
const path = require("path");

const DB_PATH = path.join(__dirname, "../DB/Tasks.json");

beforeEach(async () => {
  await fs.writeFile(DB_PATH, "[]");
});

describe("Tasks API", () => {

  test("POST /api/task creates a task", async () => {
    const res = await request(app)
      .post("/api/task")
      .send({ title: "Test", content: "Hello" });

    expect(res.statusCode).toBe(201);
    expect(res.body.title).toBe("Test");
    expect(res.body.id).toBeDefined();
  });

  test("GET /api/tasks returns tasks", async () => {
    await request(app)
      .post("/api/task")
      .send({ title: "Task", content: "Content" });

    const res = await request(app).get("/api/tasks");

    expect(res.body.length).toBe(1);
    expect(res.body[0].title).toBe("Task");
  });

  test("DELETE /api/task/:id deletes task", async () => {
    const create = await request(app)
      .post("/api/task")
      .send({ title: "Delete me", content: "bye" });

    const id = create.body.id;

    const del = await request(app).delete(`/api/task/${id}`);
    expect(del.statusCode).toBe(200);

    const list = await request(app).get("/api/tasks");
    expect(list.body.length).toBe(0);
  });

});
