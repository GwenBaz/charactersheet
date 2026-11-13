# Le pseudo-langage des effets

Version 1 du langage (`effects_version = 1` dans `schema_info`).

Ce document décrit le langage qui écrit les bonus et malus d'une race, d'une capacité, d'un
objet ou d'un effet temporaire. Il décrit aussi la **forme canonique** dans laquelle ces
textes sont stockés, et comment y arriver. Il ne contient pas de code : c'est la
spécification à suivre pour écrire l'analyseur en Rust. Les jeux d'essai de la fin
serviront de tests.

---

## 1. À quoi il sert

Un effet est un bonus ou un malus chiffré : « +2 en Dextérité », « +1 de parade à la CA »,
« +2 racial en Perception auditive ». Le langage les écrit dans **une seule colonne
texte** au lieu d'une table :

```
dex+2, con-2
ac+1:deflection
Perception auditive+2:racial, Détection+2:racial, Fouille+2:racial
will+2:racial [contre les enchantements]
```

La colonne `effects` existe dans cinq tables :

| Table | Ce qu'elle porte | Exemple |
|---|---|---|
| `race` | ajustements raciaux de caractéristiques | Elfe : `dex+2, con-2` |
| `feature` | bonus d'un don, d'une aptitude, d'un trait racial | Science de l'initiative : `init+4` |
| `item` | bonus d'un objet magique | Anneau de protection +1 : `ac+1:deflection` |
| `special_property` | bonus d'une propriété spéciale | De résistance +1 : `saves+1:resistance` |
| `character_modifier` | toute case « mod. divers », « mod. temporaire » | Bénédiction : `attack+1:morale, saves+1:morale [contre la terreur]` |

Une colonne vide (`NULL`) signifie « aucun effet ».

Le texte stocké est **toujours en forme canonique** (section 7). L'utilisateur peut
écrire librement (majuscules, espaces, noms français, ordre quelconque), mais
l'application réécrit son texte avant de l'enregistrer.

---

## 2. Syntaxe

Un texte d'effets est une **liste d'effets séparés par des virgules**. Chaque effet a
cette forme :

```
cible  signe  nombre  [ :type ]  [ [condition] ]
```

| Partie | Obligatoire | Exemple | Rôle |
|---|---|---|---|
| cible | oui | `dex`, `ac`, `Perception auditive` | ce qui reçoit le bonus |
| signe | oui | `+` ou `-` | bonus ou malus |
| nombre | oui | `2` | valeur absolue, entier de 1 à 999 |
| `:type` | non | `:racial` | type de bonus, pour la règle de cumul ; absent = sans type |
| `[condition]` | non | `[bout portant]` | situation : l'effet ne compte que si elle est cochée sur la fiche (section 5) |

Les séparateurs acceptés en saisie sont la virgule `,`, le point-virgule `;` et le
retour à la ligne. La forme canonique n'utilise que `, `. Un séparateur placé **entre
crochets** fait partie de la condition et ne coupe rien :
`will+2 [contre les sorts, les pouvoirs magiques]` est **un seul** effet.

Les segments vides sont ignorés : `str+2,,dex+1,` équivaut à `str+2, dex+1`.

### Caractères interdits

Une cible (nom de compétence compris) ne peut pas contenir `,` `;` `:` `[` `]`. Une
condition ne peut pas contenir `[` ni `]` : pas de crochets imbriqués.

---

## 3. Les cibles

### 3.1 Codes réservés

Une cible est d'abord cherchée parmi ces codes. La forme canonique utilise le code
anglais, mais l'alias français est accepté en saisie. Les codes **passent avant les noms
de compétence** : une compétence maison ne peut pas s'appeler `ac` ni `vol`.

