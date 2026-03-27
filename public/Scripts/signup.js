const form = document.getElementById("signupForm");
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

  const username = document.getElementById("username").value.trim();
  const password = document.getElementById("password").value;
  const confirmPassword = document.getElementById("confirmPassword").value;
  const role = document.getElementById("role").value;
  const secretPassword = document.getElementById("secretPassword").value;

  if (password !== confirmPassword) {
    setStatus("Passwords do not match.", "error");
    return;
  }

  const payload = {
    username,
    password,
    role,
    secretPassword,
  };

  setStatus("Creating account...");

  try {
    const res = await fetch("/signup", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      credentials: "include",
      body: JSON.stringify(payload),
    });

    const data = await res.json();

    if (!res.ok) {
      setStatus(data.errorBody || "Sign up failed.", "error");
      return;
    }

    setStatus("Account created successfully. Redirecting...", "success");
    window.location.href = data.redirectTo || "/";
  } catch (err) {
    setStatus("Network error while signing up.", "error");
  }
});