/* Funciones de BD del móulo de propiedades, familias y artículos */

--select MOD_propiedades_opt('propnumerica|#id|#componertcorto|$campo2|#campo3','t|#5|#14|$hola|#caracola','5,8')
CREATE OR REPLACE FUNCTION MOD_propiedades_conf(IN integer, IN integer, OUT campos text, OUT iu text, OUT tipo text, 
    OUT tabla text, OUT bsc text, OUT c_ajena text, OUT  dependencias text, OUT b_exacta TEXT,  OUT tamanio text)
  RETURNS SETOF record AS
$BODY$
	-- Se le pasa un identificador de usuario y un id de contexto y retornará un conjunto de registros:
	-- con las propiedades que van a tener los campos de una determinada consulta (en este caso de las propiedades de los artículos)
	
declare 

	p_idusuario alias for $1;
	p_contexto alias for $2;
	-- Tantos elementos como campos tenga la consulta que queremos conseguir. 
	p_sql text;
	p_campos text[];
	p_iu text[];
	p_tipo text[];
	p_tabla text[];
	p_bsc text[];
	p_c_ajena text[];
	p_dependencias text[];
	p_b_exacta text[];
	p_tamanio integer[];
	s_campos text;
	s_iu text;
	s_tipo text;
	s_tabla text;
	s_bsc text;
	s_c_ajena text;
	s_dependencias text;
	s_b_exacta text;
	s_tamanio text;
	p_opciones text;
	p_opciones_id integer;
begin  
/*
Campos ::text . Texto separado por un separador. Cada elemento se corresponde con el nombre de un campo
iu ::text. Texto separado por un separador. Cada elemento se corresponde con el nombre a poner en la interfaz de un campo.
tipo. Texto separado por  un separador
tabla ::text. Texto separado por un separador
bsc ::text. Texto separado por un separador
c_ajena ::text Texto separado por un separador
dependencias ::text. Texto separado por un separador
b_exacta ::text. Texto separado por un separador
tamanio ::text. Texto separado por un separador
opcion_id */

p_campos[0]:='id';p_iu[0]:='';p_tipo[0]:='integer';p_tabla[0]:='propiedades';p_bsc[0]:='MOD_propiedades';p_c_ajena[0]:='pk';
p_dependencias[0]:='';p_b_exacta[0]:='true';p_tamanio[0]:=0;

p_campos[1]:='codpropiedad';p_iu[1]:='Cod. Propiedad';p_tipo[1]:='text';p_tabla[1]:='propiedades';p_bsc[1]:='MOD_propiedades';p_c_ajena[1]:='';
p_dependencias[1]:='';p_b_exacta[1]:='true';p_tamanio[1]:=5;

p_campos[2]:='tcorto';p_iu[2]:='Texto Corto';p_tipo[2]:='text';p_tabla[2]:='propiedades';p_bsc[2]:='MOD_propiedades';p_c_ajena[2]:='';
p_dependencias[2]:='';p_b_exacta[2]:='false';p_tamanio[2]:=15;

p_campos[3]:='tlargo';p_iu[3]:='Texto Largo';p_tipo[3]:='text';p_tabla[3]:='propiedades';p_bsc[3]:='MOD_propiedades';p_c_ajena[3]:='';
p_dependencias[3]:='';p_b_exacta[3]:='false';p_tamanio[3]:=20;

p_campos[4]:='tcomercial';p_iu[4]:='Texto Comercial';p_tipo[4]:='text';p_tabla[4]:='propiedades';p_bsc[4]:='MOD_propiedades';p_c_ajena[4]:='';
p_dependencias[4]:='';p_b_exacta[4]:='false';p_tamanio[4]:=20;

p_campos[5]:='propnumerica';p_iu[5]:='¿Prop. Numerica?';p_tipo[5]:='boolean';p_tabla[5]:='propiedades';p_bsc[5]:='MOD_propiedades';p_c_ajena[5]:='';
p_dependencias[5]:='';p_b_exacta[5]:='false'; p_tamanio[5]:=20;

p_campos[6]:='componertcorto_id';p_iu[6]:='';p_tipo[6]:='integer';p_tabla[6]:='propiedades';p_bsc[6]:='MOD_propiedades';p_c_ajena[6]:='';
p_dependencias[6]:='';p_b_exacta[6]:='false';p_tamanio[6]:=0;

