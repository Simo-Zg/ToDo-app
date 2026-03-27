const userBadge = document.getElementById("userBadge");
const welcomeUsername = document.getElementById("welcomeUsername");
const welcomeRole = document.getElementById("welcomeRole");
const statusMsg = document.getElementById("statusMsg");
const logoutBtn = document.getElementById("logoutBtn");

function setStatus(message, type = "info") {
  if (!statusMsg) return;
  statusMsg.textContent = message;
  statusMsg.style.color =
    type === "error" ? "#ff9ab0" :
    type === "success" ? "#9ef0d8" :
    "rgba(255,255,255,0.75)";
}

async function loadSession() {
  setStatus("Loading session...");

  try {
    const res = await fetch("/api/me", {
      method: "GET",
      credentials: "include",
    });

    if (!res.ok) {
      window.location.href = "/signin";
      return;
    }

    const data = await res.json();
    const { username, role } = data.user;

    if (userBadge) userBadge.textContent = `${username} • ${role}`;
    if (welcomeUsername) welcomeUsername.textContent = username;
    if (welcomeRole) welcomeRole.textContent = role;
    setStatus("Session loaded.", "success");
  } catch (err) {
    setStatus("Failed to load session.", "error");
  }
}

if (logoutBtn) {
  logoutBtn.addEventListener("click", async () => {
    setStatus("Signing out...");

    try {
      const res = await fetch("/logout", {
        method: "POST",
        credentials: "include",
      });

      const data = await res.json();

      if (!res.ok) {
        setStatus("Logout failed.", "error");
        return;
      }

      window.location.href = data.redirectTo || "/signin";
    } catch (err) {
      setStatus("Network error during logout.", "error");
    }
  });
}

const disconnectBtn = document.getElementById("disconnectBtn");

if (disconnectBtn) {
  disconnectBtn.addEventListener("click", async () => {
    try {
      const res = await fetch("/logout", {
        method: "POST",
        credentials: "include",
      });

      // clear any browser-stored token too, if ever used
      localStorage.removeItem("access_token");
      localStorage.removeItem("refresh_token");
      sessionStorage.removeItem("access_token");
      sessionStorage.removeItem("refresh_token");

      const data = await res.json();

      if (!res.ok) {
        alert("Disconnect failed.");
        return;
      }

      window.location.href = data.redirectTo || "/signin";
    } catch (err) {
      alert("Network error during disconnect.");
    }
  });
}

loadSession();

/* ----------------------------- Task Logic ----------------------------- */

const taskForm = document.getElementById("taskForm");
const titleInput = document.getElementById("title");
const contentInput = document.getElementById("content");
const tasksContainer = document.getElementById("tasks");
const searchInput = document.getElementById("search");
const sortSelect = document.getElementById("sort");
const emptyState = document.getElementById("empty");
const countSpan = document.getElementById("count");

let tasks = [];

async function loadTasks() {
  try {
    const res = await fetch("/api/tasks");
    if (res.ok) {
      tasks = await res.json();
      renderTasks();
    }
  } catch (e) {
    console.error("Failed to load tasks");
  }
}

function renderTasks() {
  let filtered = tasks.filter(t => 
    (t.title && t.title.toLowerCase().includes(searchInput?.value.toLowerCase())) || 
    (t.content && t.content.toLowerCase().includes(searchInput?.value.toLowerCase()))
  );

  const sortVal = sortSelect?.value || "newest";
  if (sortVal === "newest") filtered.sort((a,b) => b.date - a.date);
  else if (sortVal === "oldest") filtered.sort((a,b) => a.date - b.date);
  else if (sortVal === "az") filtered.sort((a,b) => a.title.localeCompare(b.title));
  else if (sortVal === "za") filtered.sort((a,b) => b.title.localeCompare(a.title));

  if (countSpan) countSpan.textContent = filtered.length;

  if (filtered.length === 0) {
    if (tasksContainer) tasksContainer.innerHTML = "";
    if (emptyState) emptyState.hidden = false;
    return;
  }

  if (emptyState) emptyState.hidden = true;
  if (tasksContainer) {
    tasksContainer.innerHTML = filtered.map(t => `
      <article class="card">
        <div class="card__header">
          <h3 class="card__title">${escapeHTML(t.title)}</h3>
          <button class="btn btn--icon btn--danger" onclick="deleteTask('${t.id}')" aria-label="Delete">🗑️</button>
        </div>
        <p class="card__content">${escapeHTML(t.content)}</p>
        <div class="card__footer">
          <span class="card__date">${new Date(t.date).toLocaleDateString()}</span>
          <span class="card__owner">By: ${escapeHTML(t.owner)}</span>
        </div>
      </article>
    `).join("");
  }
}

function escapeHTML(str) {
  if (!str) return "";
  return String(str).replace(/[&<>'"]/g, 
    tag => ({
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      "'": '&#39;',
      '"': '&quot;'
    }[tag] || tag)
  );
}

if (taskForm) {
  taskForm.addEventListener("submit", async (e) => {
    e.preventDefault();
    const title = titleInput.value;
    const content = contentInput.value;

    setStatus("Adding task...", "info");

    try {
      const res = await fetch("/api/task", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ title, content })
      });

      if (!res.ok) {
        if (res.status === 401 || res.status === 403) {
           setStatus("You must be logged in to add tasks.", "error");
        } else {
           setStatus("Failed to add task.", "error");
        }
        return;
      }

      await loadTasks();
      taskForm.reset();
      setStatus("Task added.", "success");
    } catch (err) {
      setStatus("Network error.", "error");
    }
  });
}

window.deleteTask = async function(id) {
  if (!confirm("Are you sure you want to delete this task?")) return;

  try {
    const res = await fetch(`/api/task/${id}`, { method: "DELETE" });
    if (!res.ok) {
       if (res.status === 401 || res.status === 403) {
          alert("You are not authorized to delete this task.");
       } else {
          alert("Failed to delete task.");
       }
       return;
    }
    await loadTasks();
  } catch (err) {
    alert("Network error.");
  }
};

if (searchInput) searchInput.addEventListener("input", renderTasks);
if (sortSelect) sortSelect.addEventListener("change", renderTasks);

const refreshBtn = document.getElementById("refreshBtn");
if (refreshBtn) refreshBtn.addEventListener("click", loadTasks);

const clearBtn = document.getElementById("clearBtn");
if (clearBtn) clearBtn.addEventListener("click", () => taskForm && taskForm.reset());

loadTasks();