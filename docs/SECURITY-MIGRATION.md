# HabitPulse — plan de migración de seguridad y datos

## Estado de partida

Auditoría del `index.html` en la rama `main` (antes de modificar la aplicación):

- La aplicación está construida como un único HTML con JavaScript en cliente.
- El almacenamiento local serializa el objeto completo `globalStore` en LocalStorage.
- La integración Firebase solo se inicializa si existe la variable global `__firebase_config`. GitHub Pages no proporciona esa variable por sí mismo; por tanto, no se debe asumir que la nube esté activa en el despliegue actual.
- Cuando se activa, la integración sincroniza el objeto completo de usuarios con un único documento Firestore compartido. No es una separación de datos por cuenta.
- El registro y el inicio de sesión actuales comparan contraseñas en el cliente y guardan el valor de contraseña/PIN dentro de los datos de usuario.
- Hay una cuenta administradora y credenciales de respaldo definidas en el JavaScript. No deben permanecer como mecanismo de autenticación.
- El panel de administración muestra actualmente los PIN de las cuentas.
- Los amigos y el ranking leen directamente los perfiles de la colección global local.
- Las fotos de progreso se almacenan como Data URLs dentro del objeto de usuario.

## Principios de la migración

1. No sobrescribir ni borrar los datos existentes durante la transición.
2. No publicar cambios de autenticación hasta disponer de un proyecto Firebase configurado y reglas de seguridad verificadas.
3. Cada usuario debe autenticarse con Firebase Authentication; nunca validar contraseñas en JavaScript ni guardar contraseñas en Firestore/LocalStorage.
4. Guardar los datos privados en documentos separados por UID autenticado, por ejemplo `users/{uid}`, con reglas que permitan leer/escribir solo al propietario.
5. Los datos visibles a amigos deben publicarse mediante un perfil público mínimo y consentido; no exponer hábitos detallados, peso, fotos, comidas, tareas o credenciales.
6. Los códigos de amigo deben resolverse mediante un mecanismo controlado, evitando descargar la lista completa de usuarios.
7. Las fotos deben migrarse a Firebase Storage con reglas por UID y límites de tamaño/tipo.
8. La aplicación debe seguir funcionando con una sesión cerrada y mostrar errores claros si no hay conexión; no debe fingir que está sincronizando.

## Fases propuestas

### Fase 1 — Preparación (esta rama)

- Mantener intacta la rama `main` y el despliegue actual.
- Documentar el estado inicial y las dependencias externas.
- Preparar una migración compatible, con copia de seguridad exportable antes de tocar los datos.

### Fase 2 — Firebase

- Configurar Firebase Authentication (correo/contraseña o proveedor elegido).
- Configurar Firestore y Storage.
- Publicar y probar reglas de seguridad antes de conectar la aplicación.
- Añadir configuración web Firebase no secreta a la aplicación. No incluir claves privadas, service accounts ni tokens de administrador en el repositorio.

### Fase 3 — Datos y migración

- Crear un modelo de datos por UID.
- Importar los datos locales de la cuenta del propietario tras autenticación y confirmación explícita.
- Mantener un flujo de exportación/restauración y verificar recuentos antes de retirar el formato antiguo.
- Eliminar la sincronización del documento global solo después de verificar la migración.

### Fase 4 — Social y lanzamiento

- Implementar perfiles compartidos mínimos, solicitudes/amistades y ranking con métricas consentidas.
- Migrar fotos a Storage.
- Probar dos cuentas en dos dispositivos y comprobar aislamiento, reglas y conflictos de sincronización.
- Solo entonces integrar la rama en `main` y publicar.

## Información necesaria para continuar

Antes de implementar la autenticación real, confirmar si ya existe un proyecto Firebase para HabitPulse. Si existe, basta con indicar el nombre/ID del proyecto y si Authentication, Firestore y Storage están habilitados. La configuración web Firebase es pública por diseño, pero las reglas de seguridad no lo son: no compartir contraseñas, tokens, claves privadas ni archivos de service account.
