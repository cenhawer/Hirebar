# Feature Specification: Puntaje de vacantes en varias dimensiones

**Feature Branch**: `feature/HB-035-puntaje-vacantes`

**Created**: 2026-11-18

**Status**: Draft

**Input**: Idea tomada de `ai-job-search-dev/ai-job-search`: ese proyecto puntúa cada vacante en
cinco dimensiones (habilidades, experiencia, cultura, ubicación y alineación de carrera) en vez de
solo aceptar o rechazar. Hirebar hoy solo tiene `Fit` (`ENCAJA`/`RETO`) desde `JobScreener.classify`.
Esta spec lleva esa idea a Hirebar sin romper lo que ya funciona.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ver por qué una vacante encaja o no (Priority: P1)

Cuando Empleo manda una vacante a Telegram, la persona ve, además de `ENCAJA`/`RETO`, un desglose de
puntaje por dimensión (habilidades, experiencia, ubicación, alineación de carrera) para entender de
un vistazo si vale la pena postular o si el "RETO" es por una sola cosa (ej. le faltan 2 años de
experiencia) en vez de tener que leer la vacante completa.

**Why this priority**: es el cambio que la persona realmente pidió ver: la lista de vacantes de hoy
no dice *por qué* algo quedó en "RETO", solo que quedó.

**Independent Test**: con vacantes de prueba fijas y un `JobProfile` fijo, `JobScreener` produce un
puntaje por dimensión reproducible sin red ni IA; el mensaje de Telegram de prueba contiene las
cuatro líneas de desglose.

**Acceptance Scenarios**:

1. **Given** una vacante que pasa el filtro actual con `Fit.strong`, **When** se califica,
   **Then** cada dimensión queda en `alto` o `medio`, nunca en `bajo`.
2. **Given** una vacante que hoy queda en `Fit.stretch` por años de experiencia, **When** se
   califica, **Then** la dimensión "experiencia" queda en `bajo` y las demás reflejan su propio
   puntaje, no se arrastra un solo número global.
3. **Given** el mensaje que llega a Telegram por una vacante, **When** la persona lo lee,
   **Then** ve una línea por dimensión con su nivel, en el orden habilidades → experiencia →
   ubicación → alineación de carrera.
4. **Given** una vacante ya rechazada hoy por `JobScreener.screen` (idioma, país, híbrida, tarjeta
   profesional), **When** se evalúa, **Then** ni siquiera se califica por dimensiones: el rechazo
   determinista sigue siendo el primer filtro y no cambia.

---

### User Story 2 - Priorizar la lista cuando hay varias vacantes el mismo día (Priority: P2)

Cuando llegan varias vacantes el mismo día, la persona las ve ordenadas por puntaje total en vez de
por orden de llegada del portal, para revisar primero las que más encajan.

**Why this priority**: con el filtro binario de hoy, dos vacantes "ENCAJA" pueden tener encaje muy
distinto y la persona no tiene forma de priorizar sin leer las dos completas.

**Independent Test**: con tres vacantes de prueba de puntaje total distinto, la lista que llega a
Telegram las trae en orden descendente de puntaje total, con empate roto por `Fit.rank` como hoy.

**Acceptance Scenarios**:

1. **Given** tres vacantes `strong` con puntaje total 90, 70 y 85, **When** se manda la lista del
   día, **Then** llegan en el orden 90, 85, 70.
2. **Given** dos vacantes con el mismo puntaje total, **When** se ordenan, **Then** se usa el orden
   de llegada del portal como criterio de empate, igual que hoy.

---

### User Story 3 - Ajustar el peso de cada dimensión sin tocar código (Priority: P3)

La persona cambia qué tanto pesa cada dimensión (por ejemplo, darle más peso a ubicación que a
alineación de carrera) editando `Resources/perfil-busqueda.json`, sin que Hirebar necesite una
actualización.

**Why this priority**: evita hardcodear los pesos, y encaja con la convención ya existente del
proyecto de que umbrales y catálogos de dominio viven en configuración, no en código
(`Resources/perfil-busqueda.json`, constitución, principio VI).

**Independent Test**: con dos configuraciones de pesos distintas sobre la misma vacante de prueba,
el puntaje total cambia de forma consistente con el peso declarado, sin reconstruir el binario.

**Acceptance Scenarios**:

1. **Given** un peso de 0 para la dimensión "alineación de carrera", **When** se califica una
   vacante, **Then** esa dimensión no afecta el puntaje total aunque su nivel sea "bajo".
2. **Given** pesos que no suman 100, **When** Hirebar carga `perfil-busqueda.json`, **Then** los
   normaliza antes de calificar, sin fallar ni pedir que el archivo sea editado a mano para que
   sumen exacto.

