create schema if not exists streamerdb;
set search_path to streamerdb;

drop table if exists empresa cascade;
drop table if exists plataforma cascade;
drop table if exists conversao cascade;
drop table if exists pais cascade;
drop table if exists usuario cascade;
drop table if exists plataforma_usuario cascade;
drop table if exists streamer_pais cascade;
drop table if exists empresa_pais cascade;
drop table if exists canal cascade;
drop table if exists patrocinio cascade;
drop table if exists nivel_canal cascade;
drop table if exists inscricao cascade;
drop table if exists video cascade;
drop table if exists participa cascade;
drop table if exists comentario cascade;
drop table if exists doacao cascade;
drop table if exists bitcoin cascade;
drop table if exists paypal cascade;
drop table if exists cartao_credito cascade;
drop table if exists mecanismo_plat cascade;

CREATE TABLE empresa (
    tax_id        VARCHAR(50) PRIMARY KEY,
    nome          VARCHAR(100) NOT NULL,
    nome_fantasia VARCHAR(100)
);

CREATE TABLE plataforma (
    nro             SERIAL PRIMARY KEY,
    nome            VARCHAR(100) UNIQUE NOT NULL,
    qtd_users       INTEGER DEFAULT 0,       -- Atributo derivado (pode ser atualizado por TRIGGER)
    empresa_fundadora    VARCHAR(50) NOT NULL,
    empresa_responsavel   VARCHAR(50) NOT NULL,
    data_fund       DATE NOT NULL,
    FOREIGN KEY (empresa_fundadora) REFERENCES empresa(tax_id),
    FOREIGN KEY (empresa_responsavel) REFERENCES empresa(tax_id)
);

CREATE TABLE conversao (
    moeda                   VARCHAR(10) PRIMARY KEY,
    nome                    VARCHAR(50) NOT NULL,
    fator_conversao_dolar   NUMERIC(10, 4) NOT NULL
);

CREATE TABLE pais (
    DDI           VARCHAR(5) PRIMARY KEY,
    nome          VARCHAR(100) NOT NULL,
    moeda         VARCHAR(10) NOT NULL,
    FOREIGN KEY (moeda) REFERENCES conversao(moeda)
);

CREATE TABLE usuario (
    nick            VARCHAR(50) PRIMARY KEY,
    email           VARCHAR(100) UNIQUE NOT NULL,
    data_nasc       DATE,
    telefone        VARCHAR(20),
    end_postal      VARCHAR(200),
    pais_residencia VARCHAR(5) NOT NULL,
    FOREIGN KEY (pais_residencia) REFERENCES pais(DDI)
);

CREATE TABLE plataforma_usuario (
    nro_plataforma  INTEGER NOT NULL,
    nick_usuario    VARCHAR(50) NOT NULL,
    nro_usuario     VARCHAR(50),
    PRIMARY KEY (nro_plataforma, nick_usuario),
    FOREIGN KEY (nro_plataforma) REFERENCES plataforma(nro),
    FOREIGN KEY (nick_usuario) REFERENCES usuario(nick)
);

CREATE TABLE streamer_pais (
    nick_streamer   VARCHAR(50) NOT NULL,
    ddi_pais        VARCHAR(5) NOT NULL,
    nro_passaporte  VARCHAR(50),
    PRIMARY KEY (nick_streamer, ddi_pais),
    FOREIGN KEY (nick_streamer) REFERENCES usuario(nick),
    FOREIGN KEY (ddi_pais) REFERENCES pais(DDI)
);

CREATE TABLE empresa_pais (
    empresa_tax_id VARCHAR(50) NOT NULL,
    ddi_pais    VARCHAR(5) NOT NULL,
    id_nacional VARCHAR(50),
    PRIMARY KEY (empresa_tax_id, ddi_pais),
    FOREIGN KEY (empresa_tax_id) REFERENCES empresa(tax_id),
    FOREIGN KEY (ddi_pais) REFERENCES pais(DDI)
);

CREATE TABLE canal (
    id_canal            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome                VARCHAR(100) NOT NULL,
    nro_plataforma      INTEGER NOT NULL,
    tipo                VARCHAR(50),
    data_criacao        DATE NOT NULL,
    desc_canal          TEXT,
    qtd_visualizacoes   BIGINT DEFAULT 0,   -- Atributo derivado (pode ser atualizado por TRIGGER)
    nick_streamer       VARCHAR(50) NOT NULL,
    UNIQUE (nome, nro_plataforma),
    FOREIGN KEY (nro_plataforma) REFERENCES plataforma(nro),
    FOREIGN KEY (nick_streamer) REFERENCES usuario(nick)
);

CREATE TABLE patrocinio (
    empresa_tax_id     VARCHAR(50) NOT NULL,
    id_canal        UUID NOT NULL,
    valor           NUMERIC(12, 2) NOT NULL,
    PRIMARY KEY (empresa_tax_id, id_canal),
    FOREIGN KEY (empresa_tax_id) REFERENCES empresa(tax_id),
    FOREIGN KEY (id_canal) REFERENCES canal(id_canal)
);


