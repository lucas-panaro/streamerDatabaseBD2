# Streamer Database

## Sobre o projeto

Este é um projeto de banco de dados feito para a matéria TCC00335 - PROJETO DE BANCO DE DADOS PARA SISTEMAS DE INFORMAÇÃO.

Turma: A1

Período: 2025/2º

Professor: Marcos Vinicius Naves Bedo

Alunos:

- Lucas Santana Panaro
- Rafael Dos Anjos
- Rafaela Fonseca
- Arthur Octávio

## Passos para execução dos arquivos

1 - Executar arquivo 0.criar_database.sql. Este arquivo irá gerar a database streamerdb.

2 - Reconectar ao postgres selecionando o database streamerdb.

3 - Executar arquivo 1.criar_tabelas.sql. Este arquivo irá gerar o schema streamerdb (se já não existir), remover as tabelas (se já existirem) e criar as tabelas necessárias.

4 - Executar arquivo 2.criar_views.sql.

5 - Executar arquivo 3.criar_indexes.sql.

6 - Executar arquivo 4.criar_triggers.sql.

6 - Executar arquivo 5.criar_functions.sql. Este arquivo cria as functions que permitem popular as tabelas com os dados.

7 - Executar arquivo 6.popular_tabelas_dados_ficticios.sql. Este arquivo irá popular as tabelas criadas com dados artificiais.

8- Executar arquivo 7.executar_consultas.sql.

## Criação das tabelas

Iniciamos a criação das tabelas a partir do modelo relacional proposto pelo professor, e optamos por algumas adaptações, para simplificar a utilização de chaves estrangeiras. O modelo foi implementado utilizando UUIDs como chaves primárias para as tabelas principais (canal, video, comentario, doacao), e chaves compostas quando necessário, para garantir escalabilidade e integridade referencial.

São elas:

- Criação da PK com uuid artificial para a tabela canal. Fizemos isso, pois a chave candidata para PK teria 2 atributos e esta tabela está referenciada em 3 outras tabelas (video, patrocinio e nivel_canal).

- Criação de um uuid artificial para a tabela vídeo, e criação da PK composta com id_canal. Fizemos isso, pois a chave candidata para PK teria 4 atributos e esta tabela está referenciada em 2 outras tabelas (participa e comentario) e, dada a grande quantidade de vídeos esperados, optamos por termos a PK como a combinação do canal e do video.

- Criação de um uuid artificial para a tabela comentario, e criação da PK composta com id_canal e id_video. Fizemos isso, pois a chave candidata para PK teria 3 atributos e esta tabela está referenciada em 2 outras tabelas (doacao e comentario(referência a própria tabela)) e, dada a grande quantidade de comentários para cada vídeo esperados, optamos por termos a PK como a combinação do canal e do video.

- Criação de um uuid artificial para a tabela doacao. Fizemos isso, pois a chave candidata para PK teria 2 atributos e esta tabela está referenciada em 4 outras tabelas (bitcoin, paypal, cartao_credito, mecanismo_plat), além da mesma expectativa acima da grande quantidade de dados inseridos estourarem a quantidade de uuids disponíveis.

- <b>Além disso, todas as FKs e PKs seguem o padrão do modelo relacional, com restrições de unicidade e not null apropriadas.</b>

Observação: Não há uso de ids artificiais sequenciais para as tabelas principais. Utilizamos UUIDs e chaves compostas para garantir unicidade e escalabilidade. Foram criadas também constraints Not Null, observando cada cenário.

## Criação das Views

Foram definidas **5 Visões** (3 Virtuais e 2 Materializadas) no arquivo `2.criar_views.sql` para pré-calcular dados complexos e otimizar as 8 consultas obrigatórias, com foco na eficiência e no uso adequado de cada tipo de visão:

### Visões Virtuais (Atualização em Tempo Real)

As **Visões Virtuais** (`VW_`) foram escolhidas para dados que podem ser filtrados ou que dependem de transações recentes (patrocínio vigente, doações recentes):

- **`VW_RECEITA_MEMBROS_BRUTA`**: Calcula a receita mensal bruta por canal, somando os valores de cada nível de inscrição vigente. É essencial para as consultas que envolvem faturamento de membros (Consultas 2, 6 e 8), pois os dados de `inscricao` (membros vigentes) precisam ser lidos em tempo real.

- **`VW_CANAL_RECEITA_PATROCINIO`**: Simplifica a consulta de patrocínio vigente, relacionando o canal, a empresa patrocinadora e o valor do patrocínio. Utilizada nas Consultas 1, 5 e 8.

