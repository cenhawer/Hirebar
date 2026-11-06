# Feature Specification: Agente Contenido

**Feature Branch**: `docs/spec-004-agente-contenido`

**Created**: 2026-11-05

**Status**: Draft

**Input**: Spec as-is: describe lo que el agente Contenido hace hoy en el commit base de `develop`,
para que sirva de referencia contra regresiones. Las desviaciones de la constitución se listan al
final con la spec que las corrige.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Recibir una publicación lista para aprobar (Priority: P1)

En los días de cada cuenta de contenido, o cuando la persona escribe `post`, la IA prepara una
publicación (texto y carrusel de 3 a 6 imágenes) con la identidad de esa cuenta, y Hirebar se la
manda por Telegram para que la apruebe. Nada se publica sin su respuesta.

**Why this priority**: es el trabajo del agente; sin el borrador no hay nada que publicar.

**Independent Test**: con un doble de `AIRunner` que deja un borrador y láminas HTML fijas, y un doble
de `MediaRenderer`, la tarea termina con las imágenes, el texto y la pregunta de aprobación en
Telegram, y sin publicar nada.

**Acceptance Scenarios**:

1. **Given** una cuenta prendida cuyos días incluyen hoy, **When** llegan las 9 h (con 12 horas de
   tolerancia), **Then** la IA prepara una publicación para esa cuenta con la orden de no publicar.
2. **Given** dos cuentas prendidas para hoy, **When** corre la tarea, **Then** se prepara una
   publicación por cuenta.
3. **Given** que la persona escribe `post` o `post <cuenta>`, **When** se procesa, **Then** la
   publicación se prepara ya y pasa primero en la fila, delante de las búsquedas.
4. **Given** que no hay cuentas prendidas, **When** la persona escribe `post`, **Then** se le
   indica que las agregue en Ajustes → Cuentas de contenido.
5. **Given** que la IA dejó el borrador y las láminas, **When** termina, **Then** Hirebar convierte
   cada lámina HTML (1080×1350) en PNG con Chrome sin ventana y manda a Telegram las imágenes, el
   texto listo para copiar y la pregunta: `publica`, `post <cuenta> cambia <qué>` o
   `post <cuenta> salta` (sin nombre de cuenta si hay una sola).
6. **Given** que ninguna lámina se pudo convertir, **When** se manda el aviso, **Then** dice que esta
   vez no salieron imágenes.
7. **Given** una cuenta cuya revisión de rendimiento nunca se hizo o tiene más de 7 días, **When** se
   prepara su publicación, **Then** la IA revisa antes las últimas 9 a 12 publicaciones de la cuenta
   en su red y escribe `rendimiento.md`, sin publicar, comentar ni seguir a nadie.

---

### User Story 2 - Publicar, pedir cambios o descartar (Priority: P1)

La persona responde a la publicación: la publica tal cual, pide un cambio o la descarta.

**Why this priority**: convierte el borrador en una publicación real, siempre con su aprobación.

**Independent Test**: con un doble de `AIRunner`, `publica` lanza la publicación con el texto y las
imágenes del borrador; `post cambia …` vuelve a preparar con el cambio; `post salta` aparta el
borrador sin lanzar nada.

**Acceptance Scenarios**:

1. **Given** un borrador pendiente, **When** la persona responde `publica` o `publica <cuenta>`,
   **Then** la IA publica en la red de la cuenta exactamente el texto del borrador con las imágenes
   en orden, y el video si hay `reel.mp4`.
2. **Given** que la sesión abierta en la red no es la de la cuenta, **When** la IA va a publicar,
   **Then** no publica y lo dice.
3. **Given** que no se pueden adjuntar todas las imágenes, **When** la IA publica, **Then** no
   publica solo el texto y explica qué falló.
4. **Given** una publicación hecha, **When** la IA termina, **Then** el texto, las láminas y el video
   pasan a `publicado-<fecha>…` y el borrador queda vacío.
5. **Given** un borrador pendiente, **When** la persona responde `post <cuenta> cambia <qué>`,
   **Then** la IA rehace la publicación completa aplicando ese cambio sobre la anterior.