| Code canonique | Alias acceptés | Ce que ça modifie |
|---|---|---|
| `str` | `for`, `force` | **valeur** de Force (pas le modificateur) |
| `dex` | `dextérité` | valeur de Dextérité |
| `con` | `constitution` | valeur de Constitution |
| `int` | `intelligence` | valeur d'Intelligence |
| `wis` | `sag`, `sagesse` | valeur de Sagesse |
| `cha` | `charisme` | valeur de Charisme |
| `ac` | `ca` | classe d'armure (voir 3.3) |
| `fort` | `vig`, `vigueur` | jet de Vigueur |
| `ref` | `réf`, `réflexes` | jet de Réflexes |
| `will` | `vol`, `volonté` | jet de Volonté |
| `saves` | `sauv`, `sauvegardes` | les trois jets de sauvegarde |
| `init` | `initiative` | initiative |
| `attack` | `att`, `attaque` | toutes les attaques |
| `melee` | `cac`, `corps à corps` | attaques au corps à corps |
| `ranged` | `dist`, `distance` | attaques à distance |
| `damage` | `dég`, `dégâts` | tous les jets de dégâts |
| `melee_damage` | `dég_cac`, `dégâts au corps à corps` | dégâts au corps à corps |
| `ranged_damage` | `dég_dist`, `dégâts à distance` | dégâts à distance |
| `grapple` | `lutte` | tests de lutte |
| `speed` | `vit`, `vitesse` | vitesse de déplacement, en mètres |
| `hp` | `pv` | points de vie maximum |
| `skills` | `comp`, `compétences` | tous les tests de compétence |

Les accents et la casse ne comptent pas en saisie : `Volonté`, `VOLONTE` et `vol` donnent
tous `will`.

### 3.2 Noms de compétence

Une cible qui n'est pas un code est un **nom de compétence**, cherché dans la table
`skill`. La recherche se fait en quatre essais, dans cet ordre :

1. **Nom exact normalisé.** On compare le *slug* de la cible au slug du `name` de chaque
   compétence. Le slug est la normalisation qui sert aussi aux ids : minuscules, accents
   retirés, toute suite de caractères non alphanumériques remplacée par `-`, tirets
   retirés aux deux bouts. `PERCEPTION AUDITIVE`, `perception  auditive` et
   `Perception-Auditive` donnent tous `perception-auditive`.
   `Connaissances (mystères)` est une compétence à part entière dans la fiche : elle est
   trouvée ici.
2. **Compétence à spécialité.** Si rien n'est trouvé et que la cible a la forme
   `<base> (<spécialité>)`, on cherche `<base>` parmi les compétences dont
   `has_specialty = 1`. `Profession (marin)` donne la compétence Profession avec la
   spécialité `marin`.
3. **Ancien nom.** Si rien n'est trouvé, on calcule `catalog_id('skill', cible)` et on le
   cherche parmi les ids. Comme l'id d'une compétence vient du nom qu'elle avait à sa
   création, un texte écrit avant un renommage reste valide.
4. Sinon : erreur `CIBLE_INCONNUE`.

Une spécialité donnée à une compétence sans `has_specialty` est une erreur
(`SPECIALITE_INTERDITE`). C'est le cas de `Saut (en hauteur)`.

**Conséquence importante :** la mise en forme canonique **dépend du référentiel**. Il faut
importer les compétences (et les situations, section 5.1) avant les dons, races et objets
qui les citent (section 9).

### 3.3 La CA et ses trois valeurs

Le **type** du bonus décide à quelles CA il s'applique. La fiche en affiche trois :

| Type | CA normale | Contact | Pris au dépourvu |
|---|:-:|:-:|:-:|
| `armor`, `shield`, `natural` | oui | **non** | oui |
| `dodge` | oui | oui | **non** |
| tous les autres | oui | oui | oui |

---

## 4. Les types de bonus

Le type sert à la règle de cumul de la 3.5 (section 8). La forme canonique utilise le
code anglais, et l'absence de type s'écrit en omettant `:type`.

| Code canonique | Alias acceptés | VF |
|---|---|---|
| *(aucun)* | `untyped`, `sans type`, `aucun` | bonus sans type |
| `alchemical` | `alchimique` | bonus alchimique |
| `armor` | `armure` | bonus d'armure |
| `circumstance` | `circonstance` | bonus de circonstance |
| `competence` | `aptitude` | bonus d'aptitude |
| `deflection` | `parade` | bonus de parade |
| `dodge` | `esquive` | bonus d'esquive |
| `enhancement` | `altération`, `alteration` | bonus d'altération |
| `insight` | `intuition` | bonus d'intuition |
| `luck` | `chance` | bonus de chance |
| `morale` | `moral` | bonus de moral |
| `natural` | `naturel`, `armure naturelle` | bonus d'armure naturelle |
| `profane` | `impie` | bonus impie |
| `racial` | `racial` | bonus racial |
| `resistance` | `résistance` | bonus de résistance |
| `sacred` | `sacré`, `sacre` | bonus sacré |
| `shield` | `bouclier` | bonus de bouclier |
| `size` | `taille` | bonus de taille |

