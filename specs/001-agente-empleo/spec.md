# Feature Specification: Agente Empleo

**Feature Branch**: `docs/spec-001-agente-empleo`

**Created**: 2026-11-05

**Status**: Draft

**Input**: Spec as-is: describe lo que el agente Empleo hace hoy en el commit base de `develop`, para
que sirva de referencia contra regresiones. Las desviaciones de la constitución se listan al final
con la spec que las corrige.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Recibir vacantes que encajan con el perfil (Priority: P1)

La persona quiere enterarse por Telegram, cada pocos minutos, de las vacantes remotas recién
publicadas en los portales incluidos que encajan con sus habilidades, sin revisar los portales a
mano y sin ver lo que no le sirve.

**Why this priority**: es la razón de ser del agente; sin esto no hay nada que aprobar ni postular.

**Independent Test**: con fixtures de las páginas de cada portal y un perfil de prueba, una búsqueda
produce una lista con las vacantes que pasan los filtros y ninguna de las que no.

**Acceptance Scenarios**:

1. **Given** el agente prendido y al menos un portal incluido activo, **When** se cumple el intervalo
   de búsqueda, **Then** se consultan solo los portales activos y se avisa una lista por Telegram si
   algo pasó los filtros.
2. **Given** una vacante cuyo título contiene una palabra bloqueada o una habilidad en nivel "evito",
   **When** se busca, **Then** no aparece en la lista.
3. **Given** una vacante cuyo título coincide con una habilidad en nivel "domino", **When** se busca,
   **Then** aparece marcada ENCAJA.
4. **Given** una vacante cuyo título solo coincide con habilidades en nivel "conozco" o términos
   débiles, **When** se busca, **Then** aparece marcada RETO.
5. **Given** que en una búsqueda hay vacantes ENCAJA, **When** se arma la lista, **Then** se avisan
   como máximo 6 y solo vacantes ENCAJA.
6. **Given** que en una búsqueda solo hay vacantes RETO, **When** se arma la lista, **Then** se
   avisan como máximo 2.
7. **Given** una vacante que ya se revisó en una búsqueda anterior, **When** se vuelve a buscar dentro
   de los 21 días siguientes, **Then** no se vuelve a avisar.
8. **Given** una búsqueda en la que nada pasó los filtros, **When** termina, **Then** no se envía
   nada por Telegram y el panel muestra "nada nuevo".

---

### User Story 2 - Aprobar la lista y que la IA postule (Priority: P1)

La persona responde a la lista desde Telegram y la IA postula a las vacantes elegidas con su Chrome,
usando la hoja de vida que mejor encaja, y le reporta el resultado.

**Why this priority**: convierte los avisos en postulaciones, que es el resultado que busca la persona.

**Independent Test**: con un doble de `AIRunner` y de `Messenger`, aprobar una lista arma una
ejecución con exactamente las vacantes elegidas y publica en Telegram el resumen que devuelve la IA.

**Acceptance Scenarios**:

1. **Given** una lista pendiente de menos de 24 horas, **When** la persona responde `si` o pulsa
   "Sí, postular a todas", **Then** la lista pasa a "en curso", se quitan los botones del mensaje y
   la IA recibe todas sus vacantes.
2. **Given** una lista pendiente, **When** la persona responde `si 1 3`, **Then** la IA recibe solo
   las vacantes 1 y 3.
3. **Given** una lista pendiente, **When** la persona responde `si 9` y la lista tiene 4 vacantes,
   **Then** se le responde que los números van del 1 al 4 y no se ejecuta nada.
4. **Given** una lista pendiente, **When** la persona responde `no` o pulsa "No", **Then** la lista
   queda descartada.
5. **Given** que no hay listas pendientes de las últimas 24 horas, **When** la persona responde `si`,
   **Then** se le responde que no hay listas pendientes.
6. **Given** que la IA está ejecutando otra lista, **When** la persona aprueba una nueva, **Then**
   la nueva queda en cola y se le avisa que sigue después.
7. **Given** el envío automático del agente prendido, **When** una búsqueda produce una lista,
   **Then** se aprueba sola completa y el aviso lo indica.
8. **Given** una ejecución terminada, **When** la IA responde, **Then** su texto llega a Telegram con
   el estado de cada vacante (ENVIADA, PENDIENTE o DESCARTADA con motivo) y queda registrado en
   `postulaciones.md`.

