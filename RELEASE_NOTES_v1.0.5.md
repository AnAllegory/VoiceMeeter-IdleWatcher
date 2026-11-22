# VoiceMeeter IdleWatcher v1.0.5

**Release date:** 2026-11-22  
**Release type:** Stable source release  
**Runtime:** Windows PowerShell 5.1

## English

### Highlights

- Reorganized the watcher into a modular source layout: the main PowerShell orchestrator, PSD1 configuration, VBS launcher, three focused PowerShell modules and the native C# interop source.
- Added a strict API-availability gate for MacroButtons writes. Periodic and manual-refresh writes are sent only when the Remote API state is known and the VoiceMeeter engine is confirmed running.
- When the Remote API reports no server (`IsParametersDirty = -2`), the watcher no longer attempts futile button writes and retains the last state accepted by the API. When the engine becomes available again, the watcher asserts ON.
- Preserved the safer automatic-shutdown sequence: an accepted STATEONLY OFF command is followed by a 1000ms refresh allowance, then idle, display and graceful-stop conditions are checked again immediately before `Command.Shutdown`.
- Kept MacroButtons optional and non-fatal, with one STATEONLY writer and no UI-state readback.

### Safety and behavior

- Automatic shutdown requires both the configured idle threshold and a fully Off display state.
- Display On, Dimmed, unknown or unavailable blocks automatic shutdown.
- A graceful `/stop` request stops the watcher and performs cleanup; it does not shut down VoiceMeeter.
- The existing bounded shutdown-retry policy remains in place.
- The default MacroButtons logical button ID is 1. Set it to `-1` in the PSD1 configuration to disable the optional indicator.

### Logging

Keep `DebugMode = false` for normal operation. Setting it to `true` enables high-volume per-probe, per-write and loop diagnostics. This can fill and rotate the default primary log (500 KB) and fallback log (2 MB) much faster. Enable it only temporarily when troubleshooting.

### Compatibility and distribution

- Windows with Windows PowerShell 5.1.
- VoiceMeeter installed with its Remote API.
- Windows Script Host enabled for the VBS launcher.
- This is a source release, not an installer or executable package. Keep all seven runtime files together in one application folder: the PS1, PSD1, VBS, three PSM1 modules and `VMRIdleWatcherNative.cs`.

### Verification and limitations

The maintainer reported a successful target-PC automatic-shutdown test on 2026-11-22: MacroButton 1 OFF was accepted (return code 0), the 1000ms allowance elapsed, final safety validation passed, `Command.Shutdown` returned code 0, and engine stop was confirmed. After waking the PC, the maintainer observed MacroButton 1 OFF and VoiceMeeter not running.

The exact visual instant when the MacroButtons UI changed before engine shutdown was not observed because the display was Off. API acceptance is not a visual-state readback.

GitHub Actions performs static checks for Windows PowerShell 5.1 parsing, project contracts, C# compilation, VBS argument handling and PSScriptAnalyzer findings. CI does not launch VoiceMeeter or verify the live MacroButtons UI.

---

## Русский

### Главное в версии

- Наблюдатель переведён на модульную структуру: основной PowerShell-оркестратор, конфигурация PSD1, VBS-запускатель, три специализированных PowerShell-модуля и исходник нативного C# interop.
- Добавлена строгая проверка доступности API перед командами MacroButtons. Периодическая синхронизация и ручное обновление отправляют команды только при известном состоянии Remote API и подтверждённой работе движка VoiceMeeter.
- После ответа Remote API «сервер отсутствует» (`IsParametersDirty = -2`) наблюдатель больше не пытается отправлять заведомо бесполезные команды кнопке и сохраняет последнее состояние, принятое API. При повторном обнаружении движка отправляется ON.
- Сохранена более безопасная последовательность автоматического выключения: после принятой команды STATEONLY OFF выдерживается пауза 1000 мс, затем непосредственно перед `Command.Shutdown` повторно проверяются бездействие, состояние дисплея и отсутствие запроса штатной остановки.
- MacroButtons остаётся необязательной функцией: один writer, только STATEONLY, без считывания состояния интерфейса.

### Безопасность и поведение

- Автоматическое выключение разрешено только после достижения заданного порога бездействия и при полностью выключенном дисплее.
- Состояния дисплея On, Dimmed, неизвестное или недоступное блокируют выключение.
- Запрос штатной остановки `/stop` завершает работу наблюдателя и освобождает ресурсы, но сам по себе не выключает VoiceMeeter.
- Сохранено ограничение повторных команд Shutdown.
- По умолчанию используется логический ID кнопки MacroButtons 1. Значение `-1` в PSD1 отключает необязательный индикатор.

### Журналирование

Для обычной работы оставляйте `DebugMode = false`. Значение `true` включает подробные трассировки каждой проверки, записи и основного цикла. Из-за большого объёма сообщений основной журнал (по умолчанию 500 КБ) и резервный (2 МБ) могут быстро заполняться и ротироваться. Включайте DebugMode только временно для диагностики.

### Совместимость и состав архива

- Windows и Windows PowerShell 5.1.
- Установленный VoiceMeeter с Remote API.
- Включённый Windows Script Host для VBS-запускателя.
- Это архив исходного кода, а не установщик или готовый EXE. Все семь рабочих файлов должны находиться вместе в одной папке: PS1, PSD1, VBS, три модуля PSM1 и `VMRIdleWatcherNative.cs`.

### Проверка и ограничения

По сообщению сопровождающего, 2026-11-22 на целевом ПК успешно прошёл цикл автоматического выключения: команда MacroButton 1 OFF принята (код 0), выдержана пауза 1000 мс, финальная проверка безопасности пройдена, `Command.Shutdown` вернул код 0, остановка движка подтверждена. После пробуждения ПК сопровождающий увидел, что MacroButton 1 погашен, а VoiceMeeter не запущен.

Точный момент визуального изменения кнопки до остановки движка не наблюдался, поскольку дисплей был выключен. Принятие команды API не является обратным считыванием видимого состояния.

GitHub Actions выполняет статические проверки Windows PowerShell 5.1, контрактов проекта, компиляции C#, обработки неверных аргументов VBS и анализатора PSScriptAnalyzer. CI не запускает реальный VoiceMeeter и не проверяет видимое состояние MacroButtons.
