CREATE OR REPLACE FUNCTION fn_inserir_empresa(_nome VARCHAR, _nome_fantasia VARCHAR, _tax_id VARCHAR, _ddi_pais VARCHAR, _id_nacional VARCHAR)
RETURNS VOID AS $$
DECLARE
    _id_empresa UUID := gen_random_uuid();
BEGIN
    INSERT INTO empresa (id_empresa, tax_id, nome, nome_fantasia)
    VALUES (_id_empresa, _tax_id, _nome, _nome_fantasia)
    ON CONFLICT (tax_id) DO NOTHING;

    SELECT id_empresa INTO _id_empresa FROM empresa WHERE tax_id = _tax_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Empresa com tax_id "%" não encontrada.', _tax_id;
    END IF;

    INSERT INTO empresa_pais (id_empresa, ddi_pais, id_nacional)
    VALUES (_id_empresa, _ddi_pais, _id_nacional)
    ON CONFLICT (id_empresa, ddi_pais) DO NOTHING;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION fn_inserir_plataforma(_empresa_fundadora_tax_id varchar, _empresa_responsavel_tax_id varchar, _nome_plataforma varchar, _data_fundacao date) RETURNS VOID AS $$
DECLARE
    _id_empresa_fundadora UUID;
    _id_empresa_responsavel UUID;
BEGIN

    SELECT id_empresa INTO _id_empresa_fundadora FROM empresa WHERE tax_id = _empresa_fundadora_tax_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Empresa com tax_id "%" não encontrada.', _empresa_fundadora_tax_id;
    END IF;

    SELECT id_empresa INTO _id_empresa_responsavel FROM empresa WHERE tax_id = _empresa_responsavel_tax_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Empresa com tax_id "%" não encontrada.', _empresa_responsavel_tax_id;
    END IF;

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
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Usuário com email "%" não encontrado.', _email;
    END IF;

    SELECT id_plataforma INTO _id_plataforma FROM plataforma WHERE nome = _nome_plataforma;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Plataforma com nome "%" não encontrada.', _nome_plataforma;
    END IF;

    INSERT INTO plataforma_usuario (id_plataforma, id_usuario) 
    VALUES (_id_plataforma, _id_usuario)
    ON CONFLICT (id_plataforma, id_usuario) DO NOTHING;
    
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



CREATE OR REPLACE FUNCTION fn_inserir_patrocinio(_nome_plataforma VARCHAR, _nome_canal VARCHAR, _nome_empresa VARCHAR, _valor NUMERIC) RETURNS VOID AS $$
DECLARE
    _id_plataforma UUID;
    _id_canal UUID;
    _id_empresa UUID;
BEGIN
    SELECT id_plataforma INTO _id_plataforma FROM plataforma WHERE nome = _nome_plataforma;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Plataforma não encontrada: %', _nome_plataforma;
    END IF;

    SELECT id_canal INTO _id_canal FROM canal WHERE nome = _nome_canal AND id_plataforma = _id_plataforma;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Canal não encontrado: plataforma=%, canal=%', 
            _nome_plataforma, _nome_canal;
    END IF;

    SELECT id_empresa INTO _id_empresa FROM empresa WHERE nome = _nome_empresa;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Empresa não encontrada: %', _nome_empresa;
    END IF;
    
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


CREATE OR REPLACE FUNCTION fn_inserir_nivel_canal(_nome_plataforma VARCHAR, _nome_canal VARCHAR, _nivel VARCHAR, _valor NUMERIC) RETURNS VOID AS $$
DECLARE
    _id_plataforma UUID;
    _id_canal UUID;
BEGIN
    SELECT c.id_plataforma, c.id_canal INTO _id_plataforma, _id_canal 
    FROM canal c
    INNER JOIN plataforma p ON c.id_plataforma = p.id_plataforma
    WHERE c.nome = _nome_canal 
    AND p.nome = _nome_plataforma;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Canal não encontrado: plataforma=%, canal=%', 
        _nome_plataforma, _nome_canal;
    END IF;

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


