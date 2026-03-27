require("dotenv").config();
const express = require("express");
const path = require("path");
const cors = require("cors");
const cookieParser = require("cookie-parser");

const Model = require("./Model/Model");

// Controllers
const authController = require("./controllers/auth.controller");
const pageController = require("./controllers/page.controller");
const taskController = require("./controllers/task.controller");
const logController = require("./controllers/log.controller");
const adminController = require("./controllers/admin.controller");

// Middlewares
const { requireAuthApi, requireAuthPage, guestOnly, requireAdmin, requireAdminPage } = require("./middleware/auth.middleware");
const { securityLogMiddleware } = require("./middleware/security.middleware");
const { ipBlockMiddleware } = require("./middleware/ip.middleware");

const app = express();
const PUBLIC_DIR = path.join(__dirname, "public");

app.use(cookieParser());
app.use(express.json());
app.use(express.urlencoded({ extended: false }));
app.use(express.static(PUBLIC_DIR));

app.use(
  cors({
    origin: `http://127.0.0.1:${process.env.PORT}`,
    credentials: true,
  })
);

app.use(securityLogMiddleware);
app.use(ipBlockMiddleware);

/* ----------------------------- Page Endpoints ----------------------------- */

app.get("/", pageController.renderLanding);
app.get("/notes", requireAuthPage, pageController.renderApp);
app.get("/signin", guestOnly, pageController.renderSignin);
app.get("/signup", guestOnly, pageController.renderSignup);
app.get("/dashboard", requireAdminPage, pageController.renderDashboard);

/* ----------------------------- Auth Endpoints ----------------------------- */

app.post("/signin", authController.signin);
app.post("/signup", authController.signup);
app.post("/logout", authController.logout);
app.get("/api/me", requireAuthApi, authController.me);
app.post("/refresh", authController.refresh);

/* ----------------------------- Task Endpoints ----------------------------- */

app.get("/api/tasks", taskController.getTasks);
app.post("/api/task", requireAuthApi, taskController.createTask);
app.get("/api/task/:id", taskController.getTaskById);
app.delete("/api/task/:id", requireAuthApi, taskController.deleteTask);

/* ----------------------------- Admin & Log Endpoints ----------------------------- */

app.get("/api/logs", requireAdmin, logController.getLogs);
app.post("/api/admin/action", requireAdmin, adminController.handleAction);

/* ----------------------------- Fallback Endpoint ----------------------------- */

app.use((req, res) => {
  res.status(404);
  
  if (req.accepts('html')) {
    res.sendFile(path.join(PUBLIC_DIR, '404.html'));
  } else {
    res.json({ errorTitle: "Not Found", errorBody: "The requested endpoint does not exist.", errorType: "error" });
  }
});

/* ----------------------------- Start Server ----------------------------- */

async function start() {
  try {
    await Model.connectDB();
    app.listen(process.env.PORT, () => {
      console.log(`Server running on http://127.0.0.1:${process.env.PORT}`);
    });
  } catch (e) {
    console.log(e);
  }
}

start();