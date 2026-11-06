# Feature Specification: Agente Perfil

**Feature Branch**: `docs/spec-005-agente-perfil`

**Created**: 2026-11-05

**Status**: Draft

**Input**: Spec as-is: describe lo que el agente Perfil hace hoy en el commit base de `develop`, para
que sirva de referencia contra regresiones. Las desviaciones de la constitución se listan al final
con la spec que las corrige.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Agregar un logro o un cambio de trabajo desde Telegram (Priority: P1)

La persona manda un logro o un cambio de trabajo por Telegram apenas pasa. La IA lo incorpora a su
perfil sin inventar nada y regenera sus hojas de vida, que le llegan en PDF.

**Why this priority**: el perfil es la única fuente de la experiencia que usan todos los agentes;
tenerlo al día mejora cada postulación y propuesta.

**Independent Test**: con un doble de `AIRunner` que edita `perfil.json` y deja los HTML de cada
variante, y un doble de `MediaRenderer`, `logro …` termina con el pedido registrado, el perfil
actualizado y un PDF por variante en Telegram.

**Acceptance Scenarios**:

1. **Given** que la persona escribe `logro bajé el tiempo de despliegue de 30 a 10 minutos en Acme`,
   **When** se procesa, **Then** el pedido se agrega a `perfil-cambios.txt` con fecha y tipo, y se
   lanza "Actualizar perfil y hojas de vida".
2. **Given** un logro sin número, **When** la IA lo incorpora, **Then** no inventa una cifra.
3. **Given** un logro que menciona una tecnología que no está en las habilidades, **When** la IA lo
   incorpora, **Then** la agrega como "conozco" y lo dice; nunca la sube a "domino".
4. **Given** que la persona escribe `trabajo nuevo Backend Senior en Acme desde dic 2026`, **When**
   la IA lo procesa, **Then** cierra la experiencia actual con esa fecha, crea la nueva arriba y
   actualiza el titular y las reglas que nombraban el empleo anterior.
5. **Given** un pedido que la IA no entiende, **When** lo procesa, **Then** no lo agrega y pregunta
   en la respuesta final.
6. **Given** que la persona escribe `logro` sin texto, **When** se procesa, **Then** se le muestra un
   ejemplo y no se lanza nada.

---

### User Story 2 - Regenerar las hojas de vida (Priority: P1)

La persona pide sus hojas de vida y recibe un PDF por cada variante definida en su perfil, en formato
ATS y con lo más relevante para cada variante primero.

**Why this priority**: las postulaciones usan estas hojas de vida.

**Independent Test**: con un perfil de prueba de dos variantes y un doble de `MediaRenderer`, `hv`
termina con dos PDF en Telegram y el resumen "2 de 2 listas".

**Acceptance Scenarios**:

1. **Given** que la persona escribe `hv` o pulsa "Regenerar HV" en el panel, **When** se procesa,
   **Then** la IA regenera el HTML de cada variante desde `hv/plantilla.html` sin cambiar el perfil.
2. **Given** los HTML listos, **When** termina la IA, **Then** Hirebar los convierte a PDF con Chrome
   sin ventana y manda cada PDF a Telegram con el resumen "N de M listas".
3. **Given** una variante cuyo HTML la IA no dejó, **When** se convierte, **Then** el resumen la
   nombra.
4. **Given** que Chrome no convierte una variante, **When** termina, **Then** el resumen la nombra y
   pide revisar que Google Chrome esté instalado.
5. **Given** un perfil sin variantes (`cvVariants` vacío), **When** termina la IA, **Then** se avisa
   que no se generaron PDF.

---

### User Story 3 - Cambiar habilidades al instante (Priority: P1)

La persona cambia el nivel de una habilidad desde Telegram o Ajustes y la búsqueda siguiente ya la
usa, sin pasar por la IA.

**Why this priority**: es el control más directo sobre qué avisos le llegan.

**Independent Test**: con un `perfil.json` de prueba, `habilidad Go evito` deja Go en "evito" sin
tocar el resto del archivo, y el filtro de búsqueda lo usa en la siguiente llamada.

**Acceptance Scenarios**:

1. **Given** una habilidad nueva, **When** la persona escribe `habilidad Terraform domino`, **Then**
   se agrega con ese nivel y se responde que ya cuenta en la próxima búsqueda.
2. **Given** una habilidad existente, **When** la persona cambia su nivel, **Then** se responde con
   el nivel anterior y el nuevo.
3. **Given** que el nivel ya era ese, **When** la persona lo repite, **Then** se responde que ya
   estaba así.
4. **Given** que la persona escribe `habilidad Go`, **When** se procesa, **Then** se responde con el
   nivel actual de Go.
5. **Given** que la persona escribe `habilidades`, **When** se procesa, **Then** se responde con las
   habilidades agrupadas en Domino, Conozco y Evito.
6. **Given** que el nivel se escribe con un sinónimo ("fuerte", "experto", "intermedio",
   "aprendiendo", "nunca", "fuera"), **When** se procesa, **Then** se interpreta como domino, conozco
   o evito.
7. **Given** Ajustes → Habilidades, **When** la persona edita nombre, nivel y otros nombres y guarda,
   **Then** solo cambian las habilidades de `perfil.json` y el resto del archivo queda igual.
