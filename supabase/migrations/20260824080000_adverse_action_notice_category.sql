-- PostgreSQL requires a newly added enum value to commit before it is used.
alter type public.notice_category add value if not exists 'ADVERSE_ACTION';
