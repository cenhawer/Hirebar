# Implementation Plan: Versión de los datos

**Branch**: `feature/HB-022-version-datos` | **Date**: 2026-11-10 | **Spec**: [spec.md](spec.md)

## Summary

- `VersionedJSON` en `HirebarStorage`: lee la versión, agrega `schemaVersion` al guardar, envuelve las
  listas y no escribe sobre un archivo más nuevo. Lo usan `Config`, `AgentStore`,
  `ContentAccountStore` y `ProfileEditor`.
- `WorkspaceMigration.run()` en el arranque (`Engine.start`): respalda y reescribe los archivos sin
  versión y mueve el estado de `UserDefaults` a `estado/corrida.json`.
- `FileRunStateRepository` reemplaza al repositorio sobre `UserDefaults`; también implementa
  `ChatOffsetStore`, que Telegram recibe en su inicializador.
- `Paths.backups` (`respaldos/`).

## Constitution Check

| Principio | Cumple | Cómo |
|---|---|---|
| Datos versionados con respaldo | ✅ | Migración al arrancar con copia previa |
| VIII. Arquitectura hexagonal | ✅ | Telegram recibe el offset por un puerto |
