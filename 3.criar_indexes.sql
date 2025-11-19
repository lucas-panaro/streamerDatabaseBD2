SET search_path TO streamerdb;

CREATE INDEX idx_patrocinio_nro_empresa ON patrocinio (nro_empresa);

CREATE INDEX idx_inscricao_nick_membro ON inscricao (nick_membro);

CREATE INDEX idx_doacao_status_idcomentario ON doacao (status, id_comentario);

CREATE INDEX idx_video_nro_canal ON video (nro_canal);

CREATE INDEX idx_usuario_email_pais ON usuario (email, pais_residencia);