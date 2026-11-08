-- ============================================================
-- COMPTE DE DÉMO ADMINISTRATEUR
-- ============================================================
-- Ce script permet d'associer un compte Supabase existant à un profil
-- d'application de type admin pour tester le projet sans donner de
-- vraies données sensibles.
--
-- 1) Créer l'utilisateur dans Supabase > Authentication > Users
--    Email : demo@suivi-tc3.invalid
--    Mot de passe : Demo1234
--    Cocher : Auto confirm user
--
-- 2) Exécuter ce script dans SQL Editor
--
-- 3) Ensuite, dans le navigateur, se connecter avec :
--    Identifiant : demo
--    Mot de passe : Demo1234
--
-- 4) À la première connexion, l'application demandera de choisir un
--    nouveau mot de passe.
-- ============================================================

create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  identifiant text unique,
  nom text,
  role text not null default 'lecture' check (role in ('admin','responsable','lecture')),
  terminaux text[] not null default array['TCE','TC3'],
  actif boolean not null default true,
  doit_changer_mdp boolean not null default true,
  email_contact text,
  created_at timestamptz not null default now()
);

alter table public.profiles add column if not exists identifiant text unique;
alter table public.profiles add column if not exists doit_changer_mdp boolean not null default true;
alter table public.profiles add column if not exists email_contact text;

alter table public.profiles enable row level security;

create or replace function public.mdp_change() returns void
language sql security definer set search_path = public as $$
  update public.profiles
  set doit_changer_mdp = false
  where user_id = auth.uid()
$$;

revoke all on function public.mdp_change() from public;
grant execute on function public.mdp_change() to authenticated;

create or replace function public.mon_role() returns text
language sql stable security definer set search_path = public as $$
  select role
  from public.profiles
  where user_id = auth.uid() and actif
$$;

revoke all on function public.mon_role() from public;
grant execute on function public.mon_role() to authenticated;

-- associer le compte Supabase de test au profil admin de l'application
DO $$
DECLARE v_user_id uuid;
BEGIN
  select id into v_user_id
  from auth.users
  where lower(email) = 'demo@suivi-tc3.invalid'
  limit 1;

  if v_user_id is not null then
    insert into public.profiles (
      user_id, email, identifiant, nom, role, terminaux, actif, doit_changer_mdp
    )
    values (
      v_user_id,
      'demo@suivi-tc3.invalid',
      'demo',
      'Compte de démo',
      'admin',
      array['TCE','TC3'],
      true,
      true
    )
    on conflict (user_id) do update
    set email = excluded.email,
        identifiant = excluded.identifiant,
        nom = excluded.nom,
        role = excluded.role,
        terminaux = excluded.terminaux,
        actif = excluded.actif,
        doit_changer_mdp = excluded.doit_changer_mdp;
  end if;
END $$;

-- vérification rapide
select
  user_id,
  email,
  identifiant,
  nom,
  role,
  terminaux,
  actif,
  doit_changer_mdp
from public.profiles
where lower(email) = 'demo@suivi-tc3.invalid';
