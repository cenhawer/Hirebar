---
description: "Task list for Puntaje de vacantes en varias dimensiones"
---

# Tasks: Puntaje de vacantes en varias dimensiones

**Input**: Design documents from `specs/035-puntaje-vacantes/`

**Prerequisites**: plan.md, spec.md

**Tests**: incluidos, por principio de testing del proyecto (cada escenario de aceptación tiene test).

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup

- [ ] T001 Crear `Sources/HirebarDomain/JobScoreBreakdown.swift` con `DimensionScore`,
  `ScoreLevel` (`alto`/`medio`/`bajo`/`sinDatos`) y `JobScoreBreakdown`.
- [ ] T002 [P] Agregar sección `scoringWeights` (default 25/25/25/25) a
  `Resources/perfil-busqueda.json` y a su `schemaVersion`.

## Phase 2: Foundational

- [ ] T003 `Sources/HirebarStorage/SearchProfileStore.swift`: cargar `scoringWeights`, normalizar si
  no suman 100, devolver default si la sección no existe (FR-006, FR-007).
- [ ] T004 `Sources/HirebarDomain/JobScreener.swift`: nueva función `score(_:profile:weights:) ->
  JobScoreBreakdown`, llamada solo sobre vacantes que ya pasaron `screen()` (FR-001, FR-004).

**Checkpoint**: el cálculo de puntaje existe y es puro; ninguna historia de usuario depende de UI
todavía.

---

## Phase 3: User Story 1 - Ver por qué una vacante encaja o no (Priority: P1) 🎯 MVP

**Goal**: el mensaje de Telegram de cada vacante trae el desglose por dimensión.

**Independent Test**: fixtures fijas + `JobScreener.score` → desglose reproducible, sin red ni IA.

### Tests for User Story 1

- [ ] T005 [P] [US1] `Tests/HirebarDomainTests/JobScoreBreakdownTests.swift`: vacante `strong` → las
  4 dimensiones en `alto`/`medio`, nunca `bajo` (escenario 1).
- [ ] T006 [P] [US1] `Tests/HirebarDomainTests/JobScoreBreakdownTests.swift`: vacante `stretch` por
  años de experiencia → dimensión "experiencia" en `bajo`, las demás no se arrastran (escenario 2).
- [ ] T007 [P] [US1] `Tests/HirebarPortalsTests/JobScreenerTests.swift`: vacante rechazada por
  `screen()` (idioma/país/híbrida/tarjeta profesional) → nunca llega a `score()` (escenario 4,
  regresión de FR-004).

### Implementation for User Story 1

- [ ] T008 [US1] `Sources/HirebarApplication/AgentPrompts.swift`: agregar las 4 líneas de desglose
  al texto de la vacante, en el orden habilidades → experiencia → ubicación → alineación de carrera
  (escenario 3), sin quitar líneas existentes (FR-003).
- [ ] T009 [US1] `Resources/Localizable.xcstrings`: textos de cada nivel y nombre de cada dimensión;
  correr `scripts/strings.sh`.
- [ ] T010 [US1] Documentar en la guía de usuario qué significa cada nivel (FR-008).

**Checkpoint**: US1 funciona sola y es demostrable con una vacante de prueba.

---

## Phase 4: User Story 2 - Priorizar la lista del día (Priority: P2)

**Goal**: la lista del día llega ordenada por puntaje total.

**Independent Test**: 3 vacantes de prueba con puntaje 90/70/85 → llegan 90, 85, 70.

### Tests for User Story 2

- [ ] T011 [P] [US2] `Tests/HirebarUseCaseTests/RadarTests.swift`: orden descendente por puntaje
  total (escenario 1).
- [ ] T012 [P] [US2] `Tests/HirebarUseCaseTests/RadarTests.swift`: empate de puntaje → se conserva
  el orden de llegada del portal (escenario 2).

### Implementation for User Story 2

- [ ] T013 [US2] `Sources/HirebarApplication/JobRadar.swift`: ordenar por `JobScoreBreakdown.total`
  descendente antes de encolar, con `Fit.rank` y orden de llegada como criterios de empate (FR-005).
- [ ] T014 [US2] `Sources/HirebarApplication/FreelanceRadar.swift`: mismo criterio de orden
  (depende de T013 por el helper compartido si se extrae uno; si no, implementación paralela).

**Checkpoint**: US1 + US2 funcionan juntas sin romper la una a la otra.

---

## Phase 5: User Story 3 - Ajustar pesos sin tocar código (Priority: P3)

**Goal**: cambiar `perfil-busqueda.json` cambia el puntaje sin recompilar.

**Independent Test**: dos configuraciones de pesos sobre la misma vacante → puntaje total distinto
y consistente con el peso declarado.

### Tests for User Story 3

- [ ] T015 [P] [US3] `Tests/HirebarStorageTests/SearchProfileTests.swift`: pesos que no suman 100 se
  normalizan al cargar (escenario 2 de US3, FR-006).
- [ ] T016 [P] [US3] `Tests/HirebarDomainTests/JobScoreBreakdownTests.swift`: peso 0 en una dimensión
  → no afecta el total aunque su nivel sea `bajo` (escenario 1 de US3).

### Implementation for User Story 3

- [ ] T017 [US3] Confirmar que `score()` recibe los pesos ya normalizados por T003 y los aplica sin
  lógica de normalización duplicada en `HirebarDomain` (Domain no hace E/S, principio hexagonal).

**Checkpoint**: las 3 historias funcionan juntas; MVP completo de esta spec.

---

## Phase 6: Polish

- [ ] T018 [P] `scripts/coverage.sh` en verde con los targets tocados.
- [ ] T019 `scripts/lint.sh origin/develop` en verde.
- [ ] T020 Revisión de diff con `swift-code-reviewer` contra la constitución, `ARCHITECTURE.md` y
  esta spec, antes de abrir el PR a `develop` (regla de `AGENTS.md`).

## Dependencies & Execution Order

- Setup (T001-T002) sin dependencias.
- Foundational (T003-T004) depende de Setup; bloquea las 3 historias.
- US1 (T005-T010) puede empezar tras Foundational; es el MVP.
- US2 (T011-T014) depende de Foundational y de que `JobScoreBreakdown.total` exista (T001, T004);
  no depende de US1.
- US3 (T015-T017) depende de Foundational (T003); no depende de US1 ni US2.
- Polish depende de las historias que se decida entregar.
