-- Lisière — la partie gardée sur le compte (outils/sauvegarde.sql), dans le Supabase des jeux (« Vallée de pierre »)
-- Une partie en cours s'écrit sur l'appareil (scripts/partie_gardee.gd) ; connecté, elle s'écrit aussi sur le compte StoneValley :
-- on la reprend d'un autre appareil, et le portail montre où l'on en est. Une table fermée, et quatre fonctions :
--   lisiere_sauvegardes   une ligne par compte : la partie (donnees), ce qu'en montre le portail (resume), sa révision, l'appareil
--                         qui l'a écrite, et quand.
--   lisiere_garder(…)     écrit la partie du compte connecté. Elle n'écrase pas ce qu'un autre appareil a écrit depuis la dernière
--                         révision que celui-ci a lue (« conflit ») ; une partie nouvelle, elle, remplace l'ancienne.
--   lisiere_reprendre()   la partie du compte connecté, pour la reprendre (partie : null s'il n'y en a pas).
--   lisiere_oublier(…)    la partie est finie (la veilleuse est morte) : elle s'efface ; pas celle qu'un autre appareil a écrite depuis.
--   lisiere_avancee()     pour le portail : la partie en cours (son résumé, pas la partie elle-même), le record, le rang, les
--                         dernières parties finies (lisiere_parties, celles du tableau des scores).
-- Le compte supprimé emporte sa partie (on delete cascade). Appliqué le 17 novembre 2026 (migration « lisiere_sauvegardes »).
-- Pour tout retirer : la fin de ce fichier.

create table public.lisiere_sauvegardes (
  utilisateur uuid primary key references auth.users (id) on delete cascade,
  donnees jsonb not null,                          -- la partie gardée, telle que scripts/partie_gardee.gd l'écrit (photo)
  resume jsonb not null default '{}'::jsonb,       -- ce que le portail en montre : le lieu, le jour, les nuits, la saison…
  rev integer not null default 1,                  -- chaque écriture l'augmente d'un
  appareil text not null default '',               -- l'appareil qui l'a écrite (un nom tiré au hasard, gardé sur lui)
  maj_le timestamptz not null default now()
);
comment on table public.lisiere_sauvegardes is 'Lisière : la partie en cours de chaque compte. Accès uniquement par lisiere_garder, lisiere_reprendre, lisiere_oublier, lisiere_avancee.';
alter table public.lisiere_sauvegardes enable row level security;
revoke all on public.lisiere_sauvegardes from anon, authenticated;

create function public.lisiere_garder(p_donnees jsonb, p_resume jsonb, p_appareil text, p_rev integer default null, p_nouvelle boolean default false)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  moi uuid := auth.uid();
  s public.lisiere_sauvegardes;
