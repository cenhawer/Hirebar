# Implementation Plan: Registros con OSLog

**Branch**: `feature/HB-023-logs-oslog` | **Date**: 2026-11-09 | **Spec**: [spec.md](spec.md)

## Summary

`Log` pasa a `HirebarApplication` como un valor con su `os.Logger`: `Log(.telegram)`,
`Log(agent: .jobs)` o `Log.write(_:)` para el área de sistema. Cada archivo declara su área una vez
(`private let log = Log(.portals)`); el `Controller` registra cada lote con la categoría de su agente.
`LogExport` (app) corre `log show` para los últimos 3 días y abre el resultado. Se adelanta a la
spec `017` porque sin E/S propia el registro puede usarlo cualquier adaptador sin depender de otro.

## Constitution Check

| Principio | Cumple | Cómo |
|---|---|---|
| IV. Datos locales y recuperables | ✅ | Registro del sistema, sin datos personales |
| VIII. Arquitectura hexagonal | ✅ | El registro no es un adaptador más del que dependan los demás |
