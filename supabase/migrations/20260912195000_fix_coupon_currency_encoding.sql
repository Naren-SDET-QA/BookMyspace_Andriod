-- Repair the customer-visible development coupon text that was stored with
-- UTF-8 mojibake. This is idempotent and only targets the known coupon code.
update public.coupons
set description = 'Flat ₹500 off on bookings above ₹10,000'
where code = 'FESTIVE500'
  and description like 'Flat %500 off on bookings above %10,000';