begin
  if moi is null then return jsonb_build_object('ok', false, 'erreur', 'compte requis'); end if;
  if p_donnees is null or jsonb_typeof(p_donnees) <> 'object' or not (p_donnees ? 'v') then
    return jsonb_build_object('ok', false, 'erreur', 'partie invalide');
  end if;
  if octet_length(p_donnees::text) > 2000000 then return jsonb_build_object('ok', false, 'erreur', 'partie trop lourde'); end if;
  if p_resume is null or jsonb_typeof(p_resume) <> 'object' or octet_length(p_resume::text) > 4000 then
    return jsonb_build_object('ok', false, 'erreur', 'résumé invalide');
  end if;
  if p_appareil is null or char_length(p_appareil) not between 4 and 64 then return jsonb_build_object('ok', false, 'erreur', 'appareil invalide'); end if;
  select * into s from public.lisiere_sauvegardes where utilisateur = moi for update;
  if s.utilisateur is null then
    insert into public.lisiere_sauvegardes (utilisateur, donnees, resume, rev, appareil) values (moi, p_donnees, p_resume, 1, p_appareil);
    return jsonb_build_object('ok', true, 'rev', 1);
  end if;
  -- (un autre appareil a écrit depuis la révision que celui-ci connaît : on ne l'écrase pas, sauf pour une partie nouvelle)
  if not coalesce(p_nouvelle, false) and s.appareil <> p_appareil and (p_rev is null or s.rev > p_rev) then
    return jsonb_build_object('ok', false, 'erreur', 'conflit', 'rev', s.rev, 'maj_le', s.maj_le, 'resume', s.resume);
  end if;
  update public.lisiere_sauvegardes set donnees = p_donnees, resume = p_resume, rev = s.rev + 1, appareil = p_appareil, maj_le = now()
    where utilisateur = moi;
  return jsonb_build_object('ok', true, 'rev', s.rev + 1);
end $$;

create function public.lisiere_reprendre()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  moi uuid := auth.uid();
  s public.lisiere_sauvegardes;
begin
  if moi is null then return jsonb_build_object('ok', false, 'erreur', 'compte requis'); end if;
  select * into s from public.lisiere_sauvegardes where utilisateur = moi;
  if s.utilisateur is null then return jsonb_build_object('ok', true, 'partie', null); end if;
  return jsonb_build_object('ok', true, 'partie', jsonb_build_object('donnees', s.donnees, 'rev', s.rev, 'appareil', s.appareil, 'maj_le', s.maj_le));
end $$;

create function public.lisiere_oublier(p_appareil text, p_rev integer default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  moi uuid := auth.uid();
  n integer;
begin
  if moi is null then return jsonb_build_object('ok', false, 'erreur', 'compte requis'); end if;
  delete from public.lisiere_sauvegardes
    where utilisateur = moi and (appareil = coalesce(p_appareil, '') or (p_rev is not null and rev <= p_rev));
  get diagnostics n = row_count;
  return jsonb_build_object('ok', true, 'efface', n > 0);
end $$;

create function public.lisiere_avancee()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  moi uuid := auth.uid();
  v_meilleur integer; v_parties integer; v_rang integer;
begin
  if moi is null then return jsonb_build_object('ok', false, 'erreur', 'compte requis'); end if;
  select max(x.nuits), count(*) into v_meilleur, v_parties from public.lisiere_parties x where x.utilisateur = moi and x.fin is not null;
  if v_meilleur is not null then
    select 1 + count(*) into v_rang from (
      select x.utilisateur, max(x.nuits) as m from public.lisiere_parties x where x.fin is not null group by x.utilisateur
    ) t where t.m > v_meilleur;
  end if;
  return jsonb_build_object('ok', true, 'pseudo', public.lisiere_nom(moi),
    'en_cours', (select jsonb_build_object('resume', s.resume, 'maj_le', s.maj_le) from public.lisiere_sauvegardes s where s.utilisateur = moi),
    'meilleur', v_meilleur, 'rang', v_rang, 'parties', v_parties,
    'dernieres', (select coalesce(jsonb_agg(jsonb_build_object('lieu', d.lieu_nom, 'nuits', d.nuits, 'fin', d.fin) order by d.fin desc), '[]'::jsonb)
      from (select x.lieu_nom, x.nuits, x.fin from public.lisiere_parties x where x.utilisateur = moi and x.fin is not null order by x.fin desc limit 5) d));
end $$;

revoke execute on function public.lisiere_garder(jsonb, jsonb, text, integer, boolean), public.lisiere_reprendre(),
  public.lisiere_oublier(text, integer), public.lisiere_avancee() from public, anon;
grant execute on function public.lisiere_garder(jsonb, jsonb, text, integer, boolean), public.lisiere_reprendre(),
  public.lisiere_oublier(text, integer), public.lisiere_avancee() to authenticated;

-- Pour tout retirer :
--   drop function public.lisiere_garder(jsonb, jsonb, text, integer, boolean), public.lisiere_reprendre(), public.lisiere_oublier(text, integer),
--     public.lisiere_avancee();
--   drop table public.lisiere_sauvegardes;
