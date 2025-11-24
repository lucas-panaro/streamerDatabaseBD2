-- CONSULTA 01
create or replace function canais_patrocinados(_empresa_tax_id varchar(50) default null)
returns table (nome_canal varchar, valor numeric)
as $$
	select c.nome, p.valor
	from canal c
	inner join patrocinio p on c.id_canal = p.id_canal
	where _empresa_tax_id is null or p.empresa_tax_id = _empresa_tax_id
	$$ language sql;

select * from canais_patrocinados('12');

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

select * from fn_membros_valor_desembolsado();
select * from fn_membros_valor_desembolsado('user_0189');

-- CONSULTA 03
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

select * from fn_canais_doacao_recebida();

-- CONSULTA 04
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
    JOIN comentario cm ON v.id_video = cm.id_video and v.id_canal = cm.id_canal
    JOIN doacao d ON cm.id_comentario = d.id_comentario and cm.id_video = d.id_video and cm.id_canal = d.id_canal
    WHERE
        UPPER(d.status) = 'LIDA'
        AND (_id_video IS NULL OR v.id_video = _id_video)
    GROUP BY
        v.id_canal, v.id_video, v.titulo
    ORDER BY
        soma_doacoes_lidas DESC;
END;
$$ LANGUAGE plpgsql;


select * from fn_doacoes_lidas_por_video();


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

select * from fn_top_k_patrocinio(1);


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

select * from fn_top_k_membros(1);


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

select * from fn_top_k_doacoes(1);

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

select * from fn_top_k_faturamento_total(1);