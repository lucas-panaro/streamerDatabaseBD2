SET search_path TO streamerdb;

DROP INDEX IF EXISTS idx_mdtc_total_doacao;
DROP INDEX IF EXISTS idx_mftc_total;
DROP INDEX IF EXISTS idx_patrocinio_valor;
DROP INDEX IF EXISTS idx_plataforma_nome;
DROP INDEX IF EXISTS idx_canal_nome;

/* 
1-
Indice com seletividade que auxilia a consulta 7. 
Seleciona apenas as linhas com total_doacao_bruta > 0 e ordena em ordem decrescente.
Criado na coluna `total_doacao_bruta` da view materializada `MV_DOACAO_TOTAL_CANAL`. 
Otimiza o sort e filtra os resultados que não serão retornados nas consultas.

Sem o indice, temos:
Limit  (cost=60.27..60.29 rows=1 width=30)
  ->  WindowAgg  (cost=60.27..71.19 rows=624 width=30)
        ->  Sort  (cost=60.27..61.83 rows=624 width=22)
              Sort Key: total_doacao_bruta DESC
              ->  Seq Scan on mv_doacao_total_canal mdtc  (cost=0.00..31.30 rows=624 width=22)
                    Filter: (total_doacao_bruta > '0'::numeric)

Com o indice, temos:
Limit  (cost=0.28..0.39 rows=1 width=30)
  ->  WindowAgg  (cost=0.28..73.25 rows=624 width=30)
        ->  Index Scan using idx_mdtc_total_doacao on mv_doacao_total_canal mdtc  (cost=0.28..63.89 rows=624 width=22)
*/
CREATE INDEX idx_mdtc_total_doacao ON MV_DOACAO_TOTAL_CANAL (total_doacao_bruta DESC) WHERE total_doacao_bruta > 0;

/*
2-
Indice escolhido para otimizar a consulta 8
É um índice **composto** criado nas colunas `faturamento_total` e `nome_plataforma` da view materializada `MV_FATURAMENTO_TOP_CANAIS`. 
Otimiza o sort e o filtra dos resultados.

Sem o indice, temos:
Limit  (cost=33489.44..33489.57 rows=1 width=33)
  ->  WindowAgg  (cost=33489.44..104145.05 rows=537442 width=33)
        ->  Gather Merge  (cost=33489.44..96083.42 rows=537442 width=25)
              Workers Planned: 2
              ->  Sort  (cost=32489.42..33049.25 rows=223934 width=25)
                    Sort Key: faturamento_total DESC
                    ->  Parallel Seq Scan on mv_faturamento_top_canais mftc  (cost=0.00..7231.34 rows=223934 width=25)

Com o indice, temos:
Limit  (cost=0.42..0.49 rows=1 width=33)
  ->  WindowAgg  (cost=0.42..37003.90 rows=537442 width=33)
        ->  Index Scan using idx_mftc_total on mv_faturamento_top_canais mftc  (cost=0.42..28942.27 rows=537442 width=25)
*/
CREATE INDEX idx_mftc_total ON MV_FATURAMENTO_TOP_CANAIS (faturamento_total DESC, nome_plataforma);


/*
3-
Indice escolhido para otimizar a consulta 5, na tabela patrocinio
Criado nas colunas `valor` da tabela `patrocinio`. 
Otimiza o sort e o filtra dos resultados.

Sem o indice, temos:
Limit  (cost=223.10..223.12 rows=1 width=32)
  ->  WindowAgg  (cost=223.10..240.58 rows=999 width=32)
        ->  Sort  (cost=223.10..225.60 rows=999 width=24)
              Sort Key: pt.valor DESC
              ->  Hash Join  (cost=111.80..173.33 rows=999 width=24)
                    Hash Cond: (pt.id_empresa = e.id_empresa)
                    ->  Nested Loop  (cost=61.93..120.83 rows=999 width=40)
                          ->  Hash Join  (cost=61.79..96.52 rows=999 width=48)
                                Hash Cond: (pt.id_canal = c.id_canal)
                                ->  Seq Scan on patrocinio pt  (cost=0.00..20.99 rows=999 width=38)
                                ->  Hash  (cost=40.24..40.24 rows=1724 width=42)
                                      ->  Seq Scan on canal c  (cost=0.00..40.24 rows=1724 width=42)
                          ->  Memoize  (cost=0.14..0.25 rows=1 width=24)
                                Cache Key: c.id_plataforma
                                Cache Mode: logical
                                ->  Index Scan using plataforma_pkey on plataforma p  (cost=0.13..0.24 rows=1 width=24)
                                      Index Cond: (id_plataforma = c.id_plataforma)
                    ->  Hash  (cost=31.05..31.05 rows=1505 width=16)
                          ->  Seq Scan on empresa e  (cost=0.00..31.05 rows=1505 width=16)

Com o indice, temos:
Limit  (cost=0.85..11.22 rows=1 width=32)
  ->  WindowAgg  (cost=0.85..10358.66 rows=999 width=32)
        ->  Nested Loop  (cost=0.85..10343.67 rows=999 width=24)
              ->  Nested Loop  (cost=0.56..10143.98 rows=999 width=40)
                    Join Filter: (c.id_plataforma = p.id_plataforma)
                    ->  Nested Loop  (cost=0.56..10043.99 rows=999 width=48)
                          ->  Index Scan using idx_patrocinio_valor on patrocinio pt  (cost=0.28..49.26 rows=999 width=38)
                          ->  Memoize  (cost=0.29..13.39 rows=1 width=42)
                                Cache Key: pt.id_canal
                                Cache Mode: logical
                                ->  Index Scan using canal_pkey on canal c  (cost=0.28..13.38 rows=1 width=42)
                                      Index Cond: (id_canal = pt.id_canal)
                    ->  Materialize  (cost=0.00..35.07 rows=5 width=24)
                          ->  Seq Scan on plataforma p  (cost=0.00..35.05 rows=5 width=24)
              ->  Memoize  (cost=0.29..0.35 rows=1 width=16)
                    Cache Key: pt.id_empresa
                    Cache Mode: logical
                    ->  Index Only Scan using empresa_pkey on empresa e  (cost=0.28..0.34 rows=1 width=16)
                          Index Cond: (id_empresa = pt.id_empresa)
*/
CREATE INDEX idx_patrocinio_valor ON patrocinio (valor DESC);

