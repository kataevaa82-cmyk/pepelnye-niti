/* Small, testable SDK boundary; no private tokens or external game services. */
(function (root) {
  'use strict';
  const KEY = 'pepelnye-niti-v1';
  function createBridge(win) {
    let sdk = null, loadingReady = false, readySent = false;
    let desiredPlaying = false, reportedPlaying = false;
    let hidden = Boolean(win.document.hidden), sdkPaused = false, adOpen = false;
    let sdkState = 'loading', initPromise = null, adPending = false;
    let events = [];
    const emit = (type, extra = {}) => events.push({type, ...extra});
    function sync() {
      if (!sdk) return;
      if (loadingReady && !readySent) {
        try { sdk.features.LoadingAPI.ready(); readySent = true; }
        catch (error) { win.console.warn('LoadingAPI', error); }
      }
      const active = desiredPlaying && !hidden && !sdkPaused && !adOpen && !adPending;
      if (active === reportedPlaying) return;
      try {
        if (active) sdk.features.GameplayAPI.start();
        else sdk.features.GameplayAPI.stop();
        reportedPlaying = active;
      } catch (error) { win.console.warn('GameplayAPI', error); }
    }
    function pause(reason) {
      desiredPlaying = false;
      emit('pause', {reason});
      sync();
    }
    function init() {
      if (initPromise) return initPromise;
      initPromise = Promise.resolve().then(() => win.YaGames.init()).then(value => {
        sdk = value;
        sdkState = 'ready';
        if (sdk.on) {
          sdk.on('game_api_pause', () => { sdkPaused = true; pause('sdk'); });
          sdk.on('game_api_resume', () => { sdkPaused = false; sync(); });
        }
        sync();
        emit('sdk_ready');
        return true;
      }).catch(error => {
        sdkState = 'offline';
        win.console.warn('Yandex SDK unavailable; local mode.', error);
        emit('sdk_offline');
        return false;
      });
      return initPromise;
    }
    win.document.addEventListener('visibilitychange', () => {
      hidden = Boolean(win.document.hidden);
      if (hidden) pause('hidden');
      else sync();
    });
    win.addEventListener('blur', () => { hidden = true; pause('blur'); });
    win.addEventListener('focus', () => { hidden = Boolean(win.document.hidden); sync(); });
    function interstitial() {
      if (adPending || adOpen) return false;
      desiredPlaying = false;
      sync();
      if (!sdk || !sdk.adv) { emit('ad_closed', {shown: false}); return true; }
      adPending = true;
      let done = false, opened = false;
      const finish = shown => {
        if (done) { adOpen = false; sync(); return; }
        done = true;
        win.clearTimeout(timeout);
        adPending = false;
        adOpen = false;
        emit('ad_closed', {shown: Boolean(shown)});
        sync();
      };
      // Only timeout before an ad opens. Never resume underneath a playing ad.
      const timeout = win.setTimeout(() => { if (!opened) finish(false); }, 15000);
      try {
        sdk.adv.showFullscreenAdv({callbacks: {
          onOpen: () => {
            opened = true; adOpen = true;
            win.clearTimeout(timeout);
            pause('ad');
          },
          onClose: shown => finish(shown),
          onError: () => finish(false)
        }});
      } catch (_) { finish(false); }
      return true;
    }
    return {
      init,
      offline: () => { sdkState = 'offline'; emit('sdk_offline'); },
      ready: () => { loadingReady = true; sync(); },
      playing: value => {
        desiredPlaying = Boolean(value) && !hidden && !sdkPaused && !adOpen && !adPending;
        sync();
      },
      interstitial,
      poll: () => {
        const result = JSON.stringify({events, blocked: hidden || sdkPaused || adOpen || adPending, sdkState});
        events = [];
        return result;
      },
      readSave: () => {
        try { return win.localStorage.getItem(KEY) || ''; }
        catch (_) { return ''; }
      },
      writeSave: value => {
        try { JSON.parse(value); win.localStorage.setItem(KEY, value); return true; }
        catch (_) { emit('save_failed'); return false; }
      }
    };
  }
  if (typeof module !== 'undefined' && module.exports) module.exports = {createBridge};
  if (root && root.document) {
    root.AshPlatform = createBridge(root);
    const script = root.document.createElement('script');
    script.src = '/sdk.js';
    script.async = true;
    script.onload = () => root.AshPlatform.init();
    script.onerror = () => root.AshPlatform.offline();
    root.document.head.appendChild(script);
  }
})(typeof window !== 'undefined' ? window : null);
