# mail_size_analyzer

`mail_size_analyzer.sh` analiza los archivos de correo almacenados bajo `/srv/mail/*/Maildir` y calcula su distribucion por tamano usando 11 nichos mas un total general.

## Objetivo

- Recorrer todos los `Maildir` ubicados bajo `/srv/mail/*/Maildir`.
- Permitir analizar un unico usuario con `-u <usuario>`.
- Obtener el tamano de cada archivo regular en bytes.
- Convertir cada tamano a MB enteros mediante division truncada.
- Clasificar cada mail en los nichos `0-10`, `10-20`, ..., `90-100`, `+100`.
- Mostrar todos los contadores junto con la cantidad total de mails analizados.

## Uso

```bash
./scripts/mail_size_analyzer.sh [-h] [-c] [-u usuario]
```

## Flags

- `-h`: muestra la ayuda y finaliza con exit `0`.
- `-c`: imprime los 11 contadores y el total en una sola linea.
- `-u usuario`: analiza solo `/srv/mail/usuario/Maildir`.

## Reglas de clasificacion

- El tamano se obtiene en bytes.
- La conversion a MB se hace con division truncada: `bytes / 1048576`.
- Los intervalos son:
  - `0<=x<10`
  - `10<=x<20`
  - `20<=x<30`
  - `30<=x<40`
  - `40<=x<50`
  - `50<=x<60`
  - `60<=x<70`
  - `70<=x<80`
  - `80<=x<90`
  - `90<=x<=100`
  - `x>100`

## Salida

Sin `-c`:

```text
usuario1
usuario2
0-10 -> N1
10-20 -> N2
20-30 -> N3
30-40 -> N4
40-50 -> N5
50-60 -> N6
60-70 -> N7
70-80 -> N8
80-90 -> N9
90-100 -> N10
+100 -> N11
TOTAL -> Nt
```

Con `-c`:

```text
N1 N2 N3 N4 N5 N6 N7 N8 N9 N10 N11 Nt
```

Con `-u cnavarro` y sin `-c`:

```text
cnavarro
0-10 -> N1
10-20 -> N2
...
+100 -> N11
TOTAL -> Nt
```

## Errores

- El script imprime los errores por `stderr` en ingles.
- Si no hay archivos regulares para analizar, finaliza con exit `1`.
- Si falla el recorrido de la estructura de `Maildir`, finaliza con exit `1`.
- Cualquier flag no soportado o argumento posicional tambien finaliza con exit `1`.

## Ejemplos

```bash
./scripts/mail_size_analyzer.sh
./scripts/mail_size_analyzer.sh -h
./scripts/mail_size_analyzer.sh -c
./scripts/mail_size_analyzer.sh -u cnavarro
./scripts/mail_size_analyzer.sh -u cnavarro -c
```