---

### User Story 3 - Revisar los portales que agregó la persona (Priority: P2)

La persona agrega portales que Hirebar no trae (por ejemplo, la página de empleos de una empresa) y
la IA los revisa con su Chrome tres veces al día, le muestra lo que encontró y solo postula si lo
aprueba.

**Why this priority**: amplía la cobertura sin escribir un adaptador por portal.

**Independent Test**: con un doble de `AIRunner` que deja hallazgos fijos, la tarea produce una lista
pendiente con esos hallazgos y no envía nada.

**Acceptance Scenarios**:

1. **Given** al menos un portal propio activo, **When** llega una hora de la tarea "Revisar tus
   portales de empleo" (9, 13 y 17 h por defecto), **Then** la IA recibe la lista de portales con sus
   indicaciones y la orden de no postular.
2. **Given** que la IA dejó hallazgos, **When** termina, **Then** llegan a Telegram como una lista
   pendiente que se aprueba igual que la de los portales incluidos.
3. **Given** un hallazgo que ya se mostró, **When** vuelve a aparecer dentro de 30 días, **Then** no
   se repite.
4. **Given** que la IA no encontró nada, **When** responde `SIN_NOVEDADES`, **Then** no se envía nada
   por Telegram.

---

### User Story 4 - Vacantes publicadas en redes (Priority: P2)

La IA busca cada dos horas, de 8 a 20 h, publicaciones recientes en LinkedIn y en la web donde alguien
ofrece una vacante que encaja, y se las propone a la persona como lista para aprobar.

**Why this priority**: esas vacantes se llenan rápido y no aparecen en los portales.

**Independent Test**: con el motor de prueba y el fixture `social`, la tarea termina con una lista
pendiente y ningún envío.

**Acceptance Scenarios**:

1. **Given** el agente prendido, **When** llega una de las horas de la tarea "Buscar vacantes en
   redes", **Then** la IA recibe la orden de buscar publicaciones de las últimas horas.
2. **Given** una publicación con enlace para postular, **When** la IA la encuentra, **Then** la propone
   como postulación en la lista; se postula solo al aprobarla o con el envío automático de Empleo.
3. **Given** una publicación que pide la hoja de vida por correo, **When** la IA la encuentra,
   **Then** propone un borrador de correo con su texto; el borrador se deja en Gmail, sin enviarlo,
   solo al aprobarlo.
4. **Given** que no hubo nada nuevo, **When** la IA responde `SIN_NOVEDADES`, **Then** no se envía
   nada por Telegram.

---

### User Story 5 - Configurar el agente (Priority: P3)

La persona prende o apaga el agente, cambia la frecuencia de búsqueda, los portales activos, el cupo
diario, el horario de cada tarea y sus habilidades, desde el panel, Ajustes o Telegram.

**Why this priority**: ajusta el agente a la persona, pero el agente funciona con los valores por
defecto.

**Independent Test**: cambiar cada ajuste y verificar que la siguiente búsqueda o tarea lo usa.

**Acceptance Scenarios**:

1. **Given** el agente prendido, **When** la persona lo apaga (interruptor, Ajustes o
   `agente empleo off`), **Then** no se busca ni se ejecutan sus tareas, y el panel muestra
   "apagado".
2. **Given** que la persona pone 10 minutos de frecuencia en Ajustes, **When** guarda, **Then** se
   guarda 15, que es el mínimo.
3. **Given** que la persona escribe `habilidad Go evito`, **When** se hace la siguiente búsqueda,
   **Then** las vacantes con "Go" en el título se descartan, sin pasar por la IA.
4. **Given** que la persona escribe `buscar empleo`, **When** se procesa, **Then** se busca en ese
   momento sin esperar el intervalo.

---

### Edge Cases

- Un portal no responde: se pasa al siguiente y la búsqueda sigue con los demás.
- No se puede leer la descripción de una vacante: la vacante se descarta en esa búsqueda.
- La descripción indica que la vacante es vieja (Magneto, más de 7 días): se descarta.
- La sesión de la IA venció: se avisa por Telegram con el comando para volver a entrar, como máximo
  una vez por hora, y la lista queda para reintentar con `si`.
