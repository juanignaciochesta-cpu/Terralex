-- ============================================================
-- TERRALEX — Configuración de seguridad de Supabase
-- Pegar TODO este archivo en: Supabase > SQL Editor > New query > Run
-- Objetivo: lectura pública, escritura SOLO para usuarios logueados
-- ============================================================

-- 1) Activar Row Level Security en la tabla de propiedades
alter table public.propiedades enable row level security;

-- 2) Eliminar políticas viejas que permitían escribir a cualquiera
--    (borra todas las políticas existentes de la tabla para empezar limpio)
do $$
declare pol record;
begin
  for pol in
    select policyname from pg_policies
    where schemaname = 'public' and tablename = 'propiedades'
  loop
    execute format('drop policy %I on public.propiedades', pol.policyname);
  end loop;
end $$;

-- 3) Políticas nuevas para la tabla propiedades
create policy "lectura publica"
  on public.propiedades for select
  using (true);

create policy "insertar solo autenticados"
  on public.propiedades for insert
  to authenticated
  with check (true);

create policy "editar solo autenticados"
  on public.propiedades for update
  to authenticated
  using (true);

create policy "borrar solo autenticados"
  on public.propiedades for delete
  to authenticated
  using (true);

-- 4) Políticas del Storage (bucket fotos-propiedades)
--    Primero borramos las políticas existentes de storage.objects
--    que afecten a este bucket (las genéricas creadas antes)
do $$
declare pol record;
begin
  for pol in
    select policyname from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
  loop
    execute format('drop policy %I on storage.objects', pol.policyname);
  end loop;
end $$;

create policy "fotos lectura publica"
  on storage.objects for select
  using (bucket_id = 'fotos-propiedades');

create policy "fotos subir solo autenticados"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'fotos-propiedades');

create policy "fotos actualizar solo autenticados"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'fotos-propiedades');

create policy "fotos borrar solo autenticados"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'fotos-propiedades');

-- ============================================================
-- LISTO. Después de correr esto:
-- 1. Andá a Authentication > Users > Add user y creá los usuarios
--    del equipo (email + contraseña fuerte). Marcá "Auto Confirm User".
-- 2. El panel admin del sitio ahora pide ese email y contraseña.
-- ============================================================
