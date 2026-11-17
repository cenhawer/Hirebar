# Implementation Plan: Accesibilidad

**Branch**: `feature/HB-030-accesibilidad` | **Date**: 2026-11-16 | **Spec**: [spec.md](spec.md)

## Summary

- `AgentAccessibility` en `HirebarApplication`: función pura que compone la etiqueta de VoiceOver de
  una fila de agente (nombre + estado) a partir de `AgentCardData`, sin color.
- `PanelView`/`AgentRow` usan `accessibilityElement(children: .combine)` + `.accessibilityLabel` en la
  fila, `.accessibilityLabel` en el `Toggle` de encendido y en el botón de Telegram, y un ícono/texto
  accesible junto al punto de estado de la IA ocupada.
- Tamaños fijos de `.font(.system(size:))` en `PanelView.swift` reemplazados por estilos semánticos
  (`.caption2`, `.caption`, `.footnote`, `.subheadline`), salvo los puntos de estado (6pt) y el
  chevron (9pt), documentados como excepción de diseño.

## Constitution Check

| Principio | Cumple | Cómo |
|---|---|---|
| La app la puede usar cualquier persona | ✅ | VoiceOver y tamaño de letra del sistema soportados en el panel |
| VII. Probado sin red ni IA | ✅ | `AgentAccessibility` probada con `AgentCardData` de prueba, sin UI |
