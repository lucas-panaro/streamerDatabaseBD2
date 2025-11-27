CREATE SCHEMA IF NOT EXISTS streamerdb;
SET search_path TO streamerdb;

TRUNCATE TABLE 
    bitcoin, paypal, cartao_credito, mecanismo_plat, doacao, 
    comentario, participa, video, inscricao, nivel_canal, 
    patrocinio, canal, streamer_pais, plataforma_usuario, 
    usuario, empresa_pais, plataforma, empresa, conversao, pais,
    log_video_removido
RESTART IDENTITY CASCADE;

INSERT INTO conversao (moeda, nome, fator_conversao_dolar) VALUES
('USD', 'Dólar Americano', 1.0000),
('BRL', 'Real Brasileiro', 0.2000),
('EUR', 'Euro', 1.1000),
('JPY', 'Iene Japonês', 0.0070),
('GBP', 'Libra Esterlina', 1.2500)
ON CONFLICT (moeda) DO NOTHING;

INSERT INTO pais (DDI, nome, moeda) VALUES
('+1', 'Estados Unidos', 'USD'),
('+55', 'Brasil', 'BRL'),
('+44', 'Reino Unido', 'GBP'),
('+81', 'Japão', 'JPY'),
('+33', 'França', 'EUR')
ON CONFLICT (DDI) DO NOTHING;

CREATE OR REPLACE FUNCTION fn_inserir_empresa(_nome VARCHAR, _nome_fantasia VARCHAR, _tax_id VARCHAR, _ddi_pais VARCHAR, _id_nacional VARCHAR)
RETURNS VOID AS $$
DECLARE
    _id_empresa UUID := gen_random_uuid();
BEGIN
    INSERT INTO empresa (id_empresa, tax_id, nome, nome_fantasia)
    VALUES (_id_empresa, _tax_id, _nome, _nome_fantasia)
    ON CONFLICT (tax_id) DO NOTHING;

    SELECT id_empresa INTO _id_empresa FROM empresa WHERE tax_id = _tax_id;

    INSERT INTO empresa_pais (id_empresa, ddi_pais, id_nacional)
    VALUES (_id_empresa, _ddi_pais, _id_nacional)
    ON CONFLICT (id_empresa, ddi_pais) DO NOTHING;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_popular_empresas_patrocinio() RETURNS VOID AS $$
DECLARE
    n INT;
    v_tax_id TEXT;
    v_nome TEXT;
    v_nome_fantasia TEXT;