p_campos[7]:='componertlargo_id';p_iu[7]:='';p_tipo[7]:='integer';p_tabla[7]:='propiedades';p_bsc[7]:='MOD_propiedades';p_c_ajena[7]:='';
p_dependencias[7]:='';p_b_exacta[7]:='false';p_tamanio[7]:=0;
    
p_campos[8]:='componertcomercial_id';p_iu[8]:='id';p_tipo[8]:='integer';p_tabla[8]:='propiedades';p_bsc[8]:='MOD_propiedades';p_c_ajena[8]:='';
p_dependencias[8]:='';p_b_exacta[8]:='false';p_tamanio[8]:=0;

p_campos[9]:='op_corta';p_iu[9]:='Art. Heredan de Desc. Corta';p_tipo[9]:='text';p_tabla[9]:='propiedades_componer';p_bsc[9]:='MOD_propiedades_componer';p_c_ajena[9]:='componertcorta_id';
p_dependencias[9]:='';p_b_exacta[9]:='false';p_tamanio[9]:=10;

p_campos[10]:='op_larga';p_iu[10]:='Art. Heredan de Desc. Larga';p_tipo[10]:='text';p_tabla[10]:='propiedades_componer';p_bsc[10]:='MOD_propiedades';p_c_ajena[10]:='componertlarga_id';
p_dependencias[10]:='';p_b_exacta[10]:='false';p_tamanio[10]:=10;

p_campos[11]:='op_comercial';p_iu[11]:='Art. Heredan Desc. Comercial';p_tipo[11]:='text';p_tabla[11]:='propiedades_componer';p_bsc[11]:='MOD_propiedades_componer';p_c_ajena[11]:='componertcomercial_id';
p_dependencias[11]:='';p_b_exacta[11]:='false';p_tamanio[11]:=10;

s_campos:=array_to_string(p_campos,'|');
s_iu:=array_to_string(p_iu,'|');
s_tipo:=array_to_string(p_tipo,'|');
s_tabla:=array_to_string(p_tabla,'|');
s_bsc:=array_to_string(p_bsc,'|');
s_c_ajena:=array_to_string(p_c_ajena,'|');
s_dependencias:=array_to_string(p_dependencias,'|');
s_b_exacta:=array_to_string(p_b_exacta,'|');
s_tamanio:=array_to_string(p_tamanio,'|');

return query execute 'select $1 as campos, $2 as iu, $3 as tipo, $4 as tabla, $5 as bsc, $6 as c_ajena, $7 as dependencias, $8 as b_exacta, $9 as tamanio'
      using s_campos,s_iu,s_tipo,s_tabla, s_bsc, s_c_ajena, s_dependencias, s_b_exacta, s_tamanio;


END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION mod_propiedades_conf(integer, integer)
  OWNER TO stg;



  CREATE OR REPLACE FUNCTION MOD_propiedades_bsc(IN integer, IN integer, IN text, IN text,IN TEXT, OUT id integer, OUT codpropiedad character varying(5), OUT tcorto character VARYING(60), 
    OUT tlargo character varying(100), OUT tcomercial character varying(100), OUT propnumerica boolean, OUT componertcorto_id integer, OUT componertlargo_id integer, OUT componertcomercial_id integer, OUT op_corta character varying(25), 
    OUT op_larga character varying(25), OUT op_comercial character varying(25))
  RETURNS SETOF record AS
$BODY$
    -- Se le pasa un identificador de usuario, un id de contexto, un conjunto de nombres de campos, un conjunto de valores, y un conjunto de operadores (like,=, in ...) 
    -- y retornará un conjunto de registros, en este caso correspondientes a las propiedades filtradas acorde con los campos valores y operadores pasados, y con 
    -- los que se construirá ya aplicará la propia clausula where
declare 

    p_idusuario alias for $1;
    p_contexto alias for $2;
    p_where_campos alias for $3;
    p_where_valores alias for $4;
    p_where_operadores alias for $5;
    p_sql text;
    
