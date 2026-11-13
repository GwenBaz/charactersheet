-- =====================================================================
-- Fiches de personnage D&D 3.5 — schéma SQLite (Tauri : desktop, Android plus tard)
--
-- Deux mondes :
--   1. le RÉFÉRENTIEL partagé (races, classes, compétences, dons, sorts,
--      objets…) : id déterministe = UUID v5(espace de l'appli, "<type>/<slug du nom>"),
--      calculé une seule fois à la création (côté Rust) puis figé : renommer ne
--      change pas l'id. Mêmes ids chez tous les joueurs → l'échange de fichiers
--      fusionne tout seul.
--   2. les PERSONNAGES : id aléatoire (UUID v4) — deux joueurs peuvent avoir
--      chacun leur « Gandalf ».
--
-- Règle : on stocke ce que le joueur choisit ou tire aux dés, jamais ce qui se
-- calcule (modificateurs, CA totale, sauvegardes, BBA, lutte, totaux de
-- compétences, charge, DD des sorts, sorts en bonus…).
--
-- Tables de liaison : clé primaire composée des ids qu'elles relient, donc
-- elles aussi identiques chez tout le monde, sans id propre.
--
-- À chaque connexion : PRAGMA foreign_keys = ON;  (désactivé par défaut en SQLite)
-- Tables STRICT : SQLite >= 3.37. Booléens : INTEGER 0/1.
-- =====================================================================

-- Colonnes de partage, présentes dans chaque table du référentiel :
--   source        TEXT  -- « Réf. » de la fiche : livre + page (ex. « MdJ p. 89 »)
--   author        TEXT  -- pseudo du joueur qui a saisi / modifié en dernier
--   updated_at    TEXT  -- ISO 8601 UTC
--   content_hash  TEXT  -- SHA-256 du contenu (hors ces 4 colonnes) : détecte les conflits à l'import

CREATE TABLE schema_info (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
) STRICT;
-- ('schema_version', '1'), ('id_namespace', '<uuid fixe de l'appli>'), ('slug_version', '1'),
-- ('effects_version', '1')

-- Colonne effects (race, feature, item, special_property, character_modifier) :
-- bonus écrits dans le pseudo-langage décrit dans EFFETS.md, toujours stockés
-- en forme canonique (NULL si aucun effet). Ex. : 'dex+2, con-2', 'ac+1:deflection',
-- 'ranged+1 [Bout portant], ranged_damage+1 [Bout portant]'. Ces textes citent des
-- compétences (skill) et des situations (situation) par leur nom, sans clé étrangère.

-- =====================================================================
-- 1. RÉFÉRENTIEL PARTAGÉ
-- =====================================================================

-- ---------- Langues (page 2 « Langues ») ----------
CREATE TABLE language (
    id           TEXT PRIMARY KEY,
    name         TEXT NOT NULL,
    script       TEXT,                 -- alphabet (draconique, elfique…)
    description  TEXT,
    source TEXT, author TEXT, updated_at TEXT, content_hash TEXT
) STRICT;

-- ---------- Compétences (page 1) ----------
CREATE TABLE skill (
    id                   TEXT PRIMARY KEY,
    name                 TEXT NOT NULL,
    ability              TEXT CHECK (ability IN ('str','dex','con','int','wis','cha')),  -- NULL pour Langue
    trained_only         INTEGER NOT NULL DEFAULT 0 CHECK (trained_only IN (0,1)),       -- 1 = « non-innée »
    armor_check_penalty  INTEGER NOT NULL DEFAULT 0 CHECK (armor_check_penalty IN (0,1,2)), -- * = 1, Natation = 2
    has_specialty        INTEGER NOT NULL DEFAULT 0 CHECK (has_specialty IN (0,1)),     -- Artisanat (…), Profession (…), Représentation (…)
    description          TEXT,
    source TEXT, author TEXT, updated_at TEXT, content_hash TEXT
) STRICT;

-- colonne « bonus de synergie » : 5 degrés dans source → +2 dans cible
CREATE TABLE skill_synergy (
    source_skill_id  TEXT NOT NULL REFERENCES skill(id) ON DELETE CASCADE,
    target_skill_id  TEXT NOT NULL REFERENCES skill(id) ON DELETE CASCADE,
    min_ranks        INTEGER NOT NULL DEFAULT 5,
    bonus            INTEGER NOT NULL DEFAULT 2,
    condition        TEXT,             -- « pour les tests liés aux parchemins »…
    PRIMARY KEY (source_skill_id, target_skill_id)
) STRICT;

-- ---------- Situations : les [conditions] des effets, cochées sur la fiche ----------
-- Pas de clé étrangère : les effets citent la situation par son nom (EFFETS.md, 5.1).
-- Une condition absente de cette table reste une situation « libre », cochable quand même.
-- Les situations cochées ne sont pas enregistrées : c'est un état de l'écran.
CREATE TABLE situation (
    id           TEXT PRIMARY KEY,     -- UUID v5 de "situation/<slug du nom>"
    name         TEXT NOT NULL,        -- « Bout portant »
    description  TEXT,                 -- « cible à 9 m ou moins » : infobulle du menu
    source TEXT, author TEXT, updated_at TEXT, content_hash TEXT
) STRICT;

-- ---------- Capacités : dons, aptitudes de classe, traits raciaux (pages 3 et 4) ----------
-- Une seule table (comme ton feats.sql) : même forme « nom + description + effets ».
CREATE TABLE feature (
    id             TEXT PRIMARY KEY,
    name           TEXT NOT NULL,
    kind           TEXT NOT NULL CHECK (kind IN ('feat','class_feature','racial_trait')),
    feat_category  TEXT,               -- dons : général, métamagie, création d'objets…
    fighter_bonus  INTEGER NOT NULL DEFAULT 0 CHECK (fighter_bonus IN (0,1)),  -- don supplémentaire de guerrier
    has_choice     INTEGER NOT NULL DEFAULT 0 CHECK (has_choice IN (0,1)),     -- Arme de prédilection (…), Ennemi juré (…)
    repeatable     INTEGER NOT NULL DEFAULT 0 CHECK (repeatable IN (0,1)),     -- peut se prendre plusieurs fois
    prerequisites  TEXT,               -- texte libre ; structurer plus tard si on veut vérifier
    effects        TEXT,               -- Science de l'initiative : 'init+4'
    description    TEXT,
    source TEXT, author TEXT, updated_at TEXT, content_hash TEXT
) STRICT;

-- ---------- Races ----------
CREATE TABLE race (
    id                  TEXT PRIMARY KEY,
    name                TEXT NOT NULL,
    size                TEXT NOT NULL DEFAULT 'medium'
                        CHECK (size IN ('fine','diminutive','tiny','small','medium','large','huge','gargantuan','colossal')),
    base_speed_m        REAL NOT NULL DEFAULT 9,
    effects             TEXT,                         -- ajustements raciaux : 'dex+2, con-2'
    level_adjustment    INTEGER NOT NULL DEFAULT 0,   -- « ajustement de niveau » (page 4)
    favored_class_id    TEXT REFERENCES class(id),    -- NULL = classe la plus haute
    bonus_skill_points  INTEGER NOT NULL DEFAULT 0,   -- humain : +1 / niveau (×4 au niveau 1)
    bonus_feats         INTEGER NOT NULL DEFAULT 0,   -- humain : 1
    description         TEXT,
    source TEXT, author TEXT, updated_at TEXT, content_hash TEXT
) STRICT;

CREATE TABLE race_feature (               -- traits raciaux
    race_id     TEXT NOT NULL REFERENCES race(id) ON DELETE CASCADE,
    feature_id  TEXT NOT NULL REFERENCES feature(id),
    PRIMARY KEY (race_id, feature_id)
) STRICT;

CREATE TABLE race_language (
    race_id      TEXT NOT NULL REFERENCES race(id) ON DELETE CASCADE,
    language_id  TEXT NOT NULL REFERENCES language(id),
    automatic    INTEGER NOT NULL CHECK (automatic IN (0,1)),  -- 1 = de départ, 0 = supplémentaire au choix
    PRIMARY KEY (race_id, language_id)
) STRICT;

-- ---------- Classes ----------
CREATE TABLE class (
    id               TEXT PRIMARY KEY,
    name             TEXT NOT NULL,
    hit_die          INTEGER NOT NULL CHECK (hit_die IN (4,6,8,10,12)),
    skill_points     INTEGER NOT NULL,             -- par niveau, avant mod. d'INT
    is_prestige      INTEGER NOT NULL DEFAULT 0 CHECK (is_prestige IN (0,1)),
    max_level        INTEGER NOT NULL DEFAULT 20,
    caster_type      TEXT CHECK (caster_type IN ('arcane','divine')),   -- NULL = pas de sorts
    casting_ability  TEXT CHECK (casting_ability IN ('int','wis','cha')),
    knows_all_spells INTEGER CHECK (knows_all_spells IN (0,1)),         -- 1 prêtre/druide : toute la liste de la classe
                                                   -- 0 magicien/ensorceleur/barde : seulement character_spell
                                                   -- (règle maison : personne ne prépare, tout le monde a des emplacements)
    prerequisites    TEXT,                         -- classes de prestige
    description      TEXT,
    source TEXT, author TEXT, updated_at TEXT, content_hash TEXT
) STRICT;

-- ton class_progressions, sans id propre
CREATE TABLE class_level (
    class_id           TEXT NOT NULL REFERENCES class(id) ON DELETE CASCADE,
    level              INTEGER NOT NULL CHECK (level BETWEEN 1 AND 20),
    base_attack_bonus  INTEGER NOT NULL,   -- premier bonus ; les attaques multiples se calculent
    fort_save          INTEGER NOT NULL,
    ref_save           INTEGER NOT NULL,
    will_save          INTEGER NOT NULL,
    PRIMARY KEY (class_id, level)
) STRICT;

-- sorts par jour / connus (page 3) : une ligne par niveau de sort plutôt que 10 colonnes
CREATE TABLE class_spell_slots (
    class_id     TEXT NOT NULL REFERENCES class(id) ON DELETE CASCADE,
    class_level  INTEGER NOT NULL CHECK (class_level BETWEEN 1 AND 20),
    spell_level  INTEGER NOT NULL CHECK (spell_level BETWEEN 0 AND 9),
    per_day      INTEGER,      -- 0 = seulement avec les sorts en bonus ; ligne absente = pas d'accès
    known        INTEGER,      -- nombre de sorts connus (ensorceleur, barde) ; NULL = sans limite
    PRIMARY KEY (class_id, class_level, spell_level)
) STRICT;

CREATE TABLE class_feature (               -- aptitudes de classe gagnées par niveau
    class_id    TEXT NOT NULL REFERENCES class(id) ON DELETE CASCADE,
    level       INTEGER NOT NULL,
    feature_id  TEXT NOT NULL REFERENCES feature(id),
    rank        INTEGER NOT NULL DEFAULT 1,   -- Ennemi juré 1, 2, 3… = même capacité, rang croissant
    PRIMARY KEY (class_id, level, feature_id)
) STRICT;

CREATE TABLE class_skill (                 -- « compétence de classe » (case à cocher)
    class_id  TEXT NOT NULL REFERENCES class(id) ON DELETE CASCADE,
    skill_id  TEXT NOT NULL REFERENCES skill(id),
    PRIMARY KEY (class_id, skill_id)
) STRICT;

-- ---------- Magie ----------
CREATE TABLE spell_school (                -- école de prédilection / écoles interdites
    id    TEXT PRIMARY KEY,
    name  TEXT NOT NULL,
    source TEXT, author TEXT, updated_at TEXT, content_hash TEXT
) STRICT;

CREATE TABLE spell (
    id               TEXT PRIMARY KEY,
    name             TEXT NOT NULL,
    school_id        TEXT REFERENCES spell_school(id),
    subschool        TEXT,
    descriptors      TEXT,             -- [feu], [mental]…
    components       TEXT,             -- V, G, M, F, FD, PX
    casting_time     TEXT,
    range            TEXT,
    target_area      TEXT,             -- cible / zone d'effet / effet
    duration         TEXT,
    saving_throw     TEXT,
    spell_resistance TEXT,
    description      TEXT,
    source TEXT, author TEXT, updated_at TEXT, content_hash TEXT
) STRICT;

-- un sort n'a pas le même niveau selon la classe (Ens/Mag 3, Prê 4…)
CREATE TABLE spell_class_level (
    spell_id  TEXT NOT NULL REFERENCES spell(id) ON DELETE CASCADE,
    class_id  TEXT NOT NULL REFERENCES class(id),
    level     INTEGER NOT NULL CHECK (level BETWEEN 0 AND 9),
    PRIMARY KEY (spell_id, class_id)
) STRICT;

-- ---------- Objets (pages 2 et 4) ----------
CREATE TABLE item (
    id                TEXT PRIMARY KEY,
    name              TEXT NOT NULL,
    category          TEXT NOT NULL CHECK (category IN
                      ('weapon','ammo','armor','shield','container','gear','magic','gem','art','other')),
    weight_kg         REAL,
    price_cp          INTEGER,         -- en pièces de cuivre (1 po = 100 pc) : pas de flottant
    capacity          TEXT,            -- récipients : « contenance »
    effects           TEXT,            -- objets magiques : anneau de protection +1 → 'ac+1:deflection'
    description       TEXT,
    source TEXT, author TEXT, updated_at TEXT, content_hash TEXT
) STRICT;

CREATE TABLE weapon (                      -- 1-1 avec item
    item_id            TEXT PRIMARY KEY REFERENCES item(id) ON DELETE CASCADE,
    proficiency        TEXT NOT NULL CHECK (proficiency IN ('simple','martial','exotic')),
    wield              TEXT NOT NULL CHECK (wield IN ('light','one_handed','two_handed','ranged')),
    damage_small       TEXT,           -- « 1d6 »
    damage_medium      TEXT,           -- « 1d8 »
    crit_range_min     INTEGER NOT NULL DEFAULT 20,   -- 19 → 19-20
    crit_multiplier    INTEGER NOT NULL DEFAULT 2,
    range_increment_m  REAL,           -- « portée » (facteur)
    damage_type        TEXT            -- « type » : P, C, T, « P ou T »
) STRICT;

CREATE TABLE armor (                       -- armures ET boucliers, 1-1 avec item
    item_id          TEXT PRIMARY KEY REFERENCES item(id) ON DELETE CASCADE,
    armor_type       TEXT NOT NULL CHECK (armor_type IN ('light','medium','heavy','shield')),
    ac_bonus         INTEGER NOT NULL,
    max_dex          INTEGER,          -- NULL = pas de limite
    check_penalty    INTEGER NOT NULL DEFAULT 0,      -- « malus aux tests », négatif
    arcane_failure   INTEGER NOT NULL DEFAULT 0,      -- « échec des sorts », en %
    speed_9m         REAL,             -- vitesse en armure pour une vitesse de base de 9 m
    speed_6m         REAL              -- … et de 6 m
) STRICT;

CREATE TABLE special_property (            -- « propriétés spéciales » : de feu, acérée, de résistance…
    id                 TEXT PRIMARY KEY,
    name               TEXT NOT NULL,
    applies_to         TEXT NOT NULL CHECK (applies_to IN ('weapon','armor','shield','any')),
    bonus_equivalent   INTEGER,        -- +1, +2… (prix)
    flat_price_cp      INTEGER,
    effects            TEXT,           -- de résistance +1 : 'saves+1:resistance'
    description        TEXT,
    source TEXT, author TEXT, updated_at TEXT, content_hash TEXT
) STRICT;

-- =====================================================================
-- 2. PERSONNAGES (ids UUID v4)
-- =====================================================================

CREATE TABLE character (
    id                TEXT PRIMARY KEY,
    name              TEXT NOT NULL,
    player            TEXT,
    race_id           TEXT REFERENCES race(id),
    alignment         TEXT CHECK (alignment IN ('LB','NB','CB','LN','N','CN','LM','NM','CM')),
    deity             TEXT,
    size_override     TEXT,           -- NULL = taille de la race
    age               INTEGER,
    gender            TEXT,
    height            TEXT,
    weight            TEXT,
    -- caractéristiques : valeur tirée, avant race / niveaux / objets.
    -- La « valeur temporaire » de la fiche se calcule : base + character_modifier actifs.
    str_score         INTEGER NOT NULL DEFAULT 10,
    dex_score         INTEGER NOT NULL DEFAULT 10,
    con_score         INTEGER NOT NULL DEFAULT 10,
    int_score         INTEGER NOT NULL DEFAULT 10,
    wis_score         INTEGER NOT NULL DEFAULT 10,
    cha_score         INTEGER NOT NULL DEFAULT 10,
    hp_current        INTEGER,        -- PV max calculé (dés tirés + CON + effets)
    nonlethal_damage  INTEGER NOT NULL DEFAULT 0,
    action_points     INTEGER,        -- réserve de points d'action
    action_dice       TEXT,
    damage_reduction  TEXT,           -- « 5/argent » : saisie libre en v1
    immunities        TEXT,
    coins_cp INTEGER NOT NULL DEFAULT 0, coins_sp INTEGER NOT NULL DEFAULT 0,
    coins_gp INTEGER NOT NULL DEFAULT 0, coins_pp INTEGER NOT NULL DEFAULT 0,
    notes             TEXT,
    created_at        TEXT NOT NULL,
    updated_at        TEXT NOT NULL
) STRICT;

-- une ligne par niveau gagné : multiclassage, historique, PV tirés
CREATE TABLE character_level (
    character_id      TEXT NOT NULL REFERENCES character(id) ON DELETE CASCADE,
    level             INTEGER NOT NULL CHECK (level >= 1),   -- niveau global
    class_id          TEXT NOT NULL REFERENCES class(id),
    hp_roll           INTEGER NOT NULL,                      -- dé de vie de ce niveau (max au niveau 1)
    ability_increase  TEXT CHECK (ability_increase IN ('str','dex','con','int','wis','cha')),  -- niv. 4, 8, 12…
    PRIMARY KEY (character_id, level)
) STRICT;

CREATE TABLE character_skill (
    character_id  TEXT NOT NULL REFERENCES character(id) ON DELETE CASCADE,
    skill_id      TEXT NOT NULL REFERENCES skill(id),
    specialty     TEXT NOT NULL DEFAULT '',   -- Profession (marin) ; '' si sans objet
    ranks         REAL NOT NULL DEFAULT 0,    -- « degré de maîtrise » ; ,5 hors classe
    misc          INTEGER NOT NULL DEFAULT 0, -- « mod. divers » saisi à la main
    PRIMARY KEY (character_id, skill_id, specialty)
) STRICT;

-- dons choisis ; aptitudes de classe et traits raciaux seulement s'ils portent un choix
-- (Ennemi juré : orques, Style de combat : deux armes) — sinon ils se déduisent
CREATE TABLE character_feature (
    character_id  TEXT NOT NULL REFERENCES character(id) ON DELETE CASCADE,
    feature_id    TEXT NOT NULL REFERENCES feature(id),
    choice        TEXT NOT NULL DEFAULT '',   -- Arme de prédilection (épée longue)
    level_gained  INTEGER,
    origin        TEXT CHECK (origin IN ('level','class_bonus','race_bonus','other')),
    notes         TEXT,
    PRIMARY KEY (character_id, feature_id, choice)
) STRICT;

CREATE TABLE character_language (
    character_id  TEXT NOT NULL REFERENCES character(id) ON DELETE CASCADE,
    language_id   TEXT NOT NULL REFERENCES language(id),
    PRIMARY KEY (character_id, language_id)
) STRICT;

-- inventaire : équipement, armes et armures portées, munitions, récipients, gemmes, objets d'art
CREATE TABLE character_item (
    id              TEXT PRIMARY KEY,
    character_id    TEXT NOT NULL REFERENCES character(id) ON DELETE CASCADE,
    item_id         TEXT REFERENCES item(id),      -- NULL = objet libre, non référencé
    custom_name     TEXT,                          -- « Croc, épée longue +1 de feu »
    quantity        INTEGER NOT NULL DEFAULT 1,    -- munitions
    location        TEXT,                          -- « emplacement » : ceinture, dos…
    container_id    TEXT REFERENCES character_item(id) ON DELETE SET NULL,  -- dans quel récipient
    equipped        INTEGER NOT NULL DEFAULT 0 CHECK (equipped IN (0,1)),
    masterwork      INTEGER NOT NULL DEFAULT 0 CHECK (masterwork IN (0,1)),
    enhancement     INTEGER NOT NULL DEFAULT 0,    -- +1 … +5
    weight_kg       REAL,                          -- NULL = poids du référentiel
    value_cp        INTEGER,                       -- gemmes / objets d'art estimés
    notes           TEXT,
    sort_order      INTEGER
) STRICT;

CREATE TABLE character_item_property (
    character_item_id    TEXT NOT NULL REFERENCES character_item(id) ON DELETE CASCADE,
    special_property_id  TEXT NOT NULL REFERENCES special_property(id),
    PRIMARY KEY (character_item_id, special_property_id)
) STRICT;

-- par classe de lanceur du personnage (un multiclassé peut en avoir deux)
CREATE TABLE character_caster (
    character_id         TEXT NOT NULL REFERENCES character(id) ON DELETE CASCADE,
    class_id             TEXT NOT NULL REFERENCES class(id),
    specialty_school_id  TEXT REFERENCES spell_school(id),   -- école de prédilection
    PRIMARY KEY (character_id, class_id)
) STRICT;

CREATE TABLE character_forbidden_school (
    character_id  TEXT NOT NULL,
    class_id      TEXT NOT NULL,
    school_id     TEXT NOT NULL REFERENCES spell_school(id),
    PRIMARY KEY (character_id, class_id, school_id),
    FOREIGN KEY (character_id, class_id) REFERENCES character_caster(character_id, class_id) ON DELETE CASCADE
) STRICT;

-- sorts connus (grimoire du magicien, sorts de l'ensorceleur…) : la ligne existe = le sort est connu.
-- Inutile pour une classe à knows_all_spells = 1, qui connaît toute sa liste.
CREATE TABLE character_spell (
    character_id  TEXT NOT NULL,
    class_id      TEXT NOT NULL,
    spell_id      TEXT NOT NULL REFERENCES spell(id),
    PRIMARY KEY (character_id, class_id, spell_id),
    FOREIGN KEY (character_id, class_id) REFERENCES character_caster(character_id, class_id) ON DELETE CASCADE
) STRICT;

-- emplacements utilisés depuis le dernier repos, par niveau de sort.
-- Le nombre d'emplacements se calcule (class_spell_slots + sorts en bonus + école de prédilection) ;
-- seule l'utilisation se stocke. Ligne absente = rien d'utilisé ; le repos supprime les lignes.
CREATE TABLE character_spell_slot (
    character_id  TEXT NOT NULL,
    class_id      TEXT NOT NULL,
    spell_level   INTEGER NOT NULL CHECK (spell_level BETWEEN 0 AND 9),
    used          INTEGER NOT NULL DEFAULT 0 CHECK (used >= 0),
    PRIMARY KEY (character_id, class_id, spell_level),
    FOREIGN KEY (character_id, class_id) REFERENCES character_caster(character_id, class_id) ON DELETE CASCADE
) STRICT;

-- toutes les cases « mod. divers », « mod. temporaire », « modificateur particulier »
CREATE TABLE character_modifier (
    id            TEXT PRIMARY KEY,
    character_id  TEXT NOT NULL REFERENCES character(id) ON DELETE CASCADE,
    effects       TEXT NOT NULL,                 -- 'attack+1:morale, saves+1:morale [contre la terreur]'
    label         TEXT,                          -- « Bénédiction », « malus de fatigue »…
    active        INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1)),
    temporary     INTEGER NOT NULL DEFAULT 0 CHECK (temporary IN (0,1))
) STRICT;

CREATE INDEX idx_character_item_character ON character_item(character_id);
CREATE INDEX idx_character_modifier_character ON character_modifier(character_id);
CREATE INDEX idx_spell_class_level_class ON spell_class_level(class_id, level);
