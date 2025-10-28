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

CREATE OR REPlACE TRIGGER tg_user_count
AFTER INSERT OR DELETE ON plataforma_usuario
    FOR EACH ROW EXECUTE PROCEDURE fn_update_user_count();


CREATE OR REPLACE FUNCTION fn_update_view_count() RETURNS TRIGGER AS $$
	BEGIN
		SET search_path TO streamerdb;
	    IF TG_OP = 'INSERT' THEN
	        UPDATE canal SET qtd_visualizacoes = qtd_visualizacoes + NEW.visu_total WHERE nro_canal = NEW.nro_canal;
	    ELSIF TG_OP = 'DELETE' THEN
	        UPDATE canal SET qtd_visualizacoes = qtd_visualizacoes - OLD.visu_total WHERE nro_canal = OLD.nro_canal;
	    END IF;
	    RETURN NULL;
	END;
$$ LANGUAGE plpgsql;
CREATE OR REPlACE TRIGGER tg_view_count
AFTER INSERT OR DELETE ON video
    FOR EACH ROW EXECUTE PROCEDURE fn_update_view_count();
