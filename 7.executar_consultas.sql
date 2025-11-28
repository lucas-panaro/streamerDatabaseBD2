-- CONSULTA 01: Canais Patrocinados
CREATE OR REPLACE FUNCTION canais_patrocinados(_empresa_nome varchar default null, _empresa_tax_id varchar(50) default null, _nome_plataforma varchar default null)
RETURNS TABLE (nome_plataforma varchar, nome_canal varchar, nome_empresa varchar, valor numeric)
AS $$
    SELECT p.nome, c.nome, e.nome, pt.valor
    FROM canal c
    INNER JOIN plataforma p ON p.id_plataforma = c.id_plataforma
    INNER JOIN patrocinio pt ON c.id_canal = pt.id_canal and c.id_plataforma = pt.id_plataforma
	INNER JOIN empresa e on e.id_empresa = pt.id_empresa
    WHERE 1=1
	AND (_empresa_tax_id IS NULL OR e.tax_id = _empresa_tax_id)
	AND (_empresa_nome IS NULL OR e.nome = _empresa_nome)
	AND (_nome_plataforma IS NULL OR p.nome = _nome_plataforma)
$$ LANGUAGE sql;

-- Possível efetuar busca por nome da empresa
select * from canais_patrocinados('Patrocinador Genérico 584');

-- Possível efetuar busca por CNPJ da empresa
select * from canais_patrocinados(null, '584');

-- Possível efetuar busca por plataforma
select * from canais_patrocinados(null, null, 'YouTube');


-- CONSULTA 02
CREATE OR REPLACE FUNCTION fn_membros_valor_desembolsado(_nick_usuario VARCHAR(50) DEFAULT NULL)
RETURNS TABLE (
    nick_membro VARCHAR,
    qtd_canais_membro BIGINT,
    valor_mensal_total NUMERIC
)
AS $$
BEGIN
    RETURN QUERY
    SELECT
        u.nick,
        COUNT(i.id_canal) AS qtd_canais_membro,
        COALESCE(SUM(nc.valor), 0.00) AS valor_mensal_total
    FROM inscricao i
    INNER JOIN nivel_canal nc 
        ON i.id_plataforma = nc.id_plataforma AND i.id_canal = nc.id_canal AND i.nivel = nc.nivel
	INNER JOIN  usuario u 
		ON i.id_usuario = u.id_usuario
    WHERE 
        _nick_usuario IS NULL OR u.nick = _nick_usuario
    GROUP BY
        u.nick
    ORDER BY
        valor_mensal_total DESC;
END;
$$ LANGUAGE plpgsql;

select * from fn_membros_valor_desembolsado();

-- CONSULTA 03
CREATE OR REPLACE FUNCTION fn_canais_doacao_recebida(_nome_plataforma varchar DEFAULT NULL, _nome_canal varchar DEFAULT NULL)
RETURNS TABLE (
    nome_plataforma VARCHAR,
    nome_canal VARCHAR,
    soma_doacoes NUMERIC
)
AS $$
BEGIN
    SET search_path TO streamerdb;

    RETURN QUERY
    SELECT
        mv.nome_plataforma,
        mv.nome_canal,
        mv.total_doacao_bruta AS soma_doacoes
    FROM MV_DOACAO_TOTAL_CANAL mv
    WHERE
        mv.total_doacao_bruta > 0
        AND (_nome_plataforma IS NULL OR mv.nome_plataforma = _nome_plataforma)
        AND (_nome_canal IS NULL OR mv.nome_canal = _nome_canal)
    ORDER BY
        soma_doacoes DESC;
END;
$$ LANGUAGE plpgsql;

select * from fn_canais_doacao_recebida();

-- CONSULTA 04
CREATE OR REPLACE FUNCTION fn_doacoes_lidas_por_video(_nome_plataforma varchar DEFAULT NULL, _nome_canal varchar DEFAULT NULL, _titulo_video varchar DEFAULT NULL)
RETURNS TABLE (
    nome_plataforma varchar,
    nome_canal varchar,
    titulo_video VARCHAR,
    soma_doacoes_lidas NUMERIC
)
AS $$
BEGIN   
    RETURN QUERY
    SELECT
		p.nome,
        c.nome,
        v.titulo AS titulo_video,
        COALESCE(SUM(d.valor), 0.00) AS soma_doacoes_lidas
    FROM video v
	INNER JOIN canal c on v.id_canal = c.id_canal
	INNER JOIN plataforma p on v.id_plataforma = p.id_plataforma
    JOIN comentario cm ON 
		v.id_plataforma = cm.id_plataforma and
		v.id_video = cm.id_video and 	
		v.id_canal = cm.id_canal
    JOIN doacao d ON 
		cm.id_plataforma = d.id_plataforma and
		cm.id_canal = d.id_canal and
		cm.id_video = d.id_video and 
		cm.id_comentario = d.id_comentario  	
    WHERE
        UPPER(d.status) = 'LIDA'
        AND (_nome_plataforma IS NULL OR p.nome = _nome_plataforma)
        AND (_nome_canal IS NULL OR c.nome = _nome_canal)
		AND (_titulo_video IS NULL OR v.titulo = _titulo_video)
    GROUP BY
        p.nome, c.nome, v.titulo
    ORDER BY
        soma_doacoes_lidas DESC;
