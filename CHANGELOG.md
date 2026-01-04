# Changelog

All notable changes to the Salsa CRM project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-01-01

### Added - גרסה ראשונה

#### Core Features
- **Authentication System**
  - Email/Password authentication via Firebase
  - Role-based access control (Admin, Instructor)
  - Secure logout functionality

- **CRM Dashboard**
  - Real-time statistics display
  - Last session attendance rate (Pie chart)
  - Exercise progress tracker (Progress bar)
  - Students with 3 consecutive absences counter
  - Smart alerts system
  - Birthday reminders
  - Pull-to-refresh functionality

- **WhatsApp Message Builder**
  - Template-based message system
  - Random template selection from database
  - 6 message categories (Regular, Pace, Afro, Pachanga, LA Prep, Shines)
  - Event locking mechanism (first-come-first-served)
  - Dynamic placeholders: `{{BIRTHDAY_BLOCK}}`, `{{SENDER_NAME}}`
  - Manual message editing
  - Copy to clipboard
  - Direct WhatsApp opening with pre-filled text
  - WhatsApp group link integration
  - Wednesday & Saturday notifications

- **Exercise Management**
  - 15 pre-defined Salsa exercises
  - Completion tracking
  - "Next lesson" preview (review + new exercises)
  - Progress percentage calculation
  - Auto-sync with Dashboard

- **Attendance Recording**
  - Student list with search
  - Lesson type selection
  - Quick check-in (tap on row)
  - Real-time statistics (total, present, percentage)
  - Save with timestamp, instructor name, lesson type
  - Automatic calculations:
    - Attendance rate per student
    - Consecutive absence tracking

- **Template Management (Admin)**
  - Add new message templates
  - Edit existing templates
  - Activate/deactivate templates
  - Category organization
  - Database storage (not Excel)

#### Technical Implementation
- **Framework**: Flutter 3.0+
- **State Management**: Provider
- **Backend**: Firebase (Firestore, Auth, FCM)
- **UI**: Material Design 3 with RTL support
- **Charts**: fl_chart package
- **Notifications**: Local + Push (FCM)

#### Firebase Collections
- `users` - User management
- `students` - Student records
- `attendanceSessions` - Attendance sessions
- `attendanceRecords` - Individual attendance records
- `exercises` - Exercise tracking
- `messageTemplates` - Message templates
- `messageEvents` - Message sending events
- `settings` - App settings (optional)

#### Security
- Firestore Security Rules implemented
- Role-based access control
- Authentication required for all operations

#### Documentation
- README.md - Main documentation
- SETUP_GUIDE.md - Detailed setup instructions
- QUICKSTART.md - Quick start guide
- PROJECT_SUMMARY.md - Project overview
- EXAMPLE_TEMPLATES.md - 40+ message templates
- CHANGELOG.md - This file

### Known Limitations
- No automatic WhatsApp sending (platform restrictions)
- Manual student management (add via Firestore Console)
- Single studio support
- Hebrew language only (RTL)

### Future Enhancements (Roadmap)
- Student management UI
- Advanced reports (PDF export)
- Excel data export
- Automated messaging via Cloud Functions
- Payment tracking
- Multi-studio support
- Feedback system

---

## Version History

**Version 1.0.0** - Initial Release (January 2026)
- Full CRM functionality
- WhatsApp integration
- Attendance & Exercise tracking
- Admin panel

---

## Upgrade Instructions

### From version X.X.X to 1.0.0

This is the initial release. No upgrade needed.

For future upgrades, instructions will be added here.

---

## Breaking Changes

None (initial release)

---

## Contributors

- Development Team
- Salsa Instructors Team (feedback & testing)

---

**For more details, see the [README](README.md)**