6. **Given** un borrador pendiente, **When** la persona responde `post <cuenta> salta`, **Then** el
   borrador pasa a `descartado-<fecha>-<marca>.md` y no se publica.
7. **Given** borradores pendientes en varias cuentas, **When** la persona responde `publica` sin
   nombre, **Then** se le pide que diga cuál.

---

### User Story 3 - Video corto narrado con la voz de la persona (Priority: P2)

Si la cuenta tiene el video prendido, además del carrusel la IA prepara un Short animado de 20 a 40
segundos. Hirebar manda una vista previa sin voz y el guion; la persona responde con una nota de voz
leyéndolo, y Hirebar devuelve el video con su voz, cuadrado escena por escena, listo para subir.

**Why this priority**: el video trae audiencia, pero la publicación funciona sin él.

**Independent Test**: con escenas HTML y un `guion.json` de prueba, una grabación fija y dobles de
`AudioProcessor`, `SpeechRecognizer` y `MediaRenderer`, el video final tiene una escena por frase con
la duración de la voz.

**Acceptance Scenarios**:

1. **Given** una cuenta con video, **When** la IA prepara la publicación, **Then** deja de 5 a 8
   escenas HTML (1080×1920) animadas solo con CSS, `guion.json` con el texto y el tono de cada
   escena, y `texto.md` con la descripción.
2. **Given** las escenas listas, **When** se manda el carrusel, **Then** también llegan la vista
   previa sin voz, el guion para leer y la descripción lista para copiar, y la cuenta queda esperando
   la voz.
3. **Given** una cuenta esperando la voz, **When** la persona manda una nota de voz o un audio,
   **Then** Hirebar lo descarga, le quita silencios y ruido, nivela el volumen, reconoce en qué
   segundo dice cada palabra y graba cada escena cuadro por cuadro (30 por segundo) con la duración
   de su frase.
4. **Given** una cuenta con subtítulos, **When** se graba el video, **Then** se dibujan de a 3
   palabras, con la que suena resaltada, en la franja de 1150 a 1450 px.
5. **Given** un archivo `musica.mp3`, `.m4a`, `.wav` o `.aiff` en la carpeta de la cuenta, **When** se
   arma el video, **Then** se mezcla debajo de la voz al 10% del volumen.
6. **Given** el video listo, **When** se manda, **Then** llega con la descripción y la pregunta de si
   se sube; otra nota de voz lo rehace.
7. **Given** que la persona escribe `rearmar <cuenta>`, **When** se procesa, **Then** el video se
   rehace con la última nota de voz guardada.
8. **Given** que la persona escribe `video <cuenta>`, **When** se procesa, **Then** se vuelven a
   mandar la vista previa sin voz y el guion.
9. **Given** que no hay permiso de Reconocimiento de voz o no se reconoce el audio, **When** se arma
   el video, **Then** las escenas se reparten según el largo de su texto y queda anotado en el
   registro.

---

### User Story 4 - Configurar las cuentas de contenido (Priority: P3)

La persona agrega una cuenta por cada perfil donde publica y define su identidad: red, firma,
enfoque, días, paleta, estilo, video y subtítulos.

**Why this priority**: personaliza el contenido; con una cuenta por defecto ya funciona.

**Independent Test**: guardar una cuenta en Ajustes y verificar que la siguiente publicación usa su
red, firma, paleta, días y video.

**Acceptance Scenarios**:

1. **Given** Ajustes → Cuentas de contenido, **When** la persona agrega una cuenta, **Then** define
   identificador, red (LinkedIn o Instagram), nombre en las imágenes, línea bajo el nombre, usuario,
   de qué habla y para quién, días, paleta (de una lista o en hexadecimal), estilo, video y
   subtítulos, con una vista previa de la paleta.
2. **Given** una cuenta guardada, **When** se prepara su publicación, **Then** la IA recibe su ficha
   completa.
3. **Given** una cuenta apagada, **When** llega su día, **Then** no se prepara nada para ella.

---

### Edge Cases