/*
4-
Indice composto, criado nas colunas `UPPER(status)` e `id_comentario` da tabela `doacao`.
Auxilia nos filtros de busca da consulta 4, já aplicando o modificador UPPER na coluna status.

Sem o indice, temos:
Sort  (cost=120.30..120.30 rows=1 width=65)
  Sort Key: (COALESCE(sum(d.valor), 0.00)) DESC
  ->  GroupAggregate  (cost=120.26..120.29 rows=1 width=65)
        Group Key: p.nome, c.nome, v.titulo
        ->  Sort  (cost=120.26..120.27 rows=1 width=39)
              Sort Key: p.nome, c.nome, v.titulo
              ->  Nested Loop  (cost=0.97..120.25 rows=1 width=39)
                    Join Filter: (v.id_plataforma = p.id_plataforma)
                    ->  Nested Loop  (cost=0.83..120.00 rows=1 width=79)
                          ->  Nested Loop  (cost=0.56..106.63 rows=1 width=117)
                                ->  Nested Loop  (cost=0.28..106.12 rows=1 width=102)
                                      ->  Seq Scan on doacao d  (cost=0.00..67.00 rows=10 width=70)
                                            Filter: (upper((status)::text) = 'LIDA'::text)
                                      ->  Index Only Scan using comentario_pkey on comentario cm  (cost=0.28..3.90 rows=1 width=64)
                                            Index Cond: ((id_plataforma = d.id_plataforma) AND (id_canal = d.id_canal) AND (id_video = d.id_video) AND (id_comentario = d.id_comentario))
                                ->  Index Scan using video_pkey on video v  (cost=0.28..0.51 rows=1 width=63)
                                      Index Cond: ((id_plataforma = cm.id_plataforma) AND (id_canal = cm.id_canal) AND (id_video = cm.id_video))
                          ->  Index Scan using canal_pkey on canal c  (cost=0.28..13.36 rows=1 width=26)
                                Index Cond: (id_canal = v.id_canal)
                    ->  Index Scan using plataforma_pkey on plataforma p  (cost=0.13..0.24 rows=1 width=24)
                          Index Cond: (id_plataforma = cm.id_plataforma)

Com o indice, temos:
Sort  (cost=80.49..80.49 rows=1 width=65)
  Sort Key: (COALESCE(sum(d.valor), 0.00)) DESC
  ->  GroupAggregate  (cost=80.45..80.48 rows=1 width=65)
        Group Key: p.nome, c.nome, v.titulo
        ->  Sort  (cost=80.45..80.45 rows=1 width=39)
              Sort Key: p.nome, c.nome, v.titulo
              ->  Nested Loop  (cost=5.32..80.44 rows=1 width=39)
                    Join Filter: (v.id_plataforma = p.id_plataforma)
                    ->  Nested Loop  (cost=5.19..80.19 rows=1 width=79)
                          ->  Nested Loop  (cost=4.91..66.82 rows=1 width=117)
                                ->  Nested Loop  (cost=4.63..66.31 rows=1 width=102)
                                      ->  Bitmap Heap Scan on doacao d  (cost=4.36..27.19 rows=10 width=70)
                                            Recheck Cond: (upper((status)::text) = 'LIDA'::text)
                                            ->  Bitmap Index Scan on idx_doacao_status_idcomentario  (cost=0.00..4.35 rows=10 width=0)
                                                  Index Cond: (upper((status)::text) = 'LIDA'::text)
                                      ->  Index Only Scan using comentario_pkey on comentario cm  (cost=0.28..3.90 rows=1 width=64)
                                            Index Cond: ((id_plataforma = d.id_plataforma) AND (id_canal = d.id_canal) AND (id_video = d.id_video) AND (id_comentario = d.id_comentario))
                                ->  Index Scan using video_pkey on video v  (cost=0.28..0.51 rows=1 width=63)
                                      Index Cond: ((id_plataforma = cm.id_plataforma) AND (id_canal = cm.id_canal) AND (id_video = cm.id_video))
                          ->  Index Scan using canal_pkey on canal c  (cost=0.28..13.36 rows=1 width=26)
                                Index Cond: (id_canal = v.id_canal)
                    ->  Index Scan using plataforma_pkey on plataforma p  (cost=0.13..0.24 rows=1 width=24)
                          Index Cond: (id_plataforma = cm.id_plataforma)


*/
CREATE INDEX idx_doacao_status_idcomentario ON doacao(UPPER(status), id_comentario);


/*
5-
Criado na coluna `nome` da tabela `canal`. Auxilia nos filtros de busca em multiplas consultas.
*/
CREATE INDEX  idx_canal_nome ON canal(nome);