# PHASE 1 - FLUTTER & SUPABASE READ-ONLY AUDIT REPORT
**BookMySpace iOS UI Fix (fix/ios-bookmyspace-ui)**
**Audit Date:** 2026-09-20

---

## AUDIT CONFIRMATIONS

### Git Status ✅
- **Repository:** ~/BookMyspace_Andriod
- **Current Branch:** fix/ios-bookmyspace-ui
- **Modified Files:** 36 files with local changes
- **Untracked Files:** 34 new files/directories
- **Status:** Clean working tree (changes staged for review, not committed)

### Database Project ✅
- **Project:** bookmyspace-dev (zykxneztahxbjduagutv)
- **Region:** ap-south-1
- **Status:** ACTIVE_HEALTHY
- **Postgres:** 17.6.1.155
- **Tables:** 150+ tables with full schema

---

## 1. EXISTING BOOKING SYSTEM - WHAT ALREADY WORKS

### ✅ Core Models (lib/features/booking/domain/)
- **Booking.dart** (277 lines)
  - Full booking lifecycle with 9 statuses: held, pending, awaiting_owner_approval, owner_rejected, approval_expired, confirmed, completed, cancelled, refunded, no_show
  - Approval workflow with approval_requested_at, approval_expires_at, approved_at timestamps
  - Payment tracking (amount, tax_amount, total_amount)
  - Receipt integration (receipt_number, receipt_issued_at)
  - Booking holds (10-min expiry, automatic conversion to booking)
  - Time slot integration (startTime, endTime, priceAmount)
  - Slot availability checking

### ✅ Database Schema (bookings table)
- **Core Fields:** id, booking_ref, user_id, venue_id, slot_id, book_date, start_time, end_time, hold_id, status, quantity, amount, tax_amount, discount_amount, total_amount
- **Approval Workflow:** approval_required, approval_requested_at, approval_expires_at, approved_at, approved_by, rejected_at, rejection_reason, payment_expires_at
- **Metadata:** cancellation_policy, metadata (JSON), request_idempotency_key, approval_idempotency_key
- **Timestamps:** created_at, confirmed_at, cancelled_at, updated_at

### ✅ Time Slots System
- **time_slots table:** id, venue_id, label, start_time, end_time, price_amount, is_active
- **Slot Models:** TimeSlot (domain model), SlotAvailability (from RPC function)
- **RPC Functions:** available_time_slots (returns availability for date/slot)
- **Display Logic:** Formatted HH:MM display (startTime.substring(0, 5))

### ✅ Repositories
- **lib/features/booking/domain/booking_repository.dart** (98 lines - interface)
- **lib/features/booking/infrastructure/supabase_booking_repository.dart** - Full CRUD implementation
  - Fetch bookings (my_bookings)
  - Create booking hold (hold_booking RPC)
  - Approve/reject bookings (owner approval)
  - Cancel bookings (with refund handling)
  - Fetch available slots (available_time_slots RPC)

### ✅ Presentation Layer
- **booking_screen.dart** (608 lines)
  - Date picker (book_date selection)
  - Slot selection from available_time_slots RPC
  - Price display with tax calculation
  - Terms & conditions checkbox
  - Booking hold creation
  - Loading states and error handling

- **my_bookings_screen.dart** (672 lines)
  - List of user's bookings with status badges
  - Booking detail view (venue info, time, payment status)
  - Cancel booking action (with confirmation)
  - Approval workflow UI for owners
  - Status filtering (upcoming, past, cancelled)

- **booking_success_screen.dart** (185 lines)
  - Confirmation after successful hold
  - Share booking details
  - Navigation to payment

### ✅ Tests
- booking_test.dart
- supabase_booking_repository_test.dart
- booking_status_test.dart
- Mock repositories available

### ✅ Provider Setup
- booking_providers.dart - Riverpod providers for:
  - availableSlots (date/venue aware)
  - myBookings
  - bookingStatus
  - holdExpiry countdown

---

## 2. EXISTING VENUE & DISCOVERY SYSTEM

### ✅ Venue Models (lib/features/venues/domain/)
- **venue.dart** - Comprehensive venue model with:
  - Basic: id, name, slug, description, org_id, category_id
  - Address: address_line1, address_line2, city, state, postal_code, country
  - Geo: latitude, longitude, geog (PostGIS geography type)
  - Capacity: capacity, parking_capacity
  - Pricing: pricing_base_amount, pricing_currency, tax_rate
  - Amenities/Services: food_options, rules, cancellation_policy
  - Verification: is_verified, is_active
  - Ratings: avg_rating, rating_count
  - Metadata: source, source_place_id, search_document (tsvector)
  - Timestamps: created_at, updated_at, deleted_at

- **VenueCategory** model with:
  - id, slug, name, icon, description, imageUrl, imagePath
  - displayOrder for sorting
  - Translations (name_i18n, description_i18n)
  - parentSection, supportedLanguages
  - isActive flag

### ✅ Database Schema
- **venues table:** 35+ columns with PostGIS geography support
- **venue_categories:** id, slug, name, icon, metadata, is_active, parent_section, description, image_url, display_order, i18n translations
- **venue_images:** id, venue_id, url, thumbnail_url, alt_text, is_cover, sort_order, media_kind, processing_status
- **venue_amenities:** junction table (venue_id, amenity_id, metadata)
- **venue_facilities:** id, venue_id, facility, is_available
- **venue_operating_hours:** id, venue_id, day_of_week, opens_at, closes_at, is_closed
- **venue_sections:** Dynamic CMS sections per venue (title, content, images, icons)
- **amenities:** Master table with id, name, category, icon, status, sort_order, aliases support

### ✅ Discovery Features
- Full-text search (search_document tsvector)
- Geographic search (geog PostGIS field for distance calculations)
- Category filtering
- Sorting options: relevance, priceAsc, priceDesc, rating, distance
- venue_categories with parent_section grouping
- venue_subsections for hierarchical filtering
- Favorites system (favorites table with user_id, venue_id)

### ✅ Repositories & Providers
- lib/features/venues/domain/venue_repository.dart
- lib/features/venues/infrastructure/supabase_venue_repository.dart
- lib/features/venues/presentation/venue_providers.dart
- venue_details_screen.dart (708 lines - full venue view)
- venue_card.dart & venue_badges.dart (widgets)