begin  

  p_sql:=    'select propiedades.id, propiedades.codpropiedad, propiedades.tcorto, propiedades.tlargo, propiedades.tcomercial, propiedades.propnumerica, ';
  p_sql:=p_sql||'propiedades.componertcorto_id, propiedades.componertlargo_id, propiedades.componertcomercial_id, pcorta.describe as op_corta, ';
  p_sql:=p_sql||'plarga.describe as op_larga, pcomercial.describe as op_comercial  ';
  p_sql:=p_sql||'from propiedades inner join propiedades_componer pcorta on propiedades.componertcorto_id=pcorta.id ';
  p_sql:=p_sql||'inner join propiedades_componer plarga on propiedades.componertlargo_id=plarga.id ';
  p_sql:=p_sql||'inner join propiedades_componer pcomercial on propiedades.componertcomercial_id=pcomercial.id ';

  return query execute p_sql;

END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;

insert into familias_grupos_propiedades (familia_id) values (15);
insert into familias_grupos_propiedades_detalles (id,propiedad_pack_linea_id,propiedad_grupo_id) values (nextval('familias_grupos_propiedades_id_seq'), 16,1)
returning count(*);
select * from familias_grupos_propiedades_detalles
returning currval('familias_grupos_propiedades_id_seq');

delete from familias_grupos_propiedades_detalles where id=null


select * from familias_grupos_propiedades_detalles;

select currval('familias_grupos_propiedades_id_seq')
CREATE OR REPLACE FUNCTION mod_propiedades_grupos_opt(integer,integer,integer,character(10),) returns text as
$BODY$
declare
	p_idfamilia alias for $1;
	p_idgrupo alias for $2;
	p_idlineapack alias for $3
	p_op alias for $4;
	p_grupo integer;
	p_msg text;
begin
   
      p_msg:= case when p_idfamilia is null then 'Familia inexistente ' 
		when p_idlineapack is null then 'propiedad valor inexistente'
		else ''
	    end;
	if length(p_msg)>0 then 
		return p_msg;
	end if;
	if p_op='inserta' then
		if p_idgrupo is null then --crear el grupo
			insert into familias_grupos_propiedades (id,familia_id) values (nextval('familias_grupos_propiedades_id_seq'), p_idfamilia)
			returning id into p_grupo;
		else
			p_grupo:=p_idgrupo;
		end if;
		insert into familias_grupos_propiedades_detalles (propiedad_pack_linea_id,propiedad_grupo_id) values (p_idlineapack,p_grupo);
		return 'OK';
	end if;
	if p_op='elimina' then
		delete from familias_grupos_propiedades_detalles where propiedad_pack_linea_id=p_idlineapack and propiedad_grupo_id=p_idgrupo;
	  --select codarticulo, nomarticulo from articulos where 
	end if;
end;
$BODY$
LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;



drop function if exists mod_propiedades_heredadas_bsc  (IN integer, IN boolean);
CREATE OR REPLACE FUNCTION mod_propiedades_heredadas_bsc  (IN integer, IN boolean, 
	OUT familia_id INTEGER, OUT padre_id INTEGER,OUT familia CHARACTER varying(100) , out propiedad_id integer,OUT propiedad CHARACTER varying(60), OUT familia_propiedad_id integer,
	OUT valor CHARACTER varying(200),OUT procedencia CHARACTER(20),
	Out orden integer, OUT path text)
  RETURNS SETOF record AS
$BODY$
    -- Se le pasa un  identificador de familia y te mostrará dependiendo de p_descendientes:
    --p_descendentes => true
    --	Se procesan en la búsqueda las propiedades y familias descendientes de la familia pasada
    --p_incluirdescendentes => false
    --  Se procesaon en la búsqueda los las propiedades y familias ascendentes de la familia pasada
    
declare 
    p_idfamilia alias for $1;
    p_descendientes alias for $2;
    p_sql text;
    p_from text;


