---
description: "Task list for Preparación de entrevista"
---

# Tasks: Preparación de entrevista

**Input**: Design documents from `specs/037-preparacion-entrevistas/`

**Prerequisites**: plan.md, spec.md

**Tests**: incluidos.

## Phase 1: Setup

- [ ] T001 Crear `Sources/HirebarDomain/InterviewPackage.swift` con `InterviewPackage`,
  `InterviewQuestion` (categoría + texto) e `InterviewSimulation`.
- [ ] T002 [P] Agregar claves `interviewPrep`: `["entrevista"]` e `interviewSim`:
  `["simula entrevista"]` a `Resources/comandos.json`.

## Phase 2: Foundational

- [ ] T003 `Sources/HirebarApplication/CommandParser.swift`: reconocer `entrevista <id>` y `simula
  entrevista <id>` (FR-001, FR-006).
- [ ] T004 `Sources/HirebarStorage/FileRepositories.swift`: leer/escribir `entrevistas/<id>.md`
  junto a los repositorios de postulaciones ya existentes.

**Checkpoint**: los comandos se reconocen y hay dónde guardar; ninguna historia depende de IA
todavía.

---

## Phase 3: User Story 1 - Paquete de preparación (Priority: P1) 🎯 MVP

**Goal**: `entrevista <id>` entrega un documento completo sin enviar ni postular nada.

**Independent Test**: vacante registrada + doble de `AIRunner` en modo lectura → archivo en
`entrevistas/<id>.md` y resumen en Telegram.

### Tests for User Story 1

- [ ] T005 [P] [US1] `Tests/HirebarUseCaseTests/CommandFlowTests.swift`: `entrevista <id>` con
  postulación existente → documento generado sin acciones de envío (escenario 1).
- [ ] T006 [P] [US1] `Tests/HirebarApplicationTests/CommandParserTests.swift`: `entrevista` sin id y
  una sola postulación activa → se usa esa sola (escenario 3).
- [ ] T007 [P] [US1] `Tests/HirebarApplicationTests/CommandParserTests.swift`: `entrevista` sin id y
  varias activas → pide especificar, sin generar nada (escenario 4, FR-004).
- [ ] T008 [P] [US1] `Tests/HirebarUseCaseTests/CommandFlowTests.swift`: identificador que no
  coincide con nada → aviso, sin documento inventado (escenario 5, FR-005).

### Implementation for User Story 1

- [ ] T009 [US1] `Sources/HirebarApplication/AgentPrompts.swift`: `interviewPrepPrompt(_:)` con
  vacante, perfil y, si el motor lo soporta, revisión pública de la empresa (FR-003).
- [ ] T010 [US1] `Sources/HirebarApplication/Controller.swift`: orquestar el modo `interviewPrep`
  con `RunProfile` restringido a `entrevistas/` (FR-002).
- [ ] T011 [US1] `Sources/HirebarApplication/ControllerInbox.swift`: resolver ambigüedad de
  postulación activa (FR-004).
- [ ] T012 [US1] `Resources/Localizable.xcstrings`: textos del resumen y los avisos; correr
  `scripts/strings.sh`.

**Checkpoint**: US1 funciona sola y es demostrable.

---

## Phase 4: User Story 2 - Simular entrevista (Priority: P2)

**Goal**: ronda de preguntas/respuestas por Telegram sobre un paquete ya generado.

**Independent Test**: paquete existente + doble de `AIRunner` → 3 turnos de pregunta/respuesta y
comentario final, sin acciones de envío.

### Tests for User Story 2

- [ ] T013 [P] [US2] `Tests/HirebarUseCaseTests/CommandFlowTests.swift`: `simula entrevista <id>`
  sin paquete previo → aviso de que falta generarlo primero (edge case de spec, FR-006).
- [ ] T014 [P] [US2] `Tests/HirebarUseCaseTests/ControllerRunTests.swift`: intercambio de 3
  pregunta/respuesta → siguiente pregunta o comentario final al agotarse (escenario 2).
- [ ] T015 [P] [US2] `Tests/HirebarUseCaseTests/ControllerRunTests.swift`: comando `termina` a mitad
  de la simulación → cierre con comentario de lo respondido (escenario 3, FR-008).

### Implementation for User Story 2

- [ ] T016 [US2] `Sources/HirebarApplication/AgentPrompts.swift`: `interviewTurnPrompt(_:)` por
  pregunta, con el historial de respuestas de esa simulación.
- [ ] T017 [US2] `Sources/HirebarApplication/Controller.swift`: estado efímero de
  `InterviewSimulation` en curso; una sola simulación activa a la vez (FR-007).
- [ ] T018 [US2] `Sources/HirebarApplication/CommandParser.swift`: comando `termina` dentro de una
  simulación activa (FR-008).

**Checkpoint**: US1 + US2 funcionan juntas; MVP completo de esta spec.

---

## Phase 5: Polish

- [ ] T019 [P] Confirmar que ni la preparación ni la simulación afectan `PlatformQuota` (SC-002);
  test de regresión en `Tests/HirebarApplicationTests/`.
- [ ] T020 [P] `scripts/coverage.sh` en verde.
- [ ] T021 `scripts/lint.sh origin/develop` en verde.
- [ ] T022 Revisión de diff con `swift-code-reviewer` contra la constitución y esta spec antes del
  PR a `develop`.

## Dependencies & Execution Order

- Setup (T001-T002) sin dependencias.
- Foundational (T003-T004) depende de Setup; bloquea las 2 historias.
- US1 (T005-T012) es el MVP; depende solo de Foundational.
- US2 (T013-T018) depende de que `InterviewPackage` exista y se pueda generar (T001, T009-T010 de
  US1): un paquete previo es prerrequisito funcional declarado en FR-006, no solo de implementación.
- Polish depende de las historias que se decida entregar.
