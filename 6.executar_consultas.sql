-- CONSULTA 01
create or replace function canais_patrocinados(_nro_empresa int default null)
returns table (nome_canal varchar, valor numeric)
as $$
	select c.nome, p.valor
	from canal c
	inner join patrocinio p on c.nro_canal = p.nro_canal
	where _nro_empresa is null or p.nro_empresa = _nro_empresa
	$$ language sql;

select * from canais_patrocinados(11);

