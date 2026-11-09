# Research: Separar lectura de ejecución

## R1. Perfil de lectura de Claude Code

- **Decision**: `claude -p` con `--permission-mode dontAsk`, `--restricted`, `--tools` con solo
  `Read`, `Glob`, `Grep` y `WebSearch`, y `--allowedTools` con esas más las herramientas
  de solo lectura de Claude in Chrome (navegar, leer la página, buscar en la página, capturas). La
  fase de lectura no escribe archivos: devuelve sus propuestas por la salida estándar.
- **Rationale**: `dontAsk` niega sin preguntar todo lo que no está en la lista; `--restricted` confina
  las herramientas de archivos a la carpeta de trabajo y rechaza `bypassPermissions` aunque alguien
  lo agregue. Sin herramientas de escritura no hay forma de dejar archivos que otra tarea lea como
  instrucciones. Verificado contra la ayuda de Claude Code 2.1.318.
- **Alternatives considered**: `--permission-mode plan` (pensado para planificar, no para leer la web
  con el navegador); mantener `bypassPermissions` con `--disallowedTools` (una lista de exclusión deja
  pasar las herramientas nuevas que aparezcan).

## R1b. Perfil de redacción (`draft`)

- **Decision**: un tercer perfil para las tareas que escriben archivos pero no actúan afuera:
  preparar contenido (`contenido/<cuenta>/`), actualizar el perfil (`perfil.json`, `perfil.md`,
  `hv/`) y el análisis semanal (`informes/`). Igual que `read`, más `Write` y `Edit` limitados por
  regla de ruta a la carpeta o archivos declarados de la tarea; sin herramientas de acción de Chrome.
- **Rationale**: esas tareas necesitan escribir su resultado, y Contenido además lee la web. Con
  escritura limitada a su carpeta, un contenido externo malicioso solo puede alterar un borrador que
  la persona revisa antes de publicar. Cierra además la divergencia de la spec `006-agente-analista`:
  el análisis solo puede escribir en `informes/`.
- **Alternatives considered**: darles el perfil `act` (podrían enviar); darles `read` y que devuelvan
  los archivos por la salida estándar (láminas HTML y hojas de vida no caben bien en un solo bloque).

## R2. Herramientas de Claude in Chrome por fase

- **Decision**: la lista de herramientas de Chrome permitidas en cada fase vive en un archivo de
  perfiles dentro del bundle de la app (`Resources/perfiles-ia.json`), no en el workspace. En lectura
  solo entran las herramientas que ven la página; las que hacen clic, escriben, llenan formularios o
  ejecutan JavaScript quedan fuera. Una herramienta que no está en la lista queda negada por `dontAsk`.
- **Rationale**: el workspace es escribible por la fase de ejecución; si los perfiles vivieran ahí, la
  IA podría ampliarse los permisos. Una lista de inclusión es segura ante herramientas nuevas.
- **Alternatives considered**: leer los nombres de herramientas en tiempo de ejecución desde la
  extensión (no hay una interfaz estable para eso); escribirlos en el código (principio VI).

## R3. Codex y Gemini CLI

- **Decision**: lectura sin navegador: Codex con `--sandbox read-only` y Gemini con
  `--approval-mode default` y las herramientas de escritura y de shell excluidas. Las tareas que
  necesitan el navegador para leer (redes, portales propios, revisión de rendimiento, seguimientos,
  búsqueda de clientes en Gmail) solo corren con Claude Code; con Codex o Gemini se avisa al
  configurarlas y no corren. La ejecución usa los comandos de hoy, con la verificación posterior.
- **Rationale**: ninguno de los dos está instalado en el entorno de desarrollo y la restricción de
  herramientas de sus servidores MCP de navegador no se puede verificar; cerrar el navegador en
  lectura es la única opción que cumple el principio III sin suponer comportamiento no comprobado.
- **Alternatives considered**: confiar en que el servidor MCP de cada uno respete una lista de
  herramientas (no verificado); quitar Codex y Gemini (pierde funciones que hoy existen).

## R4. Comando propio ("Otra IA")

- **Decision**: dos comandos en `config.json`, `readCommand` y `actCommand`, con una advertencia fija
  en Ajustes. La lectura recibe las mismas variables `HIREBAR_*` más `HIREBAR_PHASE=read`.
- **Rationale**: resuelto en la sesión de aclaraciones de la spec (FR-004a).
- **Alternatives considered**: un solo comando (B) o quitar la opción (C), descartadas en la
  aclaración.

## R5. Dónde vive lo que la IA no debe poder cambiar

- **Decision**: la copia de lo aprobado, el registro de verificación y la pausa de cada agente viven en
  `~/Library/Application Support/Hirebar/estado/`, fuera del workspace (`.../Hirebar/workspace/`).
