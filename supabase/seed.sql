-- F5: fish domain data seed (species / variants / personality traits).
-- Spec: docs/specs/2026-08-30-f5-fish-domain-data.md
--
-- IMPORTANT: apply against the `postgres` database, NOT `_supabase`.
-- GoTrue (supabase-auth) lives in `postgres`; its migrations populate
-- `auth.uid()` / `auth.role()` RLS helpers there. _supabase has none
-- of those helpers, so the policies below would always deny. See
-- commits 60fa6545 (F3) and 422fd972 (F4) for the prior lessons.
--
-- Apply after the F3 + F4 migrations have run (those create the
-- profiles and tanks rows; F5 does not depend on them logically
-- but the spec recommends applying in order for clarity).
--
-- The F5 migration owns table definitions and RLS. This file is only the
-- reference catalogue and is safe to execute repeatedly after that migration.

-- ============================================================
-- personality_traits (4 reference rows, UUIDs consumed by F6 fish.traits)
-- ============================================================
insert into public.personality_traits
  (id, code, name_zh, name_en, description, behavior_hint)
values
  ('5f19d1f0-14d0-4e6a-9d0e-1bf389850001', 'bold',    '大胆', 'Bold',    '这条鱼对玩家的在场反应直接,靠近时游得更急,常浮到水面',         '{"swim_speed":"fast","surface_preference":"high","reaction_radius":"large"}'),
  ('5f19d1f0-14d0-4e6a-9d0e-1bf389850002', 'shy',     '害羞', 'Shy',     '这条鱼倾向躲在装饰物后,玩家靠近时游远',                          '{"swim_speed":"slow","surface_preference":"low","reaction_radius":"small"}'),
  ('5f19d1f0-14d0-4e6a-9d0e-1bf389850003', 'curious', '好奇', 'Curious', '这条鱼被移动的物体吸引,会主动游向光标或装饰',                 '{"swim_speed":"medium","surface_preference":"mid","reaction_radius":"large"}'),
  ('5f19d1f0-14d0-4e6a-9d0e-1bf389850004', 'lazy',    '慵懒', 'Lazy',    '这条鱼动得少,常停在缸中段,只在喂食时明显动',                    '{"swim_speed":"slow","surface_preference":"mid","reaction_radius":"small"}')
on conflict (code) do update set
  id = excluded.id,
  name_zh = excluded.name_zh,
  name_en = excluded.name_en,
  description = excluded.description,
  behavior_hint = excluded.behavior_hint;

-- ============================================================
-- fish_species (12 approved preset silhouettes)
-- ============================================================
insert into public.fish_species
  (id, common_name_zh, common_name_en, scientific_name, asset_base_path, preferred_temp_min, preferred_temp_max, growth_days_to_juvenile, growth_days_to_adult)
values
  ('goldfish', '金鱼',   'Goldfish',       'Carassius auratus',         'assets/fish/goldfish/', 18.0, 28.0,  7, 21),
  ('guppy',    '孔雀鱼', 'Guppy',          'Poecilia reticulata',       'assets/fish/guppy/',    22.0, 28.0,  7, 21),
  ('betta',    '斗鱼',   'Betta',          'Betta splendens',           'assets/fish/betta/',    24.0, 30.0,  7, 21),
  ('angel',    '神仙鱼', 'Angelfish',      'Pterophyllum scalare',      'assets/fish/angel/',    24.0, 30.0, 14, 42),
  ('koi',      '锦鲤',   'Koi',            'Cyprinus rubrofuscus',      'assets/fish/koi/',      16.0, 28.0, 14, 42),
  ('discus',   '七彩神仙', 'Discus',       'Symphysodon aequifasciatus','assets/fish/discus/',   26.0, 30.0, 14, 42),
  ('neon',     '霓虹灯鱼', 'Neon tetra',   'Paracheirodon innesi',      'assets/fish/neon/',     22.0, 28.0,  7, 21),
  ('zebra',    '斑马鱼', 'Zebrafish',      'Danio rerio',               'assets/fish/zebra/',    20.0, 28.0,  7, 21),
  ('swordtail','剑尾鱼', 'Swordtail',      'Xiphophorus hellerii',      'assets/fish/swordtail/',22.0, 28.0,  7, 21),
  ('molly',    '玛丽鱼', 'Molly',          'Poecilia sphenops',         'assets/fish/molly/',    22.0, 28.0,  7, 21),
  ('barb',     '虎皮鱼', 'Tiger barb',     'Puntigrus tetrazona',       'assets/fish/barb/',     22.0, 28.0,  7, 21),
  ('cory',     '鼠鱼',   'Corydoras',      'Corydoras paleatus',        'assets/fish/cory/',     20.0, 26.0,  7, 21)
