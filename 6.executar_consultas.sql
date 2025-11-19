-- CONSULTA 01
create or replace function canais_patrocinados(_nro_empresa int default null)
returns table (nome_canal varchar, valor numeric)
as $$
	select c.nome, p.valor
	from canal c
	inner join patrocinio p on c.nro_canal = p.nro_canal
	where _nro_empresa is null or p.nro_empresa = _nro_empresa
	$$ language sql;

select * from canais_patrocinados(11);

SET search_path TO streamerdb;

-- CONSULTA 02
CREATE OR REPLACE FUNCTION fn_membros_valor_desembolsado(_nick_usuario VARCHAR(50) DEFAULT NULL)
RETURNS TABLE (
    nick_membro VARCHAR,
    qtd_canais_membro BIGINT,
    valor_mensal_total NUMERIC
)
AS $$
BEGIN
    SET search_path TO streamerdb;

    RETURN QUERY
    SELECT
        i.nick_membro,
        COUNT(i.nro_canal) AS qtd_canais_membro,
        COALESCE(SUM(nc.valor), 0.00) AS valor_mensal_total
    FROM inscricao i
    INNER JOIN nivel_canal nc 
        ON i.nro_canal = nc.nro_canal AND i.nivel = nc.nivel
    WHERE 
        _nick_usuario IS NULL OR i.nick_membro = _nick_usuario
    GROUP BY
        i.nick_membro
    ORDER BY
        valor_mensal_total DESC;
END;
$$ LANGUAGE plpgsql;

-- CONSULTA 03
CREATE OR REPLACE FUNCTION fn_canais_doacao_recebida(_nro_canal INTEGER DEFAULT NULL)
RETURNS TABLE (
    nro_canal INTEGER,
    nome_canal VARCHAR,
    soma_doacoes NUMERIC
)
AS $$
BEGIN
    SET search_path TO streamerdb;

    RETURN QUERY
    SELECT
        mv.nro_canal,
        mv.nome_canal,
        mv.total_doacao_bruta AS soma_doacoes
    FROM MV_DOACAO_TOTAL_CANAL mv
    WHERE
        mv.total_doacao_bruta > 0
        AND (_nro_canal IS NULL OR mv.nro_canal = _nro_canal)
    ORDER BY
        soma_doacoes DESC;
END;
$$ LANGUAGE plpgsql;

-- CONSULTA 04
CREATE OR REPLACE FUNCTION fn_doacoes_lidas_por_video(_id_video INTEGER DEFAULT NULL)
RETURNS TABLE (
    id_video INTEGER,
    titulo_video VARCHAR,
    soma_doacoes_lidas NUMERIC
)
AS $$
BEGIN
    SET search_path TO streamerdb;

    RETURN QUERY
    SELECT
        v.id_video,
        v.titulo AS titulo_video,
        COALESCE(SUM(d.valor), 0.00) AS soma_doacoes_lidas
    FROM video v
    JOIN comentario cm ON v.id_video = cm.id_video
    JOIN doacao d ON cm.id_comentario = d.id_comentario
    WHERE
        UPPER(d.status) = 'LIDA'
        AND (_id_video IS NULL OR v.id_video = _id_video)
    GROUP BY
        v.id_video, v.titulo
    ORDER BY
        soma_doacoes_lidas DESC;
END;
$$ LANGUAGE plpgsql;

-- CONSULTA 05
CREATE OR REPLACE FUNCTION fn_top_k_patrocinio(k INTEGER)
RETURNS TABLE (
    posicao BIGINT,
    nome_canal VARCHAR,
    valor_patrocinio NUMERIC
)
AS $$
BEGIN
    SET search_path TO streamerdb;

    RETURN QUERY
    SELECT
        ROW_NUMBER() OVER (ORDER BY vcp.valor_patrocinio DESC) AS posicao,
        vcp.nome_canal,
        vcp.valor_patrocinio
    FROM VW_CANAL_RECEITA_PATROCINIO vcp
    ORDER BY
        valor_patrocinio DESC
    LIMIT k;
END;
$$ LANGUAGE plpgsql;

-- CONSULTA 06
CREATE OR REPLACE FUNCTION fn_top_k_membros(k INTEGER)
RETURNS TABLE (
    posicao BIGINT,
    nome_canal VARCHAR,
    receita_membros NUMERIC
)
AS $$
BEGIN
    SET search_path TO streamerdb;

    RETURN QUERY
    SELECT
        ROW_NUMBER() OVER (ORDER BY vrmb.receita_membros_bruta DESC) AS posicao,
        vrmb.nome_canal,
        vrmb.receita_membros_bruta AS receita_membros
    FROM VW_RECEITA_MEMBROS_BRUTA vrmb
    ORDER BY
        receita_membros DESC
    LIMIT k;
END;
$$ LANGUAGE plpgsql;

-- CONSULTA 07
CREATE OR REPLACE FUNCTION fn_top_k_doacoes(k INTEGER)
RETURNS TABLE (
    posicao BIGINT,
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
        mdtc.nome_canal,
        mdtc.total_doacao_bruta AS total_doacao
    FROM MV_DOACAO_TOTAL_CANAL mdtc
    WHERE
        mdtc.total_doacao_bruta > 0
    ORDER BY
        total_doacao DESC
    LIMIT k;
END;
$$ LANGUAGE plpgsql;

-- CONSULTA 08
CREATE OR REPLACE FUNCTION fn_top_k_faturamento_total(k INTEGER)
RETURNS TABLE (
    posicao BIGINT,
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
        mftc.nome_canal,
        mftc.faturamento_total
    FROM MV_FATURAMENTO_TOP_CANAIS mftc
    ORDER BY
        faturamento_total DESC
    LIMIT k;
END;
$$ LANGUAGE plpgsql;
