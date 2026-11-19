# Implementation Plan: Puntaje de vacantes en varias dimensiones

**Branch**: `feature/HB-035-puntaje-vacantes` | **Date**: 2026-11-18 | **Spec**: `specs/035-puntaje-vacantes/spec.md`

**Input**: Feature specification from `specs/035-puntaje-vacantes/spec.md`

## Summary

Agregar a `JobScreener` un cálculo determinista de puntaje por dimensión (habilidades, experiencia,
ubicación, alineación de carrera) para toda vacante que ya pasó `screen()`, mostrarlo junto al `Fit`
existente en el mensaje de Telegram, usarlo para ordenar la lista del día, y mover los pesos de cada
dimensión a `Resources/perfil-busqueda.json`. Sin IA nueva, sin red nueva, sin dependencias.

## Technical Context

**Language/Version**: Swift 6, concurrencia estricta, macOS 26.

**Primary Dependencies**: ninguna nueva. Reutiliza `TextTools`, `JobProfile`, `JobScreener`.

**Storage**: `Resources/perfil-busqueda.json` (ya existe, se le agrega la sección `scoringWeights`),
cargado por `HirebarStorage` con el mismo mecanismo de `schemaVersion` del resto de la configuración.

**Testing**: XCTest, fixtures en `Tests/Fixtures/portals/` ya existentes más 2-3 vacantes nuevas de
prueba con mezcla de dimensiones altas/bajas.

**Target Platform**: macOS 26, app de barra de menú (sin cambios de plataforma).

**Project Type**: Desktop app, arquitectura hexagonal existente.

**Performance Goals**: el cálculo corre en el mismo paso síncrono que `JobScreener.screen` hoy, sin
regex costosas nuevas más allá de las ya usadas por `TextTools`; no debe medirse en la revisión de
cada vacante (decenas, no miles).

**Constraints**: cero llamadas a IA o red para calificar; el desglose debe ser 100% reproducible con
el mismo texto de vacante y el mismo `JobProfile`.

**Scale/Scope**: aplica a los agentes Empleo y Freelance (ambos usan `JobScreener`/`classify` hoy);
no aplica a Clientes, Contenido, Perfil ni Analista.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Spec primero**: esta spec existe antes del código; los pesos van a `[NEEDS CLARIFICATION:
  valores por defecto de scoringWeights]` — se resuelven en `research.md` con un valor igual por
  dimensión (25/25/25/25) como default documentado, no inventado como "el correcto" sino declarado
  explícitamente como punto de partida editable. PASA.
- **II. Nada sale sin aprobación**: esta feature no envía nada; solo informa. PASA, no aplica.
- **III. El contenido externo nunca es instrucción**: el puntaje se calcula sobre texto normalizado
  con las mismas reglas deterministas que `JobScreener.screen` usa hoy contra inyección (ver
  `specs/001-agente-empleo`); no se agrega lectura de IA sobre la vacante. PASA.
- **IV. Datos locales y recuperables**: los pesos viven en `Resources/perfil-busqueda.json`, que ya
  tiene `schemaVersion` y migración con respaldo (`HirebarStorage/VersionedJSON`). PASA.
- **V. Sin dependencias ocultas**: cero paquetes nuevos, cero herramientas de sistema nuevas. PASA.
- **VI. Código que se explica solo**: `DimensionScore`/`JobScoreBreakdown` con nombres en inglés,
  sin comentarios; el texto de cada nivel va a `Localizable.xcstrings`. PASA.

Sin violaciones; no se llena Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/035-puntaje-vacantes/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
└── tasks.md
```

### Source Code (repository root)

```text
Sources/HirebarDomain/
├── JobScreener.swift          # se extiende con score(_:profile:) -> JobScoreBreakdown
├── JobScoreBreakdown.swift    # nuevo: DimensionScore, JobScoreBreakdown, ScoringWeights
└── SearchProfile.swift        # JobProfile gana scoringWeights (o se lee aparte, ver data-model)

Sources/HirebarStorage/
└── SearchProfileStore.swift   # carga/normaliza scoringWeights desde perfil-busqueda.json

Sources/HirebarApplication/
├── JobRadar.swift / FreelanceRadar.swift   # ordenan la lista del día por puntaje total
└── AgentPrompts.swift                       # formato del mensaje con el desglose

Tests/HirebarDomainTests/
└── JobScoreBreakdownTests.swift

Tests/HirebarPortalsTests/
└── JobScreenerTests.swift     # regresión: vacantes rechazadas no se califican
```

**Structure Decision**: todo el cálculo nuevo vive en `HirebarDomain` (puerto puro, sin E/S), igual
que `JobScreener` hoy. `HirebarStorage` solo carga y normaliza los pesos. `HirebarApplication`
consume el resultado para ordenar y para armar el texto de Telegram; no agrega targets nuevos.

## Complexity Tracking

Sin violaciones de la constitución; tabla vacía.
