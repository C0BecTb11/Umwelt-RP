extends RefCounted
## Страница лог-чекера (с 0.55): отдаёт сервер (admin_site.gd) по адресу https://<сервер>:8443/.
## Только текст — данные ставятся через textContent (чат игроков не может стать кодом страницы).
## В строках ниже нет обратных косых черт: GDScript не трогает текст.

const HTML := """<!doctype html>
<html lang="ru"><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<title>Umwelt RP · лог-чекер</title>
<style>
:root{--bg:#111318;--card:#1b1e25;--line:#2c313b;--fg:#e8e9ec;--mut:#9097a3;--acc:#5aa9e6;--bad:#e25c5c;--ok:#5cc28a}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--fg);font:15px/1.45 system-ui,-apple-system,Roboto,sans-serif}
header{position:sticky;top:0;z-index:5;background:#151820;border-bottom:1px solid var(--line);padding:10px 14px;display:flex;gap:10px;align-items:center}
header b{font-size:16px}header .who{margin-left:auto;color:var(--mut);font-size:13px}
button{font:inherit;border:0;border-radius:10px;padding:10px 14px;background:var(--acc);color:#071521;font-weight:600}
button.sec{background:#2a2f39;color:var(--fg)}
input{font:inherit;width:100%;padding:10px 12px;border-radius:10px;border:1px solid var(--line);background:#0e1015;color:var(--fg)}
label{display:block;color:var(--mut);font-size:12px;margin:0 0 4px}
main{max-width:980px;margin:0 auto;padding:14px}
.card{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:16px}
#login{max-width:380px;margin:40px auto}
#login h1{margin:0 0 4px;font-size:20px}#login p{color:var(--mut);margin:0 0 16px;font-size:13px}
#login .f{margin-bottom:12px}
.err{color:var(--bad);font-size:13px;min-height:18px;margin:6px 0}
.chips{display:flex;gap:8px;overflow-x:auto;padding-bottom:6px;margin-bottom:12px;scrollbar-width:none}
.chip{flex:none;padding:8px 12px;border-radius:999px;background:#232833;color:var(--fg);font-size:13px;font-weight:500;border:1px solid transparent}
.chip.on{background:#16324a;border-color:var(--acc);color:#cfe7fb}
.chip.soon{opacity:.45}
.filters{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-bottom:12px}
.filters .wide{grid-column:1/-1}
.filters .go{grid-column:1/-1;display:flex;gap:10px}.filters .go button{flex:1}
.day{margin:18px 0 8px;color:var(--mut);font-size:13px;font-weight:600;letter-spacing:.3px}
.row{display:grid;grid-template-columns:64px 1fr;gap:4px 10px;padding:10px 0;border-top:1px solid var(--line)}
.row .tm{color:var(--mut);font-variant-numeric:tabular-nums;font-size:13px;padding-top:1px}
.row .who2{font-weight:600}
.row .what{grid-column:2;word-break:break-word}
.row .meta{grid-column:2;color:var(--mut);font-size:12px}
.badge{display:inline-block;font-size:11px;font-weight:600;border-radius:6px;padding:1px 6px;margin-right:6px;vertical-align:1px}
.empty{color:var(--mut);text-align:center;padding:30px 0}
.foot{color:var(--mut);font-size:12px;margin-top:16px;text-align:center}
.more{display:block;margin:16px auto 0}
.hidden{display:none}
@media(min-width:720px){.filters{grid-template-columns:repeat(4,1fr)}.filters .wide{grid-column:auto}.filters .go{grid-column:1/-1}}
</style></head>
<body>
<header><b>Umwelt RP · лог-чекер</b><span class="who" id="who"></span><button class="sec hidden" id="out">Выйти</button></header>
<main>
<section id="login" class="card hidden">
<h1>Вход</h1>
<p>Только для допущенных администраторов. Почта и пароль игрового аккаунта.</p>
<div class="f"><label for="em">Почта</label><input id="em" type="email" autocomplete="username"></div>
<div class="f"><label for="pw">Пароль</label><input id="pw" type="password" autocomplete="current-password"></div>
<div class="err" id="lerr"></div>
<button id="lbtn" style="width:100%">Войти</button>
</section>
<section id="app" class="hidden">
<div class="chips" id="chips"></div>
<div class="filters">
<div><label for="from">С</label><input id="from" type="date"></div>
<div><label for="to">По</label><input id="to" type="date"></div>
<div class="wide"><label for="pl">Игрок — ID или часть имени</label><input id="pl" placeholder="5 или Miller"></div>
<div class="wide"><label for="tx">Текст</label><input id="tx" placeholder="слово из сообщения, предмет…"></div>
<div class="go"><button id="find">Найти</button><button class="sec" id="reset">Сбросить</button></div>
</div>
<div class="err" id="qerr"></div>
<div id="list"></div>
<button class="sec more hidden" id="more">Показать ещё</button>
<div class="foot" id="foot"></div>
</section>
</main>
<script src="/app.js"></script>
</body></html>
"""

