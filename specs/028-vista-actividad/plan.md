# Implementation Plan: Vista de actividad

**Branch**: `feature/HB-028-vista-actividad` | **Date**: 2026-11-10 | **Spec**: [spec.md](spec.md)

## Summary

- `HirebarApplication/Activity.swift`: `ActivityEntry`, `ActivityOutcome`, `ActivityPeriod`, `ActivityFilter`,
  el puerto `ActivityRepository` y los títulos de cada acción.
- `HirebarStorage/ExecutionActivity.swift`: `FileExecutionStateStore` implementa `ActivityRepository`
  con las verificaciones guardadas y los `*.practica.json`.
- App: `ActivityWindow.swift` (modelo `@Observable`, ventana y vista con filtros); botón en el pie
  del panel y **Ver actividad** en el menú; `Engine.activity` la entrega.

## Constitution Check

| Principio | Cumple | Cómo |
|---|---|---|
| VIII. Arquitectura hexagonal | ✅ | Puerto en la aplicación, lectura en Storage, vista en la app |
| VII. Probado sin red ni IA | ✅ | Tests con archivos temporales y fechas fijas |
| Accesibilidad | ✅ | El resultado se lee con ícono y texto, no solo color |