begin  
	--conformamos la clausula from
	p_from:='	FROM    familias left join ('||chr(10);
	p_from:=p_from||'			familias_propiedades fp  '||chr(10);
	p_from:=p_from||'			inner join propiedades on fp.propiedad_id=propiedades.id '||chr(10);
	p_from:=p_from||'										) on familias.id=fp.familia_id '||chr(10);

	p_sql:='WITH RECURSIVE grupos_padre AS ('||chr(10);
	p_sql:=p_sql||'	SELECT  familias.id as familia_id, familias.padre_id, familias.describe as familia, propiedades.id as propiedad_id, propiedades.tcorto as propiedad, fp.id as familia_propiedad_id,fp.valor, '||chr(10);
	p_sql:=p_sql||'		case when propiedades.id is null then ''familia'' else ''propia'' end::character(20) as procedencia, fp.orden, familias.describe::text as path '||chr(10);
	p_sql:=p_sql||p_from;
	p_sql:=p_sql||'	WHERE familias.id='||p_idfamilia||' '||chr(10); 

	p_sql:=p_sql||'	UNION '||chr(10); 
	p_sql:=p_sql||'	SELECT familias.id as familia_id, familias.padre_id, familias.describe as familia, propiedades.id as propiedad_id, propiedades.tcorto as propiedad, fp.id as familia_propiedad_id,fp.valor, '||chr(10);
	p_sql:=p_sql||'        case when propiedades.id is null then ''familia'' else ''heredada'' end::character(20) as procedencia, fp.orden, '||chr(10);
	p_sql:=p_sql||'		case 	when  grupos_padre.familia_id=familias.padre_id then grupos_padre.path||''->''||familias.describe::text '||chr(10);
	p_sql:=p_sql||'			when grupos_padre.padre_id=familias.id then familias.describe||''->''||grupos_padre.path '||chr(10);
	p_sql:=p_sql||'		end as path '||chr(10);
	p_sql:=p_sql||p_from||', grupos_padre '||chr(10);
	
	if p_descendientes then
		p_sql:=p_sql||'	where grupos_padre.familia_id=familias.padre_id '||chr(10);
	else
		p_sql:=p_sql||'	where grupos_padre.padre_id=familias.id '||chr(10);
        end if;
	p_sql:=p_sql||') -- fin de with recursivo'||chr(10);
	p_sql:=p_sql||'SELECT * FROM grupos_padre order by length(path) desc,orden; '||chr(10);
	
  return query execute p_sql;

END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;


except
(
with  g as(
select null::integer as a
)
select g.a from g
);

array[select 1]

	with grupos as (
		select agp.id as grupo_id,ap.fp_id,fp.propiedad_id 
		from articulos_grupopropiedades agp inner join articulos_propiedades ap on agp.id=ap.grupo_id inner join familias_propiedades fp 
		on ap.fp_id=fp.id inner join propiedades on fp.propiedad_id=propiedades.id 
		where agp.familia_id in (select distinct familia_id from mod_propiedades_heredadas_bsc(1,true))
	)
	select distinct grupo_id 
	from 
	(select grupo_id,string_to_array(concatenate(propiedad_id::text),', ')::int[] as vector from grupos group by grupo_id) t 
	where not t.vector@>array[1,2,3]; --no contiene todas las propiedades

select distinct familia_id,propiedad_id,valor,familia_propiedad_id from mod_propiedades_heredadas_bsc  (16,false)
select mod_propedades_combinacion_valida(16,array[1,10,23],array[1,19,29]);--propiedad incompatible

explain analyze
select f.propiedad_id,array_search(f.propiedad_id,array[10,2,23]) as pospropiedad,array_agg(v.fp2_id::text||'|'||f2.propiedad_id::text||'|'||array_search(f2.propiedad_id,array[10,2,23])::text) as vligues
from mod_propiedades_heredadas_bsc(16,false) f	inner join familias_valoresligados v on f.familia_propiedad_id=v.fp_id
			inner join familias_propiedades f2 on v.fp2_id=f2.id
where f.familia_propiedad_id = any(array[18,8,29]) and (array[f2.propiedad_id] && array[10,2,23])
group by f.propiedad_id,array_search(f.propiedad_id,array[10,2,23]) 

create or replace function mod_propedades_combinacion_valida_old(integer,integer[],integer[]) returns boolean as
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

create or replace function mod_propedades_combinacion_valida(integer,integer[],integer[]) returns boolean as
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
  
select 'a'||array[1,2,3]::text   

select 1
where 12>23+34
select t.a[4]
 from (select array[1,2,null,3] a) t
select mod_propiedades_generar_grupos (17);

select * from articulos_grupopropiedades;
select * from propiedades

select art_propiedades.grupo_id,familias.id as familia_id,familias.describe, propiedades.tcorto,familias_propiedades.valor
from articulos_propiedades art_propiedades  inner join familias_propiedades on art_propiedades.fp_id=familias_propiedades.id
inner join familias on familias_propiedades.familia_id=familias.id inner join propiedades on familias_propiedades.propiedad_id=propiedades.id


