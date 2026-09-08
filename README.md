# Py55 — Aplicación Móvil de Mototaxis con Flutter y Firebase

**Py55** es una plataforma completa de transporte y solicitud de mototaxis en tiempo real desarrollada en **Flutter** con arquitectura guiada por características (*Feature-First Architecture*) y respaldada por servicios de **Firebase** (Auth, Firestore, Realtime Database, Storage y Cloud Functions).

---

## 🚀 Requisitos e Instalación

### Prerrequisitos
- **Flutter SDK**: `>= 3.3.4 < 4.0.0`
- **Dart SDK**: Compatible con Flutter 3.22+
- **Node.js**: `>= 18.0.0` (para desplegar las Cloud Functions)
- **Firebase CLI**: `npm install -g firebase-tools`

### Pasos de Instalación
1. **Clonar el repositorio y descargar dependencias**:
   ```bash
   git clone https://github.com/Systems-Engineer-01/Py-55.git
   cd Py-55
   flutter pub get
   ```

2. **Configuración de Firebase**:
   - Inicializa tu proyecto en Firebase Console.
   - Genera el archivo `lib/firebase_options.dart` ejecutando:
     ```bash
     flutterfire configure
     ```

3. **Configuración de Google Maps API Key**:
   - Reemplaza `YOUR_GOOGLE_MAPS_API_KEY_HERE` en los siguientes archivos:
     - **Android**: `android/app/src/main/AndroidManifest.xml`
     - **iOS**: `ios/Runner/Info.plist`
     - **Constantes**: `lib/core/constants.dart` (`googleMapsApiKey`)

4. **Despliegue de Cloud Functions**:
   ```bash
   cd functions
   npm install
   firebase deploy --only functions
   ```

5. **Despliegue de Reglas de Seguridad**:
   ```bash
   firebase deploy --only firestore:rules,database
   ```

---

## 🛠️ Estructura del Proyecto

El código fuente en `lib/` está organizado por características (*features*) para máxima escalabilidad y mantenibilidad:

```
py55/
├── android/                   # Configuración nativa Android y permisos GPS/Maps
├── ios/                       # Configuración nativa iOS y permisos de ubicación
├── database.rules.json        # Reglas de seguridad para Realtime Database
├── firestore.rules            # Reglas de seguridad para Cloud Firestore
├── functions/                 # Cloud Functions de Firebase en Node.js
│   ├── index.js               # Trigger onCreate para cálculo de calificación promedio
│   └── package.json
├── lib/
│   ├── core/                  # Configuración base, constantes y diseño visual
│   │   ├── constants.dart     # Constantes globales (roles, colecciones, API keys)
│   │   ├── firebase_init.dart # Inicialización de Firebase Core
│   │   └── theme.dart         # Sistema de diseño global (Material 3)
│   ├── features/              # Módulos del sistema por funcionalidad
│   │   ├── auth/              # Autenticación celular + OTP, roles y AuthProvider
│   │   │   ├── auth_provider.dart
│   │   │   ├── auth_service.dart
│   │   │   └── screens/
│   │   ├── fare/              # Calculadora de distancia Haversine y tarifas (min/max)
│   │   │   └── fare_calculator_service.dart
│   │   ├── map/               # Geolocalización en vivo, Realtime DB y mapas
│   │   │   ├── location_service.dart
│   │   │   ├── map_service.dart
│   │   │   └── screens/
│   │   ├── rating/            # Calificaciones de viaje de 5 estrellas
│   │   │   ├── rating_service.dart
│   │   │   └── screens/
│   │   ├── ride_request/      # Solicitud de viajes, aceptación atómica y tracking
│   │   │   ├── ride_request_service.dart
│   │   │   └── screens/
│   │   └── verification/      # Carga de documentos de verificación y Panel Admin
│   │       ├── screens/
│   │       └── verification_service.dart
│   ├── main.dart              # Punto de entrada de la app con AuthWrapper reactivo
│   └── shared/                # Modelos de datos y widgets reutilizables
│       ├── models/
│       │   ├── driver_profile_model.dart
│       │   ├── ride_request_model.dart
│       │   └── user_model.dart
│       └── widgets/
│           └── verified_badge.dart
├── test/                      # Pruebas unitarias
│   └── fare_calculator_service_test.dart
└── pubspec.yaml
```

---

## 🧪 Pruebas Unitarias

Para ejecutar la suite de pruebas unitarias automáticas:
```bash
flutter test
```

---

## 🛡️ Reglas de Seguridad

- **Firestore (`firestore.rules`)**:
  - Garantiza que solo administradores (`esAdmin == true`) puedan modificar el estado de verificación o el flag de verificación de los conductores.
  - Asegura que la creación de viajes y calificaciones sea válida únicamente para usuarios autenticados.
- **Realtime Database (`database.rules.json`)**:
  - Restringe la escritura de la ubicación activa `ubicaciones_activas/$userId` únicamente al usuario correspondiente a dicho `$userId`.