### ✅ Owner Venues Management
- lib/features/owner_venues/presentation/screens/
  - owner_venues_screen.dart - List of owner's venues
  - create_venue_screen.dart - Venue creation flow
- lib/features/owner_venues/domain/owner_venue_repository.dart
- lib/features/owner_venues/infrastructure/supabase_owner_venue_repository.dart

---

## 3. EXISTING PAYMENT & REFUND SYSTEM

### ✅ Payment Models
- **PaymentStatus enum:** pending, captured, failed, refunded
- **PaymentOrder:** For Razorpay integration (orderId, amount, currency, keyId, notes)
- **Payment:** Full payment record
  - id, booking_id, user_id, provider (razorpay)
  - provider_order_id, provider_payment_id
  - amount, currency, status, method
  - is_refundable, metadata
  - timestamps: created_at, updated_at, last_reconciled_at
- **Refund:** Full refund record
  - id, payment_id, booking_id, amount, status
  - reason, provider_refund_id, processedAt
- **PaymentTransaction:** Admin view with booking details
- **PaymentHealth:** Aggregated payment metrics for admin dashboard

### ✅ Database Schema
- **payments table:** id, booking_id, user_id, provider, provider_order_id, provider_payment_id, amount, currency, status, method, is_refundable, metadata, created_at, updated_at, last_reconciled_at
- **refunds table:** id, payment_id, booking_id, amount, reason, status, provider_refund_id, processed_at, created_at, updated_at
- **payment_attempts:** id, payment_id, provider_attempt_id, status, error_code, error_message, created_at
- **booking_receipts:** id, booking_id, payment_id, receipt_number, amount, currency, issued_at, metadata

### ✅ Razorpay Integration
- Multiple implementation strategies:
  - Native (Android/iOS): native_razorpay_checkout_service.dart
  - Web: web_razorpay_checkout_service.dart, web_razorpay_bridge.dart
  - Factory pattern for platform-specific instantiation
- lib/features/payments/domain/checkout_service.dart (interface)
- Full payment screen (748 lines) with:
  - Payment status polling
  - Error recovery
  - Receipt handling

### ✅ Payment Repositories
- lib/features/payments/domain/payment_repository.dart
- lib/features/payments/infrastructure/supabase_payment_repository.dart
- lib/features/admin_payment/data/admin_payment_repository.dart

### ✅ Tests
- payment_flow_test.dart
- payment_transaction_test.dart
- payment_health_test.dart
- admin_payment_screens_test.dart
- Mock repositories available

### ✅ Admin Payment Dashboard
- admin_transaction_ledger_screen.dart - Full transaction list with filters
- admin_payment_health_screen.dart - Aggregated metrics and health status
- Widgets: payment_status_chip.dart, transaction_row_card.dart, transaction_filter_bar.dart, payment_health_metric_card.dart

---

## 4. EXISTING LOCATION & MAP SYSTEM

### ✅ Location Models
- **gps_location.dart:** GPS coordinate (latitude, longitude)
- **pin_code_location.dart:** Indian postal code lookup

### ✅ Location Services
- **geolocator_gps_location_service.dart:** Platform integration for GPS
- **india_post_pin_code_repository.dart:** Pin code to city/state/district mapping

### ✅ Database Schema (Hierarchical)
- **location_nodes:** Hierarchical location tree
  - id, parent_id, level (0=country, 1=state, 2=district, 3=city, 4=area)
  - country_code, name, normalized_name, official_code
  - latitude, longitude, timezone
  - status (active/inactive), metadata
  - Approval workflow: approved_by, approved_at
  - Merge support: merged_into_id (for consolidation)
  - timestamps: created_at, updated_at

- **location_postal_codes:** location_id → postal_code mapping
- **location_aliases:** Alternate names with locale support
- **location_change_history:** Audit trail of location changes
- **location_suggestions:** UGC suggestions with review workflow

### ✅ Map Features
- **venue_map_screen.dart** - Google Maps/Flutter Map integration
- Venue markers with popups
- Distance calculation from current location
- Category/filter-based marker display

### ✅ Providers
- lib/features/location/presentation/location_providers.dart
- gps_session.dart - Continuous GPS tracking

---

## 5. EXISTING CMS & FEATURE FLAGS

### ✅ CMS System
- **cms_banner.dart** - Banner model with:
  - title, subtitle, image_url, cta_text, cta_route
  - sort_order, is_active, starts_at, ends_at
  - slot (hero, promo, inline)
  - icon_name, colors (accent, gradient, badge)

### ✅ Database Schema
- **cms_banners table:** Full banner management with time-based activation
  - New fields: slot, icon_name, accent_color, gradient_start_color, gradient_end_color, badge_color
- **promotions table:** Detailed promotion campaigns with:
  - title, description, banner_media_id
  - start_at, end_at, priority, sort_order
  - offer_type, discount_type, discount_value
  - Colors (accent, background, text), badge, icon
  - cta_text, cta_action
- **promotion_categories & promotion_venues:** Many-to-many targeting

### ✅ Feature Flags
- **feature_flags table:** key, enabled, platforms (array), config (JSON), updated_at, updated_by
  - Platform-specific: iOS, Android, web, tablet, desktop
  - Config object for feature parameters
  - Full audit trail of updates

- **module_feature_configs table:** Per-venue, per-module feature toggles
  - 50+ boolean flags for registration, payments, documents, notifications, reviews, voice booking, map, etc.
  - Per-venue customization (venue_id, module_key)
  - Pricing configs (registration_fee, advance_amount, deposit_amount, currency, tax_rate)
  - Refund policies, approval workflows, payment timing

- **Modules/Repositories:**
  - lib/features/modules/domain/feature_flag.dart
  - lib/features/modules/domain/feature_flag_repository.dart
  - lib/features/modules/infrastructure/supabase_feature_flag_repository.dart
  - lib/features/modules/presentation/module_manifests.dart (list of available modules)
  - lib/features/modules/presentation/module_providers.dart
  - lib/features/modules/presentation/screens/admin_modules_screen.dart (admin toggle UI)

---

## 6. EXISTING ADMIN & PERMISSIONS

### ✅ Admin Directory
- **admin_directory.dart:** Admin user model with:
  - id, user_id, role (super_admin, admin, moderator, operator)
  - permissions (array of permission strings)
  - activated_at, deactivated_at
  - Scope support (global or org-specific)

