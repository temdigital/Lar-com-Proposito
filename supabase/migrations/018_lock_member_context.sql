begin;

revoke execute on function public.get_my_app_context() from public;
revoke execute on function public.get_my_app_context() from anon;
grant execute on function public.get_my_app_context() to authenticated;

commit;
