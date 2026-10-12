# Admin reports and itinerary templates

Backend changes are limited to the five existing `features/admin/admin.*.js` files. No shared migration, trips, reviews or itineraries backend files are changed.

## Database setup (required on each environment)

With PostgreSQL running and backend/.env configured, run from frontend:

```powershell
node tool/setup_admin_templates.cjs
```

The script reads `tool/admin_templates.sql` and adds two independent tables. It is safe to run again. It does not modify existing tables or remove data. Nhat should integrate this SQL into the team's shared migration workflow before deploying this feature to another environment. Merely pulling the code does not install these tables.

Templates store their validated days/activities in JSONB. `admin_template_uses` links templates to destination trips. Trips retain independent itinerary copies; editing/hiding a template does not change previous copies. A template referenced by a trip cannot be deleted; hide it instead. Deleting a destination trip removes that reference.

## Features

- Admin > Reports: pending/resolved/dismissed list, detail/evidence, mandatory internal conclusion notes, reporter notification. Account banning is a separate explicit action and does not automatically resolve a report.
- Admin > Templates: add/edit day plans, optional Cloudinary cover image, hide/show, deletion of unused templates, optimistic version checks.
- Home menu > Plan library: system/community sources, keyword search and newest/usage/rating sorting. Admin can create an independent system template from a completed public community trip.
- Use a plan: pick an active trip where the current user is leader and duration matches. Backend rejects any existing itinerary, locks the destination trip and commits every copied day/activity together. No members or actual expenses are copied.
- Community ratings refer to the original trip. A new system template does not inherit its source's ratings. System templates initially display no ratings and their own usage count.

## API

All routes require login. Reports and template administration additionally require ADMIN.

| Route | Access |
| --- | --- |
| GET /admin/reports | Admin |
| GET /admin/reports/:id | Admin |
| PUT /admin/reports/:id/resolve | Admin |
| GET/POST /admin/templates | Admin |
| GET/PUT/DELETE /admin/templates/:id | Admin |
| PUT /admin/templates/:id/status | Admin |
| POST /admin/templates/from-community/:id | Admin |
| GET /admin/library | Logged-in users |
| GET /admin/library/templates/:id | Logged-in users |
| GET /admin/library/community/:id | Logged-in users |
| POST /admin/library/templates/:id/apply | Destination trip leader |
| POST /admin/library/community/:id/apply | Destination trip leader |

Template create/update accepts JSON or multipart (`coverImage`, `days` as JSON text). Update/status/delete require the `version` returned by a read, sent as `expectedVersion`; delete uses a query parameter.

## Verification

```powershell
# From frontend; builds its own temporary PostgreSQL schema and cleans it up
node --test tool/admin_flow_test.cjs

# Include one real Cloudinary upload and delete that test asset afterwards
$env:TEST_CLOUDINARY='true'
node --test tool/admin_flow_test.cjs
Remove-Item Env:TEST_CLOUDINARY

flutter test --no-pub --dart-define=USE_MOCK_DATA=true test/admin_content_test.dart
```

Tests cover role checks, duplicate report decisions, hidden templates, stale edits, clone ownership/duration/no-overwrite, transaction rollback, independent snapshots, deletion guards and community import/use. Widget tests exercise report persistence, form validation and successful use without success snackbars.

## Separate local compatibility fix (do not include in admin commit)

`lib/features/itinerary/views/itinerary_screen.dart` uses `onReorder` on Flutter 3.38.7 and adjusts the downward insertion index before calling the existing ViewModel. This was separately authorized to allow local compilation. Keep this file out of the admin commit/push and let Phu integrate the compatible callback for the team's Flutter version.

## Linked place activities

The template editor defaults to picking an active place from the existing place catalog. Name/address/category are filled from that place. Free-entry mode supports breaks, transit and uncatalogued activities without a placeId. Backend checks and normalizes linked places on save; apply preserves place_id for itinerary/map/Smart Swap. Hidden/deleted places cause a clear error rather than partial copies or invalid references. Community-to-template import also preserves place links. No schema change is required for this addition.

The catalog picker includes Add place, which opens the shared AdminPlaceFormScreen (including Geoapify map selection). After saving, the picker reloads with the new place name and removes the previous destination filter. Geoapify configuration stays in ignored backend/.env; map requests use the backend proxy. External Geoapify ids are never used as database placeId.

## Remaining UI flows completed

Home menu exposes My recruitment posts, Received requests and Sent requests. Current trip leaders can edit existing posts with the posting form or close them. Closing uses the existing CLOSED state, preserves trip members and reloads the feed. Pending requests can be cancelled from detail or the sent list; cancellation uses the existing hard-delete contract, so reopening shows the join action again. A detail-screen Report action opens the existing review module's form with the trip attached.

Admin's toolbar policy button opens recruitment moderation. Pending trip reports are prioritized. Admin can inspect and warn the current leader or close a recruitment post with a required reason. Hiding a recruitment post does not disable its trip or prevent a later new recruitment post. Report detail exposes safe user/trip snapshots and linked recruitment posts, supports a warning with explicit recipient-visible text, and distinguishes insufficient evidence through a prefixed conclusion note while preserving the existing DISMISSED database status. Internal notes are not sent as warning text.

Backend additions remain within admin and companions. No changes to backend trips/reviews/itineraries, schema or migrations. Doc requests for independent flags and globally disabling all trip operations require a coordinated backend contract; those are not represented as working buttons in this UI. Real-time notifications, system-template ratings, and an in-app appeal workflow remain separate follow-up work.

Request lists share a single CompanionRequestsScreen with app-bar tabs: Sent first by default, Received selected for incoming-request notifications and leader entry points. Both content widgets preserve local state on tab changes; switching tabs does not replace Navigator routes or nest scaffolds.
