# Feature Specification: Panel, Ajustes y funcionamiento general

**Feature Branch**: `docs/spec-009-panel-y-ajustes`

**Created**: 2026-11-05

**Status**: Draft

**Input**: Spec as-is transversal: describe la app en la barra de menú (ícono, panel y menú), la
ventana de Ajustes, el arranque, el programador de tareas y la limpieza semanal, en el commit base de
`develop`. Las desviaciones de la constitución se listan al final con la spec que las corrige.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ver de un vistazo qué está haciendo Hirebar (Priority: P1)

La persona hace clic en el maletín de la barra de menú y ve el estado de la IA, de Telegram y de cada
agente, cuándo vuelve a correr cada uno, y puede prenderlos, apagarlos o correrlos ya.

**Why this priority**: es la cara de la app en la Mac; sin el panel, todo se maneja desde Telegram.

**Independent Test**: con un modelo del panel alimentado por dobles de los agentes y la IA, el panel
muestra cada agente con su estado, su próxima ejecución y su interruptor.

**Acceptance Scenarios**:

1. **Given** la app abierta, **When** la persona hace clic en el maletín, **Then** se abre el panel;
   con clic derecho o Control+clic se abre el menú clásico.
2. **Given** el panel abierto, **When** se mira el encabezado, **Then** se ve la IA con un punto verde
   (en espera) o naranja (trabajando) y el estado de Telegram: el avión azul si está conectado; si no,
   el estado en palabras ("Telegram sin configurar", "Esperando tu hola", "El token ya no sirve"), que
   lleva a Ajustes → Telegram y avisos.
