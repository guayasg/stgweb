select * from familias;
/*  ************************* Ejemplos de uso de la vista
1) Obtener la ruta de una determinada familia:
	select path from menufamilias order by path
/***************/
drop view if exists menufamilias; 
CREATE OR REPLACE VIEW menufamilias AS 
 WITH RECURSIVE menufamilias AS (
         SELECT familias.id, familias.padre_id, familias.codfamilia,  familias.describe, familias.propia, familias.competencia, familias.orden, familias.describe::text AS path,componer_id
           FROM familias
          WHERE familias.padre_id IS NULL
        UNION
         SELECT familias.id, familias.padre_id, familias.codfamilia, familias.describe, familias.propia, familias.competencia, familias.orden, (parentpath.path || ' -> '::text) || familias.describe::text AS path,familias.componer_id
           FROM familias,
            menufamilias parentpath
          WHERE parentpath.id = familias.padre_id
        )
 SELECT menufamilias.id, menufamilias.padre_id, menufamilias.codfamilia,  menufamilias.describe,  menufamilias.propia, menufamilias.competencia, menufamilias.orden,  menufamilias.path,componer_id
   FROM menufamilias
  ORDER BY menufamilias.path;

ALTER TABLE menufamilias
  OWNER TO stg;

select * from propiedades_componer;
delete from articulos

/*  ************************* Ejemplos de uso de la función
2) Obtener todos los ids de familias  y propiedades de un determinado grupo (el grupo 1) ordenado por su orden
	select * from mod_familia_propiedad_grupo_bsc(17)
/***************/


select * from articulos_grupopropiedades where id=160

select * from familias where id=17
select * from mod_familia_propiedad_grupo_bsc(17)
drop function if exists mod_familia_propiedad_grupo_bsc(integer,integer[],integer[]);
CREATE OR REPLACE FUNCTION mod_familia_propiedad_grupo_bsc (IN integer,	OUT id INTEGER, OUT describe text)
  RETURNS SETOF record AS
$BODY$
/* Se le pasa un id de grupo (artículo) y devolverá las difentes familias y propiedades que compone el grupo. */
declare 
    p_idgrupo alias for $1;
    p_todas alias for $2;
    p_campos text;
    p_sql text;
    p_familia_id integer;
    
    p_where text;
begin  
	
	select familia_id into p_familia_id from articulos where articulos.id=p_idgrupo;
	p_sql:=		'with t as (	'||chr(10);
	p_sql:=p_sql||	'		select distinct familia_id,familia, propiedad_id, propiedad, familia_propiedad_id, valor, orden '||chr(10);
	p_sql:=p_sql||	'		from mod_propiedades_heredadas_bsc('||p_familia_id||',false)  --ascendientes '||chr(10);
	p_sql:=p_sql||	'	)'||chr(10);
	p_sql:=p_sql||'select  case when familia_propiedad_id is null then t.familia_id else familia_propiedad_id end as id,  '||chr(10);
	p_sql:=p_sql||'		case when familia_propiedad_id is null then familia else trim(propiedad)||'': ''|| trim(valor) end as atributo '||chr(10);
	p_sql:=p_sql||'		--t.familia_id,familia, t.propiedad_id, t.propiedad, t.familia_propiedad_id, t.valor, t.orden, * '||chr(10);
	p_sql:=p_sql||'from t left join (articulos_propiedades inner join articulos grupos on articulos_propiedades.grupo_id=grupos.id)  '||chr(10);
	p_sql:=p_sql||'		on articulos_propiedades.fp_id=t.familia_propiedad_id	'||chr(10);
	p_sql:=p_sql||'where grupos.id ='||p_idgrupo||'or familia_propiedad_id is null '||chr(10);
	p_sql:=p_sql||'order by t.orden';
	return query execute p_sql;

END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;


select * from mod_familia_propiedad_grupo_bsc(17)
select * from articulos_grupopropiedades


select * from mod_propiedades_heredadas_bsc  (17,false)

drop function mod_propiedades_heredadas_bsc  (IN integer, IN boolean);
CREATE OR REPLACE FUNCTION mod_propiedades_heredadas_bsc  (IN integer, IN boolean, 
	OUT orden INTEGER, OUT familia_id INTEGER, OUT padre_id INTEGER,OUT familia CHARACTER varying(100) , out propiedad_id integer,OUT propiedad CHARACTER varying(60), OUT familia_propiedad_id integer,
	OUT valor CHARACTER varying(200),OUT procedencia CHARACTER(20), OUT cod character(10),
	OUT path text)
  RETURNS SETOF record AS
$BODY$
    -- Se le pasa un  identificador de familia y te mostrará dependiendo de p_descendientes:
    --1) p_descendentes => true
    --	Se procesan en la búsqueda las propiedades y familias descendientes de la familia pasada
    --p_descendentes => false
    --  Se procesaon en la búsqueda las propiedades y familias ascendentes de la familia pasada
    
    
declare 
    p_idfamilia alias for $1;
    p_descendientes alias for $2;
    p_campos text;
    p_sql text;
    p_from text;


