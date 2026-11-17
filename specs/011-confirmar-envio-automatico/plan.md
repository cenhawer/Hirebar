# Implementation Plan: Confirmar el envío automático

**Branch**: `feature/HB-011-confirmar-envio-automatico` | **Date**: 2026-11-09 | **Spec**: [spec.md](spec.md)

## Summary

`AutoSend` concentra qué agentes tienen envío automático, el texto de la confirmación y el registro
de cada cambio. La app pregunta con un diálogo antes de prenderlo (panel, menú y al guardar Ajustes);
Telegram responde a `auto … si` con la explicación y los botones `autoon:<agentes>` y `autocancel`, y
solo el primero lo prende. Apagar no pregunta.

## Technical Context

**Language/Version**: Swift 6.4 en el worker, Swift 6.3 en CI; `swift-tools-version` 5.9.

**Testing**: XCTest con `HIREBAR_HOME` temporal y las respuestas del `Controller` capturadas.

## Constitution Check

| Principio | Cumple | Cómo |
|---|---|---|
| II. Nada sale sin aprobación y sin rastro | ✅ | Confirmación explícita y registro de cada cambio |
| VI. Código que se explica solo | ⚠️ | Textos en el código hasta la spec `024` |
| VII. Probado sin red ni IA | ✅ | Pregunta y confirmación probadas con dobles |
| VIII. Arquitectura hexagonal | ⚠️ | `AutoSend` vive en `HirebarEngine` hasta la spec `017` |

## Project Structure

```text
Sources/HirebarEngine/AutoSend.swift              agentes, explicación y registro
Sources/HirebarEngine/Commands.swift              auto … si pregunta; autoon y autocancel
Sources/Hirebar/AutoSendConfirmation.swift        diálogo de la Mac
Sources/Hirebar/{PanelModel,StatusMenu,Settings}.swift
```
