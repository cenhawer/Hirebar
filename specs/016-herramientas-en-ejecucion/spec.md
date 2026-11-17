# Feature Specification: Herramientas en ejecución

**Feature Branch**: `feature/HB-016-herramientas-en-ejecucion`

**Created**: 2026-11-09

**Status**: Draft

**Input**: ADR-0003. Hoy, la primera vez que llega una nota de voz, la app crea un entorno de Python y
descarga ffmpeg con `pip` (paquete `imageio-ffmpeg`) sin versión fija ni verificación. Esta spec usa
solo el ffmpeg del sistema, lo valida al configurar y limita el tamaño de los audios que llegan por
Telegram.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Nada se instala mientras la app corre (Priority: P1)

La persona instala ffmpeg una vez con Homebrew y Hirebar lo usa; la app nunca descarga herramientas.

**Why this priority**: descargar binarios sin verificar en la Mac de la persona es una dependencia
oculta (principio V).

**Independent Test**: sin ffmpeg en el sistema, mandar una nota de voz; la respuesta explica cómo
instalarlo y no se crea ningún entorno de Python.

**Acceptance Scenarios**:

1. **Given** ffmpeg en `/opt/homebrew/bin` o `/usr/local/bin`, **When** llega una nota de voz,
   **Then** se usa ese ffmpeg.
2. **Given** que falta ffmpeg, **When** llega una nota de voz, **Then** la respuesta dice el comando
   para instalarlo y no se descarga nada.
3. **Given** una cuenta de contenido con video, **When** la persona la configura en Ajustes, **Then**
   ve si falta ffmpeg, el comando para instalarlo y "Comprobar de nuevo".
4. **Given** una instalación con la copia vieja de Python y ffmpeg, **When** arranca la app, **Then**
   esa copia se borra.

### User Story 2 - Audios con tamaño máximo (Priority: P2)

**Acceptance Scenarios**:

1. **Given** un audio que supera el tamaño o la duración máximos, **When** llega, **Then** no se
   descarga y la respuesta dice el máximo.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: La app MUST usar solo el ffmpeg del sistema, buscado en las rutas de
  `Resources/herramientas.json`, y MUST NOT instalar ni descargar herramientas mientras corre.
- **FR-002**: Si falta ffmpeg, la app MUST decirlo con el comando de instalación, en la respuesta a
  la nota de voz y en Ajustes de la cuenta de contenido con video.
- **FR-003**: La app MUST borrar al arrancar la copia de Python y ffmpeg que instalaban las versiones
  anteriores.
- **FR-004**: Los audios que superen `maxAudioMegabytes` o `maxAudioSeconds` MUST rechazarse sin
  descargarlos; la descarga MUST cortarse si el archivo supera el máximo.
- **FR-005**: El README MUST listar ffmpeg como requisito.

## Success Criteria *(mandatory)*

- **SC-001**: Ningún camino del código ejecuta `pip`, `venv` ni descarga binarios.
- **SC-002**: Ningún audio mayor que el máximo se descarga a la Mac.
