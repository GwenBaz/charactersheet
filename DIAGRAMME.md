# Diagramme de classes du schéma

Une classe par table de `schema.sql` (33 tables). Les diagrammes sont en
[Mermaid](https://mermaid.js.org/) : ils s'affichent sur GitHub, dans VS Code avec
l'extension « Markdown Preview Mermaid Support », ou en collant un bloc sur
<https://mermaid.live>.

## Lire les flèches

| Trait | Sens | En SQL |
|---|---|---|
| `A *-- B` (losange plein) | B appartient à A et disparaît avec lui | clé étrangère `ON DELETE CASCADE` |
| `A o-- B` (losange vide) | B est rangé dans A, mais lui survit | clé étrangère `ON DELETE SET NULL` |
| `A --> B` (flèche pleine) | A fait référence à B ; B ne peut pas être supprimé tant qu'il est utilisé | clé étrangère simple |
| `A ..> B` (pointillés) | A cite B par son nom dans sa colonne `effects` | **aucune** clé étrangère (voir `EFFETS.md`) |

L'étiquette d'un lien est la colonne qui porte la clé étrangère. Dans les diagrammes
détaillés, `PK` marque la clé primaire et `FK` une clé étrangère.

Les classes ont le nom de leur table, sauf `class`, qui est un mot réservé de Mermaid :
elle s'appelle `classe` dans le code des diagrammes, mais s'affiche `class`.

`schema_info` (version du schéma, du slug et du langage des effets, espace de noms des
ids) n'a aucun lien : elle n'apparaît pas dans les diagrammes.

Les colonnes de partage `source`, `author`, `updated_at` et `content_hash`, présentes dans
toutes les tables à id du référentiel, sont résumées par la ligne `partage`.

---

## 1. Vue d'ensemble

Toutes les tables et toutes les clés étrangères, sans les colonnes. À gauche le
référentiel partagé (ids UUID v5, identiques chez tous les joueurs), à droite les
personnages (ids UUID v4, propres à chaque joueur).

```mermaid
classDiagram
direction LR

namespace Referentiel {
    class language
    class skill
    class skill_synergy
    class situation
    class feature
    class race
    class race_feature
    class race_language
    class classe["class"]
    class class_level
    class class_spell_slots
    class class_feature
    class class_skill
    class spell_school
    class spell
    class spell_class_level
    class item
    class weapon
    class armor
    class special_property
}

namespace Personnages {
    class character
    class character_level
    class character_skill
    class character_feature
    class character_language
    class character_item
    class character_item_property
    class character_caster
    class character_forbidden_school
    class character_spell
    class character_spell_slot
    class character_modifier
}

skill *-- skill_synergy
race *-- race_feature
race_feature --> feature
race *-- race_language
race_language --> language
race --> classe
classe *-- class_level
classe *-- class_spell_slots
classe *-- class_feature
class_feature --> feature
classe *-- class_skill
class_skill --> skill
spell --> spell_school
spell *-- spell_class_level
spell_class_level --> classe
item *-- weapon
item *-- armor

character --> race
character *-- character_level
character_level --> classe
character *-- character_skill
character_skill --> skill
character *-- character_feature
character_feature --> feature
character *-- character_language
character_language --> language
character *-- character_item
character_item --> item
character_item *-- character_item_property
character_item_property --> special_property
character *-- character_caster
character_caster --> classe
character_caster --> spell_school
character_caster *-- character_forbidden_school
character_forbidden_school --> spell_school
character_caster *-- character_spell
character_spell --> spell
character_caster *-- character_spell_slot
character *-- character_modifier
```

Ce qu'il faut en retenir :

- **Les flèches vont toujours des personnages vers le référentiel, jamais l'inverse.**
  On peut donc échanger le référentiel sans rien savoir des personnages, et un personnage
  exporté doit emmener (ou trouver chez le destinataire) les éléments du référentiel
  qu'il cite.
- **Supprimer un personnage supprime tout ce qui lui appartient** (losanges pleins),
  mais rien dans le référentiel.
- **Un élément du référentiel utilisé par un personnage ne peut pas être supprimé**
  (flèches pleines sans cascade) : SQLite refuse, tant que `PRAGMA foreign_keys = ON`.
- **`situation` reste isolée** : aucune clé étrangère ne la vise, elle n'est citée que
  dans les textes `effects` (section 6). `special_property` n'est visée que par
  `character_item_property`.

---

## 2. Règles : compétences, situations, capacités, races, classes

```mermaid
classDiagram
direction TB

class skill {
    TEXT id PK
    TEXT name
    TEXT ability
    INTEGER trained_only
    INTEGER armor_check_penalty
    INTEGER has_specialty
    TEXT description
    partage
}
class skill_synergy {
    TEXT source_skill_id PK FK
    TEXT target_skill_id PK FK
    INTEGER min_ranks
    INTEGER bonus
    TEXT condition
}
class situation {
    TEXT id PK
    TEXT name
    TEXT description
    partage
}
class feature {
    TEXT id PK
    TEXT name
    TEXT kind
    TEXT feat_category
    INTEGER fighter_bonus
    INTEGER has_choice
    INTEGER repeatable
    TEXT prerequisites
    TEXT effects
    TEXT description
    partage
}
class language {
    TEXT id PK
    TEXT name
    TEXT script
    TEXT description
    partage
}
class race {
    TEXT id PK
    TEXT name
    TEXT size
    REAL base_speed_m
    TEXT effects
    INTEGER level_adjustment
    TEXT favored_class_id FK
    INTEGER bonus_skill_points
    INTEGER bonus_feats
    TEXT description
    partage
}
class race_feature {
    TEXT race_id PK FK
    TEXT feature_id PK FK
}
class race_language {
    TEXT race_id PK FK
    TEXT language_id PK FK
    INTEGER automatic
}
class classe["class"] {
    TEXT id PK
    TEXT name
    INTEGER hit_die
    INTEGER skill_points
    INTEGER is_prestige
    INTEGER max_level
    TEXT caster_type
    TEXT casting_ability
    INTEGER knows_all_spells
    TEXT prerequisites
    TEXT description
    partage
}
class class_level {
    TEXT class_id PK FK
    INTEGER level PK
    INTEGER base_attack_bonus
    INTEGER fort_save
    INTEGER ref_save
    INTEGER will_save
}
class class_spell_slots {
    TEXT class_id PK FK
    INTEGER class_level PK
    INTEGER spell_level PK
    INTEGER per_day
    INTEGER known
}
class class_feature {
    TEXT class_id PK FK
    INTEGER level PK
    TEXT feature_id PK FK
    INTEGER rank
}
class class_skill {
    TEXT class_id PK FK
    TEXT skill_id PK FK
}

skill "1" *-- "0..*" skill_synergy : source_skill_id
skill "1" *-- "0..*" skill_synergy : target_skill_id
race "1" *-- "0..*" race_feature : race_id
race_feature "0..*" --> "1" feature : feature_id
race "1" *-- "0..*" race_language : race_id
race_language "0..*" --> "1" language : language_id
race "0..*" --> "0..1" classe : favored_class_id
classe "1" *-- "1..20" class_level : class_id
classe "1" *-- "0..*" class_spell_slots : class_id
classe "1" *-- "0..*" class_feature : class_id
class_feature "0..*" --> "1" feature : feature_id
classe "1" *-- "0..*" class_skill : class_id
class_skill "0..*" --> "1" skill : skill_id
```

`feature` regroupe les dons, les aptitudes de classe et les traits raciaux (`kind`). Une
race les reçoit par `race_feature`, une classe par `class_feature` (avec le niveau et le
rang), un personnage par `character_feature` (section 5).

---

## 3. Magie

```mermaid
classDiagram
direction LR

class spell_school {
    TEXT id PK
    TEXT name
    partage
}
class spell {
    TEXT id PK
    TEXT name
    TEXT school_id FK
    TEXT subschool
    TEXT descriptors
    TEXT components
    TEXT casting_time
    TEXT range
    TEXT target_area
    TEXT duration
    TEXT saving_throw
    TEXT spell_resistance
    TEXT description
    partage
}
class spell_class_level {
    TEXT spell_id PK FK
    TEXT class_id PK FK
    INTEGER level
}
class classe["class"]

spell "0..*" --> "0..1" spell_school : school_id
spell "1" *-- "1..*" spell_class_level : spell_id
spell_class_level "0..*" --> "1" classe : class_id
```

Un sort n'a pas le même niveau selon la classe : c'est `spell_class_level` qui le porte,
pas `spell`.

---

## 4. Objets

```mermaid
classDiagram
direction LR

class item {
    TEXT id PK
    TEXT name
    TEXT category
    REAL weight_kg
    INTEGER price_cp
    TEXT capacity
    TEXT effects
    TEXT description
    partage
}
class weapon {
    TEXT item_id PK FK
    TEXT proficiency
    TEXT wield
    TEXT damage_small
    TEXT damage_medium
    INTEGER crit_range_min
    INTEGER crit_multiplier
    REAL range_increment_m
    TEXT damage_type
}
class armor {
    TEXT item_id PK FK
    TEXT armor_type
    INTEGER ac_bonus
    INTEGER max_dex
    INTEGER check_penalty
    INTEGER arcane_failure
    REAL speed_9m
    REAL speed_6m
}
class special_property {
    TEXT id PK
    TEXT name
    TEXT applies_to
    INTEGER bonus_equivalent
    INTEGER flat_price_cp
    TEXT effects
    TEXT description
    partage
}

item "1" *-- "0..1" weapon : item_id
item "1" *-- "0..1" armor : item_id
```

`weapon` et `armor` sont des **extensions** de `item` (relation 1-1, même clé) : une épée
longue a une ligne dans `item` et une dans `weapon`. `special_property` n'est reliée à
aucun objet du référentiel : c'est l'objet **porté par un personnage** qui reçoit ses
propriétés (`character_item_property`, section 5).

---

## 5. Personnages

Les tables du référentiel apparaissent sans leurs colonnes, détaillées plus haut.

```mermaid
classDiagram
direction LR

class character {
    TEXT id PK
    TEXT name
    TEXT player
    TEXT race_id FK
    TEXT alignment
    TEXT deity
    TEXT size_override
    INTEGER age
    TEXT gender
    TEXT height
    TEXT weight
    INTEGER str_dex_con_int_wis_cha_score
    INTEGER hp_current
    INTEGER nonlethal_damage
    INTEGER action_points
    TEXT action_dice
    TEXT damage_reduction
    TEXT immunities
    INTEGER coins_cp_sp_gp_pp
    TEXT notes
    TEXT created_at
    TEXT updated_at
}
class character_level {
    TEXT character_id PK FK
    INTEGER level PK
    TEXT class_id FK
    INTEGER hp_roll
    TEXT ability_increase
}
class character_skill {
    TEXT character_id PK FK
    TEXT skill_id PK FK
    TEXT specialty PK
    REAL ranks
    INTEGER misc
}
class character_feature {
    TEXT character_id PK FK
    TEXT feature_id PK FK
    TEXT choice PK
    INTEGER level_gained
    TEXT origin
    TEXT notes
}
class character_language {
    TEXT character_id PK FK
    TEXT language_id PK FK
}
class character_item {
    TEXT id PK
    TEXT character_id FK
    TEXT item_id FK
    TEXT custom_name
    INTEGER quantity
    TEXT location
    TEXT container_id FK
    INTEGER equipped
    INTEGER masterwork
    INTEGER enhancement
    REAL weight_kg
    INTEGER value_cp
    TEXT notes
    INTEGER sort_order
}
class character_item_property {
    TEXT character_item_id PK FK
    TEXT special_property_id PK FK
}
class character_caster {
    TEXT character_id PK FK
    TEXT class_id PK FK
    TEXT specialty_school_id FK
}
class character_forbidden_school {
    TEXT character_id PK FK
    TEXT class_id PK FK
    TEXT school_id PK FK
}
class character_spell {
    TEXT character_id PK FK
    TEXT class_id PK FK
    TEXT spell_id PK FK
}
class character_spell_slot {
    TEXT character_id PK FK
    TEXT class_id PK FK
    INTEGER spell_level PK
    INTEGER used
}
class character_modifier {
    TEXT id PK
    TEXT character_id FK
    TEXT effects
    TEXT label
    INTEGER active
    INTEGER temporary
}

class race
class classe["class"]
class skill
class feature
class language
class item
class special_property
class spell_school
class spell

character "0..*" --> "0..1" race : race_id
character "1" *-- "0..*" character_level : character_id
character_level "0..*" --> "1" classe : class_id
character "1" *-- "0..*" character_skill : character_id
character_skill "0..*" --> "1" skill : skill_id
character "1" *-- "0..*" character_feature : character_id
character_feature "0..*" --> "1" feature : feature_id
character "1" *-- "0..*" character_language : character_id
character_language "0..*" --> "1" language : language_id
character "1" *-- "0..*" character_item : character_id
character_item "0..*" --> "0..1" item : item_id
character_item "0..1" o-- "0..*" character_item : container_id
character_item "1" *-- "0..*" character_item_property : character_item_id
character_item_property "0..*" --> "1" special_property : special_property_id
character "1" *-- "0..*" character_caster : character_id
character_caster "0..*" --> "1" classe : class_id
character_caster "0..*" --> "0..1" spell_school : specialty_school_id
character_caster "1" *-- "0..*" character_forbidden_school : character_id, class_id
character_forbidden_school "0..*" --> "1" spell_school : school_id
character_caster "1" *-- "0..*" character_spell : character_id, class_id
character_spell "0..*" --> "1" spell : spell_id
character_caster "1" *-- "0..10" character_spell_slot : character_id, class_id
character "1" *-- "0..*" character_modifier : character_id
```

Points de lecture :

- **Les six caractéristiques sont des colonnes de `character`** (`str_score` …
  `cha_score`), résumées ici en une ligne. La « valeur temporaire » de la fiche n'est pas
  stockée : c'est la valeur de base plus les `character_modifier` actifs.
- **`character_caster` est un intermédiaire** : les sorts connus, les emplacements
  utilisés et les écoles interdites d'un personnage dépendent de la classe qui les lance
  (un prêtre-magicien a deux listes). Leur clé étrangère est composée,
  `(character_id, class_id)`.
- **Personne ne prépare ses sorts** (règle maison). `character_spell` ne dit que « ce sort
  est connu » ; `character_spell_slot` compte les emplacements utilisés par niveau de
  sort depuis le dernier repos. Le nombre d'emplacements, lui, se calcule. Une classe à
  `knows_all_spells = 1` (prêtre, druide) n'a pas de ligne dans `character_spell` : elle
  connaît toute sa liste.
- **`character_item` se contient lui-même** : `container_id` range un objet dans un sac.
  Supprimer le sac ne supprime pas son contenu, qui se retrouve hors de tout récipient
  (`SET NULL`).
- **`character_item.item_id` est facultatif** : un objet peut être saisi librement, sans
  entrée dans le référentiel (`custom_name`).

`coins_cp_sp_gp_pp` résume les quatre colonnes `coins_cp`, `coins_sp`, `coins_gp` et
`coins_pp`.

---

## 6. Les effets : des liens sans clé étrangère

Cinq tables ont une colonne `effects`, écrite dans le langage décrit par `EFFETS.md`. Ces
textes citent des compétences et des situations **par leur nom**, pas par leur id : SQLite
ne peut pas vérifier ces liens, c'est l'analyseur Rust qui le fait, à chaque saisie et à
chaque import.

```mermaid
classDiagram
direction LR

class race {
    TEXT effects
}
class feature {
    TEXT effects
}
class item {
    TEXT effects
}
class special_property {
    TEXT effects
}
class character_modifier {
    TEXT effects
}
class skill {
    TEXT name
}
class situation {
    TEXT name
}

race ..> skill : effects
feature ..> skill : effects
item ..> skill : effects
special_property ..> skill : effects
character_modifier ..> skill : effects
race ..> situation : effects
feature ..> situation : effects
item ..> situation : effects
special_property ..> situation : effects
character_modifier ..> situation : effects
```

Conséquences :

- une compétence citée doit exister : sinon l'effet est refusé (`CIBLE_INCONNUE`) ;
- une situation citée peut ne pas exister : elle devient une situation libre ;
- supprimer ou renommer une compétence ou une situation ne prévient pas SQLite : c'est
  l'application qui doit remettre en forme les textes qui la citent (`EFFETS.md`, 7.3) ;
- à l'import, compétences et situations passent avant les tables qui les citent
  (`EFFETS.md`, section 9).
