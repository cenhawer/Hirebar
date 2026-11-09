# Implementation Plan: Parser de comandos

**Branch**: `feature/HB-013-parser-comandos` | **Date**: 2026-11-09 | **Spec**: [spec.md](spec.md)

## Summary

`CommandParser` (en `HirebarApplication`) normaliza el texto, separa el argumento de los botones,
busca el verbo en `CommandVocabulary` y devuelve un `ParsedCommand` con `CommandKind` y `ListTarget`.
`Commands.handle` solo admite el mensaje, lo interpreta y despacha a funciones por grupo (control,
contenido, perfil). El vocabulario se carga de `Resources/comandos.json` y se rechaza si repite verbos.

## Constitution Check

| Principio | Cumple | Cómo |
|---|---|---|
| VI. Código que se explica solo | ✅ | Verbos en `comandos.json`; las respuestas siguen en el código hasta la spec `024` |
| VII. Probado sin red ni IA | ✅ | Tabla de pruebas sobre el vocabulario real |
| VIII. Arquitectura hexagonal | ⚠️ | Parser en `HirebarApplication`; las acciones siguen en `HirebarEngine` hasta la spec `017` |