---

### Edge Cases

- ¿Qué pasa con una vacante sin información suficiente para una dimensión (ej. no menciona
  ubicación)? → esa dimensión se marca como "sin datos" y no resta ni suma al puntaje total; se
  excluye del promedio ponderado.
- ¿Qué pasa si las cuatro dimensiones quedan en "bajo" pero `JobScreener.classify` la clasificó como
  `stretch` por las reglas actuales de stack? → se muestra igual el desglose junto al `Fit` actual;
  el desglose es informativo, no sustituye el filtro determinista existente (ver US1 escenario 4).
- ¿Qué pasa si `perfil-busqueda.json` no trae la sección de pesos nueva (instalación existente antes
  de esta feature)? → se usan pesos por defecto iguales para las cuatro dimensiones, documentados en
  la guía, sin requerir migración de datos personales.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `HirebarDomain` MUST calcular un puntaje por dimensión (habilidades, experiencia,
  ubicación, alineación de carrera) para cada vacante que haya pasado el filtro determinista de
  `JobScreener.screen`, usando únicamente datos ya disponibles en el texto de la vacante y el
  `JobProfile` de la persona — sin llamar a la IA ni a red.
- **FR-002**: El puntaje por dimensión MUST expresarse en tres niveles (`alto`, `medio`, `bajo`) más
  un valor "sin datos" cuando la vacante no menciona esa dimensión.
- **FR-003**: El mensaje de Telegram de cada vacante MUST incluir el desglose por dimensión además
  del `Fit` (`ENCAJA`/`RETO`) que ya muestra hoy, sin quitar ninguna línea existente.
- **FR-004**: El rechazo determinista de `JobScreener.screen` (idioma, país, modalidad, tarjeta
  profesional, años tope) MUST seguir aplicándose antes de calificar por dimensiones; una vacante
  rechazada no se califica.
- **FR-005**: Cuando el mismo día hay más de una vacante para un agente, Hirebar MUST ordenarlas por
  puntaje total descendente antes de mandarlas, con el orden de llegada del portal como criterio de
  empate.
- **FR-006**: El peso de cada dimensión en el puntaje total MUST vivir en
  `Resources/perfil-busqueda.json`, no en código, y Hirebar MUST normalizar los pesos si no suman
  100 al cargarlos.
- **FR-007**: Si `perfil-busqueda.json` no trae la sección de pesos, Hirebar MUST usar un peso igual
  para las cuatro dimensiones sin fallar ni requerir migración de datos existentes.
- **FR-008**: La guía de usuario MUST documentar qué significa cada nivel y cómo ajustar los pesos.

### Key Entities

- **DimensionScore**: una dimensión (`skills`, `experience`, `location`, `careerFit`), su nivel
  (`alto`/`medio`/`bajo`/`sinDatos`) y el texto breve que explica por qué quedó ahí.
- **JobScoreBreakdown**: lista de `DimensionScore` de una vacante más el puntaje total ya ponderado,
  calculado junto al `Fit` existente, nunca en lugar de él.
- **ScoringWeights**: los cuatro pesos declarados en `Resources/perfil-busqueda.json`, cargados y
  normalizados por `HirebarStorage` antes de llegar a `HirebarDomain`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El 100% de las vacantes `strong` o `stretch` que llegan a Telegram incluyen las cuatro
  líneas de desglose, verificable con tests de `HirebarDomain` sobre fixtures fijas.
- **SC-002**: Cambiar los pesos en `perfil-busqueda.json` cambia el orden de una lista de prueba de
  tres vacantes sin recompilar, verificable con un test de integración que carga dos configuraciones
  distintas.
- **SC-003**: Ninguna vacante que `JobScreener.screen` rechaza hoy pasa a calificarse por
  dimensiones: cobertura de regresión sobre los fixtures de rechazo existentes en
  `Tests/Fixtures/portals/`.

## Assumptions

- El cálculo de dimensiones es determinista (reglas sobre el texto normalizado y el `JobProfile`),
  igual que `JobScreener` hoy; no se agrega una llamada nueva a la IA para calificar, por el
  principio V (sin dependencias ocultas) y para no sumar costo de tokens por vacante.
- "Alineación de carrera" se aproxima con el stack y los catálogos ya presentes en `JobProfile`
  (`ownStack`, `strong`, `generic`, `weak`), no con un modelo nuevo de carrera que no existe hoy en
  el dominio.
- Esta spec no cambia `Fit`/`JobScreener.classify` ni los mensajes de rechazo: solo agrega
  información a lo que ya pasa el filtro.
