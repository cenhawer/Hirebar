# Implementation Plan: Uso del panel

**Branch**: `feature/HB-031-panel-uso` | **Date**: 2026-11-16 | **Spec**: [spec.md](spec.md)

## Summary

- `PanelView` envuelve las secciones de agentes en `ScrollView` con `.frame(maxHeight:)`; encabezado
  y pie quedan fuera, igual que hoy.
- `ProfileReadError`/mensajes de `ProfileStore` y `ProfileDocumentStore` cambian "perfil.json no es
  JSON válido" por un texto en términos de la persona.

## Constitution Check

| Principio | Cumple | Cómo |
|---|---|---|
| La persona entiende lo que ve | ✅ | Panel con alto fijo y mensajes sin jerga de archivo |
| VII. Probado sin red ni IA | ✅ | Mensaje de error probado con `ProfileStoreTests` existente |
