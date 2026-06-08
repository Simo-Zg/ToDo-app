const form = document.getElementById("signinForm");
const roleSelect = document.getElementById("role");
const secretField = document.getElementById("secretField");
const secretPasswordInput = document.getElementById("secretPassword");
const statusMsg = document.getElementById("statusMsg");

function setStatus(message, type = "info") {
  statusMsg.textContent = message;
  statusMsg.style.color =
    type === "error" ? "#ff9ab0" :
    type === "success" ? "#9ef0d8" :
    "rgba(255,255,255,0.75)";
}

function syncSecretField() {
  const isAdmin = roleSelect.value === "Admin";
  secretField.classList.toggle("hidden", !isAdmin);
  secretPasswordInput.required = isAdmin;

  if (!isAdmin) {
    secretPasswordInput.value = "";
  }
}

roleSelect.addEventListener("change", syncSecretField);
syncSecretField();

form.addEventListener("submit", async (e) => {
  e.preventDefault();

  const payload = {
    username: document.getElementById("username").value.trim(),
    password: document.getElementById("password").value,
    role: document.getElementById("role").value,
    secretPassword: document.getElementById("secretPassword").value,
  };

  setStatus("Signing in...");

  try {
    const res = await fetch("/signin", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      credentials: "include",
      body: JSON.stringify(payload),
    });

    const data = await res.json();

    if (!res.ok) {
      setStatus(data.errorBody || "Sign in failed.", "error");
      return;
    }

    setStatus("Signed in successfully. Redirecting...", "success");
    window.location.href = data.redirectTo || "/";
  } catch (err) {
    setStatus("Network error while signing in.", "error");
  }
});