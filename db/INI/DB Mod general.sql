/* Este archivo contiene funciones útiles que se usan en todos los archivos de funciones MOD_...*/


CREATE OR REPLACE FUNCTION concat2(text, text)
  RETURNS text AS
$BODY$
    SELECT CASE WHEN $1 IS NULL OR $1 = '' THEN $2
            WHEN $2 IS NULL OR $2 = '' THEN $1
            ELSE $1 || ', ' || $2
            END; 
$BODY$
  LANGUAGE sql VOLATILE
  COST 100;

CREATE AGGREGATE concatenate(text) (
  SFUNC=concat2,
  STYPE=text,
  INITCOND=''
);



-- EJEMPLOS DE USO:
-- select array_length(array[2,3,4,5,null::integer],1)
-- select array_search(3,array[2,3,4,5,null::integer]::int[])
CREATE FUNCTION array_search(needle ANYELEMENT, haystack ANYARRAY)
RETURNS INT AS $$
    SELECT i
      FROM generate_subscripts($2, 1) AS i
     WHERE $2[i] = $1
  ORDER BY i
$$ LANGUAGE sql STABLE;


--intersección entre dos array
CREATE FUNCTION array_intersect(anyarray, anyarray)
  RETURNS anyarray
  language sql
as $FUNCTION$
    SELECT ARRAY(
        SELECT UNNEST($1)
        INTERSECT
        SELECT UNNEST($2)
    );
$FUNCTION$;

--A - B (diferencia o except entre dos array)
CREATE FUNCTION array_except(anyarray, anyarray)
  RETURNS anyarray
  language sql
as $FUNCTION$
    SELECT ARRAY(
        SELECT UNNEST($1)
        EXCEPT
        SELECT UNNEST($2)
    );
$FUNCTION$;


CREATE OR REPLACE FUNCTION isnumeric(text) RETURNS BOOLEAN AS $$
DECLARE x NUMERIC;
BEGIN
    x = $1::NUMERIC;
    RETURN TRUE;
EXCEPTION WHEN others THEN
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql IMMUTABLE;


/*******************************FUNCIONES MOD (ORIENTADAS AL USO DE APLICACIÓN DE ESCRITORIO ****************/
create or replace function Mod_separador_reg(bool) returns text as
$BODY$
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

$BODY$
  LANGUAGE plpgsql VOLATILE
COST 100;


create or replace function Mod_typeof(text,text,text) returns text as
$BODY$
-- Devuelve el valor pasado en p_valor, solo que si dicho valor es de tipo numerico (se sabe buscando en la tabla y campo al que pertenece dicho p_valor) se devuelve tal cual, y si no, 
-- se devuelve entrecomillado, y si tuviese comillas simples incluidas, se duplicarían para que no haya problemas en su manipulación.
DECLARE
  p_tabla alias for $1; 
  p_columna alias for $2; 
  p_valor alias for $3;
  p_v text;
begin
	select  case when data_type in ('integer','numeric','decimal','real') then p_valor else quote_literal(p_valor) end from information_schema.columns into p_v
	where table_name = p_tabla
	and column_name=p_columna;
	if found then
	  return p_v;
	else
	  return quote_nullable(p_valor);
	end if;  
	
end;

$BODY$
  LANGUAGE plpgsql VOLATILE
COST 100;


drop function MOD_query_update(integer,integer,text,text,text,text);
create or replace function MOD_query_update(text,text,text,text) returns setof text as
$BODY$
-- Esta función devuelve un conjunto de registros con las consultas update a ejecutar según una serie de campos, valores, e ids de aplicación
-- Devolverá tanstos registros como ids de aplicación se le pase.
-- Cada fila devuelta tiene un único campo con la sentencia sql del update.
-- Devuelve tantos registros como actualizaciones hagan falta. 
DECLARE
  p_campos alias for $1;
  p_valores alias for $2;
  p_ids alias for $3;
  p_tabla alias for $4;
  
  p_separador_campo text;
  p_separador_reg text;
  p_sql text;
  p_allsql text;
  p_id integer;
  p_campos_arr text[];
  p_valores_arr text[];
  p_campo text;
  p_valor text;
  i integer;
  p_campovalor text;
  
begin

  select Mod_separador_reg(true), Mod_separador_reg(false) into p_separador_reg, p_separador_campo;

  select string_to_array(p_campos,p_separador_reg) into p_campos_arr; -- Construye una array, donde cada elemento son los campos a modificar de un registro (tantas posiciones de array como regisros a modificar)
  select string_to_array(p_valores,p_separador_reg) into p_valores_arr; -- Construye una array donde cada elemento son los valores a modificar de un registro (tantas posiciones de array como regisros a modificar)
  
  i:=1;
  p_allsql:='';
  for p_id in select regexp_split_to_table(p_ids,',') as id loop --itera tantas veces como registros a modificar haya
        p_campo:=p_campos_arr[i];
        p_valor:=p_valores_arr[i];
	p_sql:='update '||p_tabla||' set %campos-valores% where id='||p_id ||';';
	select concatenate(campovalor.c||'='||Mod_typeof(p_tabla,c,v)) into p_campovalor --construye la asignación del update por campo-valor
	from(
		select split_part(p_campo,p_separador_campo,t.i+1) as c,split_part(p_valor,p_separador_campo,t.i+1) as v  
		from (
			select generate_series(0,array_length(string_to_array(p_campo,p_separador_campo),1)-1) as i  --crea tantas filas como campos a modificar haya. Cada fila contiene el número de fila. (Numera los registros)
		     ) t
	) campovalor;
	i:=i+1;
	p_allsql:=p_allsql||replace(p_sql,'%campos-valores%',p_campovalor); --reemplazamos la marca %campos-valores% por lo calculado
  end loop;
  p_allsql:=left(p_allsql,length(p_allsql)-1);
  --raise exception '%',p_allsql;
  return query execute 'select  upt from regexp_split_to_table('||quote_literal(p_allsql)||','';'') upt;';

END;
$BODY$
  LANGUAGE plpgsql VOLATILE
COST 100;  

-- EJEMPLOS DE USO
--  select MOD_query_where('campo1|#campos2|#campo3','1|#valor texto|#2014-01-01','=|#in|#>=')
-- select string_to_array('=|#in|#>=','|#')

create or replace function MOD_query_where(text,text,text) returns text as
$BODY$
-- Esta función devuelve un conjunto de registros con las consultas update a ejecutar según una serie de campos, valores, e ids de aplicación
-- Devolverá tantos registros como ids de aplicación se le pase.
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
$BODY$
  LANGUAGE plpgsql VOLATILE
COST 100;  