const JS := """'use strict';
const $ = id => document.getElementById(id);
let META = null, CAT = 'all', LAST = 0, DAY = '';
const COL = {conn:'#7c8cff',chat:'#5aa9e6',payday:'#5cc28a',fight:'#e25c5c',item:'#d8a74a',acc:'#b07cff',admin:'#8a94a3',money:'#3fbf9f',sms:'#e07fb0',property:'#c9a46a'};
async function api(path, opt) {
  opt = opt || {};
  opt.headers = Object.assign({'X-Umwelt': '1'}, opt.headers || {});
  opt.credentials = 'same-origin';
  const r = await fetch(path, opt);
  let d = {};
  try { d = await r.json(); } catch (e) {}
  if (r.status === 401) { show(false); throw new Error(d.error || 'Нужно войти'); }
  if (!r.ok) throw new Error(d.error || ('Ошибка ' + r.status));
  return d;
}
function el(tag, cls, text) { const e = document.createElement(tag); if (cls) e.className = cls; if (text !== undefined) e.textContent = text; return e; }
function show(on) { $('login').classList.toggle('hidden', on); $('app').classList.toggle('hidden', !on); $('out').classList.toggle('hidden', !on); if (!on) $('who').textContent = ''; }
function msk(t) { return new Date(t + 3 * 3600 * 1000).toISOString(); }
function today() { return msk(Date.now()).slice(0, 10); }
function shift(d, n) { const x = new Date(d + 'T00:00:00Z'); x.setUTCDate(x.getUTCDate() + n); return x.toISOString().slice(0, 10); }
function item(id) { return (META && META.items[id]) || id; }
function tag(n, p) { return (n || 'Игрок') + ' (' + p + ')'; }
function describe(e) {
  switch (e.c) {
    case 'conn': return e.e === 'in' ? 'вошёл в игру' + (e.on ? ' · онлайн ' + e.on : '') : 'вышел из игры' + (e.why ? ' (' + e.why + ')' : '');
    case 'chat': return '«' + e.txt + '»' + (e.k === 'try' ? (e.ok ? ' · Удачно' : ' · Неудачно') : '') + (e.h ? ' · слышали ' + e.h : ' · рядом никого');
    case 'payday': return e.ok ? 'PayDay засчитан: отыграл ' + e.min + ' мин, зарплата $' + e.pay + ' → уровень ' + e.lv + ', опыт ' + e.xp + (e.up ? ' · НОВЫЙ УРОВЕНЬ' : '') : 'PayDay не засчитан: отыграл ' + e.min + ' мин из 20';
    case 'fight':
      if (e.e === 'hit') return 'ударил ' + tag(e.vn, e.v) + ' · урон ' + e.dmg + ' · ' + item(e.w) + (e.ko ? ' · без сознания' : '');
      if (e.e === 'ko') return 'потерял сознание';
      return 'очнулся у больницы';
    case 'item': return ({use: 'использовал', drop: 'выбросил', wear: 'надел', unwear: 'снял'}[e.e] || e.e) + ': ' + item(e.id) + (e.k > 1 ? ' ×' + e.k : '');
    case 'acc': return 'аккаунт удалён — персонаж убран из мира';
    case 'admin': return e.e === 'login' ? 'вошёл в лог-чекер' : 'неудачная попытка входа в лог-чекер';
  }
  return JSON.stringify(e);
}
function chips() {
  const box = $('chips'); box.textContent = '';
  const all = [['all', 'Все']].concat((META.order || Object.keys(META.cats)).map(k => [k, META.cats[k]]));
  for (const [k, name] of all) {
    const soon = META.soon.indexOf(k) >= 0;
    const b = el('button', 'chip' + (k === CAT ? ' on' : '') + (soon ? ' soon' : ''), name + (soon ? ' · скоро' : ''));
    b.onclick = () => { CAT = k; chips(); find(true); };
    box.appendChild(b);
  }
}
function row(e) {
  const d = msk(e.t);
  if (d.slice(0, 10) !== DAY) {
    DAY = d.slice(0, 10);
    const p = DAY.split('-');
    $('list').appendChild(el('div', 'day', p[2] + '.' + p[1] + '.' + p[0]));
  }
  const r = el('div', 'row');
  r.appendChild(el('div', 'tm', d.slice(11, 19)));
  const w = el('div');
  const b = el('span', 'badge', META.cats[e.c] || e.c);
  b.style.background = (COL[e.c] || '#666') + '33'; b.style.color = COL[e.c] || '#ccc';
  w.appendChild(b);
  w.appendChild(el('span', 'who2', e.p !== undefined ? tag(e.n, e.p) : (e.n || 'Сервер')));
  r.appendChild(w);
  r.appendChild(el('div', 'what', describe(e)));
  if (e.x !== undefined) r.appendChild(el('div', 'meta', 'место: ' + Math.round(e.x) + ', ' + Math.round(e.y)));
  $('list').appendChild(r);
}
async function find(fresh) {
  $('qerr').textContent = '';
  if (fresh) { LAST = 0; DAY = ''; $('list').textContent = ''; }
  const q = new URLSearchParams({cats: CAT === 'all' ? '' : CAT, from: $('from').value, to: $('to').value,
    player: $('pl').value, text: $('tx').value, before: LAST || '', limit: 100});
  $('find').disabled = true;
  try {
    const d = await api('/api/logs?' + q.toString());
    for (const e of d.items) row(e);
    if (d.items.length) LAST = d.items[d.items.length - 1].t;
    if (fresh && !d.items.length) $('list').appendChild(el('div', 'empty', META.soon.indexOf(CAT) >= 0 ? 'Этой системы в игре ещё нет — записи появятся, когда её сделаем' : 'Ничего не найдено'));
    $('more').classList.toggle('hidden', !d.more);
  } catch (err) { $('qerr').textContent = err.message; }
  $('find').disabled = false;
}
async function start() {
  try {
    META = await api('/api/meta');
  } catch (e) { show(false); return; }
  show(true);
  $('who').textContent = META.who;
  if (!$('to').value) { $('to').value = META.today; $('from').value = shift(META.today, -6); }
  $('foot').textContent = 'Журнал: ' + META.days + ' сут., ' + (META.bytes / 1048576).toFixed(1) + ' МБ · хранится ' + META.keep + ' дней · время московское · за раз — до ' + META.range + ' дней';
  chips(); find(true);
}
$('lbtn').onclick = async () => {
  $('lerr').textContent = ''; $('lbtn').disabled = true;
  try {
    await api('/api/login', {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({email: $('em').value.trim(), password: $('pw').value})});
    $('pw').value = '';
    await start();
  } catch (e) { $('lerr').textContent = e.message; }
  $('lbtn').disabled = false;
};
$('pw').addEventListener('keydown', e => { if (e.key === 'Enter') $('lbtn').click(); });
$('out').onclick = async () => { try { await api('/api/logout', {method: 'POST'}); } catch (e) {} show(false); };
$('find').onclick = () => find(true);
$('more').onclick = () => find(false);
$('reset').onclick = () => { $('pl').value = ''; $('tx').value = ''; $('to').value = META.today; $('from').value = shift(META.today, -6); CAT = 'all'; chips(); find(true); };
start();
"""
