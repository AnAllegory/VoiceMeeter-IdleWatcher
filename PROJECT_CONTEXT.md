# VoiceMeeter IdleWatcher — Project Context / Handover

**Last reviewed:** 2026-11-27  
**Current repository:** AnAllegory/VoiceMeeter-IdleWatcher  
**Default branch:** main  
**Visibility:** Public  
**Source baseline:** v1.0.6 merged, target-PC validated and published as the latest stable GitHub Release  
**Status:** The v1.0.6 source integration was merged through PR #13 on 2026-11-24 (merge commit `c71b20d6f4b6987be3b66758073fe325fddb4209`). PR #15 added the published Defender notice and produced release commit `d693ae05e28199b40ed10feae24c42b0a96d9f40`, to which the immutable `v1.0.6` tag points. The stable GitHub Release and Portable ZIP were initially published on 2026-11-24. The Portable ZIP download path and public website ZIP links were withdrawn on 2026-11-25; ready-to-run ZIP distribution is temporarily paused while the Google Search Console and Microsoft Defender detections are investigated. The v1.0.6 tag and GitHub Release remain unchanged; the detections do not establish whether the packages are malicious or false positives. PR #17 reconciled release documentation on `main`; PR #18 updated the tagged source links on `gh-pages`. The v1.0.5 tag remains unchanged at `ad60060dbe45323fb7c782ba6d4aa6df6b0b502f`, with its historical discussion at [#11](https://github.com/AnAllegory/VoiceMeeter-IdleWatcher/discussions/11). The current release is [v1.0.6](https://github.com/AnAllegory/VoiceMeeter-IdleWatcher/releases/tag/v1.0.6). As of 2026-11-27, the security investigation remains open and a clean Hyper-V guest is being prepared; no clean-guest Defender result or archive-execution result has yet been established.

> For a new review or development session: read this document, REPOSITORY_LINEAGE.md, ARCHITECTURE.md, CHANGELOG.md, ROADMAP.md, SECURITY.md and AGENTS.md, then inspect the actual source files and the public modular workflow. The current source is authoritative if documentation and code ever disagree.


## Краткая памятка для восстановления контекста (RU) — 2026-11-27

Это главный файл передачи проекта следующему чату или сопровождающему. Он собран из канонических документов и истории репозитория, доступных файлов Библиотеки и текущего диалога; это **не полный экспорт всех прежних переписок**. Автоматически прочитать весь архив чатов не удалось, поэтому пробелы отмечены явно. Сначала прочитать этот раздел, затем технические разделы ниже и документы из карты документации. При расхождении между пересказом и репозиторием приоритет имеют актуальный исходный код, workflow и подтверждённые журналы.

### Проект и текущее состояние

