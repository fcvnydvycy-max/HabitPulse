# HabitPulse — revisión de compatibilidad del esquema Supabase

**Rama revisada:** `habitpulse/auth-data-foundation`  
**Base revisada:** exportación de columnas de Supabase (93 columnas, 13 tablas) y `index.html` de la rama.  
**Alcance:** revisión estática. No se han importado datos, ejecutado migraciones ni modificado la web publicada.

## 1. Resultado ejecutivo

El esquema actual cubre una parte importante de HabitPulse, pero **todavía no está listo para conectar la aplicación ni para importar los datos existentes**. Hay correspondencia razonable para hábitos, comidas consumidas, tareas, entrenamientos registrados, peso y fotos. Faltan entidades para varias funciones que la aplicación ya guarda localmente, y algunas tablas actuales no contienen todos los campos que la interfaz necesita.

La aplicación actual mantiene un almacén completo por usuario en el navegador (LocalStorage) y conserva un adaptador Firebase antiguo que, si encuentra una configuración inyectada, guarda el almacén global completo en un único documento. Ese modelo no debe trasladarse a Supabase: los datos deben guardarse por usuario y entidad, con Auth y RLS.

## 2. Compatibilidad por función

| Función / dato del HTML actual | Estructura observada en la aplicación | Tabla actual | Evaluación y decisión |
|---|---|---|---|
| Cuenta y perfil | username, nombre visible, edad, peso, altura, objetivo, objetivos de kcal/macros/agua | profiles, body_metrics | Parcial. profiles solo tiene username, display_name, friend_code y avatar_path. No añadir peso, altura ni objetivos nutricionales al perfil público. Crear ajustes privados por usuario. |
| Hábitos | id antiguo, name, emoji, color, baseStreak, days[7] | habits, habit_entries | Parcial. habits tiene title, description, icon, color, frequency y archived. Mapear name→title e icono→icon. Los siete booleanos solo se pueden fechar con lastWeekMondayISO. baseStreak no debe convertirse en historial inventado. |
| Hidratación | waterGlassesByDay[7], cada vaso equivale a 0,25 L; el día seleccionado modifica el índice semanal | Ninguna | No compatible todavía. Crear registros diarios de agua con fecha y cantidad (vasos o ml). El índice semanal no es una fecha por sí solo; usar lastWeekMondayISO para recuperar fechas. |
| Rutinas de gimnasio | weeklyGymRoutine[0..6] con título y lista de ejercicios | workouts | No compatible como plantilla. workouts representa sesiones realizadas (fecha, título, duración, notas, exercises). Crear tabla separada de rutinas/plantillas semanales; no guardar la plantilla como si fuera un entrenamiento realizado. |
| Entrenamientos realizados | workouts tiene workout_date, title, duration_minutes, notes y exercises JSONB | workouts | Compatible en principio, pero hay que revisar el formato exacto de exercises y confirmar que cada sesión realizada se registra realmente desde la UI antes de diseñar el conversor. |
| Comidas consumidas | mealsByDay[fecha] contiene id, type, name, kcal, prot, carb, fat | meals | Parcial y fácil de mapear: type→meal_type, name→description, kcal→calories, prot→protein_g, carb→carbohydrates_g, fat→fat_g. Usar la fecha del objeto como consumed_at, sin sustituir fechas históricas por la fecha de importación. |
| Comidas favoritas | favoriteMeals contiene type, name y macros; se usa para volver a registrar una comida | Ninguna | No compatible. Crear tabla de plantillas/favoritos separada. No insertar favoritos en meals porque no son comidas consumidas. |
| Tareas | id, title, date, done | tasks | Parcial. tasks tiene title, due_at, completed, priority, category y description. Mapear date→due_at y done→completed; usar valores por defecto para priority. No inventar categoría ni descripción. |
| Exámenes | id, title, date | Ninguna | No compatible. Crear academic_events (o exams) con user_id, title, event_date y campos opcionales si se necesitan. Mantenerlos diferenciados de tareas. |
| Estudio / Pomodoro | studyMinutesWeek suma 25 minutos al completar un bloque; no guarda sesiones ni fechas individuales | Ninguna | No hay historial. Crear study_sessions con started_at, duration_minutes, session_type y opcionalmente completed_at. El total semanal debería calcularse a partir de sesiones fechadas. El contador acumulado actual no permite reconstruir fechas pasadas. |
| Fotos de progreso | date, weight y dataUrl (incluye imagen codificada en el almacén local) | progress_photos + Storage privado | Parcial. La tabla de metadatos tiene taken_at, caption y storage_path, pero no peso de la foto. Guardar el peso en body_metrics y enlazarlo por fecha/relación, o añadir weight_kg a progress_photos si la UI necesita que cada foto conserve exactamente su peso. La imagen debe convertirse/comprimirse y subirse a Storage privado, nunca a Postgres como Data URL. |
| Historial de peso | weightHistory: date y weight | body_metrics | Compatible en principio: measured_at y weight_kg. Importar solo fechas reales y valores válidos. |
| Objetivos y medidas del perfil | age, height, goal, targetKcal, targetProtein, targetCarbs, targetFat, targetWaterLiters | Ninguna tabla privada | No compatible. Crear user_settings con acceso exclusivo del propietario. Altura/edad y objetivos no deben exponerse en profiles. |
| Amigos | friends contiene IDs locales de cuentas del almacén global; friendCode local | profiles, friend_requests, friendships | No migrar relaciones automáticamente. Los IDs locales no son UUID de Auth y el almacén global mezclaba usuarios. Los amigos deben reenviar/aceptar solicitudes o confirmar vínculo; usar códigos generados por backend. |
| Tema visual | preferencia dark/light en LocalStorage | Ninguna | Mantener local inicialmente; no necesita sincronización. |
| Contraseña/PIN, rol admin y Face ID local | credenciales/roles guardados en el almacén local | Supabase Auth | Excluir totalmente de exportación/importación. No reutilizar PIN ni rol local como autorización. La autorización debe depender de Auth y políticas backend. |