### Visões Materializadas (Otimização para Rankeamento Pesado)

As **Visões Materializadas** (`MV_`) foram escolhidas para agregações pesadas que mudam com pouca frequência (como o total de doações ou o faturamento total), otimizando as consultas de ranking (top _k_ canais):

- **`MV_DOACAO_TOTAL_CANAL`**: Calcula a soma total de doações recebidas por cada canal. A agregação de doações ao longo de todos os vídeos é uma operação custosa, e materializá-la otimiza a Consulta 7 (ranking de doações) e a composição da `MV_FATURAMENTO_TOP_CANAIS`.
- **`MV_FATURAMENTO_TOP_CANAIS`**: Combina as três fontes de receita (Patrocínio, Membros, Doações) em um único registro de faturamento total para cada canal. Esta agregação é a mais custosa do sistema e materializá-la garante a máxima performance para a Consulta 8 (ranking de faturamento total). O cálculo utiliza as views virtuais anteriores.
- **`MV_CANAL_VISUALIZACOES`**: Soma do total de visualizações dos vídeos de cada canal.

## Criação de Indices

Para otimizar o desempenho das buscas e das operações de junção nas consultas obrigatórias (principalmente as que envolvem faturamento e listagem), foram definidos **5 Índices de Apoio** no arquivo `3.criar_indexes.sql`. A escolha destes índices visou minimizar o _overhead_ de inserção, focando em colunas que são chaves estrangeiras ou que são frequentemente usadas em filtros e ordenações:

- **`idx_mdtc_total_doacao`**: Criado na coluna `total_doacao_bruta` da view materializada `MV_DOACAO_TOTAL_CANAL`. Otimiza o sort e filtra os resultados que não serão retornados nas consultas.

- **`idx_mftc_total`**: É um índice **composto** criado nas colunas `faturamento_total` e `nome_plataforma` da view materializada `MV_FATURAMENTO_TOP_CANAIS`. Otimiza o sort e o filtra dos resultados.

- **`idx_patrocinio_valor`**: Criado nas colunas `valor` da tabela `patrocinio`. Otimiza o sort e o filtra dos resultados.

- **`idx_plataforma_nome`**: Criado na coluna `nome` da tabela `plataforma`. Auxilia nos filtros de busca em multiplas consultas.
- **`idx_canal_nome`**: Criado na coluna `nome` da tabela `canal`. Auxilia nos filtros de busca em multiplas consultas.

## Criação de Triggers

Foram implementadas **4 Triggers** no arquivo `4.criar_triggers.sql` para garantir a consistência e a integridade do banco de dados, conforme as regras de negócio e os requisitos de atributos derivados:

- **`tg_user_count` (Função: `fn_update_user_count`)**: Responsável por manter a consistência do atributo derivado `qtd_users` na tabela `plataforma`. Esta trigger é acionada **APÓS** uma inserção ou remoção na tabela `plataforma_usuario`, atualizando automaticamente o contador de usuários na plataforma correspondente.
- **`tg_view_count` (Função: `fn_update_view_count`)**: Responsável por manter a consistência do atributo derivado `qtd_visualizacoes` na tabela `canal`. É acionada **APÓS** uma inserção ou remoção na tabela `video`, somando ou subtraindo o `visu_total` do canal relacionado. --A ser substituida por uma view materializada com atualização via cronjob.
- **`tg_check_status_doacao` (Função: `fn_check_status_doacao`)**: Atua **ANTES** de qualquer inserção ou atualização na tabela `doacao`. Esta trigger garante que o campo `status` só receba valores válidos (como 'RECUSADA', 'RECEBIDA', 'LIDA' ou 'CONFIRMADA'), atendendo a um requisito de consistência de dados do projeto.
- **`tg_check_streamer` (Função: `fn_check_streamer_exists`)**: Atua **ANTES** da inserção na tabela `streamer_pais`. Sua função é garantir a integridade referencial e a lógica de negócio, assegurando que o `nick_streamer` a ser inserido já exista na tabela `usuario` (validando o subtipo).
- **`tg_update_channel_views` (Função: `fn_update_channel_views`)**: Atua **DEPOIS** de update na tabela `video`, porém a atualização é realizada apenas se random_value for = 1, o que limita a atualização a uma chance de 1 em 1000 atualizações de um canal específico. Sua função é atualizar a quantidade de visualizações de cada canal.

