-- Towny: todo lo que la app guarda de una persona, en tablas.
--
-- Lo que NO está acá es el pueblo en sí: las casas, los hitos, las calles y
-- la gente se calculan siempre a partir de esto (el hábito, su comarca, su
-- crónica de obras y sus piezas), igual que en el teléfono. Guardar la
-- geometría sería guardar dos veces lo mismo, y la segunda copia se quedaría
-- vieja en cuanto cambie una receta.
--
-- Cada tabla lleva `user_id` y una política que deja a cada uno ver y tocar
-- sólo lo suyo. El traductor de Dart que llena estas filas está en
-- `lib/sync/tables.dart`, y un test comprueba que las columnas de los dos
-- lados coinciden.

-- ----------------------------------------------------------------- el valle

create table if not exists public.valleys (
  user_id uuid primary key default auth.uid()
    references auth.users (id) on delete cascade,
  -- Qué pueblo se estaba mirando: su posición en `habits.position`.
  active int not null default 0,
  -- Si la puerta a más de un pueblo ya está abierta.
  unlocked boolean not null default false,
  -- Hasta dónde se vio el buzón del widget.
  seen_arrival int not null default 0,
  -- Los ajustes tal como los guarda la app: `{"clave": "valor"}`. Los de
  -- desarrollo (la hora y la estación fingidas) no viajan: son de cada
  -- teléfono.
  settings jsonb not null default '{}'::jsonb,
  -- Cuándo cambió esto en el teléfono que lo subió, con el reloj de ese
  -- teléfono. No es `updated_at`: una pieza puesta sin conexión el lunes y
  -- subida el miércoles cambió el lunes, y eso es lo que se compara al
  -- decidir qué copia gana (ver `lib/sync/merge.dart`).
  changed_at timestamptz,
  updated_at timestamptz not null default now()
);

-- ------------------------------------------------------- un hábito, un pueblo

create table if not exists public.habits (
  user_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  id text not null,
  -- El orden en el valle (el de la lista en la app).
  position int not null,
  name text not null,
  symbol text not null,
  -- El hueco del valle donde está el pueblo. No cambia nunca.
  slot int not null,
  -- La comarca (Ribera, Sierra…), por su número.
  "character" int not null,
  created_at timestamptz not null,
  why text,
  floor text,
  vow_hour int check (vow_hour between 0 and 23),
  vow_place text,
  identity text,
  identity_won_at timestamptz,
  after_id text,
  per_week int check (per_week between 1 and 7),
  cadence_asked_at timestamptz,
  asked_at timestamptz,
  nudged_at timestamptz,
  nudges_ignored int not null default 0,
  -- Qué fue cada edificio, en orden y escrito el día que se empezó.
  chronicle text[] not null default '{}',
  updated_at timestamptz not null default now(),
  primary key (user_id, id)
);

-- Cada logro, una pieza. `idx` es su sitio en el pueblo para siempre.
create table if not exists public.pieces (
  user_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  habit_id text not null,
  idx int not null check (idx >= 0),
  placed_at timestamptz not null,
  primary key (user_id, habit_id, idx),
  foreign key (user_id, habit_id)
    references public.habits (user_id, id) on delete cascade
);

-- Quién vive en cada pueblo: escrito el día que se remató su casa.
create table if not exists public.villagers (
  user_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  habit_id text not null,
  position int not null,
  home int not null,
  seed bigint not null,
  born_at timestamptz not null,
  name text not null,
  primary key (user_id, habit_id, position),
  foreign key (user_id, habit_id)
    references public.habits (user_id, id) on delete cascade
);

-- Lo que clavaste en el tablón, la más nueva primero.
create table if not exists public.notes (
  user_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  habit_id text not null,
  position int not null,
  pinned_at timestamptz not null,
  body text not null,
  primary key (user_id, habit_id, position),
  foreign key (user_id, habit_id)
    references public.habits (user_id, id) on delete cascade
);

-- Cuándo estuvo dormido a propósito, del tramo más viejo al más nuevo.
create table if not exists public.rests (
  user_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  habit_id text not null,
  position int not null,
  from_at timestamptz not null,
  until_at timestamptz not null check (until_at > from_at),
  primary key (user_id, habit_id, position),
  foreign key (user_id, habit_id)
    references public.habits (user_id, id) on delete cascade
);

-- ------------------------------------------------------------- el tablón

-- Dónde quedó clavado cada papel: `pueblo/papel` → hueco.
create table if not exists public.board_slots (
  user_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  key text not null,
  slot int not null check (slot >= 0),
  primary key (user_id, key)
);

-- Qué papeles ya se leyeron, por pueblo.
create table if not exists public.board_seen (
  user_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  town_id text not null,
  key text not null,
  primary key (user_id, town_id, key)
);

-- --------------------------------------------------------- cada uno lo suyo

do $$
declare
  t text;
begin
  foreach t in array array[
    'valleys', 'habits', 'pieces', 'villagers', 'notes', 'rests',
    'board_slots', 'board_seen'
  ] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists "own rows" on public.%I', t);
    execute format(
      'create policy "own rows" on public.%I for all to authenticated '
      'using (user_id = auth.uid()) with check (user_id = auth.uid())',
      t
    );
  end loop;
end
$$;

-- `updated_at` se pone solo en cada cambio.
create or replace function public.touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end
$$;

drop trigger if exists touch_valleys on public.valleys;
create trigger touch_valleys before update on public.valleys
  for each row execute function public.touch_updated_at();

drop trigger if exists touch_habits on public.habits;
create trigger touch_habits before update on public.habits
  for each row execute function public.touch_updated_at();
