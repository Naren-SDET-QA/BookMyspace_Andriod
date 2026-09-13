-- Commit the new booking states before functions and constraints reference
-- them. Some PostgreSQL versions reject use of ALTER TYPE ... ADD VALUE in
-- the same transaction as later statements that use the value.
alter type public.booking_status add value if not exists 'awaiting_owner_approval';
alter type public.booking_status add value if not exists 'owner_rejected';
alter type public.booking_status add value if not exists 'approval_expired';
