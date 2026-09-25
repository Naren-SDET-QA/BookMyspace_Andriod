# Pending SQL Migration: Listing Template Configuration

**File**: `supabase/pending/20260921120000_listing_template_config.sql`

**Status**: ⏸️ AWAITING APPROVAL — Do NOT apply until reviewed and approved

---

## Summary

This migration promotes the listing template overlay (currently in `metadata.listing` JSONB) into first-class database columns and dedicated tables. Enables admin RLS enforcement and draft/publish state without client-side filtering.

**Optional**: The app already reads/writes `venue_categories.metadata.listing`. This migration is optional but recommended for:
- Server-side draft/publish enforcement
- Admin-only visibility of unpublished categories
- Filter group management
- Future extensibility (per-listing field values)

---

## Changes Breakdown

### 1. Columns Added to `venue_categories`

```sql
ALTER TABLE public.venue_categories ADD COLUMN IF NOT EXISTS:
  ✅ listing_template TEXT DEFAULT 'generic'
     → Template type: generic|hall|hotel|education|temple|sports|studio|pg
  
  ✅ listing_config JSONB DEFAULT '{}'
     → Category-specific field config, filters, display rules
  
  ✅ is_published BOOLEAN DEFAULT true
     → Draft/publish toggle (customers only see published=true)
  
  ✅ cta_book TEXT DEFAULT 'Book & Pay'
     → Customizable booking button label
  
  ✅ cta_availability TEXT DEFAULT 'Availability'
     → Customizable availability button label
  
  ✅ accent_color TEXT NULL
     → Category brand color (hex or CSS color name)
```

**Constraint Added**:
```sql
CHECK (listing_template IN ('generic','hall','hotel','education','temple','sports','studio','pg'))
```

**Backfill**: All existing categories get values from `metadata.listing` if present, else defaults.

**Index Added**:
```sql
CREATE INDEX idx_venue_categories_published 
ON public.venue_categories (is_published, is_active, display_order)
WHERE deleted_at IS NULL;
```
→ Accelerates filtering for published categories in listing queries

---

### 2. New Table: `category_filter_groups`

Stores category-specific search filters (different per category).

```sql
CREATE TABLE public.category_filter_groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id UUID NOT NULL REFERENCES venue_categories(id) ON DELETE CASCADE,
  slug TEXT NOT NULL,                    -- e.g., 'guest_count', 'room_type'
  label TEXT NOT NULL,                   -- Display name
  filter_type TEXT DEFAULT 'options'     -- options|range|toggle
    CHECK (filter_type IN ('options','range','toggle')),
  options TEXT[] DEFAULT '{}',           -- ['1 guest','2 guests',...] for options
  display_order INTEGER DEFAULT 0,       -- Sort order
  is_required BOOLEAN DEFAULT false,     -- Mandatory vs optional
  is_active BOOLEAN DEFAULT true,        -- Enable/disable filter
  
  UNIQUE (category_id, slug)             -- One filter per category
);

CREATE INDEX idx_category_filter_groups_category 
ON public.category_filter_groups (category_id, display_order);
```

**RLS Policies**:
- **Public Read**: Customers see active filters only if category is published & active
- **Admin All**: Managers (is_category_manager) can read/write all filters

---

### 3. New Table: `listing_field_values` (Optional)

Stores per-listing extra field values (e.g., booking form extras). **NOT YET USED** — UI-only for now.

```sql
CREATE TABLE public.listing_field_values (
  listing_id UUID NOT NULL,
  field_key TEXT NOT NULL,
  value TEXT,
  updated_at TIMESTAMPTZ DEFAULT now(),
  
  PRIMARY KEY (listing_id, field_key)
);
```

**RLS Policies**:
- **Public Read**: All can see field values
- **Owner Write**: Category managers or venue owners can write

---

## RLS Impact

### Who Sees What

