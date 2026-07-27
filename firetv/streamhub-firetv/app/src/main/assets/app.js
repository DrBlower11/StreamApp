// ── Storage ──────────────────────────────────────────────
const STORAGE_KEY = 'streamhub_data';

function loadData() {
    try {
        const raw = localStorage.getItem(STORAGE_KEY);
        return raw ? JSON.parse(raw) : { sites: [], favorites: [], history: [] };
    } catch (e) {
        return { sites: [], favorites: [], history: [] };
    }
}

function saveData(data) {
    try {
        localStorage.setItem(STORAGE_KEY, JSON.stringify(data));
    } catch (e) {
        alert('Spazio di archiviazione pieno. Libera spazio e riprova.');
    }
}

let data = loadData();
const REMOTE_CHANNELS_URL = 'https://raw.githubusercontent.com/DrBlower11/StreamApp/main/firetv/channels.json';

async function loadRemoteChannels() {
    try {
        const response = await fetch(REMOTE_CHANNELS_URL, { cache: 'no-store' });
        if (!response.ok) return;
        const payload = await response.json();
        const remoteSites = (payload.channels || []).map(item => ({
            name: item.name,
            url: item.url,
            category: item.category || 'Remote'
        }));

        const existingUrls = new Set(data.sites.map(site => site.url));
        const merged = [...data.sites];
        remoteSites.forEach(site => {
            if (!existingUrls.has(site.url)) {
                merged.push(site);
                existingUrls.add(site.url);
            }
        });

        if (merged.length !== data.sites.length) {
            data.sites = merged;
            saveData(data);
            renderSites();
        }
    } catch (e) {
        console.log('Remote channels unavailable', e);
    }
}

// ── Render Siti ──────────────────────────────────────────
function renderSites() {
    const list = document.getElementById('siteList');
    const empty = document.getElementById('emptyState');
    
    if (!list || !empty) return;
    
    if (data.sites.length === 0) {
        list.innerHTML = '';
        empty.style.display = 'block';
        return;
    }
    
    empty.style.display = 'none';
    list.innerHTML = data.sites.map((site, index) => `
        <div class="site-card" onclick="openSite('${escapeHTML(site.url)}', '${escapeHTML(site.name)}')">
            <div class="site-icon">🎬</div>
            <div class="site-info">
                <div class="site-name">${escapeHTML(site.name)}</div>
                <div class="site-url">${escapeHTML(site.url.replace('https://', '').replace('http://', '').split('/')[0])}</div>
            </div>
            <div class="site-actions" onclick="event.stopPropagation()">
                <button class="btn-sm btn-del" onclick="deleteSite(${index})" title="Elimina">✕</button>
            </div>
        </div>
    `).join('');
}

function escapeHTML(str) {
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
}

// ── Aggiungi sito ────────────────────────────────────────
function showAddSite() {
    const modal = document.getElementById('addModal');
    if (modal) {
        modal.style.display = 'flex';
        setTimeout(() => {
            const input = document.getElementById('siteName');
            if (input) input.focus();
        }, 100);
    }
}

function hideAddSite() {
    const modal = document.getElementById('addModal');
    if (modal) modal.style.display = 'none';
    const nameInput = document.getElementById('siteName');
    const urlInput = document.getElementById('siteUrl');
    if (nameInput) nameInput.value = '';
    if (urlInput) urlInput.value = '';
}

function addSite() {
    const nameInput = document.getElementById('siteName');
    const urlInput = document.getElementById('siteUrl');
    if (!nameInput || !urlInput) return;
    
    const name = nameInput.value.trim();
    let url = urlInput.value.trim();
    
    if (!name) return alert('Inserisci il nome del sito');
    if (!url) return alert('Inserisci l\'URL del sito');
    
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'https://' + url;
    }
    
    if (data.sites.some(s => s.url === url)) {
        return alert('Questo URL è già stato aggiunto');
    }
    
    data.sites.push({ name, url });
    saveData(data);
    hideAddSite();
    renderSites();
}

function deleteSite(index) {
    const site = data.sites[index];
    if (!site) return;
    if (confirm('Eliminare "' + site.name + '"?')) {
        data.sites.splice(index, 1);
        saveData(data);
        renderSites();
    }
}

// ── Apri sito ───────────────────────────────────────────
let currentSite = null;

function openSite(url, name) {
    currentSite = { url, name };
    
    data.history.unshift({ 
        name: name, 
        url: url, 
        time: new Date().toLocaleString('it-IT') 
    });
    if (data.history.length > 100) data.history.length = 100;
    saveData(data);

    const browser = document.getElementById('browser');
    const frame = document.getElementById('browserFrame');
    const title = document.getElementById('browserTitle');
    if (browser && frame && title) {
        title.textContent = name;
        frame.src = url;
        browser.style.display = 'flex';
        document.getElementById('browserLoading').style.display = 'block';
        setTimeout(() => {
            const loading = document.getElementById('browserLoading');
            if (loading) loading.style.display = 'none';
        }, 900);
    } else {
        window.location.href = url;
    }
}

