SET search_path TO streamerdb;

DROP INDEX IF EXISTS idx_patrocinio_empresa_tax_id;
DROP INDEX IF EXISTS idx_inscricao_nick_membro;
DROP INDEX IF EXISTS idx_doacao_status_idcomentario;
DROP INDEX IF EXISTS idx_video_id_canal;
DROP INDEX IF EXISTS idx_usuario_email_pais;

CREATE INDEX idx_patrocinio_empresa_tax_id ON patrocinio (empresa_tax_id);

CREATE INDEX idx_inscricao_nick_membro ON inscricao (nick_membro);

CREATE INDEX idx_doacao_status_idcomentario ON doacao (status, id_comentario);

CREATE INDEX idx_video_id_canal ON video (id_canal);

CREATE INDEX idx_usuario_email_pais ON usuario (email, pais_residencia);