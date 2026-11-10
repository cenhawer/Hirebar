# Implementation Plan: Asistente de primer uso

**Branch**: `feature/HB-025-asistente-primer-uso` | **Date**: 2026-11-10 | **Spec**: [spec.md](spec.md)

## Summary

- `HirebarApplication`: `SetupStep` (pasos con título y detalle), `SetupFacts` (armados desde la
  configuración, los agentes, las cuentas, el estado del canal y los permisos), `SetupChecklist`
  (pendientes y si hace falta abrir el asistente), el puerto `SystemPermissions` y, en `Config`,
  `verifiedEngine` y `setupDismissed`.
- Adaptadores: `VoiceListener.permissionState/requestPermission` y `MacNotifications.permissionState`;
  `MacPermissions` en la app los une.
- App: `SetupAssistantModel` y `SetupAssistantView` (bienvenida y nombre, IA con prueba, Telegram con
  `ChannelSettingsView`, agentes, permisos, resumen) en su ventana; `SetupChecklistSection` en el panel;
  acceso desde el menú y el engranaje; la prueba de IA en Ajustes también marca el motor como probado.

## Constitution Check

| Principio | Cumple | Cómo |
|---|---|---|
| VII. Probado sin red ni IA | ✅ | `SetupChecklist` es puro y tiene tests |
| VIII. Arquitectura hexagonal | ✅ | Permisos por puerto; la app une los adaptadores |
