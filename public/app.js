const els = {
  form: document.getElementById('taskForm'),
  title: document.getElementById('title'),
  content: document.getElementById('content'),
  tasks: document.getElementById('tasks'),
  empty: document.getElementById('empty'),
  status: document.getElementById('statusMsg'),
  count: document.getElementById('count'),
  refreshBtn: document.getElementById('refreshBtn'),
  clearBtn: document.getElementById('clearBtn'),
  search: document.getElementById('search'),
  sort: document.getElementById('sort'),
};

let allTasks = [];

function formatDate(ms) {
  const d = new Date(ms);
  return d.toLocaleString(undefined, {
    year: 'numeric', month: 'short', day: '2-digit',
    hour: '2-digit', minute: '2-digit'
  });
}

function setStatus(msg, kind = 'info') {
  const prefix = kind === 'ok' ? '✅ ' : kind === 'error' ? '⚠️ ' : '';
  els.status.textContent = msg ? `${prefix}${msg}` : '';
}

function escapeHtml(str) {
  return String(str)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}

function getFilteredSortedTasks() {
  const q = (els.search.value || '').trim().toLowerCase();
  let tasks = allTasks;

  if (q) {
    tasks = tasks.filter(t =>
      String(t.title || '').toLowerCase().includes(q) ||
      String(t.content || '').toLowerCase().includes(q)
    );
  }

  const s = els.sort.value;
  tasks = [...tasks];
  if (s === 'newest') tasks.sort((a, b) => (b.date || 0) - (a.date || 0));
  if (s === 'oldest') tasks.sort((a, b) => (a.date || 0) - (b.date || 0));
  if (s === 'az') tasks.sort((a, b) => String(a.title || '').localeCompare(String(b.title || '')));
  if (s === 'za') tasks.sort((a, b) => String(b.title || '').localeCompare(String(a.title || '')));

  return tasks;
}

function render() {
  const tasks = getFilteredSortedTasks();
  els.count.textContent = String(tasks.length);

  els.tasks.innerHTML = tasks.map(t => {
    const title = escapeHtml(t.title);
    const content = escapeHtml(t.content);
    const date = typeof t.date === 'number' ? formatDate(t.date) : '—';

    return `
      <article class="card" data-id="${t.id}">
        <div class="card__top">
          <div>
            <h3 class="card__title">${title}</h3>
            <div class="card__meta">Created ${date}</div>
          </div>
          <div class="badge" title="Task ID">${escapeHtml(t.id)}</div>
        </div>

        <p class="card__content">${content}</p>

        <div class="card__actions">
          <button class="btn btn--danger" data-action="delete" type="button">Delete</button>
        </div>
      </article>
    `;
  }).join('');

  els.empty.hidden = tasks.length > 0;
}

async function loadTasks() {
  els.search.value = '';
  setStatus('Loading tasks...');
  try {
    const res = await fetch('/api/tasks');
    const data = await res.json();
    if (!res.ok) throw new Error(data?.error || `HTTP ${res.status}`);

    allTasks = Array.isArray(data) ? data : [];
    setStatus('');
    render();
  } catch (err) {
    setStatus(err.message || 'Failed to load tasks', 'error');
  }
}

async function addTask(title, content) {
  setStatus('Creating task...');
  try {
    const res = await fetch('/api/task', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ title, content })
    });

    const data = await res.json();
    if (!res.ok) throw new Error(data?.error || `HTTP ${res.status}`);

    allTasks.push(data);
    els.title.value = '';
    els.content.value = '';
    setStatus('Task added', 'ok');
    render();
  } catch (err) {
    setStatus(err.message || 'Failed to create task', 'error');
  }
}

async function deleteTask(id) {
  setStatus('Deleting task...');
  try {
    const res = await fetch(`/api/task/${encodeURIComponent(id)}`, { method: 'DELETE' });
    const data = await res.json();
    if (!res.ok) throw new Error(data?.error || `HTTP ${res.status}`);

    allTasks = allTasks.filter(t => t.id !== id);
    setStatus('Task deleted', 'ok');
    render();
  } catch (err) {
    setStatus(err.message || 'Failed to delete task', 'error');
  }
}

els.form.addEventListener('submit', (e) => {
  e.preventDefault();
  const title = els.title.value.trim();
  const content = els.content.value.trim();

  if (!title || !content) {
    setStatus('Title and content are required', 'error');
    return;
  }
  addTask(title, content);
});

els.clearBtn.addEventListener('click', () => {
  els.title.value = '';
  els.content.value = '';
  setStatus('Cleared');
});

els.refreshBtn.addEventListener('click', loadTasks);
els.search.addEventListener('input', render);
els.sort.addEventListener('change', render);

els.tasks.addEventListener('click', (e) => {
  const btn = e.target.closest('button[data-action]');
  if (!btn) return;

  const card = e.target.closest('.card');
  if (!card) return;

  const id = card.getAttribute('data-id');
  if (!id) return;

  if (btn.dataset.action === 'delete') deleteTask(id);
});

loadTasks();
