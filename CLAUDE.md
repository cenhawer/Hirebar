@AGENTS.md

## Claude Code

- Las reglas de Swift de este repo están en `.claude/rules/swift.md` y se cargan al leer archivos
  `.swift`; prevalecen sobre las reglas globales donde difieren.
- Revisión de cada PR con `swift-code-reviewer`; los cambios de seguridad pasan además
  `/security-review`.
- La configuración de la máquina de cada persona va en `CLAUDE.local.md`, que no se versiona.