select * from articulos_grupopropiedades

familias inner join articulos_grupopropiedades grupos on familias.id=grupos.familia_id
inner join  on grupos.id=art_propiedades.grupo_id
inner join familias_propiedades on familias.id=familias_propiedades.familia_id 
inner join propiedades on familias_propiedades.propiedad_id=propiedades.id
order by grupos.id

select * from articulos_propiedades

drop function if exists mod_propiedades_generar_grupos  (integer);

select 1
except
select null

delete from articulos_propiedades
select * from propiedades left join 
(with prop as (
 select * from familias_propiedades
 )
 select * from prop
)t on propiedades.id =t.propiedad_id

CREATE OR REPLACE FUNCTION mod_propiedades_generar_grupos(integer)
  RETURNS text as
$BODY$
--Esta función retornará el producto cartesiano de todas las posibles combinaciones de valores de las diferentes propiedades encontradas (y heredadas) en una familia. 
--Dicho producto cartesiano será introducido en la tabla articulosgrupopropiedades y articulos_propiedades. Si ya existiensen grupos de propiedades de esta famila o sucesoras, 
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
		--Construimos una consulta con tantas tablas como propiedades (distintas propias o heredadas) existan en dicha familia.
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
	p_grupo:=p_grupo||') t on '||p_array||'@>t.valores_id '||chr(10); --La combinación de valores actual ha de contener a los valores del grupo de propiedades
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
	raise 'SELECT:%  aRRAY: % JOIN: % WHERE: % SQL %', P_SELECT,P_ARRAY, P_JOIN, P_WHERE,p_sql;
	
	
	raise '%', p_sql;
		
	--ahora recorresmos todas las combinaciones. 2 posibilidades para plasmar cada combinación 
	-- 1) Si existe grupo_id =>insertamos en dicho grupo_id una o tantas propiedades como diga el campo valores_grupo_insertar en la tabla articulos_propiedades
	-- 2) si no existe grupo_id=> insertamos un grupo nuevo en la familia, y le añadimos todos los valores del array 
	for r in execute p_sql loop
	--cada registro contiene una combinación de propiedades/valores para conformar un grupo que hay que insertar. 
		if r.grupo_id is not null then
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


CREATE OR REPLACE FUNCTION mod_propiedades_generar_grupos_Old(integer)
  RETURNS text as
$BODY$
declare
    p_idfamilia alias for $1;
    p_sql text;
    p_select text;
    p_array text;
    p_join text;
    p_where text;
    p_prop integer[];
    p_grupo text;
    p_grupos integer[];
    p_grupo_select text;
    p_grupo_join text;
    p_grupo_where text;
    p_except text;
    p_aux text;
    p_grupo_array text;
    p_p0 integer; --propiedad 0
    r record;
    i integer;
    p_ngrupo integer;
    p_idgrupo integer;

