TRUNCATE TABLE 
    bitcoin, paypal, cartao_credito, mecanismo_plat, doacao, 
    comentario, participa, video, inscricao, nivel_canal, 
    patrocinio, canal, streamer_pais, plataforma_usuario, 
    usuario, empresa_pais, plataforma, empresa, conversao, pais
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
    r_canal RECORD;
BEGIN
    FOR r_canal IN
        SELECT p.nome AS nome_plataforma, c.nome AS nome_canal
        FROM canal c
        INNER JOIN plataforma p ON p.id_plataforma = c.id_plataforma
        ORDER BY random()
        LIMIT 2000
    LOOP
        PERFORM fn_inserir_patrocinio(
            r_canal.nome_plataforma,
            r_canal.nome_canal,
            (SELECT nome FROM empresa ORDER BY random() LIMIT 1),
            (1000.00 + (random() * 9000.00))::NUMERIC
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_popular_nivel_canal() RETURNS VOID AS $$
DECLARE
    r_canal RECORD;
    N INT;
BEGIN
    FOR r_canal IN
        SELECT p.nome AS nome_plataforma, c.nome AS nome_canal
        FROM canal c
        INNER JOIN plataforma p ON p.id_plataforma = c.id_plataforma
        ORDER BY random()
        LIMIT 2000
    LOOP
        N = (random() * 1000)::INT;
        PERFORM fn_inserir_nivel_canal(
            r_canal.nome_plataforma,
            r_canal.nome_canal,
            CASE MOD(N, 3)
                WHEN 0 THEN 'Bronze'
                WHEN 1 THEN 'Prata'
                ELSE 'Ouro'
            END,
            CASE MOD(N, 3)
                WHEN 0 THEN 4.99
                WHEN 1 THEN 9.99
                ELSE 24.99
            END
        );
        PERFORM fn_inserir_nivel_canal(
            r_canal.nome_plataforma,
            r_canal.nome_canal,
            CASE MOD(N, 11)
                WHEN 0 THEN 'Bronze'
                WHEN 1 THEN 'Prata'
                ELSE 'Ouro'
            END,
            CASE MOD(N, 11)
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
    r_nivel_canal RECORD;
	_nick_usuario varchar;
BEGIN
    FOR r_nivel_canal IN
        SELECT p.nome AS nome_plataforma, c.nome AS nome_canal, nivel
        FROM nivel_canal nc
        INNER JOIN plataforma p ON p.id_plataforma = nc.id_plataforma
        INNER JOIN canal c on c.id_canal = nc.id_canal
        ORDER BY random()
        LIMIT 2000
    LOOP
        SELECT nick INTO _nick_usuario FROM usuario ORDER BY random() LIMIT 1;
        PERFORM fn_inserir_inscricao(
            r_nivel_canal.nome_plataforma,
            r_nivel_canal.nome_canal,
            _nick_usuario,
            r_nivel_canal.nivel
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_popular_video() RETURNS VOID AS $$
DECLARE
    r_canal RECORD;
    N INT = random();
BEGIN
    FOR r_canal IN
        SELECT p.nome AS nome_plataforma, c.nome AS nome_canal
        FROM canal c
        INNER JOIN plataforma p ON p.id_plataforma = c.id_plataforma
        ORDER BY random()
        LIMIT 10000
    LOOP
        PERFORM fn_inserir_video(
            r_canal.nome_plataforma,
            r_canal.nome_canal,
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
    r_video RECORD;
	_nick_streamer VARCHAR;
BEGIN
    FOR r_video IN
        SELECT p.nome AS nome_plataforma, c.nome AS nome_canal, v.titulo AS titulo, v.datah::TIMESTAMP AS datah
        FROM video v
        INNER JOIN plataforma p ON p.id_plataforma = v.id_plataforma
        INNER JOIN canal c ON c.id_canal = v.id_canal AND c.id_plataforma = v.id_plataforma
        ORDER BY random()
        LIMIT 10000
    LOOP
        SELECT u.nick INTO _nick_streamer
        FROM streamer_pais sp
        INNER JOIN usuario u ON u.id_usuario = sp.id_usuario
        ORDER BY random() 
        LIMIT 1;
        PERFORM fn_inserir_participacao(
            r_video.nome_plataforma,
            r_video.nome_canal,
            r_video.titulo,
            r_video.datah,
            _nick_streamer
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION fn_popular_comentario() RETURNS VOID AS $$
DECLARE
    r_video RECORD;
	_nick VARCHAR;
    N INT;
BEGIN
    FOR r_video IN
        SELECT p.nome AS nome_plataforma, c.nome AS nome_canal, v.titulo AS titulo, v.datah::TIMESTAMP AS datah
        FROM video v
        INNER JOIN plataforma p ON p.id_plataforma = v.id_plataforma
        INNER JOIN canal c ON c.id_canal = v.id_canal AND c.id_plataforma = v.id_plataforma
        ORDER BY random()
        LIMIT 10000
    LOOP
        SELECT nick INTO _nick
        FROM usuario
        ORDER BY random() 
        LIMIT 1;

        N = random() * 1000;
        PERFORM fn_inserir_comentario(
            r_video.nome_plataforma,
            r_video.nome_canal,
            r_video.titulo,
            'Comentário teste ' || n,
            r_video.datah,
            _nick
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_popular_doacao() RETURNS VOID AS $$
DECLARE
    r_comentario RECORD;
    N INT;
    _tipo VARCHAR;
BEGIN
    FOR r_comentario IN
        SELECT p.nome AS nome_plataforma, c.nome AS nome_canal, v.titulo AS titulo, v.datah::TIMESTAMP AS datah, u.nick AS nick_usuario
        FROM comentario cm
        INNER JOIN video v ON v.id_plataforma = cm.id_plataforma AND v.id_canal = cm.id_canal AND v.id_video = cm.id_video
        INNER JOIN canal c ON c.id_plataforma = cm.id_plataforma AND c.id_canal = cm.id_canal
        INNER JOIN plataforma p ON p.id_plataforma = v.id_plataforma
        INNER JOIN usuario u ON u.id_usuario = cm.id_usuario
        ORDER BY random()
        LIMIT 500
    LOOP
        N = random() * 1000;
        _tipo := CASE MOD(n, 7)
            WHEN 0 THEN 'bitcoin'
            WHEN 1 THEN 'paypal'
            WHEN 2 THEN 'cartao'
            ELSE 'mecanismo'
        END;

        PERFORM fn_inserir_doacao(
            r_comentario.nome_plataforma,
            r_comentario.nome_canal,
            r_comentario.titulo,
            r_comentario.datah,
            r_comentario.nick_usuario,
            (1.00 + (random() * 50.00))::NUMERIC,
            1,
            CASE WHEN random() < 0.5 THEN 'Confirmada' ELSE 'Lida' END,
            _tipo
        );

        PERFORM fn_inserir_doacao(
            r_comentario.nome_plataforma,
            r_comentario.nome_canal,
            r_comentario.titulo,
            r_comentario.datah,
            r_comentario.nick_usuario,
            (1.00 + (random() * 50.00))::NUMERIC,
            1,
            CASE WHEN random() < 0.5 THEN 'Confirmada' ELSE 'Lida' END,
            _tipo
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_popular_video_view() RETURNS VOID AS $$
DECLARE
    r_video RECORD;
BEGIN
    FOR r_video IN
        SELECT p.nome AS nome_plataforma, c.nome AS nome_canal, v.titulo, v.datah::timestamp
        FROM video v
        INNER JOIN plataforma p on p.id_plataforma = v.id_plataforma
        INNER JOIN canal c on c.id_plataforma = v.id_plataforma AND c.id_canal = v.id_canal
        ORDER BY random()
        LIMIT 10000
	LOOP
    	PERFORM fn_incrementar_video_view(r_video.nome_plataforma, r_video.nome_canal, r_video.titulo, r_video.datah, (random() * 10000)::int);
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

    PERFORM fn_popular_video_view();

    PERFORM fn_popular_participacao();

    PERFORM fn_popular_comentario();

    PERFORM fn_popular_doacao();
    PERFORM fn_popular_doacao();

    PERFORM fn_update_all_channel_views();
END;
$$ LANGUAGE plpgsql;




select fn_popular_database();
REFRESH MATERIALIZED VIEW MV_DOACAO_TOTAL_CANAL;
REFRESH MATERIALIZED VIEW MV_FATURAMENTO_TOP_CANAIS;
REFRESH MATERIALIZED VIEW MV_CANAL_VISUALIZACOES;