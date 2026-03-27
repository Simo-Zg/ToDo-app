const path = require("path");
const PUBLIC_DIR = path.join(__dirname, "..", "public");

function renderLanding(req, res) {
  return res.sendFile(path.join(PUBLIC_DIR, "landing.html"));
}

function renderApp(req, res) {
  return res.sendFile(path.join(PUBLIC_DIR, "app.html"));
}

function renderSignin(req, res) {
  return res.sendFile(path.join(PUBLIC_DIR, "signin.html"));
}

function renderSignup(req, res) {
  return res.sendFile(path.join(PUBLIC_DIR, "signup.html"));
}

function renderDashboard(req, res) {
  return res.sendFile(path.join(PUBLIC_DIR, "dashboard.html"));
}

module.exports = {
  renderLanding,
  renderApp,
  renderSignin,
  renderSignup,
  renderDashboard
};
