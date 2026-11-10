# Implementation Plan: Política de datos

**Branch**: `feature/HB-029-politica-datos` | **Date**: 2026-11-10 | **Spec**: [spec.md](spec.md)

## Summary

- `RetentionPolicy` en `HirebarApplication` (plazos en días, semanas de métricas y tamaño de los
  historiales; versión y valores validados), leída del bundle en `HirebarStorage` y entregada en
  `EngineResources`.
- `Repositories.files(searchDefaults:retention:)` reparte la política: listas (`FileBatchRepository`),
  turnos del programador (`FileRunStateRepository`) y limpieza (`FileWorkspaceRepository`).
- `Housekeeping.run(policy:at:)` usa la política y `HousekeepingMedia` borra grabaciones, videos armados,
  borradores y listas descartadas vencidos.
- Guía de uso con la tabla de retención; `bundle.sh` copia el recurso y el CI lo valida.

## Constitution Check

| Principio | Cumple | Cómo |
|---|---|---|
| Datos con plazo | ✅ | Política única aplicada en la limpieza semanal |
| VII. Probado sin red ni IA | ✅ | Limpieza probada sobre carpetas temporales |
