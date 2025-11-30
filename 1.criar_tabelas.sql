create schema if not exists streamerdb;

set
    search_path to streamerdb;

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

create table
    empresa (
        id_empresa uuid primary key,
        tax_id varchar(50) unique,
        nome varchar(100) not null,
        nome_fantasia varchar(100)
    );

create table
    plataforma (
        -- Adicionamos a chave primaria como uuid para manter a unicidade de canais, videos, comentarios, doações, etc sem a necessiade de SERIAL
        id_plataforma uuid primary key,
        nome varchar(100) unique not null,
        qtd_users integer default 0,
        empresa_fundadora uuid not null,
        empresa_responsavel uuid not null,
        data_fund date not null,
        -- Adicionamos o cascade para não ter nenhuma plataforma sem empresa vinculada
        foreign key (empresa_fundadora) references empresa (id_empresa) on delete cascade,
        foreign key (empresa_responsavel) references empresa (id_empresa) on delete cascade
    );

create table
    conversao (
        moeda varchar(10) primary key,
        nome varchar(50) not null,
        fator_conversao_dolar numeric(10, 4) not null
    );

create table
    pais (
        ddi varchar(5) primary key,
        nome varchar(100) not null,
        moeda varchar(10) not null,
        foreign key (moeda) references conversao (moeda) on delete no action
    );

create table
    usuario (
        -- Adicionamos a chave primaria como uuid para evitar a replicação do nick em diversas tabelas
        id_usuario uuid primary key,
        nick varchar(50) unique not null,
        email varchar(100) unique not null,
        data_nasc date,
        telefone varchar(20),
        end_postal varchar(200),
        pais_residencia varchar(5) not null,
        foreign key (pais_residencia) references pais (ddi) on delete no action
    );

create table
    plataforma_usuario (
        id_plataforma uuid not null,
        id_usuario uuid not null,
        primary key (id_plataforma, id_usuario),
        -- Adicionamos o cascade para não ter nenhum vinculo sem plataforma
        foreign key (id_plataforma) references plataforma (id_plataforma) on delete cascade,
        -- Mantemos o no action para exigir a remoção do vinculo antes de remover o usuario
        foreign key (id_usuario) references usuario (id_usuario) on delete no action
    );

create table
    streamer_pais (
        id_usuario uuid not null,
        ddi_pais varchar(5) not null,
        nro_passaporte varchar(50),
        primary key (id_usuario, ddi_pais),
        -- Ao deletar o usuário, removemos também o vinculo de streamer
        foreign key (id_usuario) references usuario (id_usuario) on delete cascade,
        foreign key (ddi_pais) references pais (ddi) on delete no action
    );

create table
    empresa_pais (
        id_empresa uuid not null,
        ddi_pais varchar(5) not null,
        id_nacional varchar(50),
        primary key (id_empresa, ddi_pais),
        -- Ao deletar a empresa, removemos também o vinculo de empresa_pais
        foreign key (id_empresa) references empresa (id_empresa) on delete cascade,
        foreign key (ddi_pais) references pais (ddi) on delete no action
    );

create table
    canal (
        id_plataforma uuid not null,
        id_canal uuid not null,
        id_usuario uuid not null,
        nome varchar(100) not null,
        tipo varchar(50),
        data_criacao date not null,
        desc_canal text,
        qtd_visualizacoes bigint default 0,
        primary key (id_plataforma, id_canal),
        -- Garantimos a unicidade do nome do canal dentro da plataforma
        unique (id_plataforma, nome),
        -- Adicionamos o cascade para não ter nenhum canal sem plataforma vinculada
        foreign key (id_plataforma) references plataforma (id_plataforma) on delete cascade,
        -- Mantemos o no action para exigir a remoção do canal antes de remover o usuario
        foreign key (id_usuario) references usuario (id_usuario) on delete no action
    );

