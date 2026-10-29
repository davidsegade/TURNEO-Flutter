# TURNEO Flutter

Nueva aplicación móvil TURNEO en Flutter, desarrollada en paralelo a la PWA existente.

Arquitectura conservada:

**Excel corporativo ⇄ Google Sheets ⇄ Supabase ⇄ TURNEO Flutter**

## Estado de la aplicación

- Proyecto Flutter independiente.
- Supabase como backend existente.
- Pantalla General mensual.
- Lectura de `planning` por mes, no de todo el histórico.
- Colores leídos del catálogo `services`.
- Los libros Google Sheets de 2026 y 2027 tienen la misma posición por ID en
  sus mapas `SYNC_MAP`: fila 9 `u1` (DAVID), fila 10 `u4` (JUAN), fila 11
  `u5` (SANTA EUFEMIA, Adrián) y fila 12 oculta. Los dos `SYNC_MAP` están
  actualizados por `local_user_id`, no por la posición visual del roster.
- Roster visible local por ID: `u1` (David, administrador), `u4` (Juan) y
  `u5` (Adrián). `u2` (Carlos) y `u3` (Alejandro) están inactivos en Supabase
  y no son visibles en la app. Sus datos de planificación y auditoría pueden
  permanecer archivados o inactivos; este estado no afirma su eliminación
  completa de la base de datos.
- El registro sólo ofrece `u5` Adrián y `u4` Juan, con `u5` seleccionado por
  defecto. `u5` usa `Santa Eufemia` como identidad Excel/Sheets.
- Login, recuperación, registro con la función existente y cierre de sesión.
- Edición del propio cuadrante; el administrador puede editar todos. Supabase aplica RLS.
- Actualización local de la celda guardada, sin cargar el histórico.
- Las escrituras de `planning` sólo se permiten en 2027. 2026 permanece
  disponible para lectura y sus históricos no se borran ni se reescriben.
- Flutter no llama a Google Sheets directamente: escribe en Supabase y
  conserva el flujo Excel -> app y las fórmulas del libro. La configuración
  remota del trigger queda fuera de este cambio local.
- La sincronización automática app -> Google Sheets 2027 está en
  `tool/google_apps_script/turneo_2027_pull.gs`; requiere instalación y
  credenciales manuales. No se instala ni se ejecuta ningún trigger desde este
  repositorio.

## Configuración

Flutter 3.47.5 y Supabase Flutter 2.17.2. Los workflows validan la URL del
proyecto y el secreto `SUPABASE_PUBLISHABLE_KEY` contra Auth y REST. El mismo
archivo generado se utiliza al compilar, sin mezclar claves legacy:

```
python3 tool/check_config.py
flutter analyze
flutter test
flutter build web --release --base-href /TURNEO-Flutter/ --dart-define-from-file=build-config.json
```

El preflight recibe `SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY` por entorno.
`build-config.json` está excluido de Git. No se utiliza ninguna clave privilegiada
en el cliente. Las consultas anónimas no prueban el acceso autenticado:
las pruebas RLS y de sesión deben verificarse por separado.

Los balances se muestran desde `balance_snapshots`; Flutter no escribe ni
recalcula el histórico remoto. El cálculo puro común está en
`lib/src/data/balance_calculator.dart`. Para `u5`, la baseline de DAS es `0` y
DF se calcula con las mismas fórmulas existentes para festivos nacionales,
autonómicos y locales. Los cierres ya aplicados son: diciembre de 2026, DF
`5`; enero de 2027, DF `6`; y diciembre de 2027, previsión DF `18` si no
disfruta ningún DF.

El operador debe escribir una fila de `balance_baselines` por usuario y periodo
de cálculo, con `local_user_id`, el periodo completo (`period_id`, no solo el
mes) y `das_initial`; para `u5`, `das_initial = 0`. Debe escribir una fila de
`balance_snapshots` por usuario y periodo mostrado, con el mismo `period_id`,
`das_generated`, `das_available`, `df_available` y los campos PICO existentes.
Los periodos de ambas tablas deben ser idénticos y no deben mezclarse cierres
mensuales con periodos anuales.

`df_available` solo puede publicarse cuando el operador/backend haya resuelto
los festivos nacionales, autonómicos y locales del periodo y su disfrute según
el algoritmo existente, incluyendo turnos/coberturas cuando esa regla los
necesite. La previsión de diciembre de 2027 queda condicionada a no disfrutar
ningún DF. Sheets y SQL se actualizan por sus conectores separados; OpenCode
no los modifica.

Las pruebas automatizadas cubren pantallas de 320 y 390 píxeles, edición sin
recarga, errores de guardado, permisos del cliente, consultas acotadas por mes,
cambio de año, contraste de MC/TC, baseline DAS de `u5` y la incertidumbre de
DF sin cobertura.