- Foi criada a function fn_update_all_channel_views(), que irá atualizar a quantidade de visualisações de todos canais do Banco. Seria utilizado um Cron de hora em hora que faria este update completo, garantindo que o dado esteja atualizado, além da atualização randomica acima.

## Criação dos dados artificiais

Para criação dos dados artificiais, optamos por criar functions responsáveis pela inserção dos dados com a criação das chaves estrangeiras e garantindo a integridade. Após as functions criadas, criamos outras functions que populam o banco utilizando as functions anteriores, simulando a criação natural de dados.

## Consultas

Todas as consultas foram implementadas como **Functions** no arquivo `6.executar_consultas.sql`, utilizando a linguagem **PL/pgSQL** ou **SQL** (conforme aplicável) e fazendo uso das Views e Índices criados para garantir alta performance.

As funções com parâmetro `DEFAULT NULL` ou `k` atendem ao requisito de ter parâmetros opcionais ou de listar os _top k_ elementos.

### 1. Detalhamento das Funções Parametrizadas (Com Filtro Opcional)

- **Consulta 1: Canais Patrocinados** (`canais_patrocinados(_empresa_tax_id VARCHAR DEFAULT NULL)`): Lista canais e o valor do patrocínio vigente. A função otimiza o filtro por empresa patrocinadora, retornando todos os patrocínios se `_empresa_tax_id` for nulo.
- **Consulta 2: Valor Desembolsado por Membro** (`fn_membros_valor_desembolsado(_nick_usuario VARCHAR DEFAULT NULL)`): Calcula a quantidade de canais que cada usuário é membro e a soma do valor mensal desembolsado por ele. Permite filtro opcional para focar em um `_nick_usuario` específico.
- **Consulta 3: Doações Recebidas por Canal** (`fn_canais_doacao_recebida(_id_canal UUID DEFAULT NULL)`): Lista e ordena os canais que receberam doações. **Otimização:** Utiliza a **`MV_DOACAO_TOTAL_CANAL`** para acesso rápido aos valores totais agregados e permite filtro opcional por `_id_canal`.
- **Consulta 4: Soma de Doações Lidas por Vídeo** (`fn_doacoes_lidas_por_video(_id_video UUID DEFAULT NULL)`): Lista a soma das doações geradas por comentários cujo `status` é **'LIDA'**, agregadas por vídeo. **Otimização:** A filtragem por `status = 'LIDA'` é acelerada pelo índice **`idx_doacao_status_idcomentario`**, permitindo também filtro opcional por `_id_video`.

### 2. Detalhamento das Funções de Ranking (Top K)

- **Consulta 5: Top K Patrocínio** (`fn_top_k_patrocinio(k INTEGER)`): Lista e ordena os **k** canais com maior valor de patrocínio. **Otimização:** Usa a **`VW_CANAL_RECEITA_PATROCINIO`** para dados em tempo real e aplica `ORDER BY` e `LIMIT k`.
- **Consulta 6: Top K Aportes de Membros** (`fn_top_k_membros(k INTEGER)`): Lista e ordena os **k** canais com maior receita de aportes mensais de membros. **Otimização:** Utiliza a **`VW_RECEITA_MEMBROS_BRUTA`** e aplica `ORDER BY` e `LIMIT k`.
- **Consulta 7: Top K Doações Recebidas** (`fn_top_k_doacoes(k INTEGER)`): Lista e ordena os **k** canais que mais receberam doações (total acumulado). **Otimização:** Executa o `REFRESH MATERIALIZED VIEW MV_DOACAO_TOTAL_CANAL` para garantir a atualização dos dados antes de rankear com `ORDER BY` e `LIMIT k`.
- **Consulta 8: Top K Faturamento Total** (`fn_top_k_faturamento_total(k INTEGER)`): Lista e ordena os **k** canais que mais faturam, considerando as três fontes de receita (Patrocínio, Membros e Doações). **Otimização:** Executa o `REFRESH MATERIALIZED VIEW MV_FATURAMENTO_TOP_CANAIS` e rankeia o faturamento total agregado.

## Perguntas Revisão parcial:

1 - Na descrição do modelo tem "Cada canal é identificado por seu nome único, data de início, descrição, quantidade de vídeos postados e"
mas no modelo relacional tem
-- Quantidade de visualizações qtd_visualizações é atributo derivado e requer atualização
Canal(nome, tipo, data, desc, qtd_visualizacoes, nick_streamer, nro_plataforma)
nro_plataforma referencia Plataforma(nro)
nick_streamer referencia Usuario(nick)

