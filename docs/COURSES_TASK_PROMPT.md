# Task Prompt — Make Education / Courses genuinely extensible through the existing admin CMS

Scoped task prompt, matching the format of `docs/ADMIN_CATEGORIES_TASK_PROMPT.md`.
Background and gap analysis below come from the live schema of the `bookmyspace-dev`
Supabase project (`zykxneztahxbjduagutv`), not from assumptions.

## REQUIRED READING BEFORE THE PROMPT BELOW — what already exists vs what is missing

Real tables already exist for this feature: `institutes`, `courses`, `course_batches`,
`course_enrollments`, `institute_listings`, `institute_listing_plans`. This is not a
greenfield build — the prompt below must extend this schema, not replace it.

**What `institutes` currently has:** `id, org_id, name, description, logo_image,
is_verified, created_at, updated_at`. There is no education-category field, no
government-level field (private / state / central / university / NGO / other), and no
location columns of its own.

**What `courses` currently has:** `id, institute_id, title, description, mode, venue_id,
duration_weeks, fee_amount, instructor_name, cover_image, status, created_at, updated_at`.
`status` is a plain `text` column, not an enum guaranteeing draft/published semantics.
`instructor_name` is a single free-text field — there is no structured faculty/instructor
profile entity. There are no discount, demo-registration-method, brochure/video-upload, or
custom-field columns anywhere in this table or its siblings.

**What `course_batches` currently has:** `id, course_id, label, starts_on, capacity,
enrolled_count, timetable (jsonb), is_active`. This already covers "batches", "seats and
capacity", and "class timings" reasonably well via the `timetable` jsonb column — the
prompt below should extend this, not duplicate it with a second batches table.

**Education categories are not wired into the existing category system.** `venue_categories`
and `category_sections` (used by Admin → Content Management → Categories, see the sibling
task prompt) have no relationship to `institutes` or `courses` — there is no
education-category column or join table today. "Education categories" in the prompt below
must be modeled as an extension of (or a clearly justified new peer to) that existing
category system, not a third, unrelated category table.

**A generic configurable-field system may already exist and should be checked before
building a course-specific one.** The schema already has `owner_registration_field_configs`,
`owner_registration_values`, `module_feature_configs`, `module_form_versions`,
`module_document_requirements`, `module_form_submissions`, and
`module_submission_documents`. These look purpose-built for exactly the
"FIELD CONFIGURATION" requirements below (enabled/disabled, required/optional,
visible/admin-only, custom label, custom help text, display order, file uploads with
review). The implementer must inspect these tables and their current usage (they may be
scoped to owner-onboarding only) before deciding whether to extend them for courses or to
justify a course-specific field-config table. Do not build a second, parallel
field-configuration system if the existing one can be generalized — the prompt below
explicitly says not to create a second education CMS or duplicate data model, and this is
the most likely place that rule would otherwise get silently violated. The same applies to
the newest "ADMIN-CONTROLLED MODULES — PLUG AND PLAY" section below: `module_feature_configs`
and `module_form_versions` already look like the intended home for module-level and
field-level admin controls generally (not just for courses), so this is very likely the
existing system that section is describing, not a new one to build.

**No demo-registration-method modeling exists yet.** None of "internal registration form /
external link / phone-WhatsApp / demo video / brochure / scheduled live demo / recorded
preview / no demo" exists as data today — this is a real, additive gap the prompt below
must design, not a checkbox that's secretly already done.

---

## THE PROMPT

