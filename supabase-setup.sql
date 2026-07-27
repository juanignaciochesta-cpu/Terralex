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
--    OJO: solo borramos las politicas que creamos nosotros, por nombre.
--    Borrar TODAS las de storage.objects rompe cualquier otro bucket del
--    proyecto (por eso ya no se hace con un loop sobre pg_policies).
drop policy if exists "fotos lectura publica" on storage.objects;
drop policy if exists "fotos subir solo autenticados" on storage.objects;
drop policy if exists "fotos actualizar solo autenticados" on storage.objects;
drop policy if exists "fotos borrar solo autenticados" on storage.objects;

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
--
-- IMPORTANTE — configuración de URLs (Authentication > URL Configuration):
--    Site URL debe ser https://terralex.com.ar (NO localhost:3000).
--    En Redirect URLs agregá https://terralex.com.ar/**
--    Si queda apuntando a localhost, los links de "recuperar contraseña"
--    que reciben por email llevan a una pagina que no existe.
-- ============================================================
