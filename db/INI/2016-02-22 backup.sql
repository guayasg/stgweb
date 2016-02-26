--
-- PostgreSQL database dump
--

-- Dumped from database version 9.3.6
-- Dumped by pg_dump version 9.3.6
-- Started on 2016-02-22 18:55:29

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- TOC entry 2464 (class 1262 OID 24577)
-- Name: stg; Type: DATABASE; Schema: -; Owner: stg
--

CREATE DATABASE stg WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'Spanish_Spain.1252' LC_CTYPE = 'Spanish_Spain.1252';


ALTER DATABASE stg OWNER TO stg;

\connect stg

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- TOC entry 239 (class 3079 OID 11750)
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- TOC entry 2467 (class 0 OID 0)
-- Dependencies: 239
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- TOC entry 259 (class 1255 OID 180409)
-- Name: array_except(anyarray, anyarray); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION array_except(anyarray, anyarray) RETURNS anyarray
    LANGUAGE sql
    AS $_$
    SELECT ARRAY(
        SELECT UNNEST($1)
        EXCEPT
        SELECT UNNEST($2)
    );
$_$;


ALTER FUNCTION public.array_except(anyarray, anyarray) OWNER TO postgres;

--
-- TOC entry 258 (class 1255 OID 180408)
-- Name: array_intersect(anyarray, anyarray); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION array_intersect(anyarray, anyarray) RETURNS anyarray
    LANGUAGE sql
    AS $_$
    SELECT ARRAY(
        SELECT UNNEST($1)
        INTERSECT
        SELECT UNNEST($2)
    );
$_$;


ALTER FUNCTION public.array_intersect(anyarray, anyarray) OWNER TO postgres;

--
-- TOC entry 255 (class 1255 OID 163948)
-- Name: array_search(anyelement, anyarray); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION array_search(needle anyelement, haystack anyarray) RETURNS integer
    LANGUAGE sql STABLE
    AS $_$
    SELECT i
      FROM generate_subscripts($2, 1) AS i
     WHERE $2[i] = $1
  ORDER BY i
$_$;


ALTER FUNCTION public.array_search(needle anyelement, haystack anyarray) OWNER TO postgres;

