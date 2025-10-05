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

-- 105 Empresas (5 Fundadoras/Responsáveis + 100 Patrocinadoras)
-- NRO 1 a 5 para plataformas (garantido pelo TRUNCATE RESTART IDENTITY)
INSERT INTO empresa (nro, nome, nome_fantasia) VALUES
(1, 'Alphabet Inc.', 'Google'),
(2, 'Amazon.com, Inc.', 'Amazon'),
(3, 'Meta Platforms, Inc.', 'Meta'),
(4, 'Rumble Inc.', 'Rumble'),
(5, 'Stake.com', 'Kick')
ON CONFLICT (nro) DO UPDATE SET nome = EXCLUDED.nome, nome_fantasia = EXCLUDED.nome_fantasia;

-- 100 Empresas de Patrocínio (NRO 6 a 105)
INSERT INTO empresa (nro, nome, nome_fantasia)
SELECT
    n AS nro,
    'Patrocinador Genérico ' || LPAD(n::text, 3, '0') AS nome,
    'PAG_' || LPAD(n::text, 3, '0') AS nome_fantasia
FROM generate_series(6, 105) AS n
ON CONFLICT (nro) DO UPDATE SET nome = EXCLUDED.nome, nome_fantasia = EXCLUDED.nome_fantasia;

-- 5 Plataformas (NRO 1 a 5)
INSERT INTO plataforma (nro, nome, empresa_fundadora, empresa_responsavel, data_fund) VALUES
(1, 'YouTube', 1, 1, '2005-02-14'),
(2, 'Twitch', 2, 2, '2011-06-06'),
(3, 'Facebook Gaming', 3, 3, '2018-06-01'),
(4, 'Rumble', 4, 4, '2013-08-01'),
(5, 'Kick', 5, 5, '2022-12-06')
ON CONFLICT (nro) DO UPDATE SET nome = EXCLUDED.nome, empresa_fundadora = EXCLUDED.empresa_fundadora;

-- Associações Empresa-País (Exemplo)
INSERT INTO empresa_pais (nro_empresa, ddi_pais, id_nacional) VALUES
(1, '+1', 'US-123456789'), (1, '+55', 'BR-001'),
(6, '+1', 'US-777'), (7, '+55', 'BR-007')
ON CONFLICT (nro_empresa, ddi_pais) DO UPDATE SET id_nacional = EXCLUDED.id_nacional;


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
    MOD(n - 1, 5) + 1 AS nro_plataforma,
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

-- 500 Canais (Um para cada streamer - nro_canal é SERIAL)
INSERT INTO canal (nro_canal, nome, nro_plataforma, tipo, data_criacao, nick_streamer)
SELECT
    n AS nro_canal,
    'Canal_' || LPAD(n::text, 3, '0') AS nome,
    MOD(n - 1, 5) + 1 AS nro_plataforma,
    CASE MOD(n, 4)
        WHEN 0 THEN 'Jogos'
        WHEN 1 THEN 'Música'
        WHEN 2 THEN 'Notícias'
        ELSE 'Culinária'
    END AS tipo,
    ('2018-01-01'::DATE + (n * 5) * INTERVAL '1 day')::DATE AS data_criacao,
    'user_' || LPAD(n::text, 4, '0') AS nick_streamer
FROM generate_series(1, 500) AS n
ON CONFLICT (nro_canal) DO UPDATE SET nick_streamer = EXCLUDED.nick_streamer;


-- 3 Níveis para cada Canal (Total: 1500 níveis)
INSERT INTO nivel_canal (nro_canal, nivel, valor)
SELECT
    c.nro_canal, v.nivel, v.valor
FROM (
    SELECT n AS nro_canal FROM generate_series(1, 500) AS n
) AS c
CROSS JOIN (
    VALUES ('Bronze', 4.99), ('Prata', 9.99), ('Ouro', 24.99)
) AS v(nivel, valor)
ON CONFLICT (nro_canal, nivel) DO UPDATE SET valor = EXCLUDED.valor;


-- 1200 Inscrições
INSERT INTO inscricao (nro_canal, nick_membro, nivel)
SELECT
    nro_canal,
    'user_' || LPAD(membro::text, 4, '0') AS nick_membro,
    nivel
FROM (
    -- 500 membros (user_0501 a user_1000) se inscrevem em 1 canal
    SELECT
        n AS membro,
        MOD(n - 501, 500) + 1 AS nro_canal,
        'Prata' AS nivel
    FROM generate_series(501, 1000) AS n
    UNION ALL
    -- 500 streamers (user_0001 a user_0500) se inscrevem em 1 canal (diferente do próprio)
    SELECT
        n AS membro,
        MOD(n, 500) + 1 AS nro_canal,
        'Bronze' AS nivel
    FROM generate_series(1, 500) AS n
    UNION ALL
    -- 200 membros aleatórios (user_0001 a user_0200) se inscrevem em um segundo canal
    SELECT
        n AS membro,
        MOD(n + 100, 500) + 1 AS nro_canal,
        'Ouro' AS nivel
    FROM generate_series(1, 200) AS n
) AS t
ON CONFLICT (nro_canal, nick_membro) DO UPDATE SET nivel = EXCLUDED.nivel;


-- 200 Patrocínios (Empresas 6 a 105, 2 canais cada)
INSERT INTO patrocinio (nro_empresa, nro_canal, valor)
SELECT
    nro_empresa, nro_canal,
    (10000.00 + (nro_empresa * 50.00)) AS valor -- Valor variável