CREATE OR REPLACE FUNCTION fn_inserir_inscricao(_nome_plataforma VARCHAR, _nome_canal VARCHAR, _nick_usuario VARCHAR, _nivel VARCHAR) RETURNS VOID AS $$
DECLARE
    _id_plataforma UUID;
    _id_canal UUID;
    _id_usuario UUID;
BEGIN
    SELECT c.id_plataforma, c.id_canal INTO _id_plataforma, _id_canal 
    FROM canal c
    INNER JOIN plataforma p ON c.id_plataforma = p.id_plataforma
    WHERE c.nome = _nome_canal 
    AND p.nome = _nome_plataforma;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Canal não encontrado: plataforma=%, canal=%', 
        _nome_plataforma, _nome_canal;
    END IF;

    SELECT id_usuario INTO _id_usuario FROM usuario WHERE nick = _nick_usuario;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Usuário não encontrado: %', _nick_usuario;
    END IF;

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


CREATE OR REPLACE FUNCTION fn_inserir_video(_nome_plataforma VARCHAR, _nome_canal VARCHAR, _titulo VARCHAR, _datah timestamp, _tema VARCHAR, _duracao INTERVAL) RETURNS VOID AS $$
DECLARE
    _id_plataforma UUID;
    _id_canal UUID;
BEGIN
    SELECT c.id_plataforma, c.id_canal INTO _id_plataforma, _id_canal 
    FROM canal c
    INNER JOIN plataforma p ON c.id_plataforma = p.id_plataforma
    WHERE c.nome = _nome_canal 
    AND p.nome = _nome_plataforma;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Canal não encontrado: plataforma=%, canal=%', 
        _nome_plataforma, _nome_canal;
    END IF;

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

CREATE OR REPLACE FUNCTION fn_incrementar_video_view(_nome_plataforma VARCHAR, _nome_canal VARCHAR, _titulo VARCHAR, _datah timestamp, views INTEGER) RETURNS VOID AS $$
DECLARE
    _id_plataforma UUID;
    _id_canal UUID;
    _id_video UUID;
BEGIN
    SELECT v.id_plataforma, v.id_canal, v.id_video INTO _id_plataforma, _id_canal, _id_video 
	FROM video v
	INNER JOIN plataforma p on p.id_plataforma = v.id_plataforma
	INNER JOIN canal c on c.id_plataforma = v.id_plataforma AND c.id_canal = v.id_canal
	WHERE 1=1
	AND p.nome = _nome_plataforma
	AND c.nome = _nome_canal
	AND v.titulo = _titulo
	AND DATE_TRUNC('millisecond', v.datah) = DATE_TRUNC('millisecond', _datah);

    IF _id_video IS NULL THEN
        RAISE EXCEPTION 'Vídeo não encontrado: plataforma=%, canal=%, titulo=%, datah=%', 
            _nome_plataforma, _nome_canal, _titulo, _datah;
    END IF;

    UPDATE video
    SET visu_total = visu_total + views
    WHERE id_plataforma = _id_plataforma AND id_canal = _id_canal AND id_video = _id_video;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_inserir_participacao(_nome_plataforma VARCHAR, _nome_canal VARCHAR, _titulo VARCHAR, _datah timestamp, _nick_streamer VARCHAR) RETURNS VOID AS $$
DECLARE
    _id_plataforma UUID;
    _id_canal UUID;
    _id_video UUID;
    _id_streamer UUID;
BEGIN
    SELECT c.id_plataforma, c.id_canal INTO _id_plataforma, _id_canal 
    FROM canal c
    INNER JOIN plataforma p ON c.id_plataforma = p.id_plataforma
    WHERE c.nome = _nome_canal 
    AND p.nome = _nome_plataforma;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Canal não encontrado: plataforma=%, canal=%', 
        _nome_plataforma, _nome_canal;
    END IF;

    SELECT id_usuario INTO _id_streamer FROM usuario WHERE nick = _nick_streamer;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Streamer não encontrado: %', _nick_streamer;
    END IF;

    SELECT id_video INTO _id_video FROM video WHERE id_plataforma = _id_plataforma AND id_canal = _id_canal AND titulo = _titulo AND datah = _datah;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Vídeo não encontrado: plataforma=%, canal=%, titulo=%, datah=%', 
            _nome_plataforma, _nome_canal, _titulo, _datah;
    END IF;
    
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

