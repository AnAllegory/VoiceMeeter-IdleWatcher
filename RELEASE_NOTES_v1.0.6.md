# VoiceMeeter IdleWatcher v1.0.6

**Release status:** Final release package prepared; GitHub tag and Release publication pending  
**Preparation date:** 2026-11-24  
**Runtime:** Windows PowerShell 5.1

## English

### Highlights

- Corrected the MacroButtons status snapshot so `Desired=OFF` is reported only while an accepted pre-shutdown OFF command is pending the watcher's own shutdown.
- When VoiceMeeter is confirmed stopped without an accepted pre-shutdown OFF command, the snapshot reports that writes are paused and the last API-accepted state is retained.
- Clear the temporary pending-shutdown marker after a confirmed engine stop or a successful API re-login that resolves the engine state. The last API-accepted state remains separate.
- Set periodic status snapshots to a minimum interval of 300 seconds while keeping the first snapshot on the initial main-loop pass. The main monitoring loop and default MacroButtons synchronization interval remain unchanged.
- Extend static CI contracts for the diagnostic summary, pending-marker lifecycle, immediate first snapshot and 300-second interval.

### Safety and behavior

- Automatic shutdown still requires the configured idle threshold, display fully Off (0), and no pending graceful `/stop` request.
- An accepted STATEONLY OFF command is still followed by the 1000ms allowance and final idle/display/stop validation immediately before `Command.Shutdown`.
- MacroButtons remains optional and non-fatal, with one STATEONLY writer and no UI-state readback.
- No installer or EXE is included. The Portable ZIP contains the seven runtime files and this bilingual quick-start guide.

### Verification

**GitHub Actions:** The Windows PowerShell 5.1 workflow passed on merge commit `c71b20d6f4b6987be3b66758073fe325fddb4209` (run [#45386275337](https://github.com/AnAllegory/VoiceMeeter-IdleWatcher/actions/runs/45386275337)). Parsing, project-contract checks, C# compilation, VBS invalid-argument handling and PSScriptAnalyzer all completed successfully. CI is static and does not launch VoiceMeeter or inspect the live MacroButtons UI.

**Maintainer-reported target-PC validation (2026-11-24):**

- The watcher started as v1.0.6. The first status snapshot appeared immediately at 15:45:23.754.
- Subsequent snapshots appeared at 15:50:24.086, 15:55:24.464, 16:00:24.843, 16:05:25.213 and 16:10:32.905. Each interval was at least 300 seconds (300.332s, 300.378s, 300.379s, 300.370s and 307.692s).
- The display became fully Off at 16:01:44.928. The pre-shutdown STATEONLY OFF command was accepted at 16:06:45.339 (Remote API return code 0).
- The 1000ms allowance began at 16:06:45.346. Final validation passed at 16:06:46.394 with idle=482s, DisplayState=Off and StopRequested=False. `Command.Shutdown` returned code 0.
- Engine stop was confirmed at 16:06:47.458. The Remote API later reported no server (-2), as expected after VoiceMeeter stopped.
- After user activity, the Remote API became available again at 16:10:22.889. The watcher confirmed engine availability and MacroButton ON was accepted at 16:10:22.892. The 16:10:32.905 snapshot reported `Desired=ON`, `LastAccepted=ON` and `WriterStatus=Available`.

The successful API return confirms command acceptance, not visual UI readback. The target-PC test covered the normal idle/display-Off shutdown cycle and subsequent engine/API recovery. Sleep/Wake edge ordering, a `/stop` arriving after Shutdown dispatch while the API still responds, and VoiceMeeter starting while the idle threshold is already met remain observation scenarios, not confirmed defects or completed tests.

---

## Русский

### Главное в версии

- Исправлена статусная сводка MacroButtons: `Desired=OFF` отображается только пока принятая команда OFF перед выключением ожидает завершения собственного цикла Shutdown.
- Если остановка VoiceMeeter подтверждена, но команда OFF перед выключением не была принята, сводка сообщает, что записи приостановлены и сохраняется последнее состояние, принятое API.
- Временный маркер ожидающего выключения очищается после подтверждённой остановки движка или успешного повторного Login, определившего состояние движка. Последнее состояние, принятое API, хранится отдельно.
- Интервал статусных сводок установлен не менее 300 секунд, первая сводка по-прежнему появляется на первом проходе основного цикла. Основной цикл наблюдения и стандартный интервал синхронизации MacroButtons не изменены.
- Статические контракты CI дополнены проверками диагностической сводки, жизненного цикла временного маркера, немедленной первой сводки и интервала 300 секунд.

### Безопасность и поведение

- Для автоматического выключения по-прежнему необходимы заданный порог бездействия, полностью выключенный дисплей (0) и отсутствие ожидающего запроса штатной остановки `/stop`.
- После принятой команды STATEONLY OFF по-прежнему выдерживается пауза 1000 мс, затем непосредственно перед `Command.Shutdown` повторно проверяются бездействие, состояние дисплея и отсутствие запроса остановки.
- MacroButtons остаётся необязательной и некритичной функцией: один writer STATEONLY, без считывания состояния интерфейса.
- Установщик и EXE не входят в комплект. Portable ZIP содержит семь рабочих файлов и это двуязычное краткое руководство.

### Проверка

**GitHub Actions:** Workflow для Windows PowerShell 5.1 успешно завершился на merge-коммите `c71b20d6f4b6987be3b66758073fe325fddb4209` ([запуск #45386275337](https://github.com/AnAllegory/VoiceMeeter-IdleWatcher/actions/runs/45386275337)). Успешно прошли разбор PowerShell, проектные контракты, компиляция C#, обработка неверного аргумента VBS и PSScriptAnalyzer. Это статические проверки: CI не запускает VoiceMeeter и не проверяет живой интерфейс MacroButtons.

**Проверка на целевом ПК по журналу сопровождающего (2026-11-24):**

- Watcher запущен как v1.0.6. Первая статусная сводка появилась сразу, в 15:45:23.754.
- Последующие сводки появились в 15:50:24.086, 15:55:24.464, 16:00:24.843, 16:05:25.213 и 16:10:32.905. Каждый интервал составил не менее 300 секунд: 300.332, 300.378, 300.379, 300.370 и 307.692 секунды.
- Дисплей полностью выключился в 16:01:44.928. Команда STATEONLY OFF перед выключением была принята в 16:06:45.339 (код Remote API 0).
- Пауза 1000 мс началась в 16:06:45.346. Финальная проверка успешно пройдена в 16:06:46.394: idle=482s, DisplayState=Off, StopRequested=False. `Command.Shutdown` вернул код 0.
- Остановка движка подтверждена в 16:06:47.458. Позже Remote API сообщил об отсутствии сервера (-2), что ожидаемо после остановки VoiceMeeter.
- После пользовательской активности Remote API снова стал доступен в 16:10:22.889. Watcher подтвердил работу движка, а команда MacroButton ON была принята в 16:10:22.892. Сводка в 16:10:32.905 показала `Desired=ON`, `LastAccepted=ON` и `WriterStatus=Available`.

Успешный код API подтверждает принятие команды, но не является обратным считыванием визуального состояния интерфейса. На целевом ПК проверены обычный цикл выключения при бездействии и выключенном дисплее, а также последующее восстановление движка/API. Порядок событий Sleep/Wake, поступление `/stop` после отправки Shutdown при ещё отвечающем API и запуск VoiceMeeter при уже достигнутом пороге бездействия остаются сценариями для наблюдения, а не подтверждёнными дефектами или завершёнными тестами.
