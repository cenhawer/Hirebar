# Implementation Plan: Arquitectura hexagonal

**Branch**: `feature/HB-017-dominio`, `feature/HB-017-adaptadores`, `feature/HB-017-composicion` | **Date**: 2026-11-09 | **Spec**: [spec.md](spec.md)

## Summary

Tres pasos, cada uno con su PR y la suite completa en verde:

1. **Dominio**: `TextTools`, `Models`, `JobScreener`, `FreelanceClassifier`, `SearchProfile`, las
   entidades de `Agents`, `Profile`, `ContentAccounts`, `Portals`, `PlatformQuota` y `ScriptAligner`
   pasan a `HirebarDomain`. La E/S queda en almacenes de `HirebarCore` (`AgentStore`, `ProfileStore`,
   `ContentAccountStore`, `PortalStore`, `Quotas`, `SearchProfileStore`) como extensiones, sin cambiar
   la API. `AgentKind.alias` queda en el dominio y la búsqueda por nombre configurado en el almacén;
   los valores por defecto heredados de `config.json` llegan como `AgentDefaults`. `ScriptAligner` se
   reescribe con nombres descriptivos y pasos separados, con tests de caracterización que fijan su
   comportamiento; las pausas son `VoicePause`.
2. **Adaptadores**: `HirebarStorage`, `HirebarTelegram`, `HirebarNotifications`, `HirebarPortals`,
   `HirebarAI` y `HirebarMedia`; `Notifier` se reparte entre un puerto `Messenger` y la elección de
   canal en la aplicación.
3. **Casos de uso y composición**: `Controller`, `Commands`, `Scheduler` y los radares se parten en
   casos de uso con puertos; la raíz de composición en `Hirebar` crea y conecta los adaptadores.

## Constitution Check

| Principio | Cumple | Cómo |
|---|---|---|
| VII. Probado sin red ni IA | ✅ | Dominio puro vigilado por test; alineador con tests de caracterización |
| VIII. Arquitectura hexagonal | ⚠️ | Se cierra al terminar el paso 3 |
