# 💰 Finanzas Personales

App móvil para gestionar tu presupuesto mensual personal. Registra tus activos, deudas, gastos fijos y gastos hormiga, visualiza gráficos y guarda un historial de cada mes en la nube.

---

## Pantallas

| Pantalla | Descripción |
|---|---|
| **Presupuesto** | Ingresa tus activos (Nequi, Uala, efectivo, etc.) y tus deudas/gastos fijos del mes |
| **Gastos Hormiga** | Registra micro gastos por categoría y método de pago |
| **Gráficos** | Visualiza tus gastos hormiga por categoría (pie chart) y gastos fijos (bar chart) |
| **Guardados** | Historial de presupuestos guardados en la nube, con balance neto por mes |

---

## Tecnologías

- **Flutter** — framework UI multiplataforma (Android, iOS, Web)
- **Firebase Auth** — autenticación con Google y modo anónimo
- **Provider** — manejo de estado global
- **fl_chart** — gráficos de torta y barras
- **REST API (Vercel + Next.js)** — backend serverless que expone los endpoints de presupuestos
- **MongoDB Atlas** — base de datos en la nube donde se persisten los presupuestos

---

## Arquitectura

```
Flutter App
    │
    ├── Firebase Auth (JWT)
    │
    └── REST API → https://finanzas-jj.vercel.app
            │
            └── MongoDB Atlas
```

La app nunca se conecta directamente a la base de datos. Todas las operaciones pasan por la API REST, que valida el token de Firebase antes de responder.

---

## Estructura del proyecto

```
lib/
├── main.dart                  # Entry point y router raíz
├── firebase_options.dart      # Configuración de Firebase por plataforma
├── models/
│   ├── budget_item.dart       # BudgetItem, Liability, CreditCard, MicroExpense
│   └── monthly_budget.dart    # Modelo completo de un mes
├── services/
│   ├── auth_service.dart      # Firebase Auth + Google Sign-In
│   └── api_service.dart       # Llamadas HTTP al backend
├── state/
│   └── app_state.dart         # Estado global (ChangeNotifier)
├── screens/
│   ├── login_screen.dart
│   ├── budget_screen.dart
│   ├── micro_expenses_screen.dart
│   ├── charts_screen.dart
│   └── saved_budgets_screen.dart
└── theme/
    └── app_theme.dart         # Tema visual centralizado
```

---

## Correr el proyecto

```bash
# Instalar dependencias
flutter pub get

# Correr en modo debug
flutter run
```

> Requiere tener Flutter instalado y un dispositivo/emulador conectado.

---

## Autenticación

Soporta dos modos:
- **Google Sign-In** — sesión completa con persistencia en la nube
- **Modo anónimo** — permite usar la app sin cuenta; los datos se pueden migrar luego vinculando una cuenta de Google
