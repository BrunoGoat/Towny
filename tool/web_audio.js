// ¿Suena la web? Abre la web en Chromium con las reglas de reproducción de un
// navegador de verdad —nada suena hasta que la persona toca la página— y
// apunta cada intento de sonar: qué archivo, y si el navegador lo dejó.
//
//   flutter build web --profile -O1 --base-href /Towny/ -o /tmp/web
//   mkdir -p /tmp/srv && ln -sfn /tmp/web /tmp/srv/Towny
//   (cd /tmp/srv && python3 -m http.server 8765 &)
//   node tool/web_audio.js /tmp/audio.png
//
// Lo que tiene que salir: antes del primer toque, la música pide sonar y el
// navegador dice que no (NotAllowedError); después del toque, las tres capas
// de la música y el toque mismo dicen OK. Si no sale nada de nada, el sonido
// ni arrancó —que es lo que pasaba cuando el arranque reventaba en la web—.
const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch({ args: ['--autoplay-policy=user-gesture-required'] });
  const pg = await b.newPage({ viewport: { width: 400, height: 860 } });
  await pg.addInitScript(() => {
    window.__log = [];
    const L = (m) => window.__log.push((performance.now()/1000).toFixed(1) + ' ' + m);
    const AC = window.AudioContext;
    let n = 0;
    window.AudioContext = function (...a) { const c = new AC(...a); const id = ++n; L('ctx#' + id + ' new ' + c.state); c.addEventListener('statechange', () => L('ctx#' + id + ' -> ' + c.state)); const r = c.resume.bind(c); c.resume = () => { L('ctx#' + id + ' resume() called'); return r(); }; return c; };
    window.AudioContext.prototype = AC.prototype;
    const ce = document.createElement.bind(document); document.createElement = (t, ...a) => { if (String(t).toLowerCase()==='audio') L('createElement audio'); return ce(t, ...a); };
    const play = HTMLMediaElement.prototype.play;
    HTMLMediaElement.prototype.play = function () { const src = (this.src||'').split('/').pop(); L('play ' + src); return play.call(this).then(() => L('play OK ' + src), (e) => { L('play FAIL ' + src + ' ' + e.name); throw e; }); };
  });
  pg.on('console', m => console.log('console[' + m.type() + ']:', m.text().slice(0, 200))); pg.on('pageerror', e => console.log('pageerror:', e.message, (e.stack||'').slice(0,600)));
  await pg.goto('http://localhost:8765/Towny/');
  await pg.waitForTimeout(8000); console.log('audio test', await pg.evaluate(async () => { try { const a = new Audio('assets/assets/sfx/tap.wav'); await new Promise(r => a.oncanplay = r); return 'ok ' + a.duration; } catch (e) { return 'fail ' + e; } }));
  console.log('--- before click'); console.log((await pg.evaluate(() => window.__log)).join('\n'));
  await pg.mouse.click(200, 700);
  await pg.waitForTimeout(3000);
  await pg.mouse.click(200, 792); await pg.waitForTimeout(2500); await pg.mouse.click(200, 400);
  await pg.waitForTimeout(3000);
  console.log('--- after clicks'); console.log((await pg.evaluate(() => window.__log)).join('\n'));
  await pg.screenshot({ path: process.argv[2] });
  await b.close();
})();