Comme pour les cibles, les accents et la casse ne comptent pas en saisie.

---

## 5. Valeurs et conditions

**Nombre.** Entier de 1 à 999, toujours précédé de son signe. `+0` est une erreur : un
effet nul n'a pas de sens. Les zéros de tête sont tolérés en saisie (`+02`) et retirés
en forme canonique.

**Condition.** Texte entre crochets, placé en dernier. Une condition désigne une
**situation** : « bout portant », « contre les enchantements », « en charge ».
L'application ne sait pas si l'on est dans cette situation, c'est le joueur qui la
coche (section 8.2). Un effet conditionnel n'est donc **jamais ajouté
automatiquement**.

### 5.1 Situations connues et situations libres

Une condition est d'abord cherchée dans la table `situation` du référentiel, en deux
essais, comme un nom de compétence :

1. **Nom exact normalisé** : le slug de la condition est comparé au slug du `name` de
   chaque situation. `[BOUT  PORTANT]` et `[bout-portant]` trouvent « Bout portant ».
2. **Ancien nom** : on calcule `catalog_id('situation', condition)` et on le cherche
   parmi les ids, pour qu'un texte écrit avant un renommage reste valide.

Si l'un des essais aboutit, c'est une **situation connue** : elle s'écrit avec le `name`
du référentiel et elle a une description, affichée en infobulle. Deux effets de sources
différentes qui citent la même situation sont cochés ensemble.

Sinon, ce n'est **pas une erreur** : c'est une **situation libre**. Sa casse et ses
accents sont conservés, car c'est du texte destiné au joueur ; on retire seulement les
espaces en trop. Elle reste cochable sur la fiche, et deux conditions libres de même
slug sont la même situation. Mais `[à 9 m ou moins]` et `[bout portant]` restent deux
situations distinctes : c'est à ça que sert le référentiel. Le formulaire de saisie
peut proposer les situations connues en complétion automatique pour éviter ces
doublons.

### 5.2 Limites