- Una ejecución pasa de una hora: se detiene y se reporta.
- La app se reinicia con una lista en curso: la lista vuelve a pendiente.
- Telegram no está configurado: aparece una notificación de macOS que lleva a configurarlo.
- La persona responde citando un aviso viejo: la respuesta aplica a esa lista y no a la última.

## Requirements *(mandatory)*

### Functional Requirements

**Búsqueda en portales incluidos**

- **FR-001**: El agente MUST buscar en los portales incluidos activos (LinkedIn, Get on Board,
  Computrabajo, elempleo, Magneto) cada `searchEveryMinutes` minutos (30 por defecto; Ajustes no deja bajar de 15),
  empezando 5 minutos después de abrir la app.
- **FR-002**: Cada portal MUST usar las búsquedas de `search-profile.json` (consultas, regiones,
  roles) y solo vacantes remotas.
- **FR-003**: El filtro de título MUST descartar la vacante si contiene una palabra bloqueada o una
  empresa bloqueada, o si es solo de frontend sin términos fuertes ni rol backend; MUST marcarla
  ENCAJA si tiene al menos un término fuerte o un término genérico sin términos débiles; MUST
  marcarla RETO si solo tiene términos genéricos o débiles; MUST descartarla si no tiene ninguno.
- **FR-004**: Las habilidades del perfil MUST alimentar el filtro: "domino" se suma a los términos
  fuertes y al stack propio, "conozco" a los débiles, "evito" a los bloqueados y se quita de los
  demás.
- **FR-005**: El agente MUST descartar las vacantes con salario publicado por debajo del mínimo del
  perfil (`minSalaryCOP`, o `minSalaryUSD` en Get on Board).
- **FR-006**: El agente MUST unificar las vacantes repetidas, ordenarlas por encaje y antigüedad y
  revisar la descripción de las 15 primeras, salvo en los portales que ya la entregan con la
  búsqueda.
- **FR-007**: El filtro de descripción MUST descartar la vacante si: está en portugués o en inglés,
  pide inglés intermedio o superior, es híbrida o presencial sin decir 100% remoto, el portal exige
  que diga "remoto" y no lo dice, es remota solo para otro país o región, tiene sede fuera de la
  ciudad de la persona sin decir 100% remoto, exige tarjeta profesional y la persona no la tiene,
  pide más años que `maxYearsRequired`, o su stack principal no es el de la persona.
- **FR-008**: El filtro de descripción MUST bajar a RETO una vacante cuyo stack ajeno dobla al propio.
- **FR-009**: El agente MUST avisar como máximo 6 vacantes ENCAJA por búsqueda; si no hay ninguna,
  como máximo 2 RETO.
- **FR-010**: El agente MUST recordar durante 21 días las vacantes revisadas y no volver a avisarlas.
- **FR-011**: El aviso MUST numerar cada vacante con su encaje, título, detalle (portal, empresa,
  antigüedad, modalidad, salario si lo hay) y enlace, y ofrecer los botones "Sí, postular a todas" y
  "No".

**Aprobación y postulación**

- **FR-012**: La persona MUST poder aprobar toda la lista, aprobar números sueltos o descartarla, por
  texto o con los botones, sobre la lista pendiente más reciente de las últimas 24 horas o sobre la
  que cita.
- **FR-013**: Con el envío automático prendido, el agente MUST aprobar sola la lista completa.
- **FR-014**: Las listas aprobadas MUST ejecutarse de a una; las demás esperan en cola.
- **FR-015**: La IA MUST recibir las vacantes elegidas, el cupo diario del agente (20 por defecto) y
  las reglas de `instrucciones-empleo.md`: postular solo si cumple al menos el 60% de los requisitos
  excluyentes, responder con la verdad según `perfil.md`, usar la hoja de vida más parecida a la
  vacante, y marcar PENDIENTE si hace falta contraseña, cuenta nueva o CAPTCHA.
- **FR-016**: La IA MUST registrar cada vacante en `postulaciones.md` y sumar sus números en
  `metricas-claude.json`, y su respuesta MUST llegar a Telegram.
- **FR-016a**: La ejecución MUST recibir solo lo aprobado que cabe en el cupo diario restante y dejar el
  registro de acciones que la app verifica; una acción que no coincide pone el agente en pausa (spec
  `010-separar-lectura-ejecucion`).

