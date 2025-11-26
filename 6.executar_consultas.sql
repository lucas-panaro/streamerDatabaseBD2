SET search_path TO streamerdb;

-- CONSULTA 01: Canais Patrocinados (Filtro por tax_id da empresa - VARCHAR)
CREATE OR REPLACE FUNCTION canais_patrocinados(_empresa_tax_id varchar(50) default null)
RETURNS TABLE (nome_canal varchar, valor numeric)
AS $$
    SELECT c.nome, p.valor
    FROM canal c
    INNER JOIN patrocinio p ON c.id_canal = p.id_canal
    WHERE _empresa_tax_id IS NULL OR p.empresa_tax_id = _empresa_tax_id
$$ LANGUAGE sql;

-- CONSULTA 02: Membros e Valor (Sem mudanças, usa id_canal UUID internamente)
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
        COUNT(i.id_canal) AS qtd_canais_membro,
        COALESCE(SUM(nc.valor), 0.00) AS valor_mensal_total
    FROM inscricao i
    INNER JOIN nivel_canal nc 
        ON i.id_canal = nc.id_canal AND i.nivel = nc.nivel
    WHERE 
        _nick_usuario IS NULL OR i.nick_membro = _nick_usuario
    GROUP BY
        i.nick_membro
    ORDER BY
        valor_mensal_total DESC;
END;
$$ LANGUAGE plpgsql;

-- CONSULTA 03: Doações por Canal (Parâmetro UUID)
CREATE OR REPLACE FUNCTION fn_canais_doacao_recebida(_id_canal uuid DEFAULT NULL)
RETURNS TABLE (
    id_canal uuid,
    nome_canal VARCHAR,
    soma_doacoes NUMERIC
)
AS $$
BEGIN
    SET search_path TO streamerdb;

    RETURN QUERY
    SELECT
        mv.id_canal,
        mv.nome_canal,
        mv.total_doacao_bruta AS soma_doacoes
    FROM MV_DOACAO_TOTAL_CANAL mv
    WHERE
        mv.total_doacao_bruta > 0
        AND (_id_canal IS NULL OR mv.id_canal = _id_canal)
    ORDER BY
        soma_doacoes DESC;
END;
$$ LANGUAGE plpgsql;

-- CONSULTA 04: Doações Lidas (Usa tabelas base, não view removida)
CREATE OR REPLACE FUNCTION fn_doacoes_lidas_por_video(_id_video uuid DEFAULT NULL)
RETURNS TABLE (
    id_canal uuid,
    id_video uuid,
    titulo_video VARCHAR,
    soma_doacoes_lidas NUMERIC
)
AS $$
BEGIN
    SET search_path TO streamerdb;

    RETURN QUERY
    SELECT
        v.id_canal,
        v.id_video,
        v.titulo AS titulo_video,
        COALESCE(SUM(d.valor), 0.00) AS soma_doacoes_lidas
    FROM video v
    JOIN comentario cm ON v.id_video = cm.id_video AND v.id_canal = cm.id_canal
    JOIN doacao d ON cm.id_comentario = d.id_comentario AND cm.id_video = d.id_video AND cm.id_canal = d.id_canal
    WHERE
        UPPER(d.status) = 'LIDA'
        AND (_id_video IS NULL OR v.id_video = _id_video)
    GROUP BY
        v.id_canal, v.id_video, v.titulo
    ORDER BY
        soma_doacoes_lidas DESC;
END;
$$ LANGUAGE plpgsql;

-- CONSULTA 05: Top K Patrocínio (Usa View Virtual)
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

-- CONSULTA 06: Top K Membros (Usa View Virtual)
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

-- CONSULTA 07: Top K Doações (Usa View Materializada + Refresh)
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

-- CONSULTA 08: Top K Faturamento (Usa View Materializada + Refresh)
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