- **Rationale**: la fase de ejecución escribe en el workspace (registros como `postulaciones.md`); con
  `--restricted` no alcanza `estado/`, así que no puede autoaprobarse editando la lista ni levantar
  su pausa.
- **Alternatives considered**: guardar lo aprobado en `lotes.json` dentro del workspace (la IA podría
  editarlo).

## R6. Formato de propuestas y del registro de acciones

- **Decision**: JSON con `schemaVersion`. La lectura imprime un único objeto de propuestas al final de
  su salida, entre los marcadores `HIREBAR_PROPOSALS_BEGIN` y `HIREBAR_PROPOSALS_END`; la ejecución
  escribe `ejecuciones/<lote>.acciones.json`. Esquemas en `contracts/`.
- **Rationale**: la salida estándar funciona igual en los cuatro motores y no necesita permisos de
  escritura en lectura; un archivo por lote en ejecución deja el registro aunque la respuesta a
  Telegram se corte.
- **Alternatives considered**: que la lectura escriba archivos (necesita permisos de escritura);
  extraer acciones del texto libre de la respuesta (frágil).

## R7. Verificación

- **Decision**: la verificación es una función pura del dominio que recibe lo aprobado y el registro
  y devuelve, por acción, autorizada, no autorizada o no verificada. Compara tipo, identificador del
  elemento, destino normalizado y texto exacto cuando la acción envía texto. Un enlace se normaliza sin
  esquema, `www.` ni barra final, conserva los parámetros que identifican el elemento (`?jk=…`,
  `?currentJobId=…`) y quita solo los de seguimiento listados en `Resources/destinos.json`
  (`utm_*`, `trk`, `fbclid`…); un correo se compara en minúsculas.
- **Rationale**: pura y testeable sin red ni IA (principio VII); el dominio no conoce motores ni
  archivos (principio VIII).
- **Alternatives considered**: comparar por similitud de texto (abre la puerta a cambios no
  aprobados).

## R8. Exfiltración desde la fase de lectura

- **Decision**: en `read` y `draft`, la IA no puede leer `perfil.json`, `perfil.md` ni `hv/`
  (`Read` negado por ruta); los criterios que necesita para juzgar el encaje (habilidades, descartes,
  enfoque de la cuenta) van en el pedido, sin datos de contacto. `WebFetch` no está en `read` ni en
  `draft`: la lectura de la web va por Chrome. Las herramientas de Chrome permitidas en lectura
  son solo `navigate`, `read_page`, `get_page_text`, `find` y las de pestañas; `computer`,
  `form_input`, `javascript_tool`, `file_upload`, `upload_image`, `shortcuts_execute` y
  `browser_batch` quedan fuera.
- **Rationale**: un contenido con instrucciones podría pedir que la IA lea datos personales y los
  mande en la dirección de una página. Sin acceso a esos archivos, no hay qué mandar.
- **Riesgo residual**: `navigate` puede abrir cualquier dirección y Claude Code no restringe por
  dominio las herramientas de un servidor MCP; con lo anterior, lo único expuesto es lo que ya está en
  el pedido. Se cubre con casos de exfiltración en los evals de la spec `015-evals-prompts` y en el
  `/security-review` de este PR.
- **Alternatives considered**: quitar el navegador de la lectura (rompe redes y portales propios);
  dar acceso completo al perfil (expone datos de contacto).

## R9. Lo aprobado es lo que la persona vio

- **Decision**: toda lista para aprobar se arma desde la copia que la app guarda en
  `estado/propuestas/<lote>.json` al mostrarla, con destino y texto completos. Los correos de
  prospección se leen de `prospeccion/pendientes.json` una sola vez, al terminar la fase de redacción,
  y se muestran con destinatario, asunto y texto; `envia correos` aprueba esa lista, no el archivo.
  Los anuncios largos se parten en varios mensajes y el botón va en el último; si uno no llega, la
  lista se descarta. El cupo reserva lo aprobado sin verificar, y el envío automático retiene los
  seguimientos a destinos sin una acción verificada previa del agente.
- **Rationale**: si la ejecución releyera un archivo que escribe la IA, o si un mensaje cortado
  ocultara elementos, una inyección en la fase de lectura terminaría aprobada y la verificación la
  daría por buena.
- **Alternatives considered**: validar el archivo al ejecutar (la persona igual no vio el
  destinatario); limitar la cantidad de propuestas (no evita aprobar algo oculto).
- **Riesgo residual**: con el envío automático de Clientes prendido, un correo en frío nuevo sale sin
  que la persona lo vea. Su texto puede llevar lo que la fase de redacción leyó en la web y en Gmail,
  aunque no `perfil.*` ni `hv/`; por eso el envío automático de Clientes viene apagado y la guía lo
  advierte.