begin  
	--conformamos la clausula from
		
	
	p_from:=	'FROM   ('||chr(10);
	p_from:=p_from||'		SELECT  case when propiedades.id is null then familias.orden else fp.orden end as orden, familias.id as familia_id, familias.padre_id, familias.describe as familia, propiedades.id as propiedad_id, coalesce(propiedades.tcorto,'''')::character varying(60) as propiedad, fp.id as familia_propiedad_id,coalesce(fp.valor,'''') as valor, '||chr(10);
	p_from:=p_from||'			case when propiedades.id is null then ''familia'' else ''propia'' end::character(20) as procedencia, coalesce(fp.cod,familias.codfamilia) as cod, familias.describe::text as path '||chr(10);
	p_from:=p_from||' 		FROM familias left join ('||chr(10);
	p_from:=p_from||'			familias_propiedades fp  '||chr(10);
	p_from:=p_from||'			inner join propiedades on fp.propiedad_id=propiedades.id '||chr(10);
	p_from:=p_from||' 										) on familias.id=fp.familia_id '||chr(10);
	p_from:=p_from||'		union distinct '||chr(10);
	p_from:=p_from||'		select familias.orden, familias.id as familia_id, familias.padre_id,  familias.describe as familia, null as propiedad_id, ''''::character varying(60) as propiedad, null as familia_propiedad_id,'''' as valor, '||chr(10);
	p_from:=p_from||'			''familia''::character(20) as procedencia, familias.codfamilia as cod, familias.describe::text as path  '||chr(10);
	p_from:=p_from||'		from familias '||chr(10);
	p_from:=p_from||'	) t ';
	p_sql:='WITH RECURSIVE grupos_padre AS ('||chr(10);
	
	p_sql:=p_sql||'Select * '||chr(10)||p_from;
	if p_idfamilia<>0 then
		p_sql:=p_sql||'	where (t.familia_id='||p_idfamilia||' and t.propiedad_id is not null) or (t.propiedad_id is null '||case when p_descendientes then ' and t.padre_id='||p_idfamilia||' ) ' else ' and familia_id='||p_idfamilia||') ' end||chr(10); 
	else
		p_sql:=p_sql||' where t.padre_id is null '; 
	end if;

 -- fin de with recursivo


	p_sql:=p_sql||'	UNION distinct '||chr(10); 
	p_sql:=p_sql||'	SELECT t.orden, t.familia_id, t.padre_id, t.familia,   '||chr(10);
	p_sql:=p_sql||'		t.propiedad_id, t.propiedad, t.familia_propiedad_id,coalesce(t.valor,'''') as valor, ';
	p_sql:=p_sql||'		case when t.propiedad_id is null then ''familia'' else ''heredada'' end::character(20) as procedencia, t.cod, '||chr(10);
	p_sql:=p_sql||'		case when grupos_padre.padre_id=t.familia_id then t.familia||''->''||grupos_padre.path   '||chr(10);
	p_sql:=p_sql||'			when grupos_padre.padre_id=t.familia_id then t.familia||''->''||grupos_padre.path  '||chr(10);
	p_sql:=p_sql||'		end as path '||chr(10);
	p_sql:=p_sql||p_from||', grupos_padre '||chr(10);
	
	if p_descendientes then
		p_sql:=p_sql||'	where grupos_padre.familia_id=t.familia_id '||chr(10);
	else
		p_sql:=p_sql||'	where grupos_padre.padre_id=t.familia_id '||chr(10);
        end if;
	p_sql:=p_sql||') -- fin de with recursivo '||chr(10);
	p_sql:=p_sql||'Select distinct  * from  grupos_padre order by orden ; '||chr(10);
	--raise exception '%',p_sql;
  return query execute p_sql;

END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;



drop function if exists mod_propiedades_combinacion_valida(integer,integer[],integer[]);
create or replace function mod_propiedades_combinacion_valida(integer,integer[],integer[]) returns boolean as
$BODY$
declare
    p_idfamilia alias for $1;
    p_propiedades alias for $2;
    p_valores alias for $3;
    p_pos_prop_dependiente integer;
    r record;
    p_propiedad_id integer;
    p_valor_id integer;
    p_compatible boolean;
    
    i integer;
begin
	-- Se le pasa un id de familia, un array con las propiedades y otro con los valores a insertar, y comprueba que dicha combinación 
	-- es válida para insertar en la tabla arituclos_propiedades, conforme a familias_valores_ligados.
	-- Es una función algo lenta.
	--búsqueda de todos los elementos dependientes de la familia

	for r in
		select f.propiedad_id,array_search(f.propiedad_id,p_propiedades) as pospropiedad,array_agg(v.fp2_id::text||'|'||f2.propiedad_id::text||'|'||array_search(f2.propiedad_id,p_propiedades)::text) as vligues
		from mod_propiedades_heredadas_bsc(p_idfamilia,false) f	inner join familias_valoresligados v on f.familia_propiedad_id=v.fp_id
			inner join familias_propiedades f2 on v.fp2_id=f2.id
		where f.familia_propiedad_id = any(p_valores) and (array[f2.propiedad_id] && p_propiedades) --el valor está entre la combinación a analizar, y la propiedad ligada está entre las propiedades de la combinación
		group by f.propiedad_id,array_search(f.propiedad_id,p_propiedades) loop
		if array_length(r.vligues,1)>0 then --hay alguna ligadura para uno de los valores a evaluar
			p_compatible:=false;
			for i in 1..array_length(r.vligues,1) loop -- por cada atadura encontrada, de un valor evaluamos su propiedad, para ver si dicha propiedad está en el vector de propiedades
					p_valor_id:=split_part(r.vligues[i],'|',1);
					p_propiedad_id:=split_part(r.vligues[i],'|',2);
					p_pos_prop_dependiente:=split_part(r.vligues[i],'|',3);
					if p_valores[p_pos_prop_dependiente]=p_valor_id then
						p_compatible:=true;
						exit;
					end if;	
			end loop;
			if not p_compatible then 
				return p_compatible;
			end if;	
		end if;
	end loop;
	return true;
	
end;

$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


/* *************  EJEMPLOS DE USO
Ejemplo 1:
select mod_propiedades_generar_grupos (17,0); --Genera todos los posibles grupos de propiedades de la familia 17. Elimina los artículos sobrantes, y recompone los que está parcialmente construidos

Ejemplo 2: Conocer la lista de propiedades y familias (no de valores) que compone un grupo
select distinct propiedad_id,case when propiedad_id is null then familia else propiedad end as familia_propiedad from mod_propiedades_heredadas_bsc  (17,false) 

Ejemplo 3: Conocer que propiedad y valor (familias_propiedades.id) falta por incluir en un grupo.
select * from mod_propiedades_generar_grupos(17,372)

Ejemplo 4:

*/


drop function if exists mod_propiedades_elementos_combinatoria  (integer);
CREATE OR REPLACE FUNCTION mod_propiedades_elementos_combinatoria(IN integer,out id integer, OUT propiedad_valor text, OUT orden integer)
  RETURNS SETOF record AS
$BODY$
declare
  p_familia_id alias for $1;
begin	
   return query
    select distinct case when propiedad_id is null then familia_id else familia_propiedad_id end as id,
	 case when propiedad_id is null then familia else propiedad||': '||valor end as familia_propiedad,
		t1.orden as orden
	from mod_propiedades_heredadas_bsc (p_familia_id,false) t1
	order by orden;

END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
  

drop function if exists mod_propiedades_generar_grupos_original  (integer);
CREATE OR REPLACE FUNCTION mod_propiedades_generar_grupos_original(integer)
  RETURNS text as
$BODY$
--Esta función retornará el producto cartesiano de todas las posibles combinaciones de valores de las diferentes propiedades encontradas (y heredadas) en una familia. 
--Dicho producto cartesiano será introducido en la tabla articulos y articulos_propiedades. Si ya existiensen grupos de propiedades de esta famila o sucesoras, 
-- con combinacionesefectuadas, se completarán.
declare
    p_idfamilia alias for $1;
    p_sql text;
    p_select text;
    p_array text;
    p_join text;
    p_where text;
    p_prop integer[];
    p_prop_text text;
    p_grupo text;
    r record;
    i integer;
    p_idgrupo integer;


begin

        p_sql:='';
        i:=0;
        --en el with 'grupos' estarán las combinaciones ya establecidas en la tabla articulos_grupopropiedades y articulos_propiedades de la familia actual
	p_select:='with grupos as ('||chr(10);
	p_select:=p_select||'	select agp.id as grupo_id,ap.fp_id,fp.propiedad_id '||chr(10);
	p_select:=p_select||'	from articulos_grupopropiedades agp inner join articulos_propiedades ap on agp.id=ap.grupo_id inner join familias_propiedades fp '||chr(10);
	p_select:=p_select||'	on ap.fp_id=fp.id inner join propiedades on fp.propiedad_id=propiedades.id '||chr(10);
	p_select:=p_select||'	where agp.familia_id in (select distinct familia_id from mod_propiedades_heredadas_bsc('||p_idfamilia||',true))'||chr(10);
	p_select:=p_select||')'||chr(10); 
	for r in --por cada propiedad de la familia (heredada o no)
		select distinct propiedad_id
		from mod_propiedades_heredadas_bsc  (p_idfamilia,false) t inner join propiedades on t.propiedad_id=propiedades.id
		group by propiedad_id loop
		--Construimos una consulta con tantas tablas como propiedades (distintas propias o heredadas) existan en dicha familia, con el fin de hacer un producto cartesiano
		if i=0 then 
			p_select:=p_select||'select p'||i||'.familia_propiedad_id as fp_id0';
			p_array:='array[p0.familia_propiedad_id::integer';
			p_join:='from mod_propiedades_heredadas_bsc  ('||p_idfamilia||',false) p0'||chr(10); 
			p_where:='where p0.propiedad_id='||r.propiedad_id||chr(10);
		else 
			p_select:=p_select||', p'||i||'.familia_propiedad_id as fp_id'||i;
			p_array:=p_array||',p'||i||'.familia_propiedad_id::integer';
			p_join:=p_join||', mod_propiedades_heredadas_bsc  ('||p_idfamilia||',false) p'||i;
			p_where:=p_where||' and p'||i||'.propiedad_id='||r.propiedad_id;

		end if;
		i:=i+1; --i refleja el número de propiedades distintas de la familia (heredadas o no)
		p_prop:=array_append(p_prop,r.propiedad_id);
		
	end loop;

	p_array:=p_array||'] ';
	
	--La siguiente variable configura un left join a la consulta anterior con los grupos de propiedades (tablas articulos_propiedades y articulos_grupopropiedades)
	p_grupo:=' left join ( '||chr(10);
	p_prop_text:='array'||translate(p_prop::text,'{}','[]');
	p_grupo:=p_grupo||'--Todos los grupos de esa familia o descendiente que no tienen alguna de las propiedades de las combinaciones (deberían de tenerlas) '||chr(10);
	p_grupo:=p_grupo||'	select grupo_id,array_agg(fp_id) as valores_id '||chr(10);
	p_grupo:=p_grupo||'	from grupos '||chr(10);
	p_grupo:=p_grupo||'	where array[propiedad_id]<@'||p_prop_text||chr(10);--la propiedad esté dentro del array de propiedades de la combinación que estamos generando
	p_grupo:=p_grupo||'	group by grupo_id '||chr(10);
	p_grupo:=p_grupo||') t on true'||chr(10); -- Postgres no deja poner en la clausula left join (...) t on array[]@>array[]. Por lo tanto lo ponemos en el where
	p_where:=p_where||' and '||p_array||'@>coalesce(t.valores_id,array[]::integer[]) '||chr(10); --La combinación de valores actual ha de contener a los valores del grupo de propiedades
	p_join:=p_join||p_grupo;
	
	--para saber que propiedades se han de insertar en cada grupo hacemos el array_except siguiente como campo de la consulta
	p_select:=p_select||', t.grupo_id, array_except('||p_array||',t.valores_id) as combinacion_grupo_insertar ';
	

	--Para construir la clausula where de las combinaciones prohibidas que no se van a generar, construiremos un añadido a la clausua 'where' 
	-- con todas las limitaciones que se pueden dar en la combinación, según la tabla familias_valoresligados:
		
	for r in
		select v.fp_id,array_agg(v.fp2_id) as vligues, coalesce(count(*),0) as cuenta  --contamos las posibles posibilidades de combinaciones no álidas entre propiedades de la familia que estamos buscando
		from mod_propiedades_heredadas_bsc(p_idfamilia,false) f	inner join familias_valoresligados v on f.familia_propiedad_id=v.fp_id
			inner join familias_propiedades f2 on v.fp2_id=f2.id
		where (array[f.propiedad_id] && p_prop) -- la propiedad ligada está entre las propiedades de la combinación
		and (array[f2.propiedad_id] && p_prop) -- la propiedad ligada 2 está entre las propiedades de la combinación
		and f.propiedad_id<>f2.propiedad_id
		group by f.propiedad_id,v.fp_id loop

		if r.cuenta>0 then 
		-- Si entramos auí, es que hay valores que restringen la combinación en ciertas propiedades que están en uso.
		-- Por tanto añadimos clausulas al where para validar dicha combinación:
			p_where:=p_where||' and 	( '||chr(10);
			p_where:=p_where||'			(not array['||r.fp_id||'] && '||p_array||') '||chr(10); --el valor de la restricción que estamos tratando en el bucle, no se encuentra en la combinación.
			p_where:=p_where||'			or '||chr(10);
			p_where:=p_where||'			(array'||translate(r.vligues::text,'{}','[]')||' && '||p_array||')'||chr(10); --o los ligues de la restricción coincide en algún elemento con algún elemento de la combinación
			p_where:=p_where||'		) '||chr(10);
		end if;
		
	end loop;
		
	
	p_array:=', '||p_array||' as combinacion_insertar '||chr(10); 
	
	
	p_sql:=p_select||p_array||p_join||chr(10)||p_where; --consulta definitiva a ejecutar
	--raise 'SELECT:%  aRRAY: % JOIN: % WHERE: % SQL %', P_SELECT,P_ARRAY, P_JOIN, P_WHERE,p_sql;
	
	
	--raise '%', p_sql;
		
	--ahora recorresmos todas las combinaciones. 2 posibilidades para plasmar cada combinación 
	-- 1) Si existe grupo_id =>insertamos en dicho grupo_id una o tantas propiedades como diga el campo valores_grupo_insertar en la tabla articulos_propiedades
	-- 2) si no existe grupo_id=> insertamos un grupo nuevo en la familia, y le añadimos todos los valores del array 
	for r in execute p_sql loop
	--cada registro contiene una combinación de propiedades/valores para conformar un grupo que hay que insertar. 
		if r.grupo_id is not null then
			continue when array_length(r.combinacion_grupo_insertar,1)= 0; --si no hay elementos a insertar continuamos el bucle
			insert into articulos_propiedades(grupo_id,fp_id)
			select r.grupo_id,t
			from unnest(r.combinacion_grupo_insertar) t
			where t is not null; --a lo mejor podría tratar de meterse un nulo
		else
			insert into articulos_grupopropiedades (id,familia_id) values (nextval('articulos_grupopropiedades_id_seq'),p_idfamilia) returning id into p_idgrupo;
			insert into articulos_propiedades(grupo_id,fp_id)
			select p_idgrupo,t
			from unnest(r.combinacion_grupo_insertar) t;
		end if;
	end loop;
	

	return 'OK';
	
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

delete from articulos
select * from articulos
select * from articulos_propiedades
"Codarticulo repetido: 00001115. Revisar familias y Familias Propiedades siguientes: 

Colchón(00001), Dimensiones -> Medida -> Corta:  80 x 182(115), Dimensiones -> Producto -> Ancho: 80(104), Dimensiones -> Producto -> Largo: 182(99)
Colchón(00001), Dimen (...)"
select mod_propiedades_generar_grupos(1,0)
delete from articulos
delete from articulos
select * from articulos where nomcomercial like '%x 190%'
SELECT codarticulo,COUNT(*) FROM ARTICULOS GROUP BY codarticulo HAVING COUNT(*)>1

select * from familias_propiedades where valor='100 x 220'
delete from articulos
drop function if exists mod_propiedades_generar_grupos (integer,integer);


CREATE OR REPLACE FUNCTION mod_propiedades_generar_grupos(integer,integer)
  RETURNS text as
$BODY$
--Esta función retornará el producto cartesiano de todas las posibles combinaciones de valores de las diferentes propiedades encontradas (y heredadas) en una familia. 
--Dicho producto cartesiano será introducido en la tabla articulos y articulos_propiedades. Si ya existiensen grupos de propiedades de esta famila o sucesoras, 
-- con combinacionesefectuadas, se completarán.
--Modos de funcionamiento:
--Si se le pasa un 0 en grupo_id, construye o recontruye toda la combinatoria de propiedades (uso  pensado por defecto)
--Si se le pasa un número distinto de 0 devuelve una string separada por comas,  en donde en la primera posición habrá
-- un id de propiedad/familia, y en la segunda las propiedades que se pueden aún insertar en el artículo pasado


declare
    p_idfamilia alias for $1;
    p_grupo_id alias for $2;
    p_sql text;
    p_select text;
    p_array text;
    p_join text;
    p_where text;
    p_prop integer[];
    p_prop_text text;
    p_aux text;
    p_grupo text;
    p_msg text;
    r record;
    r2 record;
    i integer;
    p_idgrupo integer;
    p_articulos_conservar integer[];
    


begin
	
        p_sql:='';
        i:=0;
        p_prop:=array[]::integer[];
        --en el with 'grupos' estarán las combinaciones ya establecidas en la tabla ARTICULOS y articulos_propiedades de la familia actual
	p_select:='with grupos as ('||chr(10);
	p_select:=p_select||'	select articulos.id as grupo_id,ap.fp_id,fp.propiedad_id '||chr(10);
	p_select:=p_select||'	from articulos  inner join articulos_propiedades ap on articulos.id=ap.grupo_id inner join familias_propiedades fp '||chr(10);
	p_select:=p_select||'	on ap.fp_id=fp.id inner join propiedades on fp.propiedad_id=propiedades.id '||chr(10);
	p_select:=p_select||'	where articulos.familia_id in (select distinct familia_id from mod_propiedades_heredadas_bsc('||p_idfamilia||',false))'||chr(10);
	p_select:=p_select||')'||chr(10); 
		
	p_select:=p_select||'select *, case when t.comb  @> coalesce(t2.valores_id,array[]::integer[]) then t2.grupo_id else null::integer end as grupo_id, '||chr(10);
	--para saber que propiedades se han de insertar en cada grupo hacemos el array_except siguiente como campo de la consulta
	p_select:=p_select||'array_except(comb ,t2.valores_id) as combinacion_grupo_insertar  '||chr(10);
	p_select:=p_select||'from( '||chr(10);
	p_select:=p_select||'Select ';
	
	
	for r in --por cada propiedad de la familia (heredada o no)
		select distinct propiedad_id
		from mod_propiedades_heredadas_bsc  (p_idfamilia,false) t inner join propiedades on t.propiedad_id=propiedades.id
		group by propiedad_id loop
		--Construimos una consulta con tantas tablas como propiedades (distintas propias o heredadas) existan en dicha familia, con el fin de hacer un producto cartesiano
		if i=0 then 
			p_select:=p_select||'p'||i||'.familia_propiedad_id as fp_id0';
			p_array:='array[p0.familia_propiedad_id::integer';
			p_join:='from mod_propiedades_heredadas_bsc  ('||p_idfamilia||',false) p0'||chr(10); 
			p_where:='where p0.propiedad_id='||r.propiedad_id||chr(10);
		else 
			p_select:=p_select||', p'||i||'.familia_propiedad_id as fp_id'||i;
			p_array:=p_array||',p'||i||'.familia_propiedad_id::integer';
			p_join:=p_join||', mod_propiedades_heredadas_bsc  ('||p_idfamilia||',false) p'||i;
			p_where:=p_where||' and p'||i||'.propiedad_id='||r.propiedad_id;

		end if;
		i:=i+1; --i refleja el número de propiedades distintas de la familia (heredadas o no)
		p_prop:=array_append(p_prop,r.propiedad_id);
		
	end loop;
	
	p_array:=case when i>0 then p_array||'] ' else 'array[]::integer[]'  end;
	p_select:=p_select||case when i>0 then ', ' else '' end||p_array||' as comb ';


	--Para construir la clausula where de las combinaciones prohibidas que no se van a generar, construiremos un añadido a la clausua 'where' 
	-- con todas las limitaciones que se pueden dar en la combinación, según la tabla familias_valoresligados:
	
	for r in
		select v.fp_id,array_agg(v.fp2_id) as vligues, coalesce(count(*),0) as cuenta  --contamos las posibles posibilidades de combinaciones no álidas entre propiedades de la familia que estamos buscando
		from mod_propiedades_heredadas_bsc(p_idfamilia,false) f	inner join familias_valoresligados v on f.familia_propiedad_id=v.fp_id
			inner join familias_propiedades f2 on v.fp2_id=f2.id
		where (array[f.propiedad_id] && p_prop) -- la propiedad ligada está entre las propiedades de la combinación
		and (array[f2.propiedad_id] && p_prop) -- la propiedad ligada 2 está entre las propiedades de la combinación
		and f.propiedad_id<>f2.propiedad_id
		group by f.propiedad_id,v.fp_id loop

		if r.cuenta>0 then 
		-- Si entramos auí, es que hay valores que restringen la combinación en ciertas propiedades que están en uso.
		-- Por tanto añadimos clausulas al where para validar dicha combinación:
			p_where:=p_where||' and 	( '||chr(10);
			p_where:=p_where||'			(not array['||r.fp_id||'] && '||p_array||') '||chr(10); --el valor de la restricción que estamos tratando en el bucle, no se encuentra en la combinación.
			p_where:=p_where||'			or '||chr(10);
			p_where:=p_where||'			(array'||translate(r.vligues::text,'{}','[]')||' && '||p_array||')'||chr(10); --o los ligues de la restricción coincide en algún elemento con algún elemento de la combinación
			p_where:=p_where||'		) '||chr(10);
		end if;
		
	end loop;


	p_grupo:=' left join lateral ( '||chr(10);
	p_prop_text:='array'||translate(p_prop::text,'{}','[]');
	p_grupo:=p_grupo||'--Todos los grupos de esa familia o descendiente que no tienen alguna de las propiedades de las combinaciones (deberían de tenerlas) '||chr(10);
	p_grupo:=p_grupo||'	select grupo_id,array_agg(fp_id) as valores_id '||chr(10);
	p_grupo:=p_grupo||'	from grupos '||chr(10);
	p_grupo:=p_grupo||'	where array[propiedad_id]<@'||p_prop_text||chr(10);--la propiedad esté dentro del array de propiedades de la combinación que estamos generando
	p_grupo:=p_grupo||'	group by grupo_id '||chr(10);
	p_grupo:=p_grupo||') t2 on  (t.comb  @> coalesce(t2.valores_id,array[]::integer[])) '; --la combinación calculada incluya a la del artículo
		

	
	--p_array:=regexp_replace(regexp_replace,'[p.','[t'),',p.',',t'); --para poder usar el array de propiedades en el left join

	p_sql:=p_select||' '||chr(10)||p_join||chr(10)||p_where||chr(10)||') t '||chr(10)||p_grupo; --consulta definitiva a ejecutar

	--raise exception '%',p_sql;
	
	--_where:=p_where||' and ('||p_array||' @> coalesce(t.valores_id,array[]::integer[]))';
	--p_array:=', '||p_array||' as combinacion_insertar '||chr(10); 
	
	--La siguiente variable configura un left join a la consulta anterior con los grupos de propiedades (tablas articulos_propiedades y articulos)
	--corregido 2015-11-02 No debe fijarse como condición porque si no, no recalcula cuando hay artículos creados. p_where:=p_where||' and '||p_array||'@>coalesce(t.valores_id,array[]::integer[]) '||chr(10); --La combinación de valores actual ha de contener a los valores del grupo de propiedades
	
	p_select:=p_select||' '||p_grupo||') tfinal '|| chr(10); --consulta definitiva a ejecutar
	
	
	
	--raise 'SELECT:%  aRRAY: % JOIN: % WHERE: % SQL %', P_SELECT,P_ARRAY, P_JOIN, P_WHERE,p_sql;
	
	if p_grupo_id<>0 then
		
		p_sql:=p_sql||' and t.grupo_id='||p_grupo_id;
		--p_sql:=replace(p_sql,chr(10),'  ');
		--return p_sql;
		execute p_sql into r;
		return array_to_string(r.combinacion_grupo_insertar,',');
				
	end if;

	p_articulos_conservar:=case when p_articulos_conservar is null then array[]::integer[] else p_articulos_conservar end;
	
	--ahora recorresmos todas las combinaciones. 2 posibilidades para plasmar cada combinación 
	-- 1) Si existe grupo_id =>insertamos en dicho grupo_id una o tantas propiedades como diga el campo valores_grupo_insertar en la tabla articulos_propiedades
	-- 2) si no existe grupo_id=> insertamos un grupo nuevo en la familia, y le añadimos todos los valores del array 
	if p_sql is null then
		return 'OK';
	end if;

	
	
	for r in execute p_sql loop
	--cada registro contiene una combinación de propiedades/valores para conformar un grupo que hay que insertar. 
		if r.grupo_id is not null then
			p_articulos_conservar:=array_append(p_articulos_conservar,r.grupo_id);
			continue when array_length(r.combinacion_grupo_insertar,1)= 0; --si no hay elementos a insertar continuamos el bucle
			insert into articulos_propiedades(grupo_id,fp_id)
			select r.grupo_id,t
			from unnest(r.combinacion_grupo_insertar) t
			where t is not null; --a lo mejor podría tratar de meterse un nulo
		else    --El codartículo y el nombre largo han de ser únicos
			select nextval('articulos_id_seq') into i;
			insert into articulos (id,codarticulo,nomlargo,familia_id) values (i,i::character(15),i::text,p_idfamilia) returning id into p_idgrupo;
			insert into articulos_propiedades(grupo_id,fp_id)
			select p_idgrupo,t
			from unnest(r.combinacion_grupo_insertar) t;
			p_articulos_conservar:=array_append(p_articulos_conservar,p_idgrupo);
		end if;
	end loop;

	
	
/* Analizamos que artículos no se podrán eliminar por estar vinculados a líneas de documentos 	
	select p_articulos_conservar||array_agg(distinct articulo.id) into p_articulos_conservar
	from lineas inner join articulos on lineas.articulo_id=articulos.id
	where articulos.familia_id=p_idfamilia;
*/
	update articulos set codarticulo=t.cod,nomcorto=t.nomcorto,nomlargo=t.nomlargo,nomcomercial=t.nomcomercial
	from ( 
		select * from mod_articulos_nombre  (p_idfamilia, case when p_grupo_id<>0 then array[p_grupo_id] else array[]::integer[] end, array[]::integer[],  array[]::integer[])
	) t
	where articulos.id=t.id and array[articulos.id] && p_articulos_conservar 
		and (articulos.codarticulo<>t.cod or articulos.nomcorto<>t.nomcorto or articulos.nomlargo<>t.nomlargo or articulos.nomcomercial<>t.nomcomercial);


	delete from articulos 
	where familia_id=p_idfamilia and not (array[id] && p_articulos_conservar);
	p_msg:='OK';
	--MIRAMOS A VER SI EXISTEN CODARTICULO DUPLICADOS. Si existiesen informamos, y abortamos transacción.
	SELECT codarticulo,COUNT(*) as cuenta, array_agg(id) as articulos into r
	FROM ARTICULOS 
	GROUP BY codarticulo HAVING COUNT(*)>1
	limit 1;
	if r is not null then
		p_msg:= 'Codarticulo '||r.codarticulo||' '||r.cuenta||' veces repetido'||'. Revisar familias y Familias Propiedades siguientes: '||chr(10);
		for  r2 in
			select grupo.id,grupo.codarticulo, string_agg(distinct case when t.propiedad_id is null then t.familia else t.propiedad||': '||t.valor end||case when coalesce(t.cod)<>'' then '('||t.cod||')' else '' end,', ') as codrepe 
			from articulos grupo left join 
				(articulos_propiedades inner join familias_propiedades on articulos_propiedades.fp_id=familias_propiedades.id) 
					on grupo.id=articulos_propiedades.grupo_id
				inner join mod_propiedades_heredadas_bsc(grupo.familia_id,false) t on 
					(grupo.familia_id=t.familia_id and t.propiedad_id is null) or t.familia_propiedad_id=familias_propiedades.id
			where array[grupo.id]  && r.articulos
			group by grupo.id loop
				p_msg:= p_msg||chr(10)||r2.codrepe;
		end loop;
		i:=1/0;
	end if;

	p_msg:=p_msg||' ('||array_length(p_articulos_conservar,1)||' articulo/s (re)generados o cambiados) ';
	return p_msg;
		

	EXCEPTION
		WHEN OTHERS THEN
		p_msg:=replace(p_msg,chr(10),' - - - ');
		if length(coalesce(p_sql,''))=0 then
			p_msg:='No se pudieron renombrar artículos. El error fue: '||SQLERRM;
		end if;
		return p_msg;

			
	--Faltaría eliminar artículos que no tienen correspondencia con una combinación válida y no están siendo usados por líneas de documentos

	
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;



delete from familias_valoresligados

SELECT codarticulo,COUNT(*), array_agg(id) as articulos 
	FROM ARTICULOS 
	GROUP BY codarticulo HAVING COUNT(*)>1
	limit 1;
 select mod_propiedades_generar_grupos(14,0) as ret;
 "Codarticulo repetido: 00001. Revisar familias y Familias Propiedades siguientes:  - - - "

 select grupo.id,grupo.codarticulo, string_agg(distinct case when t.propiedad_id is null then t.familia else t.propiedad||': '||t.valor end||case when coalesce(t.cod)<>'' then '('||t.cod||')' else '' end,', ') as codrepe 
			from articulos grupo left join 
				(articulos_propiedades inner join familias_propiedades on articulos_propiedades.fp_id=familias_propiedades.id) 
					on grupo.id=articulos_propiedades.grupo_id
				inner join mod_propiedades_heredadas_bsc(grupo.familia_id,false) t on 
					(grupo.familia_id=t.familia_id and t.propiedad_id is null) or t.familia_propiedad_id=familias_propiedades.id
			where array[grupo.id]  && array[796,797,798,799,800,801,802,803,804,805,806,807,808,809,810,811,812,813,814,815,816,817,818,819,820,821,822,823,824,825,826,827,828,829,830,831,832,833,834,835,836,837,838,839,840,841,842,843,844,845,846,847,848]
			group by grupo.id 

CREATE OR REPLACE FUNCTION mod_articulos_orden_siguiente_anterior (integer,integer,integer,text) returns integer as
$BODY$
-- Se le pasa un id de una familia o de una familia_propiedad (tabla familias.id o  familias_propiedades.id). el segundo parámetro será 'subir' o 'bajar'
-- Devuelve el id del elemento que le prescede o le sucede en la ordenación familias-propiedades/valores
declare
	p_familia_id alias for $1;
	p_grupo_id alias for $2;
	p_id alias for $3;
	p_accion alias for $4;
	r  record;
begin
	
	with t as ( --las distintas propiedades y familias (no valores) de la familia y grupo pasado
		select distinct case when propiedad_id is null then familia_id else familia_propiedad_id end as id,
			case when propiedad_id is null then familia else propiedad end as familia_propiedad,
			t1.orden as orden
		from mod_propiedades_heredadas_bsc (p_familia_id,false) t1 inner join articulos_propiedades on articulos_propiedades.grupo_id=p_grupo_id
		and (articulos_propiedades.fp_id=t1.familia_propiedad_id or t1.propiedad_id is null)
	)
	select * into r
	from (  -- Consulta con función ventana para saber el antecesor y sucesor
		select orden,t.id,familia_propiedad,lead(t.id) over w as sucesor, lag(t.id) over w as antecesor 
		from t
		window w as (order by t.orden)
	) k
	where id=p_id
	order by orden;


	return case when p_accion='subir' then coalesce(r.antecesor,p_id) else coalesce(r.sucesor,p_id) end;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;



drop function if exists mod_articulos_orden_propiedades  (integer,integer);
CREATE OR REPLACE FUNCTION mod_articulos_orden_propiedades (integer,integer) returns text as
$BODY$
declare
-- Intercambio del orden entre  propiedades y/o familias.
-- supondremos que se desea intercambiar el orden de la propiedad-valor del primer parámetro, con el orden del segundo parámetro. 
-- Tanto el primer como el segundo parámetro puede se el id de una familia o de una familia_propiedad (tabla familias.id o  familias_propiedades.id).
-- Se supone que lo que se desea es que el orden de la familia_propiedad (o familia) de p_i1 ha de estar posterior al valor de la familia_propiedad (o famila) de p_i2. Si no lo están, se intercambia internamente dichos parámetros.
-- Si suponemos que p_i1 es de una familia_propiedad de Medida corta, y p_i2 es de una familia_propiedad de modelo (queremos intercambiar el orden para que el modelo vaya antes que la medida):
--	Al intercambiar el orden, seleccionamos el orden menor para la propiedad Medida Corta, y la máxima para Modelo dentro de la familia (y descendientes) a la que pertenece p_i1 y p_i2. 
--	Estos dos ordenes (mínimo y máximo) se intercambiarán en los registros correspondientes de familas_propiedades apuntados por p_i1 y p_i2.
--	Al hacer esto, todos los grupos de la famila o descendientes que contengan referencias a estas dos propiedades_valores, habrán cambiado su orden de colocación dentro del grupo

  p_i1 alias for $1;
  p_i2 alias for $2;
  p_id integer;
  p_id2 integer;
  p_oid integer;
  p_oid2 integer;
  p_orden1 integer;
  p_orden2 integer;

  r record;
  
begin

-- Se busca en una sola consulta si es un id de familia,  o de familia_propiedad
	
	select f.id as f_id, f.orden as f_orden, 
		ap.id as ap_id, ap.propiedad_id as fp_propiedad_id,ap.familia_id as fp_familia_id, ap.orden as ap_orden, 
		f2.id as f2_id, f2.orden as f2_orden, 
		ap2.id as ap2_id, ap2.propiedad_id as fp2_propiedad_id,ap2.familia_id as fp2_familia_id, ap2.orden as ap2_orden into r
	from 
		(select id,orden from familias f  where id=p_i1 union select null::integer, null::integer) f
		,( select fp.id , fp.propiedad_id ,fp.familia_id, fp.orden from familias_propiedades fp where fp.id=p_i1
			union select null::integer,null::integer,null::integer,null::integer
		) ap,  
		(select fp2.id , fp2.propiedad_id ,fp2.familia_id, fp2.orden from familias_propiedades fp2 where fp2.id=p_i2
			union select null::integer,null::integer,null::integer,null::integer
		) ap2 
		, (select id,orden from familias f2 where id=p_i2 union select null::integer, null::integer) f2
	WHERE (ap.id=p_i1 or f.id=p_i1) and (ap2.id=p_i2 or f2.id=p_i2);


	 
	-- cogemos el orden ya sea de la familia o de la familia_propiedad

	p_oid:=greatest(r.f_orden,r.ap_orden);
	p_oid2:=greatest(r.f2_orden,r.ap2_orden);

	if p_oid is null or p_oid2 is null or p_i1 is null or p_i2 is null then
	   return 'Para el primer parámetro '||coalesce(p_i1,'nulo')||' el orden establecido es '||coalesce(p_oid1,'nulo')||'. Para el segundo parametro '||coalesce(p_i2,'nulo')||' el orden es '||coalesce(p_oid2,'nulo');
	end if;
	
	if p_oid=p_oid2 then
		return 'OK'; -- si tienen el mismo orden no hacemos nada
	end if;
	
	--Si el orden del primer parámetro es mayor que el del segundo lo invertimos. La lógica de esta función presupone que el orden del primer parámetro es menor
	if p_oid>p_oid2 then 
		p_id:=	p_i2;
		p_id2:=	p_i1;

		select f.id as f_id, f.orden as f_orden, 
			ap.id as ap_id, ap.propiedad_id as fp_propiedad_id,ap.familia_id as fp_familia_id, ap.orden as ap_orden, 
			f2.id as f2_id, f2.orden as f2_orden, 
			ap2.id as ap2_id, ap2.propiedad_id as fp2_propiedad_id,ap2.familia_id as fp2_familia_id, ap2.orden as ap2_orden into r
		from 
			(select id,orden from familias f  where id=p_id1 union select null::integer, null::integer) f
			,( select fp.id , fp.propiedad_id ,fp.familia_id, fp.orden from familias_propiedades fp where fp.id=p_id1
				union select null::integer,null::integer,null::integer,null::integer
			) ap,  
			(select fp2.id , fp2.propiedad_id ,fp2.familia_id, fp2.orden from familias_propiedades fp2 where fp2.id=p_id2
				union select null::integer,null::integer,null::integer,null::integer
			) ap2 
			, (select id,orden from familias f2 where id=p_id2 union select null::integer, null::integer) f2
		WHERE (ap.id=p_id1 or f.id=p_id1) and (ap2.id=p_id2 or f2.id=p_id2);
	else
		p_id:=	p_i1;
		p_id2:=	p_i2;	
	end if;
	
	
	if r.ap_id is not null and r.ap2_id is not null then --se desea intercambiar el orden de dos propiedades
		update familias_propiedades set orden=case when familias_propiedades.familia_id=t.fam1 and familias_propiedades.propiedad_id=t.prop1 then t.maxorden else t.minorden end 
		from (
			with fp as (
				select fp1.familia_id as familia1,fp1.propiedad_id as propiedad1, fp2.familia_id as familia2,fp2.propiedad_id as propiedad2
				from familias_propiedades fp1 inner join familias_propiedades fp2 on fp1.id=p_id and fp2.id=p_id2
			)
			select min(fp.familia1) as fam1, min(fp.propiedad1)as prop1,max(fp.familia2) as fam2, max(fp.propiedad2) as prop2, min(case when fp1.familia_id=fp.familia1 and fp1.propiedad_id=fp.propiedad1 then fp1.orden else null end) as minorden,max(case when fp1.familia_id=fp.familia2 and fp1.propiedad_id=fp.propiedad2 then fp1.orden else null end) as maxorden
			from familias_propiedades fp1 inner join fp on (fp1.familia_id=fp.familia1 and fp1.propiedad_id=fp.propiedad1) or (fp1.familia_id=fp.familia2 and fp1.propiedad_id=fp.propiedad2)
		) t	
		where ((familias_propiedades.familia_id=t.fam1 and familias_propiedades.propiedad_id=t.prop1) or 
			(familias_propiedades.familia_id=t.fam2 and familias_propiedades.propiedad_id=t.prop2))  
			and t.minorden is not null and t.maxorden is not null;
	elsif r.f_id is not null and r.f2_id is not null then -- se desea intercambiar el orden de dos familas
		update familias set orden=r.f2_orden where id=r.f_id;
		update familias set orden=r.f_orden where id=r.f2_id;
	elsif r.ap_id is not null then --se desea intercambiar el orden de una familia y una propiedad. la famimlia es el segundo id
		select min(orden) into p_orden1 from familias_propiedades where familia_id=r.fp_familia_id and propiedad_id=r.fp_propiedad_id;
		if p_orden1 is not null and r.f2_id is not null then
			update familias set orden=p_orden1 where id=r.f2_id;
			update familias_propiedades set orden=r.f2_orden where familia_id=r.fp_familia_id and propiedad_id=r.fp_propiedad_id;
		end if;
	elsif r.ap2_id is not null then --se desea intercambiar el orden de una familia y una propiedad. la familia es el primer id
		select max(orden) into p_orden2 from familias_propiedades where familia_id=r.fp2_familia_id and propiedad_id=r.fp2_propiedad_id;
		if p_orden2 is not null and r.f_id is not null then
			update familias set orden=p_orden2 where id=r.f_id;
			update familias_propiedades set orden=r.f_orden where familia_id=r.fp2_familia_id and propiedad_id=r.fp2_propiedad_id;
		end if;
	end if;
	return 'OK';
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
  


/* ***********  Ejemplos de uso
1) obtener todos los campos de la tabla artículo codarticulo, tcorto,tlargo,tcomercial que compondrá cada grupo de una familia (la familia 12 en este caso)
	select * from mod_articulos_nombre(17,array[]::integer[],array[]::integer[],array[]::integer[]);
2) Si lo restringimos a unos determinados grupos dentro de la familia 12:
	select * from mod_articulos_nombre(12,array[159,160]::integer[],array[]::integer[],array[]::integer[]);
3) Si lo restringimos a todos los grupos que contengan un determinado valor (familia 0 significa todas las familias)
	select * from mod_articulos_nombre(0,array[]::integer[],array[]::integer[],array[25]::integer[]);
4) Si lo restringimos a todos los grupos que contengan una determinada propiedad
	select * from mod_articulos_nombre(0,array[]::integer[],array[]::integer[],array[25]::integer[]);
5) Si lo restringimos a todos los grupos que contengan una determinada propiedad
	select * from mod_articulos_nombre(0,array[]::integer[],array[2]::integer[],array[]::integer[]);
*/
	
select  array_agg(id::text), nomlargo from mod_articulos_nombre(17,array[]::integer[],array[]::integer[],array[]::integer[]) group by nomlargo having count(*)>1
select * from mod_articulos_nombre  (17 
select * from articulos
drop function mod_articulos_nombre  (IN integer, IN integer[],  In integer[], IN integer[]);
update familias set componer_id=4 where componer_id=3; -- cuando queremos que aparezca el texto de la familia en el nombre del artículo, la lógica está implementada con componer_id=4 (valor) 

CREATE OR REPLACE FUNCTION mod_articulos_nombre  (IN integer, IN integer[],  In integer[], IN integer[],
	Out id integer, OUT cod character(15),OUT NOMCORTO TEXT, OUT nomlargo TEXT, OUT nomcomercial TEXT)
  RETURNS SETOF record AS
$BODY$
declare


  p_idfamilia alias for $1;
  p_idgrupo alias for $2;
  p_idpropiedad alias for $3;
  p_idvalor alias for $4;
  P_Sql text;
  r record;
  p_from_familia text;
  
  p_where_grupo text;
  p_having_propiedad text;
  p_having_valor text;
  
 begin


        if p_idfamilia=0 then
		p_from_familia:='mod_propiedades_heredadas_bsc(0';
	else
		p_from_familia:='mod_propiedades_heredadas_bsc('||p_idfamilia;
	end if;
	
	p_where_grupo:=case when array_length(p_idgrupo,1)> 0 then ' and array[grupo_id] && array'||translate(p_idgrupo::text,'{}','[]') else '' end; -- El grupo esté entre los pasados (un grupo compone todas las propiedades heredadas o no de un artículo)
	p_having_propiedad:=case when array_length(p_idpropiedad,1)> 0 then ' and array_agg(propiedad_id) && array'||translate(p_idpropiedad::text,'{}','[]') else '' end; --la propiedad esté incluida en el grupo que estamos analizando
	p_having_valor:=case when array_length(p_idvalor,1)> 0 then ' and (array_agg(familia_propiedad_id) && array'||translate(p_idvalor::text,'{}','[]') else '' end; -- el id de valor esté en el grupo que estamos analizando
	
		
		
		-- el with nos devuelve todo el grupo de propiedades-valores y familias que compone la familia pasada
	p_sql:=		'with jerarquia as( '||chr(10);
	p_sql:=p_sql||'		select distinct familia_id,familia, propiedad_id, propiedad, familia_propiedad_id, valor, orden '||chr(10);
	p_sql:=p_sql||'		from  ( '||chr(10);
	p_sql:=p_sql||'			select familia_id,familia,propiedad_id, propiedad, familia_propiedad_id, valor, orden  from '||p_from_familia||',false)  '||chr(10); --ascendentes
	p_sql:=p_sql||'			union distinct '||chr(10);
	p_sql:=p_sql||'			select familia_id,familia,propiedad_id, propiedad, familia_propiedad_id, valor, orden  from '||p_from_familia||',true) '||chr(10); --descendentes
	p_sql:=p_sql||'		) t '||chr(10);
	p_sql:=p_sql||') '||chr(10);
 
	p_sql:=p_sql||'select grupo.id as grupo_id, '||chr(10);
	p_sql:=p_sql||'		regexp_replace(string_agg(case when jerarquia.propiedad_id is null and familia_componer.describe like ''cod%'' then familias.codfamilia '||chr(10);
	p_sql:=p_sql||'						when jerarquia.propiedad_id is not null and '||chr(10);
	p_sql:=p_sql||'							(corto.describe like ''cod%'' or largo.describe like ''cod%''  or comercial.describe like ''cod%'') then '||chr(10); 
	p_sql:=p_sql||'							famprop.cod '||chr(10);
	p_sql:=p_sql||'						else '''' end '||chr(10);
	p_sql:=p_sql||'					,'''' ORDER BY jerarquia.orden)'||chr(10);
	p_sql:=p_sql||'				,''\s+'', '' '',''g'')::character(15) as codarticulo, --sustituye todos los espacios en blanco consecutivos por uno solo'||chr(10);
	p_sql:=p_sql||'		regexp_replace(string_agg(case when jerarquia.propiedad_id is null and familia_componer.describe like ''%valor%'' then jerarquia.familia '||chr(10);
	p_sql:=p_sql||'						when jerarquia.propiedad_id is not null and (corto.describe like ''%propiedad + valor'') then '||chr(10);
	p_sql:=p_sql||'							pcorto.tcorto||'' ''||jerarquia.valor '||chr(10);
	p_sql:=p_sql||'						when jerarquia.propiedad_id is not null and (corto.describe like ''%propiedad'') then pcorto.tcorto '||chr(10);
	p_sql:=p_sql||'						when jerarquia.propiedad_id is not null and (corto.describe like ''%valor'') then jerarquia.valor '||chr(10);
	p_sql:=p_sql||'						else '''' end '||chr(10);
	p_sql:=p_sql||'					,'' '' ORDER BY jerarquia.orden) '||chr(10);
	p_sql:=p_sql||'				,''\s+'', '' '',''g'') as tcorto, --sustituye todos los espacios en blanco consecutivos por uno solo'||chr(10);
	p_sql:=p_sql||'		regexp_replace(string_agg(case when jerarquia.propiedad_id is null and familia_componer.describe like ''%valor%'' then jerarquia.familia '||chr(10);
	p_sql:=p_sql||'						when jerarquia.propiedad_id is not null and (largo.describe like ''%propiedad + valor'') then '||chr(10);
	p_sql:=p_sql||'							plargo.tlargo||'' ''||jerarquia.valor '||chr(10);
	p_sql:=p_sql||'						when jerarquia.propiedad_id is not null and (largo.describe like ''%propiedad'') then plargo.tlargo '||chr(10);
	p_sql:=p_sql||'						when jerarquia.propiedad_id is not null and (largo.describe like ''%valor'') then jerarquia.valor '||chr(10);
	p_sql:=p_sql||'						else '''' end '||chr(10);
	p_sql:=p_sql||'					, '' '' ORDER BY jerarquia.orden) '||chr(10);
	p_sql:=p_sql||'				,''\s+'', '' '',''g'') as tlargo, '||chr(10);
	p_sql:=p_sql||'		regexp_replace(string_agg(case when jerarquia.propiedad_id is null and familia_componer.describe like ''%valor%'' then jerarquia.familia '||chr(10);
	p_sql:=p_sql||'						when jerarquia.propiedad_id is not null and (comercial.describe like ''%propiedad + valor'') then '||chr(10);
	p_sql:=p_sql||'							pcomercial.tcomercial||'' ''||jerarquia.valor '||chr(10);
	p_sql:=p_sql||'						when jerarquia.propiedad_id is not null and (comercial.describe like ''%propiedad'') then pcomercial.tcomercial '||chr(10);
	p_sql:=p_sql||'						when jerarquia.propiedad_id is not null and (comercial.describe like ''%valor'') then jerarquia.valor '||chr(10);
	p_sql:=p_sql||'						else '''' end '||chr(10);
	p_sql:=p_sql||'					, '' '' ORDER BY jerarquia.orden) '||chr(10);
	p_sql:=p_sql||'				,''\s+'', '' '',''g'')	as tcomercial '||chr(10);
	p_sql:=p_sql||'from articulos grupo '||chr(10);
	p_sql:=p_sql||'		inner join( '||chr(10);
	p_sql:=p_sql||'			jerarquia '||chr(10);
	p_sql:=p_sql||'		left JOIN '||chr(10);
	p_sql:=p_sql||'			(articulos_propiedades inner join familias_propiedades famprop on articulos_propiedades.fp_id=famprop.id '||chr(10);
	p_sql:=p_sql||'				INNER JOIN (propiedades pcorto inner join propiedades_componer corto on pcorto.componertcorto_id=corto.id) ON famprop.propiedad_id=pcorto.id '||chr(10);
	p_sql:=p_sql||'				INNER JOIN (propiedades plargo inner join propiedades_componer largo on plargo.componertlargo_id=largo.id) ON famprop.propiedad_id=plargo.id '||chr(10);
	p_sql:=p_sql||'				INNER JOIN (propiedades pcomercial inner join propiedades_componer comercial on pcomercial.componertcomercial_id=comercial.id ) ON famprop.propiedad_id=pcomercial.id '||chr(10);
	p_sql:=p_sql||'			) on jerarquia.familia_propiedad_id=articulos_propiedades.fp_id '||chr(10);
	p_sql:=p_sql||'		LEFT JOIN '||chr(10);
	p_sql:=p_sql||'			(familias inner join propiedades_componer familia_componer on familias.componer_id=familia_componer.id)  '||chr(10);
	p_sql:=p_sql||'			on jerarquia.familia_id=familias.id  and jerarquia.propiedad_id is null '||chr(10);
	p_sql:=p_sql||'	) on grupo.id=articulos_propiedades.grupo_id or familias.id is not null '||chr(10);
	p_sql:=p_sql||'where grupo.familia_id '||case when p_idfamilia=0 then ' is not null ' else '='||p_idfamilia end||p_where_grupo||chr(10);--haya grupo creado en la familia de análisis y el grupo pertenezca a alguno de los pasados
	p_sql:=p_sql||'group by grupo.id '||chr(10);
	p_sql:=p_sql||case when length(p_having_propiedad)>0 then 'having '||p_having_propiedad||p_having_valor else '' end||chr(10);
	p_sql:=p_sql||'	order by grupo.id '||chr(10); 
	

		
 --raise exception '%',p_sql;
 return query execute p_sql;

