# ADR-0003: ffmpeg como prerrequisito del sistema

## Estado

Aceptado · 2026-11-05

## Contexto

El video narrado necesita abrir la nota de voz de Telegram (Ogg/Opus, que macOS no abre), aplicar un
filtro paso alto, recortar silencios y pausas, quitar ruido (`afftdn`), comprimir, normalizar a −14
LUFS (`loudnorm`) y detectar pausas (`silencedetect`). Hoy la app crea un entorno de Python y descarga
ffmpeg con `pip` (paquete `imageio-ffmpeg`) mientras corre, sin versión fija ni verificación.

## Decisión

ffmpeg es un prerrequisito del sistema (`brew install ffmpeg`), declarado en el README y verificado
por la app en la configuración inicial. La app nunca instala ni descarga herramientas mientras corre.

## Consecuencias

- Desaparece la descarga invisible en la Mac de la persona y la dependencia de Python.
- La persona necesita Homebrew. Hoy no agrega fricción: todo el que instala Hirebar lo compila con
  Xcode.
- El adaptador de `AudioProcessor` busca ffmpeg en el sistema y devuelve un error de prerrequisito si
  falta (spec `016-herramientas-en-ejecucion`); el asistente de primer uso lo pide al inicio (spec
  `025-asistente-primer-uso`).

## Alternativas consideradas

| Alternativa | Por qué no |
|---|---|
| Instalar en ejecución con versión fija y hash | Sigue bajando un binario mientras corre y depende de Python |
| Reemplazar por AVFoundation | macOS no abre Ogg y no tiene equivalentes nativos de `afftdn` ni `loudnorm`: mucho código propio y riesgo en la calidad de la voz |
| Empaquetar ffmpeg con la app | Exige una compilación LGPL propia (el binario de `imageio-ffmpeg` suele ser GPL), suma unos 50 MB y otro binario que firmar y notarizar |

## Cuándo revisar

Si Hirebar se distribuye firmado y notarizado a personas que no compilan (fase 7), pedir Homebrew sí
es fricción: se decide entre empaquetar ffmpeg LGPL o pasar a AVFoundation en un ADR que reemplace
a este.

## Referencias

- Constitución, principio V.
- `ARCHITECTURE.md` §3.1 y §6.
- `docs/Plan.md`, decisión D7.
