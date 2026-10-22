-- Desde cuándo valió cada ritmo de un hábito, `milisegundos|veces` (vacío
-- detrás de la raya: sin decir).
--
-- El candado mide cada día con el ritmo que tenía ese día: bajar el ritmo
-- justo antes de mirar ya no abre la puerta con días que no la merecían.
alter table public.habits
  add column if not exists paces text[] not null default '{}';
