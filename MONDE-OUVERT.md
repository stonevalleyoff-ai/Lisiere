# Lisière — le monde ouvert

Le plan pour passer d'un lieu (un biome d'Orvane, 5 400 pixels de côté) à **un monde immense, d'un seul tenant, qui a la
géographie du monde d'Orvane**. Ce document dit ce qui est décidé, les étapes, où on en est. Il se tient à jour à chaque étape.

## Ce qui est décidé (le 12 novembre 2026)

1. **Le même monde pour tous**, tiré d'Orvane. Orvane découpe chaque biome en parcelles voisines, chacune avec sa faune
   (docs/15 d'Orvane) : la carte du jeu est ce réseau, posé sur un plan. Elle ne change que si Orvane change ses parcelles.
2. **La taille** : une région se traverse en une minute et demie de marche (16 000 pixels), le monde en vingt à trente minutes.
3. **Le but ne change pas** : survivre le plus de nuits. On explore librement.
4. **L'eau est une frontière** : ni nage, ni bateau. Mais on fabrique des **ponts éphémères** (voir l'étape 4).
5. Le jeu d'aujourd'hui reste jouable (« un seul lieu ») tant que le monde ouvert n'est pas solide.

## L'idée

- **La carte** (`outils/carte.js`, `donnees/carte.json`) : chaque parcelle d'Orvane est une région. Deux biomes voisins dans
  Orvane se touchent sur la carte autant que possible ; le froid est au nord, la mer autour. Là où deux biomes de terre se
  touchent sans être voisins dans Orvane, la frontière est **fermée** : une crête, une falaise, on ne passe pas. On ne va donc
  d'un biome à l'autre que par où Orvane le dit.
- **Chaque région a son caractère** : son sol et ses plantes d'après ses axes (comme un lieu d'aujourd'hui), ses bêtes d'après
  ce qui vit dans cette parcelle (`populations[].parcelles`), son temps d'après son climat (`scripts/climat.gd`).
- **Ce qu'on chasse compte au bon endroit** : les lots disent la parcelle (`Orvane.compter(…, parcelle)`, le kit le sait déjà).
- **Le monde n'existe jamais en entier** : seuls les morceaux autour de la veilleuse sont fabriqués (toujours les mêmes au même
  endroit, d'après la graine du monde), puis oubliés. La partie gardée ne retient que ce qu'on a changé (les arbres coupés,
  brûlés, les feux, les ponts) et ce qu'on a découvert.

## Les étapes

Chacune est jouable et vérifiée (l'essai, le téléphone émulé) avant la suivante.

1. **La carte.** *Fait.* `node outils/carte.js` pose les 160 parcelles sur une grille en nid d'abeille (des régions de même
   taille), par un recuit qui cherche à respecter les voisinages d'Orvane, et écrit `donnees/carte.json` (un point par région,
   ses voisines, ses frontières fermées). `--svg` la dessine.
2. **Un biome sans bord.** Le lieu d'aujourd'hui fabriqué par morceaux autour de la veilleuse, sans limite : le sol, les
   objets, les bêtes, le temps qu'il fait, la partie gardée par différences. C'est l'étape qui prouve la fluidité sur un
   téléphone.
3. **Plusieurs biomes.** Le jeu lit la carte : les régions, les transitions (quelques centaines de pixels où les plantes se
   mêlent), le sol qui passe d'une palette à l'autre, la faune par parcelle, le temps par région, les lots avec leur parcelle.
   Les frontières fermées deviennent des crêtes.
4. **L'eau et le relief.** Les mers, les lacs, les rivières (un vrai cours d'eau, pas une région), les côtes. Les gués, où l'on
   passe à pied. **Le pont éphémère** : une fabrication (du bois, de la fibre) qu'on pose au bord de l'eau vers l'autre rive, sur
   une largeur limitée (une rivière, un bras de mer étroit, pas un lac). Il ne dure pas : il s'use à chaque passage et avec le
   temps, la crue l'emporte, le feu le brûle. Les bêtes le prennent aussi, les chasseurs compris. Un pont gardé avec la partie.
5. **Se repérer.** Une carte dans le carnet, qui se dessine à mesure qu'on explore ; le nom de la région quand on y entre ;
   les régions découvertes au tableau des scores.
6. **Des raisons de voyager.** Des ressources qui changent avec le biome, des repères, des camps.

## Où on en est

**Étape 1, faite** (la carte calculée sur le monde d'Orvane publié, graine 1) :
- 160 parcelles : 136 régions de terre (dont 4 de grottes) et 24 d'eau, en 39 biomes ; la haute mer autour ;
- 78 des 85 voisinages entre biomes d'Orvane sont respectés (92 %). Il manque : toundra et lac, désert et côte, maquis et
  montagne, sommets et volcan, récif et haute mer, bois et tourbière, lande et falaise ;
- 17 frontières fermées (des crêtes) ;
- les régions ont la même taille à 9 % près. Dix biomes sont en plusieurs morceaux (deux forêts, deux déserts…) : dans Orvane
  leurs parcelles se suivent, sur la carte pas toujours ;
- les terres font environ 290 000 pixels d'est en ouest : une demi-heure de marche.

**À décider en regardant la carte** : la taille (`--cote`), où l'on s'éveille, ce que deviennent les grottes.

## Ce qui reste incertain

- La fluidité sur un vrai téléphone quand le monde se fabrique en marchant : c'est l'objet de l'étape 2.
- La copie du monde gardée dans le jeu (hors ligne) passerait de 5 à 32 lieux : un jeu plus lourd à télécharger.
- Les parties gardées d'aujourd'hui (un lieu) ne se convertissent pas.
