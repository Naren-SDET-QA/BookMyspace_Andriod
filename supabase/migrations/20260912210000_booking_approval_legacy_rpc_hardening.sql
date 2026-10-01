-- The old helper could confirm a pending booking without checking a captured
-- payment or owner approval. It remains available only to trusted server-side
-- jobs; client confirmation is exclusively confirm_venue_booking.
revoke all on function public.confirm_booking(uuid, text) from public, anon, authenticated;
grant execute on function public.confirm_booking(uuid, text) to service_role;

revoke all on function public.request_venue_booking(uuid, uuid, date, uuid, uuid, numeric, numeric, numeric, integer) from public, anon;
revoke all on function public.approve_venue_booking(uuid, uuid, integer) from public, anon;
revoke all on function public.reject_venue_booking(uuid, uuid, text) from public, anon;
revoke all on function public.cancel_venue_booking(uuid) from public, anon;
revoke all on function public.confirm_venue_booking(uuid, uuid, text, text) from public, anon, authenticated;
revoke all on function public.expire_owner_booking_requests(integer) from public, anon, authenticated;

grant execute on function public.request_venue_booking(uuid, uuid, date, uuid, uuid, numeric, numeric, numeric, integer) to authenticated;
grant execute on function public.approve_venue_booking(uuid, uuid, integer) to authenticated;
grant execute on function public.reject_venue_booking(uuid, uuid, text) to authenticated;
grant execute on function public.cancel_venue_booking(uuid) to authenticated;
grant execute on function public.confirm_venue_booking(uuid, uuid, text, text) to service_role;
grant execute on function public.expire_owner_booking_requests(integer) to service_role;