CREATE TABLE nivel_canal (
    id_canal        UUID NOT NULL,
    nivel           VARCHAR(50) NOT NULL,
    valor           NUMERIC(10, 2) NOT NULL,
    gif             VARCHAR(200),
    PRIMARY KEY (id_canal, nivel),
    FOREIGN KEY (id_canal) REFERENCES canal(id_canal)
);


CREATE TABLE inscricao (
    id_canal        UUID NOT NULL,
    nick_membro     VARCHAR(50) NOT NULL,
    nivel           VARCHAR(50) NOT NULL,
    PRIMARY KEY (id_canal, nick_membro),
    FOREIGN KEY (nick_membro) REFERENCES usuario(nick),
    FOREIGN KEY (id_canal, nivel) REFERENCES nivel_canal(id_canal, nivel)
);

CREATE TABLE video (
    id_canal        UUID NOT NULL,
    id_video        UUID NOT NULL,
    titulo          VARCHAR(200) NOT NULL,
    dataH           TIMESTAMP NOT NULL,
    tema            VARCHAR(100),
    duracao         INTERVAL,
    visu_simul      INTEGER DEFAULT 0,
    visu_total      BIGINT DEFAULT 0,
    PRIMARY KEY (id_canal, id_video),
    UNIQUE (id_canal, titulo, dataH),
    FOREIGN KEY (id_canal) REFERENCES canal(id_canal)
);

CREATE TABLE participa (
    id_canal        UUID NOT NULL,
    id_video        UUID NOT NULL,
    nick_streamer   VARCHAR(50) NOT NULL,
    PRIMARY KEY (id_canal, id_video, nick_streamer),
    FOREIGN KEY (id_canal, id_video) REFERENCES video(id_canal, id_video),
    FOREIGN KEY (nick_streamer) REFERENCES usuario(nick)
);

CREATE TABLE comentario (
    id_canal                  UUID NOT NULL,
    id_video                  UUID NOT NULL,
    id_comentario             UUID NOT NULL,
    nick_usuario              VARCHAR(50) NOT NULL,
    seq                       INTEGER NOT NULL,
    texto                     TEXT,
    dataH                     TIMESTAMP NOT NULL,
    comentario_original_id_canal       UUID,
    comentario_original_id_video       UUID,
    comentario_original_id             UUID,
    PRIMARY KEY (id_canal, id_video, id_comentario),
    UNIQUE (id_canal, id_video, nick_usuario, seq),
    FOREIGN KEY (id_canal, id_video) REFERENCES video(id_canal, id_video),
    FOREIGN KEY (nick_usuario) REFERENCES usuario(nick),
    FOREIGN KEY (comentario_original_id_canal, comentario_original_id_video, comentario_original_id) REFERENCES comentario(id_canal, id_video, id_comentario)
);

CREATE TABLE doacao (
    id_canal        UUID NOT NULL,
    id_video        UUID NOT NULL,
    id_comentario   UUID NOT NULL,
    id_doacao       UUID NOT NULL,
    valor           NUMERIC(10, 2) NOT NULL,
    seq_pg          INTEGER NOT NULL,
    status          VARCHAR(20),
    PRIMARY KEY (id_canal, id_video, id_comentario, id_doacao),
    UNIQUE (id_comentario, seq_pg),
    FOREIGN KEY (id_canal,id_video, id_comentario) REFERENCES comentario(id_canal, id_video, id_comentario)
);

CREATE TABLE bitcoin (
    id_canal        UUID NOT NULL,
    id_video        UUID NOT NULL,
    id_comentario   UUID NOT NULL,
    id_doacao       UUID NOT NULL,
    TxID        VARCHAR(100) UNIQUE NOT NULL,
    FOREIGN KEY (id_canal,id_video, id_comentario,id_doacao) REFERENCES doacao(id_canal,id_video, id_comentario,id_doacao)
);

CREATE TABLE paypal (
    id_canal        UUID NOT NULL,
    id_video        UUID NOT NULL,
    id_comentario   UUID NOT NULL,
    id_doacao       UUID NOT NULL,
    IdPayPal    VARCHAR(100) UNIQUE NOT NULL,
    FOREIGN KEY (id_canal,id_video, id_comentario,id_doacao) REFERENCES doacao(id_canal,id_video, id_comentario,id_doacao)
);

CREATE TABLE cartao_credito (
    id_canal        UUID NOT NULL,
    id_video        UUID NOT NULL,
    id_comentario   UUID NOT NULL,
    id_doacao       UUID NOT NULL,
    nro         VARCHAR(20) NOT NULL,
    bandeira    VARCHAR(50) NOT NULL,
    FOREIGN KEY (id_canal,id_video, id_comentario,id_doacao) REFERENCES doacao(id_canal,id_video, id_comentario,id_doacao)
);

CREATE TABLE mecanismo_plat (
    id_canal        UUID NOT NULL,
    id_video        UUID NOT NULL,
    id_comentario   UUID NOT NULL,
    id_doacao       UUID NOT NULL,
    seq_plataforma  INTEGER UNIQUE,
    FOREIGN KEY (id_canal,id_video, id_comentario,id_doacao) REFERENCES doacao(id_canal,id_video, id_comentario,id_doacao)
);