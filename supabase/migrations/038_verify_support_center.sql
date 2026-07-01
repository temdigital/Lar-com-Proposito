select
  to_regprocedure('public.create_support_ticket(text,text,text,text)') is not null as create_ticket_function_exists,
  to_regprocedure('public.add_support_message(uuid,text,boolean)') is not null as add_message_function_exists,
  to_regprocedure('public.manage_support_ticket(uuid,text,text,uuid,text)') is not null as manage_ticket_function_exists,
  to_regprocedure('public.manage_contact_message(uuid,text,uuid,text)') is not null as manage_contact_function_exists,
  to_regprocedure('public.create_privacy_request(text,text,text)') is not null as create_privacy_function_exists,
  to_regprocedure('public.manage_privacy_request(uuid,text,text,uuid)') is not null as manage_privacy_function_exists,
  has_function_privilege('authenticated','public.create_support_ticket(text,text,text,text)','EXECUTE') as authenticated_can_create_ticket,
  has_function_privilege('authenticated','public.add_support_message(uuid,text,boolean)','EXECUTE') as authenticated_can_add_message,
  has_function_privilege('authenticated','public.manage_support_ticket(uuid,text,text,uuid,text)','EXECUTE') as authenticated_can_manage_ticket,
  has_function_privilege('authenticated','public.manage_contact_message(uuid,text,uuid,text)','EXECUTE') as authenticated_can_manage_contact,
  has_function_privilege('authenticated','public.create_privacy_request(text,text,text)','EXECUTE') as authenticated_can_create_privacy_request,
  has_function_privilege('authenticated','public.manage_privacy_request(uuid,text,text,uuid)','EXECUTE') as authenticated_can_manage_privacy_request,
  not has_function_privilege('anon','public.create_support_ticket(text,text,text,text)','EXECUTE') as anonymous_cannot_create_ticket,
  not has_function_privilege('anon','public.add_support_message(uuid,text,boolean)','EXECUTE') as anonymous_cannot_add_message,
  not has_function_privilege('anon','public.manage_support_ticket(uuid,text,text,uuid,text)','EXECUTE') as anonymous_cannot_manage_ticket,
  not has_function_privilege('anon','public.manage_contact_message(uuid,text,uuid,text)','EXECUTE') as anonymous_cannot_manage_contact,
  not has_function_privilege('anon','public.create_privacy_request(text,text,text)','EXECUTE') as anonymous_cannot_create_privacy_request,
  not has_function_privilege('anon','public.manage_privacy_request(uuid,text,text,uuid)','EXECUTE') as anonymous_cannot_manage_privacy_request,
  not has_table_privilege('authenticated','public.support_tickets','INSERT') as direct_ticket_insert_blocked,
  not has_table_privilege('authenticated','public.support_tickets','UPDATE') as direct_ticket_update_blocked,
  not has_table_privilege('authenticated','public.support_messages','INSERT') as direct_message_insert_blocked,
  not has_table_privilege('authenticated','public.privacy_requests','INSERT') as direct_privacy_insert_blocked,
  not has_table_privilege('authenticated','public.privacy_requests','UPDATE') as direct_privacy_update_blocked,
  not has_table_privilege('authenticated','public.contact_messages','UPDATE') as direct_contact_update_blocked,
  exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='support_messages' and policyname='support_messages_select'
  ) as protected_message_policy_exists,
  exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='support_tickets' and column_name='last_message_at'
  ) as last_message_column_exists,
  exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='contact_messages' and column_name='admin_note'
  ) as contact_admin_note_column_exists;