// ── Tab ──────────────────────────────────────────────────
function showTab(tab) {
    document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
    const activeTab = document.getElementById('tab' + tab.charAt(0).toUpperCase() + tab.slice(1));
    if (activeTab) activeTab.classList.add('active');
    
    const sectionTitle = document.getElementById('sectionTitle');
    if (!sectionTitle) return;
    
    switch (tab) {
        case 'sites':
            sectionTitle.textContent = 'I MIEI SITI';
            renderSites();
            break;
        case 'favorites':
            sectionTitle.textContent = 'PREFERITI';
            renderFavoritesOrHistory('favorites');
            break;
        case 'history':
            sectionTitle.textContent = 'CRONOLOGIA';
            renderFavoritesOrHistory('history');
            break;
    }
}

function renderFavoritesOrHistory(type) {
    const siteList = document.getElementById('siteList');
    const emptyState = document.getElementById('emptyState');
    const items = type === 'favorites' ? data.favorites : data.history;
    
    if (!siteList || !emptyState) return;
    
    if (items.length === 0) {
        siteList.innerHTML = '';
        emptyState.style.display = 'block';
        const p = emptyState.querySelector('p:first-child');
        if (p) p.textContent = type === 'favorites' ? 'Nessun preferito' : 'Nessuna cronologia';
        return;
    }
    
    emptyState.style.display = 'none';
    
    if (type === 'favorites') {
        siteList.innerHTML = items.map((item, index) => `
            <div class="list-item" onclick="openSite('${escapeHTML(item.url)}', '${escapeHTML(item.name)}')">
                <div class="list-item-thumb">★</div>
                <div class="list-item-info">
                    <div class="list-item-title">${escapeHTML(item.name)}</div>
                    <div class="list-item-url">${escapeHTML(item.url.replace('https://','').split('/')[0])}</div>
                </div>
                <button class="btn-sm btn-del" onclick="event.stopPropagation(); removeFavorite(${index})" title="Rimuovi">✕</button>
            </div>
        `).join('');
    } else {
        siteList.innerHTML = items.map(item => `
            <div class="list-item" onclick="openSite('${escapeHTML(item.url)}', '${escapeHTML(item.name)}')">
                <div class="list-item-thumb">🕐</div>
                <div class="list-item-info">
                    <div class="list-item-title">${escapeHTML(item.name)}</div>
                    <div class="list-item-url">${escapeHTML(item.time || '')} — ${escapeHTML(item.url.replace('https://','').split('/')[0])}</div>
                </div>
            </div>
        `).join('');
    }
}

// ── Preferiti ────────────────────────────────────────────
function toggleFavorite() {
    if (!currentSite) return;
    const idx = data.favorites.findIndex(f => f.url === currentSite.url);
    if (idx >= 0) {
        data.favorites.splice(idx, 1);
    } else {
        data.favorites.unshift({ name: currentSite.name, url: currentSite.url });
    }
    saveData(data);
    updateFavIcon();
}

function updateFavIcon() {
    const btn = document.getElementById('btnFavorite');
    if (!btn || !currentSite) return;
    btn.textContent = data.favorites.some(f => f.url === currentSite.url) ? '★' : '☆';
}

function removeFavorite(index) {
    if (confirm('Rimuovere dai preferiti?')) {
        data.favorites.splice(index, 1);
        saveData(data);
        renderFavoritesOrHistory('favorites');
    }
}

function closeBrowser() {
    const browser = document.getElementById('browser');
    const frame = document.getElementById('browserFrame');
    if (browser) browser.style.display = 'none';
    if (frame) frame.src = 'about:blank';
}

// ── Tasti ────────────────────────────────────────────────
document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
        const modal = document.getElementById('addModal');
        const browser = document.getElementById('browser');
        if (modal && modal.style.display === 'flex') {
            hideAddSite();
        } else if (browser && browser.style.display === 'flex') {
            closeBrowser();
        }
    }
    if (e.ctrlKey && e.key === 'n') {
        e.preventDefault();
        showAddSite();
    }
});

// ── Init ─────────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', function() {
    renderSites();
    loadRemoteChannels();
    window.addEventListener('popstate', function() {
        hideAddSite();
    });
});

// ── Service Worker ───────────────────────────────────────
if ('serviceWorker' in navigator) {
    window.addEventListener('load', function() {
        navigator.serviceWorker.register('sw.js').catch(function(err) {
            console.log('SW non registrato:', err);
        });
    });
}