END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;

"Dimensiones -> Producto -> Ancho: 200"
"Dimensiones -> Producto -> Ancho: 80"

select mod_propiedades_valoresligados_pdtes(103)

CREATE OR REPLACE FUNCTION mod_propiedades_valoresligados_pdtes  (IN integer, Out valor text, OUT id integer)
  RETURNS SETOF record AS
$BODY$
-- Función que calcula los elementos que se pueden visualizar en la interface de valoresligados. 
--Se le pasa un id de familias_propiedades, y devolverá todos las propiedade con sus valores (en formato texto) con los posibles candidatos a  ponerse como valor ligado
declare
  p_fp_id alias for $1;
  p_prop integer;
begin
	select propiedades.id into p_prop
	from familias_prpropied
	
	return query
		with valores as (
			select t.propiedad||': '||t.valor as valor,t.familia_propiedad_id,t.ptopiedad_id
			from mod_propiedades_heredadas_bsc(1,false) t
			where propiedad_id is not null and t.propiedad_id is not null
		)
		select valores.valor,valores.familia_propiedad_id 
		from valores 
		where propiedad_id<>p_fp_id 
		except
		select propiedades.tlargo||': '||f.valor as valor, v.fp2_id
		from valores inner join familias_valoresligados v on valores.familia_propiedad_id=v.fp_id 
			inner join familias_propiedades f on v.fp2_id=f.id inner join propiedades on f.propiedad_id=propiedades.id
		order by valor;
end;	
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;