FROM (
    -- Patrocínio 1 (Empresas 6 a 105 nos canais 1 a 100)
    SELECT
        6 + MOD(n - 1, 100) AS nro_empresa,
        MOD(n - 1, 100) + 1 AS nro_canal
    FROM generate_series(1, 100) AS n
    UNION ALL
    -- Patrocínio 2 (Empresas 6 a 105 nos canais 101 a 200)
    SELECT
        6 + MOD(n - 1, 100) AS nro_empresa,
        MOD(n - 1, 100) + 101 AS nro_canal
    FROM generate_series(1, 100) AS n
) AS t
ON CONFLICT (nro_empresa, nro_canal) DO UPDATE SET valor = EXCLUDED.valor;


-- ######################################################################################
-- # 4. VÍDEOS E COMENTÁRIOS (200 Vídeos, 1000 Comentários)
-- ######################################################################################

-- 200 Vídeos (Nos primeiros 200 canais)
INSERT INTO video (id_video, nro_canal, titulo, dataH, tema, duracao)
SELECT
    n AS id_video,
    MOD(n - 1, 200) + 1 AS nro_canal,
    'Vídeo Teste ' || n AS titulo,
    NOW() - (n * INTERVAL '1 hour') AS dataH,
    CASE MOD(n, 3)
        WHEN 0 THEN 'Review'
        WHEN 1 THEN 'Gameplay'
        ELSE 'Tutorial'
    END AS tema,
    (MOD(n, 15) + 5) * INTERVAL '1 minute' AS duracao
FROM generate_series(1, 200) AS n
ON CONFLICT (nro_canal, titulo, dataH) DO NOTHING;

-- Participa (Streamer do canal participa do próprio vídeo)
INSERT INTO participa (id_video, nick_streamer)
SELECT
    v.id_video, c.nick_streamer
FROM video v
JOIN canal c ON v.nro_canal = c.nro_canal
ON CONFLICT (id_video, nick_streamer) DO NOTHING;

-- 1000 Comentários (Distribuídos em 100 vídeos - 10 comentários por vídeo)
INSERT INTO comentario (id_comentario, id_video, nick_usuario, seq, texto, dataH)
SELECT
    n AS id_comentario,
    MOD(n - 1, 100) + 1 AS id_video, -- Comentários nos Vídeos 1 a 100
    'user_' || LPAD((MOD(n - 1, 1000) + 1)::text, 4, '0') AS nick_usuario,
    (MOD(n - 1, 10) + 1) AS seq, -- Sequencial de 1 a 10 para cada vídeo/usuário
    'Comentário ' || n || ' sobre o vídeo ' || (MOD(n - 1, 100) + 1) AS texto,
    NOW() - (n * INTERVAL '10 minutes') AS dataH
FROM generate_series(1, 1000) AS n
ON CONFLICT (id_video, nick_usuario, seq) DO UPDATE SET texto = EXCLUDED.texto;


-- ######################################################################################
-- # 5. DOAÇÕES (300 Doações, 75 de cada tipo de pagamento)
-- ######################################################################################

-- 300 Doações (Associadas aos primeiros 300 comentários - id_comentario 1 a 300)
INSERT INTO doacao (id_doacao, id_comentario, valor, seq_pg, status)
SELECT
    n AS id_doacao,
    n AS id_comentario,
    (5.00 + (MOD(n, 10) * 0.5)) AS valor, -- Valor variável entre 5.00 e 9.50
    1 AS seq_pg,
    'Confirmada' AS status
FROM generate_series(1, 300) AS n
ON CONFLICT (id_comentario, seq_pg) DO UPDATE SET valor = EXCLUDED.valor;

-- Distribuição dos Tipos de Pagamento (300 doações / 4 tipos = 75 de cada)

-- Bitcoin (1 a 75)
INSERT INTO bitcoin (id_doacao, TxID)
SELECT
    n AS id_doacao,
    'TX_BTC_GEN_' || LPAD(n::text, 4, '0') AS TxID
FROM generate_series(1, 75) AS n
ON CONFLICT (id_doacao) DO UPDATE SET TxID = EXCLUDED.TxID;

-- PayPal (76 a 150)
INSERT INTO paypal (id_doacao, IdPayPal)
SELECT
    n AS id_doacao,
    'ID_PAYPAL_' || LPAD(n::text, 4, '0') AS IdPayPal
FROM generate_series(76, 150) AS n
ON CONFLICT (id_doacao) DO UPDATE SET IdPayPal = EXCLUDED.IdPayPal;

-- Cartão de Crédito (151 a 225)
INSERT INTO cartao_credito (id_doacao, nro, bandeira)
SELECT
    n AS id_doacao,
    LPAD(n::text, 20, '4') AS nro, -- Número fictício
    CASE MOD(n, 3)
        WHEN 0 THEN 'Visa'
        WHEN 1 THEN 'Mastercard'
        ELSE 'Elo'
    END AS bandeira
FROM generate_series(151, 225) AS n
ON CONFLICT (id_doacao) DO UPDATE SET nro = EXCLUDED.nro, bandeira = EXCLUDED.bandeira;

-- Mecanismo da Plataforma (226 a 300)
INSERT INTO mecanismo_plat (id_doacao, seq_plataforma)
SELECT
    n AS id_doacao,
    n - 225 AS seq_plataforma -- Sequencial de 1 a 75
FROM generate_series(226, 300) AS n
ON CONFLICT (id_doacao) DO UPDATE SET seq_plataforma = EXCLUDED.seq_plataforma;