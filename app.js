// ── Storage ──────────────────────────────────────────────
const STORAGE_KEY = 'streamhub_data';

function loadData() {
    const raw = localStorage.getItem(STORAGE_KEY);
    return raw ? JSON.parse(raw) : { sites: [], favorites: [], history: [] };
}

function saveData(data) {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(data));
}

let data = loadData();

// ── Render Siti ──────────────────────────────────────────
function renderSites() {
    const list = document.getElementById('siteList');
    const empty = document.getElementById('emptyState');
    
    if (data.sites.length === 0) {
        list.innerHTML = '';
        empty.style.display = 'block';
        return;
    }
    
    empty.style.display = 'none';
    list.innerHTML = data.sites.map((site, index) => `
        <div class="site-card" onclick="openSite('${site.url}', '${site.name}')">
            <div class="site-icon">🎬</div>
            <div class="site-info">
                <div class="site-name">${site.name}</div>
                <div class="site-url">${site.url.replace('https://', '').replace('http://', '').split('/')[0]}</div>
            </div>
            <div class="site-actions" onclick="event.stopPropagation()">
                <button class="btn-sm btn-del" onclick="deleteSite(${index})">✕</button>
            </div>
        </div>
    `).join('');
}

// ── Aggiungi sito ────────────────────────────────────────
function showAddSite() {
    document.getElementById('addModal').style.display = 'flex';
    document.getElementById('siteName').focus();
}

function hideAddSite() {
    document.getElementById('addModal').style.display = 'none';
    document.getElementById('siteName').value = '';
    document.getElementById('siteUrl').value = '';
}

function addSite() {
    const name = document.getElementById('siteName').value.trim();
    let url = document.getElementById('siteUrl').value.trim();
    
    if (!name || !url) return alert('Inserisci nome e URL');
    
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'https://' + url;
    }
    
    data.sites.push({ name, url });
    saveData(data);
    hideAddSite();
    renderSites();
}

function deleteSite(index) {
    if (confirm('Eliminare questo sito?')) {
        data.sites.splice(index, 1);
        saveData(data);
        renderSites();
    }
}

// ── Browser ──────────────────────────────────────────────
let currentSite = null;

function openSite(url, name) {
    currentSite = { url, name };
    
    document.getElementById('browser').style.display = 'flex';
    document.getElementById('browserTitle').textContent = name;
    document.getElementById('browserLoading').style.display = 'block';
    
    // Aggiorna icona preferito
    updateFavIcon();
    
    // Aggiungi alla cronologia
    data.history.unshift({ name, url, time: new Date().toISOString() });
    if (data.history.length > 50) data.history.pop();
    saveData(data);
    
    const frame = document.getElementById('browserFrame');
    frame.src = url;
    
    frame.onload = () => {
        document.getElementById('browserLoading').style.display = 'none';
    };
    
    frame.onerror = () => {
        document.getElementById('browserLoading').style.display = 'none';
        alert('Impossibile caricare il sito. Potrebbe bloccare gli iframe.');
    };
}

function closeBrowser() {
    document.getElementById('browser').style.display = 'none';
    document.getElementById('browserFrame').src = '';
    currentSite = null;
}

function toggleFavorite() {
    if (!currentSite) return;
    
    const idx = data.favorites.findIndex(f => f.url === currentSite.url);
    if (idx >= 0) {
        data.favorites.splice(idx, 1);
    } else {
        data.favorites.push({ name: currentSite.name, url: currentSite.url });
    }
    saveData(data);
    updateFavIcon();
}

function updateFavIcon() {
    const btn = document.getElementById('btnFavorite');
    if (!currentSite) return;
    const isFav = data.favorites.some(f => f.url === currentSite.url);
    btn.textContent = isFav ? '★' : '☆';
}

// ── Tab ──────────────────────────────────────────────────
function showTab(tab) {
    document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
    document.querySelector(`.tab:nth-child(${tab === 'sites' ? 1 : tab === 'favorites' ? 2 : 3})`).classList.add('active');
    
    const main = document.querySelector('.main');
    const sectionTitle = main.querySelector('.section-title');
    const siteList = document.getElementById('siteList');
    const emptyState = document.getElementById('emptyState');
    
    if (tab === 'sites') {
        sectionTitle.textContent = 'I MIEI SITI';
        renderSites();
    } else if (tab === 'favorites') {
        sectionTitle.textContent = 'PREFERITI';
        renderList(data.favorites, 'favorites');
    } else if (tab === 'history') {
        sectionTitle.textContent = 'CRONOLOGIA';
        renderList(data.history, 'history');
    }
}

function renderList(items, type) {
    const list = document.getElementById('siteList');
    const empty = document.getElementById('emptyState');
    
    if (items.length === 0) {
        list.innerHTML = '';
        empty.style.display = 'block';
        empty.querySelector('p:first-child').textContent = type === 'favorites' ? 'Nessun preferito' : 'Nessuna cronologia';
        return;
    }
    
    empty.style.display = 'none';
    list.innerHTML = items.map(item => `
        <div class="list-item" onclick="openSite('${item.url}', '${item.name}')">
            <div class="list-item-thumb">${type === 'favorites' ? '★' : '🕐'}</div>
            <div class="list-item-info">
                <div class="list-item-title">${item.name}</div>
                <div class="list-item-url">${item.url.replace('https://','').split('/')[0]}</div>
            </div>
        </div>
    `).join('');
}

// ── Init ─────────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', () => {
    renderSites();
});

// ── Service Worker ───────────────────────────────────────
if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('sw.js');
}