Devemos usar a qnt de videos ou de visualizações?

2 - "tipo do canal que deve ser um entre {privado, público ou misto}."
"Para cada doação é necessário armazenar o status que só pode ser um dos três {recusado, recebido ou lido}."

-> Precisamos criar um Type, ou resolveria no backend?
https://www.postgresql.org/docs/current/datatype-enum.html

3 -
"O sistema não armazena o histórico de patrocínios, ou seja, apenas os patrocinadores com patrocínios vigentes devem aparecer nos sistema."
"O sistema não armazena o histórico de membros, ou seja, apenas os membros vigentes devem aparecer no sistema."
-> devemos lidar com isso no db?

4 - Nas consultas tem "Dar a opção de filtrar os resultados por empresa como um parâmetro opcional na forma de uma stored procedure."
As consultas são uma function e tem tbm uma stored procedure que muda o parametro? não entendi isso.
Não posso fazer apenas uma function com um parametro nullable?
Ex:

```sql
create or replace function canais_patrocinados(_nro_empresa int default null)
returns table (nome_canal varchar, valor numeric)
as $$
    select c.nome, p.valor
    from canal c
    inner join patrocinio p on c.nro_canal = p.nro_canal
    where _nro_empresa is null or p.nro_empresa = _nro_empresa
    $$ language sql;

```

5 - **Chave Composta `(nro_canal, nivel)`:** Na tabela `inscricao`, a chave estrangeira faz referência a `(nro_canal, nivel)` da tabela `nivel_canal`. Embora `(nro_canal, nivel)` seja a `PRIMARY KEY` de `nivel_canal`, **não seria mais eficiente** criar uma chave primária artificial (`id_nivel_canal` SERIAL) em `nivel_canal` para ser referenciada como FK simples na tabela `inscricao`, em vez de uma FK composta, melhorando a velocidade de _join_?

6 - **Restrição de Domínio (`tipo` e `status`):** Conforme a Pergunta 2 do _README_, campos como `canal.tipo` (`privado`, `público`, `misto`) e `doacao.status` (`recusado`, `recebido`, `lido`) **devem ter restrição de domínio na camada de BD**. Embora a validação de `status` tenha sido feita via **Trigger**, a migração para o tipo nativo **`ENUM`** do PostgreSQL **não seria a solução mais canônica e performática** para garantir a validade dos dados sem o _overhead_ de `TRIGGER` para cada inserção/atualização?

7 - **Precisão em Conversão de Moeda:** O campo `conversao.fator_conversao_dolar` é um `NUMERIC(10, 4)`. Dada a volatilidade do mercado e a necessidade de alta precisão em operações financeiras, **a precisão de 4 casas decimais é suficiente** ou deveríamos considerar um `NUMERIC(18, 8)` ou superior, para garantir que os cálculos de conversão para dólar não introduzam erros de arredondamento?

8 - **Otimização de Atributo Derivado (Qtd. Visualizações):** A Trigger **`tg_view_count`** atualiza a `qtd_visualizacoes` do `canal` a cada inserção/deleção na tabela `video`. Dado que `qtd_visualizacoes` é uma soma sobre a coluna `visu_total` de `video`, **o custo de execução desta Trigger a cada inserção de vídeo (escrevendo na tabela `canal`) compensa o benefício de ter o dado pré-calculado**, ou seria mais eficiente criar uma **View Materializada** simples sobre `canal` e `video` para agregar a visualização e atualizá-la agendadamente?

9 - **Uso de Views Materializadas e Concorrência:** As Views Materializadas (`MV_DOACAO_TOTAL_CANAL`, `MV_FATURAMENTO_TOP_CANAIS`) são atualizadas dentro das Functions de consulta (`C7` e `C8`). Dada a possibilidade de `REFRESH MATERIALIZED VIEW` bloquear leituras, **não seria obrigatório** adicionar a cláusula `CONCURRENTLY` e um `UNIQUE INDEX` na `MV` para evitar bloqueios em ambiente de produção, visto que o Faturamento Total é um cálculo pesado?

10 - **Otimização do `search_path`:** O comando `SET search_path TO streamerdb;` é repetido no início de _cada_ função e trigger. **Isso é necessário ou há uma maneira mais eficiente** de configurar o _schema_ padrão globalmente ou por conexão, minimizando a repetição do comando no código procedural?
