SET search_path TO streamerdb;

CREATE OR REPLACE FUNCTION fn_update_user_count() RETURNS TRIGGER AS $$
  BEGIN
    SET search_path TO streamerdb;
    IF TG_OP = 'INSERT' THEN
      UPDATE plataforma SET qtd_users = qtd_users + 1 WHERE id_plataforma = NEW.id_plataforma;
    ELSIF TG_OP = 'DELETE' THEN
      UPDATE plataforma SET qtd_users = qtd_users - 1 WHERE id_plataforma = OLD.id_plataforma;
    END IF;
    RETURN NULL;
  END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER tg_user_count
AFTER INSERT OR DELETE ON plataforma_usuario
  FOR EACH ROW EXECUTE PROCEDURE fn_update_user_count();


CREATE OR REPLACE FUNCTION fn_check_comentario_cronologia() RETURNS TRIGGER AS $$
DECLARE
    v_data_criacao TIMESTAMP;
BEGIN
    SET search_path TO streamerdb;
    
    SELECT datah INTO v_data_criacao 
    FROM video 
    WHERE id_video = NEW.id_video AND id_canal = NEW.id_canal;

    IF NEW.datah < v_data_criacao THEN
        RAISE EXCEPTION 'Inconsistência Temporal: Comentário (Data: %) não pode ser anterior ao Vídeo (Data: %).', NEW.datah, v_data_criacao;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER tg_check_comentario_cronologia
BEFORE INSERT OR UPDATE ON comentario
    FOR EACH ROW EXECUTE PROCEDURE fn_check_comentario_cronologia();


CREATE OR REPLACE FUNCTION fn_check_status_doacao() RETURNS TRIGGER AS $$
BEGIN
    SET search_path TO streamerdb;
    NEW.status := UPPER(NEW.status);

    IF NEW.status NOT IN ('RECUSADA', 'RECEBIDA', 'LIDA', 'CONFIRMADA') THEN
        RAISE EXCEPTION 'Status de doação inválido. Deve ser "Recusada", "Recebida", "Lida" ou "Confirmada".';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER tg_check_status_doacao
BEFORE INSERT OR UPDATE ON doacao
    FOR EACH ROW EXECUTE PROCEDURE fn_check_status_doacao();

CREATE OR REPLACE FUNCTION fn_check_streamer_exists() RETURNS TRIGGER AS $$
DECLARE
    user_count INTEGER;
BEGIN
    SET search_path TO streamerdb;
    
    SELECT COUNT(1) INTO user_count 
    FROM usuario 
    WHERE id_usuario = NEW.id_usuario;

    IF user_count = 0 THEN
        RAISE EXCEPTION 'ID de usuário "%" não encontrado na tabela de usuários.', NEW.id_usuario;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER tg_check_streamer
BEFORE INSERT ON streamer_pais
    FOR EACH ROW EXECUTE PROCEDURE fn_check_streamer_exists();

CREATE TABLE IF NOT EXISTS log_video_removido (
    id_log SERIAL PRIMARY KEY,
    id_video UUID,
    id_canal UUID,
    data_remocao TIMESTAMP DEFAULT NOW(),
    usuario_db VARCHAR(50)
);

CREATE OR REPLACE FUNCTION fn_log_video_removido() RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO log_video_removido (id_video, id_canal, usuario_db)
    VALUES (OLD.id_video, OLD.id_canal, current_user);
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER tg_log_video_removido
AFTER DELETE ON video
    FOR EACH ROW EXECUTE PROCEDURE fn_log_video_removido();