create table
    patrocinio (
        id_empresa uuid not null,
        id_plataforma uuid not null,
        id_canal uuid not null,
        valor numeric(12, 2) not null,
        primary key (id_empresa, id_plataforma, id_canal),
        unique (id_empresa, id_plataforma, id_canal),
        -- Se a empresa, plataforma ou canal forem deletados, removemos também os patrocínios vinculados
        foreign key (id_empresa) references empresa (id_empresa) on delete cascade,
        foreign key (id_plataforma, id_canal) references canal (id_plataforma, id_canal) on delete cascade,
        foreign key (id_plataforma) references plataforma (id_plataforma) on delete cascade
    );

create table
    nivel_canal (
        id_plataforma uuid not null,
        id_canal uuid not null,
        nivel varchar(50) not null,
        valor numeric(10, 2) not null,
        gif varchar(200),
        primary key (id_plataforma, id_canal, nivel),
        unique (id_plataforma, id_canal, nivel),
        foreign key (id_plataforma, id_canal) references canal (id_plataforma, id_canal) on delete cascade
    );

create table
    inscricao (
        id_plataforma uuid not null,
        id_canal uuid not null,
        id_usuario uuid not null,
        nivel varchar(50) not null,
        primary key (id_plataforma, id_canal, id_usuario),
        unique (id_plataforma, id_canal, id_usuario, nivel),
        -- Ao deletar o nivel de inscrição do canal ou usuário, removemos também as inscrições vinculadas
        foreign key (id_usuario) references usuario (id_usuario) on delete cascade,
        foreign key (id_plataforma, id_canal, nivel) references nivel_canal (id_plataforma, id_canal, nivel) on delete no action
    );

create table
    video (
        id_plataforma uuid not null,
        id_canal uuid not null,
        id_video uuid not null,
        titulo varchar(200) not null,
        datah timestamp not null,
        tema varchar(100),
        duracao interval,
        visu_simul integer default 0,
        visu_total bigint default 0,
        primary key (id_plataforma, id_canal, id_video),
        unique (id_plataforma, id_canal, titulo, datah),
        foreign key (id_plataforma, id_canal) references canal (id_plataforma, id_canal) on delete cascade
    );

create table
    participa (
        id_plataforma uuid not null,
        id_canal uuid not null,
        id_video uuid not null,
        id_usuario uuid not null,
        primary key (id_plataforma, id_canal, id_video, id_usuario),
        unique (id_plataforma, id_canal, id_video, id_usuario),
        -- foreign key com cascade para remover a participação caso o vídeo seja deletado
        foreign key (id_plataforma, id_canal, id_video) references video (id_plataforma, id_canal, id_video) on delete cascade,
        -- Se um jogador for deletado, removemos também sua participação nos vídeos
        foreign key (id_usuario) references usuario (id_usuario) on delete cascade
    );

create table
    comentario (
        id_plataforma uuid not null,
        id_canal uuid not null,
        id_video uuid not null,
        id_comentario uuid not null,
        id_usuario uuid not null,
        texto text,
        datah timestamp not null,
        coment_on boolean default false,
        comentario_original_id_plataforma uuid,
        comentario_original_id_canal uuid,
        comentario_original_id_video uuid,
        comentario_original_id uuid,
        comentario_original_id_usuario uuid,
        primary key (id_plataforma, id_canal, id_video, id_comentario, id_usuario),
        unique (id_plataforma, id_canal, id_video, id_comentario, id_usuario),
        -- Se o video for deletado, removemos também os comentários vinculados
        foreign key (id_plataforma, id_canal, id_video) references video (id_plataforma, id_canal, id_video) on delete cascade,
        -- Se o usuário for deletado, removemos também os comentários feitos por ele
        foreign key (id_usuario) references usuario (id_usuario) on delete cascade,
        -- Se o comentário original for deletado, setamos como null os campos de referência
        foreign key ( comentario_original_id_plataforma, comentario_original_id_canal, comentario_original_id_video, comentario_original_id, comentario_original_id_usuario) references comentario ( id_plataforma, id_canal, id_video, id_comentario, id_usuario) on delete set null
    );

