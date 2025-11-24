-- ######################################################################################
-- # PREPARAÇÃO: CONFIGURAÇÃO DE ESQUEMA E TRUNCATE COM RESET DE SEQUÊNCIAS
-- ######################################################################################

-- Define o esquema
CREATE SCHEMA IF NOT EXISTS streamerdb;
SET search_path TO streamerdb;

-- Limpeza de dados com reset de sequências
TRUNCATE TABLE bitcoin, paypal, cartao_credito, mecanismo_plat, doacao, comentario, participa, video, inscricao, nivel_canal, patrocinio, canal, streamer_pais, plataforma_usuario, usuario, empresa_pais, plataforma, empresa, conversao, pais RESTART IDENTITY CASCADE;

-- ######################################################################################
-- # 1. DADOS BASE: CONVERSAO, PAIS, EMPRESA E PLATAFORMA (5 de cada)
-- ######################################################################################

-- 5 Moedas (conversao)
INSERT INTO conversao (moeda, nome, fator_conversao_dolar) VALUES
('USD', 'Dólar Americano', 1.0000),
('BRL', 'Real Brasileiro', 0.2000),
('EUR', 'Euro', 1.1000),
('JPY', 'Iene Japonês', 0.0070),
('GBP', 'Libra Esterlina', 1.2500)
ON CONFLICT (moeda) DO UPDATE SET nome = EXCLUDED.nome, fator_conversao_dolar = EXCLUDED.fator_conversao_dolar;

-- 5 Países
INSERT INTO pais (DDI, nome, moeda) VALUES
('+1', 'Estados Unidos', 'USD'),
('+55', 'Brasil', 'BRL'),
('+44', 'Reino Unido', 'GBP'),
('+81', 'Japão', 'JPY'),
('+33', 'França', 'EUR')
ON CONFLICT (DDI) DO UPDATE SET nome = EXCLUDED.nome, moeda = EXCLUDED.moeda;

-- Cadastro Empresas (5 Fundadoras/Responsáveis + 500 Patrocinadoras)
-- NRO 1 a 5 para plataformas (garantido pelo TRUNCATE RESTART IDENTITY)
INSERT INTO empresa (tax_id, nome, nome_fantasia) VALUES
(1, 'Alphabet Inc.', 'Google'),
(2, 'Amazon.com, Inc.', 'Amazon'),
(3, 'Meta Platforms, Inc.', 'Meta'),
(4, 'Rumble Inc.', 'Rumble'),
(5, 'Stake.com', 'Kick')
ON CONFLICT (tax_id) DO UPDATE SET nome = EXCLUDED.nome, nome_fantasia = EXCLUDED.nome_fantasia;

-- 500 Empresas de Patrocínio (NRO 6 a 505)
INSERT INTO empresa (tax_id, nome, nome_fantasia)
SELECT
    n AS tax_id,
    'Patrocinador Genérico ' || LPAD(n::text, 3, '0') AS nome,
    'PAG_' || LPAD(n::text, 3, '0') AS nome_fantasia
FROM generate_series(6, 505) AS n
ON CONFLICT (tax_id) DO UPDATE SET nome = EXCLUDED.nome, nome_fantasia = EXCLUDED.nome_fantasia;

-- 5 Plataformas (NRO 1 a 5)
INSERT INTO plataforma (nro, nome, empresa_fundadora, empresa_responsavel, data_fund) VALUES
(1, 'YouTube', 1, 1, '2005-02-14'),
(2, 'Twitch', 2, 2, '2011-06-06'),
(3, 'Facebook Gaming', 3, 3, '2018-06-01'),
(4, 'Rumble', 4, 4, '2013-08-01'),
(5, 'Kick', 5, 5, '2022-12-06')
ON CONFLICT (nro) DO UPDATE SET nome = EXCLUDED.nome, empresa_fundadora = EXCLUDED.empresa_fundadora;

-- Associações Empresa-País
INSERT INTO empresa_pais (empresa_tax_id, ddi_pais, id_nacional) VALUES
(1, '+1', 'US-123456789'), (1, '+55', 'BR-001'),
(6, '+1', 'US-777'), (7, '+55', 'BR-007')
ON CONFLICT (empresa_tax_id, ddi_pais) DO UPDATE SET id_nacional = EXCLUDED.id_nacional;


