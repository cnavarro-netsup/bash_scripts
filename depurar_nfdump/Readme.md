# depurar_nfdump

## Proposito

Proyecto base para desarrollar un script Bash orientado a depurar o analizar salidas de `nfdump`.
Incluye estructura inicial de trabajo, documentacion de especificacion y un script esqueleto listo para evolucionar.

## Estructura

- `scripts/depurar_nfdump.sh`: punto de entrada del proyecto.
- `specs/requirements.md`: requerimientos funcionales y no funcionales.
- `specs/design.md`: decisiones de diseno y flujo esperado.
- `specs/tasks.md`: checklist de implementacion.
- `tests/test_depurar_nfdump.bats`: pruebas iniciales.

## Uso inicial

```bash
./scripts/depurar_nfdump.sh -h
```

## Siguiente paso sugerido

Definir en `specs/requirements.md` que significa exactamente "depurar nfdump": entradas esperadas, filtros, formato de salida, errores y casos de uso reales.