BEGIN
    FOR n IN 6..1505 LOOP
        v_nome := 'Patrocinador Genérico ' || LPAD(n::text, 3, '0');
        v_nome_fantasia := 'PAG_' || LPAD(n::text, 3, '0');
        v_tax_id := n::text;

        PERFORM fn_inserir_empresa(
            v_nome,
            v_nome_fantasia,
            v_tax_id,
            (SELECT ddi FROM pais ORDER BY random() LIMIT 1),
            'GEN-' || LPAD(n::text, 6, '0')
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_popular_plataforma(_empresa_fundadora_tax_id varchar, _empresa_responsavel_tax_id varchar, _nome_plataforma varchar, _data_fundacao date) RETURNS VOID AS $$
DECLARE
    _id_empresa_fundadora UUID;
    _id_empresa_responsavel UUID;
BEGIN

    SELECT id_empresa INTO _id_empresa_fundadora FROM empresa WHERE tax_id = _empresa_fundadora_tax_id;
    SELECT id_empresa INTO _id_empresa_responsavel FROM empresa WHERE tax_id = _empresa_responsavel_tax_id;

    INSERT INTO plataforma (id_plataforma, nome, empresa_fundadora, empresa_responsavel, data_fund)
    VALUES (gen_random_uuid(), _nome_plataforma, _id_empresa_fundadora, _id_empresa_responsavel, _data_fundacao)
    ON CONFLICT (nome) DO NOTHING;

END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_inserir_plataforma_usuario(_nick VARCHAR, _email VARCHAR, _data_nasc DATE, _pais_residencia VARCHAR, _nome_plataforma VARCHAR) RETURNS VOID AS $$
DECLARE
    _id_usuario UUID;
    _id_plataforma UUID;
BEGIN

    INSERT INTO usuario (id_usuario, nick, email, data_nasc, pais_residencia)
    VALUES (gen_random_uuid(), _nick, _email, _data_nasc, _pais_residencia)
    ON CONFLICT DO NOTHING;
    
    SELECT id_usuario INTO _id_usuario FROM usuario WHERE email = _email;
    SELECT id_plataforma INTO _id_plataforma FROM plataforma WHERE nome = _nome_plataforma;

    INSERT INTO plataforma_usuario (id_plataforma, id_usuario) 
    VALUES (_id_plataforma, _id_usuario)
    ON CONFLICT (id_plataforma, id_usuario) DO NOTHING;
    
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_popular_plataforma_usuario() RETURNS VOID AS $$
BEGIN
    FOR n IN 1..3000 LOOP
        PERFORM fn_inserir_plataforma_usuario(
            'user_' || LPAD(n::text, 4, '0'),
            'user_' || LPAD(n::text, 4, '0') || '@email.com',
            ('1990-01-01'::DATE + (n * 2) * INTERVAL '1 day')::DATE,
            (SELECT ddi FROM pais ORDER BY random() LIMIT 1),
            (SELECT nome FROM plataforma ORDER BY random() LIMIT 1)
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_inserir_streammer(_nick VARCHAR, _ddi_pais_residencia VARCHAR, _nro_passaporte VARCHAR) RETURNS VOID AS $$
DECLARE
    _id_usuario UUID;
BEGIN
    SELECT id_usuario INTO _id_usuario FROM usuario WHERE nick = _nick;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Usuário com nick "%" não encontrado.', _nick;
    END IF;

    INSERT INTO streamer_pais (id_usuario, ddi_pais) 
    VALUES (_id_usuario, _ddi_pais_residencia)
    ON CONFLICT (id_usuario, ddi_pais) DO NOTHING;
    
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_popular_streammer_pais() RETURNS VOID AS $$
BEGIN
    FOR n IN 1..1000 LOOP
        PERFORM fn_inserir_streammer(
            (SELECT nick FROM usuario ORDER BY random() LIMIT 1),
            (SELECT ddi FROM pais ORDER BY random() LIMIT 1),
            'PASS-' || LPAD(n::text, 6, '0')
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_inserir_canal(_nome VARCHAR, _nome_plataforma VARCHAR, _tipo VARCHAR, _data_criacao DATE, _nick_streamer VARCHAR) RETURNS VOID AS $$
BEGIN
    INSERT INTO canal (id_canal, id_plataforma, id_usuario, nome, tipo, data_criacao)
    VALUES (
        gen_random_uuid(),
        (SELECT id_plataforma FROM plataforma WHERE nome = _nome_plataforma),
        (SELECT id_usuario FROM usuario WHERE nick = _nick_streamer),
        _nome,
        _tipo,
        _data_criacao
    )
    ON CONFLICT (nome, id_plataforma) DO NOTHING;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_popular_canais() RETURNS VOID AS $$
BEGIN
    FOR n IN 1..3000 LOOP
        PERFORM fn_inserir_canal(
            'Canal_' || LPAD(n::text, 3, '0'),
            (SELECT nome FROM plataforma ORDER BY random() LIMIT 1),
            CASE MOD(n, 3)
                WHEN 0 THEN 'privado'
                WHEN 1 THEN 'publico'
                ELSE 'misto'
            END,
            ('2020-01-01'::DATE + (n * 3) * INTERVAL '1 day')::DATE,
            (SELECT nick FROM streamer_pais
            left join usuario on usuario.id_usuario = streamer_pais.id_usuario
            ORDER BY random() LIMIT 1)
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_inserir_patrocinio(_nome_plataforma VARCHAR, _nome_canal VARCHAR, _nome_empresa VARCHAR, _valor NUMERIC) RETURNS VOID AS $$
DECLARE
    _id_plataforma UUID;
    _id_canal UUID;
    _id_empresa UUID;
BEGIN
    SELECT id_plataforma INTO _id_plataforma FROM plataforma WHERE nome = _nome_plataforma;
    SELECT id_canal INTO _id_canal FROM canal WHERE nome = _nome_canal AND id_plataforma = _id_plataforma;
    SELECT id_empresa INTO _id_empresa FROM empresa WHERE nome = _nome_empresa;
    INSERT INTO patrocinio (id_plataforma, id_canal, id_empresa, valor)
    VALUES (
        _id_plataforma,
        _id_canal,
        _id_empresa,
        _valor
    )
    ON CONFLICT (id_plataforma, id_canal, id_empresa) DO NOTHING;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_popular_patrocinio() RETURNS VOID AS $$
DECLARE
    _nome_plataforma varchar;
    _nome_canal varchar;
    _nome_empresa varchar;
BEGIN
    FOR n IN 1..1000 LOOP
        SELECT plataforma.nome, canal.nome INTO _nome_plataforma, _nome_canal
        FROM canal 
        left join plataforma on plataforma.id_plataforma = canal.id_plataforma 
        ORDER BY random() LIMIT 1;

        SELECT nome INTO _nome_empresa FROM empresa ORDER BY random() LIMIT 1;
        PERFORM fn_inserir_patrocinio(
            _nome_plataforma,
            _nome_canal,
            _nome_empresa,
            (5000.00 + (n * 10.00))
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION fn_inserir_nivel_canal(_nome_plataforma VARCHAR, _nome_canal VARCHAR, _nivel VARCHAR, _valor NUMERIC) RETURNS VOID AS $$
DECLARE
    _id_plataforma UUID;
    _id_canal UUID;
BEGIN
    SELECT id_plataforma INTO _id_plataforma FROM plataforma WHERE nome = _nome_plataforma;
    SELECT id_canal INTO _id_canal FROM canal WHERE nome = _nome_canal AND id_plataforma = _id_plataforma;

    INSERT INTO nivel_canal (id_plataforma, id_canal, nivel, valor)
    VALUES (
        _id_plataforma,
        _id_canal,
        _nivel,
        _valor
    )
    ON CONFLICT (id_plataforma, id_canal, nivel) DO NOTHING;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_popular_nivel_canal() RETURNS VOID AS $$
DECLARE
    _nome_plataforma varchar;
    _nome_canal varchar;
BEGIN
    FOR n IN 1..1000 LOOP
        SELECT plataforma.nome, canal.nome INTO _nome_plataforma, _nome_canal 
        FROM canal left join plataforma on plataforma.id_plataforma = canal.id_plataforma ORDER BY random() LIMIT 1;
        PERFORM fn_inserir_nivel_canal(
            _nome_plataforma,
            _nome_canal,
            CASE MOD(n, 3)
                WHEN 0 THEN 'Bronze'
                WHEN 1 THEN 'Prata'
                ELSE 'Ouro'
            END,
            CASE MOD(n, 3)
                WHEN 0 THEN 4.99
                WHEN 1 THEN 9.99
                ELSE 24.99
            END
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_inserir_inscricao(_nome_plataforma VARCHAR, _nome_canal VARCHAR, _nick_usuario VARCHAR, _nivel VARCHAR) RETURNS VOID AS $$
DECLARE
    _id_plataforma UUID;
    _id_canal UUID;
    _id_usuario UUID;
BEGIN
    SELECT id_plataforma INTO _id_plataforma FROM plataforma WHERE nome = _nome_plataforma;
    SELECT id_canal INTO _id_canal FROM canal WHERE nome = _nome_canal AND id_plataforma = _id_plataforma;
    SELECT id_usuario INTO _id_usuario FROM usuario WHERE nick = _nick_usuario;

    INSERT INTO inscricao (id_plataforma, id_canal, id_usuario, nivel)
    VALUES (
        _id_plataforma,
        _id_canal,
        _id_usuario,
        _nivel
    )
    ON CONFLICT (id_plataforma, id_canal, id_usuario, nivel) DO NOTHING;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_popular_inscricao() RETURNS VOID AS $$
DECLARE
    _nome_plataforma varchar;
    _nome_canal varchar;
    _nick_usuario varchar;
    _nivel varchar;
BEGIN
    FOR n IN 1..1000 LOOP
        SELECT plataforma.nome, canal.nome, nivel INTO _nome_plataforma, _nome_canal, _nivel
        FROM nivel_canal 
        left join plataforma on plataforma.id_plataforma = nivel_canal.id_plataforma 
        left join canal on canal.id_canal = nivel_canal.id_canal
        ORDER BY random() LIMIT 1;

        SELECT nick INTO _nick_usuario FROM usuario ORDER BY random() LIMIT 1;
        PERFORM fn_inserir_inscricao(
            _nome_plataforma,
            _nome_canal,
            _nick_usuario,
            _nivel
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_inserir_video(_nome_plataforma VARCHAR, _nome_canal VARCHAR, _titulo VARCHAR, _datah timestamp, _tema VARCHAR, _duracao INTERVAL) RETURNS VOID AS $$
DECLARE
    _id_plataforma UUID;
    _id_canal UUID;
BEGIN
    SELECT id_plataforma INTO _id_plataforma FROM plataforma WHERE nome = _nome_plataforma;
    SELECT id_canal INTO _id_canal FROM canal WHERE nome = _nome_canal AND id_plataforma = _id_plataforma;

    INSERT INTO video (id_plataforma, id_canal, id_video, titulo, datah, tema, duracao)
    VALUES (
        _id_plataforma,
        _id_canal,
        gen_random_uuid(),
        _titulo, 
        _datah, 
        _tema, 
        _duracao
    )
    ON CONFLICT (id_plataforma, id_canal, titulo, datah) DO NOTHING;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_popular_video() RETURNS VOID AS $$
DECLARE
    _nome_plataforma varchar;
    _nome_canal varchar;
BEGIN
    FOR n IN 1..5000 LOOP
        SELECT p.nome, c.nome 
        INTO _nome_plataforma, _nome_canal
        FROM canal c
        INNER JOIN plataforma p ON p.id_plataforma = c.id_plataforma 
        ORDER BY random() 
        LIMIT 1;

        PERFORM fn_inserir_video(
            _nome_plataforma,
            _nome_canal,
            'Vídeo Teste ' || n,
            NOW()::timestamp,
            CASE MOD(n, 3)
                WHEN 0 THEN 'Review'
                WHEN 1 THEN 'Gameplay'
                ELSE 'Tutorial'
            END,
            (MOD(n, 15) + 5) * INTERVAL '1 minute'
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION fn_inserir_participacao(_nome_plataforma VARCHAR, _nome_canal VARCHAR, _titulo VARCHAR, _datah timestamp, _nick_streamer VARCHAR) RETURNS VOID AS $$
DECLARE
    _id_plataforma UUID;
    _id_canal UUID;
    _id_video UUID;
    _id_streamer UUID;
BEGIN
    SELECT id_plataforma INTO _id_plataforma FROM plataforma WHERE nome = _nome_plataforma;
    SELECT id_canal INTO _id_canal FROM canal WHERE nome = _nome_canal AND id_plataforma = _id_plataforma;
    SELECT id_usuario INTO _id_streamer FROM usuario WHERE nick = _nick_streamer;
    SELECT id_video INTO _id_video FROM video WHERE id_plataforma = _id_plataforma AND id_canal = _id_canal AND titulo = _titulo AND datah = _datah;

    INSERT INTO participa (id_plataforma, id_canal, id_video, id_usuario)
    VALUES (
        _id_plataforma,
        _id_canal,
        _id_video,
        _id_streamer
    )
    ON CONFLICT (id_plataforma, id_canal, id_video, id_usuario) DO NOTHING;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_popular_participacao() RETURNS VOID AS $$
DECLARE
    _nome_plataforma varchar;
    _nome_canal varchar;
    _titulo varchar;
    _datah timestamp;
    _nick_streamer varchar;
BEGIN
    FOR n IN 1..1000 LOOP
        SELECT p.nome, c.nome, v.titulo, v.datah
        INTO _nome_plataforma, _nome_canal, _titulo, _datah
        FROM video v
        INNER JOIN plataforma p ON p.id_plataforma = v.id_plataforma 
        INNER JOIN canal c ON c.id_canal = v.id_canal
        ORDER BY random() 
        LIMIT 1;

        SELECT u.nick INTO _nick_streamer
        FROM streamer_pais sp
        INNER JOIN usuario u ON u.id_usuario = sp.id_usuario
        ORDER BY random() 
        LIMIT 1;

        PERFORM fn_inserir_participacao(
            _nome_plataforma,
            _nome_canal,
            _titulo,
            _datah,
            _nick_streamer
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION fn_inserir_comentario(_nome_plataforma VARCHAR, _nome_canal VARCHAR, _titulo VARCHAR, _texto text, _datah timestamp, _nick_usuario VARCHAR) RETURNS VOID AS $$
DECLARE
    _id_plataforma UUID;
    _id_canal UUID;
    _id_video UUID;
    _id_usuario UUID;
BEGIN
    SELECT id_plataforma INTO _id_plataforma FROM plataforma WHERE nome = _nome_plataforma;
    SELECT id_canal INTO _id_canal FROM canal WHERE nome = _nome_canal AND id_plataforma = _id_plataforma;
    SELECT id_usuario INTO _id_usuario FROM usuario WHERE nick = _nick_usuario;
    SELECT id_video INTO _id_video FROM video WHERE id_plataforma = _id_plataforma AND id_canal = _id_canal AND titulo = _titulo AND datah = _datah;

    INSERT INTO comentario (id_plataforma, id_canal, id_video, id_comentario, id_usuario, texto, datah)
    VALUES (
        _id_plataforma,
        _id_canal,
        _id_video,
        gen_random_uuid(),
        _id_usuario,
        _texto,
        NOW()::timestamp
    )
    ON CONFLICT (id_plataforma, id_canal, id_video, id_comentario, id_usuario) DO NOTHING;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_popular_comentario() RETURNS VOID AS $$
DECLARE
    _nome_plataforma varchar;
    _nome_canal varchar;
    _titulo varchar;
    _datah timestamp;
    _nick varchar;
BEGIN
    FOR n IN 1..7500 LOOP
        SELECT p.nome, c.nome, v.titulo, v.datah
        INTO _nome_plataforma, _nome_canal, _titulo, _datah
        FROM video v
        INNER JOIN plataforma p ON p.id_plataforma = v.id_plataforma 
        INNER JOIN canal c ON c.id_canal = v.id_canal
        ORDER BY random() 
        LIMIT 1;

        SELECT nick INTO _nick
        FROM usuario
        ORDER BY random() 
        LIMIT 1;

        PERFORM fn_inserir_comentario(
            _nome_plataforma,
            _nome_canal,
            _titulo,
            'Comentário teste ' || n,
            _datah,
            _nick
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION fn_inserir_doacao(
    _nome_plataforma VARCHAR,
    _nome_canal VARCHAR,
    _titulo VARCHAR,
    _datah TIMESTAMP,
    _nick_usuario VARCHAR,
    _valor NUMERIC,
    _seq_pg INTEGER,
    _status VARCHAR,
    _tipo_pagamento VARCHAR,
    _txid TEXT DEFAULT NULL,
    _idpaypal TEXT DEFAULT NULL,
    _nro_cartao TEXT DEFAULT NULL,
    _bandeira TEXT DEFAULT NULL,
    _seq_plataforma INTEGER DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    _id_plataforma UUID;
    _id_canal UUID;
    _id_video UUID;
    _id_usuario UUID;
    _id_comentario UUID;
    _id_doacao UUID := gen_random_uuid();
BEGIN
    SELECT id_plataforma INTO _id_plataforma FROM plataforma WHERE nome = _nome_plataforma;
    SELECT id_canal INTO _id_canal FROM canal WHERE nome = _nome_canal AND id_plataforma = _id_plataforma;
    SELECT id_video INTO _id_video FROM video WHERE id_plataforma = _id_plataforma AND id_canal = _id_canal AND titulo = _titulo AND datah = _datah;
    SELECT id_usuario INTO _id_usuario FROM usuario WHERE nick = _nick_usuario;
    SELECT id_comentario INTO _id_comentario FROM comentario 
        WHERE id_plataforma = _id_plataforma AND id_canal = _id_canal AND id_video = _id_video AND id_usuario = _id_usuario
        ORDER BY datah DESC LIMIT 1;

    INSERT INTO doacao (id_plataforma, id_canal, id_video, id_comentario, id_usuario, id_doacao, valor, seq_pg, status)
    VALUES (_id_plataforma, _id_canal, _id_video, _id_comentario, _id_usuario, _id_doacao, _valor, _seq_pg, _status)
    ON CONFLICT DO NOTHING;

    -- Inserir no método de pagamento correspondente
    IF lower(_tipo_pagamento) = 'bitcoin' THEN
        INSERT INTO bitcoin (id_plataforma, id_canal, id_video, id_comentario, id_usuario, id_doacao, txid)
        VALUES (_id_plataforma, _id_canal, _id_video, _id_comentario, _id_usuario, _id_doacao, COALESCE(_txid, 'TX_BTC_' || md5(_id_doacao::text)))
        ON CONFLICT DO NOTHING;
    ELSIF lower(_tipo_pagamento) = 'paypal' THEN
        INSERT INTO paypal (id_plataforma, id_canal, id_video, id_comentario, id_usuario, id_doacao, idpaypal)
        VALUES (_id_plataforma, _id_canal, _id_video, _id_comentario, _id_usuario, _id_doacao, COALESCE(_idpaypal, 'PAYPAL_' || md5(_id_doacao::text)))
        ON CONFLICT DO NOTHING;
    ELSIF lower(_tipo_pagamento) = 'cartao' THEN
        INSERT INTO cartao_credito (id_plataforma, id_canal, id_video, id_comentario, id_usuario, id_doacao, nro, bandeira)
        VALUES (
            _id_plataforma, _id_canal, _id_video, _id_comentario, _id_usuario, _id_doacao,
            COALESCE(_nro_cartao, LPAD((floor(random() * 10000000000000000))::text, 16, '4')),
            COALESCE(_bandeira, (CASE MOD(EXTRACT(epoch FROM now())::int, 3) WHEN 0 THEN 'Visa' WHEN 1 THEN 'Mastercard' ELSE 'Elo' END))
        )
        ON CONFLICT DO NOTHING;
    ELSIF lower(_tipo_pagamento) = 'mecanismo' THEN
        INSERT INTO mecanismo_plat (id_plataforma, id_canal, id_video, id_comentario, id_usuario, id_doacao, seq_plataforma)
        VALUES (_id_plataforma, _id_canal, _id_video, _id_comentario, _id_usuario, _id_doacao, COALESCE(_seq_plataforma, 1))
        ON CONFLICT DO NOTHING;
    ELSE
        RAISE NOTICE 'Tipo de pagamento "%" inválido. Use: bitcoin, paypal, cartao, mecanismo.', _tipo_pagamento;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_popular_doacao() RETURNS VOID AS $$
DECLARE
    _nome_plataforma VARCHAR;
    _nome_canal VARCHAR;
    _titulo VARCHAR;
    _datah TIMESTAMP;
    _nick_usuario VARCHAR;
    _tipo VARCHAR;
BEGIN
    FOR n IN 1..900 LOOP
        SELECT p.nome, c.nome, v.titulo, v.datah, u.nick
        INTO _nome_plataforma, _nome_canal, _titulo, _datah, _nick_usuario
        FROM comentario cm
        INNER JOIN video v ON v.id_plataforma = cm.id_plataforma AND v.id_canal = cm.id_canal AND v.id_video = cm.id_video
        INNER JOIN plataforma p ON p.id_plataforma = v.id_plataforma
        INNER JOIN canal c ON c.id_canal = v.id_canal
        INNER JOIN usuario u ON u.id_usuario = cm.id_usuario
        ORDER BY random()
        LIMIT 1;

        _tipo := CASE MOD(n, 7)
            WHEN 0 THEN 'bitcoin'
            WHEN 1 THEN 'paypal'
            WHEN 2 THEN 'cartao'
            ELSE 'mecanismo'
        END;

        PERFORM fn_inserir_doacao(
            _nome_plataforma,
            _nome_canal,
            _titulo,
            _datah,
            _nick_usuario,
            (5.00 + (MOD(n, 10) * 0.5)),
            1,
            CASE WHEN random() < 0.5 THEN 'Confirmada' ELSE 'Lida' END,
            _tipo
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION fn_popular_database() RETURNS VOID AS $$
BEGIN
    PERFORM fn_inserir_empresa('Alphabet Inc.', 'Google', '1', '+1', 'US-123456789');
    PERFORM fn_inserir_empresa('Amazon.com, Inc.', 'Amazon', '2', '+1', 'US-987654321');
    PERFORM fn_inserir_empresa('Meta Platforms, Inc.', 'Meta', '3', '+1', 'US-555555555');
    PERFORM fn_inserir_empresa('Rumble Inc.', 'Rumble', '4', '+1', 'US-222333444');
    PERFORM fn_inserir_empresa('Stake.com', 'Kick', '5', '+1', 'US-999888777');

    PERFORM fn_popular_empresas_patrocinio();

    PERFORM fn_popular_plataforma( '1', '1','YouTube', '2005-02-14');
    PERFORM fn_popular_plataforma( '2', '2','Twitch', '2011-06-06');
    PERFORM fn_popular_plataforma( '3', '3','Facebook Gaming', '2018-06-01');
    PERFORM fn_popular_plataforma( '4', '4','Rumble', '2013-08-01');
    PERFORM fn_popular_plataforma( '5', '5','Kick', '2022-12-06');

    PERFORM fn_popular_plataforma_usuario();

    PERFORM fn_popular_streammer_pais();
    PERFORM fn_popular_canais();

    PERFORM fn_popular_patrocinio();

    PERFORM fn_popular_nivel_canal();

    PERFORM fn_popular_inscricao();

    PERFORM fn_popular_video();
    PERFORM fn_popular_participacao();

    PERFORM fn_popular_comentario();

    PERFORM fn_popular_doacao();
END;
$$ LANGUAGE plpgsql;

select fn_popular_database();


REFRESH MATERIALIZED VIEW MV_DOACAO_TOTAL_CANAL;
REFRESH MATERIALIZED VIEW MV_FATURAMENTO_TOP_CANAIS;
REFRESH MATERIALIZED VIEW MV_CANAL_VISUALIZACOES;