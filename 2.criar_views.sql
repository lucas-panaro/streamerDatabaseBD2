SET search_path TO streamerdb;

DROP VIEW IF EXISTS VW_RECEITA_MEMBROS_BRUTA;
DROP VIEW IF EXISTS VW_RECEITA_DOACAO_POR_VIDEO;
DROP VIEW IF EXISTS VW_CANAL_RECEITA_PATROCINIO;
DROP MATERIALIZED VIEW IF EXISTS MV_FATURAMENTO_TOP_CANAIS;
DROP MATERIALIZED VIEW IF EXISTS MV_DOACAO_TOTAL_CANAL;


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


CREATE OR REPLACE VIEW VW_RECEITA_DOACAO_POR_VIDEO AS
SELECT
    v.id_video,
    v.id_canal,
    v.titulo AS titulo_video,
    SUM(d.valor) AS total_doado
FROM video v
JOIN comentario cm ON v.id_video = cm.id_video AND v.id_canal = cm.id_canal
JOIN doacao d ON cm.id_comentario = d.id_comentario
GROUP BY v.id_video, v.id_canal, v.titulo;


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


CREATE MATERIALIZED VIEW MV_DOACAO_TOTAL_CANAL AS
SELECT
    v.id_canal,
    c.nome AS nome_canal,
    SUM(rdv.total_doado) AS total_doacao_bruta 
FROM video v
JOIN VW_RECEITA_DOACAO_POR_VIDEO rdv ON v.id_video = rdv.id_video
JOIN canal c ON v.id_canal = c.id_canal
GROUP BY v.id_canal, c.nome;


CREATE MATERIALIZED VIEW MV_FATURAMENTO_TOP_CANAIS AS
SELECT
    c.id_canal,
    c.nome AS nome_canal,
    COALESCE(vcp.valor_patrocinio, 0.00) AS receita_patrocinio,
    COALESCE(vrmb.receita_membros_bruta, 0.00) AS receita_membros,
    COALESCE(mdtc.total_doacao_bruta, 0.00) AS receita_doacao,
    COALESCE(vcp.valor_patrocinio, 0.00) + COALESCE(vrmb.receita_membros_bruta, 0.00) + COALESCE(mdtc.total_doacao_bruta, 0.00) AS faturamento_total
FROM canal c
LEFT JOIN VW_CANAL_RECEITA_PATROCINIO vcp ON c.id_canal = vcp.id_canal
LEFT JOIN VW_RECEITA_MEMBROS_BRUTA vrmb ON c.id_canal = vrmb.id_canal
LEFT JOIN MV_DOACAO_TOTAL_CANAL mdtc ON c.id_canal = mdtc.id_canal;


REFRESH MATERIALIZED VIEW MV_DOACAO_TOTAL_CANAL;
REFRESH MATERIALIZED VIEW MV_FATURAMENTO_TOP_CANAIS;