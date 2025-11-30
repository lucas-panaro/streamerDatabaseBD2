SET search_path TO streamerdb;


/*
trigger 1: Atualização do Contador de Usuários na Plataforma
Responsável por manter a consistência do atributo derivado `qtd_users` na tabela `plataforma`. 
Esta trigger é acionada **APÓS** uma inserção ou remoção na tabela `plataforma_usuario`, atualizando automaticamente o contador de usuários na plataforma correspondente.
*/
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


/*
trigger 2: Verificação de Cronologia de Comentários
Responsável por manter a consistência dos comentários na tabela `comentarios`. 
É acionada **ANTES** uma inserção ou update na tabela `comentario`, checando se o comentário foi feito antes do horário do video.
*/

CREATE OR REPLACE FUNCTION fn_check_comentario_cronologia() RETURNS TRIGGER AS $$
DECLARE
    v_data_criacao TIMESTAMP;
BEGIN
    SET search_path TO streamerdb;
    
    SELECT datah INTO v_data_criacao 
    FROM video 
    WHERE id_video = NEW.id_video 
      AND id_canal = NEW.id_canal
      AND id_plataforma = NEW.id_plataforma; 

    IF NEW.datah < v_data_criacao THEN
        RAISE EXCEPTION 'Inconsistência Temporal: Comentário (Data: %) não pode ser anterior ao Vídeo (Data: %).', NEW.datah, v_data_criacao;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER tg_check_comentario_cronologia
BEFORE INSERT OR UPDATE ON comentario
    FOR EACH ROW EXECUTE PROCEDURE fn_check_comentario_cronologia();

/*
trigger 3: Validação do Status da Doação
Atua **ANTES** de qualquer inserção ou atualização na tabela `doacao`. 
Esta trigger garante que o campo `status` só receba valores válidos (como 'RECUSADA', 'RECEBIDA', 'LIDA' ou 'CONFIRMADA'), atendendo a um requisito de consistência de dados do projeto.
*/

CREATE OR REPLACE FUNCTION fn_check_status_doacao() RETURNS TRIGGER AS $$
BEGIN
    SET search_path TO streamerdb;
    NEW.status := UPPER(NEW.status);

    IF NEW.status NOT IN ('RECUSADA', 'RECEBIDA', 'LIDA') THEN
        RAISE EXCEPTION 'Status de doação inválido. Deve ser "RECUSADA", "RECEBIDA" ou "LIDA". Valor recebido: %', NEW.status;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER tg_check_status_doacao
BEFORE INSERT OR UPDATE ON doacao
    FOR EACH ROW EXECUTE PROCEDURE fn_check_status_doacao();

/*
trigger 4: Verificação da Existência do Streamer
Atua **ANTES** da inserção na tabela `streamer_pais`. 
Sua função é garantir a integridade referencial e a lógica de negócio, assegurando que o `nick_streamer` a ser inserido já exista na tabela `usuario` (validando o subtipo).
*/
CREATE OR REPLACE FUNCTION fn_check_streamer_exists() RETURNS TRIGGER AS $$
DECLARE
    user_count INTEGER;
    streamer_count INTEGER;
BEGIN
    SET search_path TO streamerdb;
    
    SELECT COUNT(1) INTO user_count 
    FROM usuario 
    WHERE id_usuario = NEW.id_usuario;

    IF user_count = 0 THEN
        RAISE EXCEPTION 'ID de usuário "%" não encontrado na tabela de usuários.', NEW.id_usuario;
    END IF;

    SELECT COUNT(1) INTO streamer_count 
    FROM streamer_pais
    WHERE id_usuario = NEW.id_usuario;

    IF streamer_count > 0 THEN
        RAISE EXCEPTION 'ID de usuário "%" já está relacionado a um streamer. Faça update ao invés de inserir.', NEW.id_usuario;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER tg_check_streamer
BEFORE INSERT ON streamer_pais
    FOR EACH ROW EXECUTE PROCEDURE fn_check_streamer_exists();

/*
trigger 5: Atualização da Quantidade de Visualizações do Canal
Atua **DEPOIS** de update na tabela `video`, porém a atualização é realizada apenas se random_value for = 1, o que limita a atualização a uma chance de 1 em 1000 atualizações de um canal específico. 
Sua função é atualizar a quantidade de visualizações de cada canal.

Foi criada a também a function fn_update_all_channel_views(), no arquio 5.criar_functions.sql, que irá atualizar a quantidade de visualisações de todos canais do Banco. 
Seria utilizado um Cron de hora em hora que faria este update completo, garantindo que o dado esteja atualizado, além da atualização randomica acima.
*/
CREATE OR REPLACE FUNCTION fn_update_channel_views() RETURNS Trigger AS $$
DECLARE 
    r_view_count RECORD;
    random_value INTEGER;
BEGIN
    random_value := FLOOR(RANDOM() * 1000) + 1;
    
    IF random_value = 1 THEN
        FOR r_view_count IN
            SELECT id_plataforma, id_canal, SUM(visu_total) AS total_views 
            FROM video
            WHERE id_plataforma = NEW.id_plataforma AND id_canal = NEW.id_canal
            GROUP BY id_plataforma, id_canal
        LOOP
            UPDATE canal 
            SET qtd_visualizacoes = r_view_count.total_views
            WHERE id_plataforma = NEW.id_plataforma AND id_canal = NEW.id_canal;
        END LOOP;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER tg_update_channel_views
AFTER UPDATE ON video
    FOR EACH ROW EXECUTE PROCEDURE fn_update_channel_views();