3. **Given** el panel, **When** se miran los agentes, **Then** aparecen en tres grupos ("Buscar
   trabajo": Empleo y Freelance; "Conseguir clientes": Clientes y Contenido; "Tú": Perfil y Analista),
   cada uno con ícono, nombre, descripción, próxima ejecución ("en pausa", "apagado", "trabajando", "en 5 min",
   "a pedido") e interruptor.
4. **Given** un agente, **When** la persona abre su detalle, **Then** ve su estado, los números de la
   semana, la casilla "Envío automático" (Empleo, Freelance y Clientes), el botón "Correr ahora"
   ("Regenerar HV" en Perfil, deshabilitado si está apagado) y el menú con portales, horario, cuentas
   de contenido y "Ajustes de <agente>…".
5. **Given** el panel abierto, **When** pasan 5 segundos, **Then** se actualiza solo.
6. **Given** el pie del panel, **When** la persona usa sus botones, **Then** abre los informes, el
   registro, la carpeta de datos, Ajustes o el menú del engranaje (Ajustes, cuentas de contenido,
   Telegram, abrir al iniciar sesión y salir).
7. **Given** la IA trabajando, **When** se mira el maletín, **Then** muestra un punto naranja y el
   texto de ayuda dice qué está haciendo.

---

### User Story 2 - Configurar los agentes sin editar archivos (Priority: P1)

La persona abre Ajustes y cambia, para cada agente, su nombre, descripción, si está prendido, el
envío automático, la frecuencia de búsqueda, los portales, el cupo diario y el horario de cada tarea.

**Why this priority**: es como la persona adapta los agentes a su rutina.

**Independent Test**: con un `agentes/<agente>.json` de prueba, editar y guardar en Ajustes deja el
archivo con los valores nuevos; Descartar lo deja como estaba.

**Acceptance Scenarios**:

1. **Given** Ajustes, **When** la persona abre la ventana, **Then** ve a la izquierda Agentes,
   Habilidades, Cuentas de contenido y Motor de IA.
2. **Given** un agente, **When** la persona cambia la frecuencia de búsqueda, **Then** puede elegir
   entre 15 y 240 minutos, de 5 en 5.
3. **Given** un agente con portales incluidos, **When** la persona apaga uno, **Then** deja de
   consultarse desde la búsqueda siguiente.
4. **Given** "Tus portales", **When** la persona agrega uno, **Then** indica nombre, enlace de una
   búsqueda ya filtrada e indicaciones opcionales; si falta el nombre o el enlace no empieza por
   `https://`, se le avisa.
5. **Given** una tarea, **When** la persona la edita, **Then** cambia los días (L M X J V S D), las
   horas ("8, 14") y la tolerancia en horas (1 a 48) si la Mac estaba dormida.
6. **Given** cambios sin guardar, **When** la persona pulsa Guardar o ⌘S, **Then** se aplican desde
   la búsqueda o tarea siguiente; con Descartar se deshacen; con Mostrar archivo se abre el JSON.

---

### User Story 3 - Que los agentes corran solos a su hora (Priority: P1)

Las tareas de cada agente corren a las horas y días configurados, una vez por horario, y si la Mac
estaba dormida corren al despertar dentro de su tolerancia.

**Why this priority**: sin esto, cada agente tendría que lanzarse a mano.

**Independent Test**: con un reloj de prueba, una tarea de las 9 h con 3 horas de tolerancia corre a
las 9, no corre otra vez a las 10 y corre a las 11 si a las 9 la Mac estaba dormida.

**Acceptance Scenarios**:

1. **Given** una tarea de un agente prendido, **When** llega su hora en uno de sus días, **Then**
   corre una sola vez para ese horario.
2. **Given** que la Mac estaba dormida a la hora de la tarea, **When** despierta dentro de la
   tolerancia, **Then** la tarea corre; si despierta después, no corre hasta el siguiente horario.
3. **Given** una tarea de portales propios sin portales activos, **When** llega su hora, **Then** no
   corre.
4. **Given** el domingo desde las 19 h o el lunes, **When** la IA está libre, **Then** corre una vez
   la limpieza semanal.

---

### User Story 4 - Arrancar listo y mantenerse limpio (Priority: P2)

Al abrir la app por primera vez se preparan las carpetas y archivos de partida; al actualizar, las
reglas que la persona no editó se actualizan solas; y cada semana se borra lo viejo.

**Why this priority**: evita trabajo manual al instalar y que los archivos crezcan sin control.

**Independent Test**: con una carpeta de datos vacía, el arranque crea las carpetas, copia las
plantillas y escribe los ajustes por defecto de cada agente; con archivos viejos, la limpieza los
recorta según su retención.

**Acceptance Scenarios**:

1. **Given** una instalación nueva, **When** la app arranca, **Then** crea la carpeta de datos, copia
   los archivos de `Resources/inicial/` que falten y escribe los ajustes por defecto de los agentes
   que no los tienen.
2. **Given** una regla que la persona no editó y una versión nueva en la app, **When** la app arranca,
   **Then** la regla se reemplaza por la nueva; si la persona la editó, se conserva.
3. **Given** la limpieza semanal, **When** corre, **Then** borra las ejecuciones de más de 30 días,
   las propuestas terminadas de más de 90, las semanas de métricas más allá de las últimas 26, los
   eventos de más de 180 días y los informes de más de un año; recorta el registro al pasar de 5 MB y
   los historiales al pasar de 3 MB, y anota qué hizo.
4. **Given** el menú, **When** la persona activa "Abrir al iniciar sesión", **Then** la app queda como
   elemento de inicio de sesión de macOS.

---

### Edge Cases

- El archivo de un agente tiene un error de formato: se usan sus valores por defecto.
- La IA está ocupada el domingo por la tarde: la limpieza espera hasta que quede libre, como máximo
  hasta el lunes.
- No se puede cambiar el inicio automático: se avisa con el error de macOS.
- Una tarea tiene varias horas el mismo día: cada hora cuenta como un horario distinto.

## Requirements *(mandatory)*

### Functional Requirements

**Barra de menú y panel**

- **FR-001**: El ícono MUST mostrar un punto verde con la IA libre y naranja con la IA trabajando, y
  un texto de ayuda con el estado.
- **FR-002**: Clic MUST abrir el panel; clic derecho o Control+clic MUST abrir el menú clásico, con
  las mismas acciones.
- **FR-003**: El panel MUST mostrar el estado de la IA y de Telegram, los seis agentes agrupados con su
  próxima ejecución e interruptor, y un detalle por agente con estado, números de la semana, envío
  automático, correr ahora y su menú.
- **FR-004**: El panel MUST actualizarse cada 5 segundos mientras está abierto.

**Ajustes**

- **FR-005**: Ajustes MUST tener páginas para cada agente, Habilidades, Cuentas de contenido y Motor
  de IA.
- **FR-006**: Cada agente MUST permitir editar nombre, descripción, prendido, envío automático,
  frecuencia de búsqueda (15 a 240 minutos), portales incluidos, portales propios, cupo diario (0 a
  100) y, por tarea, días, horas y tolerancia (1 a 48 horas).
- **FR-007**: Guardar (⌘S) MUST escribir `agentes/<agente>.json` y los archivos de la página;
  Descartar MUST recargar; Mostrar archivo MUST abrir el archivo de la página en Finder.

**Programador**

- **FR-008**: El programador MUST revisar cada minuto (la primera vez 2 minutos después de arrancar)
  qué tareas de agentes prendidos están en su horario y lanzar cada horario una sola vez por día.
- **FR-009**: Un horario MUST seguir vigente desde su hora hasta su tolerancia (1 hora por defecto),
  incluso si empezó el día anterior.
- **FR-010**: El panel y `agentes` MUST mostrar la próxima ejecución de cada agente.

**Arranque y limpieza**

- **FR-011**: Al arrancar, la app MUST crear las carpetas, copiar las plantillas que faltan,
  reemplazar las reglas no editadas por la persona cuando hay versión nueva (comparando su huella con
  las versiones anteriores conocidas), escribir los ajustes por defecto que falten e iniciar la IA,
  Telegram, las búsquedas y el programador.
- **FR-012**: La app MUST pedirle a macOS que no la suspenda mientras está abierta, sin impedir que la
  Mac duerma.
- **FR-013**: La limpieza semanal MUST aplicar las retenciones de la historia 4, escenario 3.
- **FR-014**: "Abrir al iniciar sesión" MUST registrar o quitar la app como elemento de inicio de
  sesión.

### Key Entities

- **Ajustes del agente (AgentSettings)** y **Tarea (AgentTask)**: modo, horas, días y tolerancia.
- **Horario cumplido**: marca por tarea, día y hora en `UserDefaults` (`sched.*`).
- **Plantilla**: archivo de `Resources/inicial/` y las huellas de sus versiones anteriores.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Cada horario de una tarea corre como máximo una vez.
- **SC-002**: Una tarea cuyo horario cae con la Mac dormida corre al despertar si está dentro de la
  tolerancia.
- **SC-003**: Una regla editada por la persona nunca se reemplaza al actualizar la app.
- **SC-004**: Un cambio guardado en Ajustes aplica en la siguiente búsqueda o tarea, sin reiniciar.
- **SC-005**: Ningún archivo que recorta la limpieza pasa de su tamaño máximo después de ella.

## Assumptions

- La app vive en `~/Applications` y se instala con `scripts/bundle.sh --install`.
- La persona usa una sola Mac con Hirebar.
- Los valores numéricos de esta spec son los del código actual; la spec
  `024-textos-y-valores-fuera-del-codigo` los lleva a configuración.

## Divergencias con la constitución

| Comportamiento actual | Principio | Se corrige en |
|---|---|---|
| La configuración inicial (Telegram, IA, perfil, permisos) son pasos sueltos en el README y en menús, sin asistente | V | `025-asistente-primer-uso` |
| Los horarios cumplidos se guardan en `UserDefaults` | IV | `022-version-datos` |
| Las retenciones de la limpieza no cubren grabaciones de voz, borradores descartados ni listas de correos descartadas | IV | `029-politica-datos` |
| Textos de la interfaz, retenciones, rangos y huellas de versiones escritos en el código | VI | `024-textos-y-valores-fuera-del-codigo` |
| `PanelModel` y `SettingsModel` usan `ObservableObject` | Restricciones técnicas | `018-macos-26-swift-6` |
| El panel, Ajustes y el programador no tienen tests | VII | `019-tests-engine` |

## Hallazgos sin principio asociado

- El estado se comunica solo con color (puntos verde y naranja, avión azul o gris). Se resuelve en
  `030-accesibilidad`.
- El panel lee los archivos de configuración en cada refresco y por cada agente (anti-patrón de
  `AGENTS.md`). Se resuelve en `031-panel-uso`.
- La app no detiene la ejecución en curso al salir; la recupera al volver a abrir. Se resuelve en
  `017-arquitectura-hexagonal`.
- En la fila de cada agente, tocar la fila, el interruptor y la flecha comparten la misma zona: es
  fácil apagar un agente queriendo abrir su detalle. Se resuelve en `031-panel-uso`.