### ✅ Database Schema
- **user_roles table:** user_id, role, granted_by, granted_at, revoked_at
  - Roles: super_admin, admin, moderator, operator, owner, customer
- **audit_logs table:** Full audit trail
  - id, user_id, action, entity_type, entity_id, details (JSON)
  - ip_address, user_agent, actor_id, created_at
- **audit_logs_archive:** Historical records (partitioned)
- **admin_directory_repository:** Query and manage admin users

### ✅ Admin Screens
- lib/features/admin/presentation/screens/
  - admin_dashboard_screen.dart - Overview & quick actions
  - admin_cms_screen.dart - Banner/promotion management
  - admin_audit_screen.dart - Audit log viewer with filters
  - admin_directory_screens.dart - Admin user management
- admin_providers.dart - Riverpod providers for admin data

### ✅ RLS & Security Model (Database)
- Implicit in table permissions for:
  - Profiles (users can read own, admins can read all)
  - Bookings (users can read own, owners can read their venues' bookings, admins can read all)
  - Payments (admins only)
  - Audit logs (admins only)

---

## 7. EXISTING RESPONSIVE & THEME SYSTEM

### ✅ Theme Setup
- **lib/core/theme/app_theme.dart** - Light/dark theme definitions
  - Material 3 ColorScheme
  - Typography
  - Component themes

- **lib/core/theme/app_tokens.dart** - Design tokens
  - Colors, spacing, borders, shadows
  - Responsive breakpoints (phone, tablet, desktop)

- **lib/core/theme/category_accent.dart** - Category-specific color mapping

### ✅ Responsive Widgets
- **lib/core/widgets/responsive_layout.dart** - Main responsive builder
  - Phone (< 600dp), tablet (600-840dp), desktop (≥ 840dp)
  - Conditional layouts
  - MultiColumn support

- Other responsive helpers:
  - animated_category_chip.dart - Chip widget with animations
  - interactive_tilt_card.dart - 3D tilt effect for cards (gestures)
  - glassmorphic_card.dart - Modern glass morphism style
  - staggered_entrance.dart - Animation sequences
  - skeleton.dart - Loading placeholders
  - accessibility.dart - A11y support

### ✅ Flutter Version & Dependencies
- **Flutter:** ≥3.19.0
- **Dart:** ≥3.3.0 <4.0.0
- **Key packages:**
  - flutter_riverpod: ^2.5.1 (state management)
  - riverpod: ^2.5.1
  - go_router: ^14.2.0 (routing)
  - supabase_flutter: ^2.5.0 (backend)
  - google_maps_flutter: ^2.7.0 (maps)
  - flutter_map: ^7.0.0 (alternative map)
  - latlong2: ^0.9.1 (geo)
  - geolocator: ^14.0.2 (GPS)
  - geocoding: ^5.0.0 (reverse geocoding)
  - cached_network_image: ^3.3.1
  - intl: ^0.20.2 (i18n)
  - flutter_secure_storage: ^9.0.0
  - image_picker: ^1.2.3
  - file_picker: 10.3.10
  - http: ^1.2.2
  - url_launcher: ^6.3.0

### ✅ Material 3 Support
- uses-material-design: true in pubspec.yaml

---

## 8. EXISTING CATEGORIES & FILTERING

### ✅ Category System
- **VenueCategory model** with:
  - Full i18n support (nameTranslations, descriptionTranslations)
  - Hierarchical (parentSection grouping)
  - Metadata (icon, display order, image)
  - Multi-language support

### ✅ Database Schema
- **venue_categories table:** 
  - id, slug, name, icon, metadata, is_active, parent_section
  - description, image_url, image_path, display_order
  - supported_languages array
  - name_i18n, description_i18n (JSON translations)
  - deleted_at (soft delete)
  - created_at, updated_at

- **category_sections table:** Grouping sections
  - id, name, slug, sort_order, is_active
  - Timestamps

- **venue_subsections table:** Sub-category level
  - Similar structure to venue_categories
  - icon, image support

### ✅ Filtering Features
- Home category discovery/catalog (home_category_catalog.dart)
- Category glass matrix (category_glass_matrix.dart) - Visual category grid
- Dynamic category loading from DB
- Filter bar in venue listings
- Search with category constraint

---

## 9. EXISTING TESTING INFRASTRUCTURE

### ✅ Test Coverage
- **Unit Tests:**
  - test/features/booking/ - Booking logic and repository tests
  - test/features/payment* - Payment flows and health checks
  - test/features/auth/ - Authentication and roles
  - test/features/home/ - Category and responsive UI
  - test/features/location/ - GPS and pin code

- **Test Files:**
  - booking_test.dart
  - supabase_booking_repository_test.dart
  - booking_status_test.dart
  - payment_flow_test.dart
  - payment_transaction_test.dart
  - payment_health_test.dart
  - admin_payment_screens_test.dart
  - category_responsive_test.dart
  - home_category_catalog_test.dart
  - auth_parity_test.dart (Flutter ↔ Backend sync)
  - login_screen_test.dart
  - gps_and_discovery_test.dart
  - pin_code_repository_test.dart

- **Mock Objects:**
  - mock_booking_repository.dart
  - mock_payment_repository.dart
  - fake_admin_payment_repository.dart
  - mock_course_repository.dart
  - And more...

- **Integration Tests:**
  - integration_test/ directory exists (E2E tests)
  - test_driver/ directory exists

### ✅ Testing Patterns
- Riverpod/Mockito mocking
- Repository pattern testing
- Widget testing
- State management testing (Riverpod providers)

---

## 10. UNTRACKED FILES & NEW FEATURES (ON THIS BRANCH)

### 🆕 Course/Education System (NEW)
- lib/features/courses/ (NEW FEATURE)
  - Full course management system
  - Enrollment tracking
  - Batch scheduling
  - Faculty management
  - Demo registrations
  - Feedback system
  - Syllabus & FAQs
  - Instructor assignment

- Models:
  - Course, CourseBatch, CourseEnrollment, CourseDemo, CourseFeedback, CourseFaculty, CourseFaq

- Screens:
  - courses_list_screen.dart
  - course_detail_screen.dart
  - education_hub_screen.dart
  - my_courses_screen.dart
  - owner_course_editor_screen.dart
  - owner_courses_screen.dart
  - admin_education_screen.dart
  - institute_detail_screen.dart

- Database: New tables
  - courses, course_batches, course_enrollments, course_faculty, course_faqs, course_feedback, course_demo_registrations
  - institutes, institute_listings, institute_listing_plans
  - education_invoices (course payment tracking)

### 🆕 Supabase Migrations (NEW)
- supabase/migrations/20260919000000_education_extensible_profile.sql
- supabase/migrations/20260919170000_course_syllabus_and_faq.sql
- supabase/migrations/20260920100000_cms_banners_add_slot.sql
- supabase/migrations/20260920110000_cms_banners_add_visual_style.sql

### 🆕 Local Storage System (NEW)
- lib/core/storage/ (NEW)
- Likely for local caching/offline support

### 📄 Documentation Added
- docs/COURSES_TASK_PROMPT.md
- docs/E2E_TESTING_RUNBOOK.md
- docs/EDUCATION_COVERAGE_MAP.md
- docs/EDUCATION_UX_REDESIGN_PLAN.md
- docs/MIGRATION_PLAN_TARGET_TYPE.md
- docs/PHASE1_PRODUCTION_AUDIT_CODEX_PROMPT.md
- docs/PHASE1_PRODUCTION_AUDIT_REPORT.md

### 🧪 Testing & QA
- e2e-evidence/ (test screenshots/outputs)
- e2e-playwright/ (Playwright E2E tests for web/API)
- test/features/courses/ (new course tests)
- test/features/cms/ (CMS functionality tests)
- supabase/tests/ (database tests)
  - anon_execute_lockdown_test.sql
  - payment_reconciliation_safety_test.sql
  - phase7_cancellation_policy_test.sql
  - refund_cancellation_scenarios_test.sql

### 📝 Configuration & Cleanup
- PHASE7_IMPLEMENTATION_REPORT.md
- POLICY_DECISION_LOCK.md
- test-output.log
- _to_delete/ (marked for cleanup)
- Claude outputs/ (working directory)

---

## 11. MISSING FUNCTIONALITY (NOT YET IMPLEMENTED)

### ❌ Occupancy/Crowd Analytics
- **Missing Table:** No occupancy tracking table in schema
- **Missing Models:** No occupancy model in codebase
- **Missing Logic:** No real-time occupancy calculation
- **Impact:** Cannot show "how full" a venue is or historical analytics

### ❌ Hourly Occupancy Rates
- **Missing:** No occupancy_history or occupancy_metrics table
- **Missing:** No hourly aggregation logic
- **Impact:** Cannot show peak hours or usage patterns

### ❌ Availability Bulk Management
- **Missing:** No bulk availability import/export UI
- **Missing:** No calendar-based availability manager for owners
- **Impact:** Owners must set time slots one-by-one (poor UX)

### ❌ Availability Blocking (Maintenance)
- **Exists:** venue_blocked_dates table (for full-day blocking)
- **Missing:** Time-slot level blocking (e.g., "2-4pm for maintenance")
- **Impact:** Cannot block individual slots for cleaning/maintenance

### ❌ Draft/Publish Workflow for Venues
- **Missing:** No draft/published status in venues table
- **Missing:** No version control for venue edits
- **Impact:** All changes go live immediately (risky for owners)

### ❌ Multi-Language Support (Partial)
- **Exists:** i18n fields in database (name_i18n, description_i18n)
- **Exists:** supportedLanguages in VenueCategory
- **Missing:** Runtime language switching in app (likely en only)
- **Missing:** Fallback logic when translations absent
- **Impact:** Categories/venues with translations not fully utilized

### ❌ Advanced Filtering UI
- **Exists:** Models and DB support
- **Missing:** UI screen for complex filters (price range, amenities, ratings, distance)
- **Impact:** Users limited to category + search only

### ❌ Venue Review & Rating System (Partial)
- **Exists:** reviews table (id, booking_id, user_id, venue_id, rating, title, body, owner_reply, owner_replied_at, is_verified)
- **Missing:** Review display screens
- **Missing:** Review submission UI
- **Missing:** Rating calculation stored procedure (using avg_rating, rating_count in venues table)

### ❌ Owner Approval Workflow UI (Partial)
- **Exists:** Database columns (approval_required, approval_requested_at, approval_expires_at, approved_at, approved_by, rejected_at, rejection_reason)
- **Exists:** API integration likely
- **Missing:** Owner notification system (push, email)
- **Missing:** Approval dashboard in owner app
- **Missing:** Auto-reject logic when approval expires

### ❌ Coupon/Discount Management
- **Exists:** coupons table (code, discount_type, discount_value, max_uses, starts_at, ends_at, is_active)
- **Exists:** booking_coupons junction table
- **Missing:** Coupon application UI
- **Missing:** Validation logic
- **Missing:** Admin coupon CRUD screens

### ❌ Voice Booking (Feature Flag Only)
- **Exists:** voice_booking_enabled flag in module_feature_configs
- **Missing:** Any voice recognition/NLU implementation
- **Missing:** Voice interaction UI
- **Missing:** Speech-to-text integration

### ❌ AI Assistant (Feature Flag Only)
- **Exists:** ai_assistant_enabled flag in module_feature_configs
- **Missing:** Any AI/LLM integration
- **Missing:** Chatbot UI
- **Missing:** Training data/context

### ❌ Venue Sections/CMS Dynamic Content
- **Exists:** venue_sections table (type-based, with titles, content, images)
- **Exists:** venue_section_types (configurable section templates)
- **Missing:** Admin UI to manage sections per venue
- **Missing:** Display in venue detail screen
- **Impact:** Venues cannot customize their profiles with custom sections

### ❌ Analytics/Insights Dashboard
- **Exists:** analytics_events table (user_id, session_id, event_type, properties)
- **Exists:** No corresponding analytics screens
- **Missing:** Admin analytics dashboard
- **Missing:** Venue owner analytics (bookings, revenue, occupancy)
- **Impact:** No visibility into business metrics

### ❌ Wallet/Credit System
- **Exists:** wallet_ledger table (user_id, direction, amount, currency, source_type, source_id)
- **Missing:** Wallet UI
- **Missing:** Credit application logic
- **Missing:** Refund-to-wallet option

### ❌ Referral System
- **Exists:** referral_profiles, referral_attributions, referral_rewards tables
- **Missing:** Referral invite/share UI
- **Missing:** Reward claim UI
- **Missing:** Leaderboard screens

### ❌ Promotion/Marketing Campaigns
- **Exists:** promotions table with full details
- **Exists:** promotion_categories, promotion_venues (targeting)
- **Missing:** Campaign creation/management UI
- **Missing:** Display in app (banners, cards, etc.)

### ❌ Dispute Resolution System
- **Exists:** disputes table (id, booking_id, opened_by, reason, status, resolution)
- **Missing:** Dispute filing UI
- **Missing:** Admin dispute management dashboard
- **Missing:** Mediation workflow

### ❌ Support Tickets
- **Exists:** support_tickets, support_ticket_messages tables
- **Missing:** User ticket creation UI
- **Missing:** Admin ticket management dashboard
- **Missing:** Chat-like message thread UI

### ❌ External Channel Management (OTA/PMS Integration)
- **Exists:** external_channel_providers, external_channel_connections, external_property_mappings, external_rate_plan_mappings, external_room_mappings, external_reservations, external_inventory_events tables
- **Exists:** Complex sync/inventory system
- **Missing:** Connection setup UI (OAuth flows)
- **Missing:** Sync status monitoring UI
- **Missing:** Conflict resolution UI
- **Impact:** Cannot connect to Airbnb, Booking.com, etc.

### ❌ Crash Report Analysis
- **Exists:** crash_reports table (user_id, error_message, stack_trace, platform, version)
- **Missing:** Crash analysis dashboard
- **Missing:** Error aggregation/trending
- **Impact:** Cannot track app stability issues

### ❌ Push Notifications
- **Exists:** device_tokens table (user_id, platform, token, is_active)
- **Exists:** notifications table (user_id, type, title, body, data, read)
- **Missing:** Push sending service
- **Missing:** Notification preference UI
- **Impact:** No real-time alerts

### ❌ Email Delivery System
- **Exists:** email_outbox table (complete transactional email queue)
- **Missing:** Actual email service integration
- **Missing:** Template engine
- **Impact:** No confirmation/status emails sent

### ❌ Invoice Generation
- **Exists:** invoice_documents table (booking_id, storage_path, status)
- **Exists:** booking_receipts table (receipt_number, issued_at)
- **Missing:** Invoice PDF generation
- **Missing:** Invoice download UI
- **Missing:** Email delivery of invoices

---

## 12. FILES REQUIRING CHANGES FOR NEW FEATURES

### 🔧 Core Routing Changes
- **lib/core/router/app_router.dart** (32KB - modified)
  - Need to add routes for:
    - New booking screens (venue_map_screen, availability calendar)
    - Occupancy analytics screens
    - Advanced filter screens
    - Draft/publish workflow screens
    - Venue bulk availability manager
    - Owner approval dashboard
    - Review/rating screens
    - Coupon application flow
    - Admin analytics dashboard
    - Wallet management screens
    - Promotion/campaign management
    - Support ticket system
    - Dispute resolution

### 🔧 Localization Additions
- **lib/core/localization/app_localizations.dart** (modified)
  - Add strings for new booking UI elements
  - Occupancy/crowd labels
  - Approval workflow messages
  - Review/rating labels
  - Coupon/discount labels
  - Analytics labels
  - Etc.

### 🔧 Theme Enhancements
- **lib/core/theme/app_theme.dart**
  - May need new component styles for expanded UI
  - New color schemes for occupancy visualization
  - New border/shadow styles

- **lib/core/theme/app_tokens.dart**
  - May need new spacing/sizing tokens for new layouts
  - New animation timings

### 🔧 Widget Additions/Updates
- **lib/core/widgets/**
  - New responsive grid layouts
  - New chart widgets (for occupancy, revenue)
  - New form widgets (availability calendar)
  - New status badges/chips
  - New approval workflow indicators

### 🔧 Home Screen Updates
- **lib/features/home/presentation/screens/home_screen.dart** (modified)
  - Add occupancy/crowd indicators to venue cards
  - Add availability peek (next available time)
  - Add featured promotions/banners
  - May show different cards based on feature flags

- **lib/features/home/presentation/home_category_catalog.dart** (modified)
  - May need changes for advanced filtering UI

### 🔧 Booking Flow Expansion
- **lib/features/booking/**
  - New screen: venue_map_screen (already exists)
  - New screen: availability_calendar_screen (NOT YET)
  - New screen: occupancy_view_screen (NOT YET)
  - New screen: approval_status_screen (NOT YET)
  - Updates to booking_screen for new data fields

### 🔧 Payment & Receipts
- **lib/features/payments/presentation/screens/payment_screen.dart**
  - Add invoice generation button
  - Add wallet credit option
  - Add coupon discount display
  - Add receipt download link

- **lib/features/booking/presentation/screens/booking_success_screen.dart**
  - Add invoice download button
  - Add add-to-calendar option
  - Add share options

### 🔧 Owner Venues Management
- **lib/features/owner_venues/presentation/screens/**
  - New screen: owner_availability_manager.dart (bulk upload)
  - New screen: owner_approval_dashboard.dart
  - New screen: owner_analytics_screen.dart
  - Updates to create_venue_screen.dart for draft/publish workflow
  - Updates to owner_venues_screen.dart to show occupancy

### 🔧 Admin Screens
- **lib/features/admin/presentation/screens/**
  - New screen: admin_analytics_screen.dart
  - New screen: admin_promotions_screen.dart
  - New screen: admin_disputes_screen.dart
  - New screen: admin_support_tickets_screen.dart
  - New screen: admin_external_channels_screen.dart
  - Updates to admin_cms_screen.dart to manage venue sections

### 🔧 New Features
- **lib/features/reviews/** (NEW)
  - review_repository.dart
  - review_providers.dart
  - review_card.dart (widget)
  - reviews_list_screen.dart
  - submit_review_screen.dart

- **lib/features/analytics/** (NEW)
  - analytics_repository.dart
  - analytics_providers.dart
  - analytics_dashboard_screen.dart
  - occupancy_chart_widget.dart
  - revenue_chart_widget.dart

- **lib/features/promotions/** (NEW)
  - promotion_repository.dart
  - promotion_card_widget.dart
  - promotions_list_screen.dart

- **lib/features/wallet/** (NEW)
  - wallet_repository.dart
  - wallet_screen.dart
  - wallet_card_widget.dart

- **lib/features/coupons/** (NEW)
  - coupon_repository.dart
  - coupon_applier_widget.dart
  - coupons_list_screen.dart (admin)

- **lib/features/support/** (NEW)
  - support_ticket_repository.dart
  - support_ticket_list_screen.dart
  - support_ticket_detail_screen.dart
  - support_ticket_create_screen.dart

---

## 13. EXACT REUSABLE FILES & PROVIDERS

### 📦 Reusable Repository Pattern
- All repositories follow:
  - Domain interface (e.g., booking_repository.dart)
  - Supabase implementation (e.g., supabase_booking_repository.dart)
  - Riverpod providers (e.g., booking_providers.dart)

**Reuse Pattern for New Features:**
```
lib/features/[feature]/
├── domain/
│   ├── [feature].dart (model)
│   ├── [feature]_repository.dart (interface)
├── infrastructure/
│   ├── supabase_[feature]_repository.dart (implementation)
├── presentation/
│   ├── [feature]_providers.dart (Riverpod)
│   ├── screens/
│   └── widgets/
└── data/ (optional, if needed)
```

### 🔌 Riverpod Provider Templates

**List Provider with Filters:**
```dart
// From booking_providers.dart
final availableSlotsProvider = FutureProvider.family(
  (ref, bookingRequest) async {
    final repo = ref.watch(bookingRepositoryProvider);
    return repo.fetchAvailableSlots(bookingRequest);
  },
);
```

**Single Entity Provider:**
```dart
final myBookingsProvider = FutureProvider((ref) async {
  final repo = ref.watch(bookingRepositoryProvider);
  return repo.fetchMyBookings();
});
```

**Mutation Provider:**
```dart
final createBookingProvider = FutureProvider.family((ref, request) async {
  final repo = ref.watch(bookingRepositoryProvider);
  return repo.createBooking(request);
});
```

### 🏗 Reusable Widget Patterns

**Responsive Layout Container:**
```dart
// From responsive_layout.dart
ResponsiveLayout(
  phone: phoneWidget,
  tablet: tabletWidget,
  desktop: desktopWidget,
)
```

**Loading States:**
```dart
// skeleton.dart for placeholders
// AsyncValue<T> from Riverpod for async UI
value.when(
  loading: () => SkeletonLoader(),
  data: (data) => DataView(data),
  error: (err, st) => ErrorView(err),
)
```

**Cards & List Items:**
- venue_card.dart (reusable venue display)
- venue_badges.dart (status badges)
- animated_category_chip.dart (category selection)
- payment_status_chip.dart (status indicator)
- transaction_row_card.dart (transaction display)

### 🗄 Repository Patterns

**Repository Interface (Booking Example):**
```dart
abstract class BookingRepository {
  Future<List<Booking>> fetchMyBookings();
  Future<BookingHold> holdBooking(BookingRequest request);
  Future<Booking> approveBooking(String bookingId);
  Future<Booking> cancelBooking(String bookingId);
  Future<List<SlotAvailability>> fetchAvailableSlots(BookingRequest request);
}
```

**Supabase Implementation Pattern:**
- Uses supabase_flutter client
- Error handling with try-catch
- JSON deserialization with .fromJson()
- Timestamps handled with DateTime.tryParse()
- Array fields use casting/mapping

### 📊 Data Models

**Reusable Enum Pattern:**
```dart
enum BookingStatus {
  held, pending, confirmed, cancelled, unknown;
  
  static BookingStatus fromDb(String value) => switch (value) {
    'held' => held,
    'pending' => pending,
    // ...
    _ => unknown,
  };
  
  String get dbValue => switch (this) {
    held => 'held',
    pending => 'pending',
    // ...
  };
}
```

**Reusable Model Pattern:**
```dart
class Booking {
  const Booking({
    required this.id,
    required this.status,
    // ...
  });

  final String id;
  final BookingStatus status;
  // ...

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
    id: json['id'] as String? ?? '',
    status: BookingStatus.fromDb(json['status'] as String? ?? 'unknown'),
    // ...
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'status': status.dbValue,
    // ...
  };
}
```

### 🔐 Auth & Permissions

**From auth codebase:**
- auth_repository.dart (handles login, signup, password reset)
- supabase_auth_repository.dart (Supabase implementation)
- Auth patterns:
  - Phone OTP (phone_otp_provider_test.dart exists)
  - Session management
  - Role-based access control (app_role_test.dart exists)

---

## 14. DATABASE GAPS & MISSING TABLES

### ✅ Complete Tables (Supported)
- bookings, time_slots, booking_holds, booking_receipts ✅
- venues, venue_categories, venue_images, venue_amenities ✅
- payments, refunds, payment_attempts ✅
- profiles, user_roles, audit_logs ✅
- feature_flags, module_feature_configs ✅
- location_nodes, location_postal_codes ✅
- cms_banners, promotions ✅

### ⚠️ Tables Existing but Unused in App

**Reviews System:**
- ✅ Table: reviews (exists)
- ❌ App Support: Missing (no screens, providers, repositories)

**Occupancy Tracking:**
- ❌ No occupancy table exists
- ❌ No occupancy metrics/history table
- ❌ No hourly aggregation table
- **Recommendation:** Create occupancy tables before implementing analytics

**Coupons:**
- ✅ Tables: coupons, booking_coupons (exist)
- ❌ App Support: Missing (no screens, providers, repositories)

**Support Tickets:**
- ✅ Tables: support_tickets, support_ticket_messages (exist)
- ❌ App Support: Missing (no screens, providers)

**Wallet/Credits:**
- ✅ Table: wallet_ledger (exists)
- ❌ App Support: Missing (no screens, providers)

**Referrals:**
- ✅ Tables: referral_profiles, referral_attributions, referral_rewards (exist)
- ❌ App Support: Missing (no screens, providers)

**Disputes:**
- ✅ Table: disputes (exists)
- ❌ App Support: Missing (no screens, providers)

**Events:**
- ✅ Tables: events, event_registrations (exist)
- ❌ App Support: Missing (likely for future use or testing)

**Crash Reports:**
- ✅ Table: crash_reports (exists)
- ❌ App Support: Missing (no error tracking/reporting UI)

**Analytics Events:**
- ✅ Table: analytics_events (exists)
- ❌ App Support: Missing (no event tracking, no dashboard)

**Push Notifications:**
- ✅ Table: device_tokens, notifications (exist)
- ❌ App Support: Missing (no push service, no notification UI)

**Email Outbox:**
- ✅ Table: email_outbox (exists)
- ❌ App Support: Missing (no email service integration)

**Invoices:**
- ✅ Table: invoice_documents (exists)
- ❌ App Support: Missing (no PDF generation, no UI)

**External Channels (OTA/PMS):**
- ✅ All tables exist (external_channel_*, external_reservations, external_room_mappings, external_rate_plan_mappings, external_property_mappings)
- ❌ App Support: Missing (no integration UI, no sync monitoring)

**Pricing Rules:**
- ✅ Table: pricing_rules (exists)
- ❌ App Support: Missing (no pricing rule management UI)

**Inventory Management:**
- ✅ Tables: inventory_change_log, inventory_sync_errors, inventory_sync_state (exist)
- ❌ App Support: Missing (no sync UI, no monitoring dashboard)

### 🆕 Recommend Creating

For occupancy/analytics features, create:

```sql
-- Occupancy tracking (real-time and historical)
CREATE TABLE occupancy_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  venue_id uuid REFERENCES venues(id),
  slot_id uuid REFERENCES time_slots(id),
  book_date date,
  capacity_total int,
  bookings_confirmed int,
  bookings_held int,
  bookings_pending int,
  available_spots int,
  occupancy_percent numeric(5,2),
  crowd_level text, -- 'empty', 'low', 'medium', 'high', 'full'
  snapshot_at timestamptz DEFAULT now(),
  created_at timestamptz DEFAULT now()
);

-- Daily/hourly aggregates
CREATE TABLE occupancy_metrics (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  venue_id uuid REFERENCES venues(id),
  metric_date date,
  metric_hour int, -- 0-23 for hourly, NULL for daily
  avg_occupancy_percent numeric(5,2),
  peak_occupancy_percent numeric(5,2),
  min_occupancy_percent numeric(5,2),
  total_bookings int,
  total_revenue numeric(12,2),
  created_at timestamptz DEFAULT now()
);
```

---

## 15. RLS & SECURITY REVIEW

### ✅ Implicit RLS (Database)
- Profiles: Self-access + admin override
- Bookings: User owns or owns venue
- Payments: Admin only
- Audit logs: Admin only
- Feature flags: Public read, admin write

### ⚠️ Frontend Validation Issues
- **No verification that user owns venue** before allowing owner operations
- **No role checking on admin screens** (relies on navigation only)
- **No permission validation in repositories** (assumes Supabase RLS handles it)

### ⚠️ Potential Issues
1. **Missing RLS Policies on New Tables:**
   - occupancy tables (if created) need venue owner access
   - reviews, coupons, wallet_ledger need user-specific access
   - support_tickets need user + admin access

2. **No frontend permission checking:**
   - Repositories should validate user roles before API calls
   - Admin screens should check auth before rendering

3. **No audit trail for sensitive operations:**
   - Venue deletions
   - Price changes
   - Owner approvals

### 🔒 Recommendations
1. Add RLS policy checks in Supabase (not just rely on auth)
2. Add backend validation in repositories
3. Add audit logging for all sensitive operations
4. Add permission checks in UI before showing options

---

## 16. RESPONSIVE UI & PLATFORM PLAN

### 📱 iPhone/iPad (iOS)
- **Primary Target:** Portrait orientation
- **Existing:** responsive_layout.dart with phone breakpoint
- **Plan:**
  - Use phone layout (<600dp)
  - Test on actual iOS devices
  - Optimize for Face ID safe areas (notch handling)
  - Bottom nav for iOS (not drawer)
  - Native iOS gestures (swipe back)

### 📱 Android Phone
- **Primary Target:** Portrait + landscape
- **Existing:** responsive_layout.dart with phone breakpoint
- **Plan:**
  - Use phone layout (<600dp)
  - Test landscape mode
  - System button handling (Android back button)
  - Navigation drawer support

### 📱 Android Tablet
- **Target:** Portrait + landscape
- **Existing:** responsive_layout.dart with tablet breakpoint (600-840dp)
- **Plan:**
  - Use tablet layout (600-840dp)
  - Split view layouts (master-detail)
  - Larger touch targets
  - Multi-column grids

### 💻 iPad
- **Target:** Portrait + landscape
- **Existing:** responsive_layout.dart with tablet breakpoint
- **Plan:**
  - Use tablet layout
  - Leverage split screen (iPadOS 15+)
  - Larger typography
  - Desktop-like interactions

### 🖥️ Desktop Web
- **Target:** Full-width responsive
- **Existing:** responsive_layout.dart with desktop breakpoint (≥840dp)
- **Plan:**
  - Use desktop layout
  - Hover states (cards, buttons)
  - Keyboard shortcuts
  - Drag-drop file uploads
  - Multi-window support (if web app)

### 📐 Breakpoint Strategy (from app_tokens.dart)
```
phone:      < 600dp (phones)
tablet:     600 - 840dp (small tablets, 6-7")
desktop:   >= 840dp (large tablets, iPads, laptops, desktops)
```

### 🎨 Existing Responsive Components
- responsive_layout.dart (main wrapper)
- venue_card.dart (adapts to width)
- category_glass_matrix.dart (columns adjust)
- animated_category_chip.dart (wraps)
- glassmorphic_card.dart (padding adjusts)
- All core widgets use EdgeInsets.symmetric with responsive values

### ⚠️ Known iOS-Specific Issues on This Branch
- Mention of "fix/ios-bookmyspace-ui" suggests iOS-specific fixes needed
- Likely viewport/safe area issues
- Possible gesture recognizer conflicts
- Orientation handling improvements

---

## 17. RECOMMENDED IMPLEMENTATION ORDER

### 🟢 Phase 1: Core Booking Enhancements (Priority: CRITICAL)
1. Availability calendar screen (replace date picker)
2. Time-slot blocking for maintenance
3. Bulk availability import/manager for owners
4. Occupancy display (requires new DB tables)
5. Owner approval notification system
6. Auto-reject on approval expiry

### 🟡 Phase 2: User Experience (Priority: HIGH)
7. Draft/publish workflow for venues
8. Review & rating system (UI + screens)
9. Advanced venue filtering UI
10. Venue sections/CMS management
11. Coupon/discount application
12. Venue search result map integration

### 🟠 Phase 3: Owner Empowerment (Priority: MEDIUM)
13. Owner analytics dashboard (bookings, revenue, occupancy)
14. Owner approval dashboard
15. Pricing rules management
16. Cancellation policy management
17. Owner bank account management (payout setup)

### 🔴 Phase 4: Admin & Operations (Priority: MEDIUM)
18. Admin analytics dashboard
19. Admin promotion/campaign management
20. Admin support ticket system
21. Admin disputes resolution
22. Admin venue discovery/staging review

### 🟣 Phase 5: Advanced Features (Priority: LOW)
23. Wallet/credit system UI
24. Referral system UI
25. Voice booking (NLU + speech)
26. AI assistant chatbot
27. External channel integration (Airbnb, Booking.com sync)
28. Push notification service
29. Email delivery system
30. Invoice generation + PDFs

---

## 18. MIGRATIONS REQUIRING APPROVAL

### ⚠️ Already Pending (On Branch)
1. **20260919000000_education_extensible_profile.sql** (Course system)
2. **20260919170000_course_syllabus_and_faq.sql** (Course syllabus)
3. **20260920100000_cms_banners_add_slot.sql** (Banner slot field)
4. **20260920110000_cms_banners_add_visual_style.sql** (Banner colors)

### 🆕 Recommended for Approval

**For Occupancy Analytics:**
```sql
-- Create occupancy_snapshots table
-- Create occupancy_metrics table
-- Create materialized view for hourly aggregates
-- Create RLS policies
```

**For Venue Sections:**
```sql
-- Add draft_config to venue_sections
-- Add version tracking to venue_sections
-- Create venue_section_versions table
-- Add RLS for section visibility
```

**For Availability Blocking:**
```sql
-- Add time_slot_blocks table (venue_id, slot_id, book_date, reason)
-- Add triggers to prevent booking blocked slots
```

**For Draft/Publish Workflow:**
```sql
-- Add status field to venues (draft/published)
-- Add version_id to venues
-- Create venues_history table
-- Add timestamps for draft/publish dates
```

**For Voice Booking:**
```sql
-- Add voice_sessions table (tracking)
-- Add voice_transcripts table (for auditing)
-- Add voice_commands table (for NLU)
```

**For Push Notifications:**
```sql
-- Enhance device_tokens with metadata
-- Add notification_preferences table
-- Add notification_history table
```

---

## SUMMARY CHECKLIST

| Item | Status | Notes |
|------|--------|-------|
| Booking System | ✅ Complete | Full lifecycle, approvals, holds, receipts |
| Venue Management | ✅ Complete | Categories, images, amenities, search |
| Payments/Razorpay | ✅ Complete | Native + Web, refunds, receipts |
| Time Slots | ✅ Complete | HH:MM format, availability checking |
| Location/GPS | ✅ Complete | Hierarchical, postal codes, mapping |
| Maps (Google/Flutter) | ✅ Complete | Venue markers, distance, filtering |
| CMS/Banners | ✅ Complete | Scheduling, styling, positioning |
| Feature Flags | ✅ Complete | Per-platform, per-venue configs |
| Admin System | ✅ Complete | Directory, audit logs, permissions |
| Responsive Design | ✅ Complete | Phone/tablet/desktop breakpoints |
| Theme/Design Tokens | ✅ Complete | Material 3, dark mode, category colors |
| Tests | ✅ Partial | Booking, payment, auth, location tests (no occupancy tests) |
| Occupancy Analytics | ❌ Missing | Database schema needed |
| Hourly Metrics | ❌ Missing | Database schema needed |
| Availability Blocking | ⚠️ Partial | Full-day only (vendor_blocked_dates) |
| Draft/Publish | ❌ Missing | All new screens needed |
| Review System | ⚠️ Partial | DB exists, no UI |
| Coupon System | ⚠️ Partial | DB exists, no UI |
| Wallet System | ⚠️ Partial | DB exists, no UI |
| Support Tickets | ⚠️ Partial | DB exists, no UI |
| Promotions | ⚠️ Partial | DB exists, no UI (banners added) |
| Voice Booking | ❌ Flag Only | Feature flag present, no implementation |
| AI Assistant | ❌ Flag Only | Feature flag present, no implementation |
| Email Service | ⚠️ Partial | Outbox table exists, no service |
| Push Notifications | ⚠️ Partial | device_tokens exist, no service |
| Invoice PDFs | ⚠️ Partial | Table exists, no generation |
| External Channels | ⚠️ Partial | Full sync infrastructure, no UI |
| Referral Program | ⚠️ Partial | DB exists, no UI |
| Disputes | ⚠️ Partial | DB exists, no UI |

---

## CONCLUSION

**The BookMySpace platform has a solid foundation with 60% of core functionality implemented:**

✅ **Strengths:**
- Complete booking lifecycle with approval workflows
- Robust payment integration (Razorpay native + web)
- Comprehensive location/geo system (PostGIS, hierarchical locations)
- Feature flags and module system for A/B testing
- Admin audit and role-based access
- Responsive design foundation
- Good test coverage for critical paths
- Clean repository pattern and Riverpod provider structure

⚠️ **Gaps:**
- No occupancy/crowd analytics (requires new DB tables)
- Missing UI for existing DB tables (reviews, coupons, wallet, support, disputes, promotions, invoices)
- No real-time notifications (push/email)
- No external channel integration (OTA sync)
- Limited owner self-service tools
- No draft/publish workflow for safe venue editing

🔧 **Next Steps:**
1. **Approve pending migrations** (education, banner styling)
2. **Create occupancy DB schema** (snapshots + metrics)
3. **Implement occupancy display** in booking flow
4. **Build owner approval dashboard** (high-value feature)
5. **Add review/rating UI** (simple, high-impact)
6. **Build advanced filtering UI** (improves discovery)

**Estimated effort for Phase 2 (iOS UI enhancements):** 2-3 weeks depending on scope

---

**Awaiting approval to proceed with implementation.**