--
-- TOC entry 253 (class 1255 OID 90116)
-- Name: concat2(text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION concat2(text, text) RETURNS text
    LANGUAGE sql
    AS $_$
    SELECT CASE WHEN $1 IS NULL OR $1 = '' THEN $2
            WHEN $2 IS NULL OR $2 = '' THEN $1
            ELSE $1 || ', ' || $2
            END; 
$_$;


ALTER FUNCTION public.concat2(text, text) OWNER TO postgres;

--
-- TOC entry 262 (class 1255 OID 123195)
-- Name: familias_grupos_propiedades_detalles_validaciones(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION familias_grupos_propiedades_detalles_validaciones() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
  return new;


end;
$$;


ALTER FUNCTION public.familias_grupos_propiedades_detalles_validaciones() OWNER TO postgres;

--
-- TOC entry 252 (class 1255 OID 32801)
-- Name: isnumeric(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION isnumeric(text) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
DECLARE x NUMERIC;
BEGIN
    x = $1::NUMERIC;
    RETURN TRUE;
EXCEPTION WHEN others THEN
    RETURN FALSE;
END;
$_$;


ALTER FUNCTION public.isnumeric(text) OWNER TO postgres;

--
-- TOC entry 274 (class 1255 OID 303406)
-- Name: mod_articulos_nombre(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION mod_articulos_nombre(integer, OUT valor text, OUT id integer) RETURNS SETOF record
    LANGUAGE plpgsql
    AS $_$
-- Función que calcula los elementos que se pueden visualizar en la interface de valoresligados. 
--Se le pasa un id de familias_propiedades, y devolverá todos las propiedade con sus valores (en formato texto) con los posibles candidatos a  ponerse como valor ligado
declare
  p_fp alias for $1;
begin
	return query
		with valores as (
			select t.propiedad||': '||t.valor as valor,t.familia_propiedad_id
			from mod_propiedades_heredadas_bsc(1,false) t
			where propiedad_id is not null
		)
		select valores.valor,valores.familia_propiedad_id 
		from valores 
		where familia_propiedad_id<>p_fp 
		except
		select propiedades.tlargo||': '||f.valor as valor, v.fp2_id
		from valores inner join familias_valoresligados v on valores.familia_propiedad_id=v.fp_id 
			inner join familias_propiedades f on v.fp2_id=f.id inner join propiedades on f.propiedad_id=propiedades.id
		order by valor;
end;	
$_$;


ALTER FUNCTION public.mod_articulos_nombre(integer, OUT valor text, OUT id integer) OWNER TO postgres;

--
-- TOC entry 267 (class 1255 OID 229384)
-- Name: mod_articulos_nombre(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION mod_articulos_nombre(integer, integer) RETURNS text
    LANGUAGE plpgsql
    AS $_$
declare
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

--intercambio del orden entre una familia y una propiedad. los id de familia y de familias_propiedades son excluyentes
	select f.id as f_id, f.orden as f_orden, 
		ap.id as ap_id, fp.propiedad_id as fp_propiedad_id,fp.familia_id as fp_familia_id, ap.orden as ap_orden, 
		f2.id as f2_id, f2.orden as f2_orden, ap2.id as ap2_id, ap2.orden as ap2_orden into r
	from familias f 
		full join (articulos_propiedades ap  inner join familias_propiedades fp on ap.fp_id=fp.id) on f.id=p_i1 or ap.id=p_i1
		full join (articulos_propiedades ap2  inner join familias_propiedades fp2 on ap2.fp_id=fp2.id) on ap2.id=p_i2 
		full join familias f2 on f2.id=p_i2;
	-- el  orden de p_i1 ha de ser menor que el orden de p_i2. Si no lo es, lo intercambiamos.

	p_oid:=greatest(r.f_orden,r.ap_orden);
	p_oid2:=greatest(r.f2_orden,ap2_orden);

	if p_oid is null or p_oid2 is null or p_i1 is null or p_i2 is null then
	   return 'Para el primer parámetro '||coalesce(p_i1,'nulo')||' el orden establecido es '||coalesce(p_oid1,'nulo')||'. Para el segundo parametro '||coalesce(p_i2,'nulo')||' el orden es '||coalesce(p_oid2,'nulo');
	end if;
	if p_oid=p_oid2 then
		return 'OK';
	end if;
	--Si el orden del primer parámetro es mayor que el del segundo lo invertimos. La lógica de esta función presupone que el orden del primer parámetro es menor
	p_id:=	case when p_oid>p_oid2 then p_i2 else p_i1 end;
	p_id2:=	case when p_oid<p_oid1 then p_i1 else p_i2 end;

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
	elsif r.ap_id is not null then
		select min(orden) into p_orden1 from familias_propiedades where familia_id=r.fp_familia_id and propiedad_id=r.fp_propiedad_id;
		if p_orden1 is not null and r.f2_id is not null then
			update familias set orden=p_orden1 where id=r.f2_id;
			update familias_propiedades set orden=r.f2_orden where familia_id=r.fp_familia_id and propiedad_id=r.fp_propiedad_id;
		end if;
	elsif r.ap2_id is not null then
		select max(orden) into p_orden2 from familias_propiedades where familia_id=r.fp2_familia_id and propiedad_id=r.fp2_propiedad_id;
		if p_orden2 is not null and r.f_id is not null then
			update familias set orden=p_orden2 where id=r.f_id;
			update familias_propiedades set orden=r.f_orden where familia_id=r.fp2_familia_id and propiedad_id=r.fp2_propiedad_id;
		end if;
	end if;
END;
$_$;


ALTER FUNCTION public.mod_articulos_nombre(integer, integer) OWNER TO postgres;

--
-- TOC entry 265 (class 1255 OID 278540)
-- Name: mod_articulos_nombre(integer, integer[], integer[], integer[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION mod_articulos_nombre(integer, integer[], integer[], integer[], OUT id integer, OUT cod character, OUT nomcorto text, OUT nomlargo text, OUT nomcomercial text) RETURNS SETOF record
    LANGUAGE plpgsql
    AS $_$
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
	p_sql:=p_sql||'		string_agg(case when jerarquia.propiedad_id is null and familia_componer.describe like ''cod%'' then familias.codfamilia '||chr(10);
	p_sql:=p_sql||'						when jerarquia.propiedad_id is not null and '||chr(10);
	p_sql:=p_sql||'							(corto.describe like ''cod%'' or largo.describe like ''cod%''  or comercial.describe like ''cod%'') then '||chr(10); 
	p_sql:=p_sql||'							famprop.cod '||chr(10);
	p_sql:=p_sql||'						else '''' end '||chr(10);
	p_sql:=p_sql||'					,'''' ORDER BY jerarquia.orden)::character(15) '||chr(10);
	p_sql:=p_sql||'				 as codarticulo, --sustituye todos los espacios en blanco consecutivos por NADA'||chr(10);
	p_sql:=p_sql||'		trim(string_agg(case when jerarquia.propiedad_id is null and familia_componer.describe like ''%valor%'' then jerarquia.familia||'' '' '||chr(10);
	p_sql:=p_sql||'						when jerarquia.propiedad_id is not null and (corto.describe like ''%propiedad + valor'') then '||chr(10);
	p_sql:=p_sql||'							famprop.separador||pcorto.tcorto||'' ''||jerarquia.valor '||chr(10);
	p_sql:=p_sql||'						when jerarquia.propiedad_id is not null and (corto.describe like ''%propiedad'') then case when length(famprop.separador)=0 then '' '' else famprop.separador end||pcorto.tcorto '||chr(10);
	p_sql:=p_sql||'						when jerarquia.propiedad_id is not null and (corto.describe like ''%valor'') then case when length(famprop.separador)=0 then '' '' else famprop.separador end||jerarquia.valor '||chr(10);
	p_sql:=p_sql||'						else '''' end '||chr(10);
	p_sql:=p_sql||'					,'''' ORDER BY jerarquia.orden) '||chr(10);
	p_sql:=p_sql||'			)	as tcorto, --sustituye todos los espacios en blanco consecutivos por uno solo'||chr(10);
	p_sql:=p_sql||'		trim(string_agg(case when jerarquia.propiedad_id is null and familia_componer.describe like ''%valor%'' then jerarquia.familia||'' '' '||chr(10);
	p_sql:=p_sql||'						when jerarquia.propiedad_id is not null and (largo.describe like ''%propiedad + valor'') then '||chr(10);
	p_sql:=p_sql||'							case when length(famprop.separador)=0 then '' '' else famprop.separador end||plargo.tlargo||'' ''||jerarquia.valor '||chr(10);
	p_sql:=p_sql||'						when jerarquia.propiedad_id is not null and (largo.describe like ''%propiedad'') then case when length(famprop.separador)=0 then '' '' else famprop.separador end||plargo.tlargo '||chr(10);
	p_sql:=p_sql||'						when jerarquia.propiedad_id is not null and (largo.describe like ''%valor'') then case when length(famprop.separador)=0 then '' '' else famprop.separador end||jerarquia.valor '||chr(10);
	p_sql:=p_sql||'						else '''' end '||chr(10);
	p_sql:=p_sql||'					,'''' ORDER BY jerarquia.orden) '||chr(10);
	p_sql:=p_sql||'			)	as tlargo, '||chr(10);
	p_sql:=p_sql||'		trim(string_agg(case when jerarquia.propiedad_id is null and familia_componer.describe like ''%valor%'' then jerarquia.familia||'' '' '||chr(10);
	p_sql:=p_sql||'						when jerarquia.propiedad_id is not null and (comercial.describe like ''%propiedad + valor'') then '||chr(10);
	p_sql:=p_sql||'							case when length(famprop.separador)=0 then '' '' else famprop.separador end||pcomercial.tcomercial||'' ''||jerarquia.valor '||chr(10);
	p_sql:=p_sql||'						when jerarquia.propiedad_id is not null and (comercial.describe like ''%propiedad'') then case when length(famprop.separador)=0 then '' '' else famprop.separador end||pcomercial.tcomercial '||chr(10);
	p_sql:=p_sql||'						when jerarquia.propiedad_id is not null and (comercial.describe like ''%valor'') then case when length(famprop.separador)=0 then '' '' else famprop.separador end||jerarquia.valor '||chr(10);
	p_sql:=p_sql||'						else '''' end '||chr(10);
	p_sql:=p_sql||'					, '''' ORDER BY jerarquia.orden) '||chr(10);
	p_sql:=p_sql||'			)	as tcomercial '||chr(10);
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
$_$;


ALTER FUNCTION public.mod_articulos_nombre(integer, integer[], integer[], integer[], OUT id integer, OUT cod character, OUT nomcorto text, OUT nomlargo text, OUT nomcomercial text) OWNER TO postgres;

--
-- TOC entry 268 (class 1255 OID 229386)
-- Name: mod_articulos_orden_propiedades(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION mod_articulos_orden_propiedades(integer, integer) RETURNS text
    LANGUAGE plpgsql
    AS $_$
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
$_$;


ALTER FUNCTION public.mod_articulos_orden_propiedades(integer, integer) OWNER TO postgres;

--
-- TOC entry 264 (class 1255 OID 278536)
-- Name: mod_articulos_orden_siguiente_anterior(integer, integer, integer, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION mod_articulos_orden_siguiente_anterior(integer, integer, integer, text) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
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
$_$;


ALTER FUNCTION public.mod_articulos_orden_siguiente_anterior(integer, integer, integer, text) OWNER TO postgres;

--
-- TOC entry 270 (class 1255 OID 262150)
-- Name: mod_familia_propiedad_grupo_bsc(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION mod_familia_propiedad_grupo_bsc(integer, OUT id integer, OUT describe text) RETURNS SETOF record
    LANGUAGE plpgsql
    AS $_$
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
$_$;


ALTER FUNCTION public.mod_familia_propiedad_grupo_bsc(integer, OUT id integer, OUT describe text) OWNER TO postgres;

--
-- TOC entry 266 (class 1255 OID 163954)
-- Name: mod_propedades_combinacion_valida(integer, integer[], integer[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION mod_propedades_combinacion_valida(integer, integer[], integer[]) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
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

$_$;


ALTER FUNCTION public.mod_propedades_combinacion_valida(integer, integer[], integer[]) OWNER TO postgres;

--
-- TOC entry 254 (class 1255 OID 57350)
-- Name: mod_propiedades_bsc(integer, integer, text, text, text); Type: FUNCTION; Schema: public; Owner: stg
--

CREATE FUNCTION mod_propiedades_bsc(integer, integer, text, text, text, OUT id integer, OUT codpropiedad character varying, OUT tcorto character varying, OUT tlargo character varying, OUT tcomercial character varying, OUT propnumerica boolean, OUT componertcorto_id integer, OUT componertlargo_id integer, OUT componertcomercial_id integer, OUT op_corta character varying, OUT op_larga character varying, OUT op_comercial character varying) RETURNS SETOF record
    LANGUAGE plpgsql
    AS $_$
    -- Se le pasa un identificador de usuario, un id de contexto, un conjunto de nombres de campos, un conjunto de valores, y un conjunto de operadores (like,=, in ...) 
    --y retornará un conjunto de registros:
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
$_$;


ALTER FUNCTION public.mod_propiedades_bsc(integer, integer, text, text, text, OUT id integer, OUT codpropiedad character varying, OUT tcorto character varying, OUT tlargo character varying, OUT tcomercial character varying, OUT propnumerica boolean, OUT componertcorto_id integer, OUT componertlargo_id integer, OUT componertcomercial_id integer, OUT op_corta character varying, OUT op_larga character varying, OUT op_comercial character varying) OWNER TO stg;

--
-- TOC entry 271 (class 1255 OID 287057)
-- Name: mod_propiedades_combinacion_valida(integer, integer[], integer[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION mod_propiedades_combinacion_valida(integer, integer[], integer[]) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
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

$_$;


ALTER FUNCTION public.mod_propiedades_combinacion_valida(integer, integer[], integer[]) OWNER TO postgres;

--
-- TOC entry 256 (class 1255 OID 49158)
-- Name: mod_propiedades_conf(integer, integer); Type: FUNCTION; Schema: public; Owner: stg
--

CREATE FUNCTION mod_propiedades_conf(integer, integer, OUT campos text, OUT iu text, OUT tipo text, OUT tabla text, OUT bsc text, OUT c_ajena text, OUT dependencias text, OUT b_exacta text, OUT tamanio text) RETURNS SETOF record
    LANGUAGE plpgsql
    AS $_$
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
$_$;


ALTER FUNCTION public.mod_propiedades_conf(integer, integer, OUT campos text, OUT iu text, OUT tipo text, OUT tabla text, OUT bsc text, OUT c_ajena text, OUT dependencias text, OUT b_exacta text, OUT tamanio text) OWNER TO stg;

--
-- TOC entry 272 (class 1255 OID 287058)
-- Name: mod_propiedades_elementos_combinatoria(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION mod_propiedades_elementos_combinatoria(integer, OUT id integer, OUT propiedad_valor text, OUT orden integer) RETURNS SETOF record
    LANGUAGE plpgsql
    AS $_$
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
$_$;


ALTER FUNCTION public.mod_propiedades_elementos_combinatoria(integer, OUT id integer, OUT propiedad_valor text, OUT orden integer) OWNER TO postgres;

--
-- TOC entry 275 (class 1255 OID 287079)
-- Name: mod_propiedades_generar_grupos(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION mod_propiedades_generar_grupos(integer, integer) RETURNS text
    LANGUAGE plpgsql
    AS $_$
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
	--raise exception '%',p_sql;
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
		
/*
	EXCEPTION
		WHEN OTHERS THEN
		p_msg:=replace(p_msg,chr(10),' - - - ');
		if length(coalesce(p_sql,''))=0 then
			p_msg:='No se pudieron renombrar artículos. El error fue: '||SQLERRM;
		end if;
		return p_msg;
*/
			
	--Faltaría eliminar artículos que no tienen correspondencia con una combinación válida y no están siendo usados por líneas de documentos

	
END;
$_$;


ALTER FUNCTION public.mod_propiedades_generar_grupos(integer, integer) OWNER TO postgres;

--
-- TOC entry 273 (class 1255 OID 287059)
-- Name: mod_propiedades_generar_grupos_original(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION mod_propiedades_generar_grupos_original(integer) RETURNS text
    LANGUAGE plpgsql
    AS $_$
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
$_$;


ALTER FUNCTION public.mod_propiedades_generar_grupos_original(integer) OWNER TO postgres;

--
-- TOC entry 261 (class 1255 OID 123192)
-- Name: mod_propiedades_grupos(integer, boolean, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION mod_propiedades_grupos(integer, boolean, boolean, OUT familia_id integer, OUT padre_id integer, OUT familia character varying, OUT pack character varying, OUT grupo_id integer, OUT pack_linea_id integer, OUT propiedad character varying, OUT valor character varying, OUT propiedad_id integer, OUT procedencia character) RETURNS SETOF record
    LANGUAGE plpgsql
    AS $_$
    -- Se le pasa un  identificador de grupo de propiedades y te mostrará dependiendo de p_asignado y de p_incluirdescendientes:
    -- p_asginado => true: 
    --	las propiedades-valores ya asignadas al grupo o sus ascendientes
    --p_asignado => false
    --	las propiedades-valores que no está asignados a ese grupo
    --p_incluirdescendentes => true
    --	Se incluyen también en la búsqueda los descendiente del grupo
    --p_incluirdescendentes => false
    --  No se incluyen los descendientes del grupo
    
declare 
    p_idgrupo alias for $1;
    p_asignado alias for $2;
    p_incluirdescendentes alias for $3;
    p_sql text;


begin  
	p_sql:='WITH RECURSIVE grupos_padre AS (';
	p_sql:=p_sql||'	SELECT  familias.id as familia_id, familias.padre_id, familias.describe as familia, fgp.describe as pack, fgp.id as grupo_id, fgpd.propiedad_pack_linea_id as pack_linea_id, propiedades.tcorto as propiedad, ppl.valor ';
	p_sql:=p_sql||'        propiedades.id as propiedad_id,''propia'' as procedencia ';
	p_sql:=p_sql||'	FROM    familias ';
	p_sql:=p_sql||'		inner join familias_grupos_propiedades fgp on familias.id=fgp.familia_id ';
	p_sql:=p_sql||'		inner join familias_grupos_propiedades_detalles fgpd on fgp.id=fgpd.propiedad_grupo_id ';
	p_sql:=p_sql||'		inner join propiedades_packs_lineas ppl on fgpd.propiedad_pack_linea_id=ppl.id ';
	p_sql:=p_sql||'		inner join propiedades_packs pp on ppl.propiedad_pack_id=pp.id ';
	p_sql:=p_sql||'		inner join propiedades on ppl.propiedad_id=propiedades.id ';
	p_sql:=p_sql||'	WHERE fgp.id='||p_idgrupo||' '; 
	p_sql:=p_sql||'	UNION '; 
	p_sql:=p_sql||'	SELECT familias.id as familia_id, familias.padre_id, familias.describe as familia, fgp.describe as pack, fgp.id as grupo_id, fgpd.propiedad_pack_linea_id as pack_linea_id, propiedades.tcorto as propiedad, ppl.valor ';
	p_sql:=p_sql||'        propiedades.id as propiedad_id, ''heredada'' as procedencia ';
	p_sql:=p_sql||'		FROM    grupos_padre, familias	 ';
	p_sql:=p_sql||'			inner join familias_grupos_propiedades fgp on familias.id=fgp.familia_id ';
	p_sql:=p_sql||'	inner join familias_grupos_propiedades_detalles fgpd on fgp.id=fgpd.propiedad_grupo_id ';
	p_sql:=p_sql||'			inner join propiedades_packs_lineas ppl on fgpd.propiedad_pack_linea_id=ppl.id ';
	p_sql:=p_sql||'			inner join propiedades_packs pp on ppl.propiedad_pack_id=pp.id ';
	p_sql:=p_sql||'			inner join propiedades on ppl.propiedad_id=propiedades.id ';	
	p_sql:=p_sql||'		where grupos_padre.padre_id=familias.id ';
	if p_incluirdescendentes then
		p_sql:=p_sql||'	union ';
		p_sql:=p_sql||'	SELECT familias.id as familia_id, familias.padre_id, familias.describe as familia, fgp.describe as pack, fgp.id as grupo_id, fgpd.propiedad_pack_linea_id as pack_linea_id, propiedades.tcorto as propiedad, ppl.valor ';
		p_sql:=p_sql||'        propiedades.id as propiedad_id,''en descendencia'' as procedencia ';
		p_sql:=p_sql||'		FROM    grupos_padre, familias	 ';
		p_sql:=p_sql||'			inner join familias_grupos_propiedades fgp on familias.id=fgp.familia_id ';
		p_sql:=p_sql||'	inner join familias_grupos_propiedades_detalles fgpd on fgp.id=fgpd.propiedad_grupo_id ';
		p_sql:=p_sql||'			inner join propiedades_packs_lineas ppl on fgpd.propiedad_pack_linea_id=ppl.id ';
		p_sql:=p_sql||'			inner join propiedades_packs pp on ppl.propiedad_pack_id=pp.id ';
		p_sql:=p_sql||'			inner join propiedades on ppl.propiedad_id=propiedades.id ';	
		p_sql:=p_sql||'	where grupos_padre.familia_id=familias.padre_id ';
        end if;
	p_sql:=p_sql||')';
	if p_asignado then --todas las propiedades asignadas al grupo p_idgrupo
		p_sql:=p_sql||'SELECT * FROM grupos_padre ; ';
	else
		p_sql:=p_sql||'	SELECT familias.id as familia_id, familias.padre_id, familias.describe as familia, fgp.describe as pack, fgp.id as grupo_id, fgpd.propiedad_pack_linea_id as pack_linea_id, propiedades.tcorto as propiedad, ppl.valor ';
		p_sql:=p_sql||'        propiedades.id as propiedad_id, ''sin asignar'' as procedencia ';
		p_sql:=p_sql||'	FROM    familias ';
		p_sql:=p_sql||'		inner join familias_grupos_propiedades fgp on familias.id=fgp.familia_id ';
		p_sql:=p_sql||'		inner join familias_grupos_propiedades_detalles fgpd on fgp.id=fgpd.propiedad_grupo_id ';
		p_sql:=p_sql||'		inner join propiedades_packs_lineas ppl on fgpd.propiedad_pack_linea_id=ppl.id ';
		p_sql:=p_sql||'		inner join propiedades_packs pp on ppl.propiedad_pack_id=pp.id ';
		p_sql:=p_sql||'		inner join propiedades on ppl.propiedad_id=propiedades.id ';
		p_sql:=p_sql||'where propiedades.id not in (select distinct propiedad_id from grupos_padre) ';
		p_sql:=p_sql||'		and ppl.id not in (select distinct pack_linea_id from grupos_padre) ';
	end if;
  

  return query execute p_sql;

END;
$_$;


ALTER FUNCTION public.mod_propiedades_grupos(integer, boolean, boolean, OUT familia_id integer, OUT padre_id integer, OUT familia character varying, OUT pack character varying, OUT grupo_id integer, OUT pack_linea_id integer, OUT propiedad character varying, OUT valor character varying, OUT propiedad_id integer, OUT procedencia character) OWNER TO postgres;

--
-- TOC entry 263 (class 1255 OID 131083)
-- Name: mod_propiedades_grupos_bsc(integer, boolean, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION mod_propiedades_grupos_bsc(integer, boolean, boolean, OUT familia_id integer, OUT padre_id integer, OUT familia character varying, OUT pack character varying, OUT grupo_id integer, OUT pack_linea_id integer, OUT propiedad character varying, OUT valor character varying, OUT propiedad_id integer, OUT procedencia character, OUT path text) RETURNS SETOF record
    LANGUAGE plpgsql
    AS $_$
    -- Se le pasa un  identificador de grupo de propiedades y te mostrará dependiendo de p_asignado y de p_incluirdescendientes:
    -- p_asginado => true: 
    --	las propiedades-valores ya asignadas al grupo o sus ascendientes
    --p_asignado => false
    --	las propiedades-valores que no está asignados a ese grupo
    --p_incluirdescendentes => true
    --	Se incluyen también en la búsqueda los descendiente del grupo
    --p_incluirdescendentes => false
    --  No se incluyen los descendientes del grupo
    
declare 
    p_idgrupo alias for $1;
    p_asignado alias for $2;
    p_incluirdescendientes alias for $3;
    p_sql text;
    p_from text;


begin  
	--conformamos la clausula from
	p_from:='	FROM    familias '||chr(10);
	p_from:=p_from||'			inner join familias_grupos_propiedades fgp on familias.id=fgp.familia_id '||chr(10);
	p_from:=p_from||'			inner join familias_grupos_propiedades_detalles fgpd on fgp.id=fgpd.propiedad_grupo_id '||chr(10);
	p_from:=p_from||'			inner join propiedades_packs_lineas ppl on fgpd.propiedad_pack_linea_id=ppl.id '||chr(10);
	p_from:=p_from||'			inner join propiedades_packs pp on ppl.propiedad_pack_id=pp.id '||chr(10);
	p_from:=p_from||'			inner join propiedades on ppl.propiedad_id=propiedades.id '||chr(10);

	p_sql:='WITH RECURSIVE grupos_padre AS ('||chr(10);
	p_sql:=p_sql||'	SELECT  familias.id as familia_id, familias.padre_id, familias.describe as familia, pp.describe as pack, fgp.id as grupo_id, fgpd.propiedad_pack_linea_id as pack_linea_id, propiedades.tcorto as propiedad, ppl.valor, '||chr(10);
	p_sql:=p_sql||'		propiedades.id as propiedad_id,''propia''::character(20) as procedencia, familias.describe::text as path '||chr(10);
	p_sql:=p_sql||p_from;
	p_sql:=p_sql||'	WHERE fgp.id='||p_idgrupo||' '||chr(10); 

	p_sql:=p_sql||'	UNION '||chr(10); 
	p_sql:=p_sql||'	SELECT familias.id as familia_id, familias.padre_id, familias.describe as familia, pp.describe as pack, fgp.id as grupo_id, fgpd.propiedad_pack_linea_id as pack_linea_id, propiedades.tcorto as propiedad, ppl.valor, '||chr(10);
	p_sql:=p_sql||'        propiedades.id as propiedad_id, ''heredada''::character(20) as procedencia, '||chr(10);
	p_sql:=p_sql||'		case 	when grupos_padre.padre_id=familias.id then grupos_padre.path||''->''||familias.describe::text '||chr(10);
	p_sql:=p_sql||'			when grupos_padre.familia_id=familias.padre_id then familias.describe||''->''||grupos_padre.path '||chr(10);
	p_sql:=p_sql||'		end as path '||chr(10);
	p_sql:=p_sql||p_from||', grupos_padre '||chr(10);
	p_sql:=p_sql||'		where grupos_padre.padre_id=familias.id '||chr(10);
	if p_incluirdescendientes then
		p_sql:=p_sql||'	or grupos_padre.familia_id=familias.padre_id '||chr(10);
        end if;
	p_sql:=p_sql||') -- fin de with recursivo'||chr(10);
	if p_asignado then --todas las propiedades asignadas al grupo p_idgrupo
		p_sql:=p_sql||'SELECT * FROM grupos_padre ; '||chr(10);
	else
		p_sql:=p_sql||'SELECT familias.id as familia_id, familias.padre_id, familias.describe as familia, pp.describe as pack, fgp.id as grupo_id, fgpd.propiedad_pack_linea_id as pack_linea_id, propiedades.tcorto as propiedad, ppl.valor, '||chr(10);
		p_sql:=p_sql||'        propiedades.id as propiedad_id, ''sin asignar''::character(20) as procedencia, path '||chr(10);
		p_sql:=p_sql||p_from;
		p_sql:=p_sql||'where propiedades.id not in (select distinct propiedad_id from grupos_padre) '||chr(10);
		p_sql:=p_sql||'		and ppl.id not in (select distinct pack_linea_id from grupos_padre) '||chr(10);
	end if;
  return query execute p_sql;

END;
$_$;


ALTER FUNCTION public.mod_propiedades_grupos_bsc(integer, boolean, boolean, OUT familia_id integer, OUT padre_id integer, OUT familia character varying, OUT pack character varying, OUT grupo_id integer, OUT pack_linea_id integer, OUT propiedad character varying, OUT valor character varying, OUT propiedad_id integer, OUT procedencia character, OUT path text) OWNER TO postgres;

--
-- TOC entry 276 (class 1255 OID 319516)
-- Name: mod_propiedades_heredadas_bsc(integer, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION mod_propiedades_heredadas_bsc(integer, boolean, OUT orden integer, OUT familia_id integer, OUT padre_id integer, OUT familia character varying, OUT propiedad_id integer, OUT propiedad character varying, OUT familia_propiedad_id integer, OUT valor character varying, OUT procedencia character, OUT cod character varying, OUT path text) RETURNS SETOF record
    LANGUAGE plpgsql
    AS $_$
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
$_$;


ALTER FUNCTION public.mod_propiedades_heredadas_bsc(integer, boolean, OUT orden integer, OUT familia_id integer, OUT padre_id integer, OUT familia character varying, OUT propiedad_id integer, OUT propiedad character varying, OUT familia_propiedad_id integer, OUT valor character varying, OUT procedencia character, OUT cod character varying, OUT path text) OWNER TO postgres;

--
-- TOC entry 269 (class 1255 OID 311317)
-- Name: mod_propiedades_valoresligados_pdtes(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION mod_propiedades_valoresligados_pdtes(integer, OUT valor text, OUT id integer) RETURNS SETOF record
    LANGUAGE plpgsql
    AS $_$
-- Función que calcula los elementos que se pueden visualizar en la interface de valoresligados. 
--Se le pasa un id de familias_propiedades, y devolverá todos las propiedade con sus valores (en formato texto) con los posibles candidatos a  ponerse como valor ligado
declare
  p_fp_id alias for $1;
  p_familia_id integer;
  p_propiedad_id integer;
begin
	select familia_id,propiedad_id into p_familia_id, p_propiedad_id
	from familias_propiedades f 
	where f.id=p_fp_id;

	p_familia_id:=coalesce(p_familia_id,-1);	
	
	return query
		with valores as (
			select t.propiedad||': '||t.valor as valor,t.familia_propiedad_id, t.propiedad_id
			from mod_propiedades_heredadas_bsc(p_familia_id,false) t
			where propiedad_id is not null and t.propiedad_id is not null
		)
		select valores.valor,valores.familia_propiedad_id 
		from valores 
		where valores.propiedad_id<>p_propiedad_id 
		except
		select propiedades.tlargo||': '||f.valor as valor, v.fp2_id
		from valores inner join familias_valoresligados v on valores.familia_propiedad_id=v.fp_id 
			inner join familias_propiedades f on v.fp2_id=f.id inner join propiedades on f.propiedad_id=propiedades.id
		where v.fp_id=p_fp_id
		order by valor;
end;	
$_$;


ALTER FUNCTION public.mod_propiedades_valoresligados_pdtes(integer, OUT valor text, OUT id integer) OWNER TO postgres;

--
-- TOC entry 260 (class 1255 OID 98312)
-- Name: mod_query_where(text, text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION mod_query_where(text, text, text) RETURNS text
    LANGUAGE plpgsql
    AS $_$
-- Esta función devuelve un conjunto de registros con las consultas update a ejecutar según una serie de campos, valores, e ids de aplicación
-- Devolverá tanstos registros como ids de aplicación se le pase.
-- Cada fila devuelta tiene un único campo con la sentencia sql del update.
-- Devuelve tantos registros como actualizaciones hagan falta. 
DECLARE
  p_campos alias for $1;
  p_valores alias for $2;
  p_operadores alias for $3;
  
  
  p_separador_campo text;
  p_separador_reg text;
  p_where text;
  p_id integer;
  p_campos_arr text[];
  p_valores_arr text[];
  p_operadores_arr text[];
  i integer;
  p_cuenta integer;
  
begin

  select Mod_separador_reg(true), Mod_separador_reg(false) into p_separador_reg, p_separador_campo;
  select string_to_array(p_campos,p_separador_campo) into p_campos_arr; -- Construye una array, donde cada elemento son los campos a modificar de un registro (tantas posiciones de array como regisros a modificar)
  select string_to_array(p_valores,p_separador_campo) into p_valores_arr; -- Construye una array donde cada elemento son los valores a modificar de un registro (tantas posiciones de array como regisros a modificar)
  select string_to_array(p_operadores,p_separador_campo) into p_operadores_arr;
  
  p_where:='';
  p_cuenta:=array_length(p_operadores_arr,1);
  
  for i in 1..p_cuenta loop
     p_where:=p_where||case when i<p_cuenta then p_campos_arr[i]||' '||p_operadores_arr[i]||' '||p_valores_arr[i] else '' end;
     --raise exception 'campo % operador % valor3 %',p_campos_arr[i],p_operadores_arr[i],p_valores_arr[i+1];
  end loop;
  return p_where;
END;
$_$;


ALTER FUNCTION public.mod_query_where(text, text, text) OWNER TO postgres;

--
-- TOC entry 257 (class 1255 OID 98313)
-- Name: mod_separador_reg(boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION mod_separador_reg(boolean) RETURNS text
    LANGUAGE plpgsql
    AS $_$
-- Devuelve los separadores usados para particionar las cadenas de caracteres que se usan para codificar campos, valores.
-- Si se pasa un true, devolverá el texto usado para delimitar un registro dentro de la cadena. Si se pasa un false devolverá cadena de caracteres usado 
-- para separar campos dentro de la cadena de caracteres
DECLARE
  p_separator_reg alias for $1; --si p_separator_reg=true =>se devuelve el separador de registro. Si no, se devuelve el separador de campo
begin
  if p_separator_reg then
    return '|$';
   else
     return '|#';
   end if;
end;

$_$;


ALTER FUNCTION public.mod_separador_reg(boolean) OWNER TO postgres;

--
-- TOC entry 751 (class 1255 OID 90117)
-- Name: concatenate(text); Type: AGGREGATE; Schema: public; Owner: postgres
--

CREATE AGGREGATE concatenate(text) (
    SFUNC = concat2,
    STYPE = text,
    INITCOND = ''
);


ALTER AGGREGATE public.concatenate(text) OWNER TO postgres;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- TOC entry 193 (class 1259 OID 303248)
-- Name: articulos; Type: TABLE; Schema: public; Owner: stg; Tablespace: 
--

CREATE TABLE articulos (
    id integer NOT NULL,
    familia_id integer,
    unidadmedida_id integer DEFAULT 0 NOT NULL,
    bultos integer DEFAULT 1,
    codarticulo character(15) NOT NULL,
    nomcorto text DEFAULT ''::text NOT NULL,
    nomlargo text DEFAULT ''::text NOT NULL,
    nomcomercial text DEFAULT ''::text NOT NULL,
    ctrlstk boolean DEFAULT true NOT NULL,
    aplicacaducidad boolean DEFAULT false NOT NULL,
    unidadmedida_categoria_id integer DEFAULT 0,
    aplicalote boolean DEFAULT false NOT NULL,
    permitestknegativo boolean DEFAULT false NOT NULL,
    ler_id integer,
    impuesto_compra_id integer DEFAULT 1,
    impuesto_venta_id integer DEFAULT 1,
    codbarra character(15),
    ts_fechaalta timestamp without time zone DEFAULT now(),
    ts_fechabaja timestamp without time zone,
    CONSTRAINT articulos_check CHECK (
CASE
    WHEN ctrlstk THEN (bultos > 0)
    ELSE NULL::boolean
END)
);


ALTER TABLE public.articulos OWNER TO stg;

--
-- TOC entry 192 (class 1259 OID 303246)
-- Name: articulos_id_seq; Type: SEQUENCE; Schema: public; Owner: stg
--

CREATE SEQUENCE articulos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.articulos_id_seq OWNER TO stg;

--
-- TOC entry 2468 (class 0 OID 0)
-- Dependencies: 192
-- Name: articulos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: stg
--

ALTER SEQUENCE articulos_id_seq OWNED BY articulos.id;


--
-- TOC entry 183 (class 1259 OID 303130)
-- Name: articulos_lers; Type: TABLE; Schema: public; Owner: stg; Tablespace: 
--

CREATE TABLE articulos_lers (
    id integer NOT NULL,
    codler character varying(25),
    peligroso boolean,
    codman character(50),
    describe character varying(400)
);


ALTER TABLE public.articulos_lers OWNER TO stg;

--
-- TOC entry 182 (class 1259 OID 303128)
-- Name: articulos_lers_id_seq; Type: SEQUENCE; Schema: public; Owner: stg
--

CREATE SEQUENCE articulos_lers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.articulos_lers_id_seq OWNER TO stg;

--
-- TOC entry 2469 (class 0 OID 0)
-- Dependencies: 182
-- Name: articulos_lers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: stg
--

ALTER SEQUENCE articulos_lers_id_seq OWNED BY articulos_lers.id;


--
-- TOC entry 188 (class 1259 OID 303149)
-- Name: familias; Type: TABLE; Schema: public; Owner: stg; Tablespace: 
--

CREATE TABLE familias (
    id integer NOT NULL,
    padre_id integer,
    codfamilia character varying(5) DEFAULT ''::character varying NOT NULL,
    describe character varying(100) NOT NULL,
    componer_id integer DEFAULT 1 NOT NULL,
    propia boolean DEFAULT true,
    competencia boolean DEFAULT false,
    orden integer NOT NULL
);


ALTER TABLE public.familias OWNER TO stg;

--
-- TOC entry 186 (class 1259 OID 303145)
-- Name: familias_id_seq; Type: SEQUENCE; Schema: public; Owner: stg
--

CREATE SEQUENCE familias_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.familias_id_seq OWNER TO stg;

--
-- TOC entry 2470 (class 0 OID 0)
-- Dependencies: 186
-- Name: familias_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: stg
--

ALTER SEQUENCE familias_id_seq OWNED BY familias.id;


--
-- TOC entry 195 (class 1259 OID 303307)
-- Name: articulos_propiedades; Type: TABLE; Schema: public; Owner: stg; Tablespace: 
--

CREATE TABLE articulos_propiedades (
    id integer DEFAULT nextval('familias_id_seq'::regclass) NOT NULL,
    grupo_id integer,
    fp_id integer,
    orden integer NOT NULL
);


ALTER TABLE public.articulos_propiedades OWNER TO stg;

--
-- TOC entry 194 (class 1259 OID 303305)
-- Name: articulos_propiedades_orden_seq; Type: SEQUENCE; Schema: public; Owner: stg
--

CREATE SEQUENCE articulos_propiedades_orden_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.articulos_propiedades_orden_seq OWNER TO stg;

--
-- TOC entry 2471 (class 0 OID 0)
-- Dependencies: 194
-- Name: articulos_propiedades_orden_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: stg
--

ALTER SEQUENCE articulos_propiedades_orden_seq OWNED BY articulos_propiedades.orden;


--
-- TOC entry 208 (class 1259 OID 344217)
-- Name: cuentas; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE cuentas (
    id integer NOT NULL,
    codcuenta character varying(12) NOT NULL,
    describe character varying(100) NOT NULL
);


ALTER TABLE public.cuentas OWNER TO postgres;

--
-- TOC entry 207 (class 1259 OID 344215)
-- Name: cuentas_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE cuentas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cuentas_id_seq OWNER TO postgres;

--
-- TOC entry 2472 (class 0 OID 0)
-- Dependencies: 207
-- Name: cuentas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE cuentas_id_seq OWNED BY cuentas.id;


--
-- TOC entry 226 (class 1259 OID 345309)
-- Name: dircalles; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE dircalles (
    id integer NOT NULL,
    codpostal character varying(10),
    municipio_id integer,
    describe character varying(150) DEFAULT ''::character varying NOT NULL
);


ALTER TABLE public.dircalles OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 345307)
-- Name: dircalles_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE dircalles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dircalles_id_seq OWNER TO postgres;

--
-- TOC entry 2473 (class 0 OID 0)
-- Dependencies: 225
-- Name: dircalles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE dircalles_id_seq OWNED BY dircalles.id;


--
-- TOC entry 214 (class 1259 OID 345211)
-- Name: dircomunidades; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE dircomunidades (
    id integer NOT NULL,
    pais_id integer NOT NULL,
    describe character varying(150) DEFAULT ''::character varying NOT NULL
);


ALTER TABLE public.dircomunidades OWNER TO postgres;

--
-- TOC entry 213 (class 1259 OID 345209)
-- Name: dircomunidades_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE dircomunidades_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dircomunidades_id_seq OWNER TO postgres;

--
-- TOC entry 2474 (class 0 OID 0)
-- Dependencies: 213
-- Name: dircomunidades_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE dircomunidades_id_seq OWNED BY dircomunidades.id;


--
-- TOC entry 232 (class 1259 OID 345345)
-- Name: direcciones; Type: TABLE; Schema: public; Owner: stg; Tablespace: 
--

CREATE TABLE direcciones (
    id integer NOT NULL,
    nomsede character varying(50) DEFAULT ''::character varying,
    entidad_id integer,
    calle_id integer,
    infocomplementaria_id integer DEFAULT 1,
    infocomplementaria character varying(50) DEFAULT ''::character varying,
    numgobierno integer,
    portal character varying(10),
    piso integer,
    escalera character varying(10),
    letra character varying(10),
    telf1 character varying(30),
    telf2 character varying(30),
    web character varying(60),
    email character varying(60),
    gpsx character varying(10),
    gpsy character varying(10),
    nima character varying(30)
);


ALTER TABLE public.direcciones OWNER TO stg;

--
-- TOC entry 231 (class 1259 OID 345343)
-- Name: direcciones_id_seq; Type: SEQUENCE; Schema: public; Owner: stg
--

CREATE SEQUENCE direcciones_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.direcciones_id_seq OWNER TO stg;

--
-- TOC entry 2475 (class 0 OID 0)
-- Dependencies: 231
-- Name: direcciones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: stg
--

ALTER SEQUENCE direcciones_id_seq OWNED BY direcciones.id;


--
-- TOC entry 230 (class 1259 OID 345334)
-- Name: direcciones_tipos; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE direcciones_tipos (
    id integer NOT NULL,
    describe character varying(100),
    esunica boolean DEFAULT true,
    sede boolean DEFAULT false,
    sedenima boolean DEFAULT false
);


ALTER TABLE public.direcciones_tipos OWNER TO postgres;

--
-- TOC entry 229 (class 1259 OID 345332)
-- Name: direcciones_tipos_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE direcciones_tipos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.direcciones_tipos_id_seq OWNER TO postgres;

--
-- TOC entry 2476 (class 0 OID 0)
-- Dependencies: 229
-- Name: direcciones_tipos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE direcciones_tipos_id_seq OWNED BY direcciones_tipos.id;


--
-- TOC entry 234 (class 1259 OID 345371)
-- Name: direcciones_tipos_links; Type: TABLE; Schema: public; Owner: stg; Tablespace: 
--

CREATE TABLE direcciones_tipos_links (
    id integer NOT NULL,
    direccion_id integer,
    direcciones_tipo_id integer
);


ALTER TABLE public.direcciones_tipos_links OWNER TO stg;

--
-- TOC entry 233 (class 1259 OID 345369)
-- Name: direcciones_tipos_links_id_seq; Type: SEQUENCE; Schema: public; Owner: stg
--

CREATE SEQUENCE direcciones_tipos_links_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.direcciones_tipos_links_id_seq OWNER TO stg;

--
-- TOC entry 2477 (class 0 OID 0)
-- Dependencies: 233
-- Name: direcciones_tipos_links_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: stg
--

ALTER SEQUENCE direcciones_tipos_links_id_seq OWNED BY direcciones_tipos_links.id;


--
-- TOC entry 228 (class 1259 OID 345325)
-- Name: dirinfocomplementarias; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE dirinfocomplementarias (
    id integer NOT NULL,
    describe character varying(150) DEFAULT ''::character varying NOT NULL
);


ALTER TABLE public.dirinfocomplementarias OWNER TO postgres;

--
-- TOC entry 227 (class 1259 OID 345323)
-- Name: dirinfocomplementarias_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE dirinfocomplementarias_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dirinfocomplementarias_id_seq OWNER TO postgres;

--
-- TOC entry 2478 (class 0 OID 0)
-- Dependencies: 227
-- Name: dirinfocomplementarias_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE dirinfocomplementarias_id_seq OWNED BY dirinfocomplementarias.id;


--
-- TOC entry 218 (class 1259 OID 345248)
-- Name: dirislas; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE dirislas (
    id integer NOT NULL,
    provincia_id integer,
    describe character varying(150) DEFAULT ''::character varying NOT NULL
);


ALTER TABLE public.dirislas OWNER TO postgres;

--
-- TOC entry 217 (class 1259 OID 345246)
-- Name: dirislas_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE dirislas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dirislas_id_seq OWNER TO postgres;

--
-- TOC entry 2479 (class 0 OID 0)
-- Dependencies: 217
-- Name: dirislas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE dirislas_id_seq OWNED BY dirislas.id;


--
-- TOC entry 220 (class 1259 OID 345263)
-- Name: dirlocalidades; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE dirlocalidades (
    id integer NOT NULL,
    codpostal character varying(10),
    describe character varying(150) DEFAULT ''::character varying NOT NULL
);


ALTER TABLE public.dirlocalidades OWNER TO postgres;

--
-- TOC entry 219 (class 1259 OID 345261)
-- Name: dirlocalidades_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE dirlocalidades_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dirlocalidades_id_seq OWNER TO postgres;

--
-- TOC entry 2480 (class 0 OID 0)
-- Dependencies: 219
-- Name: dirlocalidades_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE dirlocalidades_id_seq OWNED BY dirlocalidades.id;


--
-- TOC entry 222 (class 1259 OID 345273)
-- Name: dirmunicipios; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE dirmunicipios (
    id integer NOT NULL,
    provincia_id integer,
    isla_id integer,
    describe character varying(150) DEFAULT ''::character varying NOT NULL
);


ALTER TABLE public.dirmunicipios OWNER TO postgres;

--
-- TOC entry 221 (class 1259 OID 345271)
-- Name: dirmunicipios_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE dirmunicipios_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dirmunicipios_id_seq OWNER TO postgres;

--
-- TOC entry 2481 (class 0 OID 0)
-- Dependencies: 221
-- Name: dirmunicipios_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE dirmunicipios_id_seq OWNED BY dirmunicipios.id;


--
-- TOC entry 224 (class 1259 OID 345294)
-- Name: dirmunicipioscp; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE dirmunicipioscp (
    id integer NOT NULL,
    municipio_id integer,
    codpostal character varying(10)
);


ALTER TABLE public.dirmunicipioscp OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 345292)
-- Name: dirmunicipioscp_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE dirmunicipioscp_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dirmunicipioscp_id_seq OWNER TO postgres;

--
-- TOC entry 2482 (class 0 OID 0)
-- Dependencies: 223
-- Name: dirmunicipioscp_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE dirmunicipioscp_id_seq OWNED BY dirmunicipioscp.id;


--
-- TOC entry 212 (class 1259 OID 345202)
-- Name: dirpaises; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE dirpaises (
    id integer NOT NULL,
    describe character varying(150) DEFAULT ''::character varying NOT NULL
);


ALTER TABLE public.dirpaises OWNER TO postgres;

--
-- TOC entry 211 (class 1259 OID 345200)
-- Name: dirpaises_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE dirpaises_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dirpaises_id_seq OWNER TO postgres;

--
-- TOC entry 2483 (class 0 OID 0)
-- Dependencies: 211
-- Name: dirpaises_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE dirpaises_id_seq OWNED BY dirpaises.id;


--
-- TOC entry 216 (class 1259 OID 345226)
-- Name: dirprovincias; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE dirprovincias (
    id integer NOT NULL,
    comunidad_id integer,
    pais_id integer DEFAULT 0 NOT NULL,
    describe character varying(150) DEFAULT ''::character varying NOT NULL
);


ALTER TABLE public.dirprovincias OWNER TO postgres;

--
-- TOC entry 215 (class 1259 OID 345224)
-- Name: dirprovincias_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE dirprovincias_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dirprovincias_id_seq OWNER TO postgres;

--
-- TOC entry 2484 (class 0 OID 0)
-- Dependencies: 215
-- Name: dirprovincias_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE dirprovincias_id_seq OWNED BY dirprovincias.id;


--
-- TOC entry 206 (class 1259 OID 344113)
-- Name: entidades; Type: TABLE; Schema: public; Owner: stg; Tablespace: 
--

CREATE TABLE entidades (
    id integer NOT NULL,
    nomentidad character varying(200),
    nomcomercial character varying(200),
    nif character(15),
    tipo_id integer DEFAULT 1,
    espropia boolean DEFAULT false,
    codentidad character(10),
    grupoventa_id integer
);


ALTER TABLE public.entidades OWNER TO stg;

--
-- TOC entry 210 (class 1259 OID 344254)
-- Name: entidades_gruposventas; Type: TABLE; Schema: public; Owner: stg; Tablespace: 
--

CREATE TABLE entidades_gruposventas (
    id integer NOT NULL,
    entidad_id integer,
    grupoventa_id integer
);


ALTER TABLE public.entidades_gruposventas OWNER TO stg;

--
-- TOC entry 209 (class 1259 OID 344252)
-- Name: entidades_gruposventas_id_seq; Type: SEQUENCE; Schema: public; Owner: stg
--

CREATE SEQUENCE entidades_gruposventas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.entidades_gruposventas_id_seq OWNER TO stg;

--
-- TOC entry 2485 (class 0 OID 0)
-- Dependencies: 209
-- Name: entidades_gruposventas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: stg
--

ALTER SEQUENCE entidades_gruposventas_id_seq OWNED BY entidades_gruposventas.id;


--
-- TOC entry 205 (class 1259 OID 344111)
-- Name: entidades_id_seq; Type: SEQUENCE; Schema: public; Owner: stg
--

CREATE SEQUENCE entidades_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.entidades_id_seq OWNER TO stg;

--
-- TOC entry 2486 (class 0 OID 0)
-- Dependencies: 205
-- Name: entidades_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: stg
--

ALTER SEQUENCE entidades_id_seq OWNED BY entidades.id;


--
-- TOC entry 238 (class 1259 OID 368767)
-- Name: entidades_links; Type: TABLE; Schema: public; Owner: stg; Tablespace: 
--

CREATE TABLE entidades_links (
    id integer NOT NULL,
    entidadlink_id integer,
    entidadlinkpadre_id integer,
    codentidad character varying(10),
    entidadlinktipo_id integer,
    entidadlinkcargo_id integer,
    cuenta_id integer
);


ALTER TABLE public.entidades_links OWNER TO stg;

--
-- TOC entry 236 (class 1259 OID 368686)
-- Name: entidades_links_cargos; Type: TABLE; Schema: public; Owner: stg; Tablespace: 
--

CREATE TABLE entidades_links_cargos (
    id integer NOT NULL,
    entidadtipo_id integer,
    describe character varying(100)
);


ALTER TABLE public.entidades_links_cargos OWNER TO stg;

--
-- TOC entry 235 (class 1259 OID 368684)
-- Name: entidades_links_cargos_id_seq; Type: SEQUENCE; Schema: public; Owner: stg
--

CREATE SEQUENCE entidades_links_cargos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.entidades_links_cargos_id_seq OWNER TO stg;

--
-- TOC entry 2487 (class 0 OID 0)
-- Dependencies: 235
-- Name: entidades_links_cargos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: stg
--

ALTER SEQUENCE entidades_links_cargos_id_seq OWNED BY entidades_links_cargos.id;


--
-- TOC entry 237 (class 1259 OID 368765)
-- Name: entidades_links_id_seq; Type: SEQUENCE; Schema: public; Owner: stg
--

CREATE SEQUENCE entidades_links_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.entidades_links_id_seq OWNER TO stg;

--
-- TOC entry 2488 (class 0 OID 0)
-- Dependencies: 237
-- Name: entidades_links_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: stg
--

ALTER SEQUENCE entidades_links_id_seq OWNED BY entidades_links.id;


--
-- TOC entry 202 (class 1259 OID 344094)
-- Name: entidades_links_tipos; Type: TABLE; Schema: public; Owner: stg; Tablespace: 
--

CREATE TABLE entidades_links_tipos (
    id integer NOT NULL,
    describehijo character varying(100),
    describepadre character varying(100)
);


ALTER TABLE public.entidades_links_tipos OWNER TO stg;

--
-- TOC entry 201 (class 1259 OID 344092)
-- Name: entidades_links_tipos_id_seq; Type: SEQUENCE; Schema: public; Owner: stg
--

CREATE SEQUENCE entidades_links_tipos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.entidades_links_tipos_id_seq OWNER TO stg;

--
-- TOC entry 2489 (class 0 OID 0)
-- Dependencies: 201
-- Name: entidades_links_tipos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: stg
--

ALTER SEQUENCE entidades_links_tipos_id_seq OWNED BY entidades_links_tipos.id;


--
-- TOC entry 204 (class 1259 OID 344102)
-- Name: entidades_tipos; Type: TABLE; Schema: public; Owner: stg; Tablespace: 
--

CREATE TABLE entidades_tipos (
    id integer NOT NULL,
    personalidad character(20),
    forma character varying(250),
    iniciales character(10),
    CONSTRAINT entidades_tipos_personalidad_check CHECK ((personalidad = ANY (ARRAY['FISICA'::character(15), 'JURIDICA'::character(15)])))
);


ALTER TABLE public.entidades_tipos OWNER TO stg;

--
-- TOC entry 203 (class 1259 OID 344100)
-- Name: entidades_tipos_id_seq; Type: SEQUENCE; Schema: public; Owner: stg
--

CREATE SEQUENCE entidades_tipos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.entidades_tipos_id_seq OWNER TO stg;

--
-- TOC entry 2490 (class 0 OID 0)
-- Dependencies: 203
-- Name: entidades_tipos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: stg
--

ALTER SEQUENCE entidades_tipos_id_seq OWNED BY entidades_tipos.id;


--
-- TOC entry 187 (class 1259 OID 303147)
-- Name: familias_orden_seq; Type: SEQUENCE; Schema: public; Owner: stg
--

CREATE SEQUENCE familias_orden_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.familias_orden_seq OWNER TO stg;

--
-- TOC entry 2491 (class 0 OID 0)
-- Dependencies: 187
-- Name: familias_orden_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: stg
--

ALTER SEQUENCE familias_orden_seq OWNED BY familias.orden;


--
-- TOC entry 191 (class 1259 OID 303202)
-- Name: familias_propiedades; Type: TABLE; Schema: public; Owner: stg; Tablespace: 
--

CREATE TABLE familias_propiedades (
    id integer DEFAULT nextval('familias_id_seq'::regclass) NOT NULL,
    cod character varying(10) DEFAULT ''::bpchar,
    familia_id integer,
    propiedad_id integer,
    valor character varying(200),
    orden integer DEFAULT nextval('familias_orden_seq'::regclass),
    separador character varying(1) DEFAULT ' '::bpchar
);


ALTER TABLE public.familias_propiedades OWNER TO stg;

--
-- TOC entry 198 (class 1259 OID 303385)
-- Name: familias_valoresligados; Type: TABLE; Schema: public; Owner: stg; Tablespace: 
--

CREATE TABLE familias_valoresligados (
    id integer NOT NULL,
    fp_id integer,
    fp2_id integer
);


ALTER TABLE public.familias_valoresligados OWNER TO stg;

--
-- TOC entry 197 (class 1259 OID 303383)
-- Name: familias_valoresligados_id_seq; Type: SEQUENCE; Schema: public; Owner: stg
--

CREATE SEQUENCE familias_valoresligados_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.familias_valoresligados_id_seq OWNER TO stg;

--
-- TOC entry 2492 (class 0 OID 0)
-- Dependencies: 197
-- Name: familias_valoresligados_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: stg
--

ALTER SEQUENCE familias_valoresligados_id_seq OWNED BY familias_valoresligados.id;


--
-- TOC entry 200 (class 1259 OID 344086)
-- Name: gruposventas; Type: TABLE; Schema: public; Owner: stg; Tablespace: 
--

CREATE TABLE gruposventas (
    id integer NOT NULL,
    codgrupo character varying(12) NOT NULL,
    describe character varying(100) NOT NULL
);


ALTER TABLE public.gruposventas OWNER TO stg;

--
-- TOC entry 199 (class 1259 OID 344084)
-- Name: gruposventas_id_seq; Type: SEQUENCE; Schema: public; Owner: stg
--

CREATE SEQUENCE gruposventas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.gruposventas_id_seq OWNER TO stg;

--
-- TOC entry 2493 (class 0 OID 0)
-- Dependencies: 199
-- Name: gruposventas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: stg
--

ALTER SEQUENCE gruposventas_id_seq OWNED BY gruposventas.id;


--
-- TOC entry 181 (class 1259 OID 270405)
-- Name: impuestos; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE impuestos (
    id integer NOT NULL,
    valor numeric(5,2) DEFAULT 0 NOT NULL,
    describe character(15) DEFAULT ''::bpchar NOT NULL,
    tipo character(12) DEFAULT 'EXENTO'::bpchar NOT NULL,
    impuesto_id integer,
    CONSTRAINT chkre CHECK (((impuesto_id IS NULL) OR ((impuesto_id IS NOT NULL) AND (tipo = 'RE'::character(12))))),
    CONSTRAINT chktipo CHECK ((tipo = ANY (ARRAY['EXENTO'::character(12), 'IVA'::character(12), 'IGIC'::character(12), 'IMPORTACION'::character(12), 'IRPF'::character(12), 'EXPORTACION'::character(12), 'RE'::character(12), 'VAT'::character(12)])))
);


ALTER TABLE public.impuestos OWNER TO postgres;

--
-- TOC entry 180 (class 1259 OID 270403)
-- Name: impuestos_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE impuestos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.impuestos_id_seq OWNER TO postgres;

--
-- TOC entry 2494 (class 0 OID 0)
-- Dependencies: 180
-- Name: impuestos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE impuestos_id_seq OWNED BY impuestos.id;


--
-- TOC entry 196 (class 1259 OID 303326)
-- Name: menufamilias; Type: VIEW; Schema: public; Owner: stg
--

CREATE VIEW menufamilias AS
 WITH RECURSIVE menufamilias AS (
         SELECT familias.id,
            familias.padre_id,
            familias.codfamilia,
            familias.describe,
            familias.propia,
            familias.competencia,
            familias.orden,
            (familias.describe)::text AS path,
            familias.componer_id
           FROM familias
          WHERE (familias.padre_id IS NULL)
        UNION
         SELECT familias.id,
            familias.padre_id,
            familias.codfamilia,
            familias.describe,
            familias.propia,
            familias.competencia,
            familias.orden,
            ((parentpath.path || ' -> '::text) || (familias.describe)::text) AS path,
            familias.componer_id
           FROM familias,
            menufamilias parentpath
          WHERE (parentpath.id = familias.padre_id)
        )
 SELECT menufamilias.id,
    menufamilias.padre_id,
    menufamilias.codfamilia,
    menufamilias.describe,
    menufamilias.propia,
    menufamilias.competencia,
    menufamilias.orden,
    menufamilias.path,
    menufamilias.componer_id
   FROM menufamilias
  ORDER BY menufamilias.path;


ALTER TABLE public.menufamilias OWNER TO stg;

--
-- TOC entry 173 (class 1259 OID 90120)
-- Name: menus; Type: TABLE; Schema: public; Owner: stg; Tablespace: 
--

CREATE TABLE menus (
    id integer NOT NULL,
    menu_id integer,
    texto character varying(250),
    textoayuda character varying(250),
    iconopen character varying(100),
    iconclosed character varying(100),
    metodo character varying(100)
);


ALTER TABLE public.menus OWNER TO stg;

--
-- TOC entry 2495 (class 0 OID 0)
-- Dependencies: 173
-- Name: TABLE menus; Type: COMMENT; Schema: public; Owner: stg
--

COMMENT ON TABLE menus IS 'Opciones de menú de la aplicación';


--
-- TOC entry 174 (class 1259 OID 90136)
-- Name: menupaths; Type: VIEW; Schema: public; Owner: stg
--

CREATE VIEW menupaths AS
 WITH RECURSIVE menupaths AS (
         SELECT menus.id,
            menus.menu_id AS padre_id,
            menus.texto,
            menus.textoayuda,
            menus.metodo,
            ''::character varying AS padre,
            (menus.texto)::text AS path_texto,
            (menus.id)::text AS path_id,
            menus.iconopen,
            menus.iconclosed
           FROM menus
          WHERE (menus.menu_id IS NULL)
        UNION
         SELECT menus.id,
            menus.menu_id AS padre_id,
            menus.texto,
            menus.textoayuda,
            menus.metodo,
            parentpath.texto AS padre,
            ((parentpath.path_texto || '/'::text) || (menus.texto)::text) AS path_texto,
            ((parentpath.path_id || '/'::text) || menus.id) AS path_id,
            menus.iconopen,
            menus.iconclosed
           FROM menus,
            menupaths parentpath
          WHERE (parentpath.id = menus.menu_id)
        )
 SELECT menupaths.id,
    menupaths.padre_id,
    menupaths.texto,
    menupaths.textoayuda,
    menupaths.metodo,
    menupaths.padre,
    menupaths.path_texto,
    menupaths.path_id,
    menupaths.iconopen,
    menupaths.iconclosed
   FROM menupaths
  ORDER BY menupaths.padre, menupaths.texto;


ALTER TABLE public.menupaths OWNER TO stg;

--
-- TOC entry 172 (class 1259 OID 90118)
-- Name: menus_id_seq; Type: SEQUENCE; Schema: public; Owner: stg
--

CREATE SEQUENCE menus_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.menus_id_seq OWNER TO stg;

--
-- TOC entry 2496 (class 0 OID 0)
-- Dependencies: 172
-- Name: menus_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: stg
--

ALTER SEQUENCE menus_id_seq OWNED BY menus.id;


--
-- TOC entry 190 (class 1259 OID 303174)
-- Name: propiedades; Type: TABLE; Schema: public; Owner: stg; Tablespace: 
--

CREATE TABLE propiedades (
    id integer NOT NULL,
    codpropiedad character varying(5) DEFAULT ''::character varying NOT NULL,
    tcorto character varying(60),
    tlargo character varying(100),
    tcomercial character varying(100),
    propnumerica boolean DEFAULT false,
    componertcorto_id integer DEFAULT 1,
    componertlargo_id integer DEFAULT 1,
    componertcomercial_id integer DEFAULT 1
);


ALTER TABLE public.propiedades OWNER TO stg;

--
-- TOC entry 185 (class 1259 OID 303138)
-- Name: propiedades_componer; Type: TABLE; Schema: public; Owner: stg; Tablespace: 
--

CREATE TABLE propiedades_componer (
    id integer NOT NULL,
    describe character varying(25),
    aplicafamilia boolean DEFAULT false
);


ALTER TABLE public.propiedades_componer OWNER TO stg;

--
-- TOC entry 184 (class 1259 OID 303136)
-- Name: propiedades_componer_id_seq; Type: SEQUENCE; Schema: public; Owner: stg
--

CREATE SEQUENCE propiedades_componer_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.propiedades_componer_id_seq OWNER TO stg;

--
-- TOC entry 2497 (class 0 OID 0)
-- Dependencies: 184
-- Name: propiedades_componer_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: stg
--

ALTER SEQUENCE propiedades_componer_id_seq OWNED BY propiedades_componer.id;


--
-- TOC entry 189 (class 1259 OID 303172)
-- Name: propiedades_id_seq; Type: SEQUENCE; Schema: public; Owner: stg
--

CREATE SEQUENCE propiedades_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.propiedades_id_seq OWNER TO stg;

--
-- TOC entry 2498 (class 0 OID 0)
-- Dependencies: 189
-- Name: propiedades_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: stg
--

ALTER SEQUENCE propiedades_id_seq OWNED BY propiedades.id;


--
-- TOC entry 175 (class 1259 OID 114694)
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: stg; Tablespace: 
--

CREATE TABLE schema_migrations (
    version character varying(255) NOT NULL
);


ALTER TABLE public.schema_migrations OWNER TO stg;

--
-- TOC entry 177 (class 1259 OID 270349)
-- Name: unidadmedida_categorias; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE unidadmedida_categorias (
    id integer NOT NULL,
    describe character varying(60)
);


ALTER TABLE public.unidadmedida_categorias OWNER TO postgres;

--
-- TOC entry 176 (class 1259 OID 270347)
-- Name: unidadmedida_categorias_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE unidadmedida_categorias_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.unidadmedida_categorias_id_seq OWNER TO postgres;

--
-- TOC entry 2499 (class 0 OID 0)
-- Dependencies: 176
-- Name: unidadmedida_categorias_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE unidadmedida_categorias_id_seq OWNED BY unidadmedida_categorias.id;


--
-- TOC entry 179 (class 1259 OID 270357)
-- Name: unidadmedidas; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE unidadmedidas (
    id integer NOT NULL,
    describe character varying(60),
    unidadmedida_categoria_id integer DEFAULT 0,
    factor numeric DEFAULT 1
);


ALTER TABLE public.unidadmedidas OWNER TO postgres;

--
-- TOC entry 178 (class 1259 OID 270355)
-- Name: unidadmedidas_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE unidadmedidas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.unidadmedidas_id_seq OWNER TO postgres;

--
-- TOC entry 2500 (class 0 OID 0)
-- Dependencies: 178
-- Name: unidadmedidas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE unidadmedidas_id_seq OWNED BY unidadmedidas.id;


--
-- TOC entry 2082 (class 2604 OID 303251)
-- Name: id; Type: DEFAULT; Schema: public; Owner: stg
--

ALTER TABLE ONLY articulos ALTER COLUMN id SET DEFAULT nextval('articulos_id_seq'::regclass);


--
-- TOC entry 2063 (class 2604 OID 303133)
-- Name: id; Type: DEFAULT; Schema: public; Owner: stg
--

ALTER TABLE ONLY articulos_lers ALTER COLUMN id SET DEFAULT nextval('articulos_lers_id_seq'::regclass);


--
-- TOC entry 2098 (class 2604 OID 303311)
-- Name: orden; Type: DEFAULT; Schema: public; Owner: stg
--

ALTER TABLE ONLY articulos_propiedades ALTER COLUMN orden SET DEFAULT nextval('articulos_propiedades_orden_seq'::regclass);


--
-- TOC entry 2107 (class 2604 OID 344220)
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY cuentas ALTER COLUMN id SET DEFAULT nextval('cuentas_id_seq'::regclass);


--
-- TOC entry 2123 (class 2604 OID 345312)
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY dircalles ALTER COLUMN id SET DEFAULT nextval('dircalles_id_seq'::regclass);


--
-- TOC entry 2111 (class 2604 OID 345214)
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY dircomunidades ALTER COLUMN id SET DEFAULT nextval('dircomunidades_id_seq'::regclass);


--
-- TOC entry 2131 (class 2604 OID 345348)
-- Name: id; Type: DEFAULT; Schema: public; Owner: stg
--

ALTER TABLE ONLY direcciones ALTER COLUMN id SET DEFAULT nextval('direcciones_id_seq'::regclass);


--
-- TOC entry 2127 (class 2604 OID 345337)
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY direcciones_tipos ALTER COLUMN id SET DEFAULT nextval('direcciones_tipos_id_seq'::regclass);


--
-- TOC entry 2135 (class 2604 OID 345374)
-- Name: id; Type: DEFAULT; Schema: public; Owner: stg
--

ALTER TABLE ONLY direcciones_tipos_links ALTER COLUMN id SET DEFAULT nextval('direcciones_tipos_links_id_seq'::regclass);


--
-- TOC entry 2125 (class 2604 OID 345328)
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY dirinfocomplementarias ALTER COLUMN id SET DEFAULT nextval('dirinfocomplementarias_id_seq'::regclass);


--
-- TOC entry 2116 (class 2604 OID 345251)
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY dirislas ALTER COLUMN id SET DEFAULT nextval('dirislas_id_seq'::regclass);


--
-- TOC entry 2118 (class 2604 OID 345266)
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY dirlocalidades ALTER COLUMN id SET DEFAULT nextval('dirlocalidades_id_seq'::regclass);


--
-- TOC entry 2120 (class 2604 OID 345276)
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY dirmunicipios ALTER COLUMN id SET DEFAULT nextval('dirmunicipios_id_seq'::regclass);


--
-- TOC entry 2122 (class 2604 OID 345297)
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY dirmunicipioscp ALTER COLUMN id SET DEFAULT nextval('dirmunicipioscp_id_seq'::regclass);


--
-- TOC entry 2109 (class 2604 OID 345205)
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY dirpaises ALTER COLUMN id SET DEFAULT nextval('dirpaises_id_seq'::regclass);


--
-- TOC entry 2113 (class 2604 OID 345229)
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY dirprovincias ALTER COLUMN id SET DEFAULT nextval('dirprovincias_id_seq'::regclass);


--
-- TOC entry 2104 (class 2604 OID 344116)
-- Name: id; Type: DEFAULT; Schema: public; Owner: stg
--

ALTER TABLE ONLY entidades ALTER COLUMN id SET DEFAULT nextval('entidades_id_seq'::regclass);


--
-- TOC entry 2108 (class 2604 OID 344257)
-- Name: id; Type: DEFAULT; Schema: public; Owner: stg
--

ALTER TABLE ONLY entidades_gruposventas ALTER COLUMN id SET DEFAULT nextval('entidades_gruposventas_id_seq'::regclass);


--
-- TOC entry 2137 (class 2604 OID 368770)
-- Name: id; Type: DEFAULT; Schema: public; Owner: stg
--

ALTER TABLE ONLY entidades_links ALTER COLUMN id SET DEFAULT nextval('entidades_links_id_seq'::regclass);


--
-- TOC entry 2136 (class 2604 OID 368689)
-- Name: id; Type: DEFAULT; Schema: public; Owner: stg
--

ALTER TABLE ONLY entidades_links_cargos ALTER COLUMN id SET DEFAULT nextval('entidades_links_cargos_id_seq'::regclass);


--
-- TOC entry 2101 (class 2604 OID 344097)
-- Name: id; Type: DEFAULT; Schema: public; Owner: stg
--

ALTER TABLE ONLY entidades_links_tipos ALTER COLUMN id SET DEFAULT nextval('entidades_links_tipos_id_seq'::regclass);


--
-- TOC entry 2102 (class 2604 OID 344105)
-- Name: id; Type: DEFAULT; Schema: public; Owner: stg
--

ALTER TABLE ONLY entidades_tipos ALTER COLUMN id SET DEFAULT nextval('entidades_tipos_id_seq'::regclass);


--
-- TOC entry 2066 (class 2604 OID 303152)
-- Name: id; Type: DEFAULT; Schema: public; Owner: stg
--

ALTER TABLE ONLY familias ALTER COLUMN id SET DEFAULT nextval('familias_id_seq'::regclass);


--
-- TOC entry 2071 (class 2604 OID 303157)
-- Name: orden; Type: DEFAULT; Schema: public; Owner: stg
--

ALTER TABLE ONLY familias ALTER COLUMN orden SET DEFAULT nextval('familias_orden_seq'::regclass);


--
-- TOC entry 2099 (class 2604 OID 303388)
-- Name: id; Type: DEFAULT; Schema: public; Owner: stg
--

ALTER TABLE ONLY familias_valoresligados ALTER COLUMN id SET DEFAULT nextval('familias_valoresligados_id_seq'::regclass);


--
-- TOC entry 2100 (class 2604 OID 344089)
-- Name: id; Type: DEFAULT; Schema: public; Owner: stg
--

ALTER TABLE ONLY gruposventas ALTER COLUMN id SET DEFAULT nextval('gruposventas_id_seq'::regclass);


--
-- TOC entry 2057 (class 2604 OID 270408)
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY impuestos ALTER COLUMN id SET DEFAULT nextval('impuestos_id_seq'::regclass);


--
-- TOC entry 2052 (class 2604 OID 90123)
-- Name: id; Type: DEFAULT; Schema: public; Owner: stg
--

ALTER TABLE ONLY menus ALTER COLUMN id SET DEFAULT nextval('menus_id_seq'::regclass);


--
-- TOC entry 2072 (class 2604 OID 303177)
-- Name: id; Type: DEFAULT; Schema: public; Owner: stg
--

ALTER TABLE ONLY propiedades ALTER COLUMN id SET DEFAULT nextval('propiedades_id_seq'::regclass);


--
-- TOC entry 2064 (class 2604 OID 303141)
-- Name: id; Type: DEFAULT; Schema: public; Owner: stg
--

ALTER TABLE ONLY propiedades_componer ALTER COLUMN id SET DEFAULT nextval('propiedades_componer_id_seq'::regclass);


--
-- TOC entry 2053 (class 2604 OID 270352)
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY unidadmedida_categorias ALTER COLUMN id SET DEFAULT nextval('unidadmedida_categorias_id_seq'::regclass);


--
-- TOC entry 2054 (class 2604 OID 270360)
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY unidadmedidas ALTER COLUMN id SET DEFAULT nextval('unidadmedidas_id_seq'::regclass);


--
-- TOC entry 2415 (class 0 OID 303248)
-- Dependencies: 193
-- Data for Name: articulos; Type: TABLE DATA; Schema: public; Owner: stg
--

INSERT INTO articulos VALUES (16325, 17, 0, 1, '111731001      ', 'Colchón  Canarias', 'Colchón  Canarias 100x182x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16326, 17, 0, 1, '111731051      ', 'Colchón  Canarias', 'Colchón  Canarias 105x182x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16327, 17, 0, 1, '111731201      ', 'Colchón  Canarias', 'Colchón  Canarias 120x182x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16328, 17, 0, 1, '111731351      ', 'Colchón  Canarias', 'Colchón  Canarias 135x182x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16329, 17, 0, 1, '111731401      ', 'Colchón  Canarias', 'Colchón  Canarias 140x182x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16330, 17, 0, 1, '111731501      ', 'Colchón  Canarias', 'Colchón  Canarias 150x182x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16331, 17, 0, 1, '111731601      ', 'Colchón  Canarias', 'Colchón  Canarias 160x182x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16332, 17, 0, 1, '111731801      ', 'Colchón  Canarias', 'Colchón  Canarias 180x182x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16333, 17, 0, 1, '111732001      ', 'Colchón  Canarias', 'Colchón  Canarias 200x182x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16334, 17, 0, 1, '111731101      ', 'Colchón  Canarias', 'Colchón  Canarias 110x182x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16335, 17, 0, 1, '111731151      ', 'Colchón  Canarias', 'Colchón  Canarias 115x182x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16339, 17, 0, 1, '111731002      ', 'Colchón  Canarias', 'Colchón  Canarias 100x190x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16340, 17, 0, 1, '111731052      ', 'Colchón  Canarias', 'Colchón  Canarias 105x190x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16341, 17, 0, 1, '111731202      ', 'Colchón  Canarias', 'Colchón  Canarias 120x190x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16342, 17, 0, 1, '111731352      ', 'Colchón  Canarias', 'Colchón  Canarias 135x190x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16343, 17, 0, 1, '111731402      ', 'Colchón  Canarias', 'Colchón  Canarias 140x190x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16344, 17, 0, 1, '111731502      ', 'Colchón  Canarias', 'Colchón  Canarias 150x190x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16345, 17, 0, 1, '111731602      ', 'Colchón  Canarias', 'Colchón  Canarias 160x190x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16346, 17, 0, 1, '111731802      ', 'Colchón  Canarias', 'Colchón  Canarias 180x190x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16347, 17, 0, 1, '111732002      ', 'Colchón  Canarias', 'Colchón  Canarias 200x190x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16348, 17, 0, 1, '111731102      ', 'Colchón  Canarias', 'Colchón  Canarias 110x190x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16349, 17, 0, 1, '111731152      ', 'Colchón  Canarias', 'Colchón  Canarias 115x190x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16353, 17, 0, 1, '111731003      ', 'Colchón  Canarias', 'Colchón  Canarias 100x200x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16354, 17, 0, 1, '111731053      ', 'Colchón  Canarias', 'Colchón  Canarias 105x200x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16355, 17, 0, 1, '111731203      ', 'Colchón  Canarias', 'Colchón  Canarias 120x200x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16356, 17, 0, 1, '111731353      ', 'Colchón  Canarias', 'Colchón  Canarias 135x200x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16357, 17, 0, 1, '111731403      ', 'Colchón  Canarias', 'Colchón  Canarias 140x200x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16358, 17, 0, 1, '111731503      ', 'Colchón  Canarias', 'Colchón  Canarias 150x200x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16359, 17, 0, 1, '111731603      ', 'Colchón  Canarias', 'Colchón  Canarias 160x200x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16360, 17, 0, 1, '111731803      ', 'Colchón  Canarias', 'Colchón  Canarias 180x200x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16361, 17, 0, 1, '111732003      ', 'Colchón  Canarias', 'Colchón  Canarias 200x200x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16362, 17, 0, 1, '111731103      ', 'Colchón  Canarias', 'Colchón  Canarias 110x200x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16363, 17, 0, 1, '111731153      ', 'Colchón  Canarias', 'Colchón  Canarias 115x200x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16367, 17, 0, 1, '111731004      ', 'Colchón  Canarias', 'Colchón  Canarias 100x210x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16368, 17, 0, 1, '111731054      ', 'Colchón  Canarias', 'Colchón  Canarias 105x210x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16323, 17, 0, 1, '111730801      ', 'Colchón  Canarias', 'Colchón  Canarias 80x182x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16324, 17, 0, 1, '111730901      ', 'Colchón  Canarias', 'Colchón  Canarias 90x182x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16336, 17, 0, 1, '111731060      ', 'Colchón  Canarias', 'Colchón  Canariasx182x23 60', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16337, 17, 0, 1, '111730802      ', 'Colchón  Canarias', 'Colchón  Canarias 80x190x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16338, 17, 0, 1, '111730902      ', 'Colchón  Canarias', 'Colchón  Canarias 90x190x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16350, 17, 0, 1, '111732060      ', 'Colchón  Canarias', 'Colchón  Canariasx190x23 60', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16351, 17, 0, 1, '111730803      ', 'Colchón  Canarias', 'Colchón  Canarias 80x200x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16352, 17, 0, 1, '111730903      ', 'Colchón  Canarias', 'Colchón  Canarias 90x200x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16364, 17, 0, 1, '111733060      ', 'Colchón  Canarias', 'Colchón  Canariasx200x23 60', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16365, 17, 0, 1, '111730804      ', 'Colchón  Canarias', 'Colchón  Canarias 80x210x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16366, 17, 0, 1, '111730904      ', 'Colchón  Canarias', 'Colchón  Canarias 90x210x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16378, 17, 0, 1, '111734060      ', 'Colchón  Canarias', 'Colchón  Canariasx210x23 60', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16379, 17, 0, 1, '111730805      ', 'Colchón  Canarias', 'Colchón  Canarias 80x220x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16380, 17, 0, 1, '111730905      ', 'Colchón  Canarias', 'Colchón  Canarias 90x220x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16392, 17, 0, 1, '111735060      ', 'Colchón  Canarias', 'Colchón  Canariasx220x23 60', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16369, 17, 0, 1, '111731204      ', 'Colchón  Canarias', 'Colchón  Canarias 120x210x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16370, 17, 0, 1, '111731354      ', 'Colchón  Canarias', 'Colchón  Canarias 135x210x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16371, 17, 0, 1, '111731404      ', 'Colchón  Canarias', 'Colchón  Canarias 140x210x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16372, 17, 0, 1, '111731504      ', 'Colchón  Canarias', 'Colchón  Canarias 150x210x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16373, 17, 0, 1, '111731604      ', 'Colchón  Canarias', 'Colchón  Canarias 160x210x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16374, 17, 0, 1, '111731804      ', 'Colchón  Canarias', 'Colchón  Canarias 180x210x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16375, 17, 0, 1, '111732004      ', 'Colchón  Canarias', 'Colchón  Canarias 200x210x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16376, 17, 0, 1, '111731104      ', 'Colchón  Canarias', 'Colchón  Canarias 110x210x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16377, 17, 0, 1, '111731154      ', 'Colchón  Canarias', 'Colchón  Canarias 115x210x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16381, 17, 0, 1, '111731005      ', 'Colchón  Canarias', 'Colchón  Canarias 100x220x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16382, 17, 0, 1, '111731055      ', 'Colchón  Canarias', 'Colchón  Canarias 105x220x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16383, 17, 0, 1, '111731205      ', 'Colchón  Canarias', 'Colchón  Canarias 120x220x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16384, 17, 0, 1, '111731355      ', 'Colchón  Canarias', 'Colchón  Canarias 135x220x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16385, 17, 0, 1, '111731405      ', 'Colchón  Canarias', 'Colchón  Canarias 140x220x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16386, 17, 0, 1, '111731505      ', 'Colchón  Canarias', 'Colchón  Canarias 150x220x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16387, 17, 0, 1, '111731605      ', 'Colchón  Canarias', 'Colchón  Canarias 160x220x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16388, 17, 0, 1, '111731805      ', 'Colchón  Canarias', 'Colchón  Canarias 180x220x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16389, 17, 0, 1, '111732005      ', 'Colchón  Canarias', 'Colchón  Canarias 200x220x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16390, 17, 0, 1, '111731105      ', 'Colchón  Canarias', 'Colchón  Canarias 110x220x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);
INSERT INTO articulos VALUES (16391, 17, 0, 1, '111731155      ', 'Colchón  Canarias', 'Colchón  Canarias 115x220x23', 'Colchón  Canarias', true, false, 0, false, false, NULL, 1, 1, NULL, '2015-11-23 16:18:41.32', NULL);


--
-- TOC entry 2501 (class 0 OID 0)
-- Dependencies: 192
-- Name: articulos_id_seq; Type: SEQUENCE SET; Schema: public; Owner: stg
--

SELECT pg_catalog.setval('articulos_id_seq', 16392, true);


--
-- TOC entry 2405 (class 0 OID 303130)
-- Dependencies: 183
-- Data for Name: articulos_lers; Type: TABLE DATA; Schema: public; Owner: stg
--

INSERT INTO articulos_lers VALUES (1, '20104', false, '                                                  ', 'Residuos plásticos');
INSERT INTO articulos_lers VALUES (2, '20110', false, '                                                  ', 'Residuos metálicos');
INSERT INTO articulos_lers VALUES (3, '30101', false, '                                                  ', 'Residuos de corteza y corcho');
INSERT INTO articulos_lers VALUES (4, '030104*', true, 'Q12/D15/S40/C51/H05/A936(9)/B0019                 ', 'Serrín, virutas, recortes, madera, tableros de partículas y chapas que contienen sustancias peligrosas');
INSERT INTO articulos_lers VALUES (5, '30105', false, '                                                  ', 'Serrín, virutas, recortes, madera, tableros de partículas y chapas distintos de los mencionados en el código 030104 ');
INSERT INTO articulos_lers VALUES (6, '080111*', true, 'Q08/R13/P12/C41/H3B/A936(9)/B0019                 ', 'Residuos de pintura y barniz que contienen disolventes orgánicos u otras sustancias peligrosas');
INSERT INTO articulos_lers VALUES (7, '080113*', true, 'Q08/D15/P12/C43/H05/A936(9)/B0019                 ', 'Lodos de pintura y barniz que contienen disolventes orgánicos u otras sustancias peligrosas');
INSERT INTO articulos_lers VALUES (8, '080115*', true, 'Q08/R13/LP12/C41/H3-B/A936(9)/B0019               ', 'Lodos acuosos que contienen pintura o barniz con disolventes orgánicos u otras sustancias peligrosas');
INSERT INTO articulos_lers VALUES (9, '080117*', true, 'Q08/R13/P12/C41/H3-B/A936(9)/B0019                ', 'Residuos de decapado o eliminación de pintura y barniz que contienen disolventes orgánicos u otras sustancias peligrosas');
INSERT INTO articulos_lers VALUES (10, '80199', false, '                                                  ', 'Filtros de cabina de pintura ');
INSERT INTO articulos_lers VALUES (11, '080312*', true, 'Q07/D15/L12/C43/H05/A936(9)/B0019                 ', 'Residuos de tintas que contienen sustancias peligrosas ');
INSERT INTO articulos_lers VALUES (12, '80313', false, '                                                  ', 'Residuos de tintas distintos de los especificados en el código 080312');
INSERT INTO articulos_lers VALUES (13, '080314*', true, 'Q07/D15/L12/C43/H05/A936(9)/B0019                 ', 'Lodos de tinta que contienen sustancias peligrosas ');
INSERT INTO articulos_lers VALUES (14, '080317*', true, 'Q14/R13/S12/C43/H05/A936(9)/B0019                 ', 'Residuos de tóner de impresión que contienen sustancias peligrosas ');
INSERT INTO articulos_lers VALUES (15, '80318', true, '                                                  ', 'Residuos de tóner de impresión distintos de los especificados en el código 080317');
INSERT INTO articulos_lers VALUES (16, '080409*', true, 'Q07/D15/L13/C41/H05/A936(9)/B0019                 ', 'Residuos de adhesivos y sellantes que contienen disolventes orgánicos u otras sustancias peligrosas');
INSERT INTO articulos_lers VALUES (17, '090103*', true, 'Q07/D15/L12/C43/H05/A936(9)/B0019                 ', 'Soluciones de revelado con disolventes');
INSERT INTO articulos_lers VALUES (18, '090104*', true, 'Q07/D15/L40/C43/H06/A936(9)/B0019                 ', 'Soluciones de fijado ');
INSERT INTO articulos_lers VALUES (19, '120101', false, '                                                  ', 'Limaduras y virutas de metales férreos');
INSERT INTO articulos_lers VALUES (20, '120103', false, '                                                  ', 'Limaduras y virutas de metales no férreos ');
INSERT INTO articulos_lers VALUES (21, '120106*', true, 'Q07/R13/L08/C40C51/H06/A936(9)/B0019              ', 'Aceites minerales de mecanizado que contienen halógenos (excepto las emulsiones o disoluciones)');
INSERT INTO articulos_lers VALUES (22, '120107*', true, 'Q07/R13/L08/C51/H05/A936(9)/B0019                 ', 'Aceites minerales de mecanizado sin halógenos (excepto las emulsiones o disoluciones)');
INSERT INTO articulos_lers VALUES (23, '120108*', true, 'Q07/R13/L08/C40C51/H06/A936(9)/B0019              ', 'Emulsiones y disoluciones de mecanizado que contienen halógenos ');
INSERT INTO articulos_lers VALUES (24, '120109*', true, 'Q07/D15/L09/C51/H05/A936(9)/B0019                 ', 'Emulsiones y disoluciones de mecanizado sin halógenos');
INSERT INTO articulos_lers VALUES (25, '120110*', true, 'Q07/R13/L08/C51/H05/A936(9)/B0019                 ', 'Aceites sintéticos de mecanizado');
INSERT INTO articulos_lers VALUES (26, '120112*', true, 'Q07/D15/P19/C51/H05/A936(9)/B0019                 ', 'Ceras y grasas usadas');
INSERT INTO articulos_lers VALUES (27, '120114*', true, 'Q08/D15/S08/C51/H05/A936(9)/B0019                 ', 'Lodos de mecanizado que contienen sustancias peligrosas');
INSERT INTO articulos_lers VALUES (28, '120116*', true, 'Q08/D15/S25/C51/H05/A936(9)/B0019                 ', 'Residuos de granallado o chorreado que contienen sustancias peligrosas (polvo de lijado)');
INSERT INTO articulos_lers VALUES (29, '120118*', true, 'Q08/D15/S08/C51/H05/A936(9)/B0019                 ', 'Lodos metálicos (lodos de esmerilado, rectificado y lapeado) que contienen aceites');
INSERT INTO articulos_lers VALUES (30, '120119*', true, 'Q07/R13/L08/C51/H05/A936(9)/B0019                 ', 'Aceites de mecanizado fácilmente biodegradables');
INSERT INTO articulos_lers VALUES (31, '120120*', true, 'Q05/D15/S09/C51C41/H05/A936(9)/B0019              ', 'Muelas y materiales de esmerilado usados que contienen sustancias peligrosas ');
INSERT INTO articulos_lers VALUES (32, '120121', false, '                                                  ', 'Muelas y materiales de esmerilado usados distintos de los especificados en el código 12 01 20 ');
INSERT INTO articulos_lers VALUES (33, '130104*', true, 'Q07/R13/L08/C40C51/H06/A936(9)/B0019              ', 'Emulsiones cloradas');
INSERT INTO articulos_lers VALUES (34, '130105*', true, 'Q07/D15/L09/C51/H05/A936(9)/B0019                 ', 'Emulsiones no cloradas ');
INSERT INTO articulos_lers VALUES (35, '130109*', true, 'Q07/R13/L08/C40C51/H06/A936(9)/B0019              ', 'Aceites hidráulicos minerales clorados');
INSERT INTO articulos_lers VALUES (36, '130110*', true, 'Q07/R13/L08/C51/H05/A936(9)/B0019                 ', 'Aceites hidráulicos minerales no clorados ');
INSERT INTO articulos_lers VALUES (37, '130111*', true, 'Q07/R13/L08/C51/H05/A936(9)/B0019                 ', 'Aceites hidráulicos sintéticos');
INSERT INTO articulos_lers VALUES (38, '130112*', true, 'Q07/R13/L08/C51/H05/A936(9)/B0019                 ', 'Aceites hidráulicos fácilmente biodegradables');
INSERT INTO articulos_lers VALUES (39, '130113*', true, 'Q07/R13/L08/C51/H05/A936(9)/B0019                 ', 'Otros aceites hidráulicos');
INSERT INTO articulos_lers VALUES (40, '130204*', true, 'Q07/R13/L08/C40C51/H06/A936(9)/B0019              ', 'Aceites minerales clorados de motor, de transmisión mecánica y lubricantes ');
INSERT INTO articulos_lers VALUES (41, '130205*', true, 'Q07/R13/L08/C51/H05/A936(9)/B0019                 ', 'Aceites minerales no clorados de motor, de transmisión mecánica y lubricantes');
INSERT INTO articulos_lers VALUES (42, '130206*', true, 'Q07/R13/L08/C51/H05/A936(9)/B0019                 ', 'Aceites sintéticos de motor, de transmisión mecánica y lubricantes');
INSERT INTO articulos_lers VALUES (43, '130207*', true, 'Q07/R13/L08/C51/H05/A936(9)/B0019                 ', 'Aceites fácilmente biodegradables de motor, de transmisión mecánica y lubricantes');
INSERT INTO articulos_lers VALUES (44, '130208*', true, 'Q07/R13/L08/C51/H05/A936(9)/B0019                 ', 'Otros aceites de motor, de transmisión mecánica y lubricantes ');
INSERT INTO articulos_lers VALUES (45, '130501*', true, 'Q12/D15/S23/C51/H05/A936(9)/B0019                 ', 'Sólidos procedentes de separadores');
INSERT INTO articulos_lers VALUES (46, '130502*', true, 'Q08/D15/P08/C51/H05/A936(9)/B0019                 ', 'Lodos del separador de agua /sustancias aceitosas');
INSERT INTO articulos_lers VALUES (47, '130506*', true, 'Q07/R13/L08/C51/H05/A936(9)/B0019                 ', 'Sólidos procedentes de los desarenadotes y de separadores de aguas/sustancias aceitosas ');
INSERT INTO articulos_lers VALUES (48, '130507*', true, 'Q07/D15/L09/C51/H05/A936(9)/B0019                 ', 'Agua aceitosa procedente de separadores de agua/sustancias aceitosas');
INSERT INTO articulos_lers VALUES (49, '130508*', true, 'Q07/D15/L09/C51/H05/A936(9)/B0019                 ', 'Mezcla de residuos procedentes de desarenadores y de separadores de agua / sustancias aceitosas');
INSERT INTO articulos_lers VALUES (50, '130702*', true, 'Q08/R13/L09/C51/H3B/A936(9)/B0019                 ', 'Gasolinas ');
INSERT INTO articulos_lers VALUES (51, '130701*', true, 'Q08/R13/L09/C51/H3A/A936(9)/B0019                 ', 'Gasóleos');
INSERT INTO articulos_lers VALUES (52, '130703*', true, 'Q08/R13/L09/C51/H3-A/A936(9)/B0019                ', 'Otros combustibles (incluidas mezclas)');
INSERT INTO articulos_lers VALUES (53, '140601*', true, 'Q07/D15/L05/C40/H06/A936(9)/B0019                 ', 'Clorofluorocarbonos, CFC, HFC (fluidos del sistema de aire acondicionado, gas licuado)');
INSERT INTO articulos_lers VALUES (54, '140602*', true, 'Q07/R13/L05/C40/H06/A936(9)/B0019                 ', 'Disolventes y mezclas de disolventes halogenados ');
INSERT INTO articulos_lers VALUES (55, '140603*', true, 'Q07/R13/L05/C41/H3-B/A936(9)/B0019                ', 'Otros disolventes y mezclas de disolventes');
INSERT INTO articulos_lers VALUES (56, '140604*', true, 'Q07/D15/L05/C40/H06/A936(9)/B0019                 ', 'Lodos o residuos sólidos que contienen disolventes halogenados');
INSERT INTO articulos_lers VALUES (57, '140605*', true, 'Q07/D15/L40/C43/H06/A936(9)/B0019                 ', 'Lodos o residuos sólidos que contienen otros disolventes');
INSERT INTO articulos_lers VALUES (58, '150101', false, '                                                  ', 'Envases de papel y cartón');
INSERT INTO articulos_lers VALUES (59, '150102', false, '                                                  ', 'Envases de plástico');
INSERT INTO articulos_lers VALUES (60, '150103', false, '                                                  ', 'Envases de madera');
INSERT INTO articulos_lers VALUES (61, '150104', false, '                                                  ', 'Envases metálicos');
INSERT INTO articulos_lers VALUES (62, '150105', false, '                                                  ', 'Envases compuestos');
INSERT INTO articulos_lers VALUES (63, '150106', false, '                                                  ', 'Envases mezclados');
INSERT INTO articulos_lers VALUES (64, '150107', false, '                                                  ', 'Envases de vidrio');
INSERT INTO articulos_lers VALUES (65, '150109', false, '                                                  ', 'Envases textiles');
INSERT INTO articulos_lers VALUES (66, '150110*', true, 'Q05/R13/S36/C51C41/H05/A936(9)/B0019              ', 'Envases plásticos que contienen restos de sustancias peligrosas');
INSERT INTO articulos_lers VALUES (67, '150111*', true, 'Q05/R13/S36/C51C41/H05/A936(9)/B0019              ', 'Envases metálicos con restos de sustancias peligrosas  ');
INSERT INTO articulos_lers VALUES (68, '150202*', true, 'Q05/D15/S09/C51C41/H05/A936(9)/B0019              ', 'Absorbentes, materiales de filtración (incluidos los filtros de aceite no especificados en otra categoría), trapos de limpieza y ropas protectoras contaminados por sustancias peligrosas');
INSERT INTO articulos_lers VALUES (69, '160103', false, '                                                  ', 'Neumáticos fuera de uso');
INSERT INTO articulos_lers VALUES (70, '160106', false, '                                                  ', 'Vehículos al final de su vida útil que no contengan sustancias peligrosas');
INSERT INTO articulos_lers VALUES (71, '160107*', true, 'Q06/R04/S35/C51/H05/A0000935/B9703                ', 'Filtros de aceite');
INSERT INTO articulos_lers VALUES (72, '160108*', true, 'Q16/R13/S37/C16/H06/A936(9)/B0019                 ', 'Componentes que contengan mercurio  ');
INSERT INTO articulos_lers VALUES (73, '160113*', true, 'Q14/R13/L40/C43/H05/A936(9)/B0019                 ', 'Líquido de frenos');
INSERT INTO articulos_lers VALUES (74, '160114*', true, 'Q14/R13/L40/C43/H05/A936(9)/B0019                 ', 'Líquidos de refrigeración y anticongelante');
INSERT INTO articulos_lers VALUES (75, '160117', false, '                                                  ', 'Metales ferrosos');
INSERT INTO articulos_lers VALUES (76, '160118', false, '                                                  ', 'Metales no ferrosos    ');
INSERT INTO articulos_lers VALUES (77, '160119', false, '                                                  ', 'Plástico');
INSERT INTO articulos_lers VALUES (78, '160120', false, '                                                  ', 'Vidrio');
INSERT INTO articulos_lers VALUES (79, '160211*', true, 'Q16/D15/S40/C05/H05/A936(9)/B0019                 ', 'Equipos desechados que contienen clorofluorocarbonos, HCFC, HFC');
INSERT INTO articulos_lers VALUES (80, '160213*', true, 'Q16/D15/S40/C06/H05/A936(9)/B0019                 ', 'Equipos eléctricos y electrónicos desechados que contienen componentes peligrosos (distintos de los especificados en los códigos de 160209* a 160212*)   ');
INSERT INTO articulos_lers VALUES (81, '160214', false, '                                                  ', 'Equipos eléctricos y electrónicos desechados distintos de los especificados en los códigos de 160209* a 160213*)  ');
INSERT INTO articulos_lers VALUES (82, '160215*', true, 'Q16/D15/S40/C06/H05/A936(9)/B0019                 ', 'Componentes peligrosos retirados de equipos desechados ');
INSERT INTO articulos_lers VALUES (83, '160216', false, '                                                  ', 'Componentes retirados de equipos desechados, distintos de los especificados en el código 160215*');
INSERT INTO articulos_lers VALUES (84, '160504*', true, 'Q14/D15/S39/C40/H3-B/A936(9)/B0019                ', 'Gases en recipientes a presión (incluidos los halones) que contienen sustancias peligrosas');
INSERT INTO articulos_lers VALUES (85, '160506*', true, 'Q03/D15/L40/C23C41/H06/A936(9)/B0019              ', 'Productos químicos de laboratorio que consisten en, o contienen, sustancias peligrosas, incluidas las mezclas de productos químicos de laboratorio');
INSERT INTO articulos_lers VALUES (86, '160507*', true, 'Q03/D15/L40/C23C41/H06/A936(9)/B0019              ', 'Productos químicos inorgánicos desechados que consisten en, o contienen, sustancias peligrosas');
INSERT INTO articulos_lers VALUES (87, '160508*', true, 'Q03/D15/L40/C23C41/H06/A936(9)/B0019              ', 'Productos químicos orgánicos desechados que consisten en, o contienen, sustancias peligrosas  ');
INSERT INTO articulos_lers VALUES (88, '160601*', true, 'Q06/R04/S37/C23C18/H06H08/A0000961/B9703          ', 'Baterías de plomo');
INSERT INTO articulos_lers VALUES (89, '160602*', true, 'Q16/R13/S37/C05C11/H06/A936(9)/B0019              ', 'Acumuladores de Ni-Cd  ');
INSERT INTO articulos_lers VALUES (90, '160603*', true, 'Q16/R13/S37/C16/H06/A936(9)/B0019                 ', 'Pilas que contienen mercurio (botón)');
INSERT INTO articulos_lers VALUES (91, '160604', false, '                                                  ', 'Pilas alcalinas (excepto las del código 160603*-Hg)');
INSERT INTO articulos_lers VALUES (92, '160605', false, '                                                  ', 'Otras pilas y acumuladores   ');
INSERT INTO articulos_lers VALUES (93, '160708*', true, 'Q07/D15/L09/C51/H05/A936(9)/B0019                 ', 'Residuos que contienen hidrocarburos');
INSERT INTO articulos_lers VALUES (94, '160801', false, '                                                  ', 'Catalizadores usados que contienen oro, plata, renio, rodio, paladio, iridio o platino (excepto los del código 160807)  ');
INSERT INTO articulos_lers VALUES (95, '160802*', true, 'Q14/D15/S26/C18/H05/A936(9)/B0019                 ', 'Catalizadores que contienen metales de transición peligrosos o compuestos de metales de transición peligrosos     ');
INSERT INTO articulos_lers VALUES (96, '160803', false, '                                                  ', 'Catalizadores usados que contienen metales de transición o compuestos de metales de transición no especificados en otra categoría    ');
INSERT INTO articulos_lers VALUES (97, '170101', false, '                                                  ', 'Hormigón');
INSERT INTO articulos_lers VALUES (98, '170102', false, '                                                  ', 'Ladrillos');
INSERT INTO articulos_lers VALUES (99, '170103', false, '                                                  ', 'Tejas y materiales cerámicos ');
INSERT INTO articulos_lers VALUES (100, '170106*', true, 'Q12/D15/S23/C51/H05/A936(9)/B0019                 ', 'Mezclas, o fracciones separadas, de hormigón, ladrillos, tejas y materiales cerámicos que contienen sustancias peligrosas');
INSERT INTO articulos_lers VALUES (101, '170107', false, '                                                  ', 'Mezclas, o fracciones separadas, de hormigón, ladrillos, tejas y materiales cerámicos distintas de las especificadas en el código 170106    ');
INSERT INTO articulos_lers VALUES (102, '170201', false, '                                                  ', 'Madera');
INSERT INTO articulos_lers VALUES (103, '170202', false, '                                                  ', 'Vidrio');
INSERT INTO articulos_lers VALUES (104, '170203', false, '                                                  ', 'Plástico');
INSERT INTO articulos_lers VALUES (105, '170204*', true, 'Q12/R13/S36/C51/H05/A936(9)/B0019                 ', 'Vidrio, plástico y madera que contienen sustancias peligrosas o están contaminados por ellas  ');
INSERT INTO articulos_lers VALUES (106, '170401', false, '                                                  ', 'Cobre, bronce, latón   ');
INSERT INTO articulos_lers VALUES (107, '170402', false, '                                                  ', 'Aluminio');
INSERT INTO articulos_lers VALUES (108, '170403', false, '                                                  ', 'Plomo');
INSERT INTO articulos_lers VALUES (109, '170405', false, '                                                  ', 'Hierro y acero');
INSERT INTO articulos_lers VALUES (110, '170406', false, '                                                  ', 'Estaño');
INSERT INTO articulos_lers VALUES (111, '170407', false, '                                                  ', 'Metales mezclados');
INSERT INTO articulos_lers VALUES (112, '170411', false, '                                                  ', 'Cables de cobre y cables de aluminio (considerados como metales incluidos en los residuos de la construcción y demolición)     ');
INSERT INTO articulos_lers VALUES (113, '170503*', true, 'Q12/D15/S23/C51/H05/A936(9)/B0019                 ', 'Tierra y piedras que contienen sustancias peligrosas   ');
INSERT INTO articulos_lers VALUES (114, '170601*', true, 'Q07/D15/S12/C25/H06/A936(9)/B0019                 ', 'Materiales de aislamiento que contienen amianto  ');
INSERT INTO articulos_lers VALUES (115, '170801*', true, 'Q12/D15/S23/C51/H05/A936(9)/B0019                 ', 'Material de construcción a partir de yeso contaminado con sustancias peligrosas  ');
INSERT INTO articulos_lers VALUES (116, '170802', false, '                                                  ', 'Materiales de construcción a partir de yeso distintos de los especificados en el código 170801');
INSERT INTO articulos_lers VALUES (117, '170903*', true, 'Q12/R15/S23/C51/H05/A936(9)/B0019                 ', 'Otros residuos de construcción y demolición (incluidos los residuos mezclados) que contienen sustancias peligrosas');
INSERT INTO articulos_lers VALUES (118, '170904', false, '                                                  ', 'Residuos mezclados de construcción y demolición distintos de los especificados en los códigos 170901, 170902 y 170903');
INSERT INTO articulos_lers VALUES (119, '190102', false, '                                                  ', 'Materiales férreos separados de la ceniza de fondo de horno');
INSERT INTO articulos_lers VALUES (120, '190205*', true, 'Q09/D15/S27/C24/H05/A936(9)/B0019                 ', 'Lodos de tratamientos físico-químicos que contienen sustancias peligrosas  ');
INSERT INTO articulos_lers VALUES (121, '190501', false, '                                                  ', 'Fracción no comportada de residuos municipales y asimilados. Residuos del tratamiento aeróbico de residuos sólidos.');
INSERT INTO articulos_lers VALUES (122, '191001', false, '                                                  ', 'Residuos de hierro y acero');
INSERT INTO articulos_lers VALUES (123, '191002', false, '                                                  ', 'Residuos no férreos');
INSERT INTO articulos_lers VALUES (124, '191202', false, '                                                  ', 'Metales férreos');
INSERT INTO articulos_lers VALUES (125, '191203', false, '                                                  ', 'Metales no férreos');
INSERT INTO articulos_lers VALUES (126, '200101', false, '                                                  ', 'Papel y cartón');
INSERT INTO articulos_lers VALUES (127, '200102', false, '                                                  ', 'Vidrio');
INSERT INTO articulos_lers VALUES (128, '200114*', true, 'Q07/D15/L27/C23/H08/A936(9)/B0019                 ', 'Ácidos');
INSERT INTO articulos_lers VALUES (129, '200117*', true, 'Q07/D15/L40/C43/H06/A936(9)/B0019                 ', 'Productos fotoquímicos ');
INSERT INTO articulos_lers VALUES (130, '200121*', true, 'Q14/D15/S40/C16/H05/A936(9)/B0019                 ', 'Tubos fluorescentes y otros residuos que contienen mercurio   ');
INSERT INTO articulos_lers VALUES (131, '200125', false, '                                                  ', 'Aceites y grasas comestibles ');
INSERT INTO articulos_lers VALUES (132, '200133*', true, 'Q06/R13/S37/C18C23/H08/A936(9)/B0019              ', 'Baterías y acumuladores especificados en los códigos 160601, 160602 o 160603 y baterías y acumuladores sin clasificar que contienen esas baterías ');
INSERT INTO articulos_lers VALUES (133, '200134', false, '                                                  ', 'Baterías y acumuladores distintos de los especificados en el código 200133 ');
INSERT INTO articulos_lers VALUES (134, '200135*', true, 'Q16/D15/S40/C06/H05/A936(9)/B0019                 ', 'Equipos eléctricos y electrónicos desechados, distintos de los especificados en los códigos 200121 y 200123, que contienen componentes peligrosos ');
INSERT INTO articulos_lers VALUES (135, '200136', false, '                                                  ', 'Equipos eléctricos y electrónicos desechados distintos de los especificados en los códigos 200121, 200123 y 200135');
INSERT INTO articulos_lers VALUES (136, '200137*', true, 'Q12/D15/S40/C51/H05/A936(9)/B0019                 ', 'Madera que contiene sustancias peligrosas ');
INSERT INTO articulos_lers VALUES (137, '200138', false, '                                                  ', 'Madera distinta de la especificada en el código 200137 ');
INSERT INTO articulos_lers VALUES (138, '200139', false, '                                                  ', 'Plásticos');
INSERT INTO articulos_lers VALUES (139, '200140', false, '                                                  ', 'Metales');
INSERT INTO articulos_lers VALUES (140, '200201', false, '                                                  ', 'Residuos biodegradables de parques y jardines    ');
INSERT INTO articulos_lers VALUES (141, '200301', false, '                                                  ', 'Mezcla de residuos municipales');
INSERT INTO articulos_lers VALUES (142, '200307', false, '                                                  ', 'Residuos voluminosos');
INSERT INTO articulos_lers VALUES (143, '0', false, '                                                  ', 'NO ES UN RESIDUO. NO DEBE DE ESTAR EN STOCK');
INSERT INTO articulos_lers VALUES (144, '160199', false, '                                                  ', 'Residuos no especificados en otra categoria (Esteriles de rechazo)  ');
INSERT INTO articulos_lers VALUES (145, '160118', false, '                                                  ', 'Metales no ferrosos');
INSERT INTO articulos_lers VALUES (146, '160601', false, '                                                  ', 'Baterias de plomo');
INSERT INTO articulos_lers VALUES (147, '170404', false, '                                                  ', 'Zinc');


--
-- TOC entry 2502 (class 0 OID 0)
-- Dependencies: 182
-- Name: articulos_lers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: stg
--

SELECT pg_catalog.setval('articulos_lers_id_seq', 147, true);


--
-- TOC entry 2417 (class 0 OID 303307)
-- Dependencies: 195
-- Data for Name: articulos_propiedades; Type: TABLE DATA; Schema: public; Owner: stg
--

INSERT INTO articulos_propiedades VALUES (82961, 16323, 173, 82723);
INSERT INTO articulos_propiedades VALUES (82962, 16323, 99, 82724);
INSERT INTO articulos_propiedades VALUES (82963, 16323, 104, 82725);
INSERT INTO articulos_propiedades VALUES (82964, 16323, 1757, 82726);
INSERT INTO articulos_propiedades VALUES (82965, 16324, 173, 82727);
INSERT INTO articulos_propiedades VALUES (82966, 16324, 105, 82728);
INSERT INTO articulos_propiedades VALUES (82967, 16324, 99, 82729);
INSERT INTO articulos_propiedades VALUES (82968, 16324, 1757, 82730);
INSERT INTO articulos_propiedades VALUES (82969, 16325, 173, 82731);
INSERT INTO articulos_propiedades VALUES (82970, 16325, 106, 82732);
INSERT INTO articulos_propiedades VALUES (82971, 16325, 99, 82733);
INSERT INTO articulos_propiedades VALUES (82972, 16325, 1757, 82734);
INSERT INTO articulos_propiedades VALUES (82973, 16326, 173, 82735);
INSERT INTO articulos_propiedades VALUES (82974, 16326, 99, 82736);
INSERT INTO articulos_propiedades VALUES (82975, 16326, 1757, 82737);
INSERT INTO articulos_propiedades VALUES (82976, 16326, 107, 82738);
INSERT INTO articulos_propiedades VALUES (82977, 16327, 108, 82739);
INSERT INTO articulos_propiedades VALUES (82978, 16327, 173, 82740);
INSERT INTO articulos_propiedades VALUES (82979, 16327, 99, 82741);
INSERT INTO articulos_propiedades VALUES (82980, 16327, 1757, 82742);
INSERT INTO articulos_propiedades VALUES (82981, 16328, 173, 82743);
INSERT INTO articulos_propiedades VALUES (82982, 16328, 99, 82744);
INSERT INTO articulos_propiedades VALUES (82983, 16328, 109, 82745);
INSERT INTO articulos_propiedades VALUES (82984, 16328, 1757, 82746);
INSERT INTO articulos_propiedades VALUES (82985, 16329, 173, 82747);
INSERT INTO articulos_propiedades VALUES (82986, 16329, 99, 82748);
INSERT INTO articulos_propiedades VALUES (82987, 16329, 1757, 82749);
INSERT INTO articulos_propiedades VALUES (82988, 16329, 110, 82750);
INSERT INTO articulos_propiedades VALUES (82989, 16330, 173, 82751);
INSERT INTO articulos_propiedades VALUES (82990, 16330, 99, 82752);
INSERT INTO articulos_propiedades VALUES (82991, 16330, 1757, 82753);
INSERT INTO articulos_propiedades VALUES (82992, 16330, 111, 82754);
INSERT INTO articulos_propiedades VALUES (82993, 16331, 173, 82755);
INSERT INTO articulos_propiedades VALUES (82994, 16331, 99, 82756);
INSERT INTO articulos_propiedades VALUES (82995, 16331, 112, 82757);
INSERT INTO articulos_propiedades VALUES (82996, 16331, 1757, 82758);
INSERT INTO articulos_propiedades VALUES (82997, 16332, 113, 82759);
INSERT INTO articulos_propiedades VALUES (82998, 16332, 173, 82760);
INSERT INTO articulos_propiedades VALUES (82999, 16332, 99, 82761);
INSERT INTO articulos_propiedades VALUES (83000, 16332, 1757, 82762);
INSERT INTO articulos_propiedades VALUES (83001, 16333, 173, 82763);
INSERT INTO articulos_propiedades VALUES (83002, 16333, 99, 82764);
INSERT INTO articulos_propiedades VALUES (83003, 16333, 1757, 82765);
INSERT INTO articulos_propiedades VALUES (83004, 16333, 114, 82766);
INSERT INTO articulos_propiedades VALUES (83005, 16334, 173, 82767);
INSERT INTO articulos_propiedades VALUES (83006, 16334, 2056, 82768);
INSERT INTO articulos_propiedades VALUES (83007, 16334, 99, 82769);
INSERT INTO articulos_propiedades VALUES (83008, 16334, 1757, 82770);
INSERT INTO articulos_propiedades VALUES (83009, 16335, 173, 82771);
INSERT INTO articulos_propiedades VALUES (83010, 16335, 99, 82772);
INSERT INTO articulos_propiedades VALUES (83011, 16335, 2057, 82773);
INSERT INTO articulos_propiedades VALUES (83012, 16335, 1757, 82774);
INSERT INTO articulos_propiedades VALUES (83013, 16336, 173, 82775);
INSERT INTO articulos_propiedades VALUES (83014, 16336, 99, 82776);
INSERT INTO articulos_propiedades VALUES (83015, 16336, 82680, 82777);
INSERT INTO articulos_propiedades VALUES (83016, 16336, 1757, 82778);
INSERT INTO articulos_propiedades VALUES (83017, 16337, 173, 82779);
INSERT INTO articulos_propiedades VALUES (83018, 16337, 100, 82780);
INSERT INTO articulos_propiedades VALUES (83019, 16337, 104, 82781);
INSERT INTO articulos_propiedades VALUES (83020, 16337, 1757, 82782);
INSERT INTO articulos_propiedades VALUES (83021, 16338, 173, 82783);
INSERT INTO articulos_propiedades VALUES (83022, 16338, 100, 82784);
INSERT INTO articulos_propiedades VALUES (83023, 16338, 105, 82785);
INSERT INTO articulos_propiedades VALUES (83024, 16338, 1757, 82786);
INSERT INTO articulos_propiedades VALUES (83025, 16339, 173, 82787);
INSERT INTO articulos_propiedades VALUES (83026, 16339, 100, 82788);
INSERT INTO articulos_propiedades VALUES (83027, 16339, 106, 82789);
INSERT INTO articulos_propiedades VALUES (83028, 16339, 1757, 82790);
INSERT INTO articulos_propiedades VALUES (83029, 16340, 173, 82791);
INSERT INTO articulos_propiedades VALUES (83030, 16340, 100, 82792);
INSERT INTO articulos_propiedades VALUES (83031, 16340, 1757, 82793);
INSERT INTO articulos_propiedades VALUES (83032, 16340, 107, 82794);
INSERT INTO articulos_propiedades VALUES (83033, 16341, 108, 82795);
INSERT INTO articulos_propiedades VALUES (83034, 16341, 173, 82796);
INSERT INTO articulos_propiedades VALUES (83035, 16341, 100, 82797);
INSERT INTO articulos_propiedades VALUES (83036, 16341, 1757, 82798);
INSERT INTO articulos_propiedades VALUES (83037, 16342, 173, 82799);
INSERT INTO articulos_propiedades VALUES (83038, 16342, 100, 82800);
INSERT INTO articulos_propiedades VALUES (83039, 16342, 109, 82801);
INSERT INTO articulos_propiedades VALUES (83040, 16342, 1757, 82802);
INSERT INTO articulos_propiedades VALUES (83041, 16343, 173, 82803);
INSERT INTO articulos_propiedades VALUES (83042, 16343, 100, 82804);
INSERT INTO articulos_propiedades VALUES (83043, 16343, 1757, 82805);
INSERT INTO articulos_propiedades VALUES (83044, 16343, 110, 82806);
INSERT INTO articulos_propiedades VALUES (83045, 16344, 173, 82807);
INSERT INTO articulos_propiedades VALUES (83046, 16344, 100, 82808);
INSERT INTO articulos_propiedades VALUES (83047, 16344, 1757, 82809);
INSERT INTO articulos_propiedades VALUES (83048, 16344, 111, 82810);
INSERT INTO articulos_propiedades VALUES (83049, 16345, 173, 82811);
INSERT INTO articulos_propiedades VALUES (83050, 16345, 100, 82812);
INSERT INTO articulos_propiedades VALUES (83051, 16345, 112, 82813);
INSERT INTO articulos_propiedades VALUES (83052, 16345, 1757, 82814);
INSERT INTO articulos_propiedades VALUES (83053, 16346, 113, 82815);
INSERT INTO articulos_propiedades VALUES (83054, 16346, 173, 82816);
INSERT INTO articulos_propiedades VALUES (83055, 16346, 100, 82817);
INSERT INTO articulos_propiedades VALUES (83056, 16346, 1757, 82818);
INSERT INTO articulos_propiedades VALUES (83057, 16347, 173, 82819);
INSERT INTO articulos_propiedades VALUES (83058, 16347, 100, 82820);
INSERT INTO articulos_propiedades VALUES (83059, 16347, 1757, 82821);
INSERT INTO articulos_propiedades VALUES (83060, 16347, 114, 82822);
INSERT INTO articulos_propiedades VALUES (83061, 16348, 173, 82823);
INSERT INTO articulos_propiedades VALUES (83062, 16348, 100, 82824);
INSERT INTO articulos_propiedades VALUES (83063, 16348, 2056, 82825);
INSERT INTO articulos_propiedades VALUES (83064, 16348, 1757, 82826);
INSERT INTO articulos_propiedades VALUES (83065, 16349, 173, 82827);
INSERT INTO articulos_propiedades VALUES (83066, 16349, 100, 82828);
INSERT INTO articulos_propiedades VALUES (83067, 16349, 2057, 82829);
INSERT INTO articulos_propiedades VALUES (83068, 16349, 1757, 82830);
INSERT INTO articulos_propiedades VALUES (83069, 16350, 173, 82831);
INSERT INTO articulos_propiedades VALUES (83070, 16350, 100, 82832);
INSERT INTO articulos_propiedades VALUES (83071, 16350, 82680, 82833);
INSERT INTO articulos_propiedades VALUES (83072, 16350, 1757, 82834);
INSERT INTO articulos_propiedades VALUES (83073, 16351, 173, 82835);
INSERT INTO articulos_propiedades VALUES (83074, 16351, 101, 82836);
INSERT INTO articulos_propiedades VALUES (83075, 16351, 104, 82837);
INSERT INTO articulos_propiedades VALUES (83076, 16351, 1757, 82838);
INSERT INTO articulos_propiedades VALUES (83077, 16352, 173, 82839);
INSERT INTO articulos_propiedades VALUES (83078, 16352, 105, 82840);
INSERT INTO articulos_propiedades VALUES (83079, 16352, 101, 82841);
INSERT INTO articulos_propiedades VALUES (83080, 16352, 1757, 82842);
INSERT INTO articulos_propiedades VALUES (83081, 16353, 173, 82843);
INSERT INTO articulos_propiedades VALUES (83082, 16353, 106, 82844);
INSERT INTO articulos_propiedades VALUES (83083, 16353, 101, 82845);
INSERT INTO articulos_propiedades VALUES (83084, 16353, 1757, 82846);
INSERT INTO articulos_propiedades VALUES (83085, 16354, 173, 82847);
INSERT INTO articulos_propiedades VALUES (83086, 16354, 101, 82848);
INSERT INTO articulos_propiedades VALUES (83087, 16354, 1757, 82849);
INSERT INTO articulos_propiedades VALUES (83088, 16354, 107, 82850);
INSERT INTO articulos_propiedades VALUES (83089, 16355, 108, 82851);
INSERT INTO articulos_propiedades VALUES (83090, 16355, 173, 82852);
INSERT INTO articulos_propiedades VALUES (83091, 16355, 101, 82853);
INSERT INTO articulos_propiedades VALUES (83092, 16355, 1757, 82854);
INSERT INTO articulos_propiedades VALUES (83093, 16356, 173, 82855);
INSERT INTO articulos_propiedades VALUES (83094, 16356, 101, 82856);
INSERT INTO articulos_propiedades VALUES (83095, 16356, 109, 82857);
INSERT INTO articulos_propiedades VALUES (83096, 16356, 1757, 82858);
INSERT INTO articulos_propiedades VALUES (83097, 16357, 173, 82859);
INSERT INTO articulos_propiedades VALUES (83098, 16357, 101, 82860);
INSERT INTO articulos_propiedades VALUES (83099, 16357, 1757, 82861);
INSERT INTO articulos_propiedades VALUES (83100, 16357, 110, 82862);
INSERT INTO articulos_propiedades VALUES (83101, 16358, 173, 82863);
INSERT INTO articulos_propiedades VALUES (83102, 16358, 101, 82864);
INSERT INTO articulos_propiedades VALUES (83103, 16358, 1757, 82865);
INSERT INTO articulos_propiedades VALUES (83104, 16358, 111, 82866);
INSERT INTO articulos_propiedades VALUES (83105, 16359, 173, 82867);
INSERT INTO articulos_propiedades VALUES (83106, 16359, 101, 82868);
INSERT INTO articulos_propiedades VALUES (83107, 16359, 112, 82869);
INSERT INTO articulos_propiedades VALUES (83108, 16359, 1757, 82870);
INSERT INTO articulos_propiedades VALUES (83109, 16360, 113, 82871);
INSERT INTO articulos_propiedades VALUES (83110, 16360, 173, 82872);
INSERT INTO articulos_propiedades VALUES (83111, 16360, 101, 82873);
INSERT INTO articulos_propiedades VALUES (83112, 16360, 1757, 82874);
INSERT INTO articulos_propiedades VALUES (83113, 16361, 173, 82875);
INSERT INTO articulos_propiedades VALUES (83114, 16361, 101, 82876);
INSERT INTO articulos_propiedades VALUES (83115, 16361, 1757, 82877);
INSERT INTO articulos_propiedades VALUES (83116, 16361, 114, 82878);
INSERT INTO articulos_propiedades VALUES (83117, 16362, 173, 82879);
INSERT INTO articulos_propiedades VALUES (83118, 16362, 2056, 82880);
INSERT INTO articulos_propiedades VALUES (83119, 16362, 101, 82881);
INSERT INTO articulos_propiedades VALUES (83120, 16362, 1757, 82882);
INSERT INTO articulos_propiedades VALUES (83121, 16363, 173, 82883);
INSERT INTO articulos_propiedades VALUES (83122, 16363, 101, 82884);
INSERT INTO articulos_propiedades VALUES (83123, 16363, 2057, 82885);
INSERT INTO articulos_propiedades VALUES (83124, 16363, 1757, 82886);
INSERT INTO articulos_propiedades VALUES (83125, 16364, 173, 82887);
INSERT INTO articulos_propiedades VALUES (83126, 16364, 101, 82888);
INSERT INTO articulos_propiedades VALUES (83127, 16364, 82680, 82889);
INSERT INTO articulos_propiedades VALUES (83128, 16364, 1757, 82890);
INSERT INTO articulos_propiedades VALUES (83129, 16365, 102, 82891);
INSERT INTO articulos_propiedades VALUES (83130, 16365, 173, 82892);
INSERT INTO articulos_propiedades VALUES (83131, 16365, 104, 82893);
INSERT INTO articulos_propiedades VALUES (83132, 16365, 1757, 82894);
INSERT INTO articulos_propiedades VALUES (83133, 16366, 102, 82895);
INSERT INTO articulos_propiedades VALUES (83134, 16366, 173, 82896);
INSERT INTO articulos_propiedades VALUES (83135, 16366, 105, 82897);
INSERT INTO articulos_propiedades VALUES (83136, 16366, 1757, 82898);
INSERT INTO articulos_propiedades VALUES (83137, 16367, 102, 82899);
INSERT INTO articulos_propiedades VALUES (83138, 16367, 173, 82900);
INSERT INTO articulos_propiedades VALUES (83139, 16367, 106, 82901);
INSERT INTO articulos_propiedades VALUES (83140, 16367, 1757, 82902);
INSERT INTO articulos_propiedades VALUES (83141, 16368, 102, 82903);
INSERT INTO articulos_propiedades VALUES (83142, 16368, 173, 82904);
INSERT INTO articulos_propiedades VALUES (83143, 16368, 1757, 82905);
INSERT INTO articulos_propiedades VALUES (83144, 16368, 107, 82906);
INSERT INTO articulos_propiedades VALUES (83145, 16369, 102, 82907);
INSERT INTO articulos_propiedades VALUES (83146, 16369, 108, 82908);
INSERT INTO articulos_propiedades VALUES (83147, 16369, 173, 82909);
INSERT INTO articulos_propiedades VALUES (83148, 16369, 1757, 82910);
INSERT INTO articulos_propiedades VALUES (83149, 16370, 102, 82911);
INSERT INTO articulos_propiedades VALUES (83150, 16370, 173, 82912);
INSERT INTO articulos_propiedades VALUES (83151, 16370, 109, 82913);
INSERT INTO articulos_propiedades VALUES (83152, 16370, 1757, 82914);
INSERT INTO articulos_propiedades VALUES (83153, 16371, 102, 82915);
INSERT INTO articulos_propiedades VALUES (83154, 16371, 173, 82916);
INSERT INTO articulos_propiedades VALUES (83155, 16371, 1757, 82917);
INSERT INTO articulos_propiedades VALUES (83156, 16371, 110, 82918);
INSERT INTO articulos_propiedades VALUES (83157, 16372, 102, 82919);
INSERT INTO articulos_propiedades VALUES (83158, 16372, 173, 82920);
INSERT INTO articulos_propiedades VALUES (83159, 16372, 1757, 82921);
INSERT INTO articulos_propiedades VALUES (83160, 16372, 111, 82922);
INSERT INTO articulos_propiedades VALUES (83161, 16373, 102, 82923);
INSERT INTO articulos_propiedades VALUES (83162, 16373, 173, 82924);
INSERT INTO articulos_propiedades VALUES (83163, 16373, 112, 82925);
INSERT INTO articulos_propiedades VALUES (83164, 16373, 1757, 82926);
INSERT INTO articulos_propiedades VALUES (83165, 16374, 102, 82927);
INSERT INTO articulos_propiedades VALUES (83166, 16374, 113, 82928);
INSERT INTO articulos_propiedades VALUES (83167, 16374, 173, 82929);
INSERT INTO articulos_propiedades VALUES (83168, 16374, 1757, 82930);
INSERT INTO articulos_propiedades VALUES (83169, 16375, 102, 82931);
INSERT INTO articulos_propiedades VALUES (83170, 16375, 173, 82932);
INSERT INTO articulos_propiedades VALUES (83171, 16375, 1757, 82933);
INSERT INTO articulos_propiedades VALUES (83172, 16375, 114, 82934);
INSERT INTO articulos_propiedades VALUES (83173, 16376, 102, 82935);
INSERT INTO articulos_propiedades VALUES (83174, 16376, 173, 82936);
INSERT INTO articulos_propiedades VALUES (83175, 16376, 2056, 82937);
INSERT INTO articulos_propiedades VALUES (83176, 16376, 1757, 82938);
INSERT INTO articulos_propiedades VALUES (83177, 16377, 102, 82939);
INSERT INTO articulos_propiedades VALUES (83178, 16377, 173, 82940);
INSERT INTO articulos_propiedades VALUES (83179, 16377, 2057, 82941);
INSERT INTO articulos_propiedades VALUES (83180, 16377, 1757, 82942);
INSERT INTO articulos_propiedades VALUES (83181, 16378, 102, 82943);
INSERT INTO articulos_propiedades VALUES (83182, 16378, 173, 82944);
INSERT INTO articulos_propiedades VALUES (83183, 16378, 82680, 82945);
INSERT INTO articulos_propiedades VALUES (83184, 16378, 1757, 82946);
INSERT INTO articulos_propiedades VALUES (83185, 16379, 173, 82947);
INSERT INTO articulos_propiedades VALUES (83186, 16379, 104, 82948);
INSERT INTO articulos_propiedades VALUES (83187, 16379, 1757, 82949);
INSERT INTO articulos_propiedades VALUES (83188, 16379, 103, 82950);
INSERT INTO articulos_propiedades VALUES (83189, 16380, 173, 82951);
INSERT INTO articulos_propiedades VALUES (83190, 16380, 105, 82952);
INSERT INTO articulos_propiedades VALUES (83191, 16380, 1757, 82953);
INSERT INTO articulos_propiedades VALUES (83192, 16380, 103, 82954);
INSERT INTO articulos_propiedades VALUES (83193, 16381, 173, 82955);
INSERT INTO articulos_propiedades VALUES (83194, 16381, 106, 82956);
INSERT INTO articulos_propiedades VALUES (83195, 16381, 1757, 82957);
INSERT INTO articulos_propiedades VALUES (83196, 16381, 103, 82958);
INSERT INTO articulos_propiedades VALUES (83197, 16382, 173, 82959);
INSERT INTO articulos_propiedades VALUES (83198, 16382, 1757, 82960);
INSERT INTO articulos_propiedades VALUES (83199, 16382, 103, 82961);
INSERT INTO articulos_propiedades VALUES (83200, 16382, 107, 82962);
INSERT INTO articulos_propiedades VALUES (83201, 16383, 108, 82963);
INSERT INTO articulos_propiedades VALUES (83202, 16383, 173, 82964);
INSERT INTO articulos_propiedades VALUES (83203, 16383, 1757, 82965);
INSERT INTO articulos_propiedades VALUES (83204, 16383, 103, 82966);
INSERT INTO articulos_propiedades VALUES (83205, 16384, 173, 82967);
INSERT INTO articulos_propiedades VALUES (83206, 16384, 109, 82968);
INSERT INTO articulos_propiedades VALUES (83207, 16384, 1757, 82969);
INSERT INTO articulos_propiedades VALUES (83208, 16384, 103, 82970);
INSERT INTO articulos_propiedades VALUES (83209, 16385, 173, 82971);
INSERT INTO articulos_propiedades VALUES (83210, 16385, 1757, 82972);
INSERT INTO articulos_propiedades VALUES (83211, 16385, 103, 82973);
INSERT INTO articulos_propiedades VALUES (83212, 16385, 110, 82974);
INSERT INTO articulos_propiedades VALUES (83213, 16386, 173, 82975);
INSERT INTO articulos_propiedades VALUES (83214, 16386, 1757, 82976);
INSERT INTO articulos_propiedades VALUES (83215, 16386, 103, 82977);
INSERT INTO articulos_propiedades VALUES (83216, 16386, 111, 82978);
INSERT INTO articulos_propiedades VALUES (83217, 16387, 173, 82979);
INSERT INTO articulos_propiedades VALUES (83218, 16387, 112, 82980);
INSERT INTO articulos_propiedades VALUES (83219, 16387, 1757, 82981);
INSERT INTO articulos_propiedades VALUES (83220, 16387, 103, 82982);
INSERT INTO articulos_propiedades VALUES (83221, 16388, 113, 82983);
INSERT INTO articulos_propiedades VALUES (83222, 16388, 173, 82984);
INSERT INTO articulos_propiedades VALUES (83223, 16388, 1757, 82985);
INSERT INTO articulos_propiedades VALUES (83224, 16388, 103, 82986);
INSERT INTO articulos_propiedades VALUES (83225, 16389, 173, 82987);
INSERT INTO articulos_propiedades VALUES (83226, 16389, 1757, 82988);
INSERT INTO articulos_propiedades VALUES (83227, 16389, 103, 82989);
INSERT INTO articulos_propiedades VALUES (83228, 16389, 114, 82990);
INSERT INTO articulos_propiedades VALUES (83229, 16390, 173, 82991);
INSERT INTO articulos_propiedades VALUES (83230, 16390, 2056, 82992);
INSERT INTO articulos_propiedades VALUES (83231, 16390, 1757, 82993);
INSERT INTO articulos_propiedades VALUES (83232, 16390, 103, 82994);
INSERT INTO articulos_propiedades VALUES (83233, 16391, 173, 82995);
INSERT INTO articulos_propiedades VALUES (83234, 16391, 2057, 82996);
INSERT INTO articulos_propiedades VALUES (83235, 16391, 1757, 82997);
INSERT INTO articulos_propiedades VALUES (83236, 16391, 103, 82998);
INSERT INTO articulos_propiedades VALUES (83237, 16392, 173, 82999);
INSERT INTO articulos_propiedades VALUES (83238, 16392, 82680, 83000);
INSERT INTO articulos_propiedades VALUES (83239, 16392, 1757, 83001);
INSERT INTO articulos_propiedades VALUES (83240, 16392, 103, 83002);


--
-- TOC entry 2503 (class 0 OID 0)
-- Dependencies: 194
-- Name: articulos_propiedades_orden_seq; Type: SEQUENCE SET; Schema: public; Owner: stg
--

SELECT pg_catalog.setval('articulos_propiedades_orden_seq', 83002, true);


--
-- TOC entry 2429 (class 0 OID 344217)
-- Dependencies: 208
-- Data for Name: cuentas; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO cuentas VALUES (1, '000000000', 'CUENTA POR DEFECTO');


--
-- TOC entry 2504 (class 0 OID 0)
-- Dependencies: 207
-- Name: cuentas_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('cuentas_id_seq', 1, true);


--
-- TOC entry 2447 (class 0 OID 345309)
-- Dependencies: 226
-- Data for Name: dircalles; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- TOC entry 2505 (class 0 OID 0)
-- Dependencies: 225
-- Name: dircalles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('dircalles_id_seq', 1, false);


--
-- TOC entry 2435 (class 0 OID 345211)
-- Dependencies: 214
-- Data for Name: dircomunidades; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- TOC entry 2506 (class 0 OID 0)
-- Dependencies: 213
-- Name: dircomunidades_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('dircomunidades_id_seq', 1, false);


--
-- TOC entry 2453 (class 0 OID 345345)
-- Dependencies: 232
-- Data for Name: direcciones; Type: TABLE DATA; Schema: public; Owner: stg
--



--
-- TOC entry 2507 (class 0 OID 0)
-- Dependencies: 231
-- Name: direcciones_id_seq; Type: SEQUENCE SET; Schema: public; Owner: stg
--

SELECT pg_catalog.setval('direcciones_id_seq', 1, false);


--
-- TOC entry 2451 (class 0 OID 345334)
-- Dependencies: 230
-- Data for Name: direcciones_tipos; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO direcciones_tipos VALUES (0, 'SEDE FISCAL', true, false, false);
INSERT INTO direcciones_tipos VALUES (1, 'SEDE ENVÍO FACTURAS', false, false, false);
INSERT INTO direcciones_tipos VALUES (2, 'SEDE ENVÍO MERCANCÍA', false, true, false);
INSERT INTO direcciones_tipos VALUES (3, 'SEDE TIENDA', false, true, false);
INSERT INTO direcciones_tipos VALUES (4, 'SEDE NIMA', false, true, true);
INSERT INTO direcciones_tipos VALUES (5, 'SEDE OFICINA', false, true, true);
INSERT INTO direcciones_tipos VALUES (6, 'SEDE ALMACEN', false, true, true);


--
-- TOC entry 2508 (class 0 OID 0)
-- Dependencies: 229
-- Name: direcciones_tipos_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('direcciones_tipos_id_seq', 5, true);


--
-- TOC entry 2455 (class 0 OID 345371)
-- Dependencies: 234
-- Data for Name: direcciones_tipos_links; Type: TABLE DATA; Schema: public; Owner: stg
--



--
-- TOC entry 2509 (class 0 OID 0)
-- Dependencies: 233
-- Name: direcciones_tipos_links_id_seq; Type: SEQUENCE SET; Schema: public; Owner: stg
--

SELECT pg_catalog.setval('direcciones_tipos_links_id_seq', 1, false);


--
-- TOC entry 2449 (class 0 OID 345325)
-- Dependencies: 228
-- Data for Name: dirinfocomplementarias; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO dirinfocomplementarias VALUES (1, 'CALLE');
INSERT INTO dirinfocomplementarias VALUES (2, 'POLIGONO');
INSERT INTO dirinfocomplementarias VALUES (3, 'POLIGONO INDUSTRIAL');
INSERT INTO dirinfocomplementarias VALUES (4, 'CARRETERA');
INSERT INTO dirinfocomplementarias VALUES (5, 'BARRANCO');
INSERT INTO dirinfocomplementarias VALUES (6, 'EDIFICIO');
INSERT INTO dirinfocomplementarias VALUES (7, 'BARRIO');
INSERT INTO dirinfocomplementarias VALUES (8, 'AVENIDA');
INSERT INTO dirinfocomplementarias VALUES (9, 'BAJADA');
INSERT INTO dirinfocomplementarias VALUES (10, 'ALDEA');
INSERT INTO dirinfocomplementarias VALUES (11, 'PARROQUIA');
INSERT INTO dirinfocomplementarias VALUES (12, 'PROLONGACION');
INSERT INTO dirinfocomplementarias VALUES (13, 'PLAZA');
INSERT INTO dirinfocomplementarias VALUES (14, 'GLORIETA');
INSERT INTO dirinfocomplementarias VALUES (15, 'ALAMEDA');
INSERT INTO dirinfocomplementarias VALUES (16, 'MERCADO');
INSERT INTO dirinfocomplementarias VALUES (17, 'CENTRO COMERCIAL');
INSERT INTO dirinfocomplementarias VALUES (18, 'RAMBLA');
INSERT INTO dirinfocomplementarias VALUES (19, 'PASEO');
INSERT INTO dirinfocomplementarias VALUES (20, 'PASAJE');


--
-- TOC entry 2510 (class 0 OID 0)
-- Dependencies: 227
-- Name: dirinfocomplementarias_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('dirinfocomplementarias_id_seq', 20, true);


--
-- TOC entry 2439 (class 0 OID 345248)
-- Dependencies: 218
-- Data for Name: dirislas; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- TOC entry 2511 (class 0 OID 0)
-- Dependencies: 217
-- Name: dirislas_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('dirislas_id_seq', 1, false);


--
-- TOC entry 2441 (class 0 OID 345263)
-- Dependencies: 220
-- Data for Name: dirlocalidades; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- TOC entry 2512 (class 0 OID 0)
-- Dependencies: 219
-- Name: dirlocalidades_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('dirlocalidades_id_seq', 1, false);


--
-- TOC entry 2443 (class 0 OID 345273)
-- Dependencies: 222
-- Data for Name: dirmunicipios; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- TOC entry 2513 (class 0 OID 0)
-- Dependencies: 221
-- Name: dirmunicipios_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('dirmunicipios_id_seq', 1, false);


--
-- TOC entry 2445 (class 0 OID 345294)
-- Dependencies: 224
-- Data for Name: dirmunicipioscp; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- TOC entry 2514 (class 0 OID 0)
-- Dependencies: 223
-- Name: dirmunicipioscp_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('dirmunicipioscp_id_seq', 1, false);


--
-- TOC entry 2433 (class 0 OID 345202)
-- Dependencies: 212
-- Data for Name: dirpaises; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- TOC entry 2515 (class 0 OID 0)
-- Dependencies: 211
-- Name: dirpaises_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('dirpaises_id_seq', 1, false);


--
-- TOC entry 2437 (class 0 OID 345226)
-- Dependencies: 216
-- Data for Name: dirprovincias; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- TOC entry 2516 (class 0 OID 0)
-- Dependencies: 215
-- Name: dirprovincias_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('dirprovincias_id_seq', 1, false);


--
-- TOC entry 2427 (class 0 OID 344113)
-- Dependencies: 206
-- Data for Name: entidades; Type: TABLE DATA; Schema: public; Owner: stg
--

INSERT INTO entidades VALUES (1, 'SUAREZ Y MORALES REPRESENTACIONES, S.L', 'SYM', 'B35386630      ', 6, true, NULL, 0);
INSERT INTO entidades VALUES (2, 'DIMOLAX CANARIAS, S.L', 'DIMOLAX CANARIAS, S.L', 'B35386631      ', 6, true, NULL, 0);
INSERT INTO entidades VALUES (3, 'GUAYASEN GONZALEZ SANTIAGO', 'GUAYASEN GONZALEZ SANTIAGO', '44715918P      ', 1, false, '          ', NULL);


--
-- TOC entry 2431 (class 0 OID 344254)
-- Dependencies: 210
-- Data for Name: entidades_gruposventas; Type: TABLE DATA; Schema: public; Owner: stg
--



--
-- TOC entry 2517 (class 0 OID 0)
-- Dependencies: 209
-- Name: entidades_gruposventas_id_seq; Type: SEQUENCE SET; Schema: public; Owner: stg
--

SELECT pg_catalog.setval('entidades_gruposventas_id_seq', 1, false);


--
-- TOC entry 2518 (class 0 OID 0)
-- Dependencies: 205
-- Name: entidades_id_seq; Type: SEQUENCE SET; Schema: public; Owner: stg
--

SELECT pg_catalog.setval('entidades_id_seq', 2, true);


--
-- TOC entry 2459 (class 0 OID 368767)
-- Dependencies: 238
-- Data for Name: entidades_links; Type: TABLE DATA; Schema: public; Owner: stg
--

INSERT INTO entidades_links VALUES (1, 3, 1, 'emp-001', 1, 2, NULL);
INSERT INTO entidades_links VALUES (2, 3, 2, 'emp-002', 1, 2, NULL);


--
-- TOC entry 2457 (class 0 OID 368686)
-- Dependencies: 236
-- Data for Name: entidades_links_cargos; Type: TABLE DATA; Schema: public; Owner: stg
--

INSERT INTO entidades_links_cargos VALUES (1, 1, 'DIRECTOR COMERCIAL');
INSERT INTO entidades_links_cargos VALUES (2, 1, 'INFORMATICO');
INSERT INTO entidades_links_cargos VALUES (3, 1, 'CONTABLE');
INSERT INTO entidades_links_cargos VALUES (4, 1, 'MOZO DE ALMACÉN');


--
-- TOC entry 2519 (class 0 OID 0)
-- Dependencies: 235
-- Name: entidades_links_cargos_id_seq; Type: SEQUENCE SET; Schema: public; Owner: stg
--

SELECT pg_catalog.setval('entidades_links_cargos_id_seq', 1, false);


--
-- TOC entry 2520 (class 0 OID 0)
-- Dependencies: 237
-- Name: entidades_links_id_seq; Type: SEQUENCE SET; Schema: public; Owner: stg
--

SELECT pg_catalog.setval('entidades_links_id_seq', 1, false);


--
-- TOC entry 2423 (class 0 OID 344094)
-- Dependencies: 202
-- Data for Name: entidades_links_tipos; Type: TABLE DATA; Schema: public; Owner: stg
--

INSERT INTO entidades_links_tipos VALUES (1, 'ES EMPLEADO DE', 'EMPLEADOS');
INSERT INTO entidades_links_tipos VALUES (2, 'ES CLIENTE AL MAYOR (VENDEDOR) DE', 'CLIENTES AL MAYOR (VENDEDORES)');
INSERT INTO entidades_links_tipos VALUES (3, 'ES CLIENTE AL MAYOR (CONSUMIDOR FINAL) DE', 'CLIENTES AL MAYOR (CONSUMIDORES FINALES)');
INSERT INTO entidades_links_tipos VALUES (4, 'ES CLIENTE AL MENOR DE', 'CLIENTES AL MENOR');
INSERT INTO entidades_links_tipos VALUES (5, 'ES REPRESENTANTE DE', 'REPRESENTANTES');
INSERT INTO entidades_links_tipos VALUES (6, 'ES ACREEDOR DE', 'ACREEDORES');
INSERT INTO entidades_links_tipos VALUES (7, 'ES COMERCIAL DE', 'COMERCIALES');
INSERT INTO entidades_links_tipos VALUES (8, 'ES COMERCIAL DE', 'COMERCIALES');
INSERT INTO entidades_links_tipos VALUES (9, 'ES REPRESENTANTE/AGENTE CUENTA PROPIA DE', 'REPRESENTANTES/AGENTES POR CUENTA PROPIA');
INSERT INTO entidades_links_tipos VALUES (10, 'ES REPRESENTANTE/AGENTE CUENTA AJENA (SUBAGENTE) DE', 'REPRESENTANTES/AGENTES POR CUENTA AJENA (SUBAGENTE)');


--
-- TOC entry 2521 (class 0 OID 0)
-- Dependencies: 201
-- Name: entidades_links_tipos_id_seq; Type: SEQUENCE SET; Schema: public; Owner: stg
--

SELECT pg_catalog.setval('entidades_links_tipos_id_seq', 10, true);


--
-- TOC entry 2425 (class 0 OID 344102)
-- Dependencies: 204
-- Data for Name: entidades_tipos; Type: TABLE DATA; Schema: public; Owner: stg
--

INSERT INTO entidades_tipos VALUES (1, 'FISICA              ', 'PERSONA FISICA', 'PF        ');
INSERT INTO entidades_tipos VALUES (2, 'FISICA              ', 'EMPRESARIO INDIVIDUAL', 'EI        ');
INSERT INTO entidades_tipos VALUES (3, 'FISICA              ', 'COMUNIDAD DE BIENES', 'CB        ');
INSERT INTO entidades_tipos VALUES (4, 'FISICA              ', 'SOCIEDAD CIVIL', 'SCI       ');
INSERT INTO entidades_tipos VALUES (5, 'JURIDICA            ', 'SOCIEDADES MERCANTILES -> SOCIEDAD COLECTIVA', 'SCO       ');
INSERT INTO entidades_tipos VALUES (6, 'JURIDICA            ', 'SOCIEDADES MERCANTILES -> SOCIEDAD RESPONSABILIDAD LIMITADA', 'SL        ');
INSERT INTO entidades_tipos VALUES (7, 'JURIDICA            ', 'SOCIEDADES MERCANTILES -> SOCIEDAD LIITADA NUEVA EMPRESA', 'SLNE      ');
INSERT INTO entidades_tipos VALUES (8, 'JURIDICA            ', 'SOCIEDADES MERCANTILES -> SOCIEDAD ANONIMA', 'SA        ');
INSERT INTO entidades_tipos VALUES (9, 'JURIDICA            ', 'SOCIEDADES MERCANTILES -> SOCIEDAD COMANDITARIA POR ACCIONES', 'SCA       ');
INSERT INTO entidades_tipos VALUES (10, 'JURIDICA            ', 'SOCIEDADES MERCANTILES -> SOCIEDAD COMANDITARIA SIMPLE', 'SCS       ');
INSERT INTO entidades_tipos VALUES (11, 'JURIDICA            ', 'SOCIEDADES MERCANTILES ESPECIALES -> SOCIEDAD LABORAL 1', 'SAL       ');
INSERT INTO entidades_tipos VALUES (12, 'JURIDICA            ', 'SOCIEDADES MERCANTILES ESPECIALES -> SOCIEDAD LABORAL 2', 'SLL       ');
INSERT INTO entidades_tipos VALUES (13, 'JURIDICA            ', 'SOCIEDADES MERCANTILES ESPECIALES -> SOCIEDAD COOPERATIVA', 'COOP      ');
INSERT INTO entidades_tipos VALUES (14, 'JURIDICA            ', 'SOCIEDADES MERCANTILES ESPECIALES -> AGRUPACION DE INTERES ECONOMICO', 'AIE       ');
INSERT INTO entidades_tipos VALUES (15, 'JURIDICA            ', 'SOCIEDADES MERCANTILES ESPECIALES -> SOCIEDAD DE INVERSION MOBILIARIA', 'SIM       ');


--
-- TOC entry 2522 (class 0 OID 0)
-- Dependencies: 203
-- Name: entidades_tipos_id_seq; Type: SEQUENCE SET; Schema: public; Owner: stg
--

SELECT pg_catalog.setval('entidades_tipos_id_seq', 1, false);


--
-- TOC entry 2410 (class 0 OID 303149)
-- Dependencies: 188
-- Data for Name: familias; Type: TABLE DATA; Schema: public; Owner: stg
--

INSERT INTO familias VALUES (35, 3, '3', 'Topper', 1, true, false, 28);
INSERT INTO familias VALUES (31, 3, '0', 'Acabado', 1, true, false, 24);
INSERT INTO familias VALUES (34, 3, '2', 'Almohada', 1, true, false, 27);
INSERT INTO familias VALUES (32, 3, '4', 'Cabecero', 1, true, false, 25);
INSERT INTO familias VALUES (33, 3, '1', 'Pata', 1, true, false, 26);
INSERT INTO familias VALUES (27, 2, '7', 'Cama eléctrica', 1, true, false, 23);
INSERT INTO familias VALUES (25, 2, '5', 'Box Springs', 1, true, false, 21);
INSERT INTO familias VALUES (23, 2, '3', 'Abatible', 1, true, false, 19);
INSERT INTO familias VALUES (22, 2, '2', 'Canapé', 1, true, false, 18);
INSERT INTO familias VALUES (24, 2, '4', 'Mixto', 1, true, false, 20);
INSERT INTO familias VALUES (26, 2, '6', 'Nido', 1, true, false, 22);
INSERT INTO familias VALUES (21, 2, '1', 'Tapi', 1, true, false, 17);
INSERT INTO familias VALUES (83, 8, '3', 'Muestrario', 4, true, false, 31);
INSERT INTO familias VALUES (17, 12, '1', 'Espuma 1 capa', 2, true, false, 14);
INSERT INTO familias VALUES (18, 12, '2', 'Espuma 2 capas', 4, true, false, 15);
INSERT INTO familias VALUES (19, 12, '3', 'Espuma 3 capas', 4, true, false, 16);
INSERT INTO familias VALUES (1, NULL, '1', 'Colchón', 6, true, false, 1);
INSERT INTO familias VALUES (2, NULL, '2', 'Base', 6, true, false, 2);
INSERT INTO familias VALUES (3, NULL, '3', 'Complementos', 1, true, false, 3);
INSERT INTO familias VALUES (82, 8, '2', 'Tarifa', 4, true, false, 30);
INSERT INTO familias VALUES (81, 8, '1', 'Catálogo', 4, true, false, 29);
INSERT INTO familias VALUES (92, 9, '0', 'Comisión', 4, true, false, 34);
INSERT INTO familias VALUES (4201, NULL, '0', 'Materias primas', 1, true, false, 167);
INSERT INTO familias VALUES (4, NULL, '4', 'Textil', 1, true, false, 4);
INSERT INTO familias VALUES (4202, NULL, '5', 'Tapicerías', 1, true, false, 168);
INSERT INTO familias VALUES (4203, NULL, '6', 'Muebles', 1, true, false, 169);
INSERT INTO familias VALUES (7, NULL, '7', 'Repuestos', 1, true, false, 5);
INSERT INTO familias VALUES (8, NULL, '8', 'Marketing', 1, true, false, 6);
INSERT INTO familias VALUES (9, NULL, '9', 'Servicios', 1, true, false, 7);
INSERT INTO familias VALUES (96, 9, '3', 'Incidencia', 4, true, false, 38);
INSERT INTO familias VALUES (91, 9, '1', 'Visita personal', 4, true, false, 33);
INSERT INTO familias VALUES (11, 1, '1', 'Muelle', 1, true, true, 8);
INSERT INTO familias VALUES (12, 1, '2', 'No muelle', 1, true, true, 9);
INSERT INTO familias VALUES (13, 11, '2', 'Semicilíndrico', 1, true, false, 10);
INSERT INTO familias VALUES (14, 11, '1', 'Cilíndrico', 1, true, false, 11);
INSERT INTO familias VALUES (15, 11, '3', 'Compactado', 1, true, false, 12);
INSERT INTO familias VALUES (16, 11, '4', 'Ensacado', 1, true, false, 13);
INSERT INTO familias VALUES (1203, 11, '5', 'Infinito', 6, true, false, 121);
INSERT INTO familias VALUES (93, 9, '2', 'Logística', 4, true, false, 35);
INSERT INTO familias VALUES (4204, 93, '1', 'Transporte', 1, true, false, 170);
INSERT INTO familias VALUES (4205, 93, '2', 'Disrtibución', 1, true, false, 171);
INSERT INTO familias VALUES (4206, 93, '3', 'Montaje', 1, true, false, 172);
INSERT INTO familias VALUES (4207, 4204, '1', 'Mayorista almacén', 1, true, false, 173);
INSERT INTO familias VALUES (4208, 4204, '2', 'Mayorista consumidor', 1, true, false, 174);
INSERT INTO familias VALUES (4209, 4204, '3', 'Consumidor', 1, true, false, 175);
INSERT INTO familias VALUES (84, 8, '4', 'PLV', 4, true, false, 32);


--
-- TOC entry 2523 (class 0 OID 0)
-- Dependencies: 186
-- Name: familias_id_seq; Type: SEQUENCE SET; Schema: public; Owner: stg
--

SELECT pg_catalog.setval('familias_id_seq', 83240, true);


--
-- TOC entry 2524 (class 0 OID 0)
-- Dependencies: 187
-- Name: familias_orden_seq; Type: SEQUENCE SET; Schema: public; Owner: stg
--

SELECT pg_catalog.setval('familias_orden_seq', 180, true);


--
-- TOC entry 2413 (class 0 OID 303202)
-- Dependencies: 191
-- Data for Name: familias_propiedades; Type: TABLE DATA; Schema: public; Owner: stg
--

INSERT INTO familias_propiedades VALUES (106, '100', 1, 2, '100', 116, '');
INSERT INTO familias_propiedades VALUES (107, '105', 1, 2, '105', 116, '');
INSERT INTO familias_propiedades VALUES (171, '171', 16, 23, 'Iria', 113, '');
INSERT INTO familias_propiedades VALUES (172, '172', 16, 23, 'Colliseum', 114, '');
INSERT INTO familias_propiedades VALUES (175, '175', 16, 23, 'Cies', 117, '');
INSERT INTO familias_propiedades VALUES (176, '176', 15, 23, 'Tambre', 118, '');
INSERT INTO familias_propiedades VALUES (177, '177', 13, 23, 'Alfa', 119, '');
INSERT INTO familias_propiedades VALUES (178, '178', 14, 23, 'Granada', 120, '');
INSERT INTO familias_propiedades VALUES (2056, '110', 1, 2, '110', 116, '');
INSERT INTO familias_propiedades VALUES (2057, '115', 1, 2, '115', 116, '');
INSERT INTO familias_propiedades VALUES (108, '120', 1, 2, '120', 116, '');
INSERT INTO familias_propiedades VALUES (109, '135', 1, 2, '135', 116, '');
INSERT INTO familias_propiedades VALUES (110, '140', 1, 2, '140', 116, '');
INSERT INTO familias_propiedades VALUES (111, '150', 1, 2, '150', 116, '');
INSERT INTO familias_propiedades VALUES (112, '160', 1, 2, '160', 116, '');
INSERT INTO familias_propiedades VALUES (113, '180', 1, 2, '180', 116, '');
INSERT INTO familias_propiedades VALUES (114, '200', 1, 2, '200', 116, '');
INSERT INTO familias_propiedades VALUES (173, '173', 17, 23, 'Canarias', 41, '');
INSERT INTO familias_propiedades VALUES (99, '1', 1, 1, '182', 127, 'x');
INSERT INTO familias_propiedades VALUES (100, '2', 1, 1, '190', 127, 'x');
INSERT INTO familias_propiedades VALUES (101, '3', 1, 1, '200', 127, 'x');
INSERT INTO familias_propiedades VALUES (102, '4', 1, 1, '210', 127, 'x');
INSERT INTO familias_propiedades VALUES (103, '5', 1, 1, '220', 127, 'x');
INSERT INTO familias_propiedades VALUES (1785, '0', 1, 3, '0', 165, 'x');
INSERT INTO familias_propiedades VALUES (1749, '15', 1, 3, '15', 165, 'x');
INSERT INTO familias_propiedades VALUES (1750, '16', 1, 3, '16', 165, 'x');
INSERT INTO familias_propiedades VALUES (1751, '17', 1, 3, '17', 165, 'x');
INSERT INTO familias_propiedades VALUES (1752, '18', 1, 3, '18', 165, 'x');
INSERT INTO familias_propiedades VALUES (1753, '19', 1, 3, '19', 165, 'x');
INSERT INTO familias_propiedades VALUES (1754, '20', 1, 3, '20', 165, 'x');
INSERT INTO familias_propiedades VALUES (1755, '21', 1, 3, '21', 165, 'x');
INSERT INTO familias_propiedades VALUES (1756, '22', 1, 3, '22', 165, 'x');
INSERT INTO familias_propiedades VALUES (1757, '23', 1, 3, '23', 165, 'x');
INSERT INTO familias_propiedades VALUES (1759, '24', 1, 3, '24', 165, 'x');
INSERT INTO familias_propiedades VALUES (1760, '25', 1, 3, '25', 165, 'x');
INSERT INTO familias_propiedades VALUES (1761, '26', 1, 3, '26', 165, 'x');
INSERT INTO familias_propiedades VALUES (1762, '27', 1, 3, '27', 165, 'x');
INSERT INTO familias_propiedades VALUES (1763, '28', 1, 3, '28', 165, 'x');
INSERT INTO familias_propiedades VALUES (1764, '190', 1, 3, '29', 165, 'x');
INSERT INTO familias_propiedades VALUES (1765, '30', 1, 3, '30', 165, 'x');
INSERT INTO familias_propiedades VALUES (1766, '31', 1, 3, '31', 165, 'x');
INSERT INTO familias_propiedades VALUES (1767, '32', 1, 3, '32', 165, 'x');
INSERT INTO familias_propiedades VALUES (1768, '33', 1, 3, '33', 165, 'x');
INSERT INTO familias_propiedades VALUES (1769, '34', 1, 3, '34', 165, 'x');
INSERT INTO familias_propiedades VALUES (1770, '35', 1, 3, '35', 165, 'x');
INSERT INTO familias_propiedades VALUES (1771, '36', 1, 3, '36', 165, 'x');
INSERT INTO familias_propiedades VALUES (1772, '198', 1, 3, '37', 165, 'x');
INSERT INTO familias_propiedades VALUES (1773, '199', 1, 3, '38', 165, 'x');
INSERT INTO familias_propiedades VALUES (1774, '200', 1, 3, '39', 165, 'x');
INSERT INTO familias_propiedades VALUES (1775, '201', 1, 3, '40', 165, 'x');
INSERT INTO familias_propiedades VALUES (82680, '060', 1, 2, '60', 180, '');
INSERT INTO familias_propiedades VALUES (104, '080', 1, 2, '80', 116, '');
INSERT INTO familias_propiedades VALUES (105, '090', 1, 2, '90', 116, '');


--
-- TOC entry 2419 (class 0 OID 303385)
-- Dependencies: 198
-- Data for Name: familias_valoresligados; Type: TABLE DATA; Schema: public; Owner: stg
--

INSERT INTO familias_valoresligados VALUES (151, 173, 1757);


--
-- TOC entry 2525 (class 0 OID 0)
-- Dependencies: 197
-- Name: familias_valoresligados_id_seq; Type: SEQUENCE SET; Schema: public; Owner: stg
--

SELECT pg_catalog.setval('familias_valoresligados_id_seq', 151, true);


--
-- TOC entry 2421 (class 0 OID 344086)
-- Dependencies: 200
-- Data for Name: gruposventas; Type: TABLE DATA; Schema: public; Owner: stg
--

INSERT INTO gruposventas VALUES (0, 'GEN', 'GENÉRICO');
INSERT INTO gruposventas VALUES (1, 'HIP', 'HIPERCOR');
INSERT INTO gruposventas VALUES (2, 'ECI', 'EL CORTE INGLES');
INSERT INTO gruposventas VALUES (3, 'MKM', 'MERKAMUEBLES');


--
-- TOC entry 2526 (class 0 OID 0)
-- Dependencies: 199
-- Name: gruposventas_id_seq; Type: SEQUENCE SET; Schema: public; Owner: stg
--

SELECT pg_catalog.setval('gruposventas_id_seq', 3, true);


--
-- TOC entry 2403 (class 0 OID 270405)
-- Dependencies: 181
-- Data for Name: impuestos; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO impuestos VALUES (0, 0.00, '0% IGIC EXENTO ', 'EXENTO      ', NULL);
INSERT INTO impuestos VALUES (1, 7.00, '7% IGIC        ', 'IGIC        ', NULL);


--
-- TOC entry 2527 (class 0 OID 0)
-- Dependencies: 180
-- Name: impuestos_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('impuestos_id_seq', 1, false);


--
-- TOC entry 2396 (class 0 OID 90120)
-- Dependencies: 173
-- Data for Name: menus; Type: TABLE DATA; Schema: public; Owner: stg
--

INSERT INTO menus VALUES (1, NULL, 'Oficina', 'Area de Oficina', NULL, NULL, '');
INSERT INTO menus VALUES (2, NULL, 'Produccion', 'Area de Produccion', NULL, NULL, '');
INSERT INTO menus VALUES (3, NULL, 'Comercial', 'Area Comercial', NULL, NULL, '');
INSERT INTO menus VALUES (4, NULL, 'Maestros comunes', 'Elementos básicos comunes, o que afectan a más de un area anterior', NULL, NULL, '');
INSERT INTO menus VALUES (5, 4, 'Relacion entre sociedades', 'Definición de los posibles vínculos de una sociedad con otra (Proveedor De, cliente De...)', NULL, NULL, '');
INSERT INTO menus VALUES (6, 4, 'Tipos de sociedades', 'Tipo de personalidad, y forma juridica', NULL, NULL, '');
INSERT INTO menus VALUES (7, 4, 'Sociedades', 'Sociedades/personas con las que nos relacionamos', NULL, NULL, '');
INSERT INTO menus VALUES (9, 2, 'Productos', 'Todo lo relacionado con la gestion del catalogo (articulos, almacenes)', 'productos-open.png', 'productos-closed.png', '');
INSERT INTO menus VALUES (10, 9, 'Familias de los articulos', 'Gestión de las diferentes familias que categorizan a los articulos', 'familias-open.png', 'familias-closed.png', '');
INSERT INTO menus VALUES (11, 9, 'Propiedades de los articulos', 'Definicion de las propiedades que definen la naturaleza de los articulos y familias', 'propiedades-open.PNG', 'propiedades-closed.PNG', 'Mod_propiedades');
INSERT INTO menus VALUES (12, 9, 'Catálogos de propiedad', 'Definicion de conjunto de propiedades con sus valores preconfigurados', 'catalogos-propiedades-open.png', 'catalogos-propiedades-closed.png', '');
INSERT INTO menus VALUES (13, 9, 'Artículos', 'Gestion de los diferentes articulos', 'articulos-open.png', 'articulos-closed.png', '');


--
-- TOC entry 2528 (class 0 OID 0)
-- Dependencies: 172
-- Name: menus_id_seq; Type: SEQUENCE SET; Schema: public; Owner: stg
--

SELECT pg_catalog.setval('menus_id_seq', 13, true);


--
-- TOC entry 2412 (class 0 OID 303174)
-- Dependencies: 190
-- Data for Name: propiedades; Type: TABLE DATA; Schema: public; Owner: stg
--

INSERT INTO propiedades VALUES (19, '', 'Densidad artículo', 'Densidad (kg/m3) artículo', 'Densidad artículo (kg/m3)', true, 1, 1, 1);
INSERT INTO propiedades VALUES (4, '', 'Largo embalaje', 'Dimensión (cm) largo embalaje', 'Largo embalaje (cm)', true, 1, 1, 1);
INSERT INTO propiedades VALUES (5, '', 'Ancho embalaje', 'Dimensión (cm) ancho embalaje', 'Ancho embalaje (cm)', true, 1, 1, 1);
INSERT INTO propiedades VALUES (6, '', 'Alto embalaje', 'Dimensión (cm) alto embalaje', 'Alto embalaje (cm)', true, 1, 1, 1);
INSERT INTO propiedades VALUES (17, '', 'Volumen embalaje', 'Volumen (m3) embalaje', 'Volumen embalaje (m3)', true, 1, 1, 1);
INSERT INTO propiedades VALUES (14, '', 'Masa embalaje', 'Masa (kg) embalaje', 'Masa embalaje (kg)', true, 1, 1, 1);
INSERT INTO propiedades VALUES (24, '', 'Largo transporte', 'Dimensión (cm) largo transporte', 'Largo transporte (cm)', true, 1, 1, 1);
INSERT INTO propiedades VALUES (8, '', 'Ancho transporte', 'Dimensión (cm) ancho transporte', 'Ancho transporte (cm)', true, 1, 1, 1);
INSERT INTO propiedades VALUES (9, '', 'Alto transporte', 'Dimensión (cm) alto transporte', 'Alto transporte (cm)', true, 1, 1, 1);
INSERT INTO propiedades VALUES (18, '', 'Volumen transporte', 'Volumen (m3) transporte', 'Volumen transporte (m3)', true, 1, 1, 1);
INSERT INTO propiedades VALUES (15, '', 'Masa transporte', 'Masa (kg) transporte', 'Masa transporte (kg)', true, 1, 1, 1);
INSERT INTO propiedades VALUES (11, '', 'Medida larga', 'Dimensión (cm) medida larga', 'Medida larga (cm)', false, 1, 6, 6);
INSERT INTO propiedades VALUES (22, '', 'Madera tipo', 'Madera tipo', 'Madera tipo', false, 6, 6, 6);
INSERT INTO propiedades VALUES (21, '', 'Madera acabado', 'Madera acabado', 'Madera acabado', false, 6, 6, 6);
INSERT INTO propiedades VALUES (20, '', 'Tapicería tipo', 'Tapicería tipo', 'Tapicería tipo', false, 6, 6, 6);
INSERT INTO propiedades VALUES (7, '', 'Tapicería tratamiento', 'Tapicería tratamiento', 'Tapicería tratamiento', false, 1, 1, 1);
INSERT INTO propiedades VALUES (12, '', 'Talla', 'Medida -> Talla', 'Talla', false, 1, 1, 1);
INSERT INTO propiedades VALUES (10, '', 'Medida corta', 'Dimensión (cm) medida corta', 'Medida corta (cm)', false, 1, 1, 1);
INSERT INTO propiedades VALUES (2, '', 'Ancho artículo', 'Dimensión (cm) ancho artículo', 'Ancho artículo (cm)', true, 1, 6, 1);
INSERT INTO propiedades VALUES (1, '', 'Largo artículo', 'Dimensión (cm) largo artículo', 'Largo artículo (cm)', true, 1, 6, 1);
INSERT INTO propiedades VALUES (3, '', 'Alto artículo', 'Dimensión (cm) alto artículo', 'Alto artículo (cm)', true, 1, 4, 1);
INSERT INTO propiedades VALUES (23, '', 'Modelo', 'Modelo', 'Modelo', false, 6, 6, 6);
INSERT INTO propiedades VALUES (16, '', 'Volumen artículo', 'Volumen (m3) artículo', 'Volumen artículo (m3)', true, 1, 1, 1);
INSERT INTO propiedades VALUES (13, '', 'Masa artículo', 'Masa (kg) artículo', 'Masa artículo (kg)', true, 1, 1, 1);


--
-- TOC entry 2407 (class 0 OID 303138)
-- Dependencies: 185
-- Data for Name: propiedades_componer; Type: TABLE DATA; Schema: public; Owner: stg
--

INSERT INTO propiedades_componer VALUES (1, 'ninguno', true);
INSERT INTO propiedades_componer VALUES (2, 'cod', true);
INSERT INTO propiedades_componer VALUES (3, 'propiedad', false);
INSERT INTO propiedades_componer VALUES (4, 'valor', true);
INSERT INTO propiedades_componer VALUES (5, 'cod + propiedad', false);
INSERT INTO propiedades_componer VALUES (6, 'cod + valor', true);
INSERT INTO propiedades_componer VALUES (7, 'cod + propiedad + valor', false);
INSERT INTO propiedades_componer VALUES (8, 'propiedad + valor', false);


--
-- TOC entry 2529 (class 0 OID 0)
-- Dependencies: 184
-- Name: propiedades_componer_id_seq; Type: SEQUENCE SET; Schema: public; Owner: stg
--

SELECT pg_catalog.setval('propiedades_componer_id_seq', 8, true);


--
-- TOC entry 2530 (class 0 OID 0)
-- Dependencies: 189
-- Name: propiedades_id_seq; Type: SEQUENCE SET; Schema: public; Owner: stg
--

SELECT pg_catalog.setval('propiedades_id_seq', 25, true);


--
-- TOC entry 2397 (class 0 OID 114694)
-- Dependencies: 175
-- Data for Name: schema_migrations; Type: TABLE DATA; Schema: public; Owner: stg
--

INSERT INTO schema_migrations VALUES ('20150624181202');


--
-- TOC entry 2399 (class 0 OID 270349)
-- Dependencies: 177
-- Data for Name: unidadmedida_categorias; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO unidadmedida_categorias VALUES (0, 'CONTEO');
INSERT INTO unidadmedida_categorias VALUES (1, 'PESO');
INSERT INTO unidadmedida_categorias VALUES (2, 'VOLUMEN/CAPACIDAD');
INSERT INTO unidadmedida_categorias VALUES (3, 'SUPERFICIE');


--
-- TOC entry 2531 (class 0 OID 0)
-- Dependencies: 176
-- Name: unidadmedida_categorias_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('unidadmedida_categorias_id_seq', 3, true);


--
-- TOC entry 2401 (class 0 OID 270357)
-- Dependencies: 179
-- Data for Name: unidadmedidas; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO unidadmedidas VALUES (0, 'UNIDADES', 0, 1);
INSERT INTO unidadmedidas VALUES (1, 'KG', 1, 1);
INSERT INTO unidadmedidas VALUES (2, 'M²', 3, 1);
INSERT INTO unidadmedidas VALUES (3, 'TNM', 1, 1000);
INSERT INTO unidadmedidas VALUES (4, 'L', 2, 1);
INSERT INTO unidadmedidas VALUES (5, 'M³', 2, 1000);


--
-- TOC entry 2532 (class 0 OID 0)
-- Dependencies: 178
-- Name: unidadmedidas_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('unidadmedidas_id_seq', 5, true);


--
-- TOC entry 2150 (class 2606 OID 303135)
-- Name: articulos_lers_pkey; Type: CONSTRAINT; Schema: public; Owner: stg; Tablespace: 
--

ALTER TABLE ONLY articulos_lers
    ADD CONSTRAINT articulos_lers_pkey PRIMARY KEY (id);


--
-- TOC entry 2168 (class 2606 OID 303270)
-- Name: articulos_pkey; Type: CONSTRAINT; Schema: public; Owner: stg; Tablespace: 
--

ALTER TABLE ONLY articulos
    ADD CONSTRAINT articulos_pkey PRIMARY KEY (id);


--
-- TOC entry 2174 (class 2606 OID 303313)
-- Name: articulos_propiedades_pkey; Type: CONSTRAINT; Schema: public; Owner: stg; Tablespace: 
--

ALTER TABLE ONLY articulos_propiedades
    ADD CONSTRAINT articulos_propiedades_pkey PRIMARY KEY (id);


--
-- TOC entry 2196 (class 2606 OID 344222)
-- Name: cuentas_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY cuentas
    ADD CONSTRAINT cuentas_pkey PRIMARY KEY (id);


--
-- TOC entry 2224 (class 2606 OID 345315)
-- Name: dircalles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY dircalles
    ADD CONSTRAINT dircalles_pkey PRIMARY KEY (id);


--
-- TOC entry 2202 (class 2606 OID 345217)
-- Name: dircomunidades_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY dircomunidades
    ADD CONSTRAINT dircomunidades_pkey PRIMARY KEY (id);


--
-- TOC entry 2231 (class 2606 OID 345353)
-- Name: direcciones_pkey; Type: CONSTRAINT; Schema: public; Owner: stg; Tablespace: 
--

ALTER TABLE ONLY direcciones
    ADD CONSTRAINT direcciones_pkey PRIMARY KEY (id);


--
-- TOC entry 2237 (class 2606 OID 345376)
-- Name: direcciones_tipos_links_pkey; Type: CONSTRAINT; Schema: public; Owner: stg; Tablespace: 
--

ALTER TABLE ONLY direcciones_tipos_links
    ADD CONSTRAINT direcciones_tipos_links_pkey PRIMARY KEY (id);


--
-- TOC entry 2229 (class 2606 OID 345342)
-- Name: direcciones_tipos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY direcciones_tipos
    ADD CONSTRAINT direcciones_tipos_pkey PRIMARY KEY (id);


--
-- TOC entry 2227 (class 2606 OID 345331)
-- Name: dirinfocomplementarias_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY dirinfocomplementarias
    ADD CONSTRAINT dirinfocomplementarias_pkey PRIMARY KEY (id);


--
-- TOC entry 2209 (class 2606 OID 345254)
-- Name: dirislas_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY dirislas
    ADD CONSTRAINT dirislas_pkey PRIMARY KEY (id);


--
-- TOC entry 2212 (class 2606 OID 345269)
-- Name: dirlocalidades_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY dirlocalidades
    ADD CONSTRAINT dirlocalidades_pkey PRIMARY KEY (id);


--
-- TOC entry 2216 (class 2606 OID 345279)
-- Name: dirmunicipios_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY dirmunicipios
    ADD CONSTRAINT dirmunicipios_pkey PRIMARY KEY (id);


--
-- TOC entry 2220 (class 2606 OID 345299)
-- Name: dirmunicipioscp_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY dirmunicipioscp
    ADD CONSTRAINT dirmunicipioscp_pkey PRIMARY KEY (id);


--
-- TOC entry 2200 (class 2606 OID 345208)
-- Name: dirpaises_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY dirpaises
    ADD CONSTRAINT dirpaises_pkey PRIMARY KEY (id);


--
-- TOC entry 2205 (class 2606 OID 345233)
-- Name: dirprovincias_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY dirprovincias
    ADD CONSTRAINT dirprovincias_pkey PRIMARY KEY (id);


--
-- TOC entry 2198 (class 2606 OID 344259)
-- Name: entidades_gruposventas_pkey; Type: CONSTRAINT; Schema: public; Owner: stg; Tablespace: 
--

ALTER TABLE ONLY entidades_gruposventas
    ADD CONSTRAINT entidades_gruposventas_pkey PRIMARY KEY (id);


--
-- TOC entry 2239 (class 2606 OID 368691)
-- Name: entidades_links_cargos_pkey; Type: CONSTRAINT; Schema: public; Owner: stg; Tablespace: 
--

ALTER TABLE ONLY entidades_links_cargos
    ADD CONSTRAINT entidades_links_cargos_pkey PRIMARY KEY (id);


--
-- TOC entry 2241 (class 2606 OID 368772)
-- Name: entidades_links_pkey; Type: CONSTRAINT; Schema: public; Owner: stg; Tablespace: 
--

ALTER TABLE ONLY entidades_links
    ADD CONSTRAINT entidades_links_pkey PRIMARY KEY (id);


--
-- TOC entry 2186 (class 2606 OID 344099)
-- Name: entidades_links_tipos_pkey; Type: CONSTRAINT; Schema: public; Owner: stg; Tablespace: 
--

ALTER TABLE ONLY entidades_links_tipos
    ADD CONSTRAINT entidades_links_tipos_pkey PRIMARY KEY (id);


--
-- TOC entry 2192 (class 2606 OID 344120)
-- Name: entidades_pkey; Type: CONSTRAINT; Schema: public; Owner: stg; Tablespace: 
--

ALTER TABLE ONLY entidades
    ADD CONSTRAINT entidades_pkey PRIMARY KEY (id);


--
-- TOC entry 2188 (class 2606 OID 344110)
-- Name: entidades_tipos_iniciales_key; Type: CONSTRAINT; Schema: public; Owner: stg; Tablespace: 
--

ALTER TABLE ONLY entidades_tipos
    ADD CONSTRAINT entidades_tipos_iniciales_key UNIQUE (iniciales);


--
-- TOC entry 2190 (class 2606 OID 344108)
-- Name: entidades_tipos_pkey; Type: CONSTRAINT; Schema: public; Owner: stg; Tablespace: 
--

ALTER TABLE ONLY entidades_tipos
    ADD CONSTRAINT entidades_tipos_pkey PRIMARY KEY (id);


--
-- TOC entry 2154 (class 2606 OID 303159)
-- Name: familias_pkey; Type: CONSTRAINT; Schema: public; Owner: stg; Tablespace: 
--

ALTER TABLE ONLY familias
    ADD CONSTRAINT familias_pkey PRIMARY KEY (id);


--
-- TOC entry 2162 (class 2606 OID 303211)
-- Name: familias_propiedades_familia_id_propiedad_id_valor_key; Type: CONSTRAINT; Schema: public; Owner: stg; Tablespace: 
--

ALTER TABLE ONLY familias_propiedades
    ADD CONSTRAINT familias_propiedades_familia_id_propiedad_id_valor_key UNIQUE (familia_id, propiedad_id, valor);


--
-- TOC entry 2164 (class 2606 OID 303209)
-- Name: familias_propiedades_pkey; Type: CONSTRAINT; Schema: public; Owner: stg; Tablespace: 
--

ALTER TABLE ONLY familias_propiedades
    ADD CONSTRAINT familias_propiedades_pkey PRIMARY KEY (id);


--
-- TOC entry 2178 (class 2606 OID 303392)
-- Name: familias_valoresligados_fp_id_fp2_id_key; Type: CONSTRAINT; Schema: public; Owner: stg; Tablespace: 
--

ALTER TABLE ONLY familias_valoresligados
    ADD CONSTRAINT familias_valoresligados_fp_id_fp2_id_key UNIQUE (fp_id, fp2_id);


--
-- TOC entry 2180 (class 2606 OID 303390)
-- Name: familias_valoresligados_pkey; Type: CONSTRAINT; Schema: public; Owner: stg; Tablespace: 
--

ALTER TABLE ONLY familias_valoresligados
    ADD CONSTRAINT familias_valoresligados_pkey PRIMARY KEY (id);


--
-- TOC entry 2184 (class 2606 OID 344091)
-- Name: gruposventas_pkey; Type: CONSTRAINT; Schema: public; Owner: stg; Tablespace: 
--

ALTER TABLE ONLY gruposventas
    ADD CONSTRAINT gruposventas_pkey PRIMARY KEY (id);


--
-- TOC entry 2148 (class 2606 OID 270415)
-- Name: impuestos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY impuestos
    ADD CONSTRAINT impuestos_pkey PRIMARY KEY (id);


--
-- TOC entry 2139 (class 2606 OID 90128)
-- Name: menus_pkey; Type: CONSTRAINT; Schema: public; Owner: stg; Tablespace: 
--

ALTER TABLE ONLY menus
    ADD CONSTRAINT menus_pkey PRIMARY KEY (id);


--
-- TOC entry 2141 (class 2606 OID 90130)
-- Name: menus_texto_key; Type: CONSTRAINT; Schema: public; Owner: stg; Tablespace: 
--

ALTER TABLE ONLY menus
    ADD CONSTRAINT menus_texto_key UNIQUE (texto);


--
-- TOC entry 2152 (class 2606 OID 303144)
-- Name: propiedades_componer_pkey; Type: CONSTRAINT; Schema: public; Owner: stg; Tablespace: 
--

ALTER TABLE ONLY propiedades_componer
    ADD CONSTRAINT propiedades_componer_pkey PRIMARY KEY (id);


--
-- TOC entry 2160 (class 2606 OID 303184)
-- Name: propiedades_pkey; Type: CONSTRAINT; Schema: public; Owner: stg; Tablespace: 
--

ALTER TABLE ONLY propiedades
    ADD CONSTRAINT propiedades_pkey PRIMARY KEY (id);


--
-- TOC entry 2144 (class 2606 OID 270354)
-- Name: unidadmedida_categorias_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY unidadmedida_categorias
    ADD CONSTRAINT unidadmedida_categorias_pkey PRIMARY KEY (id);


--
-- TOC entry 2146 (class 2606 OID 270367)
-- Name: unidadmedidas_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY unidadmedidas
    ADD CONSTRAINT unidadmedidas_pkey PRIMARY KEY (id);


--
-- TOC entry 2169 (class 1259 OID 303304)
-- Name: idx_articulos_codbarra; Type: INDEX; Schema: public; Owner: stg; Tablespace: 
--

CREATE INDEX idx_articulos_codbarra ON articulos USING btree (codbarra);


--
-- TOC entry 2170 (class 1259 OID 303301)
-- Name: idx_articulos_familia_id; Type: INDEX; Schema: public; Owner: stg; Tablespace: 
--

CREATE INDEX idx_articulos_familia_id ON articulos USING btree (familia_id);


--
-- TOC entry 2171 (class 1259 OID 303302)
-- Name: idx_articulos_nomcomercial; Type: INDEX; Schema: public; Owner: stg; Tablespace: 
--

CREATE INDEX idx_articulos_nomcomercial ON articulos USING btree (nomcomercial);


--
-- TOC entry 2175 (class 1259 OID 303325)
-- Name: idx_articulos_propiedades_fp_id; Type: INDEX; Schema: public; Owner: stg; Tablespace: 
--

CREATE INDEX idx_articulos_propiedades_fp_id ON articulos_propiedades USING btree (fp_id);


--
-- TOC entry 2176 (class 1259 OID 303324)
-- Name: idx_articulos_propiedades_grupo_id_id; Type: INDEX; Schema: public; Owner: stg; Tablespace: 
--

CREATE INDEX idx_articulos_propiedades_grupo_id_id ON articulos_propiedades USING btree (grupo_id);


--
-- TOC entry 2172 (class 1259 OID 303303)
-- Name: idx_articulos_unidadmedida_id; Type: INDEX; Schema: public; Owner: stg; Tablespace: 
--

CREATE INDEX idx_articulos_unidadmedida_id ON articulos USING btree (unidadmedida_id);


--
-- TOC entry 2213 (class 1259 OID 345321)
-- Name: idx_dircalles_codpostal; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX idx_dircalles_codpostal ON dirlocalidades USING btree (codpostal);


--
-- TOC entry 2225 (class 1259 OID 345322)
-- Name: idx_dircalles_municipio_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX idx_dircalles_municipio_id ON dircalles USING btree (municipio_id);


--
-- TOC entry 2203 (class 1259 OID 345223)
-- Name: idx_dircomunidades_pais_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX idx_dircomunidades_pais_id ON dircomunidades USING btree (pais_id);


--
-- TOC entry 2232 (class 1259 OID 345387)
-- Name: idx_direcciones_idcalle; Type: INDEX; Schema: public; Owner: stg; Tablespace: 
--

CREATE INDEX idx_direcciones_idcalle ON direcciones USING btree (calle_id);


--
-- TOC entry 2233 (class 1259 OID 345388)
-- Name: idx_direcciones_idinfocomplementaria; Type: INDEX; Schema: public; Owner: stg; Tablespace: 
--

CREATE INDEX idx_direcciones_idinfocomplementaria ON direcciones USING btree (infocomplementaria_id);


--
-- TOC entry 2234 (class 1259 OID 345389)
-- Name: idx_direcciones_nima; Type: INDEX; Schema: public; Owner: stg; Tablespace: 
--

CREATE INDEX idx_direcciones_nima ON direcciones USING btree (nima);


--
-- TOC entry 2235 (class 1259 OID 345390)
-- Name: idx_direcciones_nomsede; Type: INDEX; Schema: public; Owner: stg; Tablespace: 
--

CREATE INDEX idx_direcciones_nomsede ON direcciones USING btree (nomsede);


--
-- TOC entry 2210 (class 1259 OID 345260)
-- Name: idx_dirislas_provincia_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX idx_dirislas_provincia_id ON dirislas USING btree (provincia_id);


--
-- TOC entry 2214 (class 1259 OID 345270)
-- Name: idx_dirlocalidades_codpostal_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX idx_dirlocalidades_codpostal_id ON dirlocalidades USING btree (codpostal);


--
-- TOC entry 2221 (class 1259 OID 345306)
-- Name: idx_dirmunicipios_codpostal; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX idx_dirmunicipios_codpostal ON dirmunicipioscp USING btree (codpostal);


--
-- TOC entry 2217 (class 1259 OID 345291)
-- Name: idx_dirmunicipios_isla_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX idx_dirmunicipios_isla_id ON dirmunicipios USING btree (isla_id);


--
-- TOC entry 2218 (class 1259 OID 345290)
-- Name: idx_dirmunicipios_provincia_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX idx_dirmunicipios_provincia_id ON dirmunicipios USING btree (provincia_id);


--
-- TOC entry 2222 (class 1259 OID 345305)
-- Name: idx_dirmunicipioscp_municipio_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX idx_dirmunicipioscp_municipio_id ON dirmunicipioscp USING btree (municipio_id);


--
-- TOC entry 2206 (class 1259 OID 345245)
-- Name: idx_dirprovincias_coumunidad_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX idx_dirprovincias_coumunidad_id ON dirprovincias USING btree (comunidad_id);


--
-- TOC entry 2207 (class 1259 OID 345244)
-- Name: idx_dirprovincias_pais_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX idx_dirprovincias_pais_id ON dirprovincias USING btree (pais_id);


--
-- TOC entry 2193 (class 1259 OID 352276)
-- Name: idx_entidades_codentidad; Type: INDEX; Schema: public; Owner: stg; Tablespace: 
--

CREATE UNIQUE INDEX idx_entidades_codentidad ON entidades USING btree (codentidad);


--
-- TOC entry 2242 (class 1259 OID 368798)
-- Name: idx_entidades_entidadlink_id; Type: INDEX; Schema: public; Owner: stg; Tablespace: 
--

CREATE UNIQUE INDEX idx_entidades_entidadlink_id ON entidades_links USING btree (entidadlink_id, entidadlinkpadre_id);


--
-- TOC entry 2194 (class 1259 OID 344126)
-- Name: idx_entidades_nif; Type: INDEX; Schema: public; Owner: stg; Tablespace: 
--

CREATE UNIQUE INDEX idx_entidades_nif ON entidades USING btree (nif);


--
-- TOC entry 2155 (class 1259 OID 303171)
-- Name: idx_familias_describe; Type: INDEX; Schema: public; Owner: stg; Tablespace: 
--

CREATE INDEX idx_familias_describe ON familias USING btree (describe);


--
-- TOC entry 2156 (class 1259 OID 303170)
-- Name: idx_familias_padre_id; Type: INDEX; Schema: public; Owner: stg; Tablespace: 
--

CREATE INDEX idx_familias_padre_id ON familias USING btree (padre_id);


--
-- TOC entry 2165 (class 1259 OID 303222)
-- Name: idx_familias_propiedades_familia_id; Type: INDEX; Schema: public; Owner: stg; Tablespace: 
--

CREATE INDEX idx_familias_propiedades_familia_id ON familias_propiedades USING btree (familia_id);


--
-- TOC entry 2166 (class 1259 OID 303223)
-- Name: idx_familias_propiedades_propiedad_id; Type: INDEX; Schema: public; Owner: stg; Tablespace: 
--

CREATE INDEX idx_familias_propiedades_propiedad_id ON familias_propiedades USING btree (propiedad_id);


--
-- TOC entry 2181 (class 1259 OID 303404)
-- Name: idx_familias_valoresligados_fp2_id; Type: INDEX; Schema: public; Owner: stg; Tablespace: 
--

CREATE INDEX idx_familias_valoresligados_fp2_id ON familias_valoresligados USING btree (fp2_id);


--
-- TOC entry 2182 (class 1259 OID 303403)
-- Name: idx_familias_valoresligados_fp_id_id; Type: INDEX; Schema: public; Owner: stg; Tablespace: 
--

CREATE INDEX idx_familias_valoresligados_fp_id_id ON familias_valoresligados USING btree (fp_id);


--
-- TOC entry 2157 (class 1259 OID 303200)
-- Name: idx_propiedades_codpropiedad; Type: INDEX; Schema: public; Owner: stg; Tablespace: 
--

CREATE INDEX idx_propiedades_codpropiedad ON propiedades USING btree (codpropiedad);


--
-- TOC entry 2158 (class 1259 OID 303201)
-- Name: idx_propiedades_tcorto; Type: INDEX; Schema: public; Owner: stg; Tablespace: 
--

CREATE INDEX idx_propiedades_tcorto ON propiedades USING btree (tcorto);


--
-- TOC entry 2142 (class 1259 OID 114697)
-- Name: unique_schema_migrations; Type: INDEX; Schema: public; Owner: stg; Tablespace: 
--

CREATE UNIQUE INDEX unique_schema_migrations ON schema_migrations USING btree (version);


--
-- TOC entry 2253 (class 2606 OID 303271)
-- Name: articulos_familia_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: stg
--

ALTER TABLE ONLY articulos
    ADD CONSTRAINT articulos_familia_id_fkey FOREIGN KEY (familia_id) REFERENCES familias(id);


--
-- TOC entry 2257 (class 2606 OID 303291)
-- Name: articulos_impuesto_compra_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: stg
--

ALTER TABLE ONLY articulos
    ADD CONSTRAINT articulos_impuesto_compra_id_fkey FOREIGN KEY (impuesto_compra_id) REFERENCES impuestos(id) MATCH FULL;


--
-- TOC entry 2258 (class 2606 OID 303296)
-- Name: articulos_impuesto_venta_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: stg
--

ALTER TABLE ONLY articulos
    ADD CONSTRAINT articulos_impuesto_venta_id_fkey FOREIGN KEY (impuesto_venta_id) REFERENCES impuestos(id) MATCH FULL;


--
-- TOC entry 2256 (class 2606 OID 303286)
-- Name: articulos_ler_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: stg
--

ALTER TABLE ONLY articulos
    ADD CONSTRAINT articulos_ler_id_fkey FOREIGN KEY (ler_id) REFERENCES articulos_lers(id);


--
-- TOC entry 2260 (class 2606 OID 303319)
-- Name: articulos_propiedades_fp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: stg
--

ALTER TABLE ONLY articulos_propiedades
    ADD CONSTRAINT articulos_propiedades_fp_id_fkey FOREIGN KEY (fp_id) REFERENCES familias_propiedades(id) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 2259 (class 2606 OID 303314)
-- Name: articulos_propiedades_grupo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: stg
--

ALTER TABLE ONLY articulos_propiedades
    ADD CONSTRAINT articulos_propiedades_grupo_id_fkey FOREIGN KEY (grupo_id) REFERENCES articulos(id) MATCH FULL ON DELETE CASCADE;


--
-- TOC entry 2255 (class 2606 OID 303281)
-- Name: articulos_unidadmedida_categoria_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: stg
--

ALTER TABLE ONLY articulos
    ADD CONSTRAINT articulos_unidadmedida_categoria_id_fkey FOREIGN KEY (unidadmedida_categoria_id) REFERENCES unidadmedida_categorias(id) MATCH FULL;


--
-- TOC entry 2254 (class 2606 OID 303276)
-- Name: articulos_unidadmedida_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: stg
--

ALTER TABLE ONLY articulos
    ADD CONSTRAINT articulos_unidadmedida_id_fkey FOREIGN KEY (unidadmedida_id) REFERENCES unidadmedidas(id) MATCH FULL ON UPDATE CASCADE;


--
-- TOC entry 2274 (class 2606 OID 345316)
-- Name: dircalles_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY dircalles
    ADD CONSTRAINT dircalles_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES dirmunicipios(id) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 2267 (class 2606 OID 345218)
-- Name: dircomunidades_pais_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY dircomunidades
    ADD CONSTRAINT dircomunidades_pais_id_fkey FOREIGN KEY (pais_id) REFERENCES dirpaises(id) MATCH FULL;


--
-- TOC entry 2276 (class 2606 OID 345359)
-- Name: direcciones_calle_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: stg
--

ALTER TABLE ONLY direcciones
    ADD CONSTRAINT direcciones_calle_id_fkey FOREIGN KEY (calle_id) REFERENCES dircalles(id) MATCH FULL;


--
-- TOC entry 2275 (class 2606 OID 345354)
-- Name: direcciones_entidad_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: stg
--

ALTER TABLE ONLY direcciones
    ADD CONSTRAINT direcciones_entidad_id_fkey FOREIGN KEY (entidad_id) REFERENCES entidades(id) MATCH FULL;


--
-- TOC entry 2277 (class 2606 OID 345364)
-- Name: direcciones_infocomplementaria_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: stg
--

ALTER TABLE ONLY direcciones
    ADD CONSTRAINT direcciones_infocomplementaria_id_fkey FOREIGN KEY (infocomplementaria_id) REFERENCES dirinfocomplementarias(id) MATCH FULL;


--
-- TOC entry 2278 (class 2606 OID 345377)
-- Name: direcciones_tipos_links_direccion_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: stg
--

ALTER TABLE ONLY direcciones_tipos_links
    ADD CONSTRAINT direcciones_tipos_links_direccion_id_fkey FOREIGN KEY (direccion_id) REFERENCES direcciones(id) MATCH FULL;


--
-- TOC entry 2279 (class 2606 OID 345382)
-- Name: direcciones_tipos_links_direcciones_tipo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: stg
--

ALTER TABLE ONLY direcciones_tipos_links
    ADD CONSTRAINT direcciones_tipos_links_direcciones_tipo_id_fkey FOREIGN KEY (direcciones_tipo_id) REFERENCES direcciones_tipos(id);


--
-- TOC entry 2270 (class 2606 OID 345255)
-- Name: dirislas_provincia_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY dirislas
    ADD CONSTRAINT dirislas_provincia_id_fkey FOREIGN KEY (provincia_id) REFERENCES dirprovincias(id) MATCH FULL;


--
-- TOC entry 2272 (class 2606 OID 345285)
-- Name: dirmunicipios_isla_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY dirmunicipios
    ADD CONSTRAINT dirmunicipios_isla_id_fkey FOREIGN KEY (isla_id) REFERENCES dirislas(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 2271 (class 2606 OID 345280)
-- Name: dirmunicipios_provincia_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY dirmunicipios
    ADD CONSTRAINT dirmunicipios_provincia_id_fkey FOREIGN KEY (provincia_id) REFERENCES dirprovincias(id) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 2273 (class 2606 OID 345300)
-- Name: dirmunicipioscp_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY dirmunicipioscp
    ADD CONSTRAINT dirmunicipioscp_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES dirmunicipios(id) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 2268 (class 2606 OID 345234)
-- Name: dirprovincias_comunidad_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY dirprovincias
    ADD CONSTRAINT dirprovincias_comunidad_id_fkey FOREIGN KEY (comunidad_id) REFERENCES dircomunidades(id);


--
-- TOC entry 2269 (class 2606 OID 345239)
-- Name: dirprovincias_pais_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY dirprovincias
    ADD CONSTRAINT dirprovincias_pais_id_fkey FOREIGN KEY (pais_id) REFERENCES dirpaises(id) MATCH FULL;


--
-- TOC entry 2265 (class 2606 OID 344260)
-- Name: entidades_gruposventas_entidad_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: stg
--

ALTER TABLE ONLY entidades_gruposventas
    ADD CONSTRAINT entidades_gruposventas_entidad_id_fkey FOREIGN KEY (entidad_id) REFERENCES entidades(id) MATCH FULL;


--
-- TOC entry 2266 (class 2606 OID 344265)
-- Name: entidades_gruposventas_grupoventa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: stg
--

ALTER TABLE ONLY entidades_gruposventas
    ADD CONSTRAINT entidades_gruposventas_grupoventa_id_fkey FOREIGN KEY (grupoventa_id) REFERENCES gruposventas(id);


--
-- TOC entry 2264 (class 2606 OID 360468)
-- Name: entidades_grupoventa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: stg
--

ALTER TABLE ONLY entidades
    ADD CONSTRAINT entidades_grupoventa_id_fkey FOREIGN KEY (grupoventa_id) REFERENCES gruposventas(id);


--
-- TOC entry 2280 (class 2606 OID 368692)
-- Name: entidades_links_cargos_entidadtipo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: stg
--

ALTER TABLE ONLY entidades_links_cargos
    ADD CONSTRAINT entidades_links_cargos_entidadtipo_id_fkey FOREIGN KEY (entidadtipo_id) REFERENCES entidades_links_tipos(id) MATCH FULL;


--
-- TOC entry 2285 (class 2606 OID 368793)
-- Name: entidades_links_cuenta_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: stg
--

ALTER TABLE ONLY entidades_links
    ADD CONSTRAINT entidades_links_cuenta_id_fkey FOREIGN KEY (cuenta_id) REFERENCES cuentas(id);


--
-- TOC entry 2281 (class 2606 OID 368773)
-- Name: entidades_links_entidadlink_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: stg
--

ALTER TABLE ONLY entidades_links
    ADD CONSTRAINT entidades_links_entidadlink_id_fkey FOREIGN KEY (entidadlink_id) REFERENCES entidades(id) MATCH FULL;


--
-- TOC entry 2284 (class 2606 OID 368788)
-- Name: entidades_links_entidadlinkcargo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: stg
--

ALTER TABLE ONLY entidades_links
    ADD CONSTRAINT entidades_links_entidadlinkcargo_id_fkey FOREIGN KEY (entidadlinkcargo_id) REFERENCES entidades_links_cargos(id);


--
-- TOC entry 2282 (class 2606 OID 368778)
-- Name: entidades_links_entidadlinkpadre_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: stg
--

ALTER TABLE ONLY entidades_links
    ADD CONSTRAINT entidades_links_entidadlinkpadre_id_fkey FOREIGN KEY (entidadlinkpadre_id) REFERENCES entidades(id) MATCH FULL;


--
-- TOC entry 2283 (class 2606 OID 368783)
-- Name: entidades_links_entidadlinktipo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: stg
--

ALTER TABLE ONLY entidades_links
    ADD CONSTRAINT entidades_links_entidadlinktipo_id_fkey FOREIGN KEY (entidadlinktipo_id) REFERENCES entidades_links_tipos(id) MATCH FULL;


--
-- TOC entry 2263 (class 2606 OID 344121)
-- Name: entidades_tipo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: stg
--

ALTER TABLE ONLY entidades
    ADD CONSTRAINT entidades_tipo_id_fkey FOREIGN KEY (tipo_id) REFERENCES entidades_tipos(id) MATCH FULL;


--
-- TOC entry 2247 (class 2606 OID 303165)
-- Name: familias_componer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: stg
--

ALTER TABLE ONLY familias
    ADD CONSTRAINT familias_componer_id_fkey FOREIGN KEY (componer_id) REFERENCES propiedades_componer(id) MATCH FULL;


--
-- TOC entry 2246 (class 2606 OID 303160)
-- Name: familias_padre_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: stg
--

ALTER TABLE ONLY familias
    ADD CONSTRAINT familias_padre_id_fkey FOREIGN KEY (padre_id) REFERENCES familias(id);


--
-- TOC entry 2251 (class 2606 OID 303212)
-- Name: familias_propiedades_familia_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: stg
--

ALTER TABLE ONLY familias_propiedades
    ADD CONSTRAINT familias_propiedades_familia_id_fkey FOREIGN KEY (familia_id) REFERENCES familias(id) MATCH FULL;


--
-- TOC entry 2252 (class 2606 OID 303217)
-- Name: familias_propiedades_propiedad_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: stg
--

ALTER TABLE ONLY familias_propiedades
    ADD CONSTRAINT familias_propiedades_propiedad_id_fkey FOREIGN KEY (propiedad_id) REFERENCES propiedades(id) MATCH FULL;


--
-- TOC entry 2262 (class 2606 OID 303398)
-- Name: familias_valoresligados_fp2_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: stg
--

ALTER TABLE ONLY familias_valoresligados
    ADD CONSTRAINT familias_valoresligados_fp2_id_fkey FOREIGN KEY (fp2_id) REFERENCES familias_propiedades(id) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 2261 (class 2606 OID 303393)
-- Name: familias_valoresligados_fp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: stg
--

ALTER TABLE ONLY familias_valoresligados
    ADD CONSTRAINT familias_valoresligados_fp_id_fkey FOREIGN KEY (fp_id) REFERENCES familias_propiedades(id) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 2245 (class 2606 OID 270416)
-- Name: impuestos_impuesto_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY impuestos
    ADD CONSTRAINT impuestos_impuesto_id_fkey FOREIGN KEY (impuesto_id) REFERENCES impuestos(id);


--
-- TOC entry 2243 (class 2606 OID 90131)
-- Name: menus_menu_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: stg
--

ALTER TABLE ONLY menus
    ADD CONSTRAINT menus_menu_id_fkey FOREIGN KEY (menu_id) REFERENCES menus(id);


--
-- TOC entry 2250 (class 2606 OID 303195)
-- Name: propiedades_componertcomercial_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: stg
--

ALTER TABLE ONLY propiedades
    ADD CONSTRAINT propiedades_componertcomercial_id_fkey FOREIGN KEY (componertcomercial_id) REFERENCES propiedades_componer(id) MATCH FULL;


--
-- TOC entry 2248 (class 2606 OID 303185)
-- Name: propiedades_componertcorto_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: stg
--

ALTER TABLE ONLY propiedades
    ADD CONSTRAINT propiedades_componertcorto_id_fkey FOREIGN KEY (componertcorto_id) REFERENCES propiedades_componer(id) MATCH FULL;


--
-- TOC entry 2249 (class 2606 OID 303190)
-- Name: propiedades_componertlargo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: stg
--

ALTER TABLE ONLY propiedades
    ADD CONSTRAINT propiedades_componertlargo_id_fkey FOREIGN KEY (componertlargo_id) REFERENCES propiedades_componer(id) MATCH FULL;


--
-- TOC entry 2244 (class 2606 OID 270368)
-- Name: unidadmedidas_unidadmedida_categoria_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY unidadmedidas
    ADD CONSTRAINT unidadmedidas_unidadmedida_categoria_id_fkey FOREIGN KEY (unidadmedida_categoria_id) REFERENCES unidadmedida_categorias(id) MATCH FULL;


--
-- TOC entry 2466 (class 0 OID 0)
-- Dependencies: 5
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


-- Completed on 2016-02-22 18:55:31

--
-- PostgreSQL database dump complete
--