**Portales propios**

- **FR-017**: La tarea "Revisar tus portales de empleo" MUST correr a las horas configuradas (9, 13 y
  17 h por defecto) si hay portales propios activos, con la orden explícita de no postular.
- **FR-018**: Los hallazgos MUST llegar como una lista pendiente (máximo 8) que se aprueba como la de
  los portales incluidos, y no repetirse durante 30 días.

**Redes**

- **FR-019**: La tarea "Buscar vacantes en redes" MUST correr a las horas configuradas (8, 10, 12,
  14, 16, 18 y 20 h por defecto) con permisos de solo lectura y devolver lo que encuentra como lista
  para aprobar (postular o borrador de correo), según `instrucciones-redes.md`.

**Configuración y estado**

- **FR-020**: La persona MUST poder prender o apagar el agente, cambiar la frecuencia, los portales
  activos, el cupo diario, el horario de cada tarea y el envío automático desde el panel, Ajustes o
  Telegram.
- **FR-021**: El panel MUST mostrar la última búsqueda ("buscando…", "<hora>, nada nuevo",
  "<hora>, N avisada(s)"), la próxima ejecución, el encaje de la semana y si el agente está apagado.
- **FR-022**: El agente MUST sumar por semana las vacantes avisadas y las RETO.

### Key Entities

- **Vacante (Hit)**: identificador por portal, portal, encaje, título, enlace, detalle y antigüedad.
- **Encaje (Fit)**: ENCAJA o RETO.
- **Lista (Batch)**: tipo de tarea, vacantes, estado (pendiente, en curso, hecho, descartado, error,
  interrumpido), mensaje de Telegram asociado y resultado; se guarda 14 días.
- **Perfil de búsqueda de empleo (JobProfile)**: país, ciudad, consultas por portal, términos
  fuertes, genéricos, débiles y bloqueados, empresas y palabras de título bloqueadas, stack propio y
  ajeno, salario mínimo, años máximos y tarjeta profesional.
- **Habilidad (Skill)**: nombre, nivel (domino, conozco, evito) y otros nombres.
- **Ajustes del agente (AgentSettings)**: prendido, envío automático, frecuencia, cupo diario y
  tareas con su horario.
- **Portal propio (CustomPortal)**: nombre, enlace, indicaciones y si está activo.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Una vacante publicada en un portal incluido activo que encaja aparece en Telegram en la
  primera búsqueda después de su publicación (a lo sumo `searchEveryMinutes` minutos más el tiempo de
  la búsqueda).
- **SC-002**: Ninguna vacante se avisa dos veces dentro de 21 días.
- **SC-003**: Ninguna vacante avisada viola un filtro de título o, cuando se pudo leer, de
  descripción, contra los fixtures de cada portal.
- **SC-004**: Ninguna búsqueda avisa más de 6 vacantes.
- **SC-005**: Con el envío automático apagado, ninguna postulación de una lista ocurre sin un `si` de
  la persona.
- **SC-006**: Cambiar una habilidad por Telegram afecta la búsqueda siguiente, sin reiniciar la app.

## Assumptions

- La persona tiene Chrome con sesión iniciada en los portales donde postula y la extensión de la IA
  instalada.
- La IA elegida está instalada y con sesión iniciada.
- Los portales incluidos responden sin iniciar sesión a las búsquedas que hace Hirebar.
- El perfil (`perfil.json`) es veraz: la IA no agrega experiencia que no esté ahí.
- Los valores numéricos de esta spec (intervalos, máximos, ventanas) son los del código actual; la
  spec `024-textos-y-valores-fuera-del-codigo` los lleva a configuración.

## Divergencias con la constitución

| Comportamiento actual | Principio | Se corrige en |
|---|---|---|
| El envío automático se prende con una casilla, sin confirmación | II | `011-confirmar-envio-automatico` |
| Sin modo práctica | II | `014-modo-practica` |
| Las vacantes vistas se guardan en `UserDefaults` | IV | `022-version-datos` |
| Intervalos, máximos, ventanas y listas de idioma escritos en el código | VI | `024-textos-y-valores-fuera-del-codigo` |
| El motor del agente no tiene tests | VII | `019-tests-engine` |
