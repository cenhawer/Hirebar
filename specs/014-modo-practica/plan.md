# Implementation Plan: Modo práctica

**Branch**: `feature/HB-014-modo-practica` | **Date**: 2026-11-09 | **Spec**: [spec.md](spec.md)

## Summary

`AgentSettings.practice`. Antes de lanzar una ejecución `act`, `Controller.simulateIfPracticing` lee
lo aprobado del lote, lo guarda como `PracticeLog`, libera la aprobación (cupo), cierra el lote y
manda el resumen. `Practice.set` cambia el modo y lo registra; lo usan el panel, el menú, Ajustes y el
comando `practica`.

## Constitution Check

| Principio | Cumple | Cómo |
|---|---|---|
| II. Nada sale sin aprobación y sin rastro | ✅ | En práctica nada sale; queda el registro de lo que habría salido |
| VII. Probado sin red ni IA | ✅ | Simulación probada con `HIREBAR_HOME` temporal y el guard inyectado |