-- ######################################################################################
-- # 2. USUÁRIOS E STREAMERS (1000 usuários, 500 streamers)
-- ######################################################################################

-- 1000 Usuários
INSERT INTO usuario (nick, email, data_nasc, pais_residencia)
SELECT
    'user_' || LPAD(n::text, 4, '0') AS nick,
    'user_' || LPAD(n::text, 4, '0') || '@email.com' AS email,
    ('1980-01-01'::DATE + (n * 3) * INTERVAL '1 day')::DATE AS data_nasc,
    CASE MOD(n, 5)
        WHEN 0 THEN '+1'
        WHEN 1 THEN '+55'
        WHEN 2 THEN '+44'
        WHEN 3 THEN '+81'
        ELSE '+33'
    END AS pais_residencia
FROM generate_series(1, 1000) AS n
ON CONFLICT (nick) DO UPDATE SET email = EXCLUDED.email, pais_residencia = EXCLUDED.pais_residencia;

-- Plataforma_Usuario (1000 usuários)
INSERT INTO plataforma_usuario (nro_plataforma, nick_usuario, nro_usuario)
SELECT
    floor(random() * 5) + 1 AS nro_plataforma,
    'user_' || LPAD(n::text, 4, '0') AS nick_usuario,
    'P' || (MOD(n - 1, 5) + 1) || '_' || LPAD(n::text, 4, '0') AS nro_usuario
FROM generate_series(1, 1000) AS n
ON CONFLICT (nro_plataforma, nick_usuario) DO UPDATE SET nro_usuario = EXCLUDED.nro_usuario;

-- 500 Streamers (Os primeiros 500 usuários)
INSERT INTO streamer_pais (nick_streamer, ddi_pais)
SELECT
    u.nick AS nick_streamer,
    u.pais_residencia AS ddi_pais
FROM usuario u
WHERE u.nick IN (SELECT 'user_' || LPAD(n::text, 4, '0') FROM generate_series(1, 500) AS n)
ON CONFLICT (nick_streamer, ddi_pais) DO NOTHING;


-- ######################################################################################
-- # 3. CANAIS E INSCRIÇÕES (500 Canais, 1500 Níveis, 1200 Inscrições, 200 Patrocínios)
-- ######################################################################################

-- 500 Canais (Um para cada streamer - id_canal é SERIAL)
INSERT INTO canal (id_canal, nome, nro_plataforma, tipo, data_criacao, nick_streamer)
SELECT
    gen_random_uuid() AS id_canal,
    'Canal_' || LPAD(n::text, 3, '0') AS nome,
    MOD(n - 1, 5) + 1 AS nro_plataforma,
    CASE MOD(n, 3)
        WHEN 0 THEN 'privado'
        WHEN 1 THEN 'publico'
        ELSE 'misto'
    END AS tipo,
    ('2018-01-01'::DATE + (n * 5) * INTERVAL '1 day')::DATE AS data_criacao,
    'user_' || LPAD(n::text, 4, '0') AS nick_streamer
FROM generate_series(1, 500) AS n
ON CONFLICT (id_canal) DO UPDATE SET nick_streamer = EXCLUDED.nick_streamer;


-- 3 Níveis para cada Canal (Total: 1500 níveis)
INSERT INTO nivel_canal (id_canal, nivel, valor)
SELECT
    c.id_canal, v.nivel, v.valor
FROM (
    select id_canal FROM canal
) AS c
CROSS JOIN (
    VALUES ('Bronze', 4.99), ('Prata', 9.99), ('Ouro', 24.99)
) AS v(nivel, valor)
ON CONFLICT (id_canal, nivel) DO UPDATE SET valor = EXCLUDED.valor;


-- 1200 Inscrições (mapeando números aos UUID reais dos canais)
WITH canal_index AS (
    SELECT id_canal, row_number() OVER (ORDER BY nome) AS canal_seq
    FROM canal
)
INSERT INTO inscricao (id_canal, nick_membro, nivel)
SELECT
    ci.id_canal,
    'user_' || LPAD(membro::text, 4, '0') AS nick_membro,
    nivel
