const {test} = require('node:test');
const assert = require('node:assert/strict');
const {createBridge} = require('../web/bridge.js');

function fixture() {
  const handlers = {}, sdkHandlers = {}, records = [], timers = new Map(), storage = new Map();
  let adCallbacks, resolveInit, nextTimer = 1;
  const sdk = {
    features: {
      LoadingAPI: {ready: () => records.push('ready')},
      GameplayAPI: {start: () => records.push('start'), stop: () => records.push('stop')}
    },
    on: (type, fn) => { sdkHandlers[type] = fn; },
    adv: {showFullscreenAdv: ({callbacks}) => { adCallbacks = callbacks; }}
  };
  const win = {
    document: {hidden: false, addEventListener: (type, fn) => { handlers[type] = fn; }},
    addEventListener: (type, fn) => { handlers[type] = fn; },
    console: {warn() {}},
    setTimeout: fn => { const id = nextTimer++; timers.set(id, fn); return id; },
    clearTimeout: id => timers.delete(id),
    localStorage: {getItem: k => storage.get(k), setItem: (k, v) => storage.set(k, v)},
    YaGames: {init: () => new Promise(resolve => { resolveInit = resolve; })}
  };
  const bridge = createBridge(win);
  const ready = async () => {
    const pending = bridge.init();
    await Promise.resolve();
    resolveInit(sdk);
    await pending;
  };
  return {bridge, win, ready, records, handlers, sdkHandlers, timers, ad: () => adCallbacks,
    state: () => JSON.parse(bridge.poll())};
}

test('readiness queues until SDK init and is reported exactly once', async () => {
  const f = fixture();
  f.bridge.ready(); f.bridge.ready(); f.bridge.playing(true);
  assert.deepEqual(f.records, []);
  await f.ready();
  assert.deepEqual(f.records, ['ready', 'start']);
  f.bridge.ready(); f.bridge.playing(true);
  assert.deepEqual(f.records, ['ready', 'start']);
});

test('hidden/blur pauses and never automatically resumes gameplay', async () => {
  const f = fixture(); await f.ready(); f.bridge.playing(true);
  f.win.document.hidden = true; f.handlers.visibilitychange();
  assert.equal(f.state().blocked, true);
  assert.deepEqual(f.records, ['start', 'stop']);
  f.win.document.hidden = false; f.handlers.visibilitychange(); f.handlers.focus();
  assert.deepEqual(f.records, ['start', 'stop']);
  f.bridge.playing(true);
  assert.equal(f.records.at(-1), 'start');
  f.handlers.blur();
  assert.equal(f.records.at(-1), 'stop');
});

test('SDK pause remains stopped until the user explicitly resumes', async () => {
  const f = fixture(); await f.ready(); f.bridge.playing(true);
  f.sdkHandlers.game_api_pause();
  f.sdkHandlers.game_api_resume();
  assert.deepEqual(f.records, ['start', 'stop']);
  f.bridge.playing(true);
  assert.equal(f.records.at(-1), 'start');
});

test('interstitial blocks gameplay, deduplicates requests and completes once', async () => {
  const f = fixture(); await f.ready(); f.bridge.playing(true); f.state();
  assert.equal(f.bridge.interstitial(), true);
  assert.equal(f.bridge.interstitial(), false);
  assert.equal(f.state().blocked, true);
  f.ad().onOpen();
  assert.equal(f.timers.size, 0);
  f.bridge.playing(true);
  assert.equal(f.records.at(-1), 'stop');
  f.ad().onClose(true); f.ad().onError(new Error('late duplicate'));
  const events = f.state().events.filter(x => x.type === 'ad_closed');
  assert.equal(events.length, 1);
  assert.equal(events[0].shown, true);
  assert.equal(f.records.at(-1), 'stop');
});

test('ad errors return control without pretending an ad was shown', async () => {
  const f = fixture(); await f.ready(); f.state(); f.bridge.interstitial(); f.ad().onError();
  assert.deepEqual(f.state().events, [{type: 'ad_closed', shown: false}]);
});

test('an unexpectedly late ad still blocks and pauses gameplay', async () => {
  const f = fixture(); await f.ready(); f.bridge.interstitial();
  [...f.timers.values()][0]();
  f.state(); f.bridge.playing(true);
  f.ad().onOpen();
  assert.equal(f.state().blocked, true);
  assert.equal(f.records.at(-1), 'stop');
  f.ad().onClose(true);
  assert.equal(f.state().blocked, false);
});

test('offline play does not simulate advertising', () => {
  const f = fixture(); f.bridge.offline(); f.state(); f.bridge.interstitial();
  assert.deepEqual(f.state().events, [{type: 'ad_closed', shown: false}]);
});

test('saves round-trip Unicode and failure is observable', () => {
  const f = fixture();
  const value = JSON.stringify({version: 1, title: 'Пепельные нити', collected: [0, 2]});
  assert.equal(f.bridge.writeSave(value), true);
  assert.equal(f.bridge.readSave(), value);
  assert.equal(f.bridge.writeSave('broken json'), false);
  assert.equal(f.bridge.readSave(), value);
  f.win.localStorage.setItem = () => { throw new Error('storage disabled'); };
  assert.equal(f.bridge.writeSave(value), false);
  assert.equal(f.state().events.filter(x => x.type === 'save_failed').length, 2);
});

test('init failure is handled and memoized', async () => {
  const f = fixture(); let count = 0;
  f.win.YaGames.init = async () => { count++; throw new Error('offline'); };
  assert.equal(await f.bridge.init(), false);
  assert.equal(await f.bridge.init(), false);
  assert.equal(count, 1);
  assert.equal(f.state().sdkState, 'offline');
});