8. **Given** que `perfil.json` no es JSON válido, **When** se cambia una habilidad, **Then** se
   responde con el error y no se escribe nada.

---

### Edge Cases

- `perfil.json` tiene un error de formato: la app sigue sin las habilidades y lo anota en el
  registro.
- Hay varios pedidos acumulados en `perfil-cambios.txt`: la IA los recibe todos en una sola ejecución
  y el archivo se vacía al terminar.
- La sesión de la IA venció, una ejecución pasa de una hora o la app se reinicia: igual que en
  Empleo (spec `001-agente-empleo`).

## Requirements *(mandatory)*

### Functional Requirements

**Pedidos de cambio**

- **FR-001**: `logro <texto>` y `trabajo <texto>` MUST agregar el pedido con fecha y tipo a
  `perfil-cambios.txt` y lanzar "Actualizar perfil y hojas de vida".
- **FR-002**: La IA MUST incorporar los pedidos en `perfil.json` según `instrucciones-perfil.md`:
  logros con verbo en pasado, tecnologías y fecha; cambios de trabajo cerrando la experiencia
  anterior; tecnologías nuevas como "conozco"; sin inventar empresas, fechas, títulos ni cifras.
- **FR-003**: La IA MUST mantener `perfil.md` igual a `perfil.json` y validar que `perfil.json` siga
  siendo JSON válido.
- **FR-004**: Al terminar la ejecución, la app MUST vaciar `perfil-cambios.txt`.

**Hojas de vida**

- **FR-005**: La IA MUST escribir `hv/<id>.html` por cada variante de `cvVariants` desde la
  plantilla, con el titular y las tecnologías de `focus` primero, en formato ATS (una columna, sin
  tablas ni imágenes, títulos estándar, máximo 2 páginas) y sin habilidades en "evito".
- **FR-006**: La app MUST convertir cada HTML a `<file>.pdf` con Chrome sin ventana (90 segundos
  máximo por archivo), mandar cada PDF a Telegram y un resumen con las variantes que faltaron o
  fallaron.

**Habilidades**

- **FR-007**: `habilidad <nombre> <nivel>` MUST cambiar o agregar la habilidad en `perfil.json` sin
  pasar por la IA, conservando el resto del archivo.
- **FR-008**: Los niveles MUST aceptar sinónimos: domino (dominio, fuerte, experto), conozco
  (intermedio, básico, reto, aprendiendo) y evito (no, nunca, bloquear, fuera).
- **FR-009**: `habilidad <nombre>` MUST responder el nivel actual; `habilidades` MUST responder la
  lista agrupada por nivel.
- **FR-010**: Ajustes → Habilidades MUST permitir editar nombre, nivel y otros nombres, y guardar solo
  la sección de habilidades.
- **FR-011**: Un cambio de habilidad MUST aplicar desde la búsqueda siguiente de Empleo y Freelance
  (spec `001-agente-empleo`, FR-004; spec `002-agente-freelance`, FR-005).

### Key Entities

- **Perfil (Profile)**: `person`, `preferences`, `skills`, `experience`, `projects`, `rules` y
  `cvVariants`; la app solo lee y escribe `skills` y lee `cvVariants`, el resto lo edita la IA o la
  persona a mano.
- **Habilidad (Skill)**: nombre, nivel, años y otros nombres.
- **Variante de hoja de vida (CVVariant)**: identificador, título, nombre del archivo y tecnologías de
  enfoque.
- **Pedido de cambio**: fecha, tipo (Logro, Cambio de trabajo) y texto, en `perfil-cambios.txt`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Un cambio de habilidad por Telegram queda guardado y aplica en la búsqueda siguiente,
  sin ejecutar la IA.
- **SC-002**: Cambiar una habilidad no modifica ninguna otra sección de `perfil.json`.
- **SC-003**: `hv` produce un PDF por cada variante o nombra en el resumen cada una que faltó.
- **SC-004**: Ningún logro incorporado contiene una cifra que no estaba en el pedido de la persona.
- **SC-005**: Ninguna hoja de vida incluye una habilidad en "evito".

## Assumptions

- La persona edita a mano en `perfil.json` sus datos, estudios, preferencias, reglas y variantes de
  hoja de vida; Hirebar no tiene editor para esas secciones.
- Google Chrome está instalado en `/Applications`.
- La plantilla `hv/plantilla.html` de `Resources/inicial/hv/` es el punto de partida de todas las
  hojas de vida.

## Divergencias con la constitución

| Comportamiento actual | Principio | Se corrige en |
|---|---|---|
| `perfil.json` no tiene `schemaVersion` | IV | `022-version-datos` |
| `perfil-cambios.txt` se vacía sin dejar historia de los pedidos | II | `028-vista-actividad` |
| Textos de respuesta y sinónimos de nivel escritos en el código | VI | `024-textos-y-valores-fuera-del-codigo` |
| El flujo de actualización del perfil no tiene tests | VII | `019-tests-engine` |

## Hallazgos sin principio asociado

- Los datos personales, la experiencia, las preferencias y las variantes de hoja de vida solo se
  editan a mano en `perfil.json`; un error de formato deja a la app sin habilidades. Se resuelve en
  `026-editor-perfil`.