Ce que la v1 ne sait pas écrire, et qui passe par une condition :
- les valeurs qui dépendent du niveau ou du rang : `damage+2 [par rang d'Ennemi juré]` ;
- les valeurs qui dépendent d'un choix : `attack+1 [avec l'arme choisie]`.

Une fois cochées, ces situations ajoutent leur valeur telle qu'elle est écrite : +2 pour
l'Ennemi juré, quel que soit le rang. Le joueur corrige alors par un modificateur.

Une v2 pourra ajouter des variables (`niv`, `rang`, `choix`). Elle changera
`effects_version`.

---

## 6. Les erreurs

L'analyseur ne doit **jamais planter** sur un texte saisi. Il rend soit la forme
canonique, soit une liste d'erreurs. Chaque erreur donne le **numéro de l'effet** dans
la liste (à partir de 1) et, si possible, la **position** du caractère fautif, pour que
le formulaire puisse le souligner.

| Code | Cas | Exemple |
|---|---|---|
| `CROCHET_NON_FERME` | `[` sans `]` | `will+2 [contre` |
| `CROCHET_NON_OUVERT` | `]` sans `[` | `will+2 contre]` |
| `CROCHETS_IMBRIQUES` | `[` dans une condition | `will+2 [a [b]]` |
| `TEXTE_APRES_CONDITION` | quelque chose après `]` | `will+2 [a] x` |
| `CONDITION_VIDE` | `[]` ou `[  ]` | `will+2 []` |
| `TYPE_MULTIPLE` | plus d'un `:` | `ac+1:dodge:luck` |
| `TYPE_INCONNU` | type absent du tableau 4 | `ac+1:bidon` |
| `SIGNE_MANQUANT` | pas de `+` ni de `-` avant le nombre | `str2` |
| `NOMBRE_MANQUANT` | signe sans nombre | `str+` |
| `NOMBRE_NUL` | valeur 0 | `str+0` |
| `NOMBRE_TROP_GRAND` | plus de 999 | `hp+1000` |
| `CIBLE_MANQUANTE` | rien avant le signe | `+2` |
| `CIBLE_INCONNUE` | ni code, ni compétence | `charme+2` |
| `SPECIALITE_INTERDITE` | spécialité sur une compétence qui n'en a pas | `Saut (haut)+2` |
| `EFFET_EN_DOUBLE` | même cible, même type, même condition deux fois | `str+2, str-1` |

**Pourquoi `EFFET_EN_DOUBLE` est une erreur.** Dans une même source, deux bonus de même
type sur la même cible ne se cumulent pas en 3.5. Les additionner en silence cacherait
une faute de frappe. Deux effets de **types différents** sur la même cible sont permis :
`ac+1:dodge, ac+2:deflection`.

---

## 7. La forme canonique

### 7.1 Pourquoi

Le même contenu peut s'écrire de dix façons : `str+2,cha-2`, `CHA -2 , FOR+2`…
Si chaque joueur stocke sa façon, deux bases qui disent la même chose ont des
`content_hash` différents, et **chaque échange de fichiers produit un faux conflit**.
La forme canonique garantit qu'un même contenu donne toujours le même texte, au
caractère près.

Elle doit vérifier trois propriétés, qui feront de bons tests :

1. **Idempotence** : mettre en forme canonique un texte déjà canonique le rend inchangé.
2. **Indifférence à l'ordre** : `a, b` et `b, a` donnent le même résultat.
3. **Indifférence à la présentation** : casse, espaces, accents des codes, alias
   français et séparateurs ne changent pas le résultat.

### 7.2 Les étapes

Les étapes s'enchaînent dans cet ordre. Une erreur à une étape n'empêche pas d'analyser
les effets suivants : on collecte **toutes** les erreurs, pour les montrer d'un coup.

**Étape 0 : nettoyage des caractères**

- Normaliser le texte en Unicode **NFC**. Un `é` peut arriver en un caractère ou en deux
  (`e` + accent), selon le clavier et le système. Après NFC, il n'en reste qu'une forme.
- Remplacer les variantes typographiques :
  - `−` (moins mathématique), `–` (tiret demi-cadratin) et `—` (cadratin) par `-` ;
  - `＋` par `+` ;
  - les espaces insécables (U+00A0, U+202F) par une espace ordinaire. Un clavier français
    en insère avant `:` et à l'intérieur des crochets.
- Retirer les espaces au début et à la fin.
- Si le texte est vide, le résultat est « aucun effet » : on stocke `NULL`.

**Étape 1 : découpage en effets**

Parcourir le texte caractère par caractère en suivant si l'on est **entre crochets** :

- `[` hors crochets : on entre dans une condition ;
- `[` entre crochets : erreur `CROCHETS_IMBRIQUES` ;
- `]` entre crochets : on sort de la condition ;
- `]` hors crochets : erreur `CROCHET_NON_OUVERT` ;
- `,` `;` ou retour à la ligne **hors crochets** : fin d'un effet ;
- en fin de texte encore entre crochets : erreur `CROCHET_NON_FERME`.

Chaque morceau est débarrassé de ses espaces de bord. Les morceaux vides sont ignorés.
On garde pour chaque morceau sa position de départ dans le texte, pour situer les erreurs.

**Étape 2 : analyse d'un effet, en partant de la droite**

On lit l'effet **de droite à gauche**, parce que la fin a une forme fixe
(signe, nombre, type, condition) alors que le début, le nom de compétence, est libre.
Cela permet des noms de compétence qui contiennent des tirets ou des parenthèses.

1. **Condition.** Si le morceau contient `[`, le texte entre `[` et `]` est la condition.
   - S'il reste quelque chose après `]` : `TEXTE_APRES_CONDITION`.
   - Les espaces de bord sont retirés, toute suite d'espaces intérieure devient une seule.
   - Si elle est vide : `CONDITION_VIDE`.
   - On continue avec ce qui précède `[`, sans ses espaces de fin.
2. **Type.** Si ce qui reste contient `:` :
   - plus d'un `:` : `TYPE_MULTIPLE` ;
   - sinon, ce qui suit `:` est le type, ce qui précède continue.
3. **Nombre.** On lit les chiffres à la fin de ce qui reste.
   - Aucun chiffre : `NOMBRE_MANQUANT`.
   - La valeur est convertie en entier : 0 donne `NOMBRE_NUL`, plus de 999 donne
     `NOMBRE_TROP_GRAND`.
4. **Signe.** On saute les espaces éventuels avant le nombre. Le caractère suivant
   (toujours vers la gauche) doit être `+` ou `-`, sinon `SIGNE_MANQUANT`.
5. **Cible.** Tout ce qui précède le signe, sans espaces de bord. S'il ne reste rien :
   `CIBLE_MANQUANTE`.

**Étape 3 : résolution**

- **Type** : calculer son slug et le chercher parmi les codes et alias du tableau 4.
  Introuvable : `TYPE_INCONNU`. Pas de type, ou `untyped` : « sans type ».
- **Cible** : calculer son slug et le chercher parmi les codes et alias du tableau 3.1.
  Introuvable : suivre les quatre essais de la section 3.2.
- **Spécialité** : espaces de bord retirés, suites d'espaces réduites à une, mise en
  minuscules.
- **Condition** : suivre les deux essais de la section 5.1. Trouvée : situation connue,
  avec son id. Introuvable : situation libre, avec son texte nettoyé (étape 2). Jamais
  d'erreur.

Après cette étape, chaque effet est une donnée structurée et non plus du texte :
une cible (un code, ou une compétence avec son id et sa spécialité), un signe et une
valeur, un type, une situation éventuelle (connue avec son id, ou libre avec son texte).

**Étape 4 : contrôle des doublons**

Deux effets sont en double s'ils ont la même cible (même code, ou même compétence avec
la même spécialité), le même type et la même situation. Deux situations connues se
comparent par leur id ; deux situations libres par leur slug, pour que
`[contre les Enchantements]` et `[contre les enchantements]` soient reconnues comme
identiques. Doublon : `EFFET_EN_DOUBLE`.

S'il y a eu la moindre erreur dans les étapes 1 à 4, on s'arrête ici et on rend la liste
des erreurs.

**Étape 5 : tri**

Les effets sont triés selon trois clés successives :

1. **la cible**, d'abord les codes dans l'ordre du tableau 3.1 (`str`, `dex`, `con`, `int`,
   `wis`, `cha`, `ac`, `fort`, `ref`, `will`, `saves`, `init`, `attack`, `melee`,
   `ranged`, `damage`, `melee_damage`, `ranged_damage`, `grapple`, `speed`, `hp`,
   `skills`), puis les compétences par slug de leur nom, puis par spécialité ;
2. **le type** : sans type d'abord, puis par ordre alphabétique du code ;
3. **la condition** : sans condition d'abord, puis par slug du texte écrit à l'étape 6
   (le `name` d'une situation connue, le texte d'une situation libre).

Grâce à l'étape 4, deux effets n'ont jamais les trois clés identiques : l'ordre est
toujours complètement déterminé.

**Étape 6 : écriture**

Chaque effet s'écrit, **sans aucune espace sauf avant le crochet** :

- la cible :
  - un code : le code canonique (`str`, `ac`, `will`…) ;
  - une compétence : son `name` **tel qu'il est stocké dans `skill`** ;
  - une compétence à spécialité : `name` + ` (` + spécialité + `)` ;
- le signe `+` ou `-` ;
- le nombre, sans zéro de tête ;
- si le bonus a un type : `:` + le code du type ;
- s'il y a une condition : une espace, `[`, puis le `name` de la situation **tel qu'il
  est stocké dans `situation`** pour une situation connue, ou le texte nettoyé pour une
  situation libre, puis `]`.

Les effets sont joints par `, ` (virgule et espace). Le résultat est stocké dans la
colonne `effects`, et c'est sur ce texte que se calcule le `content_hash`.

### 7.3 Quand remettre en forme canonique

- **à chaque saisie**, avant l'enregistrement, avec l'aperçu du résultat dans le
  formulaire ;
- **à chaque import** : un texte reçu est remis en forme canonique avec *son* référentiel
  local, et rejeté s'il ne s'analyse pas ;
- **après le renommage d'une compétence ou d'une situation** : les textes qui la citent
  contiennent l'ancien nom. Ils restent valides grâce à l'essai « ancien nom » (sections
  3.2 et 5.1), mais ne sont plus canoniques. Il faut donc les remettre en forme dans
  toutes les tables qui ont une colonne `effects`.
- **après l'ajout d'une situation** : une situation libre de même slug devient connue.
  Le texte ne change pas si le `name` est écrit pareil, mais il faut le remettre en
  forme si la casse ou les accents diffèrent.

---

## 8. Application des effets (calcul de la fiche)

Ce n'est pas le rôle de l'analyseur, mais c'est la raison d'être du langage.

### 8.1 Le calcul d'une valeur

Le calcul reçoit la fiche **et la liste des situations cochées** (vide par défaut). Pour
une valeur de la fiche (par exemple la CA ou un jet de Volonté) :

1. **Rassembler** les effets qui la visent dans toutes les sources actives du personnage :
   race, capacités, objets équipés, propriétés de ces objets, modificateurs actifs.
2. **Développer les cibles groupées** : `saves` compte pour `fort`, `ref` et `will` ;
   `attack` pour `melee` et `ranged` ; `damage` pour `melee_damage` et `ranged_damage` ;
   `skills` pour chaque compétence. Une ligne d'arme de la fiche prend `melee` et
   `melee_damage` pour une arme de corps à corps, `ranged` et `ranged_damage` pour une
   arme à distance (`weapon.wield = 'ranged'`).
3. **Trier les effets conditionnels** : un effet dont la situation est cochée est
   gardé, les autres sont mis de côté.
4. **Cumuler** les effets gardés selon la règle de la 3.5 :
   - les bonus sans type, d'esquive (`dodge`) et de circonstance s'additionnent ;
   - pour tout autre type, seul le plus grand bonus compte ;
   - les malus (valeurs négatives) s'additionnent tous.
5. Pour la CA, appliquer le tableau 3.3 pour obtenir les valeurs contact et pris au
   dépourvu.

La v1 ne gère pas la nuance « deux bonus de circonstance de la même source ne se
cumulent pas ».

### 8.2 Les situations sur la fiche

**Ce que la fiche affiche.** Par défaut, aucune situation n'est cochée : chaque valeur
est la valeur « sans situation particulière ». À côté d'une valeur, un menu liste les
situations qui la modifient, avec l'écart que chacune apporte. Cocher une situation dans
un menu la coche **pour toute la fiche** : Tir à bout portant modifie l'attaque et les
dégâts à distance, et le joueur ne doit pas avoir à cocher deux fois. Un bandeau rappelle
les situations cochées et permet de les retirer. Plusieurs situations peuvent être
cochées en même temps.

**Les situations de la fiche** sont toutes celles que citent les effets des sources
actives. Une situation connue est identifiée par son id, une situation libre par le slug
de son texte.

**Ce que le calcul rend**, pour chaque valeur :

- la valeur sans situation ;
- la valeur avec les situations cochées ;
- les situations qui la modifient, chacune avec son écart :
  - pour une situation non cochée, valeur avec (cochées + elle) moins valeur avec les
    cochées ;
  - pour une situation cochée, valeur avec les cochées moins valeur avec (cochées sans
    elle).

**L'écart se calcule en refaisant le calcul, jamais en additionnant les valeurs des
effets**, à cause de la règle de cumul. L'interface ne fait aucune addition : elle
affiche ce que le calcul lui rend.

**Les situations cochées ne sont pas enregistrées.** C'est un état de l'écran, gardé
tant que la fiche est ouverte : ce n'est pas un choix du personnage, mais le moment
de la partie. Ce qui dure (Rage, un sort lancé sur soi) passe par un
`character_modifier`, avec sa case `active`.

### 8.3 Jeux d'essai du calcul

On suppose un personnage sans autre bonus que ceux indiqués, avec la situation connue
« Bout portant ».

| Effets actifs | Situations cochées | Valeur | Résultat |
|---|---|---|---|
| `ranged+1 [Bout portant]` | aucune | attaque à distance | 0, menu : Bout portant +1 |
| `ranged+1 [Bout portant]` | Bout portant | attaque à distance | +1, menu : Bout portant +1 (cochée) |
| `ranged+1 [Bout portant]` | Bout portant | attaque au corps à corps | 0, pas de menu |
| `ranged+1 [Bout portant], ranged_damage+1 [Bout portant]` | Bout portant | dégâts d'un arc | +1 |
| `ranged+1 [Bout portant], ranged_damage+1 [Bout portant]` | Bout portant | dégâts d'une épée | 0 |
| `damage+2 [en charge]` | en charge | dégâts d'une épée et d'un arc | +2 et +2 |
| `attack+1:morale` et `attack+2:morale [en charge]` | aucune | attaque | +1, menu : en charge **+1** |
| `attack+1:morale` et `attack+2:morale [en charge]` | en charge | attaque | +2 (et non +3) |
| `ac+2:dodge [en combat]` | en combat | CA, contact, pris au dépourvu | +2, +2, 0 |

---

## 9. Versions et échanges

- `schema_info.effects_version` donne la version du langage. Un fichier reçu d'une
  version plus récente que celle de l'application est refusé avec un message clair,
  plutôt que mal lu.
- À l'import, l'ordre compte : d'abord les compétences et les situations, puis tout ce
  qui a une colonne `effects`. Sinon les noms ne se résolvent pas.
- Une compétence citée dans un texte mais absente du fichier reçu comme de la base
  locale empêche l'import de l'élément qui la cite. On le signale, on ne l'invente pas.
- Une situation citée mais absente devient une situation libre, sans bloquer l'import.
  Pour que tout le monde partage les mêmes situations, l'export embarque les situations
  connues que citent les éléments exportés.

---

## 10. Jeux d'essai

On suppose que la table `skill` contient « Perception auditive », « Détection »,
« Saut », « Connaissances (mystères) » et « Profession » (avec `has_specialty = 1`), et
que la table `situation` contient « Bout portant ».

### Textes valides

| Saisie | Forme canonique |
|---|---|
| `str+2, cha-2` | `str+2, cha-2` |
| `STR +2 , Cha-2` | `str+2, cha-2` |
| `cha-2; str+2` | `str+2, cha-2` |
| `for+2` | `str+2` |
| `init+4, dex+2` | `dex+2, init+4` |
| `ca+1:parade` | `ac+1:deflection` |
| `ac+1:untyped` | `ac+1` |
| `ac+2:deflection, ac+1:esquive` | `ac+1:dodge, ac+2:deflection` |
| `ac+1, ac+1:dodge` | `ac+1, ac+1:dodge` |
| `perception auditive+2:racial` | `Perception auditive+2:racial` |
| `PERCEPTION  AUDITIVE + 2 : Racial` | `Perception auditive+2:racial` |
| `détection+2, Perception auditive+2` | `Détection+2, Perception auditive+2` |
| `connaissances (mysteres)+2` | `Connaissances (mystères)+2` |
| `profession ( Marin )+2` | `Profession (marin)+2` |
| `vol+2:racial[ contre les   enchantements ]` | `will+2:racial [contre les enchantements]` |
| `will+2 [contre les sorts, les pouvoirs]` | `will+2 [contre les sorts, les pouvoirs]` |
| `will+2, will+2 [contre la terreur]` | `will+2, will+2 [contre la terreur]` |
| `dist+1 [BOUT  PORTANT], dég_dist+1 [bout-portant]` | `ranged+1 [Bout portant], ranged_damage+1 [Bout portant]` |
| `ranged+1 [à 9 m ou moins]` | `ranged+1 [à 9 m ou moins]` (situation libre) |
| `ranged+1 [Bout portant], ranged+1 [à 9 m ou moins]` | `ranged+1 [à 9 m ou moins], ranged+1 [Bout portant]` (deux situations) |
| `ranged_damage+1, damage+1` | `damage+1, ranged_damage+1` |
| `str+2,,dex+1,` | `str+2, dex+1` |
| `ac−1` (moins Unicode) | `ac-1` |
| `ac+02` | `ac+2` |
| *(vide ou espaces seuls)* | `NULL` |

### Textes refusés

| Saisie | Erreur |
|---|---|
| `str2` | `SIGNE_MANQUANT` (effet 1) |
| `str+` | `NOMBRE_MANQUANT` (effet 1) |
| `str+0` | `NOMBRE_NUL` (effet 1) |
| `hp+1000` | `NOMBRE_TROP_GRAND` (effet 1) |
| `+2` | `CIBLE_MANQUANTE` (effet 1) |
| `charme+2` | `CIBLE_INCONNUE` (effet 1) |
| `ac+1:bidon` | `TYPE_INCONNU` (effet 1) |
| `ac+1:dodge:luck` | `TYPE_MULTIPLE` (effet 1) |
| `Saut (haut)+2` | `SPECIALITE_INTERDITE` (effet 1) |
| `str+2, for-1` | `EFFET_EN_DOUBLE` (effet 2) |
| `ranged+1 [bout portant], dist+2 [Bout-Portant]` | `EFFET_EN_DOUBLE` (effet 2) |
| `will+2 [contre` | `CROCHET_NON_FERME` |
| `will+2 contre]` | `CROCHET_NON_OUVERT` |
| `will+2 [a [b]]` | `CROCHETS_IMBRIQUES` |
| `will+2 [a] x` | `TEXTE_APRES_CONDITION` (effet 1) |
| `will+2 []` | `CONDITION_VIDE` (effet 1) |
| `str2, charme+2` | `SIGNE_MANQUANT` (effet 1) **et** `CIBLE_INCONNUE` (effet 2) : toutes les erreurs d'un coup |

### Propriétés à tester en plus

- Pour chaque ligne du premier tableau, remettre en forme canonique la forme canonique
  obtenue doit la redonner à l'identique (idempotence).
- Mélanger l'ordre des effets d'une saisie valide ne doit pas changer le résultat.

---

## 11. Parcours d'apprentissage Rust

L'analyseur est un bon premier projet Rust : pas d'interface, pas de base, des entrées et
des sorties en texte, et des tests déjà écrits ci-dessus. Je te propose de le construire
dans une **bibliothèque à part** (une *crate* de type `lib`), testée par `cargo test`,
que l'application Tauri utilisera ensuite.

Chaque exercice ajoute une étape et les tests qui vont avec.

| # | Exercice | Notions Rust rencontrées |
|---|---|---|
| 1 | **Les types.** Décrire une cible, un type de bonus, un effet et une erreur sous forme de types : une énumération pour les caractéristiques, une pour les types de bonus, une pour les cibles (dont une variante « compétence » qui porte un id et une spécialité), une structure pour l'effet, une énumération pour les erreurs. | `enum` avec données, `struct`, `Option`, les `derive` (`Debug`, `Clone`, `PartialEq`, `Eq`, `Hash`, `PartialOrd`, `Ord`) |
| 2 | **Les tables de correspondance.** Codes et alias vers les énumérations (tableaux 3.1 et 4), et la fonction de slug. | `match`, `&str` contre `String`, itération sur `chars()`, la crate `unicode-normalization` |
| 3 | **Le nettoyage** (étape 0). | Unicode en Rust : une `String` est de l'UTF-8, un caractère peut faire plusieurs octets |
| 4 | **Le découpage** (étape 1), avec les erreurs de crochets. | `char_indices`, et le piège : on ne coupe une chaîne qu'à une frontière de caractère, jamais au milieu d'un `é` |
| 5 | **L'analyse d'un effet** (étape 2), de droite à gauche. | `rfind`, `split_at`, `trim`, `parse`, `Result` et l'opérateur `?` |
| 6 | **La résolution** (étape 3). Les référentiels des compétences et des situations arrivent en paramètre, pour que les tests leur passent de fausses listes en mémoire, sans base de données. | emprunts (`&`), `HashMap`, durées de vie quand une fonction rend un morceau de son entrée |
| 7 | **Doublons et tri** (étapes 4 et 5). | `HashSet`, `sort_by_key`, ordre dérivé des variantes d'un `enum` |
| 8 | **L'écriture** (étape 6). | le trait `Display`, `join` |
| 9 | **Toutes les erreurs d'un coup.** Faire d'abord une version qui s'arrête à la première erreur, puis une qui les collecte toutes. | `Vec<Erreur>`, `Result<T, Vec<E>>`, `Iterator::partition` |
| 10 | **Les tests de propriété** (idempotence, ordre indifférent), en bonus. | la crate `proptest` |
| 11 | **Le branchement dans Tauri** : une commande qui reçoit le texte saisi et rend la forme canonique ou les erreurs, sérialisées en JSON pour Angular. | `#[tauri::command]`, la crate `serde` |

Trois règles à garder tout du long :

- **Jamais de `unwrap()` sur une entrée utilisateur.** Un texte mal formé doit produire une
  erreur, pas faire planter l'application.
- **Écrire le test avant l'étape.** Les tableaux de la section 10 sont déjà les tests.
- **Garder l'analyseur indépendant de la base.** Il reçoit la liste des compétences et
  des situations, il ne va pas la lire lui-même. C'est ce qui le rend testable.

Le calcul de la fiche (section 8), avec ses situations cochées, fera un bon deuxième
projet une fois l'analyseur fini : ses jeux d'essai sont dans la section 8.3.