FROM (
    -- 500 membros (user_0501 a user_1000) se inscrevem em 1 canal
    SELECT
        n AS membro,
        MOD(n - 501, 500) + 1 AS canal_seq_int,
        'Prata' AS nivel
    FROM generate_series(501, 1000) AS n
    UNION ALL
    -- 500 streamers (user_0001 a user_0500) se inscrevem em 1 canal (diferente do próprio)
    SELECT
        n AS membro,
        MOD(n, 500) + 1 AS canal_seq_int,
        'Bronze' AS nivel
    FROM generate_series(1, 500) AS n
    UNION ALL
    -- 200 membros aleatórios (user_0001 a user_0200) se inscrevem em um segundo canal
    SELECT
        n AS membro,
        MOD(n + 100, 500) + 1 AS canal_seq_int,
        'Ouro' AS nivel
    FROM generate_series(1, 200) AS n
) AS t
JOIN canal_index ci ON ci.canal_seq = t.canal_seq_int
ON CONFLICT (id_canal, nick_membro) DO UPDATE SET nivel = EXCLUDED.nivel;


-- 200 Patrocínios (Empresas 6 a 105, 2 canais cada) usando mapeamento para UUID dos canais
WITH canal_index AS (
    SELECT id_canal, row_number() OVER (ORDER BY nome) AS canal_seq
    FROM canal
), patrocinio_base AS (
    -- Conjunto 1: empresas 6..105 nos canais 1..100
    SELECT
        6 + ((n - 1) % 100) AS empresa_tax_id,
        ((n - 1) % 100) + 1 AS canal_seq_int
    FROM generate_series(1, 100) AS n
    UNION ALL
    -- Conjunto 2: mesmas empresas nos canais 101..200
    SELECT
        6 + ((n - 1) % 100) AS empresa_tax_id,
        ((n - 1) % 100) + 101 AS canal_seq_int
    FROM generate_series(1, 100) AS n
)
INSERT INTO patrocinio (empresa_tax_id, id_canal, valor)
SELECT
    pb.empresa_tax_id,
    ci.id_canal,
    (10000.00 + (pb.empresa_tax_id * 50.00)) AS valor
FROM patrocinio_base pb
JOIN canal_index ci ON ci.canal_seq = pb.canal_seq_int
ON CONFLICT (empresa_tax_id, id_canal) DO UPDATE SET valor = EXCLUDED.valor;


-- ######################################################################################
-- # 4. VÍDEOS E COMENTÁRIOS (200 Vídeos, 1000 Comentários)
-- ######################################################################################

-- 5000 Vídeos (UUIDs para id_video e mapeamento de canais via índice)
WITH canal_index AS (
    SELECT id_canal, row_number() OVER (ORDER BY nome) AS canal_seq
    FROM canal
)
INSERT INTO video (id_video, id_canal, titulo, dataH, tema, duracao, visu_total)
SELECT
    gen_random_uuid() AS id_video,
    ci.id_canal,
    'Vídeo Teste ' || n AS titulo,
    NOW() - (n * INTERVAL '1 hour') AS dataH,
    CASE MOD(n, 3)
        WHEN 0 THEN 'Review'
        WHEN 1 THEN 'Gameplay'
        ELSE 'Tutorial'
    END AS tema,
    (MOD(n, 15) + 5) * INTERVAL '1 minute' AS duracao,
    floor(random() * 90000) AS visu_total
FROM generate_series(1, 5000) AS n
JOIN canal_index ci ON ci.canal_seq = ((n - 1) % 500) + 1
ON CONFLICT (id_canal, titulo, dataH) DO NOTHING;

-- Participa (Streamer do canal participa do próprio vídeo)
INSERT INTO participa (id_video, id_canal, nick_streamer)
SELECT
    v.id_video, v.id_canal, c.nick_streamer
FROM video v
JOIN canal c ON v.id_canal = c.id_canal
ON CONFLICT (id_video, id_canal, nick_streamer) DO NOTHING;

