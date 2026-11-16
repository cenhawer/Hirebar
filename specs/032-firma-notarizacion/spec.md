# Feature Specification: Firma de la app

**Feature Branch**: `feature/HB-032-firma-notarizacion`

**Created**: 2026-11-16

**Status**: Draft

**Input**: Plan original (`docs/Plan.md`): "App firmada con Developer ID y notarizada; Gatekeeper no
la bloquea". Esa firma y notarización completas requieren una cuenta de pago del Apple Developer
Program; el usuario no tiene una (el mismo caso que en Kuentas y StreamingHub para iPad). Solo cuenta
con el certificado gratis de Xcode (Apple Development / Personal Team).

## Decisión de producto (D8)

Sin Developer ID Application ni Apple Developer Program, no hay notarización real posible: `notarytool`
exige esa membresía. **Se cierra esta spec con firma ad-hoc/Apple Development y sin notarización**,
documentando la limitación en vez de simularla. `scripts/bundle.sh` ya firma por defecto con `-` (ad-hoc)
y acepta `HIREBAR_SIGN_IDENTITY` para firmar con el certificado Apple Development del usuario, igual que
Kuentas. Esto alcanza para correr la app en la Mac donde se compila; **Gatekeeper puede seguir
bloqueándola si se copia a otra Mac sin ese certificado**, y no hay forma de evitarlo sin la cuenta de
pago. Si el usuario consigue un Developer ID más adelante, esta spec se reabre para notarización real.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - La app corre en la Mac de desarrollo sin advertencias repetidas (Priority: P1)

**Acceptance Scenarios**:

1. **Given** `HIREBAR_SIGN_IDENTITY` fijo al certificado Apple Development del usuario, **When**
   corre `scripts/bundle.sh --install`, **Then** la app queda firmada con esa identidad y conserva el
   permiso de Reconocimiento de voz entre compilaciones (ya cubierto por `016`/`025`).
2. **Given** ningún `HIREBAR_SIGN_IDENTITY` configurado, **When** corre `scripts/bundle.sh`, **Then**
   la app queda firmada ad-hoc (`-`), utilizable en la misma Mac.

### User Story 2 - La persona entiende la limitación antes de copiar la app (Priority: P1)

**Acceptance Scenarios**:

1. **Given** el README, **When** la persona lee la sección de instalación, **Then** encuentra una
   nota explícita: sin Developer ID de pago, Gatekeeper puede bloquear la app en otra Mac, y cómo
   abrirla igual (clic derecho → Abrir, o `xattr -dr com.apple.quarantine`).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `scripts/bundle.sh` MUST sigue firmando con `HIREBAR_SIGN_IDENTITY` (por defecto ad-hoc);
  esta spec no agrega notarización real.
- **FR-002**: El README MUST documenta explícitamente que la app no está notarizada, por qué
  (sin cuenta de pago de Apple Developer Program) y qué hacer si Gatekeeper la bloquea en otra Mac.

## Success Criteria *(mandatory)*

- **SC-001**: `scripts/bundle.sh --install` sigue instalando y abriendo la app en la Mac de
  desarrollo sin pasos manuales adicionales (ya validado por specs anteriores).
- **SC-002**: El README menciona "Gatekeeper" y "Developer ID" explícitamente con la limitación y la
  salida manual.
