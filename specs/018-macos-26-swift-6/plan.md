# Implementation Plan: macOS 26 y Swift 6

**Branch**: `feature/HB-018-macos-26-swift-6` | **Date**: 2026-11-10 | **Spec**: [spec.md](spec.md)

## Summary

- `Package.swift`: `swift-tools-version` 6.2, `platforms: [.macOS(.v26)]` y
  `defaultIsolation(MainActor.self)` en la app. `Info.plist` con `LSMinimumSystemVersion` 26.0.
- Aplicación: `Controller`, `Radar`, `Scheduler`, `ChannelSetup`, `Notifier`, `ExecutionGuard` y
  `TelegramExecutionAlerts` en `@MainActor`; los puertos `Clock`, `AIRunner`, `MediaRenderer` y
  `ExecutionAlerts` también. `ChatChannel` sigue sin aislamiento (Telegram trabaja en su hilo) y sus
  respuestas llegan en cierres `@MainActor @Sendable`.
- Adaptadores: los envíos de Telegram serializan el cuerpo JSON antes de cambiar de hilo; la descarga
  de la nota de voz corre en una tarea separada con `async/await`.
- Medios: `WebFrameCapture` en `@MainActor` con `async/await`; `ReelRenderer` se parte en
  `ReelRenderer` (API y armado), `ReelVideoWriter` (cuadros), `ReelFrames` (dibujo) y
  `ReelSoundMixer` (sonido con las APIs async de AVFoundation).
- App: `PanelModel`, `SettingsModel` y `ChannelSettingsModel` con `@Observable`; las vistas con
  `@Bindable`; `onChange` y `Text` con las APIs actuales.
- Tests: las clases que usan el motor son `@MainActor` con `setUp`/`tearDown` `async`; los dobles
  respetan el aislamiento de cada puerto.

## Constitution Check

| Principio | Cumple | Cómo |
|---|---|---|
| VII. Probado sin red ni IA | ✅ | La suite completa pasa con los dobles aislados |
| VIII. Arquitectura hexagonal | ✅ | El aislamiento se declara en los puertos de la aplicación |
| Stack (macOS 26, Swift 6, `@Observable`) | ✅ | Paquete, bundle y modelos de interfaz al día |
