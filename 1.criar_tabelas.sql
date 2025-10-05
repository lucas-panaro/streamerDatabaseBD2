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
    nro           SERIAL PRIMARY KEY,
    nome          VARCHAR(100) NOT NULL,
    nome_fantasia VARCHAR(100)
);

CREATE TABLE plataforma (
    nro             SERIAL PRIMARY KEY,
    nome            VARCHAR(100) UNIQUE NOT NULL,
    qtd_users       INTEGER DEFAULT 0,       -- Atributo derivado (pode ser atualizado por TRIGGER)
    empresa_fundadora    INTEGER NOT NULL,
    empresa_responsavel   INTEGER NOT NULL,
    data_fund       DATE NOT NULL,
    FOREIGN KEY (empresa_fundadora) REFERENCES empresa(nro),
    FOREIGN KEY (empresa_responsavel) REFERENCES empresa(nro)
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
    nro_empresa INTEGER NOT NULL,
    ddi_pais    VARCHAR(5) NOT NULL,
    id_nacional VARCHAR(50),
    PRIMARY KEY (nro_empresa, ddi_pais),
    FOREIGN KEY (nro_empresa) REFERENCES empresa(nro),
    FOREIGN KEY (ddi_pais) REFERENCES pais(DDI)
);

CREATE TABLE canal (
    nro_canal           SERIAL PRIMARY KEY,
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
    nro_empresa     INTEGER NOT NULL,
    nro_canal     INTEGER NOT NULL,
    valor           NUMERIC(12, 2) NOT NULL,
    PRIMARY KEY (nro_empresa, nro_canal),
    FOREIGN KEY (nro_empresa) REFERENCES empresa(nro),
    FOREIGN KEY (nro_canal) REFERENCES canal(nro_canal)
);


CREATE TABLE nivel_canal (
    nro_canal       INTEGER NOT NULL,
    nivel           VARCHAR(50) NOT NULL,
    valor           NUMERIC(10, 2) NOT NULL,
    gif             VARCHAR(200),
    PRIMARY KEY (nro_canal, nivel),
    FOREIGN KEY (nro_canal) REFERENCES canal(nro_canal)
);


CREATE TABLE inscricao (
    nro_canal  INTEGER NOT NULL,
    nick_membro     VARCHAR(50) NOT NULL,
    nivel           VARCHAR(50) NOT NULL,
    PRIMARY KEY (nro_canal, nick_membro),
    FOREIGN KEY (nick_membro) REFERENCES usuario(nick),
    FOREIGN KEY (nro_canal, nivel) REFERENCES nivel_canal(nro_canal, nivel)
);

CREATE TABLE video (
    id_video        SERIAL PRIMARY KEY,
    nro_canal       INTEGER NOT NULL,
    titulo          VARCHAR(200) NOT NULL,
    dataH           TIMESTAMP NOT NULL,
    tema            VARCHAR(100),
    duracao         INTERVAL,
    visu_simul      INTEGER DEFAULT 0,
    visu_total      BIGINT DEFAULT 0,
    UNIQUE (nro_canal, titulo, dataH),
    FOREIGN KEY (nro_canal) REFERENCES canal(nro_canal)
);

CREATE TABLE participa (
    id_video        INTEGER NOT NULL,
    nick_streamer   VARCHAR(50) NOT NULL,
    PRIMARY KEY (id_video, nick_streamer),
    FOREIGN KEY (id_video) REFERENCES video(id_video),
    FOREIGN KEY (nick_streamer) REFERENCES usuario(nick)
);

CREATE TABLE comentario (
    id_comentario             SERIAL PRIMARY KEY,
    id_video                  INTEGER NOT NULL,
    nick_usuario              VARCHAR(50) NOT NULL,
    seq                       INTEGER NOT NULL,
    texto                     TEXT,
    dataH                     TIMESTAMP NOT NULL,
    comentario_original       INTEGER,
    UNIQUE (id_video, nick_usuario, seq),
    FOREIGN KEY (id_video) REFERENCES video(id_video),
    FOREIGN KEY (nick_usuario) REFERENCES usuario(nick),
    FOREIGN KEY (comentario_original) REFERENCES comentario(id_comentario)
);

CREATE TABLE doacao (
    id_doacao       SERIAL PRIMARY KEY,
    id_comentario   INTEGER NOT NULL,
    valor           NUMERIC(10, 2) NOT NULL,
    seq_pg          INTEGER NOT NULL,
    status          VARCHAR(20),
    UNIQUE (id_comentario, seq_pg),
    FOREIGN KEY (id_comentario) REFERENCES comentario(id_comentario)
);

CREATE TABLE bitcoin (
    id_doacao   INTEGER PRIMARY KEY,
    TxID        VARCHAR(100) UNIQUE NOT NULL,
    FOREIGN KEY (id_doacao) REFERENCES doacao(id_doacao)
);

CREATE TABLE paypal (
    id_doacao   INTEGER PRIMARY KEY,
    IdPayPal    VARCHAR(100) UNIQUE NOT NULL,
    FOREIGN KEY (id_doacao) REFERENCES doacao(id_doacao)
);

CREATE TABLE cartao_credito (
    id_doacao   INTEGER PRIMARY KEY,
    nro         VARCHAR(20) NOT NULL,
    bandeira    VARCHAR(50) NOT NULL,
    FOREIGN KEY (id_doacao) REFERENCES doacao(id_doacao)
);

CREATE TABLE mecanismo_plat (
    id_doacao       INTEGER PRIMARY KEY,
    seq_plataforma  INTEGER UNIQUE,
    FOREIGN KEY (id_doacao) REFERENCES doacao(id_doacao)
);