create table
    doacao (
        id_plataforma uuid not null,
        id_canal uuid not null,
        id_video uuid not null,
        id_comentario uuid not null,
        id_usuario uuid not null,
        id_doacao uuid not null,
        valor numeric(10, 2) not null,
        seq_pg integer not null,
        status varchar(20),
        primary key (
            id_plataforma,
            id_canal,
            id_video,
            id_comentario,
            id_usuario,
            id_doacao
        ),
        unique (
            id_plataforma,
            id_canal,
            id_video,
            id_comentario,
            id_usuario,
            id_doacao
        ),
        foreign key (
            id_plataforma,
            id_canal,
            id_video,
            id_comentario,
            id_usuario
        ) references comentario (
            id_plataforma,
            id_canal,
            id_video,
            id_comentario,
            id_usuario
        ) on delete cascade
    );

create table
    bitcoin (
        id_plataforma uuid not null,
        id_canal uuid not null,
        id_video uuid not null,
        id_comentario uuid not null,
        id_usuario uuid not null,
        id_doacao uuid not null,
        txid varchar(100) unique not null,
        primary key (
            id_plataforma,
            id_canal,
            id_video,
            id_comentario,
            id_usuario,
            id_doacao
        ),
        foreign key (
            id_plataforma,
            id_canal,
            id_video,
            id_comentario,
            id_usuario,
            id_doacao
        ) references doacao (
            id_plataforma,
            id_canal,
            id_video,
            id_comentario,
            id_usuario,
            id_doacao
        ) on delete cascade
    );

create table
    paypal (
        id_plataforma uuid not null,
        id_canal uuid not null,
        id_video uuid not null,
        id_comentario uuid not null,
        id_usuario uuid not null,
        id_doacao uuid not null,
        idpaypal varchar(100) unique not null,
        primary key (
            id_plataforma,
            id_canal,
            id_video,
            id_comentario,
            id_usuario,
            id_doacao
        ),
        foreign key (
            id_plataforma,
            id_canal,
            id_video,
            id_comentario,
            id_usuario,
            id_doacao
        ) references doacao (
            id_plataforma,
            id_canal,
            id_video,
            id_comentario,
            id_usuario,
            id_doacao
        ) on delete cascade
    );

create table
    cartao_credito (
        id_plataforma uuid not null,
        id_canal uuid not null,
        id_video uuid not null,
        id_comentario uuid not null,
        id_usuario uuid not null,
        id_doacao uuid not null,
        nro varchar(20) not null,
        bandeira varchar(50) not null,
        primary key (
            id_plataforma,
            id_canal,
            id_video,
            id_comentario,
            id_usuario,
            id_doacao
        ),
        foreign key (
            id_plataforma,
            id_canal,
            id_video,
            id_comentario,
            id_usuario,
            id_doacao
        ) references doacao (
            id_plataforma,
            id_canal,
            id_video,
            id_comentario,
            id_usuario,
            id_doacao
        ) on delete cascade
    );

create table
    mecanismo_plat (
        id_plataforma uuid not null,
        id_canal uuid not null,
        id_video uuid not null,
        id_comentario uuid not null,
        id_usuario uuid not null,
        id_doacao uuid not null,
        seq_plataforma integer unique,
        primary key (
            id_plataforma,
            id_canal,
            id_video,
            id_comentario,
            id_usuario,
            id_doacao
        ),
        foreign key (
            id_plataforma,
            id_canal,
            id_video,
            id_comentario,
            id_usuario,
            id_doacao
        ) references doacao (
            id_plataforma,
            id_canal,
            id_video,
            id_comentario,
            id_usuario,
            id_doacao
        ) on delete cascade
    );