-- Hasta dónde se vio el buzón del widget no viaja: es de cada aparato.
--
-- Cada widget numera sus piezas desde uno, así que el número de un teléfono
-- no le dice nada a otro. La app ya no lo sube; esto lo saca de la tabla en
-- los proyectos que se crearon con la primera migración.
alter table public.valleys drop column if exists seen_arrival;
