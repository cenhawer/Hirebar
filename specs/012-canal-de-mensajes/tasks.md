---

description: "Tareas de implementación: canal de mensajes"
---

# Tasks: Canal de mensajes

**Input**: Design documents from `/specs/012-canal-de-mensajes/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: obligatorios (constitución, principio VII).

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup

- [x] T001 Actualizar `ARCHITECTURE.md`: dueño del canal, guardián, vinculación, notificaciones de macOS en lugar de ntfy.sh y `Resources/canal.json` (FR-004, FR-007, FR-010)
- [x] T002 [P] `Resources/canal.json`, copiado por `scripts/bundle.sh` y validado en CI (FR-010)

## Phase 2: Foundational

- [x] T003 [P] `ChannelOwner` y `ChannelSender` en `Sources/HirebarDomain/ChannelOwner.swift`
- [x] T004 [P] `ChannelGuard` en `Sources/HirebarApplication/ChannelGuard.swift` con tests (FR-004, FR-005)
- [x] T005 [P] `ChannelPairing` en `Sources/HirebarApplication/ChannelPairing.swift` con tests (FR-002)
- [x] T006 Remitente, fecha y tipo de chat en `Telegram.parse`, `getMe` y borrar el token en `Sources/HirebarCore/Telegram.swift`, con tests de parseo (FR-001, FR-004)
- [x] T007 `channelOwner` en `Config` con migración del `chatId` y sin `ntfyTopic`, con tests (FR-006, FR-008)

## Phase 3: User Story 1 - Anclar el bot (P1)

- [x] T008 [US1] `ChannelSetup` en `Sources/HirebarEngine/ChannelSetup.swift`: comprobar token, empezar, proponer, confirmar, descartar y vencer la vinculación (FR-001, FR-002, FR-003)
- [x] T009 [US1] Sección "Telegram y avisos" en `Sources/Hirebar/ChannelSettingsView.swift` y página en `Settings.swift` (FR-009)

## Phase 4: User Story 2 - Bot cerrado (P1)

- [x] T010 [US2] El guardián decide antes de cada mensaje y botón en `Sources/HirebarEngine/Commands.swift`; sin vinculación por primer mensaje (FR-004, FR-005)
- [x] T011 [US2] Tests de mensajes de otra cuenta, grupo, botón ajeno y límite por minuto

## Phase 5: User Story 3 - Avisos en la Mac (P2)

- [x] T012 [US3] `MacNotifications` y `Notifier` sin ntfy; respaldo cuando falla un envío (FR-007, FR-008)
- [x] T013 [US3] El delegado de notificaciones abre el panel en `Sources/Hirebar/AppDelegate.swift` (FR-007)

## Phase 6: User Story 4 - Estado a la vista (P2)

- [x] T014 [US4] Estado del canal en `PanelModel`, `PanelView` y `StatusMenu`, con el botón a la sección (FR-009)

## Phase 7: Polish

- [x] T015 [P] README, `GUIA.md` (crear el bot y vincularlo), `CHANGELOG.md`; specs `008` y `009` al producto actual
- [x] T016 `swift-code-reviewer` y `/security-review` sobre el diff; resolver cada hallazgo
