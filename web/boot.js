/* The export tool copies this file and bridge.js next to index.html. */
(() => {
  'use strict';
  const status = document.getElementById('status');
  const progress = document.getElementById('progress');
  const canvas = document.getElementById('canvas');
  for (const event of ['contextmenu', 'dragstart', 'selectstart']) {
    document.addEventListener(event, e => e.preventDefault());
  }
  document.addEventListener('touchmove', e => e.preventDefault(), {passive: false});
  canvas.addEventListener('wheel', e => e.preventDefault(), {passive: false});
  window.addEventListener('keydown', e => {
    if (['Space', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(e.code)) e.preventDefault();
  });
  const engine = new Engine(window.ASH_ENGINE_CONFIG);
  engine.startGame({
    canvas,
    onProgress: (current, total) => {
      if (total > 0) progress.value = current / total;
      status.textContent = 'Загружаем мастерскую…';
    }
  }).then(() => {
    document.getElementById('loader').hidden = true;
    document.getElementById('loader').style.display = 'none';
    canvas.focus();
  }).catch(error => {
    console.error(error);
    status.textContent = 'Не удалось запустить игру. Обнови страницу или попробуй браузер с поддержкой WebGL 2.';
    progress.hidden = true;
  });
})();
