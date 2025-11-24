CREATE OR REPLACE FUNCTION fn_update_user_count() RETURNS TRIGGER AS $$
	BEGIN
		SET search_path TO streamerdb;
	  IF TG_OP = 'INSERT' THEN
	    UPDATE plataforma SET qtd_users = qtd_users + 1 WHERE nro = NEW.nro_plataforma;
	  ELSIF TG_OP = 'DELETE' THEN
	    UPDATE plataforma SET qtd_users = qtd_users - 1 WHERE nro = OLD.nro_plataforma;
	  END IF;
  	RETURN NULL;
	END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER tg_user_count
AFTER INSERT OR DELETE ON plataforma_usuario
  FOR EACH ROW EXECUTE PROCEDURE fn_update_user_count();

-- Trocar por view materializada
CREATE OR REPLACE FUNCTION fn_update_view_count() RETURNS TRIGGER AS $$
	BEGIN
		SET search_path TO streamerdb;
	  IF TG_OP = 'INSERT' THEN
	    UPDATE canal SET qtd_visualizacoes = qtd_visualizacoes + NEW.visu_total WHERE id_canal = NEW.id_canal;
	  ELSIF TG_OP = 'DELETE' THEN
	    UPDATE canal SET qtd_visualizacoes = qtd_visualizacoes - OLD.visu_total WHERE id_canal = OLD.id_canal;
	  END IF;
	  RETURN NULL;
	END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE TRIGGER tg_view_count
AFTER INSERT OR DELETE ON video
  FOR EACH ROW EXECUTE PROCEDURE fn_update_view_count();


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
    WHERE nick = NEW.nick_streamer;

    IF user_count = 0 THEN
        RAISE EXCEPTION 'Nick de streamer "%" não encontrado na tabela de usuários.', NEW.nick_streamer;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER tg_check_streamer
BEFORE INSERT ON streamer_pais
    FOR EACH ROW EXECUTE PROCEDURE fn_check_streamer_exists();