# Implementation Plan: Partir archivos

**Branch**: `feature/HB-020-partir-archivos` | **Date**: 2026-11-10 | **Spec**: [spec.md](spec.md)

## Summary

- `HirebarApplication`: `Controller` en cinco archivos y los comandos en cuatro, como extensiones del
  mismo tipo; los miembros que se usan entre archivos dejan de ser `private`. `runNext` se divide en
  `readyToLaunch`, `launch` y `explain`.
- App: `Settings` en `Settings` (vistas), `SettingsModel`, `SettingsEditors` y `EngineEditor`; `save`
  se divide en `validatedAccounts`, `saveAgents` y `normalized`.
- `HirebarTelegram`: `TelegramUpdates` (lectura de mensajes) y `TelegramSending` (envíos).
- Se quitan los 32 comentarios que quedaban; `SourceShapeTests` vigila largo y comentarios.

## Constitution Check

| Principio | Cumple | Cómo |
|---|---|---|
| Código autoexplicativo, cero comentarios | ✅ | Test sobre `Sources` |
| VII. Probado sin red ni IA | ✅ | Suite completa sin cambios de comportamiento |
