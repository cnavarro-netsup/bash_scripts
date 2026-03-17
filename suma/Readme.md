# suma.sh

## Propósito

`scripts/suma.sh` suma dos números reales con punto decimal y máximo dos decimales. Está pensado para operaciones simples donde el resultado debe mostrarse en formato legible mientras los logs informativos y de error van por stderr.

## Uso

```bash
# Ejecutar suma y mostrar resultado
./scripts/suma.sh [-d] <número1> <número2>
```

### Opciones

- `-d`: activa modo debug (`set -x`).
- `-h`: muestra esta ayuda.

### Ejemplos

- `./scripts/suma.sh 3.45 1.55` → STDOUT: `Resultado: 5.00`, STDERR contiene logs INFO.
- `./scripts/suma.sh -d -3.5 2.25` → activa trazas y muestra `Resultado: -1.25`.

## Validaciones

- Se requieren exactamente dos argumentos posicionales.
- Cada número debe usar punto decimal y tener máximo dos décimas.
- Si la entrada es inválida, el script imprime el error en STDERR y sale con código 1.

## Logs

Todos los mensajes informativos o errores van a STDERR con formato `[INFO|ERROR]` para facilitar su parsing en pipelines.

## Tests

Se provee la suite Bats `tests/test_suma.bats` que verifica los casos felices (positivos, negativos, enteros) y los errores esperados. Ejecutar con `bats tests/test_suma.bats`.
