---

description: "Tareas de implementación: confirmar el envío automático"
---

# Tasks: Confirmar el envío automático

**Input**: Design documents from `/specs/011-confirmar-envio-automatico/`

**Tests**: obligatorios (constitución, principio VII).

## Phase 1: User Story 1 - Saber qué se prende antes de prenderlo (P1)

- [x] T001 [US1] `AutoSend` con los agentes, la explicación y el registro en `Sources/HirebarEngine/AutoSend.swift` (FR-002, FR-004, FR-005)
- [x] T002 [US1] `auto … si` pregunta con botones; `autoon` prende y `autocancel` no cambia nada, en `Sources/HirebarEngine/Commands.swift` (FR-001, FR-003)
- [x] T003 [US1] Diálogo de confirmación en el panel, el menú y al guardar Ajustes (FR-001, FR-003)
- [x] T004 [US1] Tests de Telegram, agentes sin envío automático, detección en Ajustes y apagado sin pregunta
- [x] T005 `GUIA.md`, `CHANGELOG.md`, `ARCHITECTURE.md` §4.2 y spec `001`/`002`/`003` al producto actual
- [ ] T006 `swift-code-reviewer` sobre el diff
