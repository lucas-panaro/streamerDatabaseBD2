SET
    search_path TO streamerdb;

DROP MATERIALIZED VIEW IF EXISTS MV_FATURAMENTO_TOP_CANAIS CASCADE;

DROP MATERIALIZED VIEW IF EXISTS MV_DOACAO_TOTAL_CANAL CASCADE;

DROP MATERIALIZED VIEW IF EXISTS MV_CANAL_VISUALIZACOES CASCADE;

DROP VIEW IF EXISTS VW_CANAL_RECEITA_PATROCINIO CASCADE;

DROP VIEW IF EXISTS VW_RECEITA_MEMBROS_BRUTA CASCADE;

-- VIEW 1: Receita Mensal de Membros por Canal
CREATE
OR REPLACE VIEW VW_RECEITA_MEMBROS_BRUTA AS
SELECT
    p.nome AS nome_plataforma,
    c.nome AS nome_canal,
    COUNT(i.id_usuario) AS qtd_membros,
    SUM(nc.valor) AS receita_membros_bruta
FROM
    nivel_canal nc
    INNER JOIN plataforma p ON nc.id_plataforma = p.id_plataforma
    INNER JOIN inscricao i ON nc.id_plataforma = i.id_plataforma AND nc.id_canal = i.id_canal AND nc.nivel = i.nivel
    INNER JOIN canal c ON nc.id_plataforma = c.id_plataforma AND nc.id_canal = c.id_canal
GROUP BY
    p.nome,
    c.nome;

-- VIEW 2: Canais e Patrocínio Vigente
create
OR REPLACE VIEW VW_CANAL_RECEITA_PATROCINIO AS
SELECT
    p.nome AS nome_plataforma,
    c.nome AS nome_canal,
    e.nome AS nome_empresa,
    pt.valor AS valor_patrocinio
FROM
    canal c
    INNER JOIN plataforma p ON c.id_plataforma = p.id_plataforma
    JOIN patrocinio pt ON c.id_canal = pt.id_canal
    JOIN empresa e ON pt.id_empresa = e.id_empresa;

-- MV 1: Doação Total por Canal (Agregação Pesada)
CREATE MATERIALIZED VIEW MV_DOACAO_TOTAL_CANAL AS
SELECT
    p.nome AS nome_plataforma,
    c.nome AS nome_canal,
    COALESCE(SUM(d.valor), 0.00) AS total_doacao_bruta
FROM
    video v
    INNER JOIN canal c ON v.id_canal = c.id_canal
    and v.id_plataforma = c.id_plataforma
    INNER JOIN plataforma p ON v.id_plataforma = p.id_plataforma -- Joins usando as chaves compostas completas para performance e correção
    LEFT JOIN comentario cm ON v.id_plataforma = c.id_plataforma
    AND v.id_canal = cm.id_canal
    AND v.id_video = cm.id_video
    LEFT JOIN doacao d ON cm.id_plataforma = c.id_plataforma
    AND cm.id_video = d.id_video
    AND cm.id_canal = d.id_canal
    AND cm.id_usuario = d.id_usuario
    and cm.id_comentario = d.id_comentario
GROUP BY
    p.nome,
    c.nome;

-- MV 2: Faturamento Total Agregado (Depende da MV 1 e das Views Virtuais)
CREATE MATERIALIZED VIEW MV_FATURAMENTO_TOP_CANAIS AS
SELECT
    p.nome AS nome_plataforma,
    c.nome AS nome_canal,
    COALESCE(vcp_aggr.receita_patrocinio, 0.00) AS receita_patrocinio,
    COALESCE(vrmb.receita_membros_bruta, 0.00) AS receita_membros,
    COALESCE(mdtc.total_doacao_bruta, 0.00) AS receita_doacao,
    -- Soma total
    COALESCE(vcp_aggr.receita_patrocinio, 0.00)
      + COALESCE(vrmb.receita_membros_bruta, 0.00)
      + COALESCE(mdtc.total_doacao_bruta, 0.00) AS faturamento_total
FROM
    canal c
    INNER JOIN plataforma p ON c.id_plataforma = p.id_plataforma
    LEFT JOIN (
        SELECT nome_plataforma, nome_canal, SUM(valor_patrocinio) AS receita_patrocinio
        FROM VW_CANAL_RECEITA_PATROCINIO
        GROUP BY nome_plataforma, nome_canal
    ) vcp_aggr ON p.nome = vcp_aggr.nome_plataforma AND c.nome = vcp_aggr.nome_canal
    LEFT JOIN VW_RECEITA_MEMBROS_BRUTA vrmb ON p.nome = vrmb.nome_plataforma AND c.nome = vrmb.nome_canal
    LEFT JOIN MV_DOACAO_TOTAL_CANAL mdtc ON p.nome = mdtc.nome_plataforma AND c.nome = mdtc.nome_canal;

-- MV 3: Total de Visualizações por Canal (Substituto do Trigger antigo)
CREATE MATERIALIZED VIEW MV_CANAL_VISUALIZACOES AS
select
    p.nome as nome_plataforma,
    c.nome as nome_canal,
    SUM(visu_total) as total_visualizacoes
FROM
    video v
    inner join plataforma p on p.id_plataforma = v.id_plataforma
    inner join canal c on c.id_canal = v.id_canal
GROUP BY
    p.nome,
    c.nome;

REFRESH MATERIALIZED VIEW MV_DOACAO_TOTAL_CANAL;

REFRESH MATERIALIZED VIEW MV_FATURAMENTO_TOP_CANAIS;

REFRESH MATERIALIZED VIEW MV_CANAL_VISUALIZACOES;