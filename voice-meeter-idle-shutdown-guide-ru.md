---
permalink: /voice-meeter-idle-shutdown-guide-ru/
---
<!doctype html>
<html lang="ru">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="index,follow">
<meta name="description" content="Как автоматически выключать VoiceMeeter после бездействия Windows. VoiceMeeter IdleWatcher проверяет время простоя и требует полного выключения дисплея перед запросом остановки через Remote API.">
<link rel="canonical" href="https://anallegory.github.io/VoiceMeeter-IdleWatcher/voice-meeter-idle-shutdown-guide-ru/">
<link rel="alternate" hreflang="en" href="https://anallegory.github.io/VoiceMeeter-IdleWatcher/voice-meeter-idle-shutdown-guide-en/">
<link rel="alternate" hreflang="ru" href="https://anallegory.github.io/VoiceMeeter-IdleWatcher/voice-meeter-idle-shutdown-guide-ru/">
<link rel="alternate" hreflang="x-default" href="https://anallegory.github.io/VoiceMeeter-IdleWatcher/voice-meeter-idle-shutdown-guide-en/">
<meta property="og:type" content="article">
<meta property="og:title" content="Как автоматически выключать VoiceMeeter после бездействия">
<meta property="og:description" content="Практическое описание автоматического выключения VoiceMeeter в Windows с проверкой бездействия, состояния дисплея и Remote API.">
<meta property="og:url" content="https://anallegory.github.io/VoiceMeeter-IdleWatcher/voice-meeter-idle-shutdown-guide-ru/">
<title>Автоматическое выключение VoiceMeeter после бездействия | IdleWatcher</title>
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "TechArticle",
  "headline": "Как автоматически выключать VoiceMeeter после бездействия",
  "description": "Практическое руководство по автоматическому выключению VoiceMeeter в Windows с помощью VoiceMeeter IdleWatcher.",
  "inLanguage": "ru",
  "mainEntityOfPage": "https://anallegory.github.io/VoiceMeeter-IdleWatcher/voice-meeter-idle-shutdown-guide-ru/",
  "about": ["VoiceMeeter", "Windows PowerShell", "VoiceMeeter Remote API", "Windows idle detection"],
  "author": {"@type": "Organization", "name": "VoiceMeeter IdleWatcher"}
}
</script>
<style>
:root{color-scheme:dark;--bg:#0d1422;--panel:#141f31;--ink:#e7edf7;--muted:#a5b4c9;--line:#2b3a52;--link:#a9c5ff;--amber:#f3c678}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:16px/1.7 system-ui,-apple-system,"Segoe UI",sans-serif}
a{color:var(--link)}.bar{padding:16px max(20px,calc((100% - 900px)/2));background:#0a1220;border-bottom:1px solid var(--line)}.bar a{text-decoration:none;color:#fff;font-weight:700}
main{width:min(900px,calc(100% - 32px));margin:30px auto 54px;padding:clamp(22px,4vw,42px);background:var(--panel);border:1px solid var(--line);border-radius:18px}
h1,h2{line-height:1.25;letter-spacing:-.025em}h1{font-size:clamp(2rem,5vw,3rem);margin-top:0}h2{margin-top:2em;padding-bottom:.35em;border-bottom:1px solid var(--line)}
p,li{color:#d5deec}strong{color:#fff}.notice{padding:14px 17px;border:1px solid #c99b55;border-radius:12px;background:#392c1b;color:#fff0d4}.notice strong{color:#ffe0a8}
code{padding:2px 5px;border-radius:5px;background:#26364e}footer{text-align:center;color:var(--muted);padding:0 16px 30px;font-size:.9rem}
</style>
</head>
<body>
<header class="bar"><a href="/VoiceMeeter-IdleWatcher/">VoiceMeeter IdleWatcher</a> · <a href="/VoiceMeeter-IdleWatcher/voice-meeter-idle-shutdown-guide-en/" lang="en">English</a></header>
<main>
<article>
<h1>Как автоматически выключать VoiceMeeter после бездействия</h1>
<p>VoiceMeeter представляет собой виртуальный аудиомикшер для Windows. Если после окончания работы он продолжает оставаться запущенным, может пригодиться автоматическое выключение после периода бездействия. Но одного таймера недостаточно: отсутствие ввода не всегда означает, что пользователь закончил работу.</p>

<h2>Какие условия нужно проверять</h2>
<p>Осторожная автоматизация должна учитывать сразу два условия:</p>
<ul>
<li><strong>Время бездействия Windows:</strong> должен пройти заданный интервал без пользовательского ввода.</li>
<li><strong>Состояние питания дисплея:</strong> дисплей должен быть полностью выключен. Состояния On, Dimmed, неизвестное или недоступное блокируют автоматическое выключение.</li>
</ul>
<p>Только при выполнении обоих условий наблюдатель отправляет запрос на выключение движка VoiceMeeter через Remote API. Windows при этом не выключается.</p>
<div class="notice"><strong>Важное ограничение: бездействие не означает тишину.</strong><br>IdleWatcher не измеряет воспроизведение звука и не определяет, продолжается ли трансляция, запись, загрузка, рендеринг или другая фоновая задача. Если VoiceMeeter должен оставаться доступным во время воспроизведения звука без участия пользователя, не включайте автоматическое выключение в такой ситуации. Учитывайте это ограничение при выборе порога бездействия.</div>

<h2>Как работает VoiceMeeter IdleWatcher</h2>
<ol>
<li>Небольшой запускатель Windows Script Host запускает PowerShell-наблюдатель в фоновом режиме.</li>
<li>Наблюдатель проверяет время последнего пользовательского ввода, уведомления о питании дисплея и доступность VoiceMeeter Remote API.</li>
<li>Порог бездействия по умолчанию составляет восемь минут. Его можно изменить в файле конфигурации.</li>
<li>Непосредственно перед запросом выключения защитные условия проверяются повторно. Если они изменились, выключение отменяется.</li>
</ol>
<p>Дополнительно можно включить индикатор MacroButtons. Он использует режим STATEONLY Remote API: меняет отображаемое состояние кнопки, не запуская её макрос. Принятие команды API не является считыванием фактического состояния интерфейса.</p>

<h2>Требования</h2>
<ul>
<li>Windows.</li>
<li>Windows PowerShell 5.1.</li>
<li>Установленный VoiceMeeter с DLL Remote API.</li>
<li>Включённый Windows Script Host для VBS-запускателя.</li>
</ul>
<p>Исходный код написан на PowerShell и разделён на модули. Файлы реализации должны находиться вместе в одной папке. Подробности приведены в <a href="https://github.com/AnAllegory/VoiceMeeter-IdleWatcher/blob/main/README.ru.md">README на русском</a> и <a href="https://github.com/AnAllegory/VoiceMeeter-IdleWatcher/blob/main/ARCHITECTURE.md">описании архитектуры</a>.</p>

<h2>Это выключение Windows?</h2>
<p>Нет. IdleWatcher отправляет запрос на остановку движка VoiceMeeter через Remote API. Он не завершает сеанс пользователя, не выключает компьютер, не переводит Windows в спящий режим и не завершает работу самой Windows.</p>

<h2>Текущий статус исходников и распространения</h2>
<div class="notice"><strong>Распространение Portable-пакетов временно приостановлено.</strong><br>Проект сейчас не предлагает поддерживаемый готовый ZIP-пакет, пока расследуются обнаруженные сигналы безопасности исторических архивов. Не запускайте ранее скачанные Portable ZIP и не обходите предупреждения антивируса. Исходный код и документация остаются открытыми для ознакомления.</div>
<p>Можно изучить <a href="https://github.com/AnAllegory/VoiceMeeter-IdleWatcher">репозиторий GitHub</a>, прочитать <a href="/VoiceMeeter-IdleWatcher/security-audit-ru/">отчёт о проверке исторических пакетов</a> или вернуться на <a href="/VoiceMeeter-IdleWatcher/">главную страницу проекта</a>.</p>

<h2>Частые вопросы</h2>
<h3>Может ли VoiceMeeter выключиться, пока я ещё работаю за компьютером?</h3>
<p>Для запроса выключения должны одновременно пройти заданный интервал бездействия и полностью выключиться дисплей. Состояния On, Dimmed и неизвестное блокируют запрос. Условия повторно проверяются непосредственно перед ним.</p>
<h3>Может ли VoiceMeeter выключиться, пока без участия пользователя воспроизводится звук?</h3>
<p>Да, такая ситуация возможна. IdleWatcher проверяет бездействие пользователя и состояние питания дисплея, но не измеряет воспроизведение звука. Если воспроизведение или другая фоновая задача должны продолжаться, не полагайтесь только на условия бездействия и выключенного дисплея.</p>
<h3>Останавливает ли команда остановки IdleWatcher сам VoiceMeeter?</h3>
<p>Нет. Штатная остановка IdleWatcher прекращает работу наблюдателя и освобождает ресурсы. Она не отправляет команду выключения VoiceMeeter.</p>
<h3>Можно ли использовать программу без VoiceMeeter Remote API?</h3>
<p>Нет. Наблюдателю необходима DLL Remote API, которая поставляется вместе с установленным VoiceMeeter.</p>
</article>
</main>
<footer>VoiceMeeter IdleWatcher · Open source · MIT License · <a href="https://github.com/AnAllegory/VoiceMeeter-IdleWatcher">Репозиторий GitHub</a></footer>
</body>
</html>