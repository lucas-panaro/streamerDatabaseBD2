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

    PERFORM fn_inserir_plataforma( '1', '1','YouTube', '2005-02-14');
    PERFORM fn_inserir_plataforma( '2', '2','Twitch', '2011-06-06');
    PERFORM fn_inserir_plataforma( '3', '3','Facebook Gaming', '2018-06-01');
    PERFORM fn_inserir_plataforma( '4', '4','Rumble', '2013-08-01');
    PERFORM fn_inserir_plataforma( '5', '5','Kick', '2022-12-06');

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