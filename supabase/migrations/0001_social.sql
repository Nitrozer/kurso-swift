-- Le social de Kurso : la ligue, les amis, les groupes de classe.
--
-- CE QUI N'EST PAS ICI, ET N'Y SERA JAMAIS
-- Pas une page, pas une carte, pas un enregistrement, pas un PDF. Le §12 du
-- contrat dit « aucune donnee de cours sur un serveur » et ajoute « cette
-- regle-la ne bouge pas ». Ce qui circule tient en peu de choses : un prenom,
-- un code de six signes, des XP de la semaine, et qui a demande quoi a qui.
-- Meme la demande de notes ne transporte qu'un NOM de cours et une date : les
-- pages partent d'appareil a appareil, par AirDrop.
--
-- Le prefixe `kurso_` est deliberé : ce projet Supabase heberge encore le
-- schema d'une version precedente de l'application (profiles, notes,
-- notebooks…). On n'y touche pas, et on ne reutilise aucun de ses noms.

-- ------------------------------------------------------------------ profils

create table if not exists public.kurso_profiles (
  id              uuid primary key references auth.users on delete cascade,
  display_name    text        not null default '' check (char_length(display_name) <= 40),
  friend_code     text        not null unique check (friend_code ~ '^[0-9A-Z]{6}$'),
  grade           text        not null default 'HB' check (grade in ('HB', '2B', '4B', '6B')),
  weekly_xp       integer     not null default 0 check (weekly_xp >= 0),
  week_started_at timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

comment on table public.kurso_profiles is
  'Ce qu''un ami voit de vous : un prenom, un code, un grade, les XP de la semaine. Rien de scolaire.';
comment on column public.kurso_profiles.weekly_xp is
  'Gagnes hors ligne, donc declares par le client. Une ligue de douze amis sans classement public ni recompense ne vaut pas une verification serveur ; on l''ecrit plutot que de faire semblant.';

alter table public.kurso_profiles enable row level security;

-- ------------------------------------------------------------------- liens

create table if not exists public.kurso_friendships (
  id         uuid        primary key default gen_random_uuid(),
  requester  uuid        not null references auth.users on delete cascade,
  addressee  uuid        not null references auth.users on delete cascade,
  state      text        not null default 'pending' check (state in ('pending', 'accepted', 'declined')),
  created_at timestamptz not null default now(),
  constraint kurso_friendships_two_people check (requester <> addressee),
  constraint kurso_friendships_once unique (requester, addressee)
);

create index if not exists kurso_friendships_addressee_idx
  on public.kurso_friendships (addressee) where state = 'pending';

alter table public.kurso_friendships enable row level security;

-- ------------------------------------------------------------------ classes

create table if not exists public.kurso_groups (
  id         uuid        primary key,
  name       text        not null check (char_length(btrim(name)) between 1 and 40),
  join_code  text        not null unique check (join_code ~ '^[0-9A-Z]{6}$'),
  owner      uuid        not null references auth.users on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.kurso_group_members (
  group_id  uuid        not null references public.kurso_groups on delete cascade,
  member    uuid        not null references auth.users on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (group_id, member)
);

alter table public.kurso_groups        enable row level security;
alter table public.kurso_group_members enable row level security;

-- --------------------------------------------------------- demandes de notes

create table if not exists public.kurso_note_asks (
  id          uuid        primary key default gen_random_uuid(),
  asker       uuid        not null references auth.users on delete cascade,
  asked       uuid        not null references auth.users on delete cascade,
  course_name text        not null check (char_length(course_name) <= 60),
  slot_id     text        not null check (char_length(slot_id) <= 120),
  slot_start  timestamptz not null,
  state       text        not null default 'pending'
              check (state in ('pending', 'accepted', 'declined', 'handed')),
  created_at  timestamptz not null default now(),
  constraint kurso_note_asks_two_people check (asker <> asked),
  constraint kurso_note_asks_once unique (asker, asked, slot_id)
);

comment on column public.kurso_note_asks.course_name is
  'Le NOM du cours (« Analyse »), jamais son contenu. Les pages ne passent pas par ici : elles partent par AirDrop, d''appareil a appareil.';
comment on column public.kurso_note_asks.state is
  '« handed » signifie que le fichier est parti par AirDrop. Le serveur n''a fait que transmettre la question.';

alter table public.kurso_note_asks enable row level security;

-- -------------------------------------------------------------- qui voit qui
--
-- Ces trois fonctions sont en `security definer` pour une raison precise :
-- une politique sur `kurso_profiles` qui lirait `kurso_friendships` sous RLS
-- declencherait une recursion. Elles ne lisent rien d'autre que le lien entre
-- deux comptes, et ne rendent qu'un booleen.

create or replace function public.kurso_is_friend(other uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.kurso_friendships f
    where f.state = 'accepted'
      and ((f.requester = auth.uid() and f.addressee = other)
        or (f.addressee = auth.uid() and f.requester = other))
  );
$$;

-- Visibilite du profil : un lien en cours suffit. Sans cela, une demande
-- recue s'afficherait sans prenom — RLS cacherait celui qui frappe a la porte.
create or replace function public.kurso_has_link(other uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.kurso_friendships f
    where f.state in ('pending', 'accepted')
      and ((f.requester = auth.uid() and f.addressee = other)
        or (f.addressee = auth.uid() and f.requester = other))
  );
$$;

create or replace function public.kurso_shares_group(other uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from public.kurso_group_members mine
    join public.kurso_group_members theirs on theirs.group_id = mine.group_id
    where mine.member = auth.uid() and theirs.member = other
  );
$$;

create or replace function public.kurso_in_group(target uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.kurso_group_members m
    where m.group_id = target and m.member = auth.uid()
  );
$$;

-- ------------------------------------------------------------- politiques

drop policy if exists "profil : le sien"          on public.kurso_profiles;
drop policy if exists "profil : ses amis"         on public.kurso_profiles;
drop policy if exists "profil : creation"         on public.kurso_profiles;
drop policy if exists "profil : mise a jour"      on public.kurso_profiles;

create policy "profil : le sien" on public.kurso_profiles
  for select to authenticated using (id = auth.uid());

-- Un ami accepte, ou quelqu'un du meme groupe de classe. Personne d'autre :
-- il n'existe aucune facon de lister les comptes de Kurso.
create policy "profil : ses amis" on public.kurso_profiles
  for select to authenticated
  using (public.kurso_has_link(id) or public.kurso_shares_group(id));

create policy "profil : creation" on public.kurso_profiles
  for insert to authenticated with check (id = auth.uid());

create policy "profil : mise a jour" on public.kurso_profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists "lien : les siens"    on public.kurso_friendships;
drop policy if exists "lien : demander"     on public.kurso_friendships;
drop policy if exists "lien : repondre"     on public.kurso_friendships;
drop policy if exists "lien : annuler"      on public.kurso_friendships;
drop policy if exists "lien : retirer"      on public.kurso_friendships;

create policy "lien : les siens" on public.kurso_friendships
  for select to authenticated using (requester = auth.uid() or addressee = auth.uid());

create policy "lien : demander" on public.kurso_friendships
  for insert to authenticated with check (requester = auth.uid() and state = 'pending');

-- Celui qui recoit accepte ou refuse.
create policy "lien : repondre" on public.kurso_friendships
  for update to authenticated
  using (addressee = auth.uid())
  with check (addressee = auth.uid() and state in ('accepted', 'declined'));

-- Celui qui a demande peut se retracter, jamais s'accepter lui-meme.
create policy "lien : annuler" on public.kurso_friendships
  for update to authenticated
  using (requester = auth.uid() and state = 'pending')
  with check (requester = auth.uid() and state = 'declined');

create policy "lien : retirer" on public.kurso_friendships
  for delete to authenticated using (requester = auth.uid() or addressee = auth.uid());

drop policy if exists "groupe : le sien"    on public.kurso_groups;
drop policy if exists "groupe : creer"      on public.kurso_groups;
drop policy if exists "groupe : renommer"   on public.kurso_groups;

create policy "groupe : le sien" on public.kurso_groups
  for select to authenticated using (public.kurso_in_group(id));

create policy "groupe : creer" on public.kurso_groups
  for insert to authenticated with check (owner = auth.uid());

create policy "groupe : renommer" on public.kurso_groups
  for update to authenticated using (owner = auth.uid()) with check (owner = auth.uid());

drop policy if exists "membre : les siens"  on public.kurso_group_members;
drop policy if exists "membre : partir"     on public.kurso_group_members;

create policy "membre : les siens" on public.kurso_group_members
  for select to authenticated using (public.kurso_in_group(group_id));

-- On entre par la fonction `kurso_join_group`, qui verifie le code et le
-- nombre de places. On sort quand on veut, et seul pour soi-meme.
create policy "membre : partir" on public.kurso_group_members
  for delete to authenticated using (member = auth.uid());

drop policy if exists "notes : les siennes" on public.kurso_note_asks;
drop policy if exists "notes : demander"    on public.kurso_note_asks;
drop policy if exists "notes : repondre"    on public.kurso_note_asks;
drop policy if exists "notes : retirer"     on public.kurso_note_asks;

create policy "notes : les siennes" on public.kurso_note_asks
  for select to authenticated using (asker = auth.uid() or asked = auth.uid());

-- On ne demande ses notes qu'a un ami ou a quelqu'un de sa classe. Un inconnu
-- ne peut pas frapper a la porte.
create policy "notes : demander" on public.kurso_note_asks
  for insert to authenticated
  with check (
    asker = auth.uid()
    and (public.kurso_is_friend(asked) or public.kurso_shares_group(asked))
  );

create policy "notes : repondre" on public.kurso_note_asks
  for update to authenticated
  using (asked = auth.uid() or asker = auth.uid())
  with check (asked = auth.uid() or asker = auth.uid());

create policy "notes : retirer" on public.kurso_note_asks
  for delete to authenticated using (asker = auth.uid() or asked = auth.uid());

-- ------------------------------------------------------------- le code ami
--
-- La seule facon de trouver quelqu'un : connaitre son code en entier. Pas de
-- recherche par prenom, pas de « personnes que vous connaissez peut-etre »,
-- aucune liste. On ne tombe sur personne par hasard.

create or replace function public.kurso_find_by_code(code text)
returns table (id uuid, display_name text, grade text)
language sql stable security definer set search_path = public as $$
  select p.id, p.display_name, p.grade
  from public.kurso_profiles p
  where p.friend_code = upper(btrim(code))
    and p.id <> auth.uid()
  limit 1;
$$;

revoke all on function public.kurso_find_by_code(text) from public, anon;
grant execute on function public.kurso_find_by_code(text) to authenticated;

-- ------------------------------------------------------------ entrer en classe

create or replace function public.kurso_join_group(code text)
returns table (id uuid, name text, join_code text, owner uuid, member_count bigint)
language plpgsql volatile security definer set search_path = public as $$
declare
  target public.kurso_groups;
  seats  bigint;
begin
  select * into target from public.kurso_groups g where g.join_code = upper(btrim(code));
  if not found then
    raise exception 'groupe introuvable' using errcode = 'no_data_found';
  end if;

  select count(*) into seats from public.kurso_group_members m where m.group_id = target.id;
  -- Quarante : une classe, pas un reseau.
  if seats >= 40 and not exists (
       select 1 from public.kurso_group_members m
       where m.group_id = target.id and m.member = auth.uid()) then
    raise exception 'groupe complet' using errcode = 'check_violation';
  end if;

  insert into public.kurso_group_members (group_id, member)
  values (target.id, auth.uid())
  on conflict do nothing;

  select count(*) into seats from public.kurso_group_members m where m.group_id = target.id;
  return query select target.id, target.name, target.join_code, target.owner, seats;
end;
$$;

revoke all on function public.kurso_join_group(text) from public, anon;
grant execute on function public.kurso_join_group(text) to authenticated;

-- Celui qui cree un groupe en fait partie. Sans ce declencheur, il en serait
-- proprietaire sans etre membre, et ne le verrait meme pas.
create or replace function public.kurso_group_owner_joins() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.kurso_group_members (group_id, member)
  values (new.id, new.owner)
  on conflict do nothing;
  return new;
end;
$$;

drop trigger if exists kurso_group_owner_joins on public.kurso_groups;
create trigger kurso_group_owner_joins
  after insert on public.kurso_groups
  for each row execute function public.kurso_group_owner_joins();
