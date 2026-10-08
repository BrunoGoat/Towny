/// Las obras en inglés: el nombre y la frase del día que se rematan. Por id,
/// que es lo que no cambia nunca de una obra. Ver `lib/data/landmarks.dart` y
/// `lib/data/landmarks_retired.dart`; un test comprueba que no falte ninguna.
library;

const Map<String, (String, String)> landmarksEn = {
  // ---------------------------------------------------------- el catálogo
  'pozo': (
    'Council well',
    'Water stops being a long walk. Now it is where people talk as evening '
        'falls.',
  ),
  'cruz': (
    'Boundary cross',
    'Whoever arrives knows they are home. Whoever leaves looks at it one last '
        'time.',
  ),
  'palomar': (
    'Dovecote',
    'News you wait for looking at the sky. Almost always good.',
  ),
  'colmenar': (
    'Apiary',
    'Sweetness on the table and light at night, in exchange for leaving them '
        'in peace.',
  ),
  'huerto': (
    "The priest's garden",
    'What is left over gets shared, and nobody keeps count of who got what.',
  ),
  'pajar': (
    'Hayloft',
    'Storing in August what January will need is a way of believing there '
        'will be a January.',
  ),
  'corral': (
    'Pen',
    'At dusk they are counted and shut in. Nothing is lost tonight.',
  ),
  'gallinero': (
    'Henhouse',
    "The first visit of every morning. Some kinds of love are just a habit.",
  ),
  'alfar': (
    'Pottery',
    'Everything in this town that holds something passed through a pair of '
        'hands and a wheel.',
  ),
  'camposanto': (
    'Churchyard',
    'There are people now who will never leave. Folk come to talk to them '
        'and go home lighter.',
  ),
  'atalaya': (
    'Watchtower',
    'Someone keeps watch for everyone else while everyone else sleeps.',
  ),
  'almenara': (
    'Signal fire',
    'A fire up high to tell the valley that we are here and that we warn.',
  ),
  'molinoViento': (
    'Windmill',
    'You can hear the sails from bed. While they turn, there is bread.',
  ),
  'almazara': (
    'Olive press and grove',
    'Oil from olive trees planted by people who never got to taste it.',
  ),
  'cerveceria': (
    'Brewhouse',
    "Where the day ends. Nobody asks how it went if you'd rather not say.",
  ),
  'mercado': (
    'Covered market',
    'One fixed day a week when the whole town sees each other\'s faces.',
  ),
  'salinas': (
    'Salt pans',
    'Taking from the sea what makes food last. Slow, grateful work.',
  ),
  'ceca': (
    'Mint',
    "A coin with the town's mark, that travels far and comes back telling "
        'where it has been.',
  ),
  'tejedores': (
    "Weavers' guild",
    'Nobody haggles alone. The trade is defended by everyone or not at all.',
  ),
  'hospederia': (
    "Pilgrims' hospital",
    'A bed and a meal for whoever is passing through. No one asks where they '
        'come from.',
  ),
  'botica': (
    'Apothecary',
    'You no longer have to just bear everything. Some things have a cure '
        'now.',
  ),
  'escuela': (
    'Grammar school',
    'The children will know things their parents never knew.',
  ),
  'escribania': (
    "Scrivener's office",
    'What is agreed gets written down, and people stop arguing about what '
        'was said.',
  ),
  'capilla': ('Chapel', 'A small place for what is not said out loud.'),
  'campanario': (
    'Free-standing bell tower',
    'The bell tells the hour, the feast and the grief. It is heard from the '
        'fields, and people know.',
  ),
  'claustro': (
    'Cloister',
    'Four galleries for walking in circles, thinking, without bothering '
        'anyone.',
  ),
  'refectorio': (
    'Refectory',
    'Eating together every day, in silence. That is love too.',
  ),
  'bodega': (
    'Wine cellar',
    "Down there nobody is in a hurry: this year's wine waits for next "
        "year's.",
  ),
  'silos': (
    'Grain silos',
    'Grain for three years. You sleep differently knowing that.',
  ),
  'faro': (
    'Lighthouse',
    'Someone climbs up every evening to light it for those who have not come '
        'back yet.',
  ),
  'herreriaMayor': (
    'Great forge',
    'The hammer can be heard from the square. When it stops, everyone looks '
        'up.',
  ),
  'horca': (
    'Gallows field',
    'There are rules and they are kept. It is not pretty, and everyone knows '
        'what it is for.',
  ),
  'palenque': (
    'Tourney lists',
    'An afternoon of shouting in the sun that people talk about the rest of '
        'the year.',
  ),
  'huertoMonjes': (
    "The monks' garden",
    'You eat from what you tend. The same work every day, without '
        'complaint.',
  ),
  'vinedo': (
    "The chapter's vineyard",
    'The wine for mass and the wine for afterwards come from the same vine.',
  ),
  'colmenarMayor': (
    'Great apiary',
    'The honey from here is known elsewhere. The town is starting to be '
        'famous for something good.',
  ),
  'castillo': (
    'Castle',
    'No more running for the hills every time dust rises on the road.',
  ),
  'homenaje': (
    'Keep',
    'From the top you see the whole valley and, in the middle of it, what is '
        'yours.',
  ),
  'puertaVilla': (
    'Town gate',
    'Arriving stops being just showing up. From today on, you come in.',
  ),
  'muralla': (
    'Stretch of wall',
    'A town that closes at night and wakes up with everyone inside.',
  ),
  'alcazar': (
    'Fortress palace',
    'Whoever rules no longer lives like everyone else, and it shows from '
        'afar.',
  ),
  'palacio': (
    "The lord's palace",
    'Visitors from outside are received. The whole town puts on its best.',
  ),
  'concejo': (
    'Council house',
    'Here things are argued loudly and decided by everyone. Nobody comes to '
        'tell us how.',
  ),
  'lonja': (
    "Merchants' exchange",
    'A word given here is good in three kingdoms. Half the town lives on '
        'that.',
  ),
  'iglesia': (
    'Church',
    'Where the town gathers for the first things and for the last.',
  ),
  'catedral': (
    'Cathedral',
    'You start it knowing the grandchildren will finish it, and you start it '
        'anyway.',
  ),
  'monasterio': (
    'Monastery',
    'People who chose a smaller life to make it a deeper one.',
  ),
  'abadia': (
    'Abbey',
    'They pray, they store and they share. In the bad years you can tell who '
        'was storing.',
  ),
  'colegiata': (
    'Collegiate church',
    'Too much church for a town like this, and that is exactly the pride.',
  ),
  'sinagoga': (
    'Synagogue',
    'Another way of praying that also belongs here, for as long as the '
        'other.',
  ),
  'mezquita': (
    'Mosque',
    'The call is heard all over the quarter, and the quarter knows the time '
        'without looking.',
  ),
  'baptisterio': (
    'Baptistery',
    'The newborn come in through here. They leave with a name and with '
        'people.',
  ),
  'hospitalMayor': (
    'Great hospital',
    'Those with no one to care for them are cared for. That is the town '
        'too.',
  ),
  'universidad': (
    'University',
    'People come from outside to learn here, and those who leave carry the '
        'name with them.',
  ),
  'biblioteca': (
    'Library',
    'A whole year to copy a book that someone not yet born will read.',
  ),
  'teatro': (
    'Mystery-play yard',
    'One afternoon a year the town tells its own story and laughs at '
        'itself.',
  ),
  'coso': (
    'Arena and stands',
    'The whole town sitting in the same place, shouting the same thing.',
  ),
  'jardin': ('Palace garden', 'It is good for nothing. It was needed anyway.'),
  'arcoVilla': (
    'Town arch',
    'It closes nothing and defends nothing. It was raised for the pleasure '
        'of being able to.',
  ),
  'panteon': (
    "Founders' pantheon",
    'Those who started this have a place to be, and someone to thank for '
        'the town.',
  ),

  // ---------------------------------------------------------- las retiradas
  //
  // Ya no se construyen, pero un pueblo viejo puede tenerlas en su crónica y
  // las nombra.
  'fuente': (
    'Square fountain',
    'Four spouts and a square around them. This is where people stop to '
        'talk.',
  ),
  'horno': (
    'Common oven',
    'A single fire for the whole town, lit in turns. You can smell bread '
        'three streets away.',
  ),
  'fragua': (
    'Forge',
    'Hammer blows before dawn. Everything that cuts and everything that '
        'holds comes from here.',
  ),
  'lavadero': (
    'Wash house',
    'Sloping stone and running water. Also the place where everything that '
        'happens gets known.',
  ),
  'abrevadero': (
    'Watering trough',
    'The animals drink, and travellers stop. Half an inn for the price of a '
        'stone.',
  ),
  'era': (
    'Threshing floor',
    'Hard, swept ground to separate grain from straw. A whole year ends '
        'here.',
  ),
  'porqueriza': (
    'Pigsty',
    'Ugly, yes. But it is the meat for the whole winter.',
  ),
  'lenera': (
    'Woodshed',
    'Firewood stacked and dry. In January this is worth more than silver.',
  ),
  'carbonera': (
    'Charcoal kiln',
    'The wood burns covered, for days on end, until it turns to charcoal. '
        'Patience made into a trade.',
  ),
  'tejar': (
    'Tile works',
    'The tiles for every roof you can see from here come from here.',
  ),
  'tinte': (
    'Dye works',
    'Vats of colour and hands stained for weeks. So that clothes are not '
        'always brown.',
  ),
  'batan': (
    'Fulling mill',
    'Wooden mallets beating the cloth until it tightens. Wool becomes '
        'fabric.',
  ),
  'picota': (
    'Stocks and pillory',
    'It is not pretty. But a town with its own laws is a town that already '
        'governs itself.',
  ),
  'ermita': (
    'Hermitage',
    'Small, set apart and always open. For whoever passes by, and for '
        'whoever wants no company.',
  ),
  'humilladero': (
    'Wayside shrine',
    'Four pillars and a roof at the crossroads. For kneeling on the way out '
        'and on the way back.',
  ),
  'osario': (
    'Ossuary',
    'Those who built this are still here. A town is made of that too.',
  ),
  'mojon': (
    'Boundary stone',
    'The town reaches this far. Now there is an inside and an outside.',
  ),
  'pasarela': (
    'Plank bridge',
    'Four posts and a few boards. The stream no longer decides who crosses.',
  ),
  'vado': (
    'Paved ford',
    'Stones set into the bed. You cross dry-footed most of the year.',
  ),
  'barca': ('Ferry', 'A rope from bank to bank. The river stops being a wall.'),
  'tenada': (
    'Open shed',
    'A roof without walls, for the cattle and for whoever gets caught in the '
        'rain.',
  ),
  'majada': (
    'Sheepfold',
    'A fence, shelter and water. The flock can stay outside the town.',
  ),
  'huertaCercada': (
    'Walled garden',
    "Three fenced beds. What's eaten for supper in August is planted in "
        'March.',
  ),
  'molinoAgua': (
    'Watermill',
    'The wheel turns by itself day and night. The river works for free.',
  ),
  'acena': (
    'River mill',
    'Two wheels in the current, on stone piers. It grinds even when summer '
        'brings the water down.',
  ),
  'noria': (
    'Water wheel',
    'Buckets lifting water from the river to the garden. Summer stops being '
        'frightening.',
  ),
  'serreria': (
    'Sawmill',
    'The saw cuts by itself with the strength of the water. Beams no longer '
        'come from outside.',
  ),
  'lagar': (
    'Wine press and vineyard',
    'Vines in rows and a press at the end. There will be wine of our own, '
        'and a harvest.',
  ),
  'tahona': (
    'Bakehouse',
    'They knead at night so there is bread in the morning. Nobody remembers '
        'to say thank you.',
  ),
  'carniceria': (
    "Butcher's",
    "A counter on the street and scales watched by the council. Meat stops "
        'being only for feast days.',
  ),
  'pescaderia': (
    "Fishmonger's",
    'From the river to the cold stone in one morning. Fridays are sorted.',
  ),
  'alhondiga': (
    'Public granary',
    "Everyone's grain is kept and sold at a fair price. Against hunger and "
        'against the moneylender.',
  ),
  'aduana': (
    'Customs house',
    'What comes in pays. Not elegant, but it pays for everything else.',
  ),
  'canteros': (
    "Stonemasons' guild",
    'The people who know how to cut stone no longer come from outside: they '
        'live here.',
  ),
  'herrador': (
    "Farrier's house",
    'A lame horse gets nowhere. The whole road passes through this door.',
  ),
  'cuadras': (
    'Stables',
    'Stalls and a trough. Travellers can stay the night now.',
  ),
  'posadaCamino': (
    'Roadside inn',
    "A bed, a stable and a fire. The town is starting to be on someone's "
        'map.',
  ),
  'leproseria': (
    'Leper house',
    'Set apart, with its own fence and well. Caring for those people fear '
        'says more than a cathedral.',
  ),
  'banos': ('Baths', 'Hot water under a dome. A luxury, and one you notice.'),
  'palomarTorre': (
    'Dovecote tower',
    'A thousand nests in a tower. Doves, manure and post, all in the same '
        'stone.',
  ),
  'reloj': (
    'Clock tower',
    'The same time for everyone. It seems like little and it changes '
        'everything.',
  ),
  'puente': (
    'Stone bridge',
    'Stone arches, and it no longer matters how the river comes down.',
  ),
  'acueducto': (
    'Aqueduct',
    'Two tiers of arches bringing water from the hills. The valley is '
        'crossed from above.',
  ),
  'presa': (
    'Dam and weir',
    'The water is held back and shared out when it is needed. Taming a river '
        'is serious business.',
  ),
  'embarcadero': (
    'Jetty',
    'Driven posts and a platform. Whatever arrives by water can come ashore '
        'now.',
  ),
  'astillero': (
    'Shipyard',
    'A keel on the slipway. Here people begin to build for going far away.',
  ),
  'cantera': (
    'Quarry',
    'Half the town came out of this hole. The scar that building leaves.',
  ),
  'teneria': (
    'Tannery',
    'It smells bad and it is on the outskirts for a reason. But leather is '
        'leather.',
  ),
  'dehesa': (
    'Oak pasture',
    'Old holm oaks and shade. The cattle fatten on their own and nobody '
        'hurries them.',
  ),
  'motte': (
    'Motte and palisade',
    'A mound raised by hand, a palisade and a tower on top. That is how '
        'every castle began.',
  ),
  'barbacana': (
    'Barbican',
    'Two towers in front of the gate, so that whoever arrives thinks twice.',
  ),
  'aljibe': (
    'Great cistern',
    'Vaults full of rainwater. A siege or a drought stops being frightening.',
  ),
  'observatorio': (
    'Observatory',
    'A tower with a dome that opens. From tonight the town does not only '
        'look at the ground it walks on: someone up there is writing down '
        'what happens in the sky, and what they write stays written for the '
        'whole valley.',
  ),
};
