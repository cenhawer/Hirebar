# Implementation Plan: Fixtures de portales

**Branch**: `feature/HB-021-fixtures-portales` | **Date**: 2026-11-10 | **Spec**: [spec.md](spec.md)

## Summary

- `WebPageFetcher` pasa a `data(_:)` con `text(_:)` derivado; `PortalClock` para la hora.
- Los siete lectores reciben el lector de páginas; Freelancer, Get on Board y Magneto también la hora.
- Computrabajo: identificador con comillas simples o dobles y modalidad con clases extra;
  `offers(in:)` en Computrabajo y elempleo.
- Fixtures reales recortados en `Tests/Fixtures/portals/` (búsqueda de cada portal, vacante de
  LinkedIn y proyecto de Workana); `PortalFixtureTests` con perfiles de prueba y hora fija.

## Constitution Check

| Principio | Cumple | Cómo |
|---|---|---|
| VII. Probado sin red ni IA | ✅ | Lector de páginas falso y hora fija |
| VIII. Arquitectura hexagonal | ✅ | Los lectores reciben el puerto en vez de llamar a `Net` |