- La IA no deja láminas o Chrome no las convierte: el aviso lo indica y la publicación sigue con el
  texto.
- Llega una nota de voz y ninguna cuenta espera voz: si hay una cuenta con video y guion, se usa
  esa; si no, se responde que no hay ningún video esperando voz.
- No se puede descargar el audio de Telegram: se pide que lo manden otra vez.
- No sale la vista previa sin voz: se manda igual el guion y se avisa.
- ffmpeg no está instalado: hoy la app lo instala con `pip` la primera vez.
- Una publicación ya está en curso para la misma cuenta: un nuevo `post` responde que ya está en
  curso.
- La sesión de la IA venció, una ejecución pasa de una hora o la app se reinicia: igual que en
  Empleo (spec `001-agente-empleo`).

## Requirements *(mandatory)*

### Functional Requirements

**Preparar la publicación**

- **FR-001**: La tarea "Preparar publicaciones" MUST correr a las horas configuradas (9 h por
  defecto, con 12 horas de tolerancia) y preparar una publicación por cada cuenta prendida cuyos
  días incluyen hoy.
- **FR-002**: `post` y `post <cuenta>` MUST preparar la publicación ya, delante de las tareas que
  esperan en la fila.
- **FR-003**: La IA MUST recibir la ficha de la cuenta y la orden explícita de no publicar, y seguir
  `instrucciones-contenido.md`: no repetir tema, gancho ni formato de las últimas 5 publicaciones
  (`temas.md`), rotar formatos y temas, usar tendencias de la semana sin inventar datos, y no hablar
  de la hoja de vida de la persona.
- **FR-004**: El borrador MUST quedar en `borrador.md`: en LinkedIn de 120 a 200 palabras sin
  emojis y con máximo 3 hashtags; en Instagram de 60 a 150 palabras con 8 a 12 hashtags.
- **FR-005**: Las láminas MUST ser de 3 a 6 archivos HTML de 1080×1350 px, sin recursos externos,
  solo con los colores de la paleta, con número de lámina y la firma de la cuenta.
- **FR-006**: Cada 7 días por cuenta, la IA MUST revisar el rendimiento de sus últimas publicaciones
  y escribir `rendimiento.md`, sin actuar en la red.
- **FR-007**: Al terminar, Hirebar MUST convertir las láminas a PNG con Chrome sin ventana y mandar a
  Telegram las imágenes, el texto listo para copiar y la pregunta de aprobación.

**Aprobación y publicación**

- **FR-008**: Ninguna publicación MUST salir sin un `publica` de la persona; el agente no tiene envío
  automático.
- **FR-009**: `publica` MUST publicar exactamente el texto y las imágenes del borrador, y el video
  como pieza aparte si existe; si no se adjuntan todas las imágenes, no se publica.
- **FR-010**: La IA MUST verificar que la sesión abierta sea la de la cuenta antes de publicar.
- **FR-011**: Tras publicar, la IA MUST mover el texto, las láminas y el video a
  `publicado-<fecha>…` y dejar el borrador vacío.
- **FR-012**: `post <cuenta> cambia <qué>` MUST rehacer la publicación completa con el cambio, con
  las versiones anteriores disponibles para la IA.
- **FR-013**: `post <cuenta> salta` MUST apartar el borrador como descartado sin publicar.

**Video narrado**

- **FR-014**: Con el video prendido, la IA MUST dejar de 5 a 8 escenas HTML de 1080×1920 animadas solo
  con CSS (o `window.onFrame`), `guion.json` con el texto y el tono de cada escena, y `texto.md`.
- **FR-015**: Hirebar MUST mandar la vista previa sin voz, el guion para leer y la descripción, y
  marcar la cuenta como esperando voz.
- **FR-016**: Al recibir la nota de voz, Hirebar MUST prepararla (paso alto, recorte de silencios y
  pausas, reducción de ruido, compresión y normalización a −14 LUFS), reconocer los tiempos de cada
  palabra en el dispositivo si se puede, cuadrar cada escena con su frase y grabar el video a 30
  cuadros por segundo.
