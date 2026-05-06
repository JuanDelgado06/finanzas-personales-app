# 💰 Finanzas Personales

Una aplicación móvil Flutter para gestionar tu dinero, presupuestos mensuales y deudas de forma intuitiva y visual. Registra tus activos, tarjetas de crédito, gastos fijos y gastos diarios, visualiza análisis completos y sincroniza todo en la nube.

**Disponible para**: Android, iOS y Web

---

## ✨ Características Principales

### 📊 Gestión de Presupuesto Mensual
- **Activos**: Registra tus cuentas bancarias, billeteras digitales (Nequi, Uala, etc.) y efectivo disponible
- **Dinero que te deben**: Realiza seguimiento a deudas de terceros hacia ti
- **Gastos fijos**: Anota pagos recurrentes (servicios, arriendo, seguros, etc.)
- **Tarjetas de crédito**: Gesiona independientemente tus créditos activos

### 🏧 Tarjetas de Crédito
Cada tarjeta almacena:
- **Cupo total**: Límite de crédito disponible
- **Saldo actual**: Monto adeudado actualmente
- **Pago mínimo y total**: Cuotas que debes pagar
- **Fecha de corte**: Cuándo se cierra el ciclo
- **Fecha de pago**: Vencimiento de la deuda
- **Indicador visual**: Barra de utilización de cupo con diseño elegante

### 💸 Gastos Hormiga (Micro gastos)
- Registra gastos pequeños del día a día
- Categorías: Comida, Transporte, Mercado, Salud, Hogar, Otros
- Selecciona método de pago: tus cuentas o tarjetas de crédito
- Sincronización automática mientras escribes

### 📈 Análisis y Reportes
- **Resumen financiero**: Gráfico de torta con desglose de gastos por categoría
- **Balance neto**: Activos - Pasivos totales
- **Balance parcial**: Activos - (Pasivos mínimos), ideal para planificar
- **Desglose por método de pago**: Visualiza cuánto gastaste en cada cuenta/tarjeta
- **Indicadores clave**: Gastos hormiga, gastos fijos, utilización de crédito

### 💾 Almacenamiento en la Nube
- Guarda múltiples presupuestos mensuales
- Sincroniza automáticamente con Firebase
- Historial completo con fechas de creación
- Funciona offline: los datos se sincronizan cuando hay conexión
- Migra datos anónimos al crear una cuenta

---

## 🎯 Casos de Uso

| Caso | Descripción |
|------|-----------|
| **Planificación mensual** | Ingresa todos tus ingresos, deudas y presupuestos estimados al inicio del mes |
| **Seguimiento diario** | Registra gastos del día (comida, transporte) en tiempo real |
| **Gestión de crédito** | Monitorea cupo disponible y pagos pendientes de múltiples tarjetas |
| **Análisis de patrones** | Revisa históricos para identificar dónde gastas más |
| **Comparación mensual** | Carga presupuestos previos para ver si mejoraste tu situación financiera |

---

## 🔧 Stack Técnico

| Componente | Tecnología |
|---|---|
| **Frontend** | Flutter 3.x, Dart |
| **UI/UX** | Phosphor Icons, fl_chart, Material Design |
| **Estado global** | Provider |
| **Autenticación** | Firebase Auth + Google Sign-In |
| **Persistencia local** | SharedPreferences, SQLite |
| **Backend** | REST API (Next.js en Vercel) |
| **Base de datos** | MongoDB Atlas |
| **Hosting** | Vercel (API), Firebase (Auth) |

---

## 📐 Arquitectura

```
┌─────────────────────────────────────────┐
│         Flutter App (Local)             │
│  • UI Screens                           │
│  • State Management (Provider)          │
│  • Local Cache (SharedPreferences)      │
│  • Offline Support                      │
└────────────┬────────────────────────────┘
             │ HTTPS
    ┌────────▼────────┐
    │  Firebase Auth  │
    │  (JWT Token)    │
    └─────────────────┘
             │
    ┌────────▼────────────────────┐
    │   REST API                  │
    │   (finanzas-jj.vercel.app)  │
    │   • Token validation        │
    │   • Budget CRUD operations  │
    │   • Data transformation     │
    └────────┬────────────────────┘
             │
    ┌────────▼────────────────────┐
    │    MongoDB Atlas            │
    │    (Cloud Database)         │
    │    • Users data             │
    │    • Budget history         │
    └─────────────────────────────┘
```

---

## 📂 Estructura del Proyecto

```
lib/
├── main.dart                          # Entry point y navegación principal
├── firebase_options.dart              # Configuración de Firebase
├── models/
│   ├── budget_item.dart               # BudgetItem (activo/deuda)
│   │                                  # Liability (gasto fijo)
│   │                                  # CreditCard (tarjeta de crédito)
│   │                                  # MicroExpense (gasto hormiga)
│   └── monthly_budget.dart            # MonthlyBudget (presupuesto completo)
├── services/
│   ├── auth_service.dart              # Firebase Auth + Google Sign-In
│   │                                  # Sesiones anónimas y vinculación
│   └── api_service.dart               # HTTP client → backend REST API
├── state/
│   └── app_state.dart                 # AppState (ChangeNotifier)
│                                      # • CRUD de formulario
│                                      # • Cálculos (totales, balances)
│                                      # • Sincronización automática
│                                      # • Caché offline
├── screens/
│   ├── login_screen.dart              # Autenticación y modo anónimo
│   ├── onboarding_screen.dart         # Primer acceso
│   ├── budget_screen.dart             # Presupuesto mensual
│   │                                  # Tarjetas de crédito (diseño realista)
│   │                                  # Gastos fijos
│   │                                  # Activos y dinero adeudado
│   ├── micro_expenses_screen.dart     # Gastos hormiga con categorías
│   ├── charts_screen.dart             # Análisis y gráficos
│   └── saved_budgets_screen.dart      # Historial de presupuestos
└── theme/
    └── app_theme.dart                 # Colores, tipografía, decoraciones
```