begin
        p_sql:='';
        i:=0;
        --en p_grupos estarán las combinaciones ya establecidas. Restaremos combinaciones que se generan - combinaciones ya generadas
        p_grupo:='with grupos as (';
        p_grupo:=p_grupo||'	select agp.id as grupo_id,ap.fp_id,fp.propiedad_id ';
	p_grupo:=p_grupo||'	from articulos_grupopropiedades agp inner join articulos_propiedades ap on agp.id=ap.grupo_id inner join familias_propiedades fp ';
	p_grupo:=p_grupo||'	on ap.fp_id=fp.id inner join propiedades on fp.propiedad_id=propiedades.id ';
	p_grupo:=p_grupo||'	where agp.familia_id in (select distinct familia_id from mod_propiedades_heredadas_bsc('||p_idfamilia||',true))';
	p_grupo:=p_grupo||')';

	for r in
		select distinct propiedad_id
		from mod_propiedades_heredadas_bsc  (p_idfamilia,false) t inner join propiedades on t.propiedad_id=propiedades.id
		group by propiedad_id loop
		if i=0 then 
			p_select:='select p'||i||'.familia_propiedad_id as fp_id0';
			p_array:=',array[p0.familia_propiedad_id::integer';
			p_join:='from mod_propiedades_heredadas_bsc  ('||p_idfamilia||',false) p0'; 
			p_where:='where p0.propiedad_id='||r.propiedad_id;

			p_grupo_select:='select g0.fp_id::integer as fp_id0 '; --puede ser nulo por el resultado de la combinación
			p_grupo_array:=',array[g0.fp_id::integer';
			p_grupo_join:='from grupos g0 ';
			p_grupo_where:='where g0.fp_id is null ';
			
			p_p0:=r.propiedad_id;

		else 
			p_select:=p_select||', p'||i||'.familia_propiedad_id as fp_id'||i;
			p_array:=p_array||',p'||i||'.familia_propiedad_id::integer';
			p_join:=p_join||', mod_propiedades_heredadas_bsc  ('||p_idfamilia||',false) p'||i;
			p_where:=p_where||' and p'||i||'.propiedad_id='||r.propiedad_id;

			p_grupo_select:=p_grupo_select|| ',g'||i||'.fp_id::integer as fp_id'||i;
			p_grupo_array:=p_grupo_array||',g'||i||'.fp_id::integer';
			p_grupo_join:=p_grupo_join||' full join grupos g'||i||' on g'||(i-1)||'.grupo_id=g'||i||'.grupo_id ';
			p_grupo_join:=p_grupo_join||' and g'||i||'.propiedad_id='||r.propiedad_id||case when i=1 then ' and g0.propiedad_id='||p_p0 else '' end;
			p_grupo_where:=p_grupo_where||' or g'||i||'.fp_id is null ';
		

		end if;
		i:=i+1;
		p_prop:=array_append(p_prop,r.propiedad_id);
		
	end loop;

	p_array:=p_array||'] ';
	p_grupo_array:=p_grupo_array||'] ';
	--Se añade la clausula de lsi una combinación es válida o no
	p_where:=p_where||' and mod_propedades_combinacion_valida('||p_idfamilia||', array'||translate(p_prop::text,'{}','[]')||p_array||')';
	
	--p_grupo_where:=p_grupo_where||' and mod_propedades_combinacion_valida('||p_idfamilia||','||p_prop::text||','||p_grupo_array||')';

	p_array:=p_array||' as campos ';
	p_grupo_array:=p_grupo_array||' as campos ';
	
	p_sql:=p_select||p_array||chr(10)||p_join||chr(10)||p_where;
	p_except:=p_grupo||chr(10)||p_grupo_select||p_grupo_array||chr(10)||p_grupo_join;
	p_sql:=p_sql||chr(10)||' except ( '||p_except||');';
	
	
	--raise '%', p_sql;
	--antes de atacar las inserciones, vamos a calcular los grupos a los que le falta alguna propiedad de las combinaciones a insertar
	with grupos as (
			select agp.id as grupo_id,ap.fp_id,fp.propiedad_id 
			from articulos_grupopropiedades agp inner join articulos_propiedades ap on agp.id=ap.grupo_id inner join familias_propiedades fp 
				on ap.fp_id=fp.id inner join propiedades on fp.propiedad_id=propiedades.id 
			where agp.familia_id in (select distinct familia_id from mod_propiedades_heredadas_bsc(p_idfamilia,true))
	)
	select array_agg(grupo_id) into p_grupos --Todos los grupos de esa familia o descendiente que no tienen alguna de las propiedades de las combinaciones
	from (
		select grupo_id 
		from grupos 
		group by grupo_id 
		having not array_agg(propiedad_id)@>p_prop --El grupo no contiene todas las propiedades de la combinación
	) t;
	
	p_ngrupo:=1;
	for r in execute p_sql loop
	--cada registro contiene una combinación de propiedades/valores para conformar un grupo que hay que insertar. 
		if p_ngrupo between 1 and array_length(p_grupos,1) then --hay un grupo al que le falta al menos una propiedad de la combinación=>se inserta en dicho grupo
			for j in 1..i loop --para cada propiedad de la combinación		
				insert into articulos_propiedades(id,grupo_id,fp_id)
				select p_grupo[p_ngrupo],r.campos[j] --insertamos el grupo y el valor de la  propiedad
				where not exists (
					select familias_propiedades.id
					from articulos_propiedades inner join familias_propiedades on articulos_propiedades.fp_id=familias_propiedades.id
					where articulos_propiedades.grupo_id=p_grupo[p_ngrupo] and familias_propiedades.propiedad_id=p_prop[j]
				); --Si la propiedad ya existe en el grupo, no se insertará
	    		end loop; 
			p_ngrupo:=p_ngrupo+1;
		else --Si todos los grupos tienen todas las propiedades de la combinación a insertar, entonces creamos un nuevo grupo con todas las propiedades
			insert into articulos_grupopropiedades (id,familia_id) values (nextval('articulos_grupopropiedades_id_seq'),p_idfamilia) returning id into p_idgrupo;
		  	for j in 1..i loop --para cada propiedad de la combinación		
				insert into articulos_propiedades(grupo_id,fp_id) values (p_idgrupo,r.campos[j]);
			end loop;	
		end if;
	end loop;
	

	return 'OK';
	
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
  


