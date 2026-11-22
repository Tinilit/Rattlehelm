import assert from 'node:assert/strict';
import { mkdir, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { chromium } from 'playwright';

const [address, build, output = 'build/browser-smoke'] = process.argv.slice(2);
if (!address || !build) {
  throw new Error('Usage: node ci/browser_smoke.mjs <URL> <build SHA> [output directory]');
}

const url = new URL(address);
url.searchParams.set('smoke', '1');
url.searchParams.set('build', build);
const width = Number(process.env.PLAYTEST_WIDTH || 1280);
const height = Math.round(width * 9 / 16);
const record = process.env.RECORD_PLAYTEST === '1';
const quick = !record && process.env.RATTLEHELM_QUICK_SMOKE === '1';
const reducedEffects = process.env.REDUCED_EFFECTS === '1';
const messages = [];
const critical = [];
const assets = new Map();
await mkdir(output, { recursive: true });

const browser = await chromium.launch({
  executablePath: process.env.CHROMIUM_BIN || undefined,
  args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'],
});
const page = await browser.newPage({ viewport: { width, height } });
page.setDefaultTimeout(15_000);
await page.addInitScript((recordVideo) => {
  const NativeContext = window.AudioContext;
  const audio = { contexts: [], samples: [] };
  window.rattlehelmSmokeAudio = audio;
  if (!NativeContext) return;
  window.AudioContext = class extends NativeContext {
    constructor(...options) {
      super(...options);
      audio.contexts.push(this);
      if (recordVideo) this.playtestCapture = this.createMediaStreamDestination();
    }
  };
  if (recordVideo) {
    const connect = AudioNode.prototype.connect;
    AudioNode.prototype.connect = function (destination, ...ports) {
      const capture = this.context.playtestCapture;
      if (capture && destination === this.context.destination) connect.call(this, capture, ...ports);
      return connect.call(this, destination, ...ports);
    };
  }
  const startSource = AudioBufferSourceNode.prototype.start;
  AudioBufferSourceNode.prototype.start = function (...options) {
    const result = startSource.apply(this, options);
    const channel = this.buffer?.getChannelData(0);
    if (channel?.some((value) => Math.abs(value) > 0.02)) {
      audio.samples.push({ length: this.buffer.duration, running: this.context.state === 'running' });
    }
    return result;
  };
}, record);

page.on('console', (message) => {
  messages.push(`${message.type()} ${message.text()}`);
  if (message.type() === 'error') critical.push(message.text());
});
page.on('pageerror', (error) => critical.push(error.message));
page.on('requestfailed', (request) => critical.push(`${request.url()} ${request.failure()?.errorText}`));
page.on('response', (response) => {
  const path = new URL(response.url()).pathname;
  if (response.status() >= 400) critical.push(`HTTP ${response.status()} ${path}`);
  const file = path.split('/').at(-1);
  if (['index.js', 'index.wasm', 'index.pck'].includes(file)) {
    assets.set(file, { status: response.status(), contentType: response.headers()['content-type'] });
  }
});

function waitFor(field, op, value, timeout = 15_000) {
  return page.waitForFunction(({ field, op, value }) => {
    const encoded = document.documentElement.dataset.rattlehelm;
    if (!encoded) return false;
    const actual = JSON.parse(encoded)[field];
    if (op === 'eq') return actual === value;
    return op === 'lte' ? actual <= value : actual >= value;
  }, { field, op, value }, { timeout });
}

const snapshot = () => page.evaluate(() => JSON.parse(document.documentElement.dataset.rattlehelm));

const withKeys = async (keys, callback) => {
  for (const key of keys) await page.keyboard.down(key);
  try {
    await callback();
  } finally {
    for (const key of keys.toReversed()) await page.keyboard.up(key);
  }
};
const moveUntil = (keys, field, value, op = 'gte') =>
  withKeys(keys, () => waitFor(field, op, value, 8_000));
const waitForLane = (tolerance) => page.waitForFunction((distance) => {
  const state = JSON.parse(document.documentElement.dataset.rattlehelm);
  return Math.abs(state.heroY - state.enemyY) <= distance;
}, tolerance);

async function counterattack(direction) {
  const before = await snapshot();
  if (Math.abs(before.heroY - before.enemyY) > 12) {
    const step = before.heroY > before.enemyY ? 'w' : 's';
    await withKeys([step], () => waitForLane(9));
  }
  const key = direction > 0 ? 'd' : 'a';
  await withKeys([key], async () => {
    await page.waitForFunction((direction) => {
      const state = JSON.parse(document.documentElement.dataset.rattlehelm);
      const reach = (state.enemyX - state.heroX) * direction;
      return state.phase === 0 && reach > 0 && reach <= 62 &&
        Math.abs(state.heroY - state.enemyY) <= 17;
    }, direction);
    await page.keyboard.press('j', { delay: 20 });
  });
  await waitFor('hits', 'gte', before.hits + 1);
  const hit = await snapshot();
  assert.equal(hit.attackFacing, direction);
  return hit;
}

async function rollAndCounter(direction, name) {
  const before = await snapshot();
  const towardLane = before.heroY < before.enemyY ? 's' : 'w';
  await withKeys([direction > 0 ? 'd' : 'a', towardLane], () => page.keyboard.press('k'));
  await waitFor('phase', 'eq', 4);
  await waitFor('phase', 'eq', 0);
  const rolled = await snapshot();
  assert.ok((rolled.heroX - rolled.enemyX) * direction > 15, 'Roll did not cross the gatekeeper');
  const hit = await counterattack(-direction);
  await page.screenshot({ path: join(output, `counter-${name}.png`) });
  return hit;
}

async function startRecording() {
  await page.waitForFunction(() => window.rattlehelmSmokeAudio.contexts[0]?.playtestCapture);
  await page.evaluate(() => {
    const canvas = document.querySelector('canvas');
    const stream = canvas.captureStream(60);
    const audio = window.rattlehelmSmokeAudio.contexts[0].playtestCapture.stream;
    for (const track of audio.getAudioTracks()) stream.addTrack(track);
    const recorder = new MediaRecorder(stream, {
      mimeType: 'video/webm;codecs=vp9,opus',
      videoBitsPerSecond: 3_000_000,
    });
    const chunks = [];
    recorder.addEventListener('dataavailable', ({ data }) => chunks.push(data));
    window.stopRattlehelmRecording = () => new Promise((resolve) => {
      recorder.addEventListener('stop', () => {
        const reader = new FileReader();
        reader.onload = () => resolve(reader.result.slice(reader.result.indexOf(';base64,') + 8));
        reader.readAsDataURL(new Blob(chunks, { type: recorder.mimeType }));
      }, { once: true });
      recorder.stop();
    });
    recorder.start();
  });
}

async function runSmoke() {
  const response = await page.goto(url.href, { waitUntil: 'domcontentloaded', timeout: 60_000 });
  assert.ok(response.ok(), `Could not load ${url}`);
  await waitFor('screen', 'eq', 'title', 60_000);
  await waitFor('build', 'eq', build, 12_000);
  assert.match(messages.join('\n'), /WebGL 2\.0/);
  assert.match(messages.join('\n'), /single-threaded/);
  for (const file of ['index.js', 'index.wasm', 'index.pck']) {
    assert.ok([200, 304].includes(assets.get(file)?.status), `${file} failed to load`);
  }
  assert.match(assets.get('index.wasm').contentType, /application\/wasm/);
  await page.screenshot({ path: join(output, 'title.png') });

  async function clickCanvas(x, y) {
    await canvas.click({ position: { x: width * x / 1280, y: height * y / 720 } });
  }
  // Click Play on the rendered canvas, then use ordinary browser keyboard events.
  const canvas = page.locator('canvas');
  if (reducedEffects) {
    await clickCanvas(164, 493);
    await waitFor('screen', 'eq', 'settings');
    for (const y of [393, 441, 537]) await clickCanvas(870, y);
    await clickCanvas(464, 604);
    await waitFor('screen', 'eq', 'title');
  }
  if (record) await startRecording();
  await clickCanvas(202, 426);
  await waitFor('room', 'eq', 'training_yard');
  assert.equal(await canvas.evaluate((element) => document.activeElement === element), true);
  const entry = await snapshot();
  if (reducedEffects) {
    assert.deepEqual([entry.healthNumbers, entry.shake, entry.particles], [false, false, false]);
  }
  await moveUntil(['s'], 'heroY', 575);
  await moveUntil(['d'], 'heroX', 403);
  await page.keyboard.press('j');
  await waitFor('hits', 'gte', 1);
  const hit = await snapshot();
  assert.ok(hit.heroX > entry.heroX && hit.heroY > entry.heroY, 'Input did not move on both floor axes');
  assert.ok(hit.heroX < 440, `The slash must reach straw from outside the old grounded reach (heroX=${hit.heroX})`);
  assert.equal(hit.action, 'slash_1');
  assert.equal(hit.attackFacing, 1);
  assert.equal(hit.impactMaterial, 1);
  assert.equal(hit.impactTick - hit.attackTick, 5);
  await page.waitForFunction(() => {
    const audio = window.rattlehelmSmokeAudio;
    return audio.contexts.some((context) => context.state === 'running') &&
      audio.samples.some(({ running, length }) => running && Math.abs(length - 0.25) < 0.025) &&
      audio.samples.some(({ running, length }) => running && Math.abs(length - 0.42) < 0.025);
  });
  await page.screenshot({ path: join(output, 'training-hit.png') });

  await moveUntil(['w'], 'heroY', 511, 'lte');
  await moveUntil(['d'], 'heroX', 707);
  await page.keyboard.press('j');
  await waitFor('hits', 'gte', 2);
  assert.equal((await snapshot()).impactMaterial, 2);
  await page.waitForFunction(() => window.rattlehelmSmokeAudio.samples.some(({ running, length }) =>
    running && Math.abs(length - 0.66) < 0.025));
  await moveUntil(['s'], 'heroY', 539);
  await moveUntil(['d'], 'heroX', 1073);
  await waitFor('exitReady', 'eq', true);
  await page.keyboard.press('e');
  await waitFor('room', 'eq', 'watch_gate');
  if (quick) {
    assert.deepEqual(critical, []);
    console.log(`PASS ${build}: Chromium WebGL 2, WebAudio, keyboard combat and room transition`);
    return;
  }
  await page.evaluate(() => {
    const times = [];
    let previous;
    window.rattlehelmFrameTimes = times;
    function sample(timestamp) {
      const state = JSON.parse(document.documentElement.dataset.rattlehelm);
      if (state.screen === 'summary') return;
      if (state.screen === 'battle') {
        if (previous !== undefined) times.push(timestamp - previous);
        previous = timestamp;
      } else {
        previous = undefined;
      }
      requestAnimationFrame(sample);
    }
    requestAnimationFrame(sample);
  });
  await page.keyboard.down('d');
  try {
    await waitFor('enemyAction', 'eq', 'club_sweep');
  } finally {
    await page.keyboard.up('d');
  }
  const windup = await snapshot();
  await moveUntil(['w'], 'heroY', windup.heroY - 43, 'lte');
  await waitFor('enemyMisses', 'gte', 1);
  const miss = await snapshot();
  assert.ok(miss.missDepth >= 24, `Guard missed at unexpected depth: ${miss.missDepth}`);
  assert.equal(miss.heroHp, 100);
  await page.keyboard.press('Escape');
  await waitFor('screen', 'eq', 'pause');
  const paused = await snapshot();
  await page.screenshot({ path: join(output, 'pause.png') });
  assert.equal(paused.build, build);
  assert.equal((await snapshot()).tick, paused.tick);
  await page.keyboard.press('Escape');
  await waitFor('screen', 'eq', 'battle');
  await waitFor('tick', 'gte', paused.tick + 1);

  const westCounter = await rollAndCounter(1, 'from-east');
  assert.equal(westCounter.enemyHp, 32);
  await page.waitForFunction(() => {
    const state = JSON.parse(document.documentElement.dataset.rattlehelm);
    return state.phase === 0 && state.enemyPhase === 1 &&
      state.enemyFacing === 1 && state.enemyActionTick <= 7;
  });
  const secondWindup = await snapshot();
  await moveUntil(['s'], 'heroY', secondWindup.heroY + 43);
  await waitFor('enemyMisses', 'gte', secondWindup.enemyMisses + 1);
  const secondMiss = await snapshot();
  assert.equal(secondMiss.missFacing, 1);
  assert.ok(secondMiss.missDepth >= 24);
  assert.equal(secondMiss.heroHp, secondWindup.heroHp);
  const eastCounter = await rollAndCounter(-1, 'from-west');
  assert.equal(eastCounter.enemyHp, 20);

  while (!(await snapshot()).cleared) {
    await waitFor('phase', 'eq', 0);
    await counterattack(1);
  }
  await moveUntil(['d'], 'heroX', 1075);
  const exit = await snapshot();
  if (exit.heroY > 552) await moveUntil(['w'], 'heroY', 552, 'lte');
  await waitFor('exitReady', 'eq', true);
  await page.keyboard.press('e');
  await waitFor('screen', 'eq', 'summary');
  assert.equal((await snapshot()).won, true);
  await page.screenshot({ path: join(output, 'victory.png') });

  if (record) {
    await page.waitForTimeout(700);
    const encoded = await page.evaluate(() => window.stopRattlehelmRecording());
    const video = Buffer.from(encoded, 'base64');
    assert.ok(video.length > 1024, 'Playtest recording is empty');
    await writeFile(join(output, 'watch-gate.webm'), video);
  }
  const frames = (await page.evaluate(() => window.rattlehelmFrameTimes)).sort((a, b) => a - b);
  const median = frames[Math.floor(frames.length / 2)];
  const max = frames.at(-1);
  console.log(`Watch Gate ${width}×${height}, Chromium WebGL 2: ${frames.length} rAF intervals, median ${median.toFixed(1)} ms, max ${max.toFixed(1)} ms`);
  assert.deepEqual(critical, []);
  console.log(`PASS ${build}: Chromium WebGL 2, WebAudio, hit t${hit.impactTick}, depth misses ${miss.missDepth.toFixed(1)}/${secondMiss.missDepth.toFixed(1)}, rolls and counters in both directions, pause, victory`);
}

try {
  await runSmoke();
} catch (error) {
  await page.screenshot({ path: join(output, 'failure.png'), timeout: 4_000 }).catch(() => {});
  throw error;
} finally {
  const state = await snapshot().catch(() => null);
  await writeFile(join(output, 'browser.log'), [
    url.href, ...messages, ...critical, JSON.stringify(state), JSON.stringify(Object.fromEntries(assets)),
  ].join('\n') + '\n');
  await browser.close();
}