```text
Implement only the missing functionality for an extensible Education/Courses module on top
of the existing institutes, courses, course_batches, and course_enrollments tables and the
existing admin CMS, category system, Supabase storage, authentication, and permissions. Do
not redesign or remove existing UI, routing, auth, booking, payment, or existing behavior
for venues, events, or any other module. Do not create a second education CMS or duplicate
data model — extend institutes/courses/course_batches and the existing category and
field-configuration systems (inspect owner_registration_field_configs, module_form_versions,
module_document_requirements, and module_form_submissions first; generalize them for course
use if they fit, rather than building a parallel system).

EXTENSIBLE EDUCATION CATALOG AND DEMO CONTENT:
The Education module must support any institute, course, or learning category through the
existing admin CMS. Do not hardcode only one education type.
Supported examples include:
- Dance and performing arts
- Music and instruments
- Civil services preparation
- State government institutes
- Central government institutes
- Competitive examinations
- Schools and colleges
- Professional and technical courses
- Vocational training
- Online courses
- Offline classroom courses
- Workshops and short-term programs

ADMIN PLUG-AND-PLAY CONFIGURATION:
Admins must be able to create, edit, enable, disable, reorder, and publish:
- Education categories
- Institute names
- Institute type
- Government level: private, state government, central government, university, NGO, or other
- Course names
- Faculty/instructor profiles
- Course duration
- Fee and discounts
- Location
- Online/offline/hybrid mode
- Class timings
- Batches
- Seats and capacity
- Demo-class availability
- Registration method
- Feedback settings
- Invoice settings
- Required and optional form fields

FIELD CONFIGURATION:
For every education category, institute, or course, admins must be able to configure fields as:
- Enabled or disabled
- Required or optional
- Visible to users or admin-only
- Custom label
- Custom help text
- Display order

Supported configurable fields should include:
- Student name
- Parent/guardian name
- Mobile number
- Email
- Date of birth
- Gender
- Address
- State
- District
- Education level
- Preferred batch
- Preferred timing
- Course selection
- Institute selection
- Uploaded documents
- Profile image
- Previous experience
- Referral source
- Consent checkbox
- Custom text, number, date, dropdown, radio, and checkbox fields

DEMO REGISTRATION OPTIONS:
Each course or institute may use one or more demo-registration methods:
1. Internal registration form
2. External registration link
3. Phone/WhatsApp contact action
4. Uploaded sample/demo video
5. Uploaded sample class document or brochure
6. Scheduled live demo class
7. Recorded demo preview
8. No demo available

Admin must be able to choose the method and enable or disable each option.
For external links:
- Validate that the URL is valid.
- Open safely in the browser or in-app web view.
- Clearly show that the user is leaving the app.
- Do not silently transmit personal information to an external site.
- Preserve the course and institute context when the user returns.

For uploads:
- Allow admin uploads for demo videos, brochures, PDFs, images, and sample materials.
- Store files through the existing secure storage system.
- Validate file type and size.
- Show upload progress, success, retry, and error states.
- Provide preview, replace, and remove actions.
- Do not expose private files publicly without the existing access rules.
- Never hardcode uploaded file URLs.

USER EXPERIENCE:
The course page should clearly show only the options configured by the admin:
- Register for Demo
- Watch Demo
- Download Brochure
- Open Registration Link
- Contact Institute
- Enroll Now

Do not show empty labels, disabled fields, or unavailable buttons.

ADMIN PREVIEW:
Add an admin preview mode showing exactly how the configured institute/course page will
appear on:
- Web desktop
- Tablet
- iOS
- Android

Changes should remain draft until the admin explicitly publishes them.
Use the existing CMS, repositories, providers, Supabase storage, authentication, and
permissions. Do not create a second education CMS or duplicate data model.

ADMIN-CONTROLLED MODULES — PLUG AND PLAY:
Beyond individual education fields, the admin must be able to control entire modules and
feature areas across the Education/Courses experience in the same plug-and-play way, without
a code deployment. Before building any new configuration table for this, inspect
module_feature_configs and module_form_versions — these already look purpose-built as a
generic, cross-module admin-control system and should be generalized/reused rather than
duplicated.

MODULE-LEVEL CONTROLS:
Admins must be able to enable, disable, reorder, and configure entire modules/sections, such as:
- Institutes listing
- Courses listing
- Batches and scheduling
- Demo/registration module
- Enrollment/booking module
- Reviews and feedback module
- Invoicing/payment module
- Faculty/instructor profiles module
- Notifications for education flows
Disabling a module must hide it completely from end users (no broken links, no empty
sections, no dead navigation entries) while preserving its underlying data.

FIELD-LEVEL CONTROLS:
Within any enabled module, admins must retain the same field-level configuration described
above (enabled/disabled, required/optional, visible/admin-only, custom label, custom help
text, display order) so that every module's fields, not just course-registration fields, are
plug-and-play.

SUPPORTED FIELD TYPES:
The field-configuration system must support at minimum: text, number, date, dropdown/select,
radio, checkbox, multi-select, file upload, image upload, and consent/acknowledgement fields,
consistently across every module it is applied to.

PLUG-AND-PLAY RULES:
- Do not create a separate education CMS or duplicate configurable-field system — extend the
  existing module/field configuration tables and admin UI.
- Every module and field change must be admin-driven at runtime, not hardcoded in app code.
- Changes must support enable/disable, reorder, and draft-vs-published states consistently
  with the rest of the admin CMS.
- Removing or disabling a module/field must never delete existing user data silently.
- New modules or fields must degrade gracefully on older app builds that have not yet synced
  the latest configuration (no crashes, no blank screens).

ADMIN PREVIEW:
The admin preview mode described above must also reflect module-level enable/disable state —
a disabled module must not appear in the preview for Web desktop, Tablet, iOS, or Android,
and a newly enabled module must appear in preview before it is published.

VERIFICATION — test at least these examples, each demonstrated end to end, not just
implemented:
- Dance institute with uploaded video demo
- Civil services institute with an external registration link
- State government institute with brochure upload
- Central government institute with custom application fields
- Course with no demo
- Course with internal demo registration
- Course with custom required fields
- Disabling a module (e.g. Reviews and feedback) and confirming it disappears from both the
  live app and the admin preview across all four preview surfaces
- Reordering and reconfiguring a field within an enabled module and confirming the change is
  draft until explicitly published

Ensure all configured flows work with loading, validation, empty, error, disabled, draft,
published, and back-navigation states. Report anything you could not runtime-verify as
BLOCKED rather than claiming completion.
```
