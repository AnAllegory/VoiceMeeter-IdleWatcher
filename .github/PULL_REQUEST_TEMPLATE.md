## Summary / Краткое описание

Describe the change and the problem it solves.

## Related issue / Связанный Issue

Closes #

## Change type / Тип изменений

- [ ] Bug fix / Исправление ошибки
- [ ] Feature / Новая функция
- [ ] Documentation / Документация
- [ ] Maintenance or CI / Сопровождение или CI

## Safety and compatibility / Безопасность и совместимость

- [ ] Automatic shutdown still requires the idle threshold and display fully Off (0).
- [ ] Final idle, display and graceful-stop validation remains immediately before Command.Shutdown.
- [ ] MacroButtons remains optional and has a single STATEONLY writer.
- [ ] No GetStatus readback, MacroButton_IsDirty polling, process polling, WMI subscription, Process.Exited handler or second writer was introduced.
- [ ] Windows PowerShell 5.1 compatibility is preserved.
- [ ] Seven runtime files remain together and module import order is unchanged, where applicable.

## Validation / Проверки

Describe exactly what you ran. Distinguish static CI, source inspection and manual runtime testing.

- [ ] Relevant local checks completed, or the reason they could not be run is explained.
- [ ] GitHub Actions result has been reviewed.
- [ ] Manual runtime results, if any, are accurately attributed and include the tested tag or commit.

## Documentation / Документация

- [ ] Both README files were updated if user-facing behavior or instructions changed.
- [ ] Relevant project records were updated where necessary.

## Final review / Финальная проверка

- [ ] No secrets, credentials, unredacted logs or unrelated personal data are included.
- [ ] No public release tag was moved and no release was published as part of this routine change.
