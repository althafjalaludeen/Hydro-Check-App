# Changelog

All notable changes to the HydroCheck project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [v2.3.0] - 2026-03-27

### Added
- **3-Tier Role-Based Access Control** — Admin, Subordinate (Staff), and End User roles
- **Subordinate Dashboard** — Dedicated dashboard for staff members
- **Zone Management** — Zone-based water monitoring and management
- **Ticketing System** — Communication and issue tracking between users and admins
- **Announcements** — Admin can broadcast announcements to users
- **Staff Management** — Admin can manage subordinate/staff accounts
- **Data Export** — PDF and Excel export capabilities for reports
- **Test History Page** — View historical water quality test data
- **Admin Users Tab** — Admin panel for managing all users
- **Firebase Services** — Full Firebase integration for authentication, devices, alerts, and water readings
- **Firmware** — ESP32 firmware for water quality sensors (Arduino & PlatformIO)
- **App Logo** — Custom app icon and branding assets

### Changed
- Upgraded from basic water monitoring app to a **Municipal Smart Water Management Platform**
- Refactored `AdminDashboard` with enhanced device management and user oversight
- Improved `UserDashboard` with zone-aware monitoring
- Enhanced `AuthenticationPages` with role-based login/signup flows
- Updated Android build configuration and manifest
- Updated app icons for all DPI levels

### Removed
- Removed iOS-specific generated files (Flutter ephemeral configs)

---

## [v1.0.0] - 2026-02-20

### Added
- **Initial Release** — Hydro Check Water Quality Monitoring App
- User authentication (login/signup)
- Device management (add, view, monitor IoT water sensors)
- Admin dashboard with device overview
- User dashboard with personal device monitoring
- Water quality reading history
- Device location tracking
- Mobile number and alert notifications
- Firebase backend integration
- Android, iOS, Web, and Windows platform support

---

[v2.3.0]: https://github.com/althafjalaludeen/Hydro-Check-App/compare/v1.0.0...v2.3.0
[v1.0.0]: https://github.com/althafjalaludeen/Hydro-Check-App/releases/tag/v1.0.0
