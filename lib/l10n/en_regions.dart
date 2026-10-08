/// Las comarcas en inglés: el nombre, cómo es, y para qué hábitos va. Por
/// [TownCharacter.order], que es lo que no cambia nunca de una comarca. Ver
/// `lib/data/character.dart`.
library;

const Map<int, (String, String, String)> regionsEn = {
  0x1A7C: (
    'Riverside',
    'Wide, low houses, whitewashed, nearly all of them tiled.',
    'For habits of calm and rest: sleeping better, meditating, drinking '
        'water.',
  ),
  0x33F1: (
    'Highlands',
    'Tall and tight, grey stone and slate, with steep roofs.',
    'For habits that take physical effort and are genuinely hard: training, '
        'running, getting up early.',
  ),
  0x5E02: (
    'Marches',
    'A border town: thick walls, ochre, few windows, everything close '
        'together.',
    'For giving something up and holding out: no smoking, less screen time, '
        'less sugar.',
  ),
  0x7B45: (
    'Vale',
    'Timber and thatch, big plots and a vegetable patch in nearly every one.',
    'For habits tied to nature and health: eating well, cooking, walking '
        'outdoors.',
  ),
  0x91C8: (
    'Coast',
    'Lime and indigo, almost flat roofs and plenty of air between the '
        'houses.',
    'For order and clarity: tidying the house, the accounts, planning the '
        'week.',
  ),
  0xB30D: (
    'Oakwood',
    'Dark timber under the oaks, very steep thatched roofs.',
    'For what grows slowly, like an oak: reading, studying, writing, '
        'learning an instrument.',
  ),
  0xD4A3: (
    'Crossroads',
    'A town on the road: inns, wide squares and houses of different colours.',
    'For bonds: calling the family, writing to a friend, going out more, '
        'being patient with others.',
  ),
  0xE817: (
    'Potteries',
    "A craftsmen's town: workshops and kilns, fired clay and red roofs.",
    'For creative things: drawing, playing music, writing, photography, what '
        'is made with the hands.',
  ),
};