on conflict (id) do update set
  common_name_zh = excluded.common_name_zh,
  common_name_en = excluded.common_name_en,
  scientific_name = excluded.scientific_name,
  asset_base_path = excluded.asset_base_path,
  preferred_temp_min = excluded.preferred_temp_min,
  preferred_temp_max = excluded.preferred_temp_max,
  growth_days_to_juvenile = excluded.growth_days_to_juvenile,
  growth_days_to_adult = excluded.growth_days_to_adult;

-- ============================================================
-- Remove three early catalogue placeholders that were replaced by approved
-- silhouettes. This stays harmless on a fresh database and keeps a re-seeded
-- development database aligned with the Flutter catalogue.
delete from public.fish_species where id in ('tropical', 'puffer', 'tetra');

-- fish_variants (3 colour treatments per species, 36 total)
-- ============================================================
insert into public.fish_variants
  (id, species_id, variant_label, color_hex, asset_filename)
values
  -- goldfish
  ('goldfish_classic', 'goldfish', '暖阳',   '#F49A4A', 'base.png'),
  ('goldfish_coral',   'goldfish', '珊瑚',   '#E8756F', 'base.png'),
  ('goldfish_moon',    'goldfish', '月光',   '#E7C77E', 'base.png'),
  -- guppy
  ('guppy_lagoon',     'guppy',    '潟湖',   '#59B8C5', 'base.png'),
  ('guppy_sunset',     'guppy',    '日落',   '#F08A65', 'base.png'),
  ('guppy_violet',     'guppy',    '鸢尾',   '#9D83C8', 'base.png'),
  -- betta
  ('betta_coral',      'betta',    '珊瑚',   '#E86F74', 'base.png'),
  ('betta_cobalt',     'betta',    '钴蓝',   '#477EBE', 'base.png'),
  ('betta_violet',     'betta',    '暮紫',   '#9773B9', 'base.png'),
  -- angel
  ('angel_silver',     'angel',    '银雾',   '#BBC9D0', 'base.png'),
  ('angel_gold',       'angel',    '浅金',   '#E4BE72', 'base.png'),
  ('angel_blue',       'angel',    '远海',   '#5F9EB7', 'base.png'),
  -- koi
  ('koi_kohaku',       'koi',      '红白',   '#E26F5B', 'base.png'),
  ('koi_sanke',        'koi',      '墨橙',   '#C68158', 'base.png'),
  ('koi_ochiba',       'koi',      '落叶',   '#A78C66', 'base.png'),
  -- discus
  ('discus_sunrise',   'discus',   '朝霞',   '#E98B65', 'base.png'),
  ('discus_ocean',     'discus',   '海蓝',   '#559BB8', 'base.png'),
  ('discus_rose',      'discus',   '玫瑰',   '#D77D93', 'base.png'),
  -- neon tetra
  ('neon_cyan',        'neon',     '青霓',   '#55C2C7', 'base.png'),
  ('neon_red',         'neon',     '赤霓',   '#DF6B6E', 'base.png'),
  ('neon_lime',        'neon',     '青柠',   '#8EBC72', 'base.png'),
  -- zebrafish
  ('zebra_blue',       'zebra',    '水蓝',   '#65A9C4', 'base.png'),
  ('zebra_gold',       'zebra',    '麦金',   '#D9AF62', 'base.png'),
  ('zebra_mint',       'zebra',    '薄荷',   '#71B59B', 'base.png'),
  -- swordtail
  ('swordtail_coral',  'swordtail','珊瑚',   '#E87969', 'base.png'),
  ('swordtail_amber',  'swordtail','琥珀',   '#D99B52', 'base.png'),
  ('swordtail_blue',   'swordtail','晴蓝',   '#5D9DBD', 'base.png'),
  -- molly
  ('molly_ink',        'molly',    '墨蓝',   '#496979', 'base.png'),
  ('molly_peach',      'molly',    '蜜桃',   '#E79A7D', 'base.png'),
  ('molly_mint',       'molly',    '青芽',   '#75AD91', 'base.png'),
  -- tiger barb
  ('barb_honey',       'barb',     '蜂蜜',   '#DDA65E', 'base.png'),
  ('barb_coral',       'barb',     '赤陶',   '#CE775D', 'base.png'),
  ('barb_green',       'barb',     '苔绿',   '#789B75', 'base.png'),
  -- corydoras
  ('cory_sand',        'cory',     '细沙',   '#BFA579', 'base.png'),
  ('cory_silver',      'cory',     '银灰',   '#9BAEB5', 'base.png'),
  ('cory_rose',        'cory',     '玫瑰沙', '#C9918B', 'base.png')
on conflict (id) do update set
  species_id = excluded.species_id,
  variant_label = excluded.variant_label,
  color_hex = excluded.color_hex,
  asset_filename = excluded.asset_filename;

-- Retained species had an earlier F5 palette. Remove those superseded rows
-- after the approved variants above have been upserted.
delete from public.fish_variants
where species_id in (
  'goldfish', 'guppy', 'betta', 'angel', 'koi', 'discus',
  'neon', 'zebra', 'swordtail', 'molly', 'barb', 'cory'
)
and asset_filename <> 'base.png';