CREATE OR REPLACE FUNCTION familias_grupos_propiedades_detalles_validaciones() RETURNS trigger AS
$BODY$
-- Antes de insertar en la tabla familias_grupos_propiedades_detalles:
-- Se comprueba que la propiedad y el registro en propiedades_packs_lineas no estén duplicadas en familias_grupos_propiedades
declare
r record;
p_t text;
begin
  select t.propiedad,t.valor,t.familia, t.grupo_id into r
  from mod_propiedades_grupos_bsc  (new.propiedad_grupo_id, true, true) t
  where t.pack_linea_id=new.propiedad_pack_linea_id; 
  if found then 
      p_t := case when new.propiedad_grupo_id=grupo_id then ' al mismo grupo de propiedades de la familia actual ' else ' a un grupo de propiedades de alguna fammilia descendiente/ascendiente a la actual. Familia:' end;
      RAISE EXCEPTION 'Esta propiedad/valor (%) ya está asignada % % ', r.propiedad||':'||r.valor,p_t, r.familia;
  end if;
  select propiedades.tcorto, r.familia into r
  from propiedades 
	inner join propiedades_packs_lineas ppl on propiedades.id=ppl.propiedad_id 
	inner join mod_propiedades_grupos_bsc  (new.propiedad_grupo_id, true, true) t on propiedades.id=t.propiedad_id
  where ppl.id=new.propiedad_pack_linea_id;
  
  if found then 
      RAISE EXCEPTION 'Esta propiedad (%) ya está asignada a un grupo de propiedades de la familia % ', r.propiedad, r.familia;
  end if;
  -- hay que trasladar todos los cambios en el artículo (codarticulo,nombre corto, largo, comercial). 
  -- No se permite vincular o quitar una nueva propiedad si se d algúno de estos casos:
 -- la propiedad a quitar/poner altera el código o el texto largo del artículo  
  -- el artículo  está vinculado a algún documento con gestión de cartera
  return new;


end;
$BODY$ LANGUAGE plpgsql 

DROP TRIGGER familias_grupos_propiedades_detalles_validaciones ON familias_grupos_propiedades_detalles;

CREATE TRIGGER familias_grupos_propiedades_detalles_validaciones before INSERT 
    ON familias_grupos_propiedades_detalles FOR EACH row 
    EXECUTE PROCEDURE familias_grupos_propiedades_detalles_validaciones ();




create or replace function MOD_propiedades_opt(integer,integer,text,text,text,text) returns text as
$BODY$
-- Se le pasa un identificador de usuario y de contexto, así como una serie de campos, valores e ids de aplicación.
-- Atendiendo a si hay que actualizar, insertar o eliminar, aplicará la correspondiente consulta y la ejecutará.
-- Si hay algún error, devolverá el texto de la consulta ejecutada, y la explicación del error (devuelto por la base de datos).
-- Si todo vabien, devolverá OK.


declare
  p_idusuario alias for $1;
  p_idcontexto alias for $2;
  p_campos alias for $3;
  p_valores alias for $4;
  p_ids alias for $5;
  p_op alias for $6;
  p_r text;
  i integer;
begin
   --Evaluar el usuario y el contexto
   i:=0;
   if p_op like 'actualiza%' then
     for p_r in select MOD_query_update(p_campos,p_valores,p_ids,'propiedades')  loop
	begin
		i:=i+1;
		execute p_r||';';
		exception when others then
			raise exception 'No se ha actualizado la tabla de propiedades % Sentencia usada: %.% Mensaje de la base de datos: %',chr(10),p_r,chr(10),SQLERRM;
	end;
         
     end loop;  
     
   else
   end if;
   return 'OK.'||i||' propiedades actualizadas';
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
COST 100;  