- Канонический репозиторий: [AnAllegory/VoiceMeeter-IdleWatcher](https://github.com/AnAllegory/VoiceMeeter-IdleWatcher), ветка main. Историческая Beta-ветка не является каноническим источником.
- Последний опубликованный стабильный релиз: **v1.0.6**. Неизменяемые теги и релизы не перемещать.
- Распространение готовых ZIP-пакетов приостановлено. Не запускать ранее скачанные Portable ZIP, не отключать Defender и не восстанавливать архивы из карантина.
- Причина предупреждений Google Search Console и Microsoft Defender **не установлена**. Нельзя называть их ложным срабатыванием или подтверждённым заражением без новых доказательств.
- На целевом ПК Defender обнаружил в Portable ZIP v1.0.6 угрозу **Trojan:Script/Wacatac.H!ml** и поместил архив в карантин. Отдельная пользовательская проверка папки установленного приложения не зафиксировала обнаружение. Это разные проверки, и отрицательный результат папки не оправдывает ZIP.
- Google Search Console сообщил о Portable ZIP v1.0.5 и странице, ссылавшейся на него. Позднее проверка URL показала, что страница находится в индексе Google. Индексация URL не означает, что предупреждение «Проблемы безопасности» снято.
- Итог отправки запроса на повторную проверку Google в имеющейся передаче не подтверждён. Проверить актуальный статус непосредственно в Search Console.
- В переписке упоминалась проблема структуры ZIP, но её точное воспроизведение и перечень ошибочных путей пока не зафиксированы в канонических материалах. Не описывать её как установленный дефект, пока не исследованы точные архивы и их списки файлов.

### Лаборатория Hyper-V

Хост: Windows 11 Pro 26H2, сборка 26300.10075, Intel Core i5-9400F, RAM 16 ГБ. Hyper-V и аппаратная виртуализация включены. Установка выполняется с HDD, поэтому медленная работа диска ожидаема.

Создана VM VM-Test-Windows11:
- Поколение 2; 6 ГБ RAM; 2 виртуальных процессора.
- Сеть Default Switch.
- Динамически расширяемый VHDX, максимальный размер 80 ГБ:
  E:\VM\VM-Test-Windows11\VM-Test-Windows11\Virtual Hard Disks\VM-Test-Windows11.vhdx
- ISO:
  E:\VM\Windows11_Client_x64_ru-ru_26300_9457.iso
- SHA-256, вычисленный PowerShell на хосте и сверенный с опубликованным значением для этого ISO:
  3DD71E8F84BFDC0054E1C4383DB2EAC921D21952AC03B2231CB6E9610A2F7423

Первоначальная загрузка VM завершилась UEFI Boot Summary с ошибкой загрузки SCSI DVD. После временного отключения Secure Boot внутри VM установщик Windows запустился. Это наблюдаемая последовательность, но сама по себе она не доказывает окончательную причину сбоя. Secure Boot сейчас оставлен отключённым; не включать его и не менять шаблоны наугад. **Состояние виртуального TPM 2.0 в беседе не было надёжно подтверждено**: не утверждать, что он включён, пока это не проверено в параметрах VM. Виртуальный TPM Hyper-V не равен физическому TPM-чипу хоста.

Внутри гостевой Windows выбрана редакция Windows 11 Pro, регион Россия и русская клавиатура. На этапе OOBE началась проверка/загрузка обновлений. Имя гостевого устройства VM-LAB-WIN11 и локальное имя пользователя LabUser предлагались как варианты, но окончательное подтверждение этих двух значений отсутствует. Точный текущий экран гостевой Windows следует уточнить у пользователя перед следующей инструкцией.

В гостя не передавались физические диски хоста и общие папки. Default Switch предоставляет сетевой доступ через хост. Это снижает прямое смешение сред, но не является абсолютной гарантией изоляции. Не включать общий доступ к папкам/буферу обмена и не подключать личный диск E: без отдельной необходимости.

### Следующие задачи лаборатории

1. Завершить OOBE и штатные обновления Windows.
2. Обновить Microsoft Defender Security Intelligence; проверить состояние защиты в реальном времени и другие актуальные параметры, ничего не отключая.
3. Создать контрольную точку Hyper-V для чистой обновлённой системы до помещения исследуемых архивов.
4. Получить только точные исторические артефакты v1.0.5 и v1.0.6, зафиксировать источник, имена, размеры и SHA-256. Не восстанавливать копию из карантина хоста.
5. Сначала сканировать архивы и содержимое без запуска. Сохранить точное имя обнаружения, действие Defender, время и версию сигнатур.
6. Сравнить результаты с исходниками и историей сборки. Исполнение программы не является первым шагом и требует отдельного обоснования и подготовленного снимка VM.
7. Не возвращать ZIP-загрузки на сайт, пока причины сигналов не исследованы и сопровождающий не примет отдельное решение о распространении.

### Как вести дальнейшую работу

- Общаться по-русски, давать **одно конкретное действие за раз** и ориентироваться на фактические названия элементов на экране. Не придумывать кнопки, не повторять уже пройденные шаги и не менять настройки без объяснения причины.
- Не устанавливать в гостевую Windows драйверы материнской платы, физического CPU/GPU, Realtek и прочих устройств хоста. Это виртуальное оборудование Hyper-V; использовать штатные драйверы Windows и обновления, не ставить сборники драйверов и оптимизаторы.
- Разделять подтверждённые факты, результаты CI, пользовательские наблюдения и гипотезы. Не выдавать пользовательский тест за тест, выполненный помощником.
- После завершения расследования обновить этот файл, CHANGELOG и, при необходимости, отдельные публичные заметки на двух языках. Не менять исходный код, версии, теги или релизы в рамках чисто документальной передачи.

### Безопасная проверка восстановления после очистки чатов

Не удалять старые чаты до проверки восстановления. Сначала дождаться слияния документационного PR, затем открыть новый чат и попросить прочитать [PROJECT_CONTEXT.md](https://github.com/AnAllegory/VoiceMeeter-IdleWatcher/blob/main/PROJECT_CONTEXT.md), [REPOSITORY_LINEAGE.md](https://github.com/AnAllegory/VoiceMeeter-IdleWatcher/blob/main/REPOSITORY_LINEAGE.md), [ARCHITECTURE.md](https://github.com/AnAllegory/VoiceMeeter-IdleWatcher/blob/main/ARCHITECTURE.md), [CHANGELOG.md](https://github.com/AnAllegory/VoiceMeeter-IdleWatcher/blob/main/CHANGELOG.md), [ROADMAP.md](https://github.com/AnAllegory/VoiceMeeter-IdleWatcher/blob/main/ROADMAP.md), [SECURITY.md](https://github.com/AnAllegory/VoiceMeeter-IdleWatcher/blob/main/SECURITY.md) и [AGENTS.md](https://github.com/AnAllegory/VoiceMeeter-IdleWatcher/blob/main/AGENTS.md). Попросить новый чат назвать текущий этап, подтверждённые факты и единственный следующий шаг. Удалять старые переписки только после успешной проверки и, желательно, после сохранения собственного экспорта/резервной копии истории.


## 1. Repository relationship and lineage

There is one canonical public repository:

- Public project: https://github.com/AnAllegory/VoiceMeeter-IdleWatcher
- Historical private modular workspace: https://github.com/AnAllegory/VoiceMeeter-IdleWatcher-Beta

The public repository's main branch previously contained the monolithic v1.0.1 source line. The modular implementation was developed in the private workspace through internal milestones v1.0.2, v1.0.3, v1.0.4 and v1.0.5.

The modular source baseline v1.0.5 was merged into public main through PR #10 (merge commit `5436b1ccbbd464aa43a4846af53750fafbf126e5`). The merge preserved the original public repository's commit history. The private Beta repository remains a historical workspace and is not the canonical source for future public development.

The repositories do not have asserted direct Git parent/child ancestry. The public v1.0.0 and v1.0.1 tags remain unchanged historical releases. The modular v1.0.5 baseline was integrated through PR #10 and published as the latest stable public release on 2026-11-22. The `v1.0.5` tag points to validated `main` commit `ad60060dbe45323fb7c782ba6d4aa6df6b0b502f`. The v1.0.2-v1.0.4 numbers remain internal development milestones, not separate public tags. The release includes bilingual notes and a linked Announcements discussion (#11).

The former public monolithic CI workflow was replaced with the modular workflow. Do not restore the old workflow unchanged: it validates a different source layout.

See REPOSITORY_LINEAGE.md for the timeline, module mapping and release boundary.

## 2. Purpose and non-negotiable safety rule

VoiceMeeter IdleWatcher is a Windows PowerShell automation utility. It monitors Windows idle time and display power state, and requests VoiceMeeter shutdown only when the configured idle threshold has elapsed and the display is fully Off.

Automatic shutdown requires:
- Idle threshold reached.
- Display fully Off (0).
- No pending graceful /stop request at final validation.

Display On (1), Dimmed (2), unknown or unavailable blocks automatic shutdown. After a successful pre-shutdown MacroButtons OFF write and its 1000ms allowance, all final safety conditions are rechecked immediately before Command.Shutdown.

Stopping IdleWatcher is not the same as shutting down VoiceMeeter. A normal /stop request terminates the watcher and performs cleanup; it does not itself send Command.Shutdown.

## 3. Current source files and responsibilities

- VoiceMeeter-IdleWatcher.ps1 — orchestrator, configuration loading/validation, monitoring loop, engine/API state, shutdown flow and retry policy.
- VoiceMeeter-IdleWatcher.psd1 — runtime configuration.
- VoiceMeeter-IdleWatcher.vbs — hidden launcher, explicit startup-status handling and graceful /stop.
- VoiceMeeter-IdleWatcher.Support.psm1 — logging, startup-status writing, stop signaling and immediate refresh signaling.
- VoiceMeeter-IdleWatcher.Interop.psm1 — Remote DLL discovery, C# marker replacement/compilation, API Login and session recovery.
- VoiceMeeter-IdleWatcher.MacroButtons.psm1 — single STATEONLY write path and last-write status.
- VMRIdleWatcherNative.cs — Windows idle/display/event interop and VoiceMeeter Remote API declarations.

Import order: **Support -> Interop -> MacroButtons**.

Keep the PS1, PSD1, VBS, three modules and C# source together in one application folder. Preserve tabs for code indentation.

## 4. Configuration baseline

Values verified in the current PSD1/source:

| Setting | Default | Meaning |
|---|---:|---|
| IdleMinutes | 8 | Idle threshold; valid range 1–60 |
| DebugMode | false | Detailed per-probe/per-write and loop diagnostics |
| ShutdownCommandLimit | 3 | Bounded successful, unconfirmed Shutdown commands per engine run |
| CheckIntervalSec | 10 | Main monitoring interval |
| RetryIntervalSec | 30 | Retry interval after relevant API errors |
| EngineAbsentProbeIntervalSec | 3 | Probe interval while engine is absent |
| DisplayNotificationTimeoutSec | 5 | Initial display-notification timeout |
| PostShutdownProbeIntervalSec | 1 | Prompt probe after Shutdown |
| PostShutdownRestartProbeIntervalSec | 3 | Probe interval while waiting for restart |
| PostShutdownConfirmationTimeoutSec | 5 | Stop confirmation window |
| ApiSessionRecoveryRetryIntervalSec | 5 | API session recovery interval |
| StopWaitTimeoutSec | 20 | Graceful stop wait |
| MacroButtonLogicalIndex | 1 | Remote API logical button index; -1 disables it |
| MacroButtonSyncIntervalSec | 10 | Periodic indicator write interval |
| MaxLogSizeBytes | 512000 | Primary log size threshold |
| FallbackMaxLogSizeBytes | 2097152 | Fallback log size threshold |

Numeric and named configuration values are bounded and validated at startup. STATEONLY mode is not a PSD1 setting. Keep `DebugMode = false` for normal operation; `true` enables high-volume diagnostic traces and can trigger log rotation quickly. The default primary and fallback log thresholds are 500 KB and 2 MB.

## 5. Critical implementation contracts

### PowerShell and module structure

- Windows PowerShell 5.1 compatibility is mandatory. Do not introduce PowerShell 7-only syntax or dependencies.
- Keep import order Support -> Interop -> MacroButtons.
- Keep code indentation tabs, not spaces.
- Keep the C# path marker __VOICEMEETER_DLL_PATH__ exactly once inside the verbatim string in VMRIdleWatcherNative.cs.
- Interop reads that C# file as UTF-8, doubles embedded quotes in the selected DLL path and replaces the marker before compiling.
- Select VoicemeeterRemote64.dll or VoicemeeterRemote.dll according to the PowerShell watcher process architecture, not guessed VoiceMeeter process bitness.
- Preserve the existing VBS launcher contract, startup status, single-instance mutex, named events, display notifications, API recovery, retry limits and cleanup paths.

### MacroButtons

- One centralized writer only: Invoke-MacroButtonStateSync.
- STATEONLY is fixed to 0x00000002 inside VoiceMeeter-IdleWatcher.MacroButtons.psm1.
- No GetStatus readback and no MacroButton_IsDirty call.
- Logical ID defaults to 1; -1 disables this optional feature.
- Synchronization errors remain non-fatal.
- API return code 0 means the write was accepted; it is not a UI readback.
- Desired, LastAccepted, WriterStatus and LastAcceptedAt are distinct. WriterStatus is the last writer result/status, not live API health. LastAccepted is not proof of the current visible button state.

### API availability gate (introduced in v1.0.5; retained in v1.0.6)

Periodic and manual-refresh writes require both a known API state and a confirmed running VoiceMeeter engine. A known-stopped state (IsParametersDirty = -2) means the server is unavailable, not that an OFF write can be sent. In this state, no repeated write is attempted and the last API-accepted indicator state is retained.

At startup or recovery, a Login result that indicates there is no running engine does not cause an initial OFF write. When the engine later becomes available, the watcher asserts ON.

### Automatic shutdown sequence (v1.0.4, retained in v1.0.6)

1. Check idle threshold, display Off and no pending /stop.
2. Attempt STATEONLY OFF while the API is available.
3. If OFF is accepted, wait 1000ms for the MacroButtons application to process its display-state polling notification.
4. Repeat idle, display and /stop checks immediately before Command.Shutdown.
5. If validation fails, cancel Shutdown and restore ON when possible.

The wait is not a readback. If MacroButtons is disabled or the optional OFF write fails, the wait is skipped and MacroButtons remains non-fatal. The final safety validation is still mandatory.

## 6. Maintainer-reported runtime evidence

The following are observations reported by the maintainer from the target Windows PC. They are not tests executed by GitHub Actions or by an external reviewer.

### Earlier evidence and the reason for v1.0.4

A prior v1.0.3 automatic-shutdown log recorded STATEONLY OFF accepted at 14:47:51.073 and Shutdown sent at 14:47:51.098, only 25ms later. The maintainer reported that the visible indicator had not extinguished before VoiceMeeter closed. This supported a timing-race hypothesis and led to the v1.0.4 1000ms allowance. The exact UI scheduling was not measured.

### v1.0.4 evidence and the reason for v1.0.5

The v1.0.4 log showed:
- 15:39:19.644 — OFF accepted.
- 15:39:19.651 — 1000ms allowance started.
- 15:39:20.669 — final safety validation passed.
- 15:39:20.687 — Shutdown returned code 0.
- 15:39:21.741 — engine stop confirmed.
- 15:39:30.801 — a redundant OFF write was attempted after the API had returned -2.

The last item led to the v1.0.5 write gate.

### v1.0.5 API transition and automatic shutdown test (2026-11-22)

The maintainer's v1.0.5 log recorded an engine/API availability transition:
- 16:00:38.322 — Remote API available.
- 16:00:38.327 — engine availability confirmed.
- 16:00:38.410 — MacroButton 1 ON accepted.
- 16:01:28.554 — API reported no server (-2); the watcher logged that OFF could not be sent and the last accepted state was retained.
- 16:01:42 — graceful watcher cleanup completed and the single-instance mutex was released.

A subsequent automatic-shutdown cycle recorded:
- 16:09:13 — display fully Off.
- 16:14:13.513 — idle threshold reached and MacroButton 1 OFF accepted.
- 16:14:13.519 — 1000ms refresh allowance started.
- 16:14:14.537 — final idle/display/stop validation passed.
- 16:14:14.557 — Command.Shutdown returned code 0.
- 16:14:15.617 — engine stop was confirmed.
- 16:14:24.642 — Remote API reported no server.
- 16:16:38.743 — user activity detected.
- 16:16:48.773 — display reported On.

After waking the PC, the maintainer visually confirmed that MacroButton 1 was not lit and VoiceMeeter was not running.

**What this proves:** the OFF write was accepted before Shutdown; the 1000ms wait and final revalidation occurred in the logged order; Shutdown succeeded; the engine stopped; and the indicator was OFF after the PC was awake again.

**What it does not prove:** the exact visual instant when the MacroButtons window extinguished the button relative to engine shutdown. The maintainer could not observe the button while the display was Off. There is no API readback in this design.

### v1.0.6 maintenance release (merged and target-PC validated 2026-11-24)

The v1.0.6 changes were merged through PR #13 (merge commit `c71b20d6f4b6987be3b66758073fe325fddb4209`) and contain three maintenance changes:

- The periodic status snapshot is emitted on the first main-loop pass, then only when at least 300 seconds have elapsed since the previous snapshot. The main monitoring loop remains at its configured interval (10 seconds by default); the MacroButtons synchronization interval is separate and unchanged.
- The diagnostic `Desired` summary now reports OFF only when the watcher has an accepted OFF write pending its own shutdown. If VoiceMeeter is confirmed stopped and no pre-shutdown OFF was accepted, the snapshot reports that writes are paused and the last accepted API state is retained.
- The temporary pending-shutdown marker is cleared when engine stop is confirmed or a successful API re-login confirms the engine state. The last API-accepted state remains independent; Remote API writes, API gates and shutdown eligibility are unchanged.

The maintainer-reported target-PC test on 2026-11-24 confirmed an immediate first snapshot at 15:45:23.754; five subsequent intervals of 300.332s, 300.378s, 300.379s, 300.370s and 307.692s; STATEONLY OFF accepted at 16:06:45.339; the 1000ms allowance; final validation passed at 16:06:46.394 (idle=482s, DisplayState=Off, StopRequested=False); Command.Shutdown return code 0; engine stop confirmed at 16:06:47.458; and API/engine recovery with MacroButton ON accepted at 16:10:22.892. The successful API return confirms command acceptance, not visual UI readback. Sleep/Wake event ordering, /stop arriving after Shutdown dispatch while the API is still responding, and VoiceMeeter starting when idle is already satisfied and the display is Off remain open observation scenarios, not confirmed defects or completed tests.

## 7. Accepted limitations and scope decisions

### Manual VoiceMeeter Exit

When VoiceMeeter is closed manually, the API server may disappear before the watcher can deliver STATEONLY OFF. After IsParametersDirty = -2, the watcher cannot send a command through that absent server. v1.0.5 now avoids futile writes and retains the last accepted indicator state. When VoiceMeeter becomes available again, the watcher asserts ON.

This is an accepted API lifecycle limitation, not a reason to add an independent writer.

### Deliberately not implemented

- VoiceMeeter process polling or WMI process monitoring.
- Process.Exited subscriptions as a way to write after API teardown.
- A second MacroButtons writer.
- GetStatus or MacroButton_IsDirty readback/polling in the watcher.
- A configurable STATEONLY bitmode.
- DLL selection based on guessed VoiceMeeter process bitness.

Any proposal to revisit these decisions must identify a reproducible problem and preserve the single-writer/API-availability model unless the maintainer explicitly approves a new design.

## 8. CI and validation

The public modular workflow is .github/workflows/powershell-check.yml. It runs on pushes to main and pull requests targeting main. See the public repository's [Actions page](https://github.com/AnAllegory/VoiceMeeter-IdleWatcher/actions) for the latest main-branch validation result.

The workflow performs:
- Windows PowerShell 5.1 parsing for the main script and PowerShell modules.
- Static project-contract checks for the v1.0.6 version, the 1000ms sequence, final safety validation, the STATEONLY invariant, no-readback contract, API write gates, diagnostic-summary semantics, pending-marker lifecycle and 300-second status-snapshot cadence.
- Tab-indentation checks for source files.
- C# interop compilation after the DLL marker is replaced with a placeholder path.
- VBS invalid-argument validation without launching the watcher.
- PSScriptAnalyzer 1.25.0 on the main script and PowerShell modules; Error-level findings fail CI, while Warning and Information findings are reported but non-blocking.

It does **not** launch the watcher, connect to a real VoiceMeeter instance, exercise Remote API sessions or test the visible MacroButtons UI/display hardware.

Always distinguish static CI, source inspection and maintainer-reported runtime behavior.

## 9. Documentation map

- README.md and README.ru.md — user-facing overview, requirements, configuration and start/stop instructions.
- REPOSITORY_LINEAGE.md — history of the public monolithic source and its modular development workspace.
- ARCHITECTURE.md — module boundaries, state flow and safety contracts.
- CHANGELOG.md — public change history and published release records, including v1.0.6.
- PROJECT_CONTEXT.md — this handover, source invariants and runtime evidence.
- GROK_REVIEW_BRIEF.md — historical technical review request and its disposition.
- AGENTS.md — mandatory rules for future review and maintenance.
- ROADMAP.md — current project status, follow-up observations and deliberate non-goals.
- SECURITY.md — vulnerability reporting guidance and safe handling of diagnostic material.
- CONTRIBUTING.md and CONTRIBUTING.ru.md — contributor workflow, development requirements and project safety contracts.
- .github/ISSUE_TEMPLATE/ and .github/PULL_REQUEST_TEMPLATE.md — structured issue and pull-request forms.
- RELEASE_NOTES_v1.0.5.md — published stable-release description and verification notes.
- RELEASE_NOTES_v1.0.6.md — final bilingual maintenance-release notes, static CI result and target-PC runtime evidence.
- LICENSE — MIT license terms.

This repository is the canonical documentation and source location. Keep the bilingual guides and project records synchronized with implementation changes.

## 10. Working rules for future assistance

- Communicate in Russian unless the maintainer asks otherwise.
- Use the actual current source files and workflow as the implementation truth.
- Treat public main as the canonical source baseline. Review proposed changes through pull requests before merging; use the private Beta repository only as historical lineage context.
- Give one concrete user instruction at a time.
- Do not ask for information already recorded in this handover or supplied in the current conversation.
- Do not claim a runtime test was executed by the assistant. Attribute local test results to the maintainer.
- Keep documentation consistent in English and Russian where both versions exist.
- Do not create or move public tags, or publish releases, unless the maintainer explicitly authorizes the release action.


## 11. Security and distribution investigation (2026-11-25 to 2026-11-27)

This section separates documented observations from unresolved explanations. It is not a security verdict.

### Timeline and established observations

- **2026-11-24:** v1.0.6 source integration and maintenance release were published. Static CI passed and the maintainer reported target-PC runtime validation. The Portable ZIP was initially published as a release artifact.
- **2026-11-25:** The maintainer reported a Google Search Console Security Issues warning involving the v1.0.5 Portable ZIP and a page that linked to it. The maintainer also reported a Microsoft Defender detection on the downloaded v1.0.6 Portable ZIP: Trojan:Script/Wacatac.H!ml; Defender quarantined the archive.
- A separate custom scan of the installed application folder completed with no recorded detection. This is not equivalent to scanning the original ZIP and does not establish that the archive is safe.
- The public ZIP download path and website download links were withdrawn. The website and both READMEs now display a bilingual, evidence-limited warning. Ready-to-run distribution remains paused.
- During a later Search Console URL inspection, the maintainer saw that the project page was indexed by Google. URL indexing is not the same as a clean Security Issues report, a successful review request or the removal of a security warning.
- The maintainer opened the Search Console Security Issues area and attempted to request a review. One form attempt was blocked by the required acknowledgement field. The final submission status and Google's final decision are not established by the repository evidence available at this handover date; check the live Search Console property before reporting a result.

### Evidence boundaries

| Question | Current evidence | What remains unproven |
|---|---|---|
| Did Google flag the v1.0.5 Portable ZIP / linking page? | Reported in Search Console and documented on the site and in repository notices. | The exact underlying Google classifier reason and final review outcome. |
| Did Defender detect v1.0.6 Portable ZIP? | Yes; Trojan:Script/Wacatac.H!ml was reported and the downloaded archive was quarantined on the maintainer's Windows 11 PC. | Whether this is a true positive, false positive or packaging/heuristic interaction. |
| Did a separate folder scan detect the same threat? | The maintainer reported no detection event in a separate custom scan of the installed application folder. | This does not clear the ZIP, the extracted contents, every file or every execution path. |
| Has the same archive been tested in a clean guest? | No result is recorded as of 2026-11-27; the Hyper-V guest is still being prepared. | Clean-guest scan result and any later controlled runtime behavior. |
| Is there a confirmed ZIP layout defect? | A ZIP-structure/layout concern was mentioned during recent conversations. | The exact malformed/duplicate/missing paths and a reproducible comparison have not been captured in the canonical record. Do not describe it as confirmed until the original archives are inspected. |
| Is the source proven safe? | Static CI and prior source review/target-PC validation exist. | CI is not malware analysis and does not certify packaged archives or prove absence of malicious behavior. |

### Required handling

- Do not run historical Portable ZIPs on the host.
- Do not disable Defender, bypass a warning or restore a quarantined archive.
- Keep the public ZIP distribution pause and bilingual warning until the maintainer makes a new, evidence-based decision.
- Record exact artifact provenance, version, filename, byte size and SHA-256 before comparing results.
- Preserve the distinction between archive scan, extracted-folder scan, individual-file scan, static source review and runtime execution.
- If Defender detects an item, record the threat name, affected path, action, time and Security Intelligence version. Do not restore it merely to continue.
- Do not infer that a page being indexed means Google has cleared the security issue.

## 12. Hyper-V investigation lab — host and guest record (created 2026-11-26/27)

### Host

- Windows 11 Pro 26H2, OS build 26300.10075.
- Intel Core i5-9400F; 16 GB RAM.
- Hyper-V was enabled through Windows Features; CPU virtualization was already enabled.
- The user reports that the E: storage device is an HDD, so guest installation and updates may be slow.

### Virtual machine configuration

| Setting | Recorded value |
|---|---|
| Hyper-V VM name | VM-Test-Windows11 |
| Generation | 2 |
| Startup memory | 6144 MB; dynamic memory was not selected in the wizard |
| Virtual processors | 2 |
| Virtual switch | Default Switch |
| Virtual disk | Dynamically expanding VHDX, maximum 80 GB |
| VHDX path | E:\VM\VM-Test-Windows11\VM-Test-Windows11\Virtual Hard Disks\VM-Test-Windows11.vhdx |
| Installation ISO | E:\VM\Windows11_Client_x64_ru-ru_26300_9457.iso |
| ISO build | Windows 11 Client x64, Russian, build 26300.9457 |
| ISO SHA-256 | 3DD71E8F84BFDC0054E1C4383DB2EAC921D21952AC03B2231CB6E9610A2F7423 |

The maintainer computed the ISO SHA-256 with PowerShell and reported that it matched the Microsoft-published hash checked during download. The ISO is an installation medium; Windows itself is installed inside the VHDX. The dynamically expanding 80 GB value is a maximum virtual size, not 80 GB preallocated on E:.

### Boot and security settings

The initial Generation 2 boot attempt displayed a UEFI boot summary in which the SCSI DVD boot loader failed; the empty virtual disk and unavailable network boot image were also listed. After Secure Boot was temporarily disabled in this VM's settings, Windows Setup proceeded to the language-selection screen. This establishes the observed sequence, not a fully isolated root-cause diagnosis.

Current handover facts:
- Secure Boot was left **disabled inside this VM** as the workaround that allowed Setup to proceed. Do not imply that this is the preferred final hardening state.
- The Secure Boot template had been set to **Microsoft Windows** before the failed boot.
- **Virtual TPM 2.0 status was not positively verified in the conversation.** Do not state that it is enabled. If Windows 11 requirements or a later test depends on it, inspect the separate TPM checkbox in VM Security settings and record its actual state. A Hyper-V virtual TPM is a guest virtual device and is not the same thing as a physical TPM chip in the host.
- The VM uses Default Switch, so the guest has network connectivity through the host's connection. This is not an independent physical network connection.
- No host physical disk was passed through and no host shared folder was intentionally configured. Do not describe the VM as an absolute security boundary.

### Guest installation progress at last handover

- Windows 11 Pro was selected in Windows Setup.
- The guest region was set to Russia and the keyboard to Russian.
- The guest device name VM-LAB-WIN11 and local account name LabUser were suggested during OOBE, but their final acceptance is not confirmed in this record.
- OOBE reached a Windows update check/download screen, which indicated that the process could take around 30 minutes. The exact current screen and update completion must be confirmed with the maintainer at the next interaction.
- No third-party hardware-driver bundles, optimization utilities or additional antivirus products have been installed as part of the recorded lab preparation.

### Minimal lab policy

Use Windows Update, Defender platform/security-intelligence updates and inbox Hyper-V virtual-device drivers. Do not install host motherboard, physical CPU, GPU, Realtek or other OEM drivers into this guest. Do not add unnecessary developer tools or applications. Keep Defender enabled. Do not enable host folder sharing or attach personal physical disks for convenience.

## 13. Next actions for the clean-guest investigation

1. Finish the guest OOBE and Windows Update. Confirm the guest reaches the desktop and reboots normally from its VHDX with the ISO no longer needed for boot.
2. Update Microsoft Defender Security Intelligence and verify that real-time protection is enabled. Record the actual state and version rather than assuming defaults.
3. Create and name a Hyper-V checkpoint for the updated, Defender-ready guest before importing any historical sample.
4. Obtain the exact historical v1.0.5 and v1.0.6 Portable artifacts from a traceable source. Do not recover the quarantined host copy. If an original artifact is unavailable, state that limitation instead of substituting a GitHub-generated source snapshot.
5. Record artifact filenames, sizes and SHA-256 hashes. Compare ZIP entry lists and directory structure before extraction. Keep the two versions separate.
6. Scan the ZIP archives without executing them. Record Defender's detection name, affected path, action, timestamp and intelligence version. If a sample is quarantined, do not restore it just to continue.
7. Compare archive contents with the corresponding tagged source/release records. Do not infer a false positive from a clean folder scan or a clean scan of a different artifact.
8. Only consider runtime execution after static/archive evidence has been reviewed and the maintainer explicitly chooses a controlled test. Use a fresh checkpoint and disable guest networking before any run that does not require network access. Never expose host folders or personal data to the guest.

No clean-guest scan, archive comparison or runtime result is established by this handover. These are pending tasks, not completed work.

## 14. Recovering project continuity after chat cleanup

This handover was compiled from the canonical repository documents and PR history, available Library files, and the current conversation. It is not a complete archive or transcript of every previous chat; the Files search available for this task surfaced Library files, not arbitrary full chat transcripts. Treat unrecorded historical details as unknown until they are recovered from an export or another primary source.

The repository, not the chat list, should be the durable record. Before deleting old chats:

1. Merge the documentation update and verify that PROJECT_CONTEXT.md is readable on GitHub.
2. Start a new chat and ask it to read this file first, then REPOSITORY_LINEAGE.md, ARCHITECTURE.md, CHANGELOG.md, ROADMAP.md, SECURITY.md and AGENTS.md.
3. Ask the new chat to report the canonical repository/release, unresolved security questions, exact Hyper-V lab state and the single next action. Correct any discrepancy while the old chats are still available.
4. Keep a local/exported copy of important conversations or the handover if you want an additional fallback.
5. Only then decide whether to delete old conversations.

A new chat may need the repository URL or a copy of this document if it does not have repository access. Do not assume that deleting chats automatically gives a new chat access to every repository or file.

