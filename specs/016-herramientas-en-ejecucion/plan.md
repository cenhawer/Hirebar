# Implementation Plan: Herramientas en ejecución

**Branch**: `feature/HB-016-herramientas-en-ejecucion` | **Date**: 2026-11-09 | **Spec**: [spec.md](spec.md)

## Summary

`SystemTools` lee `Resources/herramientas.json` (rutas de ffmpeg, comando de instalación y límites de
audio). `AudioTools` toma ffmpeg de ahí o falla con el comando para instalarlo; la copia vieja de
Python se borra al arrancar. Telegram informa tamaño y duración de cada audio, y la app los compara con
el máximo antes de descargar. Ajustes muestra el estado de ffmpeg en las cuentas con video.

## Constitution Check

| Principio | Cumple | Cómo |
|---|---|---|
| V. Sin dependencias ocultas | ✅ | ffmpeg del sistema, sin `pip` ni descargas |
| VI. Código que se explica solo | ⚠️ | Rutas y límites en `herramientas.json`; textos en el código hasta la spec `024` |
| VII. Probado sin red ni IA | ✅ | Búsqueda y límites probados con rutas falsas |
