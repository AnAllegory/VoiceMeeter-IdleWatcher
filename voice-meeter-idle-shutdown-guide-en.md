---
permalink: /voice-meeter-idle-shutdown-guide-en/
---
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="index,follow">
<meta name="description" content="Learn how to automate VoiceMeeter shutdown after Windows inactivity. VoiceMeeter IdleWatcher checks user idle time and requires the display to be fully off before requesting shutdown through the Remote API.">
<link rel="canonical" href="https://anallegory.github.io/VoiceMeeter-IdleWatcher/voice-meeter-idle-shutdown-guide-en/">
<link rel="alternate" hreflang="en" href="https://anallegory.github.io/VoiceMeeter-IdleWatcher/voice-meeter-idle-shutdown-guide-en/">
<link rel="alternate" hreflang="ru" href="https://anallegory.github.io/VoiceMeeter-IdleWatcher/voice-meeter-idle-shutdown-guide-ru/">
<link rel="alternate" hreflang="x-default" href="https://anallegory.github.io/VoiceMeeter-IdleWatcher/voice-meeter-idle-shutdown-guide-en/">
<meta property="og:type" content="article">
<meta property="og:title" content="How to Automatically Shut Down VoiceMeeter After Inactivity">
<meta property="og:description" content="A practical explanation of idle-aware VoiceMeeter shutdown on Windows, including the display-off safety condition and Remote API requirements.">
<meta property="og:url" content="https://anallegory.github.io/VoiceMeeter-IdleWatcher/voice-meeter-idle-shutdown-guide-en/">
<title>Automatically Shut Down VoiceMeeter After Inactivity | IdleWatcher Guide</title>
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "TechArticle",
  "headline": "How to Automatically Shut Down VoiceMeeter After Inactivity",
  "description": "A practical guide to idle-aware VoiceMeeter shutdown on Windows using VoiceMeeter IdleWatcher.",
  "inLanguage": "en",
  "mainEntityOfPage": "https://anallegory.github.io/VoiceMeeter-IdleWatcher/voice-meeter-idle-shutdown-guide-en/",
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
<header class="bar"><a href="/VoiceMeeter-IdleWatcher/">VoiceMeeter IdleWatcher</a> · <a href="/VoiceMeeter-IdleWatcher/voice-meeter-idle-shutdown-guide-ru/" lang="ru">Русский</a></header>
<main>
<article>
<h1>How to Automatically Shut Down VoiceMeeter After Inactivity</h1>
<p>VoiceMeeter is a virtual audio mixer for Windows. If it stays running after you finish using your computer, you may want it to shut down automatically after a period of inactivity. The important part is making that decision safely: a quiet moment does not always mean you have finished working.</p>

<h2>What should an idle-aware shutdown check?</h2>
<p>A conservative Windows automation should consider more than a timer. VoiceMeeter IdleWatcher uses two conditions together:</p>
<ul>
<li><strong>Windows user idle time:</strong> the configured inactivity threshold must have elapsed.</li>
<li><strong>Display power state:</strong> the display must be fully Off. On, Dimmed, unknown or unavailable states block automatic shutdown.</li>
</ul>
<p>Only when both conditions are satisfied does the watcher request VoiceMeeter shutdown through the VoiceMeeter Remote API. It does not shut down Windows.</p>

<h2>How VoiceMeeter IdleWatcher works</h2>
<ol>
<li>A small Windows Script Host launcher starts the PowerShell watcher in the background.</li>
<li>The watcher checks the last user input, display power notifications and VoiceMeeter Remote API availability.</li>
<li>The default idle threshold is eight minutes and can be changed in the configuration file.</li>
<li>Before sending the shutdown request, the watcher checks the safety conditions again. If the conditions have changed, shutdown is cancelled.</li>
</ol>
<p>An optional MacroButtons indicator can show the watcher's intended state. It uses the Remote API's STATEONLY mode, which changes the displayed button state without running the button macro. API acceptance is not a visual readback.</p>

<h2>Requirements</h2>
<ul>
<li>Windows.</li>
<li>Windows PowerShell 5.1.</li>
<li>VoiceMeeter installed with its Remote API DLL.</li>
<li>Windows Script Host enabled for the VBS launcher.</li>
</ul>
<p>The project is modular PowerShell source. Its implementation files are designed to remain together in one application folder. See the <a href="https://github.com/AnAllegory/VoiceMeeter-IdleWatcher/blob/main/README.md">English README</a> and <a href="https://github.com/AnAllegory/VoiceMeeter-IdleWatcher/blob/main/ARCHITECTURE.md">architecture notes</a> for implementation details.</p>

<h2>Is this the same as shutting down Windows?</h2>
<p>No. IdleWatcher requests the VoiceMeeter engine to shut down through its Remote API. It does not sign out the user, power off the PC, put Windows to sleep or terminate Windows itself.</p>

<h2>Current source and distribution status</h2>
<div class="notice"><strong>Portable downloads are temporarily paused.</strong><br>The project is not currently offering a supported ready-to-run ZIP package while historical package security detections are being investigated. Do not run previously downloaded Portable ZIP files or bypass antivirus warnings. The source code and documentation remain public for inspection.</div>
<p>You can review the <a href="https://github.com/AnAllegory/VoiceMeeter-IdleWatcher">GitHub repository</a>, read the <a href="/VoiceMeeter-IdleWatcher/security-audit-en/">historical package security review</a>, or return to the <a href="/VoiceMeeter-IdleWatcher/">project homepage</a>.</p>

<h2>Frequently asked questions</h2>
<h3>Can VoiceMeeter shut down while I am still using the PC?</h3>
<p>The configured idle threshold must have elapsed and the display must be fully Off. Display On, Dimmed or unknown blocks the automatic shutdown request. The conditions are checked again immediately before the request.</p>
<h3>Does stopping the watcher shut down VoiceMeeter?</h3>
<p>No. Stopping IdleWatcher stops the watcher and performs cleanup. It does not issue a VoiceMeeter shutdown request.</p>
<h3>Can I use it without VoiceMeeter Remote API?</h3>
<p>No. The watcher requires the Remote API DLL supplied with a VoiceMeeter installation.</p>
</article>
</main>
<footer>VoiceMeeter IdleWatcher · Open source · MIT License · <a href="https://github.com/AnAllegory/VoiceMeeter-IdleWatcher">GitHub repository</a></footer>
</body>
</html>