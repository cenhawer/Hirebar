# Feature Specification: Tests del motor

**Feature Branch**: `feature/HB-019-tests-engine`

**Created**: 2026-11-10

**Status**: Draft

**Input**: Constitución, principio VII. El programador, los comandos, el `Controller` y los radares
tenían poca o ninguna cobertura, y el flujo de la nota de voz no se probaba.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Programador probado con un reloj controlado (Priority: P1)

**Independent Test**: los tests avanzan un reloj de prueba y disparan el tic del programador sin
esperar tiempo real.

**Acceptance Scenarios**:

1. **Given** una tarea en su hora, **When** el reloj hace tic dos veces, **Then** corre una sola vez.
2. **Given** una tarea fuera de su hora o un agente apagado, **When** hay tic, **Then** no corre.
3. **Given** una revisión de portales propios sin portales, **When** llega su hora, **Then** se salta.
4. **Given** el domingo después de las 19 h, **When** el motor está libre, **Then** la limpieza
   semanal corre una vez; si el motor está ocupado, espera a que termine.

### User Story 2 - Comandos de Telegram probados de punta a punta (Priority: P1)

**Acceptance Scenarios**:

1. **Given** un mensaje de otra cuenta, **When** llega, **Then** se ignora.
2. **Given** la persona dueña del bot, **When** escribe `estado`, `informe`, `anota`, `no`, `si` o
   `logro`, **Then** recibe el estado, arranca el informe, se anota, se descarta la lista, se ejecuta
   la lista con perfil de ejecución o se encola el cambio de perfil.
3. **Given** un texto que no es un comando, **When** llega, **Then** responde con la ayuda.

### User Story 3 - Flujo de la nota de voz (Priority: P1)

**Acceptance Scenarios**:

1. **Given** una cuenta con video esperando voz, **When** llega una nota de voz, **Then** se descarga,
   se arma el video, se envía y se pregunta si se publica.
2. **Given** una descarga fallida, **When** termina, **Then** se pide reenviar el audio.
3. **Given** ningún video esperando voz o un audio demasiado largo, **When** llega la nota, **Then**
   se explica qué hacer sin descargarla.

### User Story 4 - Corridas de la IA y radares (Priority: P2)

**Acceptance Scenarios**:

1. **Given** dos tareas, **When** se piden, **Then** la segunda espera a que termine la primera y la
   misma tarea no se encola dos veces.
2. **Given** una corrida fallida, con la sesión vencida o más larga que el límite, **When** termina o
   vence el plazo, **Then** queda como fallida, se explica cómo volver a iniciar sesión o se detiene.
3. **Given** un portal con hallazgos, **When** el radar revisa, **Then** arma la lista pendiente,
   recuerda lo visto y no vuelve a avisar lo mismo; empleo prefiere lo fuerte sobre lo de reto.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Los tests MUST correr sin red, IA, Chrome ni Telegram reales, con dobles de los puertos.
- **FR-002**: El estado de corrida MUST ir en memoria en los tests (`MemoryRunState`), nunca en
  `UserDefaults`.
- **FR-003**: El reloj de prueba MUST permitir disparar los tics y vencer plazos sin esperar.
- **FR-004**: El programador MUST calcular la próxima corrida con el reloj inyectado.

## Success Criteria *(mandatory)*

- **SC-001**: Cada escenario de aceptación tiene al menos un test.
- **SC-002**: `Scheduler` y los radares superan el 60 % de cobertura de líneas; la cobertura total
  sube y `.coverage-minimum` se ajusta a la medida.