---

## 🚀 Guía de Instalación

### Requisitos Previos
- Flutter 3.x o superior
- Dart 3.x o superior
- Android SDK (para Android) / Xcode (para iOS)
- Cuenta de Firebase con Google Sign-In habilitado

### Pasos

1. **Clonar el repositorio**
   ```bash
   git clone https://github.com/josed/finanzas_personales.git
   cd finanzas_personales
   ```

2. **Instalar dependencias**
   ```bash
   flutter pub get
   ```

3. **Configurar Firebase**
   - Crea un proyecto en [Firebase Console](https://console.firebase.google.com)
   - Descarga el archivo de configuración (`google-services.json` para Android, `GoogleService-Info.plist` para iOS)
   - Coloca en las carpetas correspondientes

4. **Ejecutar la app**
   ```bash
   # Debug (Android/iOS)
   flutter run

   # Release (APK)
   flutter build apk --release

   # Web
   flutter run -d chrome
   ```

---

## 📱 Pantallas y Flujos

### 1️⃣ Autenticación
- Opción de iniciar sesión con Google
- Modo anónimo para probar la app sin cuenta
- Migración automática de datos al vincular Google

### 2️⃣ Presupuesto (Pantalla Principal)
Estructura modular por secciones expandibles:
- **Activos**: 4 cuentas por defecto (Nequi, Uala, Davivienda, Efectivo)
- **Dinero Adeudado**: Deudas de terceros
- **Gastos Fijos**: Pagos recurrentes (servicios, arriendo, etc.)
- **Tarjetas de Crédito**: Sección independiente con diseño visual realista
  - Muestra saldo, cupo, porcentaje de utilización
  - Expandible para editar todos los detalles

### 3️⃣ Gastos Hormiga
- Botón flotante para agregar gasto rápidamente
- Entrada en forma de modal con:
  - Monto (teclado numérico)
  - Categoría (dropdown)
  - Método de pago (activos o tarjetas)
- Agrupación por categoría con collapse/expand
- Estado de guardado en tiempo real

### 4️⃣ Gráficos
- **Pie Chart**: Gastos hormiga por categoría (porcentajes)
- **Datos clave**: Categoría con mayor gasto
- **Desglose por método de pago**: Tabla con totales
- **Resumen financiero**: Balance neto, activos, pasivos, etc.

### 5️⃣ Presupuestos Guardados
- Lista de todos los presupuestos guardados
- Información: fecha, balance neto, detalles
- Acciones: cargar (aplica al formulario) o eliminar
- Pull-to-refresh para sincronizar

---

## 💡 Características Avanzadas

### Cálculos Automáticos
- **Total de Activos**: Suma de dinero disponible menos lo gastado en hormiga
- **Total de Pasivos**: Pago total de tarjetas + gastos fijos + gastos hormiga no cubiertos
- **Balance Neto**: Activos - Pasivos (lo que realmente tienes)
- **Balance Parcial**: Activos - (Pagos mínimos), para planificación conservadora

### Sincronización Offline
- Los cambios se guardan localmente de inmediato
- Si hay conexión, se sincronizan automáticamente con la API
- Si no hay conexión, se encolan y se envían cuando vuelva la conexión
- Indicadores visuales de estado de sincronización

### Métodos de Pago Flexibles
- Los gastos hormiga se pueden asignar a cualquier activo o tarjeta de crédito
- El sistema automáticamente resta de la cuenta correspondiente

---

## 🔐 Seguridad

- **JWT Token**: Cada solicitud usa token de Firebase
- **Validación backend**: La API valida el token antes de responder
- **No hay credenciales en el cliente**: Todo se maneja vía Firebase
- **HTTPS**: Todas las comunicaciones están cifradas
- **Datos privados**: Cada usuario solo ve sus propios datos

---

## 🎨 Diseño Visual

- **Paleta de colores**: Tonos oscuros con acentos de azul cian
- **Tipografía**: Fuentes modernas y legibles
- **Iconos**: Phosphor Icons para consistencia
- **Tarjetas de Crédito**: Diseño elegante con gradientes y efectos de profundidad
- **Tema oscuro**: Modo noche amigable con los ojos

---

## 🧪 Testing

```bash
# Ejecutar tests
flutter test

# Coverage
flutter test --coverage
```

---

## 🤝 Contribuciones

Las contribuciones son bienvenidas. Para cambios importantes:

1. Fork el proyecto
2. Crea una rama (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

---

## 📝 Licencia

Este proyecto está bajo licencia MIT. Ver `LICENSE` para más detalles.

---

## 📞 Contacto

**José David**
- GitHub: [@josed](https://github.com/josed)
- Email: contacto@ejemplo.com

---

## 🗺️ Roadmap

- [ ] Presupuestos compartidos con otros usuarios
- [ ] Alertas de límite de gasto
- [ ] Exportar presupuestos a PDF
- [ ] Análisis predictivo de gastos
- [ ] Integración con bancos reales (API)
- [ ] Modo multi-divisa
- [ ] Widgets de home screen
- [ ] Sincronización con Google Sheets

---

**Última actualización**: Mayo 5, 2026