## 3. Cambios de esquema recomendados antes de integrar

Crear una migración posterior (no aplicada todavía) con estas entidades:

1. **user_settings** — una fila por usuario: edad (si se decide conservarla), altura, objetivo, kcal, proteína, carbohidratos, grasa y objetivo de agua. RLS owner-only.
2. **water_entries** — user_id, entry_date, glasses (o amount_ml), created_at; restricción única por usuario y fecha si solo se mantiene un total diario.
3. **gym_routines** — user_id, day_of_week, title, exercises JSONB, created_at, updated_at. Una rutina por usuario y día, si esa es la regla deseada.
4. **favorite_meals** — user_id, meal_type, name/description, calories, protein_g, carbohydrates_g, fat_g, created_at.
5. **academic_events** — user_id, title, event_date, event_type; separar exámenes de tareas.
6. **study_sessions** — user_id, started_at, duration_minutes, session_type, completed_at. No persistir solo un total semanal mutable.
7. **Ajuste opcional de progress_photos** — añadir weight_kg si cada foto debe conservar el peso asociado aunque no exista una medición corporal independiente.

Todas las tablas nuevas deben tener RLS habilitado y políticas owner-only basadas en auth.uid(). No crear políticas públicas para estos datos.

## 4. Reglas de conversión de datos

- Generar UUID nuevos para las filas importadas. Mantener una tabla/archivo de correspondencia entre ID antiguo e ID nuevo durante la migración, especialmente para habit_entries.
- Hábitos: traducir name→title, emoji→icon y days[]→habit_entries solo cuando lastWeekMondayISO esté presente y sea una fecha válida. El índice 0 corresponde al lunes y el 6 al domingo, según la tira semanal de la aplicación.
- Hidratación: convertir cada índice semanal en fecha solo con lastWeekMondayISO; conservar el número de vasos o convertirlo a 250 ml por vaso. No inferir fechas si falta esa referencia.
- Comidas: recorrer las claves YYYY-MM-DD de mealsByDay y crear una fila por comida. Validar macros numéricos; cero es un valor válido.
- Favoritos: importar en favorite_meals, nunca en meals.
- Tareas y exámenes: mantener colecciones separadas y convertir fechas locales a fecha/hora sin cambiar el día por conversiones de zona horaria.
- Fotos: exportar blobs por separado, validar tipo/tamaño, recomprimir en el navegador y eliminar metadatos EXIF/localización cuando sea posible. Subir con ruta que empiece por el UUID autenticado.
- Peso: importar weightHistory con fecha y peso válidos; evitar duplicados por usuario y fecha si se decide esa regla.
- Amigos: no convertir automáticamente IDs locales ni conceder amistades por datos del cliente.
- Credenciales, PIN, rol admin y credenciales Face ID antiguas: excluir.

## 5. Riesgos y comprobaciones pendientes

- La tabla `profiles` tiene SELECT solo propio según la auditoría RLS anterior. Esto puede impedir buscar usuarios por username/friend_code desde el cliente. Diseñar una función RPC limitada que devuelva solo los campos públicos necesarios (por ejemplo username, display_name y friend_code), sin abrir perfiles completos.
- Revisar que las funciones RPC de solicitudes/amistades y retos tengan EXECUTE concedido solo a roles adecuados y validen el usuario actual en el servidor.
- Revisar la función de listado de amigos para confirmar que solo devuelve amistades aceptadas.
- En `challenge_members`, decidir cómo abandonar un reto y cómo eliminar miembros; ahora la auditoría muestra SELECT e INSERT, sin DELETE.
- En `challenge_entries`, revisar la duplicidad/nombres de políticas DELETE y UPDATE; comprobar que el usuario no puede escribir entradas para otro miembro.
- Verificar constraints/índices únicos: username normalizado, friend_code, pareja de amistad ordenada, solicitudes duplicadas, una entrada de hábito por hábito/fecha, y un registro de agua por usuario/fecha.
- Revisar SECURITY DEFINER de todas las funciones: search_path fijo, validación de auth.uid(), privilegios mínimos y grants de EXECUTE.
- Probar aislamiento real con dos cuentas de prueba: lecturas, escrituras, actualizaciones y borrados cruzados deben fallar, incluidas fotos y retos.

## 6. Plan seguro de integración

1. Aprobar el diseño de las tablas faltantes y las reglas de fechas.
2. Preparar migración SQL versionada y revisarla antes de ejecutarla en el proyecto de pruebas.
3. Implementar autenticación Supabase en una copia de trabajo de la app, sin sustituir aún el sistema local.
4. Implementar un exportador local JSON + fotos que no incluya credenciales ni datos sensibles innecesarios.
5. Implementar importador en modo simulación (dry-run) con recuentos, errores y registros ambiguos.
6. Probar exportar, borrar el perfil de prueba y restaurar en un usuario de prueba distinto.
7. Activar escritura cloud por módulos, con pruebas de aislamiento y restauración.
8. Solo después, preparar una versión de transición y pedir aprobación antes de publicar o tocar `main`.

**Estado:** revisión realizada; no se ha modificado el esquema Supabase, no se ha importado información y no se ha tocado `main` ni la web publicada.
