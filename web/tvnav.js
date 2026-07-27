(function () {
  let activeIndex = 0;
  const focusables = () => Array.from(document.querySelectorAll('.site-card, .tab, .btn, .btn-icon, .btn-back, .btn-fav'));

  function updateFocus() {
    const items = focusables();
    items.forEach((el, idx) => {
      el.classList.toggle('tv-focus', idx === activeIndex);
    });
  }

  function move(delta) {
    const items = focusables();
    if (!items.length) return;
    activeIndex = (activeIndex + delta + items.length) % items.length;
    items[activeIndex].focus?.();
    updateFocus();
  }

  document.addEventListener('keydown', (e) => {
    if (e.key === 'ArrowRight') { e.preventDefault(); move(1); }
    if (e.key === 'ArrowLeft') { e.preventDefault(); move(-1); }
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      const items = focusables();
      if (items[activeIndex]) items[activeIndex].click();
    }
    if (e.key === 'Backspace' || e.key === 'Escape') {
      const browser = document.getElementById('browser');
      if (browser && browser.style.display === 'flex') {
        e.preventDefault();
        closeBrowser();
      }
    }
  });

  document.addEventListener('DOMContentLoaded', updateFocus);
})();
