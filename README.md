# Streamer Database

## Sobre o projeto

Este é um projeto de banco de dados feito para a matéria TCC00335 - PROJETO DE BANCO DE DADOS PARA SISTEMAS DE INFORMAÇÃO.

Turma: A1

Período: 2025/2º

Professor: Marcos Vinicius Naves Bedo

Alunos:

- Lucas Santana Panaro
- Rodrigo Dias
- Rafael Dos Anjos
- Rafaela Fonseca
- Arthur Octávio
- Lucca Amaral

## Passos para execução dos arquivos

1 - Executar arquivo 0.criar_database.sql. Este arquivo irá gerar a database streamerdb.

2 - Reconectar ao postgres selecionando o database streamerdb.

3 - Executar arquivo 1.criar_tabelas.sql. Este arquivo irá gerar o schema streamerdb (se já não existir), remover as tabelas(se já existirem) e criar as tabelas necessárias.

4 - Executar arquivo 2.criar_views.sql.

5 - Executar arquivo 3.criar_indexes.sql.

6 - Executar arquivo 4.criar_triggers.sql.

7 - Executar arquivo 5.popular_tabelas_dados_ficticios.sql. Este arquivo irá popular as tabelas criadas com dados artificiais.

8- Executar arquivo 6.executar_consultas.sql.

## Criação das tabelas

Iniciamos a criação das tabelas a partir do modelo relacional proposto pelo professor, e optamos por algumas adaptações, para simplificar a utilização de chaves estrangeiras.
São elas:

- Criação de um id artificial para a tabela canal. Fizemos isso, pois a chave candidata para PK teria 2 atributos e esta tabela está referenciada em 3 outras tabelas (video, patrocinio e nivel_canal).

- Criação de um id artificial para a tabela vídeo. Fizemos isso, pois a chave candidata para PK teria 4 atributos e esta tabela está referenciada em 2 outras tabelas (participa e comentario).

- Criação de um id artificial para a tabela comentario. Fizemos isso, pois a chave candidata para PK teria 3 atributos e esta tabela está referenciada em 2 outras tabelas (doacao e comentario(referência a própria tabela)).

- Criação de um id artificial para a tabela doacao. Fizemos isso, pois a chave candidata para PK teria 2 atributos e esta tabela está referenciada em 4 outras tabelas (bitcoin, paypal, cartao_credito, mecanismo_plat).

- <b>Além disso, foram criadas restrições unique na chave candidata original para todos os 3 casos acima.</b>

Foram criadas também constraints Not Null, observando cada cenário.

## Criação das Views

TODO

## Criação de Indices

TODO

## Criação de Triggers

TODO

## Criação dos dados artificiais

Para criação dos dados artificiais, foi utilizado o Google Gemini, com o seguinte prompt:

```
Dado a DDL de banco de dados, crie comandos SLQ para inserção de dados artificiais.
Para as plataformas, use as mais comuns ( youtube, twich, rumble, etc).
Crie pelo menos:
 - 5 plataformas
 - 5 moedas
 - 5 paises
 - 100 empresas de patrocinio
 - 1000 usuários
 - 1000 comentários
 - 500 canais
 - 3 niveis_canal para cada canal
 - 1200 inscrições
 - 200 patrocinios
 - 300 doações com diferentes tipos de pagamentos (distribuidos igualmente entre elas)

Não há garantia que o 1o Id inserido em uma tabela cuja PK é sequencial tenha o Id = 1.
Adicione truncate para limpar as tabelas antes das inserções.
Além disso, deve-se previnir conflitos, substituindo o dado pelo que está sendo inserido desta vez.
Sem funções para criação da massa, gere todos os dados explicitamente.
Retorne apenas um script SQL.
{arquivo criar_tabelas.sql}
```

O retorno obtido foi salvo no arquivo popular_tabelas_dados_ficticios.sql.

## Consultas

TODO

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

```
create or replace function canais_patrocinados(_nro_empresa int default null)
returns table (nome_canal varchar, valor numeric)
as $$
	select c.nome, p.valor
	from canal c
	inner join patrocinio p on c.nro_canal = p.nro_canal
	where _nro_empresa is null or p.nro_empresa = _nro_empresa
	$$ language sql;
```
