---

description: "Tareas de implementación: arquitectura hexagonal"
---

# Tasks: Arquitectura hexagonal

## Paso 1: Dominio

- [x] T001 Mover `TextTools`, `Models`, `JobScreener`, `FreelanceClassifier` y `SearchProfile` a `HirebarDomain` (FR-001)
- [x] T002 Partir `Agents`, `Profile`, `ContentAccounts`, `Portals` y `Quotas` en entidades de dominio y almacenes (FR-001, FR-005)
- [x] T003 `ScriptAligner` y `WordTiming` al dominio, reescritos con tests de caracterización; `VoicePause` (FR-001, FR-005)
- [x] T004 `DomainPurityTests` (SC-001)

## Paso 2: Adaptadores

- [x] T005 `HirebarStorage` con los almacenes, `Paths`, `Config`, el Llavero (`KeychainSecretStore` sobre `Security.framework`, puerto `SecretStore`) y el estado de ejecución (FR-002)
- [x] T006 `HirebarTelegram` (con su cliente HTTP y el token inyectado) y `HirebarNotifications`; `Notifier` queda en el motor hasta el paso 3 (FR-002)
- [x] T007 `HirebarPortals` con `Net` (FR-002)
- [ ] T007b `HirebarAI` y `HirebarMedia`, junto con los casos de uso del paso 3 (FR-002)

## Paso 3: Casos de uso y composición

- [ ] T008 Casos de uso de lotes, comandos, programación y radares en `HirebarApplication` (FR-003)
- [ ] T009 Raíz de composición en `Hirebar`; sin `.shared` propios (FR-004, SC-002)