| Role | Before Migration | After Migration |
|------|------------------|-----------------|
| **Anon / Guest** | All active categories | Only published + active |
| **Authenticated** | All active categories | Only published + active |
| **Category Manager** | Own categories | All categories (draft + published) |
| **Admin** | (RLS disabled) | (RLS disabled) |

### Policy Changes

**`categories_public_read`** policy is **updated**:
```sql
-- BEFORE
USING (is_active AND deleted_at IS NULL);

-- AFTER
USING (is_active AND is_published AND deleted_at IS NULL);
```

→ Customers no longer see unpublished categories

**New Policies**:
- `category_filter_groups_public_read` — Customers see only active filters on published categories
- `category_filter_groups_admin_all` — Managers can read/write all filters
- `listing_field_values_public_read` — All can read field values
- `listing_field_values_owner_write` — Managers/owners can write

---

## Rollback SQL

```sql
-- ROLLBACK SCRIPT (copy to apply if needed)

DROP POLICY IF EXISTS listing_field_values_owner_write ON public.listing_field_values;
DROP POLICY IF EXISTS listing_field_values_public_read ON public.listing_field_values;
DROP TABLE IF EXISTS public.listing_field_values;

DROP POLICY IF EXISTS category_filter_groups_admin_all ON public.category_filter_groups;
DROP POLICY IF EXISTS category_filter_groups_public_read ON public.category_filter_groups;
DROP TABLE IF EXISTS public.category_filter_groups;

DROP POLICY IF EXISTS categories_public_read ON public.venue_categories;
CREATE POLICY categories_public_read ON public.venue_categories
  FOR SELECT TO anon, authenticated
  USING (is_active AND deleted_at IS NULL);

DROP INDEX IF EXISTS public.idx_venue_categories_published;

ALTER TABLE public.venue_categories
  DROP CONSTRAINT IF EXISTS venue_categories_listing_template_chk;

ALTER TABLE public.venue_categories
  DROP COLUMN IF EXISTS listing_template,
  DROP COLUMN IF EXISTS listing_config,
  DROP COLUMN IF EXISTS is_published,
  DROP COLUMN IF EXISTS cta_book,
  DROP COLUMN IF EXISTS cta_availability,
  DROP COLUMN IF EXISTS accent_color;
```

---

## Data Safety

✅ **No data loss**: Backfill reads from `metadata.listing`, preserves existing values  
✅ **Reversible**: Rollback script provided, can be tested first in staging  
✅ **RLS backward compatible**: All default values match current behavior (is_published=true)  
✅ **Zero downtime**: Backfill happens server-side, no client blocking  
✅ **Index on WHERE deleted_at IS NULL**: Only live rows indexed (no bloat)

---

## Affected Tables

| Table | Operation | Impact |
|-------|-----------|--------|
| `venue_categories` | ALTER | +6 columns, +1 constraint, +1 index, +1 policy |
| `category_filter_groups` | CREATE | New table (linked to categories) |
| `listing_field_values` | CREATE | New table (optional, not yet used) |

---

## Next Steps

1. ✅ **Review** this migration for correctness
2. ⏳ **Test** in staging environment (apply migration, verify backfill)
3. ⏳ **Test** app behavior: categories render, filters load, RLS works
4. ⏳ **Approve** and apply to production via Supabase dashboard
5. ⏳ **Monitor** query performance and RLS enforcement

---

## Approval Checklist

- [ ] Rollback plan reviewed
- [ ] RLS impact understood (is_published flag enforcement)
- [ ] No conflicts with existing schema
- [ ] Backfill logic correct (reads from metadata.listing)
- [ ] Index strategy reasonable (WHERE deleted_at IS NULL)
- [ ] Approved for production application

**Do NOT apply until all checkboxes are confirmed.**

---

## Questions?

- What happens if a category has no `metadata.listing`? → Uses defaults (is_published=true, template='generic')
- Can we roll back quickly? → Yes, rollback script is in the migration file
- Will this block writes? → No, backfill is server-side and non-blocking
- Do we need to update the app code? → App already handles these fields, migration just makes them persistent