- **FR-017**: Los subtítulos, si la cuenta los tiene, MUST mostrarse de a 3 palabras con la palabra
  actual resaltada.
- **FR-018**: La música de la carpeta de la cuenta, si existe, MUST mezclarse al 10% del volumen.
- **FR-019**: `rearmar <cuenta>` MUST rehacer el video con la última grabación; `video <cuenta>` MUST
  reenviar la vista previa y el guion.

**Cuentas**

- **FR-020**: Cada cuenta MUST tener identificador, prendida, red, nombre, línea bajo el nombre,
  usuario, enfoque, estilo, paleta (fondo, superficie, acento, texto, secundario), días, video y
  subtítulos, guardados en `contenido/cuentas.json`.
- **FR-021**: Ajustes MUST ofrecer paletas predefinidas (Negro y naranja, Azul noche, Claro con azul,
  Verde) y una vista previa.

### Key Entities

- **Cuenta de contenido (ContentAccount)**: identidad de un perfil donde se publica; su carpeta
  guarda borrador, láminas, video, temas, rendimiento, cambios pedidos y publicaciones anteriores.
- **Paleta (ContentPalette)**: cinco colores en hexadecimal.
- **Escena**: archivo HTML del video con el texto que dice la persona en ella.
- **Tiempo de palabra (WordTiming)**: palabra, inicio y fin en la grabación.
- **Grabación**: la nota de voz de la persona (`video/grabacion.*`).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Ninguna publicación sale sin un `publica` de la persona.
- **SC-002**: El texto publicado es idéntico al de `borrador.md` aprobado.
- **SC-003**: Ninguna publicación sale con menos imágenes que las del borrador.
- **SC-004**: En el video, cada escena empieza cuando la persona dice la primera palabra de su
  frase, contra una grabación de prueba.
- **SC-005**: Ninguna lámina ni escena carga recursos externos.
- **SC-006**: Ninguna de las últimas 5 publicaciones de una cuenta repite tema, gancho y formato.

## Assumptions

- La persona tiene sesión iniciada en LinkedIn o Instagram con la cuenta correcta en su Chrome.
- Google Chrome está instalado en `/Applications` para convertir las láminas.
- La persona tiene derechos sobre la música que pone en la carpeta de la cuenta.
- Los valores numéricos de esta spec son los del código actual; la spec
  `024-textos-y-valores-fuera-del-codigo` los lleva a configuración.

## Divergencias con la constitución

| Comportamiento actual | Principio | Se corrige en |
|---|---|---|
| La IA navega la red de la cuenta para revisar rendimiento, y publica, con permisos para actuar | III | `010-separar-lectura-ejecucion` |
| ffmpeg se instala con `pip` mientras la app corre | V | `016-herramientas-en-ejecucion` |
| El permiso de Reconocimiento de voz se pide al llegar la primera nota de voz | V | `025-asistente-primer-uso` |
| La cuenta que espera voz se guarda en `UserDefaults` | IV | `022-version-datos` |
| Las grabaciones de voz, borradores descartados y publicaciones anteriores no tienen retención | IV | `029-politica-datos` |
| `instrucciones-contenido.md` trae hashtags de una marca y de una ciudad concretas y "Colombia y Latinoamérica" como mercado | IV · VI | `024-textos-y-valores-fuera-del-codigo` (pasan a la ficha de la cuenta y al perfil) |
| Tamaños, cuadros por segundo, palabras por subtítulo, volumen de la música y ventanas escritos en el código | VI | `024-textos-y-valores-fuera-del-codigo` |
| El motor del agente no tiene tests | VII | `019-tests-engine` |

## Hallazgos sin principio asociado

- `instrucciones-linkedin-borrador.md` e `instrucciones-linkedin-publicar.md` ya no los usa ninguna
  tarea, pero se copian en cada instalación nueva. Se eliminan en `020-partir-archivos`.
- Las tareas de contenido se llaman internamente `linkedin-borrador` y `linkedin-publicar` aunque
  sirven para cualquier red. Se renombran en `017-arquitectura-hexagonal`, con migración de los
  archivos de agentes que guardan ese nombre.