CREATE OR REPLACE FUNCTION fn_inserir_comentario(_nome_plataforma VARCHAR, _nome_canal VARCHAR, _titulo VARCHAR, _texto text, _datah timestamp, _nick_usuario VARCHAR, _coment_on boolean) RETURNS VOID AS $$
DECLARE
    _id_plataforma UUID;
    _id_canal UUID;
    _id_video UUID;
    _id_usuario UUID;
    _coment_on boolean;
BEGIN
    SELECT c.id_plataforma, c.id_canal INTO _id_plataforma, _id_canal 
    FROM canal c
    INNER JOIN plataforma p ON c.id_plataforma = p.id_plataforma
    WHERE c.nome = _nome_canal 
    AND p.nome = _nome_plataforma;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Canal não encontrado: plataforma=%, canal=%', 
        _nome_plataforma, _nome_canal;
    END IF;
    
    SELECT id_usuario INTO _id_usuario FROM usuario WHERE nick = _nick_usuario;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Usuário não encontrado: %', _nick_usuario;
    END IF;

    SELECT id_video INTO _id_video FROM video WHERE id_plataforma = _id_plataforma AND id_canal = _id_canal AND titulo = _titulo AND datah = _datah;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Vídeo não encontrado: plataforma=%, canal=%, titulo=%, datah=%', 
            _nome_plataforma, _nome_canal, _titulo, _datah;
    END IF;

    INSERT INTO comentario (id_plataforma, id_canal, id_video, id_comentario, id_usuario, texto, coment_on, datah)
    VALUES (
        _id_plataforma,
        _id_canal,
        _id_video,
        gen_random_uuid(),
        _id_usuario,
        _texto,
        _coment_on,
        NOW()::timestamp
    )
    ON CONFLICT (id_plataforma, id_canal, id_video, id_comentario, id_usuario) DO NOTHING;
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
    SELECT cm.id_plataforma, cm.id_canal, cm.id_video, cm.id_usuario, cm.id_comentario INTO _id_plataforma, _id_canal, _id_video, _id_usuario, _id_comentario
    FROM comentario cm
    INNER JOIN plataforma p ON cm.id_plataforma = p.id_plataforma
    INNER JOIN canal c ON cm.id_plataforma = c.id_plataforma AND cm.id_canal = c.id_canal
    INNER JOIN video v ON cm.id_plataforma = v.id_plataforma AND cm.id_canal = v.id_canal AND cm.id_video = v.id_video
    INNER JOIN usuario u ON cm.id_usuario = u.id_usuario
    WHERE 1=1
    AND c.nome = _nome_canal 
    AND p.nome = _nome_plataforma
    AND u.nick = _nick_usuario
    AND v.titulo = _titulo
	AND DATE_TRUNC('millisecond', v.datah) = DATE_TRUNC('millisecond', _datah);
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Comentario não encontrado: plataforma=%, canal=%', 
        _nome_plataforma, _nome_canal;
    END IF;
    
    INSERT INTO doacao (id_plataforma, id_canal, id_video, id_comentario, id_usuario, id_doacao, valor, seq_pg, status)
    VALUES (_id_plataforma, _id_canal, _id_video, _id_comentario, _id_usuario, _id_doacao, _valor, _seq_pg, _status)
    ON CONFLICT DO NOTHING;

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

CREATE OR REPLACE FUNCTION fn_update_all_channel_views() RETURNS VOID AS $$
BEGIN
    UPDATE canal c
    SET qtd_visualizacoes = v.total_views
    FROM (
        SELECT id_plataforma, id_canal, SUM(visu_total) AS total_views
        FROM video
        GROUP BY id_plataforma, id_canal
    ) v
    WHERE c.id_plataforma = v.id_plataforma
      AND c.id_canal = v.id_canal;
END;
$$ LANGUAGE plpgsql;