END;
$$ LANGUAGE plpgsql;


select * from fn_doacoes_lidas_por_video();
select * from fn_doacoes_lidas_por_video('YouTube');



-- CONSULTA 05
CREATE OR REPLACE FUNCTION fn_top_k_patrocinio(k INTEGER, _nome_plataforma varchar DEFAULT NULL)
RETURNS TABLE (
    posicao BIGINT,
    nome_plataforma VARCHAR,
    nome_canal VARCHAR,
    valor_patrocinio NUMERIC
)
AS $$
BEGIN
    RETURN QUERY
    SELECT
        ROW_NUMBER() OVER (ORDER BY vcp.valor_patrocinio DESC) AS posicao,
		vcp.nome_plataforma,
        vcp.nome_canal,
        vcp.valor_patrocinio
    FROM VW_CANAL_RECEITA_PATROCINIO vcp
	WHERE 1=1
	AND (_nome_plataforma IS NULL OR vcp.nome_plataforma = _nome_plataforma)
    ORDER BY
        valor_patrocinio DESC
    LIMIT k;
END;
$$ LANGUAGE plpgsql;

select * from fn_top_k_patrocinio(1);
select * from fn_top_k_patrocinio(1, 'YouTube');


-- CONSULTA 06
CREATE OR REPLACE FUNCTION fn_top_k_membros(k INTEGER, _nome_plataforma varchar DEFAULT NULL)
RETURNS TABLE (
    posicao BIGINT,
    nome_plataforma VARCHAR,
    nome_canal VARCHAR,
    receita_membros NUMERIC
)
AS $$
BEGIN
    SET search_path TO streamerdb;

    RETURN QUERY
    SELECT
        ROW_NUMBER() OVER (ORDER BY vrmb.receita_membros_bruta DESC) AS posicao,
		vrmb.nome_plataforma,
        vrmb.nome_canal,
        vrmb.receita_membros_bruta AS receita_membros
    FROM VW_RECEITA_MEMBROS_BRUTA vrmb
	WHERE 1=1
	AND (_nome_plataforma IS NULL OR vrmb.nome_plataforma = _nome_plataforma)
    ORDER BY
        receita_membros DESC
    LIMIT k;
END;
$$ LANGUAGE plpgsql;

select * from fn_top_k_membros(1);
select * from fn_top_k_membros(1, 'YouTube');


-- CONSULTA 07
CREATE OR REPLACE FUNCTION fn_top_k_doacoes(k INTEGER, _nome_plataforma varchar DEFAULT NULL)
RETURNS TABLE (
    posicao BIGINT,
    nome_plataforma VARCHAR,
    nome_canal VARCHAR,
    total_doacao NUMERIC
)
AS $$
BEGIN
    SET search_path TO streamerdb;
    
    REFRESH MATERIALIZED VIEW MV_DOACAO_TOTAL_CANAL;

    RETURN QUERY
    SELECT
        ROW_NUMBER() OVER (ORDER BY mdtc.total_doacao_bruta DESC) AS posicao,
        mdtc.nome_plataforma,
        mdtc.nome_canal,
        mdtc.total_doacao_bruta AS total_doacao
    FROM MV_DOACAO_TOTAL_CANAL mdtc
    WHERE
        mdtc.total_doacao_bruta > 0
        AND (_nome_plataforma IS NULL OR mdtc.nome_plataforma = _nome_plataforma)
    ORDER BY
        total_doacao DESC
    LIMIT k;
END;
$$ LANGUAGE plpgsql;

select * from fn_top_k_doacoes(1);
select * from fn_top_k_doacoes(1, 'YouTube');

-- CONSULTA 08
CREATE OR REPLACE FUNCTION fn_top_k_faturamento_total(k INTEGER, _nome_plataforma varchar DEFAULT NULL)
RETURNS TABLE (
    posicao BIGINT,
    nome_plataforma VARCHAR,
    nome_canal VARCHAR,
    faturamento_total NUMERIC
)
AS $$
BEGIN
    SET search_path TO streamerdb;
    
    REFRESH MATERIALIZED VIEW MV_FATURAMENTO_TOP_CANAIS;

    RETURN QUERY
    SELECT
        ROW_NUMBER() OVER (ORDER BY mftc.faturamento_total DESC) AS posicao,
        mftc.nome_plataforma,
        mftc.nome_canal,
        mftc.faturamento_total
    FROM MV_FATURAMENTO_TOP_CANAIS mftc
    WHERE 1=1
        AND (_nome_plataforma IS NULL OR mftc.nome_plataforma = _nome_plataforma)
    ORDER BY
        faturamento_total DESC
    LIMIT k;
END;
$$ LANGUAGE plpgsql;

select * from fn_top_k_faturamento_total(1);
select * from fn_top_k_faturamento_total(1, 'YouTube');