-- 1000 Comentários (100 vídeos, 10 por vídeo) usando mapeamento para PK composta
WITH video_index AS (
    SELECT id_video, id_canal, row_number() OVER (ORDER BY dataH DESC) AS vid_seq
    FROM video
)
INSERT INTO comentario (id_comentario, id_video, id_canal, nick_usuario, seq, texto, dataH)
SELECT
    gen_random_uuid() AS id_comentario,
    vi.id_video,
    vi.id_canal,
    'user_' || LPAD(((MOD(n - 1, 1000) + 1))::text, 4, '0') AS nick_usuario,
    (MOD(n - 1, 10) + 1) AS seq,
    'Comentário ' || n || ' sobre o vídeo ' || vi.vid_seq AS texto,
    NOW() - (n * INTERVAL '10 minutes') AS dataH
FROM generate_series(1, 1000) AS n
JOIN video_index vi ON vi.vid_seq = ((n - 1) % 100) + 1
ON CONFLICT (id_video, id_canal, nick_usuario, seq) DO UPDATE SET texto = EXCLUDED.texto;


-- ######################################################################################
-- # 5. DOAÇÕES (300 Doações, 75 de cada tipo de pagamento)
-- ######################################################################################

START TRANSACTION;


-- ######################################################################################
-- # 5. DOAÇÕES (300 Doações, 75 de cada tipo de pagamento)
-- ######################################################################################

WITH
comentario_index AS (
    SELECT id_canal, id_video, id_comentario, row_number() OVER (ORDER BY dataH DESC) AS com_seq
    FROM comentario
),
doacao_insert AS (
    INSERT INTO doacao (id_canal, id_video, id_comentario, id_doacao, valor, seq_pg, status)
    SELECT
        ci.id_canal,
        ci.id_video,
        ci.id_comentario,
        gen_random_uuid() AS id_doacao,
        (5.00 + (MOD(ci.com_seq, 10) * 0.5)) AS valor,
        1 AS seq_pg,
        CASE WHEN random() < 0.5 THEN 'Confirmada' ELSE 'Lida' END AS status
    FROM comentario_index ci
    WHERE ci.com_seq <= 300
    RETURNING id_canal, id_video, id_comentario, id_doacao
),
doacao_classificada AS (
    SELECT d.*, row_number() OVER () AS rn
    FROM doacao_insert d
),
btc AS (
    INSERT INTO bitcoin (id_canal, id_video, id_comentario, id_doacao, TxID)
    SELECT id_canal, id_video, id_comentario, id_doacao, 'TX_BTC_GEN_' || LEFT(id_doacao::text, 8)
    FROM doacao_classificada WHERE rn BETWEEN 1 AND 75
    RETURNING 1
),
pp AS (
    INSERT INTO paypal (id_canal, id_video, id_comentario, id_doacao, IdPayPal)
    SELECT id_canal, id_video, id_comentario, id_doacao, 'ID_PAYPAL_' || LEFT(id_doacao::text, 8)
    FROM doacao_classificada WHERE rn BETWEEN 76 AND 150
    RETURNING 1
),
cc AS (
    INSERT INTO cartao_credito (id_canal, id_video, id_comentario, id_doacao, nro, bandeira)
    SELECT id_canal, id_video, id_comentario, id_doacao,
           LEFT(id_doacao::text, 16) AS nro,
           CASE MOD(rn, 3)
               WHEN 0 THEN 'Visa'
               WHEN 1 THEN 'Mastercard'
               ELSE 'Elo' END AS bandeira
    FROM doacao_classificada WHERE rn BETWEEN 151 AND 225
    RETURNING 1
),
plat AS (
    INSERT INTO mecanismo_plat (id_canal, id_video, id_comentario, id_doacao, seq_plataforma)
    SELECT id_canal, id_video, id_comentario, id_doacao, (rn - 225)
    FROM doacao_classificada WHERE rn BETWEEN 226 AND 300
    RETURNING 1
)
SELECT 1;
COMMIT;

REFRESH MATERIALIZED VIEW MV_DOACAO_TOTAL_CANAL;
REFRESH MATERIALIZED VIEW MV_FATURAMENTO_TOP_CANAIS;