# VoiceMeeter IdleWatcher v1.0.6

**Release status:** Prepared maintenance candidate; not yet published  
**Release date:** To be assigned on publication  
**Runtime:** Windows PowerShell 5.1

## English

### Highlights

- Corrected the MacroButtons status snapshot so `Desired=OFF` is reported only when the pre-shutdown OFF write was accepted and remains pending for the watcher's own shutdown.
- When VoiceMeeter is confirmed stopped and no pre-shutdown OFF write was accepted, the diagnostic snapshot now says that writes are paused and the last API-accepted state is retained. This corrects reporting only; it does not add a writer or change API behavior.
- Set periodic status snapshots to a minimum interval of 300 seconds, while keeping the first snapshot on the initial main-loop pass. The monitoring loop and default MacroButtons synchronization interval remain unchanged.
- Extended static CI contracts for the diagnostic summary, the immediate first snapshot and the 300-second interval.

### Safety and behavior

- The automatic-shutdown safety gates are unchanged: the configured idle threshold must be reached, the display must be fully Off (0), and no graceful `/stop` request may be pending.
- The accepted STATEONLY OFF command is still followed by the 1000ms allowance and final idle/display/stop validation immediately before `Command.Shutdown`.
- MacroButtons remains optional and non-fatal, with one STATEONLY writer and no UI-state readback.
- v1.0.5 remains the latest published stable release until a separate publication action is completed. No v1.0.6 tag or GitHub Release is created by this candidate preparation.

### Verification and limitations

The GitHub Actions workflow checks Windows PowerShell 5.1 parsing, project contracts, the status-snapshot and diagnostic-summary invariants, the 1000ms shutdown sequence, final safety validation, C# compilation, VBS invalid-argument handling and PSScriptAnalyzer findings. These are static checks; CI does not launch VoiceMeeter, connect to its Remote API or inspect the MacroButtons UI.

Before publication, run the candidate on the target Windows PC and verify:

1. The first status snapshot appears on the initial main-loop pass; later snapshots are separated by at least 300 seconds.
2. The normal idle-threshold plus display-Off shutdown sequence still completes, with the OFF acceptance, 1000ms allowance, final validation and Shutdown result visible in the log.
3. Observe, without assuming a defect, Sleep/Wake event ordering, a `/stop` request arriving after Shutdown dispatch while the Remote API is still responding, and VoiceMeeter starting while the idle threshold is already reached and the display is Off.

The additional scenarios above are open runtime observations, not confirmed defects. No target-PC runtime test of the v1.0.6 candidate is claimed here.

---

## Русский

### Главное в версии

- Исправлена сводка состояния MacroButtons: `Desired=OFF` отображается только тогда, когда команда OFF перед выключением была принята API и остаётся ожидающей штатного выключения наблюдателя.
- Если остановка VoiceMeeter подтверждена, но команда OFF перед выключением не была принята, диагностическая сводка теперь сообщает, что записи приостановлены и сохраняется последнее состояние, принятое API. Исправлено только журналирование: новый writer не добавлен, поведение API не изменено.
- Периодичность статусных сводок ограничена интервалом не чаще одного раза в 300 секунд. Первая сводка по-прежнему выводится на первом проходе основного цикла. Интервал цикла наблюдения и стандартная периодичность синхронизации MacroButtons не изменены.
- Статические проверки CI дополнены контрактами для диагностической сводки, немедленного первого снимка и интервала 300 секунд.

### Безопасность и поведение

- Защитные условия автоматического выключения не изменены: должен быть достигнут заданный порог бездействия, дисплей должен быть полностью выключен (0), а запрос штатной остановки `/stop` не должен ожидать обработки.
- После принятой команды STATEONLY OFF по-прежнему выдерживается пауза 1000 мс, затем непосредственно перед `Command.Shutdown` повторно проверяются бездействие, состояние дисплея и отсутствие запроса остановки.
- MacroButtons остаётся необязательной и некритичной функцией: один writer STATEONLY, без считывания состояния интерфейса.
- До отдельной публикации v1.0.5 остаётся последним стабильным релизом. При подготовке этого кандидата тег v1.0.6 и GitHub Release не создавались.

### Проверка и ограничения

Workflow GitHub Actions проверяет разбор Windows PowerShell 5.1, контракты проекта, периодичность статусных сводок и смысл диагностического поля, последовательность с паузой 1000 мс, финальную проверку безопасности, компиляцию C#, обработку неверного аргумента VBS и результаты PSScriptAnalyzer. Это статические проверки: CI не запускает VoiceMeeter, не подключается к его Remote API и не проверяет интерфейс MacroButtons.

Перед публикацией необходимо проверить кандидата на целевом ПК:

1. Первая статусная сводка появляется на первом проходе основного цикла, последующие выводятся с интервалом не менее 300 секунд.
2. Обычная последовательность выключения при достижении порога бездействия и выключенном дисплее завершается штатно; в журнале видны принятие OFF, пауза 1000 мс, финальная проверка и результат Shutdown.
3. Без предположения о наличии дефекта понаблюдать за порядком событий Sleep/Wake, за запросом `/stop`, поступившим после отправки Shutdown, пока Remote API ещё отвечает, и за запуском VoiceMeeter, когда порог бездействия уже достигнут, а дисплей выключен.

Эти дополнительные сценарии являются открытыми вопросами runtime-проверки, а не подтверждёнными дефектами. Проверка кандидата v1.0.6 на целевом ПК здесь не заявляется.
