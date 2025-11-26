SET search_path TO streamerdb;

DROP MATERIALIZED VIEW IF EXISTS MV_FATURAMENTO_TOP_CANAIS CASCADE;
DROP MATERIALIZED VIEW IF EXISTS MV_DOACAO_TOTAL_CANAL CASCADE;
DROP MATERIALIZED VIEW IF EXISTS MV_CANAL_VISUALIZACOES CASCADE;
DROP VIEW IF EXISTS VW_CANAL_RECEITA_PATROCINIO CASCADE;
DROP VIEW IF EXISTS VW_RECEITA_MEMBROS_BRUTA CASCADE;

-- VIEW 1: Receita Mensal de Membros por Canal
CREATE OR REPLACE VIEW VW_RECEITA_MEMBROS_BRUTA AS
SELECT
    nc.id_canal,
    c.nome AS nome_canal,
    COUNT(i.nick_membro) AS qtd_membros,
    SUM(nc.valor) AS receita_membros_bruta
FROM nivel_canal nc
JOIN inscricao i ON nc.id_canal = i.id_canal AND nc.nivel = i.nivel
JOIN canal c ON nc.id_canal = c.id_canal
GROUP BY nc.id_canal, c.nome;

-- VIEW 2: Canais e Patrocínio Vigente
CREATE OR REPLACE VIEW VW_CANAL_RECEITA_PATROCINIO AS
SELECT
    c.id_canal,
    c.nome AS nome_canal,
    p.empresa_tax_id,
    e.nome AS nome_empresa,
    p.valor AS valor_patrocinio
FROM canal c
JOIN patrocinio p ON c.id_canal = p.id_canal
JOIN empresa e ON p.empresa_tax_id = e.tax_id;

-- MV 1: Doação Total por Canal (Agregação Pesada)
CREATE MATERIALIZED VIEW MV_DOACAO_TOTAL_CANAL AS
SELECT
    v.id_canal,
    c.nome AS nome_canal,
    COALESCE(SUM(d.valor), 0.00) AS total_doacao_bruta 
FROM video v
JOIN canal c ON v.id_canal = c.id_canal
-- Joins usando as chaves compostas completas para performance e correção
LEFT JOIN comentario cm ON v.id_video = cm.id_video AND v.id_canal = cm.id_canal
LEFT JOIN doacao d ON cm.id_comentario = d.id_comentario 
                   AND cm.id_video = d.id_video 
                   AND cm.id_canal = d.id_canal
GROUP BY v.id_canal, c.nome;

-- MV 2: Faturamento Total Agregado (Depende da MV 1 e das Views Virtuais)
CREATE MATERIALIZED VIEW MV_FATURAMENTO_TOP_CANAIS AS
SELECT
    c.id_canal,
    c.nome AS nome_canal,
    COALESCE(vcp.valor_patrocinio, 0.00) AS receita_patrocinio,
    COALESCE(vrmb.receita_membros_bruta, 0.00) AS receita_membros,
    COALESCE(mdtc.total_doacao_bruta, 0.00) AS receita_doacao,
    -- Soma total
    COALESCE(vcp.valor_patrocinio, 0.00) + 
    COALESCE(vrmb.receita_membros_bruta, 0.00) + 
    COALESCE(mdtc.total_doacao_bruta, 0.00) AS faturamento_total
FROM canal c
LEFT JOIN VW_CANAL_RECEITA_PATROCINIO vcp ON c.id_canal = vcp.id_canal
LEFT JOIN VW_RECEITA_MEMBROS_BRUTA vrmb ON c.id_canal = vrmb.id_canal
LEFT JOIN MV_DOACAO_TOTAL_CANAL mdtc ON c.id_canal = mdtc.id_canal;

-- MV 3: Total de Visualizações por Canal (Substituto do Trigger antigo)
CREATE MATERIALIZED VIEW MV_CANAL_VISUALIZACOES AS
SELECT 
    id_canal,
    SUM(visu_total) as total_visualizacoes
FROM video
GROUP BY id_canal;

REFRESH MATERIALIZED VIEW MV_DOACAO_TOTAL_CANAL;
REFRESH MATERIALIZED VIEW MV_FATURAMENTO_TOP_CANAIS;
REFRESH MATERIALIZED VIEW MV_CANAL_VISUALIZACOES;