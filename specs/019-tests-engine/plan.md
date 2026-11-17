# Implementation Plan: Tests del motor

**Branch**: `feature/HB-019-tests-engine` | **Date**: 2026-11-10 | **Spec**: [spec.md](spec.md)

## Summary

- Dobles: `TestClock` con tics y plazos, `MemoryRunState`, `RecordingWorkspace`,
  `Repositories.forTests`, `TestChatChannel` con descargas y videos registrados, `TestMediaRenderer`
  con video narrado configurable y `TestAIRunner` con corridas que se pueden detener.
- `EngineHarness` arma el motor con todos los dobles y el vocabulario real de `Resources/comandos.json`.
- Suites: `SchedulerTests`, `CommandFlowTests`, `VoiceNoteFlowTests`, `ControllerRunTests` y
  `RadarTests` (fuentes y lector de páginas falsos).
- Código: `Scheduler.nextRun` usa el reloj inyectado; los radares lanzan el envío automático con una
  tarea en lugar de `DispatchQueue`.

## Constitution Check

| Principio | Cumple | Cómo |
|---|---|---|
| VII. Probado sin red ni IA | ✅ | Todo el motor se prueba con dobles de los puertos |
