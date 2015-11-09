

CREATE OR REPLACE FUNCTION empresa_01.articulos_compatibilidad_coalbcab(text)
  RETURNS text AS
$BODY$				
declare				
p_codarticulo  alias for $1 ;
cSql text;
r record;
p_msg1 text;
i integer;
p_cuenta integer;

begin	
  cSql:=''''||replace(p_codarticulo,',',''',''')||'''';
  cSql:='select  ''Grupo: ''||case when char_length(codgrupo)=0 then ''SIN DEFINIR'' else codgrupo end ||''  -->  ''||concatenate(codarticulo) as grupo,count(*) as cuenta from articulos where codarticulo in ('||cSql||') group by codgrupo;';
   i:=0;
   perform cif from empresa where cif='B35855543';
   if not found then
      return 'OK';
   end if;
   
   FOR r IN EXECUTE cSql LOOP
     i:=i+1;
     p_cuenta:=r.cuenta;  
     if i>1 then -- segunda iteración
       if r.cuenta>p_cuenta then
         return case when p_cuenta=1 then 'ERROR|Existe un artículo incompatible con el resto de líneas del albarán:' else 'ERROR|Existen varios artículos incompatibles en el albarán: 'end ||p_msg1||' INCOMPATIBLE con: '||r.grupo;
       else
         return case when r.cuenta=1 then 'ERROR|Existe un artículo incompatible con el resto de líneas del albarán:' else 'ERROR|Existen varios artículos incompatibles en el albarán: ' end ||r.grupo||' INCOMPATIBLE con: '||p_msg1;
       end if;
     end if;
     p_msg1:=r.grupo;
   END LOOP;
   return 'OK';
     
END;				
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION empresa_01.articulos_compatibilidad_coalbcab(text)
  OWNER TO dovalo;



CREATE OR REPLACE FUNCTION empresa_01.coalbcab_grupo_particion(text, numeric)
  RETURNS integer AS
$BODY$	
declare	
p_importe ALIAS FOR $1;	 
p_importeparticion alias for $2;
r record;
p_acumulado numeric;
p_grupo integer;
p_ultgrupo integer;
begin
  p_acumulado:=0;	
  p_ultgrupo:=0;
  p_grupo:=0;
  for r in SELECT dev::numeric FROM regexp_split_to_table(p_importe, ', ') AS dev loop
     p_acumulado:=p_acumulado+r.dev;
     p_grupo:=p_grupo+trunc(p_acumulado/p_importeparticion);
     if p_ultgrupo<>p_grupo then
       p_acumulado:=r.dev;
       p_ultgrupo:=p_grupo;
     end if;
  end loop;
  return p_grupo;
 end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;



  CREATE OR REPLACE FUNCTION empresa_01.coalblin_casos_fraude(timestamp without time zone, timestamp without time zone, timestamp without time zone, timestamp without time zone, text, text, integer, integer, integer, integer, text, integer)
  RETURNS text AS
$BODY$
DECLARE
p_tsmin alias for $1;
p_tsmax alias for $2;
p_tsregistro alias for $3;
p_tsregistronxt alias for $4;
p_codarticulo alias for $5;
p_codarticulonxt alias for $6;
p_cantidad alias for $7;
p_cantidadnxt alias for $8;
p_numdocumento alias for $9;
p_numdocumentonxt alias for $10;
p_fechas alias for $11;
p_op alias for $12;
p_tipo1 boolean;
p_tipo2 boolean; 
p_tipo3 boolean;
p_tmedio integer; -- tiempo medio
p_ret text;
--devuelve cod gnerico|codespecifico|texto fraude o cadena vacía si no hay indicio de fraude. codgenerico puede ser 0,1,2,100,o 200
-- p_op puede ser:
--    1 para que devuelva  solo lo que cumpla '2 pesadas consecutivas del mismo artículo y cantidad en albaranes distintos'
--    2 para que devuelva true solo lo que cumpla 'Albarán abierto '||to_char(ts_max-ts_min, 'HH24 \"horas\" MI \"minutos\"')
--    3 El tiempo medio entre pesadas es sospechoso
--    100 para que devuelva true si se da 1 o se da 2 o se da 3
--    200 para que devuelva true si se da 1 Y se da 2 Y se da 3
--    0 para no filtrar por casos de fraude
BEGIN
    if p_op=0 then
       return '0|1|No se comprueba si hay fraude';
    end if;
    p_tipo1:= p_tsregistronxt>p_tsregistro and p_numdocumento <> p_numdocumentonxt  and trim(p_codarticulo)=trim(p_codarticulonxt) and p_cantidad = p_cantidadnxt;
    if p_op=1 then 
          return case when p_tipo1 then '1|1|2 pesadas consecutivas del mismo artículo y cantidad en albaranes distintos' else '' end;
    end if;

    p_tipo2:=(extract(epoch FROM p_tsmax) - extract(epoch from p_tsmin)>30*60);

    if p_op=2 then 
       return case when p_tipo2 then '2|2|Albarán '||p_numdocumento||' abierto '||to_char(p_tsmax-p_tsmin, 'HH24 \"horas\" MI \"minutos\"') else '' end;
    end if;
   
   p_tipo3:=false;
   
   if char_length(p_fechas)>0 and split_part(p_fechas,', ',2)<>'' then --hay más de una línea
    select (sum(case when t2 is null then 0 else coalesce(date_part('epoch', t.t2),0) - coalesce(date_part('epoch', t.t1),0) end)/(max(t.cuenta)-1))::integer into p_tmedio
     from (
	select txt as t1,lead(txt) over (order by txt) as t2, count(*) over () as cuenta from(
		SELECT regexp_split_to_table(p_fechas, ', ')::timestamp as txt 
		order by txt
	)  t 
     ) t;

     p_tipo3:=p_tmedio>5*60; --tendrá true si el tiempo medio entre líneas es mayor a 5 minutos
   end if;

   if p_op=3 then
      return case when p_tipo3 then '3|3|El tiempo medio entre pesadas es sospechoso' else '' end;
   end if;
        
    if p_tipo1 and p_tipo2 and p_tipo3 then
          --Da igual el tipo de operación que se haya mandado sacar. Se retorna un true, con el texto que conviene
          return '200|1|2 pesadas consecutivas del mismo artículo y cantidad en albaranes distintos Y albarán '||p_numdocumento||' abierto '||to_char(p_tsmax-p_tsmin, 'HH24 \"horas\" MI \"minutos\"')||' Y El tiempo medio entre pesadas es sospechoso';
    else
       if p_op=200 then --se ha mandado filtrar con un AND en  todas las condiciones, y no se ha cumplido=>retornamos el equivalente a false
          return '';
       end if;
    end if;

    p_ret:='';
    --El 100 se usa para obtener todas las descripciones de los textos fraudulentos. Si no es fraudulento, se devuelve un texto que lo indica (no se devuelve vacío en ningún caso)
    if p_op=100 or p_op=110 then --se cumple alguna de las condiciones, y no se cumple el AND entre las 3, YA QUE LO HEMOS COMPROBADO ANTERIORMENTE
       if p_tipo1 then
             p_ret :=p_op||'|1|2 pesadas consecutivas del mismo artículo y cantidad en albaranes distintos';
       end if;
       p_ret:=p_ret||case when char_length(p_ret)>0 and p_tipo2 then ' Y '  when p_tipo2 then p_op||'|2|' else '' end;
       if p_tipo2 then
            p_ret:=p_ret || 'Albarán '||p_numdocumento||' abierto '||to_char(p_tsmax-p_tsmin, 'HH24 \"horas\" MI \"minutos\"');
       end if;
       p_ret:=p_ret||case when char_length(p_ret)>0 and p_tipo3 then ' Y ' when p_tipo3 then p_op||'|3|' else '' end;
       if p_tipo3 then
          p_ret:=p_ret || 'El tiempo medio entre pesadas es sospechoso';
       end if;
       
       return case when length(p_ret)>0 or p_op=110 then p_ret else p_op||'|2|No se detecta fraude' end; -- 
    end if;
    return ''; -- si llega aquí devolvemos que no hay error
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION empresa_01.coalblin_casos_fraude(timestamp without time zone, timestamp without time zone, timestamp without time zone, timestamp without time zone, text, text, integer, integer, integer, integer, text, integer)
  OWNER TO dovalo;



CREATE OR REPLACE FUNCTION empresa_01.coalbregistro_numera(character, character)
  RETURNS text AS
$BODY$
declare
	------------------------------------------------------------------
	-- Funcion para numerar los albaranes y generar libro policia ----
	------------------------------------------------------------------
	
	-- Delegacion de la que se va a numerar
	p_codDelegacion alias for $1;
	-- Fecha hasta la cual vamos a numerar los albaranes
	p_fechaLimite alias for $2;
	cSql text;
	oObj record;
	nMaxDoc integer;
begin
	select max(numdocumento) into nMaxDoc from coalbregistro where seriedocumento=p_codDelegacion ;
	cSql:='select nextval(''seccomalbpolicia' || lower(p_codDelegacion) || ''') as orden, ';
	cSql:=cSql || 'ca.seriedocumento, ca.numdocumento, cr.numdocumento ';
	cSql:=cSql || 'from coalbcab ca ';
	cSql:=cSql || 'inner join seriescompras sc ';
	cSql:=cSql || 'on ca.seriedocumento = sc.codserie ';
	cSql:=cSql || 'left join coalbregistro cr ';
	cSql:=cSql || 'on ca.seriedocumento = cr.seriedocumento and ca.numdocumento = cr.numdocumento ';
	cSql:=cSql || 'where ';
	cSql:=cSql || 'sc.ctrlcaja = true ';
	cSql:=cSql || 'and ca.codproveedor != ''1000001'' ';
	cSql:=cSql || 'and ca.coddelegacion = ''' || p_codDelegacion || ''' ';
	cSql:=cSql || 'and ca.numdocumento > ' || nMaxDoc::text || ' ';
	cSql:=cSql || 'and ca.fechadoc <= ''' || p_fechaLimite || '''::date '; 
	cSql:=cSql || 'and cr.numdocumento is null ';
	cSql:=cSql || 'order by ca.ts_registro ';

	--raise exception 'dgfdgf %',cSql;

	For oObj In Execute cSql Loop
		Insert into coalbregistro (seriedocumento, numdocumento, numorden) 
			values (oObj.seriedocumento, oObj.numdocumento, oObj.orden);
	End Loop;

RETURN 'OK';
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;



CREATE OR REPLACE FUNCTION empresa_01.colamargenes_aplica_contenedor(character, integer)
  RETURNS void AS
$BODY$
------------------------------------------------------------------
--- Esta función hará que todos los albaranes de descuento de almacén de un contenedor que se modifiquen, y 
--- tengan líneas de detalle, rehagan los registros oportunos en colamargenes, y colamargenes_cancelaciones 
--- para la hoja de márgenes de contenedores
------------------------------------------------------------------
declare
   p_serie alias for $1;
   p_numdoc alias for $2;
   p_condiciones_turcos boolean;

begin
      
      if proviene_de_contenedor(p_serie, p_numdoc, 8) then    -- Es un contenedor para los turcos a los que no hace falta recalcular colamargenes
        return;
      end if;
	  if proviene_de_contenedor(p_serie, p_numdoc, 7) then -- Es una salida a otra empresa y cumple las características de los turcos
		delete from colamargenes where serie=p_serie and num=p_numdoc;
		delete from colamargenes_cancelaciones where serie=p_serie and num=p_numdoc;
		perform colamargenes_cancela_exportacion_turcos(p_serie, p_numdoc);

	  elsif proviene_de_contenedor(p_serie, p_numdoc, 5) then -- Es una salida a otra empresa
	        --Por si se recalcula un contenedor,se elimina primero antes de calcular nada
		delete from colamargenes where serie=p_serie and num=p_numdoc;
		delete from colamargenes_cancelaciones where serie=p_serie and num=p_numdoc;
		
	   
		perform colamargenes_cancela_exportacion(coalbcab.seriedocumento,coalbcab.numdocumento, coalbcab.ts_registro,coalblin.codarticulo,sum(coalblin.cantidad))
		from coalbcab inner join coalblin on coalbcab.seriedocumento=coalblin.albserie and coalbcab.numdocumento=coalblin.albdocumento
		where coalbcab.seriedocumento=p_serie and coalbcab.numdocumento=p_numdoc
		group by coalbcab.seriedocumento,coalbcab.numdocumento, coalbcab.ts_registro,coalblin.codarticulo;
	  elsif proviene_de_contenedor(p_serie, p_numdoc, 4) then --es una entrada de la misma empresa
	        --Por si se recalcula un contenedor,se elimina primero antes de calcular nada
		delete from colamargenes where serie=p_serie and num=p_numdoc;
		delete from colamargenes_cancelaciones where serie=p_serie and num=p_numdoc;
	   	perform colamargenes_cancela_recepcion(coalbcab.seriedocumento,coalbcab.numdocumento, coalbcab.ts_registro,coalblin.codarticulo,sum(coalblin.cantidad))
		from coalbcab inner join coalblin on coalbcab.seriedocumento=coalblin.albserie and coalbcab.numdocumento=coalblin.albdocumento
		where coalbcab.seriedocumento=p_serie and coalbcab.numdocumento=p_numdoc
		group by coalbcab.seriedocumento,coalbcab.numdocumento, coalbcab.ts_registro,coalblin.codarticulo;
	  end if;
      return ; 
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


CREATE OR REPLACE FUNCTION empresa_01.colamargenes_aplica_transformacion(character, integer)
  RETURNS void AS
$BODY$
------------------------------------------------------------------
--- Esta función creará para el albarán vinculado a una transformación
--  todos los cambios oportunos en la tabla colamargenes y colamargenes_cancelaciones
--  que hacen falta para que en la hoja de márgenes de contenedores esté repercutido
--  esta transformación
------------------------------------------------------------------

declare
p_serie ALIAS FOR $1;
p_num ALIAS FOR $2;
r record;
p_seriemov text;
p_nummov integer;
BEGIN 
    select TRIM(albsalida) into p_seriemov 
    from proalbcab where seriedocumento=p_serie and numdocumento=p_num;
    --RAISE EXCEPTION 'ALBSALIDA |%|',P_SERIEMOV;
    if char_length(coalesce(p_seriemov,''))>1 then
        p_nummov:=split_part(p_seriemov,'|',2)::integer;
        p_seriemov:=trim(split_part(p_seriemov,'|',1));
	perform colamargenes_cancela_transformaciones(coalbcab.seriedocumento,coalbcab.numdocumento, coalbcab.ts_registro,coalblin.codarticulo,sum(coalblin.cantidad))
	from coalbcab inner join 
		     coalblin on coalbcab.seriedocumento=coalblin.albserie and coalbcab.numdocumento=coalblin.albdocumento
	where coalbcab.seriedocumento=p_seriemov and coalbcab.numdocumento=p_nummov
	group by coalbcab.seriedocumento,coalbcab.numdocumento, coalbcab.ts_registro,coalblin.codarticulo;
    end if;
		
     
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;




CREATE OR REPLACE FUNCTION empresa_01.colamargenes_cancela_cantidadesnegativas(character, character)
  RETURNS void AS
$BODY$
-- Dado una delegación y un cod de artículo, busca en colamargenes cantidades en negativa a cencelar. Con esas cantidades, busca compras en positivo del mismo precio que
-- se puedan cancelar entre sí y genera dicha cancelación en colamargenes_cancelaciones. Al final queda cancelado la compra en negativo, y la compra en positivo.
--La cancelación de la compra en negativo, tiene como serie,num la compra en positivo. La cancelación de la compra en positivo tiene como serie,num la compra en negativo

DECLARE
	p_coddelegacion alias for $1;
	p_codarticulo alias for $2;
	r record;
	r2 record;
	p_cantidad numeric(20,2);
	p_ts timestamp;
BEGIN
     
      --ha de autocancelarse con otras cantidades positivas del mismo codarticulo,precio,y delegación
      for r in
	select max(cola.cantidad)-coalesce(sum(cancelaciones.cantidad_cancelada),0) as cantidad, cola.id, cola.pxunidad,cola.ts_registro,cola.serie,cola.num  
	from colamargenes cola 
		  left join colamargenes_cancelaciones cancelaciones on cola.id=cancelaciones.idcolamargenes
	where coddelegacion=p_coddelegacion and codarticulo=p_codarticulo and cola.idtipoop=1
		and cola.idtipodoc!=8 -- Esta restricción habría que quitarla, en cuanto se habilite el arrastre de fluctuaciones y perdidas, conforme se cancela
	group by cola.id, cola.pxunidad,cola.ts_registro,cola.serie,cola.num 
	having max(cola.cantidad)-coalesce(sum(cancelaciones.cantidad_cancelada),0)<0
	order by pxunidad desc,cola.ts_registro
      loop
      --Por cada compra negativa pendiente pendiente de cancelar ...
	p_cantidad:=abs(r.cantidad);
	p_ts:=now();
	for r2 in 
	        -- se insertan tantas cancelaciones negativas como compras en positivo se encuentren sin cancelar del mismo artículo ...
		insert into colamargenes_cancelaciones (idcolamargenes, cantidad_cancelada, idtipodoc, serie, num,ts_registro) 
		select  r.id, (-1) * coalesce(case when t.cantant+t.cantidad > p_cantidad then p_cantidad - cantant else t.cantidad end,0) as cantidad,
			11,t.serie,t.num,p_ts
		from (
			select *,coalesce(lag(cantsuma,1)over (order by cantsuma),0) as cantant 
			FROM (
				select max(cola.cantidad)-coalesce(sum(cancelaciones.cantidad_cancelada),0) as cantidad, cola.id as idcola, cola.pxunidad,cola.ts_registro,cola.serie,cola.num,
					sum(max(cola.cantidad)-coalesce(sum(cancelaciones.cantidad_cancelada),0))  over (order by cola.pxunidad desc,cola.ts_registro) as cantsuma   
				from colamargenes cola 
					  left join colamargenes_cancelaciones cancelaciones on cola.id=cancelaciones.idcolamargenes
				where coddelegacion=p_coddelegacion and codarticulo=p_codarticulo and cola.idtipoop=1 and cola.pxunidad=r.pxunidad
				      and cola.idtipodoc!=8 -- Esta restricción habría que quitarla, en cuanto se habilite el arrastre de fluctuaciones y perdidas, conforme se cancela
				group by cola.id, cola.pxunidad,cola.serie,cola.num,cola.ts_registro
				having max(cola.cantidad)-coalesce(sum(cancelaciones.cantidad_cancelada),0)>0
				order by pxunidad desc,cola.ts_registro
			) t 
		) t
		where p_cantidad-t.cantant > 0
		returning *
	loop
	-- y como ya hemos cancelado las cantidades negativas, hemos de cancelar las compras en positivo que hemos usado.
	    insert into colamargenes_cancelaciones (idcolamargenes, cantidad_cancelada, idtipodoc, serie, num,ts_registro)
	    select  cola.id, abs(r2.cantidad_cancelada) as cantidad,11,r.serie,r.num,p_ts
	    from colamargenes cola 
	    where cola.serie=r2.serie and cola.num=r2.num and cola.codarticulo=p_codarticulo
	    group by cola.id;  
	end loop; 
      end loop;
		
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;



CREATE OR REPLACE FUNCTION empresa_01.colamargenes_cancela_exportacion(character, integer, timestamp without time zone, character, numeric)
  RETURNS void AS
$BODY$
-- Dado una serie y número de albarán, así como un artículo, unos kg, y una fecha de ejecución, esto crea en la tabla colamargenes_cancelaciones
-- 1) uno o varios registros en colamargenes_cancelaciones cancelando las compras del artículo del mov de salida del contenedor en la delegación origen del mismo.
-- 2.1) Si alguna de las cancelaciones proviene de una transformación, entonces hemos de cancelar su fluctuación si la tuviese.
-- 2.2) y su pérdida si la tuviese. 
-- Los kg de fluctuación y de pérdida a cancelar serían los proporcionales a los kg de compra que vamos a cancelar. 
-- Por ejemplo, Si vamos a cancelar 80 kg de compra, y resulta que topamos con una compra con cantidad 100 Kg de compra que provienen de una transformación (idtipoop=1 and idtipodoc=8),
-- entonces hemos de cancelar el 80 % de la fluctuación asociada a esa transformación, y el 80 % de esa pérdida.

DECLARE
	p_serie alias for $1;
	p_num alias for $2;
	p_ts alias for $3;
	p_codarticulo alias for $4;
	p_cant alias for $5;
	r record;
	r2 record;
	r3 record;
	p_cantidad numeric (20,2);
	p_serienum text;
	p_coddelegacionorigen character(10);
	p_coddelegacion character(10);
	p_aplicaporcentaje numeric(20,10);
	p_cantidadIN numeric(15,2);
	p_cantidadOU numeric(15,2);
	p_cantidadBasura numeric(15,2);
	p_compracancelada integer[];
BEGIN
    p_serienum:=trim(p_serie)||'|'||p_num;
    
    select coddelegacion into p_coddelegacionorigen from exalbcab where albsalida=p_serienum; 
    if not found then
      return;
    end if;
    
    -- cancelamos las cantidades negativas que pudiera haber antes de realizar el resto de procesos
    perform colamargenes_cancela_cantidadesnegativas(coalbcab.coddelegacion,p_codarticulo) from coalbcab where seriedocumento=p_serie and numdocumento=p_num;
    --1) Se cancelan las compras del artículo en cuestión en la delegación origen del contenedor
    p_cantidad=-1 * p_cant;
   -- raise exception 'P_CODARTICULO %, P_TS %,P_CODDELEGACION %, CANTIDAD %',p_codarticulo,p_ts,p_coddelegacionorigen, P_CANTIDAD;
    
    for r in
	insert into colamargenes_cancelaciones (idcolamargenes, cantidad_cancelada, idtipodoc, serie, num,ts_registro) 
	select  t.id, coalesce(case when t.cantant + t.cantidad > p_cantidad then p_cantidad - cantant else t.cantidad end,0) as cantidad,
			4,p_serie,p_num,p_ts
	from (
		select *,coalesce(lag(cantsuma,1)over (order by cantsuma),0) as cantant 
		FROM (
			select max(cola.cantidad)-coalesce(sum(cancelaciones.cantidad_cancelada),0) as cantidad, cola.id, cola.pxunidad,cola.ts_registro,
			       sum(max(cola.cantidad)-coalesce(sum(cancelaciones.cantidad_cancelada),0))  over (order by cola.pxunidad desc,cola.ts_registro,cola.id) as cantsuma   
			from colamargenes cola 
					  left join colamargenes_cancelaciones cancelaciones on cola.id=cancelaciones.idcolamargenes
			where coddelegacion=p_coddelegacionorigen and codarticulo=p_codarticulo and cola.ts_registro<p_ts and cola.idtipoop=1
			group by cola.id, cola.pxunidad,cola.ts_registro
			having max(cola.cantidad)-coalesce(sum(cancelaciones.cantidad_cancelada),0)>0
			order by pxunidad desc,cola.ts_registro,cola.id
		) t 
	) t
	where p_cantidad-t.cantant > 0 and p_cantidad>0
	returning id,idcolamargenes,cantidad_cancelada as cantidadcancelada,serie,num
    loop
      
       -- 2.1) Por cada cantidad cancelada de compra, miramos si corresponde a una transformación
       select cola.id,cantidad as cantidadcompra,cola.serie,cola.num into r2
       from colamargenes cola
       where id=r.idcolamargenes and idtipodoc=8;

       
       if found then --proviene de una transformación=>insertar cancelaciones de fluctuación y pérdidas
	   --r2.serie y num es el albarán de transformación que hemos encontrado. las fluctuaciones y pérdidas deben de ir referidas a él
	   if r.cantidadcancelada>0 and r2.cantidadcompra>0 then
	       --Obtenemos la cantidad del artículo OU
	       
	       select cantidad,coddelegacion  into p_cantidadOU, p_coddelegacion from coalbcab 
			inner join coalblin on coalbcab.seriedocumento=coalblin.seriedocumento and coalbcab.numdocumento=coalblin.numdocumento
	       where coalbcab.seriedocumento=r2.serie and coalbcab.numdocumento=r2.num and cantidad>0 and codarticulo=p_codarticulo;  
	       
	       if found then
	          --Calculamos el pordentaje que representa los kg a cancelar,respecto a los kg del artículoOU en cuestión, 
		  p_aplicaporcentaje:=(r.cantidadcancelada/p_cantidadOU);
	       else
	          p_aplicaporcentaje:=0;
	       end if;
	      -- RAISE EXCEPTION 'FOUND %, r.idcolamargenes %, cantidadou %, aplicaporcentaje %',FOUND,r.idcolamargenes,p_cantidadOU,p_aplicaporcentaje;
	       if p_aplicaporcentaje>0.009 then
			insert into colamargenes_cancelaciones (idcolamargenes, cantidad_cancelada, idtipodoc, serie, num,ts_registro)
			select  t.id as id,  
				--Si la proporción que representa lo cancelado respecto al total del artículo OU es mayor o igual que la cantidad pendiente de fluctuación=>se cancela la fluctuación restante
			        case when (p_aplicaporcentaje * t.cantidadfluctuacion - t.cantidadpdte)>=-0.01 then t.cantidadpdte else round(p_aplicaporcentaje * t.cantidadfluctuacion,2) end as cant_cancelada,
				4 as idtipodoc,p_serie as serie,p_num as num,p_ts as ts
			from (	--Buscamos fluctuaciones de dicha transformación
				select max(cola.cantidad) as cantidadfluctuacion,max(cola.cantidad)-coalesce(sum(cancelaciones.cantidad_cancelada),0) as cantidadpdte, 
				       cola.id, cola.ts_registro
				from colamargenes cola 
					left join colamargenes_cancelaciones cancelaciones on cola.id=cancelaciones.idcolamargenes
				where cola.serie=r2.serie and cola.num=r2.num and cola.ts_registro<p_ts and cola.idtipoop=3 and codarticulo=p_codarticulo 
				group by cola.id,cola.ts_registro
				having max(cola.cantidad)-coalesce(sum(cancelaciones.cantidad_cancelada),0)>0.009
			) t;-- como no se admiten 2 artículos iguales como OU, solo se va a insertar como mucho una línea
		end if;

		--2.2) Ahora tratamos las pérdidas 
		select sum(case when cantidad<0 then cantidad * (-1) else 0 end),max(coddelegacion) as coddelegacion, --la cantidadIN la obtenemos en positivo
		       sum(case when cantidad>0 and articulos.codfamilia='00017' then cantidad  else 0 end) into p_cantidadIN, p_coddelegacion,p_cantidadBasura
		from coalbcab 
			inner join coalblin on coalbcab.seriedocumento=coalblin.seriedocumento and coalbcab.numdocumento=coalblin.numdocumento
			inner join articulos on coalblin.codarticulo=articulos.codarticulo
	        where coalbcab.seriedocumento=r2.serie and coalbcab.numdocumento=r2.num;
	       --  RAISE EXCEPTION 'FOUND %, r.idcolamargenes %, cantidadou %, aplicaporcentaje % CANTIDADBASURA %',FOUND,r.idcolamargenes,p_cantidadOU,p_aplicaporcentaje,p_cantidadBasura;
	        if found and p_cantidadBasura>0 then
	          --Calculamos el pordentaje que representa los kg a cancelar,respecto a los kg de basura y cantidad de Entrada
	          -- que porcentaje de pérdida hemos de imputar
		   p_aplicaporcentaje:=(r.cantidadcancelada * p_cantidadBAsura)/p_cantidadIN; --en este caso,p_aplicaporcentaje tiene los kg de pérdida a imputar
	        else
	           p_aplicaporcentaje:=0;
	        end if;	
		if p_aplicaporcentaje>0.009 then
		    for r2 in
			select  t.id,  
				--Si la proporción que representa lo cancelado respecto al total del artículo  es mayor o igual que la cantidad pendiente de fluctuación=>se cancela la fluctuación restante
			        case when (p_aplicaporcentaje - t.cantidadpdte)>=-0.01 then t.cantidadpdte else round(p_aplicaporcentaje,2) end as cant_cancelada,
				4 as idtipodoc,p_serie as serie,p_num as num,p_ts as ts 
			from (	--Buscamos pérdidas pendientes de cancelar en dicha transformación
				select max(cola.cantidad)-coalesce(sum(cancelaciones.cantidad_cancelada),0) as cantidadpdte, 
				       cola.id, cola.pxunidad,cola.ts_registro
				from colamargenes cola 
					left join colamargenes_cancelaciones cancelaciones on cola.id=cancelaciones.idcolamargenes
					inner join articulos on cola.codarticulo=articulos.codarticulo
				where cola.serie=r2.serie and cola.num=r2.num and cola.ts_registro<p_ts and cola.idtipoop=2
				group by cola.id, cola.pxunidad,cola.ts_registro
				having max(cola.cantidad)-coalesce(sum(cancelaciones.cantidad_cancelada),0)>0.009
			) t loop
			--no hacemos el insert ... select from, porque puede haber varios artículos basura, lo cual implica varias pérdidas por transformación y artículo
				insert into colamargenes_cancelaciones (idcolamargenes, cantidad_cancelada, idtipodoc, serie, num,ts_registro) VALUES
				(r2.id,r2.cant_cancelada,r2.idtipodoc,r2.serie,r2.num,r2.ts);
				p_aplicaporcentaje:=p_aplicaporcentaje - r2.cant_cancelada;
				exit when p_aplicaporcentaje<=0;
			end loop;
		end if;
	   end if;
       else -- no proviene de una transformación. Almacenamos en un vector por si proveniesen de una transformación heredada
	   p_compracancelada := array_append(p_compracancelada,r.id);
       end if;
    end loop;
    perform colamargenes_transformaciones_heredadas(p_compracancelada,false); --Si se hizo alguna de las cancelaciones a una compra generada por una transformación=>
									      -- se vincula también a dicho contenedor la fluctuación y pérdida que le corresonde. Se le pasa el parámetro de no crear en destino

    perform colamargenes_transformaciones_basura(p_serie,p_num,p_codarticulo,p_cantidad);-- revisar la cantidad que se le pasa, ya que no se le debería de imputar el 100 % de la pérdida a esta cantidad (p_cantidad)
											 --Al final dentro de esa función, se le imputa como mucho una fracción
   
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


  CREATE OR REPLACE FUNCTION empresa_01.colamargenes_cancela_exportacion_turcos(character, integer)
  RETURNS void AS
$BODY$

declare
   p_seriemov alias for $1;
   p_numdocmov alias for $2;
   p_serienum text;
   p_seriepallet text;
   p_numpallet integer;
   r record;
   p_serie text;
   p_numdoc integer;
   cEmp text;

begin
   -- Se le pasa la seir/número de MOV. Obtenemos la serie/num de contenedor
   select trim(codempresa) into cEmp from empresa;
   p_serienum=trim(p_seriemov)||'|'||p_numdocmov;
   
   select trim(seriedocumento),numdocumento,pespallets into p_serie, p_numdoc,p_serienum
   from exalbcab
   where albsalida=p_serienum and codempresa=cEmp;
   
   --EN P_SERIENUM ESTÁ AHORA LA SERIE Y NUM DE PALLET
   
   if not found then
      return;
   end if;
   

   p_seriepallet:=split_part(p_serienum ,'|',1);
   p_numpallet:=split_part(p_serienum,'|',2)::integer;
   --raise exception 'p_seriePALLET=%',p_serienum;

   for r in
	select distinct split_part(proalbcab.albsalida,'|',1) as seriemov, split_part(proalbcab.albsalida,'|',2)::integer as nummov 
	from copedlin inner join PROALBCAB on copedlin.facserie=proalbcab.seriedocumento and copedlin.facdocumento=proalbcab.numdocumento 
	inner join proalblin on proalbcab.seriedocumento=proalblin.seriedocumento and proalbcab.numdocumento=proalblin.numdocumento and estadoarttrans='OU'
	where copedlin.seriedocumento=p_seriepallet and copedlin.numdocumento=p_numpallet and length(proalbcab.albsalida)>1
   loop
	-- Para todas las líneas de los descuentos de las transformaciones que están vinculadas a un pallet de contenedor con cliente el turco, localizamos todos los registros en colamargenes
	-- y cancelamos. Los Movs de una transformación solo insertan registros en colamargenes los artículos OU. 
	insert into colamargenes_cancelaciones (idcolamargenes, cantidad_cancelada, idtipodoc, serie, num,ts_registro)
	select id, cantidad,14,p_seriemov,p_numdocmov,coalbcab.ts_registro
	from colamargenes,coalbcab
	where serie=r.seriemov and colamargenes.num=r.nummov and coalbcab.seriedocumento=p_seriemov and coalbcab.numdocumento=p_numdocmov and colamargenes.idtipoop=1; --material de compra
	
	-- Los registros en colamargenes pueden ser de pérdidas o fluctuaciones (las transformaciones las generan). 
	-- independientemente del tipo, el MOV de salida del contenedor pasado a esta función va a quedar cancelándolo.
	-- Cuando se haga la exportación final a turquía, tenemos que coger todo lo que hay en colamargenes del artículo/delegación, sin tener en cuenta las cancelaciones de tipo 14,15,16

	insert into colamargenes_cancelaciones (idcolamargenes, cantidad_cancelada, idtipodoc, serie, num,ts_registro)
	select id, cantidad,15,p_seriemov,p_numdocmov,coalbcab.ts_registro
	from colamargenes,coalbcab
	where serie=r.seriemov and colamargenes.num=r.nummov and coalbcab.seriedocumento=p_seriemov and coalbcab.numdocumento=p_numdocmov and colamargenes.idtipoop=2; --material de pérdida

	
	/* nO PONER EN FRAGMENTADORA HASTA QUE SE ARREGLE LO DEL PRECIO DE COMPRA DEL 11-01-04 Y 03 */
	insert into colamargenes_cancelaciones (idcolamargenes, cantidad_cancelada, idtipodoc, serie, num,ts_registro)
	select id, cantidad,16,p_seriemov,p_numdocmov,coalbcab.ts_registro
	from colamargenes,coalbcab
	where serie=r.seriemov and colamargenes.num=r.nummov and coalbcab.seriedocumento=p_seriemov and coalbcab.numdocumento=p_numdocmov and colamargenes.idtipoop=3; --material de fluctuación
	/* */
	
   end loop;   	
  perform colamargenes_transformaciones_basura(p_seriemov,p_numdocmov,proalblin.codarticulo,sum(proalblin.cantidad))
	from copedlin inner join PROALBCAB on copedlin.facserie=proalbcab.seriedocumento and copedlin.facdocumento=proalbcab.numdocumento 
	inner join proalblin on proalbcab.seriedocumento=proalblin.seriedocumento and proalbcab.numdocumento=proalblin.numdocumento and estadoarttrans='OU'
	where copedlin.seriedocumento=p_seriepallet and copedlin.numdocumento=p_numpallet and length(proalbcab.albsalida)>1
	group by proalblin.codarticulo;
   
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION empresa_01.colamargenes_cancela_exportacion_turcos(character, integer)
  OWNER TO dovalo;


CREATE OR REPLACE FUNCTION empresa_01.colamargenes_cancela_recepcion(character, integer, timestamp without time zone, character, numeric)
  RETURNS void AS
$BODY$
-- Dado una serie y número de albarán, así como un artículo, unos kg, y una fecha de ejecución, esto crea en la tabla colamargenes_cancelaciones
-- uno o varios registros en la delegación de origen del contenedor (contenedor que se busca por el campo albentrada=serie|num pasado por parámetro), cancelando compras.
-- Por otro lado crea en colamargenes unas nuevas compras en la delegación del albarán que se le pasa (p_serie y p_num). El precio a usar en dicha compra será el PMP 
-- de lo cancelado en el proceso anterior (lo que está macado por serie, num.

DECLARE
	p_serie alias for $1;
	p_num alias for $2;
	p_ts alias for $3;
	p_codarticulo alias for $4;
	p_cantidad alias for $5;
	r record;
	cEmp text;
	p_coddelegacionorigen character(15);
	p_coddelegaciondestino character(15);
	p_serienum character(20);
	p_compracancelada integer[];
	p_seriecontenedor text;
	p_numcontenedor integer;
	p_serienumsalida character(20);
	p_seriesalida text;
	p_numsalida integer;
	p_articulos_enviados character(20)[];
	
BEGIN

   --raise exception 'p_serie %,p_num %,p_ts %, p_codarticulo %,p_cantidad %',p_serie,p_num,p_ts,p_codarticulo,p_cantidad;
   p_serienum:=trim(p_serie)||'|'||p_num;
   select coddelegacion,TRIM(exalbcab.seriedocumento),exalbcab.numdocumento,exalbcab.albsalida into p_coddelegacionorigen,p_seriecontenedor,p_numcontenedor,p_serienumsalida
   from exalbcab inner join empresa on exalbcab.codempresadestino=exalbcab.codempresa
   where albentrada=p_serienum; --SACAMOS LA DELEGACIÓN ORIGEN, la serie y número de contenedor, y la serie y numero de albarán de descuento en origen
   if not found then
       return;
   end if;

   
   select coddelegacion into p_coddelegaciondestino from coalbcab where seriedocumento=p_serie and numdocumento=p_num; 
   --delegación destino donde entra la mercancía
   if not found or length(coalesce(p_serienumsalida,''))<=2 then
       return;
   end if;

   p_seriesalida :=split_part(p_serienumsalida,'|',1);
   p_numsalida :=split_part(p_serienumsalida,'|',2)::integer;

   --29/09/2014 En esta cancelación, no tiene porqué coincidir el artículo recibido en destino, con el artículo que se cancela en origen
   --Calculamos todos los artículos que se usaron en el envío para descontar el artículo que tenemos en la recepción
--RAISE EXCEPTION 'SERIECONTENEDOR=%, NUMCONTENEDOR=%,SERIESALIDA=%,NUMSALIDA=%,RECEPCIONSERIE=%,RECEPCIONNUM=%,ARTICULOS ENVIADOS%',P_SERIECONTENEDOR,P_NUMCONTENEDOR,P_SERIESALIDA,P_NUMSALIDA,P_SERIE,P_NUM,P_ARTICULOS_ENVIADOS;
   p_articulos_enviados:=  array(
		select distinct envio.codarticulo as codarticuloenvio 
		from exalblin inner join coalblin recepcion on exalblin.ordarticulo=recepcion.posarticulo and exalblin.seriedocumento=p_seriecontenedor 
		and exalblin.numdocumento=p_numcontenedor
		inner join coalblin envio on exalblin.ordarticulo=envio.posarticulo and envio.seriedocumento=p_seriesalida and envio.numdocumento=p_numsalida
		where recepcion.seriedocumento=p_serie and recepcion.numdocumento=p_num  and recepcion.codarticulo=p_codarticulo and envio.cantidad<0
	 ); 
 -- RAISE EXCEPTION 'SERIECONTENEDOR=%, NUMCONTENEDOR=%,SERIESALIDA=%,NUMSALIDA=%,RECEPCIONSERIE=%,RECEPCIONNUM=%,ARTICULOS ENVIADOS%',P_SERIECONTENEDOR,P_NUMCONTENEDOR,P_SERIESALIDA,P_NUMSALIDA,P_SERIE,P_NUM,P_ARTICULOS_ENVIADOS;

   for r in
   	    insert into colamargenes_cancelaciones (idcolamargenes, cantidad_cancelada, idtipodoc, serie, num,ts_registro) 
   	   
	    select  t.id
		    , coalesce(case when t.cantant+t.cantidad > p_cantidad then p_cantidad - cantant else cantidad end,0) as cantidad
		    ,6,p_seriesalida,p_numsalida,p_ts
	    from (
		   select *,coalesce(lag(cantsuma,1) over (order by cantsuma),0) as cantant 
		   FROM (
			  select max(cola.cantidad)-coalesce(sum(cancelaciones.cantidad_cancelada),0) as cantidad, cola.id, cola.pxunidad
				,cola.ts_registro
				,sum(max(cola.cantidad)-coalesce(sum(cancelaciones.cantidad_cancelada),0))  over (order by cola.pxunidad desc,cola.ts_registro,cola.id) as cantsuma   
			  from colamargenes cola 
				left join colamargenes_cancelaciones cancelaciones on cola.id=cancelaciones.idcolamargenes
				--inner join articulosenvio on cola.codarticulo=articulosenvio.codarticulo
			  where coddelegacion=p_coddelegacionorigen and cola.ts_registro<p_ts  and cola.idtipoop=1
			    and cola.codarticulo = any (p_articulos_enviados)
			  group by cola.id, cola.pxunidad,cola.ts_registro
			  having max(cola.cantidad)-coalesce(sum(cancelaciones.cantidad_cancelada),0)>0
			  order by pxunidad desc,cola.ts_registro,cola.id
		   ) t 
	    ) t
	    where p_cantidad-t.cantant > 0
	    returning id
    loop
	 p_compracancelada := array_append(p_compracancelada,r.id);  -- los ids de cancelados se analizarán en una función que generará en su caso, las transformaciones heredadas
    end loop;
   
   -- Ahora insertamos en colamargenes la misma cantidad pero en la otra delegación (la de destino). El precio a usar será el ponderado de las cancelaciones de la consulta anterior.
   -- En resumen, insertamos unos registros como si se hubiesen comprado. a la otra delegación.
   insert into colamargenes (coddelegacion,codarticulo, pxunidad, cantidad,idtipoop,idtipodoc,serie, num, ts_registro) 
   select p_coddelegaciondestino,p_codarticulo,sum(cola.pxunidad*cancelaciones.cantidad_cancelada)/sum(cancelaciones.cantidad_cancelada),
	sum(cancelaciones.cantidad_cancelada), 1, case when cola.idtipodoc in (8,12) then 12 else 10 end, p_serie, p_num, p_ts 
   from colamargenes cola inner join colamargenes_cancelaciones cancelaciones on cola.id=cancelaciones.idcolamargenes
   where cancelaciones.serie=p_seriesalida and cancelaciones.num=p_numsalida and cola.codarticulo = ANY(p_articulos_enviados) -- solo cancelaciones de los artículos enviados
   and cola.idtipoop=1
   group by case when cola.idtipodoc in (8,12) then 12 else 10 end
   having coalesce(sum(cancelaciones.cantidad_cancelada),0)>0; --una compra
   --si  la compra proviene de una transformación heredada [cola.idtipo in (8,12)], se marca esa compra como con tipo generada por transformación heredada. Es necesaria
   -- esta marca porque tanto esta compra como las pérdidas y fluctuaciones asociadas, deben de tratarse como transformaciones enteras.

   perform colamargenes_transformaciones_heredadas(p_compracancelada,true); --Si se hizo alguna de las cancelaciones a una compra generada por una transformación=>
									    --generamos una transformación heredada

END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION empresa_01.colamargenes_cancela_recepcion(character, integer, timestamp without time zone, character, numeric)
  OWNER TO dovalo;


CREATE OR REPLACE FUNCTION empresa_01.colamargenes_cancela_transformaciones(character, integer, timestamp without time zone, character, numeric)
  RETURNS void AS
$BODY$
-- Dado una serie y número de albarán, así como un artículo, unos kg, y una fecha de ejecución, esto crea en la tabla colamargenes_cancelaciones
-- uno o varios registros en colamargenes_cancelaciones cancelando las compras del artículo IN.
-- Por otro lado crea en colamargenes unas nuevas compras provenientes de las líneas OU del albarán que se le pasa (p_serie y p_num). 
-- El precio a usar en dicha compra será el PMP de lo cancelado en el proceso anterior (lo que está marcado por serie, num del articulo IN).
-- Una tercera acción, es insertar en colamargenes como fluctuación (idtipoop=3) la cantidad de kg del artículo OU, y con pxunidad
-- la diferencia de precio entre el artículo OU (pmp) y el artículo IN (pmp de lo cancelado).
-- Una cuarta acción es insertar en colamargenes como pérdida 

DECLARE
	p_serie alias for $1;
	p_num alias for $2;
	p_ts alias for $3;
	p_codarticulo alias for $4;
	p_cantidad alias for $5; --NO SE USA EN TODA LA FUNCIÓN. Se deja para homogenizar con respecto a otras llamadas.
	r record;
	r2 record;
	p_codfamilia character(10);
	p_precioventanilla numeric (15,2);
	p_compracancelada integer[];

BEGIN
	select concatenate(case when cantidad<0 then coalblin.codarticulo else '' end) as codartIN,min(case when coalblin.cantidad<0 then coalblin.cantidad else 0 end) * (-1) as cantidadIn,
	       concatenate(case when cantidad>0 then coalblin.codarticulo||'|'||cantidad else '' end) as codartOU, 
	       SUM(case when coalblin.cantidad>0 and coalblin.codarticulo=p_codarticulo then coalblin.cantidad else 0 end) as cantidadOU,
	       coalbcab.coddelegacion into r
	from coalbcab inner join coalblin on coalbcab.seriedocumento=coalblin.seriedocumento and coalbcab.numdocumento=coalblin.numdocumento
	where coalbcab.seriedocumento=p_serie and coalbcab.numdocumento=p_num
	group by coalbcab.seriedocumento,coalbcab.numdocumento, coddelegacion;
	
	perform cancelaciones.id from colamargenes cola inner join colamargenes_cancelaciones cancelaciones on cola.id=cancelaciones.idcolamargenes 
	where cola.codarticulo=r.codartIN and cancelaciones.serie=p_serie and cancelaciones.num=p_num and cancelaciones.idtipodoc=5;
	
	if not found  then  --Si no está creado el artículo de entrada  a la transformación=>cancelamos esa compra
	        for r2 in
			insert into colamargenes_cancelaciones (idcolamargenes, cantidad_cancelada, idtipodoc, serie, num,ts_registro) 
			select  t.id, coalesce(case when t.cantant+t.cantidad > r.cantidadIN then r.cantidadIN - cantant else cantidad end,0) as cantidad,
			           5,p_serie,p_num,p_ts
			from (
				 select *, coalesce(lag(cantsuma,1) over (order by cantsuma),0) as cantant 
				 FROM (
					select max(cola.cantidad)-coalesce(sum(cancelaciones.cantidad_cancelada),0) as cantidad, cola.id, cola.pxunidad,cola.ts_registro,
					      sum(max(cola.cantidad)-coalesce(sum(cancelaciones.cantidad_cancelada),0))  over (order by cola.pxunidad desc,cola.ts_registro,cola.id) as cantsuma   
					from colamargenes cola 
						left join colamargenes_cancelaciones cancelaciones on cola.id=cancelaciones.idcolamargenes
					where coddelegacion=r.coddelegacion and cola.codarticulo=r.codartIN and cola.ts_registro<p_ts and cola.idtipoop=1
						--and cola.idtipodoc!=8 -- Esta restricción habría que quitarla, en cuanto se habilite el arrastre de fluctuaciones y perdidas, conforme se cancela
					group by cola.id, cola.pxunidad,cola.ts_registro,cola.id
					having max(cola.cantidad)-coalesce(sum(cancelaciones.cantidad_cancelada),0)>0
					order by pxunidad desc,cola.ts_registro
				) t 
			) t
			where (r.cantidadIN-t.cantant > 0 and r.cantidadIN>0)
			returning id
		loop
		  p_compracancelada := array_append(p_compracancelada,r2.id);
		end loop;

		perform colamargenes_transformaciones_heredadas(p_compracancelada,true); --Si se hizo alguna de las cancelaciones a una compra generada por una transformación=>
									    --generamos una transformación heredada
					 
	end if;

	if r.codartIN<>p_codarticulo then -- Si es el artículo de entrada a la transformación no hacemos nada más
		-- Insertamos como compra en colamargenes la misma cantidad del artículo OU pasado. 
		-- El precio a usar será el ponderado de las cancelaciones de la consulta anterior (artículo IN).

		
		select case when articulos.codfamilia='00017' then true else false end as esbasura, r.coddelegacion as coddelegacion, p_codarticulo as codarticulo, 
		      case when t.cantidad<>0 then t.pxunidad/t.cantidad else 0 end as pxunidad,r.cantidadOU as cantidad, 1 as idtipoop, 8 as idtipodoc, p_serie as serie, p_num as num, p_ts as ts into r2 --la cantidad a poner es la del artículo OU
		from(
 		      select sum(cola.pxunidad * cancelaciones.cantidad_cancelada) as pxunidad,sum(cancelaciones.cantidad_cancelada) as cantidad
		      from colamargenes cola 
				  inner join colamargenes_cancelaciones cancelaciones on cola.id=cancelaciones.idcolamargenes 
				  
		      where cancelaciones.serie=p_serie and cancelaciones.num=p_num and cola.codarticulo=r.codartIN and cancelaciones.idtipodoc=5 
   	        ) t inner join articulos on p_codarticulo=articulos.codarticulo  -- los artículos de la familia basura se ponen con precioxunidad = 0
   	        where coalesce(t.cantidad,0)>0;
		if found then
		        insert into colamargenes (coddelegacion,codarticulo, pxunidad, cantidad,idtipoop,idtipodoc,serie, num, ts_registro) values
		        (r2.coddelegacion,r2.codarticulo,case when r2.esbasura then 0 else r2.pxunidad end,r2.cantidad,r2.idtipoop,r2.idtipodoc,r2.serie,r2.num,r2.ts);
		else
		   return;
		end if; -- pxunidad tiene el precio por unidad calculado para el artículo OU que, al que hemos creado una compra.

		-- Precio de ventanilla
		select precompra into p_precioventanilla from precioscompra where coddelegacion=r.coddelegacion and codarticulo=p_codarticulo and codtarifa=0 and estado=1;
		
		if not found then --miramos en el histórico a ver si existió al menos un precio vigente lo más reciéntemente posible, sin que haya una tarifa estado=-3 con fecha más reciente
		   select precompra into p_precioventanilla
		   from hisprecioscompra h inner join  
			(select  coddelegacion,codarticulo,max(ts_variacion) as ts_variacion
			 from hisprecioscompra 
			 where coddelegacion=r.coddelegacion and codarticulo=p_codarticulo and codtarifa=0 and ts_valid is not null
			 group by coddelegacion,codarticulo
			 having coalesce(max(case when estado=1 then ts_variacion else null end),'1900-01-01 00:00')>coalesce(max(case when estado=-3 then ts_variacion else null end),'1900-01-01 00:00') 
		   ) t
		   on h.coddelegacion=t.coddelegacion and h.codarticulo=t.codarticulo and h.ts_variacion=t.ts_variacion
		   where h.coddelegacion=r.coddelegacion and h.codarticulo=p_codarticulo and h.codtarifa=0 and h.ts_valid is not null;
		   if not found then --si no se encuentra=> ponemos que no hay fluctuación
			p_precioventanilla:= r2.pxunidad;
		   end if;
		end if;
		
		--RAISE EXCEPTION 'coddelegacion %,codartIN %,p_ts %',r.coddelegacion,r.codartIN,p_ts;
		if abs(p_precioventanilla-r2.pxunidad)>=0.01 then --solo si hay fluctuación insertamos tal fluctuación
		-- Ahora calculamos la fluctuación que insertaremos en colamargenes.
			insert into colamargenes (coddelegacion,codarticulo, pxunidad, cantidad,idtipoop,idtipodoc,serie, num, ts_registro) 
			select r.coddelegacion, p_codarticulo, p_precioventanilla - r2.pxunidad, r2.cantidad, 3, 8, p_serie, p_num, p_ts --la fluctuación si es positiva es una transformación rentable
			from articulos
			where codarticulo=p_codarticulo and codfamilia<>'00017' and r2.cantidad>0;
		end if;

		--Ahora calculamos la pérdida que insertaremos en colamargenes. La pérdida son los Kg del artículo OU de la transformación,
		-- por el precio que hemos cancelado del artículo IN
		insert into colamargenes (coddelegacion,codarticulo, pxunidad, cantidad,idtipoop,idtipodoc,serie, num, ts_registro) 
		select r.coddelegacion, p_codarticulo, r2.pxunidad, r2.cantidad, 2, 8, p_serie, p_num, p_ts  --la pérdida será siempre positiva
		from articulos
		where codarticulo=p_codarticulo and codfamilia='00017' and r2.cantidad>0;   
	end if;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;



CREATE OR REPLACE FUNCTION empresa_01.colamargenes_inicializa()
  RETURNS void AS
$BODY$

DECLARE
	r record;
	r2 record;
	cEmp text;
BEGIN
  select trim(codempresa) into cEmp from empresa;
  for r in select coddelega as coddelegacion,codarticulo,stkreal from stocks where stkreal>0 order by coddelega,codarticulo loop

	insert into colamargenes (coddelegacion,codarticulo, pxunidad, cantidad,idtipoop,idtipodoc,serie, num,ts_registro)
	select t.coddelegacion,t.codarticulo,t.precompra as precompra
		,coalesce(case when cantant+cantidad>r.stkreal then r.stkreal-cantant else cantidad end,0) as cantidad,
		1,7,t.seriedocumento,t.numdocumento,t.ts_registro
	from (
		select *,coalesce(lag(cantsuma,1)over (order by cantsuma),0) as cantant 
		FROM (
			select 	coalbcab.coddelegacion,coalblin.codarticulo,avg(coalblin.precompra) as precompra,sum(coalblin.cantidad) as cantidad,1 as idtipoop,7 as idtipodoc,
				coalbcab.seriedocumento,coalbcab.numdocumento, sum(sum(coalblin.cantidad))  over (order by avg(coalblin.precompra) desc,coalbcab.ts_registro) as cantsuma   
				,coalbcab.ts_registro
			from coalbcab inner join coalblin on coalbcab.seriedocumento=coalblin.albserie and coalbcab.numdocumento=coalblin.albdocumento
			     INNER JOIN SERIESCOMPRAS ON COALBCAB.SERIEDOCUMENTO=SERIESCOMPRAS.CODSERIE AND SERIESCOMPRAS.ctrlcaja AND SERIESCOMPRAS.CTRLSTK
			WHERE coalbcab.tipofpago<>'DONACION' and coalblin.cantidad>0 and coalblin.ts_registro>'2013-07-01 00:00:00' 
			      and coalblin.codarticulo=r.codarticulo and coalbcab.coddelegacion=r.coddelegacion
			group by coalbcab.seriedocumento,coalbcab.numdocumento,coalbcab.coddelegacion,coalblin.codarticulo,coalbcab.ts_registro 
	      ) t 
	) t
	where r.stkreal-cantant>0;
    /*
	--En la siguiente consulta introduciremos las compras generadas por transformaciones y recepción de contenedores
	--insert into colamargenes (coddelegacion,codarticulo, pxunidad, cantidad,idtipoop,idtipodoc,serie, num,ts_registro)
	for r2 in 
	select  coddelegacion,codarticulo,cantidad,tipoop, tipodoc, seriedocumento,numdocumento, ts_registro
	from (
	    select * 
		from(    
			--Entradas de otras delegaciones (el precio lo vamos a dejar a 0 (lo actualizaremos en pasos posteriores)
			select 	coalbcab.coddelegacion,coalblin.codarticulo,0 as precompra,sum(coalblin.cantidad) as cantidad,1 as tipoop, 10 as tipodoc, coalbcab.seriedocumento,coalbcab.numdocumento  
				,coalbcab.ts_registro
			from coalbcab inner join coalblin on coalbcab.seriedocumento=coalblin.albserie and coalbcab.numdocumento=coalblin.albdocumento
				      inner join exalbcab on char_length(coalesce(exalbcab.albsalida,''))>1 and char_length(coalesce(exalbcab.albentrada,''))>1 and 
					    exalbcab.codempresa=exalbcab.codempresadestino and exalbcab.codempresa=cEmp
			              inner join docvinculos(2,cEmp,'',0) as t(seriedoc character(10),numdoc integer,serielink character(10),numlink integer) on 
			                  t.seriedoc=exalbcab.seriedocumento and t.numdoc=exalbcab.numdocumento and coalbcab.seriedocumento=t.serielink and coalbcab.numdocumento=t.numlink
			WHERE coalblin.cantidad>0 and coalbcab.ts_registro>'2014-07-01 00:00:00' and coalblin.codarticulo=r.codarticulo 
			      and coalbcab.coddelegacion=r.coddelegacion
			group by coalbcab.seriedocumento,coalbcab.numdocumento,coalbcab.coddelegacion,coalblin.codarticulo,coalbcab.ts_registro 
			union -- Entradas por transformaciones. el precio se queda a 0, pendiente de recalcular en otro proceso.
			select 	coalbcab.coddelegacion,coalblin.codarticulo,0 as precompra,sum(coalblin.cantidad) as cantidad,1 tipoop, 8 as tipodoc, coalbcab.seriedocumento,coalbcab.numdocumento  
				,coalbcab.ts_registro
			from coalbcab inner join coalblin on coalbcab.seriedocumento=coalblin.albserie and coalbcab.numdocumento=coalblin.albdocumento
				      inner join proalbcab on char_length(coalesce(proalbcab.albsalida,''))>1 and char_length(coalesce(proalbcab.albsalida,''))>1
					    and proalbcab.albsalida=trim(coalbcab.seriedocumento)||'|'||coalbcab.numdocumento
			WHERE coalblin.cantidad>0 and coalbcab.ts_registro>'2014-07-01 00:00:00' and coalblin.codarticulo=r.codarticulo 
			      and coalbcab.coddelegacion=r.coddelegacion
			group by coalbcab.seriedocumento,coalbcab.numdocumento,coalbcab.coddelegacion,coalblin.codarticulo,coalbcab.ts_registro 
		) t order by t.ts_registro
	) t loop

	  if r2.tipodoc=10 then --transformaciones
	      perform colamargenes_cancela_transformaciones(r2.seriedocumento,r2.numdocumento,r2.ts_registro,r2.codarticulo,r2.cantidad);
	  else --recepciones
	      perform colamargenes_cancela_recepcion(r2.seriedocumento,r2.numdocumento,r2.ts_registro,r2.codarticulo,r2.cantidad);
	  end if;
	end loop;
	*/
  end loop;
  
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION empresa_01.colamargenes_inicializa()
  OWNER TO dovalo;


CREATE OR REPLACE FUNCTION empresa_01.colamargenes_inicializa_correccion()
  RETURNS void AS
$BODY$

DECLARE
	r record;
	r2 record;
	p_ts timestamp;
BEGIN

  select min(ts_now) into p_ts
  from colamargenes;

  
  for r in select coddelega as coddelegacion,codarticulo,stkreal from stocks where stkreal>0 AND CODDELEGA='ARI' 
		  AND CODARTICULO IN ('01-03', '01-04', '01-06', '01-15', '01-16', '01-17', '01-18', '02-01', '02-02', '02-02', '02-02', '02-04', '02-08', '02-12', '02-13', '02-14', '02-15', '04-01', '05-01', '05-01', '26-02', '26-02', '26-10', '01-06-01',
		   '01-06', '01-04', '02-08-01', '02-07', '11-03', '02-11', '02-15-01', '02-15-01', '11-01', '26-02-01', '26-02', '26-03')
		 order by coddelega,codarticulo loop

	select pmedio/variacion as precio, pmedio,variacion into r2
	from (
		select coalesce(sum(precompra * case when cantant+cantidad>stkreal then stkreal-cantant else cantidad end),0) as pmedio, max(stkreal) as variacion
		from (
			select *,coalesce(lag(cantsuma,1)over (order by cantsuma),0) as cantant 
			FROM (
				select  coalbcab.fechadoc,coalbcab.seriedocumento,coalblin.cantidad, coalblin.precompra,coalbcab.numdocumento,coalblin.codarticulo,r.stkreal as STKREAL,  
					sum(coalblin.cantidad)  over (order by coalblin.ts_registro desc) as cantsuma,coalblin.ts_registro
				from coalbcab inner join coalblin on coalbcab.seriedocumento=coalblin.albserie and coalbcab.numdocumento=coalblin.albdocumento
					INNER JOIN SERIESCOMPRAS ON COALBCAB.SERIEDOCUMENTO=SERIESCOMPRAS.CODSERIE AND SERIESCOMPRAS.ctrlcaja AND SERIESCOMPRAS.CTRLSTK
				WHERE COALBCAB.CODDELEGACION=r.coddelegacion AND COALBLIN.CODARTICULO=r.codarticulo  and coalbcab.tipofpago<>'DONACION' --and coalblin.tsregistro<p_tsfecha
				order by coalblin.ts_registro desc) t
			) t
		where t.stkreal-cantant>0
	)   t;

	update colamargenes  set pxunidad=r2.precio 
	from ( select cola.id
	       from colamargenes cola inner join colamargenes_cancelaciones cancelaciones on cola.id=cancelaciones.idcolamargenes
	       where cola.coddelegacion=r.coddelegacion and cola.codarticulo=r.codarticulo and  cancelaciones.serie='MOV' AND 
	          CANCELACIONES.NUM=341490
	     ) t 
	where colamargenes.id=t.id and colamargenes.coddelegacion=r.coddelegacion and colamargenes.codarticulo=r.codarticulo;
  
  end loop;
 
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;



CREATE OR REPLACE FUNCTION empresa_01.colamargenes_transformaciones_basura(character, integer, character, numeric)
  RETURNS void AS
$BODY$
-- se le pasa una serie y num de albarán,así como un código de artículo y cantidad. Devolverá cancelaciones de pérdida en transformaciones directas de basura.
-- Transformaciones directas a basura, son transformacione del artículo 11-01 (o cualquier artículo del hierro en Fragmentadora) en SÓLO	artículos de la familia BASURA (00017)
-- Se ha de llamar a esta función únicamente cuando se exporta un contenedor
declare
	p_serie alias for $1; 
	p_num alias for $2; 
	p_codarticulo alias for $3;
	p_cantidad alias for $4;
	p_fragmentadora boolean;
	p_art_aplica_dto_basura boolean;				  
	p_cant numeric(20,2);
	r record;
	r2 record;
begin

     p_cant:= round(0.2 * (p_cantidad /0.8),2); -- usamos esta variable para saber lo que debemos descontar de perdida conforme con el ratio de la primera línea
												-- 20% de la cantidad que usamos originalmente para descontar, la cual es el 80 % de la original
     
     --0.24847616423257095619; -- este es el porcentaje que se corresponde con la basura que se generó respecto al hierro que se exportó desde el comienzo de 2014 hasta el 28/07/2014
     select case when trim(cif)='B35689991' then true else false end into p_fragmentadora from empresa;
     if not found then
        p_fragmentadora:=false;
     end if;  
     --2014-09-10 no imputar pérdidas a artículos de desecho
     select (not p_fragmentadora and p_codarticulo in ('11-01','11-03')) or (p_fragmentadora and articulos.codfamilia='00011' and articulos.codarticulo not like '11-04-%') into p_art_aplica_dto_basura 
     from articulos
     where codarticulo=p_codarticulo;

    if not coalesce(p_art_aplica_dto_basura,false) then --Si no es hierro o familia del hierro
      return;
    end if;
        
           
     
     for r in --transformaciones directas en basura en colamargenes pendientes de cancelar
     select t.* from (
	select colabasura.id, colabasura.ts_registro, colabasura.serie,colabasura.num,max(cola.codarticulo) as articuloIN,colapdte.pxunidad,colabasura.codarticulo,colapdte.cantpdte
	from colamargenes cola inner join colamargenes_cancelaciones cancelaciones on cola.id=cancelaciones.idcolamargenes and cancelaciones.idtipodoc=5
		inner join colamargenes colabasura on cancelaciones.serie=colabasura.serie and cancelaciones.num=colabasura.num and colabasura.idtipodoc=8 --transformaciones
		inner join articulos on colabasura.codarticulo=articulos.codarticulo
		inner join --ahora comprobamos que la transformación (serie,num de colabasura) esté sin cancelar
			(select cola.id,max(cola.cantidad)-coalesce(sum(cancelaciones.cantidad_cancelada),0) as cantpdte,cola.pxunidad
			 from colamargenes cola left join colamargenes_cancelaciones cancelaciones on cola.id=cancelaciones.idcolamargenes
			 where cola.idtipoop=2 -- solo lo pendiente de cancelar de basura (perdida=2)
			 group by cola.id,cola.pxunidad
			 having max(cola.cantidad)-coalesce(sum(cancelaciones.cantidad_cancelada),0)>0.009
			) colapdte on colabasura.id=colapdte.id  -- que no estén canceladas
		inner join (
			select seriedocumento,numdocumento
			from coalblin inner join articulos on coalblin.codarticulo=articulos.codarticulo
			where seriedocumento='MOV' AND cantidad>0 --SOLO LAS LÍNEAS OU DE ALBARANES DE TRANSFORMACIÓN
			group by seriedocumento,numdocumento
			having sum(case when articulos.codfamilia='00017' then 1 else 0 end)=count(*) --solo las transformaciones en las que todas sus líneas OU sean de la familia basura
		) c
		on colabasura.serie=c.seriedocumento and colabasura.num=c.numdocumento
	group by colabasura.id, colabasura.ts_registro,colabasura.serie,colabasura.num,colapdte.cantpdte,colapdte.pxunidad,colabasura.codarticulo
	) t inner join articulos on t.articuloIN=articulos.codarticulo
	where case when p_fragmentadora then articulos.codfamilia='00011' else articulos.codarticulo='11-01' end --and colabasura.idtipoop=2
	order by t.pxunidad desc,t.num,t.articuloIN
     loop
         if p_cant>0 then
            insert into colamargenes_cancelaciones (idcolamargenes, cantidad_cancelada, idtipodoc, serie, num,ts_registro)  
	        select r.id, case when (p_cant - r.cantpdte)>=-0.01 then r.cantpdte else round(p_cant,2) end, 13, p_serie,p_num,ts_registro
	        from coalbcab where seriedocumento=p_serie and numdocumento=p_num and coalbcab.ts_registro>r.ts_registro --para que se cancelen solo documentos anteriores
	        returning cantidad_cancelada into r2;
	        if found then
	           p_cant:=p_cant-r2.cantidad_cancelada;
	        end if;
         end if;
         exit when  p_cant<=0; --salimos del bucle, cuando ya hayamos descontado toda la cantidad, o se termine de iterar en el for
     end loop;
     return;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


CREATE OR REPLACE FUNCTION empresa_01.colamargenes_transformaciones_heredadas(integer[], boolean)
  RETURNS void AS
$BODY$
declare
	p_ids alias for $1; --cancelaciones de compras que se han hecho(sobre las cancelaciones que provengan de transformaciones/transformaciones heredadas, se iterará)
	p_generacionendestino alias for $2; --indica si generar fluctauciones y perdidas en destino 
					   -- (True para recepciones de material y transformaciones. False para exportaciones)
	p_aplicaporcentaje numeric(20,10);
	p_cantidadIN numeric(15,2);
	p_cantidadBasura numeric (15,2);
	p_cant numeric(20,2);
	r record;
	r2 record;
begin


  --p_ids:=array(select id  from colamargenes where id in (152879,152880,152881));

  --raise exception 'id= %',array_to_string(p_ids,', ');
  --los enteros que se pasan en el vector por parámetro, se corresponden con ids de canclaciones de compra.
  --Por cada línea de compra cancelada que pertenezca a una transformación/transformación heredada, generamos su correspondiente compra,fluctuación y pérdida en la delegación.

   for r in 
	select cola.coddelegacion,cola.codarticulo,cola.id as idcola,cola.pxunidad,cancelaciones.id
	       ,cola.cantidad as cantidad_cola,cancelaciones.cantidad_cancelada as cantidad_cancelada,cola.pxunidad
	       ,cancelaciones.ts_registro,cola.serie as seriecola,cola.num as numcola, cancelaciones.serie as seriecancelacion
	       ,cancelaciones.num numcancelacion,cancelaciones.ts_registro -- solo nos sirve el ts de cancelación.
	       ,cola.idtipodoc
	from colamargenes cola inner join colamargenes_cancelaciones cancelaciones on cola.id=cancelaciones.idcolamargenes
	where cola.idtipodoc in (8,12) and cancelaciones.id in (select unnest(p_ids))
   loop
	--1.1) tratamos las fluctuaciones
	if r.cantidad_cola>0 then
		p_aplicaporcentaje:=(r.cantidad_cancelada/r.cantidad_cola);
	else
	        p_aplicaporcentaje:=0;
	end if;
	 
	 -- cancelamos la antigua fluctuación
	 if p_aplicaporcentaje>0.009 then
	        p_cant:=0;
		for r2 in --por cada cancelación de una compra proveniente de una transformación / transformación heredada, cancelamos la correspondiente fluctuación ... (puede haber más de una fluctuación?)
			select  t.id,  
			        case when (p_aplicaporcentaje * t.cantidadfluctuacion - t.cantidadpdte)>=-0.01 then t.cantidadpdte else round(p_aplicaporcentaje * t.cantidadfluctuacion,2) end as cantidad_cancelada,
				r.idtipodoc as idtipodoc, r.seriecancelacion as seriecancelacion,r.numcancelacion as numcancelacion,r.ts_registro as ts_registro,
				sum(cantidadpdte) over () as cantidadpdte,t.pxunidad
			from (	--Buscamos fluctuaciones de dicha transformación
				select max(cola.cantidad) as cantidadfluctuacion,max(cola.cantidad) - coalesce(sum(cancelaciones.cantidad_cancelada),0) as cantidadpdte, 
				       cola.id, cola.ts_registro,cola.pxunidad
				from colamargenes cola 
					left join colamargenes_cancelaciones cancelaciones on cola.id=cancelaciones.idcolamargenes
				where cola.serie=r.seriecola and cola.num=r.numcola and cola.idtipoop=3 and codarticulo=r.codarticulo 
				group by cola.id,cola.ts_registro,cola.pxunidad
				having max(cola.cantidad)-coalesce(sum(cancelaciones.cantidad_cancelada),0)>0.009
			) t
		loop 
		     
		     --raise exception 'aplicaporcentaje= %, p_aplicaporcentaje * r2.cantidadpdte= %,p_cant=%',p_aplicaporcentaje,p_aplicaporcentaje * r2.cantidadpdte, p_cant;
		     if (p_aplicaporcentaje * r2.cantidadpdte) - p_cant>0 then
			insert into colamargenes_cancelaciones (idcolamargenes, cantidad_cancelada, idtipodoc, serie, num,ts_registro) values
			(r2.id,r2.cantidad_cancelada - p_cant,12,r2.seriecancelacion,r2.numcancelacion,r2.ts_registro);
	        
			if p_generacionendestino then
		-- ... y luego (la fluctuación cancelada) la volvemos  a generar en colamargenes como fluctuación en la delegación de destino, como generada por el documento serie y num 
		--     de la cancelación original de la compra (r.seriecancelacion,r.numcancelacion)
				insert into colamargenes (coddelegacion,codarticulo, pxunidad, cantidad,idtipoop,idtipodoc,serie, num, ts_registro)
				select coalbcab.coddelegacion,r.codarticulo,r2.pxunidad,r2.cantidad_cancelada - p_cant,3,12,r.seriecancelacion,r.numcancelacion,r.ts_registro
				from coalbcab
				where coalbcab.seriedocumento=r.seriecancelacion and coalbcab.numdocumento=r.numcancelacion;
			end if;
			p_cant:= p_cant + r2.cantidad_cancelada;
			
		     end if;
		end loop;
	 end if;


	--1.2) Ahora tratamos las pérdidas 
	     
		select sum(cantidad), -- 
		       sum(case when cantidad>0 and articulos.codfamilia='00017' then cola.cantidad  else 0 end) into p_cantidadIN,p_cantidadBasura
		from colamargenes cola inner join articulos on cola.codarticulo=articulos.codarticulo
	        where cola.serie=r.seriecola and cola.num=r.numcola and idtipoop in (1) and idtipodoc=r.idtipodoc; 
	        -- todas las compras generadas por r.seriecola y r.numcola equivale a la cantidad IN (=cantidad de los articulos OU).
	        -- Los artículos OU de basura también se ponen como compras (tipoop=1). 
	        
	       --  RAISE EXCEPTION 'FOUND %, r.idcolamargenes %, cantidadou %, aplicaporcentaje % CANTIDADBASURA %',FOUND,r.idcolamargenes,p_cantidadOU,p_aplicaporcentaje,p_cantidadBasura;
	        if found and p_cantidadBasura>0 then
	          --Calculamos el pordentaje que representa los kg a cancelar,respecto a los kg de basura y cantidad de Entrada
	          -- que porcentaje de pérdida hemos de imputar
		   p_aplicaporcentaje:=(r.cantidad_cancelada * p_cantidadBAsura)/p_cantidadIN; --en este caso,p_aplicaporcentaje tiene los kg de pérdida a imputar
	        else
	           p_aplicaporcentaje:=0;
	        end if;	
		if p_aplicaporcentaje>0.009 then
		   p_cant:=0;
		   for r2 in
			select  t.id,  
				--Si la proporción que representa lo cancelado respecto al total del artículo  es mayor o igual que la cantidad pendiente de fluctuación=>se cancela la fluctuación restante
			        case when (p_aplicaporcentaje - t.cantidadpdte)>=-0.01 then t.cantidadpdte else round(p_aplicaporcentaje,2) end as cantidad_cancelada,
				r.idtipodoc as idtipodoc, r.seriecancelacion as seriecancelacion,r.numcancelacion as numcancelacion,r.ts_registro as ts_registro,t.codarticulo
			from (	--Buscamos pérdidas pendientes de cancelar en dicha transformación
				select max(cola.cantidad)-coalesce(sum(cancelaciones.cantidad_cancelada),0) as cantidadpdte,cola.id,cola.codarticulo
				from colamargenes cola 
					left join colamargenes_cancelaciones cancelaciones on cola.id=cancelaciones.idcolamargenes
					inner join articulos on cola.codarticulo=articulos.codarticulo
				where cola.serie=r.seriecola and cola.num=r.numcola  and cola.idtipoop=2 
				group by cola.id,cola.ts_registro,cola.codarticulo
				having max(cola.cantidad)-coalesce(sum(cancelaciones.cantidad_cancelada),0)>0.009
			) t 
		   loop
			
			 if p_aplicaporcentaje-p_cant>0 then
				insert into colamargenes_cancelaciones (idcolamargenes, cantidad_cancelada, idtipodoc, serie, num,ts_registro) values
				(r2.id,p_aplicaporcentaje-p_cant,12,r2.seriecancelacion,r2.numcancelacion,r2.ts_registro);

			  	if p_generacionendestino then
		-- ... y luego (la perdida cancelada) la volvemos  a generar en colamargenes como pérdida en la delegación de destino, como generada por el documento serie y num 
		--     de la cancelación original de la compra (r.seriecancelacion,r.numcancelacion)
					insert into colamargenes (coddelegacion,codarticulo, pxunidad, cantidad,idtipoop,idtipodoc,serie, num, ts_registro)
					select coalbcab.coddelegacion,r2.codarticulo,r.pxunidad,p_aplicaporcentaje-p_cant,2,12,r.seriecancelacion,r.numcancelacion,r.ts_registro
					from coalbcab
					where seriedocumento=r.seriecancelacion and numdocumento=r.numcancelacion;
				end if;
			 end if;
			 p_cant:= p_cant + r2.cantidad_cancelada;
			
		   end loop;
		end if;
   end loop;
 
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

ALTER FUNCTION empresa_01.colamargenes_transformaciones_heredadas(integer[], boolean)
  OWNER TO dovalo;




  CREATE OR REPLACE FUNCTION empresa_01.contab_actualizar_cuentas_con_contaplus(integer, character)
  RETURNS void AS
$BODY$

declare 
        p_anio alias for $1;
        p_secciones alias for $2;
        -- Las secciones se identifican con un campo de tipo texto en donde cada
        -- posicion en la cadena representa una seccion.
        -- Un - (guion medio) representa que NO se procesa y 
        -- una X (equis) representa que SI se procesa esa seccion.
        -- Pos.  1 -- Asociacion de cuentas_contaplus a la tabla cuentas
        -- Pos.  2 -- Clientes Exportacion
        -- Pos.  3 -- Proveedores
        -- Pos.  4 -        Correcciones fechas albaranes - facturas compra 
        -- Pos.  5 -        Pagos alb compra no facturados
        -- Pos.  6 -- Clientes interiores
        -- Pos.  7 -        Vencimientos en ventas
        -- Pos.  8 -- Acreedores
        -- Pos.  9 -        Pagos a acreedores
        -- Pos. 10 -        Vales        
        
	cSql text;
begin
-- ******************************************************************************************
-- Se espera una tabla "cuentas_contaplus" con la misma estructura que la tabla cuentas.
-- El contenido de esta tabla será los datos del fichero "subcta" del contaplus, del que sólo
-- se han extraido los campos de:
--   * cuenta contable
--   * nombre de la cuenta
--   * nif asociado
-- ******************************************************************************************
--  NOTA
-- Se parte de la idea de que los datos que hay en la tabla de cuentas estará bien de los años
-- anteriores. Si se detectara algún error, arrastrado de años anteriores, se corregirá puntualmente
-- ******************************************************************************************

-- TRIGGERS QUE HABRIA QUE CREAR --
-- Asignacion de cuenta contable en las facturas de exportacion
-- verificar tipo de impuesto en facturas de exportacion -> 0X

-- #################
-- #################
-- ### SECCION 1 ###
-- #################
if (substring(p_secciones,1,1) = 'X') then 
-- #################


--Ponemos la numeración inicial de la tabla cuentas (campo codcuenta)
perform nextcodcuenta(true);
----------------------------------------------------------------------------------
--- completar la tabla cuentas ---------------------------------------------------
----------------------------------------------------------------------------------
-- Insertamos una cuenta "nula" para identificar aquello que no está vinculado a
-- contabilidad y además no debe reasignarse de forma automática en ningún momento
insert into cuentas (codcuenta, nomcuenta, ctadestino, nif) 
select '-----' as codcuenta, '-----' as nomcuenta, '000000000' as ctadestino, ''::text as nif
where '-----' not in (
	select distinct trim(codcuenta) as codcuenta 
	from cuentas
	where codcuenta is not null
	);

-- Corregimos un error arrastrado de traspasos de años anteriores. Se podían asignar
-- cuentas de forma automática, pero si no tenían nada que traspasar, esas cuentas no 
-- se creaban en contaplus. Si posteriormente meten datos manualmente en contaplus,
-- los números de cuenta puede que no coincidan para un mismo NIF entre dovalo <-> contaplus
-- Hay que excluir de aquí las empresas del grupo.
update cuentas set ctadestino = cp.ctadestino
	from cuentas_contaplus cp
	where cuentas.nif = cp.nif
	and substring(cuentas.ctadestino,1,5) = substring(cp.ctadestino,1,5)
	and cuentas.ctadestino is not null
	and cp.ctadestino is not null
	and char_length(trim(cuentas.ctadestino)) = 9
	and cuentas.ctadestino != cp.ctadestino 
	and cuentas.nif not in ('B35855543','B35689991','B35066273');

update cuentas set nif = cp.nif
	from cuentas_contaplus cp
	where cuentas.ctadestino = cp.ctadestino
	and cuentas.ctadestino is not null
	and cp.ctadestino is not null
	and char_length(trim(cuentas.ctadestino)) = 9
	and trim(cuentas.nif) != trim(cp.nif) 
	and cuentas.nif not in ('B35855543','B35689991','B35066273');
	
-- Si se detectan NIFs duplicados en la tabla cuentas para un mismo grupo, se considerará
-- que hay algún error arrastrado de otros años. Como no sabemos cuál está correcto o cuál
-- no, lo que hacemos es borrar todos duplicados.
delete from cuentas 
where ( select concatenate(cuentas) from (
	select  concatenate(codcuenta) as cuentas 
	from cuentas where ctadestino like '4100%' group by nif
	having count(*) > 1
	UNION 
	select  concatenate(codcuenta) as cuentas 
	from cuentas where ctadestino like '4000%' group by nif
	having count(*) > 1
	UNION 
	select  concatenate(codcuenta) as cuentas 	
	from cuentas where ctadestino like '4300%' group by nif
	having count(*) > 1
--	UNION
--	select  concatenate(codcuenta) as cuentas 	
--	from cuentas where ctadestino like '4070%' group by nif
--	having count(*) > 1

	) as ctas_1)
	like '%' || trim(codcuenta) || '%' ;  

-- Insertamos aquellas cuentas que existen en contaplus y que no están en cuentas.
-- La secuencia de codcuenta se controla con el DEFAULT en la propia tabla.
insert into cuentas (nomcuenta, ctadestino, nif) 
select cp.nomcuenta, cp.ctadestino, cp.nif
from cuentas_contaplus cp
where trim(cp.ctadestino) not in (
	select distinct trim(ctadestino) as ctadestino 
	from cuentas
	where ctadestino is not null
	)
order by ctadestino;

	-- generar idpadre3
update cuentas 
	set idpadre3=cuentas2.codcuenta 
	from cuentas as cuentas2 
	where char_length(cuentas.ctadestino)=9 and 
	substring(cuentas.ctadestino,1,3) = cuentas2.ctadestino and
	(cuentas.idpadre3 is null or char_length(trim(cuentas.idpadre3))=0 
	or cuentas.idpadre3='0');
	-- generar idpadre1
update cuentas 
	set idpadre1=cuentas2.codcuenta 
	from cuentas as cuentas2 
	where char_length(cuentas.ctadestino)=9 and 
	substring(cuentas.ctadestino,1,1) = cuentas2.ctadestino and
	(cuentas.idpadre1 is null or char_length(trim(cuentas.idpadre1))=0 
	or cuentas.idpadre1='0');

-- #################
end if;
-- #################
-- ### SECCION 1 ###
-- #################
-- #################

-- #################
-- #################
-- ### SECCION 2 ###
-- #################
if (substring(p_secciones,2,1) = 'X') then 
-- #################
----------------------------------------------------------------------------------
--- EXPORTACIONES (tipo 10) ------------------------------------------------------
----------------------------------------------------------------------------------
-- actualizar el nombre de la cuenta y el nif, para aquello que difiera del 
-- contaplus. La asignacion de cuentas de contaplus es lo que prevalece.


update cuentas
	set nomcuenta = cp.nomcuenta, nif=cp.nif
	from cuentas_contaplus cp
	where cuentas.ctadestino = cp.ctadestino 
	and cuentas.ctadestino like '4300%'
	and (cuentas.nomcuenta != cp.nomcuenta or cuentas.nif != cp.nif);

update clientesexp set codcontable = ctas.codcuenta
	from cuentas ctas
	where trim(clientesexp.nif)::text = trim(ctas.nif)::text and 
	ctas.ctadestino like '4300%' and
	(clientesexp.codcontable is null or char_length(trim(clientesexp.codcontable))=0
	or clientesexp.codcontable != ctas.codcuenta);

-- Entre empresas del grupo no se emiten facturas de exportacion
update clientesexp set codcontable = '-----' 
	where nif in ('B35855543','B35689991','B35066273');
update clientesexp set codcontable = '-----' 
	where codclienteexp = '0001';

-- 
update clientesexp set codcontable = '00000' where nif in (
	select cx.nif from clientesexp cx 
	left join cuentas ct on cx.nif = ct.nif and ct.ctadestino like '4300%'
	where cx.codcontable != '-----' and ct.nif is null );
	
-- Ahora, los clientes de exportacion que no tienen una cuenta contable asociada
-- son los que tenemos que crearle y asociarle una nueva.
--create temp sequence secctacontable;
--perform setval('secctacontable', max(ctadestino::integer)) 
--	from cuentas
--	where char_length(cuentas.ctadestino)=9 and cuentas.ctadestino like '4300%';
perform nextcodcontable('4300',true); --se reinicia la secuencia de asignación de cuentas contables
insert into cuentas (nomcuenta,nif,ctadestino)
	select nomclienteexp, nif, nextcodcontable('4300',false)  --nextval('secctacontable')::character(12)
	from clientesexp cli
	where char_length(codcontable)!=5 or codcontable='00000';
--drop sequence secctacontable;		

update clientesexp set codcontable = cuentas.codcuenta 
	from cuentas
	where clientesexp.nif is not null and clientesexp.nif != '' 
	and cuentas.ctadestino like '4300%' and char_length(ctadestino)=9
	and cuentas.nif = clientesexp.nif
	and (clientesexp.codcontable is null or clientesexp.codcontable = '00000' 
	or char_length(clientesexp.codcontable)=0);
	
-- Todas las exportaciones son de chatarra a la peninsula
-- Se desactivan trigger que provocan conflictos al completar lo siguiente
DROP TRIGGER exfaccab_02_valor_contenedores ON empresa_01.exfaccab;

update exfaccab set codcontable = ctas.codcuenta
	from cuentas ctas 
	where ctas.ctadestino = '700000001' and
		(exfaccab.codcontable = '00000' or exfaccab.codcontable is null);

CREATE TRIGGER exfaccab_02_valor_contenedores
  AFTER UPDATE
  ON empresa_01.exfaccab
  FOR EACH ROW
  EXECUTE PROCEDURE empresa_01.exfaccab_valor_contenedores();



-- #################
end if;
-- #################
-- ### SECCION 2 ###
-- #################
-- #################

-- #################
-- #################
-- ### SECCION 3 ###
-- #################
if (substring(p_secciones,3,1) = 'X') then 
-- #################
		
----------------------------------------------------------------------------------
-- EXPORTACIÓN PROVEEDORES 
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
-- actualizar el nombre de la cuenta y el nif, para aquello que difiera del 
-- contaplus. La asignacion de cuentas de contaplus es lo que prevalece.
update cuentas
	set nomcuenta = cp.nomcuenta, nif=cp.nif
	from cuentas_contaplus cp 
	where cuentas.ctadestino = cp.ctadestino 
	and cuentas.ctadestino like '4000%'
	and (cuentas.nomcuenta != cp.nomcuenta or cuentas.nif != cp.nif);


--Creamos los proveedores que van a conformar la 400.0
create temp table tmpproveedorescontado 
(
  codproveedor character (10),
  nomproveedor character varying(140),
  nif character (16),
  numfacturacontados integer,
  tmpproveedorescontado numeric(13,2)
);

cSql:=	'insert into tmpproveedorescontado ';
cSql:=cSql||'	(codproveedor, nomproveedor, nif, numfacturacontados, tmpproveedorescontado) ';
cSql:=cSql||'select proveedores.codproveedor, NOMPROVEEDOR,nif,';
cSql:=cSql||'	SUM(case when cofaccab.tipofpago=''CONTADO'' THEN 1 ELSE 0 END) AS NUMFACTURACONTADOS,';
cSql:=cSql||'	SUM(TOTDOCUMENTO) AS TOTALANIO ';
cSql:=cSql||'	FROM proveedores INNER JOIN cofaccab ON proveedores.CODPROVEEDOR=cofaccab.CODPROVEEDOR ';
cSql:=cSql||'	WHERE DATE_PART(''YEAR'',fechafacturado )='||p_anio;
cSql:=cSql||'	GROUP BY proveedores.CODPROVEEDOR, proveedores.NOMPROVEEDOR,nif ';
cSql:=cSql||'	HAVING SUM(case when cofaccab.tipofpago=''CONTADO'' AND DATE_PART(''YEAR'',FECHAPAGADO)='||p_anio||' THEN 1 ELSE 0 END)=COUNT(cofaccab.TIPOFPAGO) AND ';
cSql:=cSql||'	SUM(TOTDOCUMENTO)<=3000;';
Execute cSql;

	

--Actualizar la cuenta contable en el maestro si el nif coincide con el de la tabla cuentas
update proveedores set codcontable = ctas.codcuenta
	from cuentas ctas
	where trim(proveedores.nif)::text = trim(ctas.nif)::text and 
	ctas.ctadestino like '4000%' and
	(proveedores.codcontable is null or char_length(trim(proveedores.codcontable))=0
	or proveedores.codcontable != ctas.codcuenta);

	
-- actualizar aquellos proveedores que no tienen directamente un nif en la tabla cuentas, al valor 00000 para que se le cree automáticamente la cuenta contable en un proceso posterior. No se excluyen los posibles proveedores de contado
update proveedores set codcontable = '00000' where nif in (
	select px.nif from proveedores px 
	INNER JOIN (SELECT CODPROVEEDOR FROM COFACCAB WHERE DATE_PART('YEAR',fechafacturado)=P_ANIO GROUP BY CODPROVEEDOR) T ON Px.CODPROVEEDOR=T.CODPROVEEDOR
	left join cuentas ct on px.nif = ct.nif and ct.ctadestino like '4000%'
	where px.codcontable != '-----' and ct.nif is null  );

-- CREAMOS LOS vinculos en proveedores A LA 400.0, para aquellos proveedores que estan en tmpproveedorescontado
-- y que no tienen una cuenta contable asignada en contabilidad.
update proveedores set codcontable=cuentas.codcuenta 
from tmpproveedorescontado, cuentas 
where cuentas.CTADESTINO='400000000' and proveedores.CODPROVEEDOR=tmpproveedorescontado.CODPROVEEDOR
	and proveedores.codcontable = '00000';

	
-- Ahora, los proveedores que no tienen una cuenta contable asociada
-- son los que tenemos que crearle y asociarle una nueva.
--create temp sequence secctacontable;
--perform setval('secctacontable', max(ctadestino::integer)) 
--	from cuentas
--	where char_length(cuentas.ctadestino)=9 and cuentas.ctadestino like '4000%';
perform nextcodcontable('4000',true); --se reinicia la secuencia de asignación de cuentas contables
	
insert into cuentas (nomcuenta,nif,ctadestino)  -- SOLO PROVEEDORES QUE TIENE FACTURAS 
	select pro.nomproveedor, pro.nif, nextcodcontable('4000',false) --nextval('secctacontable')::character(12)
	from proveedores pro INNER JOIN (SELECT CODPROVEEDOR FROM COFACCAB WHERE DATE_PART('YEAR',fechafacturado)=P_ANIO GROUP BY CODPROVEEDOR) T ON PRO.CODPROVEEDOR=T.CODPROVEEDOR
	left join tmpproveedorescontado on pro.codproveedor=tmpproveedorescontado.codproveedor
	where (char_length(codcontable)!=5 or codcontable='00000') and 
	       tmpproveedorescontado.codproveedor is null; --no sea un proveedor de contado (con todas sus facturas de contado)
	
--drop sequence secctacontable;		

-- Volvemos a revincular proveedores para vincular las nuevas cuentas recién creadas
update proveedores set codcontable = cuentas.codcuenta 
	from cuentas left join tmpproveedorescontado on cuentas.nif=tmpproveedorescontado.nif
	where proveedores.nif is not null and proveedores.nif != '' 
	and cuentas.ctadestino like '4000%' and char_length(ctadestino)=9
	and cuentas.nif = proveedores.nif
	and (proveedores.codcontable is null or proveedores.codcontable = '00000' 
	or char_length(proveedores.codcontable)=0)
	and tmpproveedorescontado.nif is null; -- no estén en la tabla de proveedores de contado

/*	eN EL VUELQUE DE LOS DATOS DE 2012 NO SE VA A USAR ESTA CONSULTA:

--CONSULTA UTIL. PROVEEDORES QUE DEBEN DE FACTURAR EN COMPRA (SUPERAN LOS 3000 EUROS), Y NO LO ESTÁN
SELECT DISTINCT PROVEEDORES.CODPROVEEDOR,PROVEEDORES.NOMPROVEEDOR,NOMCOMERCIAL,PROVEEDORES.NIF,T.SUMA FROM PROVEEDORES INNER JOIN
(SELECT PROVEEDORES.NIF,SUM(TOTDOCUMENTO) AS SUMA,COALBCAB.CODPROVEEDOR FROM COALBCAB INNER JOIN PROVEEDORES  ON COALBCAB.CODPROVEEDOR=PROVEEDORES.CODPROVEEDOR 
WHERE FECHADOC BETWEEN '2012-01-01' AND '2012-12-31'
GROUP BY PROVEEDORES.NIF,COALBCAB.CODPROVEEDOR
HAVING SUM(TOTDOCUMENTO)>=3000) T ON PROVEEDORES.NIF=T.NIF AND PROVEEDORES.CODPROVEEDOR=T.CODPROVEEDOR
LEFT JOIN COFACCAB ON PROVEEDORES.CODPROVEEDOR=COFACCAB.CODPROVEEDOR
WHERE COFACCAB.CODPROVEEDOR IS NULL
ORDER BY NOMPROVEEDOR;
*/

drop table tmpproveedorescontado;


--Si después del proceso de reasignación de cuenta, quedan proveedores por imputarles una cuenta contable=>se ponen a la 4009.2 para que salga en el detalle del listado de la 4009 (se podían haber puesto a cualquier cuenta)
update proveedores set codcontable=cuentas.codcuenta 
from coalbcab, cuentas 
where coalbcab.codproveedor=proveedores.codproveedor and cuentas.ctadestino='400900002'
and date_part('year',fechadoc)=p_anio and coalesce(proveedores.codcontable,'')='' ;



-- #################
end if;
-- #################
-- ### SECCION 3 ###
-- #################
-- #################

-- #################
-- #################
-- ### SECCION 4 ###
-- #################
if (substring(p_secciones,4,1) = 'X') then 
-- #################

--Regularizaciones de fechas de facturado de albaranes facturados
/* 1) CONTEMPLAR ESTE CASO EN LOS VUELQUES NO HACE EL 400 AL 400. EL PROBLEMA ES QUE LAS FECHA DE FACTURADO DEL ALBARÁN NO PUEDE SER EN NINGÚN CASO INFERIOR A LA FECHA FACTURADO DE LA FACTURA  
La consulta de comprobación de albaranes que incumplen esto sería:
SELECT DISTINCT COFACCAB.SERIEDOCUMENTO,COFACCAB.NUMDOCUMENTO,COFACCAB.TIPOFPAGO ,COALBCAB.SERIEDOCUMENTO,COALBCAB.NUMDOCUMENTO ,COFACCAB.FECHADOC,COFACCAB.FECHAFACTURADO,COFACCAB.FECHAPAGADO, 
       COALBCAB.FECHADOC,COALBCAB.FECHAFACTURADO,COALBCAB.FECHAPAGADO 
       --calbcab.seriedocumento||coalbcab.numdocumento
FROM COFACCAB INNER JOIN COFACLIN ON COFACCAB.SERIEDOCUMENTO=COFACLIN.FACSERIE AND COFACCAB.NUMDOCUMENTO=COFACLIN.FACDOCUMENTO 
              INNER JOIN COALBCAB ON COFACLIN.ALBSERIE=COALBCAB.SERIEDOCUMENTO AND COFACLIN.ALBDOCUMENTO=COALBCAB.NUMDOCUMENTO
 WHERE (DATE_PART('YEAR',COFACCAB.FECHAFACTURADO)=p_anio or DATE_PART('YEAR',COFACCAB.fechapagado)=p_anio) AND COFACCAB.FECHAFACTURADO>COALBCAB.FECHAFACTURADO
 ORDER BY COFACCAB.SERIEDOCUMENTO,COFACCAB.NUMDOCUMENTO;

 LA SOLUCIÓN y regularización PASA POR PONER LA FECHA DE FACTURADO DEL ALBARÁN = A LA FECHA DE FACTURADO DE LA FACTURA */
update coalbcab set fechafacturado=cofaccab.fechafacturado from cofaccab inner join cofaclin ON COFACCAB.SERIEDOCUMENTO=COFACLIN.FACSERIE AND COFACCAB.NUMDOCUMENTO=COFACLIN.FACDOCUMENTO 
where COFACLIN.ALBSERIE=COALBCAB.SERIEDOCUMENTO AND COFACLIN.ALBDOCUMENTO=COALBCAB.NUMDOCUMENTO and
      (DATE_PART('YEAR',COFACCAB.FECHAFACTURADO)=p_anio or DATE_PART('YEAR',COFACCAB.fechapagado)=p_anio) AND COFACCAB.FECHAFACTURADO>COALBCAB.FECHAFACTURADO;
-- Hay que poner un trigger que ponga automaticamente estas fechas de facturado. Se supone que ya hay uno (oalbcab_03controlxestado) pero de algún modo estos casos escaparon a su control en Fragmentadora 2012. en recuperadora no ocurrió en 2012 */
/* Fin caso 1) */

 

/* 2) EL SIGUIENTE CASO ES QUE SE PAGA UN ALBARÁN DESPUÉS DE HABERSE FACTURADO (EN EL MISMO EJERCICIO), PERO CON FECHA ANTERIOR AL PAGO DE LA FACTURA. Fecha de facturado de la factura<fecha pagado del albarán y fecha pago del albarán es <=fecha de pago de la factura
--Consulta de comprobación:
select DISTINCT COFACCAB.SERIEDOCUMENTO,COFACCAB.NUMDOCUMENTO,COFACCAB.TIPOFPAGO ,COALBCAB.SERIEDOCUMENTO,COALBCAB.NUMDOCUMENTO ,COFACCAB.FECHADOC,COFACCAB.FECHAFACTURADO,COFACCAB.FECHAPAGADO, 
       COALBCAB.FECHADOC,COALBCAB.FECHAFACTURADO,COALBCAB.FECHAPAGADO,coalbcab.totdocumento,cofaccab.totdocumento,case when cofaccab.fechapagado is null then cofaccab.fechafacturado else cofaccab.fechapagado end
FROM COFACCAB INNER JOIN COFACLIN ON COFACCAB.SERIEDOCUMENTO=COFACLIN.FACSERIE AND COFACCAB.NUMDOCUMENTO=COFACLIN.FACDOCUMENTO 
              INNER JOIN COALBCAB ON COFACLIN.ALBSERIE=COALBCAB.SERIEDOCUMENTO AND COFACLIN.ALBDOCUMENTO=COALBCAB.NUMDOCUMENTO
 WHERE (DATE_PART('YEAR',COFACCAB.FECHAFACTURADO)=p_anio or DATE_PART('YEAR',COFACCAB.fechapagado)=p_anio) AND coalbcab.fechapagado>coalbcab.FECHAFACTURADO and (cofaccab.fechapagado is null or cofaccab.fechapagado>coalbcab.fechapagado)
 ORDER BY COFACCAB.SERIEDOCUMENTO,COFACCAB.NUMDOCUMENTO;

LA SOLUCIÓN PASA POR PONER LA FECHA DE FACTURADO DESPUÉS DE LA FECHA DE PAGO DEL ALBARÁN PERO ANTES o igual a LA FECHA DE PAGADO DE LA FACTURA */
DROP TRIGGER coalbcab_gestiona_pagos_y_estados ON coalbcab; --desactivamos sel trigger que evita esta actualización
update coalbcab set fechafacturado=case when cofaccab.fechapagado is null then cofaccab.fechafacturado else cofaccab.fechapagado end from cofaccab inner join cofaclin ON COFACCAB.SERIEDOCUMENTO=COFACLIN.FACSERIE AND COFACCAB.NUMDOCUMENTO=COFACLIN.FACDOCUMENTO 
where COFACLIN.ALBSERIE=COALBCAB.SERIEDOCUMENTO AND COFACLIN.ALBDOCUMENTO=COALBCAB.NUMDOCUMENTO and
      (DATE_PART('YEAR',COFACCAB.FECHAFACTURADO)=p_anio or DATE_PART('YEAR',COFACCAB.fechapagado)=p_anio) AND coalbcab.fechapagado>coalbcab.FECHAFACTURADO and (cofaccab.fechapagado is null or cofaccab.fechapagado>coalbcab.fechapagado) ;

CREATE TRIGGER coalbcab_gestiona_pagos_y_estados
  BEFORE UPDATE
  ON coalbcab
  FOR EACH ROW
  EXECUTE PROCEDURE coalbcab_gestiona_pagos_y_estados();
/* Hay que poner un trigger que ponga automaticamente esta fecha de facturado del albarán para que  nunca se de este caso */
/* Fin caso 2) */


/* 3) EL SIGUIENTE CASO ES QUE SE FACTURA UN ALBARÁN DE OTRO EJERCICIO PAGADO AL CONTADO EN OTRO EJERCICIO (TANTO LA FECHA DEL ALBARÁN COMO LA FECHA DE PAGO DEL ALBARÁN SON DE UN EJERCICIO ANTERIOR). AL FACTURARSE, LA FECHA DE PAGO DE LA FACTURA QUEDA COMO QUE
   SE PAGÓ EN EL EJERCICIO ANTERIOR (EL TRIGGER PONDRÁ COMO FECHA DE PAGO LA FECHA DE PAGO DEL ALBARÁN). ESTO ORIGINA PROBLEMAS EN EL VUELQUE, Y LO QUE SE DECIDE ES PONER QUE LA FECHA DE PAGO DE LA FACTURA SEA = A LA FECHA DE FACTURA 
select SERIEDOCUMENTO,NUMDOCUMENTO
FROM COFACCAB INNER JOIN COFACLIN ON COFACCAB.SERIEDOCUMENTO=COFACLIN.FACSERIE AND COFACCAB.NUMDOCUMENTO=COFACLIN.FACDOCUMENTO 
              INNER JOIN COALBCAB ON COFACLIN.ALBSERIE=COALBCAB.SERIEDOCUMENTO AND COFACLIN.ALBDOCUMENTO=COALBCAB.NUMDOCUMENTO
 WHERE (DATE_PART('YEAR',COFACCAB.FECHAFACTURADO)=p_anio AND DATE_PART('YEAR',COFACCAB.fechapagado)<p_anio)   
 GROUP BY COFACCAB.SERIEDOCUMENTO,COFACCAB.NUMDOCUMENTO
 HAVING  SUM(CASE WHEN COALBCAB.FECHAPAGADO IS NOT NULL AND DATE_PART('YEAR',COALBCAB.FECHAPAGADO)<p_anio THEN 1 else 0 END)=COUNT(COALBCAB.SERIEDOCUMENTO);

lA SOLUCIÓN DEL CASO 3) PASA POR POER LA FECHA DE PAGADO A LA MISMA FECHA DE FACTURADO */
update COFACCAB set FECHAPAGADO=COFACCAB.FECHAFACTURADO  WHERE SERIEDOCUMENTO||NUMDOCUMENTO IN (
select COFACCAB.SERIEDOCUMENTO||COFACCAB.NUMDOCUMENTO
FROM COFACCAB INNER JOIN COFACLIN ON COFACCAB.SERIEDOCUMENTO=COFACLIN.FACSERIE AND COFACCAB.NUMDOCUMENTO=COFACLIN.FACDOCUMENTO 
              INNER JOIN COALBCAB ON COFACLIN.ALBSERIE=COALBCAB.SERIEDOCUMENTO AND COFACLIN.ALBDOCUMENTO=COALBCAB.NUMDOCUMENTO
 WHERE (DATE_PART('YEAR',COFACCAB.FECHAFACTURADO)=P_ANIO AND DATE_PART('YEAR',COFACCAB.fechapagado)<P_ANIO)   
 GROUP BY COFACCAB.SERIEDOCUMENTO,COFACCAB.NUMDOCUMENTO
 HAVING  SUM(CASE WHEN COALBCAB.FECHAPAGADO IS NOT NULL AND DATE_PART('YEAR',COALBCAB.FECHAPAGADO)<P_ANIO THEN 1 else 0 END)=COUNT(COALBCAB.SERIEDOCUMENTO)
);


/* 3.1) EL SIGUIENTE CASO ES QUE SE FACTURA UN ALBARÁN DE ESTE EJERCICIO. Dicho albarán se paga y se factura en el mismo. Pero la factura queda como pagada en el siguiente ejercicio posterior al actual. 
        En resumen igual que el caso 3, con la diferencia que el pago y el facturado es en el ejercicio actual. LO QUE SE DECIDE ES PONER QUE LA FECHA DE PAGO DE LA FACTURA SEA = A LA FECHA DE FACTURA 
       
select cofaccab.SERIEDOCUMENTO,cofaccab.NUMDOCUMENTO
FROM COFACCAB INNER JOIN COFACLIN ON COFACCAB.SERIEDOCUMENTO=COFACLIN.FACSERIE AND COFACCAB.NUMDOCUMENTO=COFACLIN.FACDOCUMENTO 
              left JOIN COALBCAB ON COFACLIN.ALBSERIE=COALBCAB.SERIEDOCUMENTO AND COFACLIN.ALBDOCUMENTO=COALBCAB.NUMDOCUMENTO
 WHERE (DATE_PART('YEAR',COFACCAB.FECHAFACTURADO)=p_anio AND DATE_PART('YEAR',COFACCAB.fechapagado)>p_anio)   
 GROUP BY COFACCAB.SERIEDOCUMENTO,COFACCAB.NUMDOCUMENTO
 HAVING  SUM(CASE WHEN COALBCAB.FECHAPAGADO IS NOT NULL AND DATE_PART('YEAR',COALBCAB.FECHAPAGADO)=p_anio THEN 1 else 0 END)=COUNT(cofaclin.SERIEDOCUMENTO);

lA SOLUCIÓN DEL CASO 3.1) PASA POR POER LA FECHA DE PAGADO A LA MISMA FECHA DE FACTURADO */
update COFACCAB set FECHAPAGADO=COFACCAB.FECHAFACTURADO  WHERE SERIEDOCUMENTO||NUMDOCUMENTO IN (
select COFACCAB.SERIEDOCUMENTO||COFACCAB.NUMDOCUMENTO
FROM COFACCAB INNER JOIN COFACLIN ON COFACCAB.SERIEDOCUMENTO=COFACLIN.FACSERIE AND COFACCAB.NUMDOCUMENTO=COFACLIN.FACDOCUMENTO 
              INNER JOIN COALBCAB ON COFACLIN.ALBSERIE=COALBCAB.SERIEDOCUMENTO AND COFACLIN.ALBDOCUMENTO=COALBCAB.NUMDOCUMENTO
 WHERE (DATE_PART('YEAR',COFACCAB.FECHAFACTURADO)=P_ANIO AND DATE_PART('YEAR',COFACCAB.fechapagado)>P_ANIO)   
 GROUP BY COFACCAB.SERIEDOCUMENTO,COFACCAB.NUMDOCUMENTO
 HAVING  SUM(CASE WHEN COALBCAB.FECHAPAGADO IS NOT NULL AND DATE_PART('YEAR',COALBCAB.FECHAPAGADO)=P_ANIO THEN 1 else 0 END)=COUNT(COALBCAB.SERIEDOCUMENTO)
);

/* 4) Los albaranes facturados en otro ejercicio deben de tener fechafacturado=fecha de facturado de la factura.
--Para identificar las facturas que contienen albaranes con fecha facturado de distinto ejercicio que la fecha de facturado de la factura
select cofaccab.SERIEDOCUMENTO,cofaccab.NUMDOCUMENTO,cofaccab.fechafacturado,concatenate(coalbcab.fechafacturado::text),cofaccab.fechapagado,concatenate(coalbcab.fechapagado::text)
FROM COFACCAB INNER JOIN COFACLIN ON COFACCAB.SERIEDOCUMENTO=COFACLIN.FACSERIE AND COFACCAB.NUMDOCUMENTO=COFACLIN.FACDOCUMENTO 
              INNER JOIN COALBCAB ON COFACLIN.ALBSERIE=COALBCAB.SERIEDOCUMENTO AND COFACLIN.ALBDOCUMENTO=COALBCAB.NUMDOCUMENTO
 WHERE (DATE_PART('YEAR',COFACCAB.FECHAFACTURADO)<>DATE_PART('YEAR',coalbcab.fechafacturado))  and  (DATE_PART('YEAR',coalbcab.fechafacturado)=p_anio or DATE_PART('YEAR',COFACCAB.FECHAFACTURADO)=p_anio)
 GROUP BY COFACCAB.SERIEDOCUMENTO,COFACCAB.NUMDOCUMENTO,cofaccab.fechafacturado,cofaccab.fechapagado
 La solución al caso 4) pasa por poner la fecha de facturado del albarán a la fecha de facturado de la factura */
DROP TRIGGER coalbcab_gestiona_pagos_y_estados ON coalbcab; --desactivamoe sel trigger que evita esta actualización
update coalbcab set fechafacturado=cofaccab.fechafacturado from cofaccab inner join cofaclin ON COFACCAB.SERIEDOCUMENTO=COFACLIN.FACSERIE AND COFACCAB.NUMDOCUMENTO=COFACLIN.FACDOCUMENTO 
where COFACLIN.ALBSERIE=COALBCAB.SERIEDOCUMENTO AND COFACLIN.ALBDOCUMENTO=COALBCAB.NUMDOCUMENTO and
      (DATE_PART('YEAR',COFACCAB.FECHAFACTURADO)<>DATE_PART('YEAR',coalbcab.fechafacturado))  and  (DATE_PART('YEAR',coalbcab.fechafacturado)=p_anio or DATE_PART('YEAR',COFACCAB.FECHAFACTURADO)=p_anio) ;
CREATE TRIGGER coalbcab_gestiona_pagos_y_estados
  BEFORE UPDATE
  ON coalbcab
  FOR EACH ROW
  EXECUTE PROCEDURE coalbcab_gestiona_pagos_y_estados();


-- #################
end if;
-- #################
-- ### SECCION 4 ###
-- #################
-- #################

-- #################
-- #################
-- ### SECCION 5 ###
-- #################
if (substring(p_secciones,5,1) = 'X') then 
-- #################


----------------------------------------------------------------------------------
-- PAGOS DE ALBARANES DE COMPRA Que no están facturados (tipo 3)
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
delete from vencimientos where tipodocumento='COALBCAB' and date_part('year',fechapago)=p_anio;
-- Los codigos de cuenta están conciliados entre las tres empresas, por lo que no es
-- necesario asignarlos en base a "ctadestino".

INSERT INTO VENCIMIENTOS (CODMAESTRO,FECHADOC,FECHAVTO,FECHAIMPAGO,FECHAPAGO,TIPODOCUMENTO,FACSERIE,FACDOCUMENTO,TOTVTO,TOTDOCUMENTO,TIPOFPAGO,CODCONTABLE)
    SELECT CODPROVEEDOR,FECHADOC,CAJA_CIERRES.FECHA,FECHADOC,CAJA_CIERRES.FECHA,'COALBCAB', coalbcab.SERIEDOCUMENTO,coalbcab.NUMDOCUMENTO,sum(coalblin.totlinea),sum(coalblin.totlinea),
       'CONTADO',
	Case 	When caja_cierres.coddelegacion='LPA' then '01583' 
		When caja_cierres.coddelegacion='LAN' then '01584' 
		When caja_cierres.coddelegacion='TFN' then '01585' 
		When caja_cierres.coddelegacion='ARI' then '01586' 
		When caja_cierres.coddelegacion='FUE' then '01587' 
		When caja_cierres.coddelegacion='TFS' then '01588' end  
       FROM COALBCAB 
	inner join CAJA_CIERRES  on coalbcab.codcierre=caja_cierres.codcierre 
	inner join caja_nombres on coalbcab.codcaja=caja_nombres.codcaja
	inner join seriescompras on coalbcab.seriedocumento = seriescompras.codserie
	inner join coalblin on coalbcab.seriedocumento=coalblin.albserie and coalbcab.numdocumento=coalblin.albdocumento
	left join cofaclin on coalblin.albserie=cofaclin.albserie and coalblin.albdocumento=cofaclin.albdocumento and coalblin.ordarticulo=cofaclin.posarticulo
       WHERE seriescompras.ctrlcaja AND TIPOFPAGO IN ('CONTADO') AND TOTDOCUMENTO<>0 AND 
		COALBCAB.ESTADO='PAGADO EN ALBARAN' AND COALBCAB.TOTDOCUMENTO<>0 and date_part('YEAR',caja_cierres.fecha)=p_anio
		--and (coalbcab.fechafacturado is null or date_part('YEAR',coalbcab.fechafacturado)>p_anio) --Se comenta porque se guardan en vencimientos parciales de líneas de albaranes
		and (cofaclin.albserie is null or date_part('YEAR',coalbcab.fechafacturado)>p_anio) --solamente las líneas que no están facturadas. Lo que va por factura ya lo trata la propia factura
	group by  CODPROVEEDOR,FECHADOC,CAJA_CIERRES.FECHA,FECHADOC,CAJA_CIERRES.FECHA,coalbcab.SERIEDOCUMENTO,coalbcab.NUMDOCUMENTO,Case When caja_cierres.coddelegacion='LPA' then '01583' 
		When caja_cierres.coddelegacion='LAN' then '01584' 
		When caja_cierres.coddelegacion='TFN' then '01585' 
		When caja_cierres.coddelegacion='ARI' then '01586' 
		When caja_cierres.coddelegacion='FUE' then '01587' 
		When caja_cierres.coddelegacion='TFS' then '01588' end  ; 



-- #################
end if;
-- #################
-- ### SECCION 5 ###
-- #################
-- #################

-- #################
-- #################
-- ### SECCION 6 ###
-- #################
if (substring(p_secciones,6,1) = 'X') then 
-- #################


----------------------------------------------------------------------------------
-- EXPORTACIÓN CLIENTES (tipo )
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------

-- actualizar el nombre de la cuenta y el nif, para aquello que difiera del 
-- contaplus. La asignacion de cuentas de contaplus es lo que prevalece.
update cuentas
	set nomcuenta = cp.nomcuenta, nif=cp.nif
	from cuentas_contaplus cp
	where cuentas.ctadestino = cp.ctadestino 
	and cuentas.ctadestino like '4300%'
	and (cuentas.nomcuenta != cp.nomcuenta or cuentas.nif != cp.nif);


--Todos los CLIENTES nuevos (tabla tempacreedores) y clientes (tempclientes) nuevos, 
--con todas (sin excepción) las facturas de contado y su  fecha de factura y fecha de 
--pago sean del año indicado y su importe anual no supere los 3000 euros van una cuenta 
--genérica que 410.0 Acreedores varios contado. y 430.0 Clientes varios contado.
-- OJO. Si ese acreedor/cliente ya tenía cuenta en contabilidad, hay que respetar su cuenta.
create temp table tempclientescontado 
(
  codcliente character (6),
  nomcliente character varying(140),
  nif character (16),
  numfacturacontados integer,
  tmpclientes numeric(13,2)
);

cSql:=	'insert into tempclientescontado ';
cSql:=cSql||'	(codcliente, nomcliente, nif, numfacturacontados, tmpclientes) ';
cSql:=cSql||'select clientes.codcliente, nomcliente,nif,';
cSql:=cSql||'	SUM(case when vefaccab.tipofpago=''CONTADO'' THEN 1 ELSE 0 END) AS NUMFACTURACONTADOS,';
cSql:=cSql||'	SUM(TOTDOCUMENTO) AS TOTALANIO ';
--into temp tmpacreedorescontado ';
cSql:=cSql||'	FROM clientes INNER JOIN vefaccab ON clientes.codcliente=vefaccab.codcliente ';
cSql:=cSql||'	WHERE DATE_PART(''YEAR'',fechadoc )='||p_anio;
cSql:=cSql||'	GROUP BY clientes.codcliente, clientes.nomcliente,nif ';
cSql:=cSql||'	HAVING SUM(case when vefaccab.tipofpago=''CONTADO'' AND DATE_PART(''YEAR'',FECHACOBRADO)='||p_anio||' THEN 1 ELSE 0 END)=COUNT(vefaccab.TIPOFPAGO) AND ';
cSql:=cSql||'	SUM(TOTDOCUMENTO)<=3000;';
Execute cSql;


-- Actualizar la cuenta contable en el maestro si el nif coincide con el de la tabla cuentas
-- NO se excluyen los que estén en tmpacreedorescontado, ya que prevalece los que ya estan en contabilidad
update clientes set codcontable = ctas.codcuenta
	from cuentas ctas 
	where trim(clientes.nif)::text = trim(ctas.nif)::text and 
	ctas.ctadestino like '4300%' and
	(clientes.codcontable is null or char_length(trim(clientes.codcontable))=0
	or clientes.codcontable != ctas.codcuenta); 
	
--Los acreedores de grupo se ponen sin vincular a cuentas concretas (usarán contab_excepciones)
update clientes set codcontable = '-----' 
	where nif in ('B35855543','B35689991','B35066273');
--2013-07-02 -Estos clientes tienen que tener por defecto estas cuentas 
UPDATE CLIENTES SET CODCONTABLE='00736' FROM CUENTAS WHERE CODCLIENTE='0056';
UPDATE CLIENTES SET CODCONTABLE='00737' FROM CUENTAS WHERE CODCLIENTE='0018';

	
-- actualizar aquellos acreedores que no tienen directamente un nif en la tabla cuentas, al valor 00000 para que se le cree automáticamente la cuenta contable en un proceso posterior
update clientes set codcontable = '00000' where nif in (
	select px.nif 
	from clientes px 
		left join cuentas ct on px.nif = ct.nif and ct.ctadestino like '4300%'
		inner join (select codcliente from vefaccab where date_part('year',fechadoc)=p_anio 
			group by codcliente) T ON px.codcliente=T.codcliente
	where px.codcontable != '-----' and ct.nif is null );

-- CREAMOS LOS vinculos en clientes A LA 430.0, para aquellos clientes que estan en tmpacreedorescontado
-- y que no tienen una cuenta contable asignada en contabilidad.
update clientes set codcontable=cuentas.codcuenta 
from tempclientescontado, cuentas 
where cuentas.CTADESTINO='430000000' and clientes.codcliente=tempclientescontado.codcliente
	and clientes.codcontable = '00000';
	
-- Ahora, los acreedores que no tienen una cuenta contable asociada, y no están en tempclientescontado
-- son los que tenemos que crearle y asociarle una nueva.
--create temp sequence secctacontable;
--perform setval('secctacontable', max(ctadestino::integer)) 
--	from cuentas
--	where char_length(cuentas.ctadestino)=9 and cuentas.ctadestino like '4100%';
perform nextcodcontable('4300',true);
	
insert into cuentas (nomcuenta,nif,ctadestino)
	select cli.nomcliente, cli.nif, nextcodcontable('4300',false)--nextval('secctacontable')::character(12)
	from clientes cli left join tempclientescontado tmp on cli.codcliente=tmp.codcliente
		inner join (select codcliente from vefaccab where date_part('year',fechadoc)=p_anio 
		group by codcliente) T ON cli.codcliente=T.codcliente
 	where char_length(codcontable)!=5 or codcontable='00000' and tmp.codcliente is null; --no sea un acreedor varios 
	
--drop sequence secctacontable;		

-- Volvemos a revincular clientes para vincular las nuevas cuentas recién creadas
update clientes set codcontable = cuentas.codcuenta 
	from cuentas left join tempclientescontado on cuentas.nif=tempclientescontado.nif
	where clientes.nif is not null and clientes.nif != '' 
	and cuentas.ctadestino like '4300%' and char_length(ctadestino)=9
	and cuentas.nif = clientes.nif
	and (clientes.codcontable is null or clientes.codcontable = '00000' 
	or char_length(clientes.codcontable)=0)
	and tempclientescontado.nif is null; -- no estén en la tabla de clientes de contado

-- #################
end if;
-- #################
-- ### SECCION 6 ###
-- #################
-- #################

-- #################
-- #################
-- ### SECCION 7 ###
-- #################
if (substring(p_secciones,7,1) = 'X') then 
-- #################

--Cobros de facturas de venta
delete from vencimientos where tipodocumento='VEFACCAB' and date_part('year',fechapago)=p_anio;
-- Los codigos de cuenta están conciliados entre las tres empresas, por lo que no es
-- necesario asignarlos en base a "ctadestino".
insert into vencimientos (codmaestro,fechadoc,fechavto,fechaimpago,fechapago,tipodocumento,facserie,
	facdocumento,totvto,totdocumento,tipofpago,codcontable)
	select codcliente,fechadoc,fechacobrado,fechadoc,fechacobrado,'VEFACCAB', seriedocumento,numdocumento,
	totdocumento,totdocumento, 'CONTADO',
	Case 	When caja_nombres.coddelegacioncaja='LPA' then '01583' 
		When caja_nombres.coddelegacioncaja='LAN' then '01584' 
		When caja_nombres.coddelegacioncaja='TFN' then '01585' 
		When caja_nombres.coddelegacioncaja='ARI' then '01586' 
		When caja_nombres.coddelegacioncaja='FUE' then '01587' 
		When caja_nombres.coddelegacioncaja='TFS' then '01588' end 
	FROM VEFACCAB inner join caja_nombres on vefaccab.codcaja=caja_nombres.codcaja
	WHERE FECHACOBRADO is not null and tipofpago IN ('CONTADO') and date_part('year',vefaccab.fechacobrado)=p_anio;




drop table tempclientescontado;

--Faltan los pagos de clientes


-- #################
end if;
-- #################
-- ### SECCION 7 ###
-- #################
-- #################

-- #################
-- #################
-- ### SECCION 8 ###
-- #################
if (substring(p_secciones,8,1) = 'X') then 
-- #################

----------------------------------------------------------------------------------
-- EXPORTACIÓN ACREEDORES (tipo 5)
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------

-- actualizar el nombre de la cuenta y el nif, para aquello que difiera del 
-- contaplus. La asignacion de cuentas de contaplus es lo que prevalece.
update cuentas
	set nomcuenta = cp.nomcuenta, nif=cp.nif
	from cuentas_contaplus cp
	where cuentas.ctadestino = cp.ctadestino 
	and cuentas.ctadestino like '4100%'
	and (cuentas.nomcuenta != cp.nomcuenta or cuentas.nif != cp.nif);


--Todos los acreedores nuevos (tabla tempacreedores) y clientes (tempclientes) nuevos, 
--con todas (sin excepción) las facturas de contado y su  fecha de factura y fecha de 
--pago sean del año indicado y su importe anual no supere los 3000 euros van una cuenta 
--genérica que 410.0 Acreedores varios contado. y 430.0 Clientes varios contado.
-- OJO. Si ese acreedor/cliente ya tenía cuenta en contabilidad, hay que respetar su cuenta.
create temp table tmpacreedorescontado 
(
  codproveedor character (6),
  nomproveedor character varying(140),
  nif character (16),
  numfacturacontados integer,
  tmpacreedorescontado numeric(13,2)
);

cSql:=	'insert into tmpacreedorescontado ';
cSql:=cSql||'	(codproveedor, nomproveedor, nif, numfacturacontados, tmpacreedorescontado) ';
cSql:=cSql||'select acreedores.codproveedor, NOMPROVEEDOR,nif,';
cSql:=cSql||'	SUM(case when COACRCAB.tipofpago=''CONTADO'' THEN 1 ELSE 0 END) AS NUMFACTURACONTADOS,';
cSql:=cSql||'	SUM(TOTDOCUMENTO) AS TOTALANIO ';
--into temp tmpacreedorescontado ';
cSql:=cSql||'	FROM ACREEDORES INNER JOIN COACRCAB ON ACREEDORES.CODPROVEEDOR=COACRCAB.CODPROVEEDOR ';
cSql:=cSql||'	WHERE DATE_PART(''YEAR'',FECHAFACTURADO )='||p_anio;
cSql:=cSql||'	GROUP BY ACREEDORES.CODPROVEEDOR, ACREEDORES.NOMPROVEEDOR,nif ';
cSql:=cSql||'	HAVING SUM(case when COACRCAB.tipofpago=''CONTADO'' AND DATE_PART(''YEAR'',FECHAPAGADO)='||p_anio||' THEN 1 ELSE 0 END)=COUNT(COACRCAB.TIPOFPAGO) AND ';
cSql:=cSql||'	SUM(TOTDOCUMENTO)<=3000;';
Execute cSql;


-- Actualizar la cuenta contable en el maestro si el nif coincide con el de la tabla cuentas
-- NO se excluyen los que estén en tmpacreedorescontado, ya que prevalece los que ya estan en contabilidad
update ACREEDORES set codcontable = ctas.codcuenta
	from cuentas ctas 
	where trim(acreedores.nif)::text = trim(ctas.nif)::text and 
	ctas.ctadestino like '4100%' and
	(acreedores.codcontable is null or char_length(trim(acreedores.codcontable))=0
	or acreedores.codcontable != ctas.codcuenta); 
	
--Los acreedores de grupo se ponen sin vincular a cuentas concretas (usarán contab_excepciones)
update acreedores set codcontable = '-----' 
	where nif in ('B35855543','B35689991','B35066273');
	
-- actualizar aquellos acreedores que no tienen directamente un nif en la tabla cuentas, al valor 00000 para que se le cree automáticamente la cuenta contable en un proceso posterior
update acreedores set codcontable = '00000' where nif in (
	select px.nif 
	from acreedores px 
		left join cuentas ct on px.nif = ct.nif and ct.ctadestino like '4100%'
		inner join (select codproveedor from coacrcab where date_part('year',fechafacturado)=p_anio 
			group by codproveedor) T ON px.codproveedor=T.codproveedor
	where px.codcontable != '-----' and ct.nif is null );

-- CREAMOS LOS vinculos en ACREEDORES A LA 410.0, para aquellos acreedores que estan en tmpacreedorescontado
-- y que no tienen una cuenta contable asignada en contabilidad.
update acreedores set codcontable=cuentas.codcuenta 
from tmpacreedorescontado, cuentas 
where cuentas.CTADESTINO='410000000' and acreedores.CODPROVEEDOR=tmpacreedorescontado.CODPROVEEDOR
	and acreedores.codcontable = '00000';
	
-- Ahora, los acreedores que no tienen una cuenta contable asociada, y no están en tmpacreedorescontado
-- son los que tenemos que crearle y asociarle una nueva.
create temp sequence secctacontable;
perform setval('secctacontable', max(ctadestino::integer)) 
	from cuentas
	where char_length(cuentas.ctadestino)=9 and cuentas.ctadestino like '4100%';
	
insert into cuentas (nomcuenta,nif,ctadestino)
	select acr.nomproveedor, acr.nif, nextval('secctacontable')::character(12)
	from acreedores acr left join tmpacreedorescontado tmp on acr.codproveedor=tmp.codproveedor
		inner join (select codproveedor from coacrcab where date_part('year',fechafacturado)=p_anio 
		group by codproveedor) T ON acr.codproveedor=T.codproveedor
 	where char_length(codcontable)!=5 or codcontable='00000' and tmp.codproveedor is null; --no sea un acreedor varios 
	
drop sequence secctacontable;		

-- Volvemos a revincular acreedores para vincular las nuevas cuentas recién creadas
update acreedores set codcontable = cuentas.codcuenta 
	from cuentas left join tmpacreedorescontado on cuentas.nif=tmpacreedorescontado.nif
	where acreedores.nif is not null and acreedores.nif != '' 
	and cuentas.ctadestino like '4100%' and char_length(ctadestino)=9
	and cuentas.nif = acreedores.nif
	and (acreedores.codcontable is null or acreedores.codcontable = '00000' 
	or char_length(acreedores.codcontable)=0)
	and tmpacreedorescontado.nif is null; -- no estén en la tabla de acreedores de contado

	-- generar idpadre3
update cuentas 
	set idpadre3=cuentas2.codcuenta 
	from cuentas as cuentas2 
	where char_length(cuentas.ctadestino)=9 and 
	substring(cuentas.ctadestino,1,3) = cuentas2.ctadestino and
	(cuentas.idpadre3 is null or char_length(trim(cuentas.idpadre3))=0 
	or cuentas.idpadre3='0');
	-- generar idpadre1
update cuentas 
	set idpadre1=cuentas2.codcuenta 
	from cuentas as cuentas2 
	where char_length(cuentas.ctadestino)=9 and 
	substring(cuentas.ctadestino,1,1) = cuentas2.ctadestino and
	(cuentas.idpadre1 is null or char_length(trim(cuentas.idpadre1))=0 
	or cuentas.idpadre1='0');
	
-- #################
end if;
-- #################
-- ### SECCION 8 ###
-- #################
-- #################

-- #################
-- #################
-- ### SECCION 9 ###
-- #################
if (substring(p_secciones,9,1) = 'X') then 
-- #################
	

----------------------------------------------------------------------------------
-- PAGOS DE ACREEDORES (tipo 6)
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
delete from vencimientos where tipodocumento='COACRCAB' and date_part('year',fechapago)=p_anio;
-- Los codigos de cuenta están conciliados entre las tres empresas, por lo que no es
-- necesario asignarlos en base a "ctadestino".
insert into vencimientos (codmaestro,fechadoc,fechavto,fechaimpago,fechapago,tipodocumento,facserie,
	facdocumento,totvto,totdocumento,tipofpago,codcontable)
	select codproveedor,fechadoc,fechapagado,fechadoc,fechapagado,'COACRCAB', seriedocumento,numdocumento,
	totdocumento,totdocumento, 'CONTADO',
	Case 	When caja_nombres.coddelegacioncaja='LPA' then '01583' 
		When caja_nombres.coddelegacioncaja='LAN' then '01584' 
		When caja_nombres.coddelegacioncaja='TFN' then '01585' 
		When caja_nombres.coddelegacioncaja='ARI' then '01586' 
		When caja_nombres.coddelegacioncaja='FUE' then '01587' 
		When caja_nombres.coddelegacioncaja='TFS' then '01588' end 
	FROM coacrcab inner join caja_nombres on coacrcab.codcaja=caja_nombres.codcaja
	WHERE fechapagado is not null and tipofpago IN ('CONTADO') and date_part('year',coacrcab.fechapagado)=p_anio;

drop table tmpacreedorescontado;

----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
-- #################
end if;
-- #################
-- ### SECCION 9 ###
-- #################
-- #################

-- ##################
-- ##################
-- ### SECCION 10 ###
-- ##################
if (substring(p_secciones,10,1) = 'X') then 
-- ##################

----------------------------------------------------------------------------------
-- EXPORTACIÓN VALES CONTADO (EMPLEADOS TIPO 18)
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------

-- actualizar el nombre de la cuenta y el nif, para aquello que difiera del 
-- contaplus. La asignacion de cuentas de contaplus es lo que prevalece.
/*
update cuentas
	set nomcuenta = cp.nomcuenta, nif=cp.nif
	from cuentas_contaplus cp
	where cuentas.ctadestino = cp.ctadestino 
	and cuentas.ctadestino like '4070%' or cuentas.ctadestino like '4600%'
	and (cuentas.nomcuenta != cp.nomcuenta or cuentas.nif != cp.nif);
*/
--IMPEDIMOS que el Nif contenga caracteres raros (hay integridad referencial en vales_movimientos
UPDATE VALES_PERSONAS SET NIF=replace(replace(replace(nif,' ', ''),'-',''),'.','');

--Hacemos que los vales_personas de empleados estén vinculados a la delegación que le corresponde
update vales_personas set coddelegacion=vales_movimientos.coddelegacion FROM VALES_MOVIMIENTOS where vales_personas.nif=vales_movimientos.nif and vales_personas.tiporelacion='EMPLEADOS' AND VALES_MOVIMIENTOS.CODDELEGACION IS NOT NULL;


-- POR DEFECTO SE PONE COMO ANTICIPO DE PROVEEDORES VARIOS OK
UPDATE  VALES_PERSONAS SET CODCONTABLE=CUENTAS.CODCUENTA FROM CUENTAS WHERE VALES_PERSONAS.TIPORELACION='COMERCIALES'  AND  CTADESTINO = '407000003';

-- LUEGO SE VINCULA LA CUENTA CORRESPONDIENTE POR NIF DE LA TABLA CUENTAS
UPDATE  VALES_PERSONAS SET CODCONTABLE=CUENTAS.CODCUENTA FROM CUENTAS WHERE VALES_PERSONAS.TIPORELACION IN ('COMERCIALES','PROVEEDORES/ACREEDORES')  AND CUENTAS.NOMCUENTA LIKE '%'|| VALES_PERSONAS.NIF || '%' AND CTADESTINO LIKE '407%';

--DIRECCION/CONSEJEROS ASOCIACIÓN DE LA CUENTA CONTABLE DE ANTICIPO DE FERNANDO
UPDATE VALES_PERSONAS SET CODCONTABLE=CUENTAS.CODCUENTA from CUENTAS WHERE VALES_PERSONAS.NIF='42853083N' AND CUENTAS.CTADESTINO='551000003';

--ASOCIACIÓN DE LA CUENTA CONTABLE DE ANTICIPO DE FERNANDO
UPDATE VALES_PERSONAS SET CODCONTABLE=CUENTAS.CODCUENTA from CUENTAS WHERE VALES_PERSONAS.NIF='42833487N' AND CUENTAS.CTADESTINO='551000002';





--Vinculamos la cuenta 460 a todos los vales_personas empleados.
update vales_personas set codcontable=cuentas.codcuenta from cuentas where vales_personas.tiporelacion='EMPLEADOS' AND 
       Case 	When vales_personas.coddelegacion='LPA' then cuentas.ctadestino='460000001' 
		When vales_personas.coddelegacion='LAN' then cuentas.ctadestino='460000002' 
		When vales_personas.coddelegacion='TFN' then cuentas.ctadestino='460000003' 
		When vales_personas.coddelegacion='ARI' then cuentas.ctadestino='460000004' 
		When vales_personas.coddelegacion='FUE' then cuentas.ctadestino='460000005' 
		When vales_personas.coddelegacion='TFS' then cuentas.ctadestino='460000006'  end; 


----------------------------------------------------------------------------------
-- PAGOS DE vales (tipo 18)
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
delete from vencimientos where tipodocumento='VALES_MOVIMIENTOS' and date_part('year',fechapago)=p_anio;
-- Los codigos de cuenta están conciliados entre las tres empresas, por lo que no es
-- necesario asignarlos en base a "ctadestino".


INSERT INTO VENCIMIENTOS (CODMAESTRO,FECHADOC,FECHAVTO,FECHAIMPAGO,FECHAPAGO,TIPODOCUMENTO,FACSERIE,FACDOCUMENTO,TOTVTO,TOTDOCUMENTO,TIPOFPAGO,CODCONTABLE)
       SELECT vales_movimientos.nif,CAJA_CIERRES.FECHA,CAJA_CIERRES.FECHA,VALES_MOVIMIENTOS.FECHA,VALES_MOVIMIENTOS.FECHA,'VALES_MOVIMIENTOS', APUNTE,APUNTE,DEBE-HABER,DEBE-HABER,
       'CONTADO',  
       Case 	When caja_cierres.coddelegacion='LPA' then '01583' 
		When caja_cierres.coddelegacion='LAN' then '01584' 
		When caja_cierres.coddelegacion='TFN' then '01585' 
		When caja_cierres.coddelegacion='ARI' then '01586' 
		When caja_cierres.coddelegacion='FUE' then '01587' 
		When caja_cierres.coddelegacion='TFS' then '01588' end 
       FROM VALES_MOVIMIENTOS INNER JOIN CAJA_CIERRES ON  CAJA_CIERRES.CODCIERRE=VALES_MOVIMIENTOS.CODCIERRE inner join vales_personas on vales_personas.nif=vales_movimientos.nif
       WHERE CODCUENTA IN ('00040','00176', '00177','00178','00179','00180')  and date_part('year',vales_movimientos.fecha)=p_anio and vales_personas.tiporelacion IN ('EMPLEADOS','DIRECCION/CONSEJEROS');

-- ##################
end if;
-- ##################
-- ### SECCION 10 ###
-- ##################
-- ##################


----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
end

$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION empresa_01.contab_actualizar_cuentas_con_contaplus(integer, character)
  OWNER TO dovalo;


CREATE OR REPLACE FUNCTION empresa_01.contab_crea_contaplus()
  RETURNS void AS
$BODY$
BEGIN
	BEGIN
	CREATE TEMP TABLE contab_contaplus
	(
	asien numeric(6),
	fecha date,
	subcta character(12),
	contra character(12),
	ptadebe numeric(16,2),
	concepto character(25),
	ptahaber numeric(16,2),
	factura numeric(8),
	baseimpo numeric(16,2),
	iva numeric(5,2),
	recequiv numeric(5,2),
	documento character(10),
	departa character(3) default '   ',
	clave character(6),
	estado character(1),
	ncasado numeric(6),
	tcasado numeric(1),
	trans numeric(6),
	cambio numeric(16,6),
	debeme numeric(16,2),
	haberme numeric(16,2),
	auxiliar character(1),
	serie character(1),
	sucursal character(4),
	coddivisa character(5),
	impauxme numeric(16,2),
	monedauso character(1),
	eurodebe numeric(16,2),
	eurohaber numeric(16,2),
	baseeuro numeric(16,2),
	noconv boolean,
	numeroinv character(10),
	serie_rt character(1),
	factu_rt numeric(8),
	baseimp_rt numeric(16,2),
	baseimp_rf numeric(16,2),
	rectifica boolean,
	fecha_rt date,
	nic character(1),
	libre boolean,
	libre2 numeric(6),
	iinterrump boolean,
	segactiv character(6),
	seggeog character(6),
	irect349 boolean,
	fecha_op date,
	fecha_ex date,
	departa5 character(5),
	factura10 character(10),
	porcen_ana numeric(5,2),
	porceng_seg numeric(5,2),
	numapunte numeric(6),
	eurototal numeric(16,2),
	razonsoc character(100),
	apellido1 character(50),
	apellido2 character(50),
	tipoope character(1),
	nfactick numeric(8),
	numacuini character(40),
	numacufin character(40),
	teridnif numeric(1),
	ternif character(15),
	ternom character(40),
	ternif14 character(9),
	tbientran boolean,
	tbiencod character(10),
	transinm boolean,
	metal boolean,
	metalimp numeric(16,2),
	cliente character(12),
	opbienes numeric(1),
	facturaex character(40),
	tipofac character(1),
	tipoiva character(1),
	relleno1 character(40),
	l340 boolean,
	relleno2 numeric(4) default 0
	)
	WITH (OIDS=FALSE);  
	EXCEPTION WHEN duplicate_table THEN
		delete from contab_contaplus;
	END;
END
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION empresa_01.contab_crea_contaplus()
  OWNER TO dovalo;


-- Function: empresa_01.contab_tipo_01(text)

-- DROP FUNCTION empresa_01.contab_tipo_01(text);

CREATE OR REPLACE FUNCTION empresa_01.contab_tipo_01(cfiltros text)
  RETURNS void AS
$BODY$
-- Revisado a: 20120418
declare 
	cSql text;
begin

cSql := '';
cSql := cSql || 'insert into contab_intermedia ';
--// Seccion del gasto, grupo 6. Caso estandar 
cSql := cSql || 'select nextval(''contab_intermedia_id_seq'') as id, ';
cSql := cSql || '0 as idcontabexp, 0 as asien, ';
cSql := cSql || 'max((Date_PART(''YEAR'',  doc.fechadoc::TIMESTAMP)||''-''||CASE WHEN DATE_PART(''MONTH'',doc.fechadoc::TIMESTAMP)<10 THEN ''0'' ELSE '''' END || DATE_PART(''MONTH'',doc.fechadoc::TIMESTAMP)||''-1'')::DATE + INTERVAL ''1 MONTH'' - INTERVAL ''1 DAY'') as fecha, ';
cSql := cSql || 'ctasdoc.ctadestino as subcta, ';
cSql := cSql || ''''' as contra, 0 as ptadebe, ';
cSql := cSql || 'max(''AL.'' || doc.coddelegacion|| (Date_PART(''YEAR'',  doc.fechadoc::TIMESTAMP)||''-''||CASE WHEN DATE_PART(''MONTH'',doc.fechadoc::TIMESTAMP)<10 THEN ''0'' ELSE '''' END || DATE_PART(''MONTH'',doc.fechadoc::TIMESTAMP)||''-1'')::DATE + INTERVAL ''1 MONTH'' - INTERVAL ''1 DAY'') as concepto, ';
cSql := cSql || '0 as ptahaber, 0 as factura, 0 as baseimpo, 0 as iva, ';
cSql := cSql || '0 as recequiv, max( doc.coddelegacion||(Date_PART(''YEAR'',  doc.fechadoc::TIMESTAMP)||''-''||CASE WHEN DATE_PART(''MONTH'',doc.fechadoc::TIMESTAMP)<10 THEN ''0'' ELSE '''' END || DATE_PART(''MONTH'',doc.fechadoc::TIMESTAMP)||''-1'')::DATE + INTERVAL ''1 MONTH'' - INTERVAL ''1 DAY'' ) as documento, ';
cSql := cSql || '''000'' as departa, max(series.codproyecto) as clave, ';
cSql := cSql || ''' '' as auxiliar, '' '' as serie, '''' as coddivisa, ''2'' as monedauso, ';
cSql := cSql || 'case when sum(lin.totlinea) >= 0 then sum(lin.totlinea) else 0 end as eurodebe, ';
cSql := cSql || 'case when sum(lin.totlinea) >= 0 then 0 else abs(sum(lin.totlinea)) end as eurohaber, ';
cSql := cSql || '0 as baseeuro, '''' as serie_rt, 0 as factu_rt, 0 as baseimp_rt, ';
cSql := cSql || '0 as baseimp_rf, false as rectifica, null::date as fecha_rt, ';
cSql := cSql || '''E'' as nic, null::date as fecha_op, ';
cSql := cSql || 'max((Date_PART(''YEAR'',  doc.fechadoc::TIMESTAMP)||''-''||CASE WHEN DATE_PART(''MONTH'',doc.fechadoc::TIMESTAMP)<10 THEN ''0'' ELSE '''' END || DATE_PART(''MONTH'',doc.fechadoc::TIMESTAMP)||''-1'')::DATE + INTERVAL ''1 MONTH'' - INTERVAL ''1 DAY'') as fecha_ex, ';
cSql := cSql || 'max( doc.coddelegacion||(Date_PART(''YEAR'',  doc.fechadoc::TIMESTAMP)||''-''||CASE WHEN DATE_PART(''MONTH'',doc.fechadoc::TIMESTAMP)<10 THEN ''0'' ELSE '''' END || DATE_PART(''MONTH'',doc.fechadoc::TIMESTAMP)||''-1'')::DATE + INTERVAL ''1 MONTH'' - INTERVAL ''1 DAY'' ) as factura10, ';
cSql := cSql || ''''' as razonsoc, '''' as apellido1, '''' as apellido2, ';
cSql := cSql || ''' '' as tipoope, 1 as nfactick, 0 as teridnif, ';
cSql := cSql || ''''' as ternif, '''' as ternom, false as metal, ';
cSql := cSql || '0 as metalimp, '''' as cliente, ';
cSql := cSql || '0 as opbienes, ';
cSql := cSql || ''''' as facturaex, ';
cSql := cSql || ''''' as tipofac, ';
cSql := cSql || ''''' as tipoiva, false as l340, ';
cSql := cSql || ''''' as nif, ';
cSql := cSql || '''coalbcab'' as tipodocumento, ';
cSql := cSql || 'doc.coddelegacion  as seriedocumento, ';
cSql := cSql || 'max((Date_PART(''YEAR'',  doc.fechadoc::TIMESTAMP)||CASE WHEN DATE_PART(''MONTH'',doc.fechadoc::TIMESTAMP)<10 THEN ''0'' ELSE '''' END || DATE_PART(''MONTH'',doc.fechadoc::TIMESTAMP)))::integer as numdocumento ';
cSql := cSql || 'from coalbcab doc ';
cSql := cSql || 'inner join coalblin lin on doc.seriedocumento = lin.seriedocumento and ';
cSql := cSql || 'doc.numdocumento = lin.numdocumento ';
cSql := cSql || 'inner join articulos art on lin.codarticulo = art.codarticulo ';
cSql := cSql || 'inner join arttipos tip on art.codtipo = tip.codtipo ';
cSql := cSql || 'inner join cuentas ctasdoc on tip.codcontable6 = ctasdoc.codcuenta ';
cSql := cSql || 'inner join proveedores mae on doc.codproveedor = mae.codproveedor ';
cSql := cSql || 'inner join seriescompras series on series.codserie = doc.seriedocumento ';
cSql := cSql || 'left join contab_excepciones exc on exc.codmaestro = mae.codproveedor and ';
cSql := cSql || 'exc.tipodocumento = ''coalbcab'' ';
cSql := cSql || 'left join cuentas ctasexc on exc.codcontabledocumento = ctasexc.codcuenta ';
cSql := cSql || 'where  ';
cSql := cSql || cFiltros ;
cSql := cSql || ' and (doc.idcontabexp=0 or doc.changepostexp) and series.ctrlcaja=true and ctasexc.codcuenta is null ';
cSql := cSql || 'group by (Date_PART(''YEAR'',  doc.fechadoc::TIMESTAMP)||''-''||CASE WHEN DATE_PART(''MONTH'',doc.fechadoc::TIMESTAMP)<10 THEN ''0'' ELSE '''' END || DATE_PART(''MONTH'',doc.fechadoc::TIMESTAMP)||''-1'')::DATE + INTERVAL ''1 MONTH'' - INTERVAL ''1 DAY'',doc.coddelegacion, ctasdoc.ctadestino ';

cSql := cSql || 'UNION ALL ';
--// Seccion del gasto, grupo 6. Caso  excepciones
cSql := cSql || 'select nextval(''contab_intermedia_id_seq'') as id, ';
cSql := cSql || '0 as idcontabexp, 0 as asien, ';
cSql := cSql || 'max((Date_PART(''YEAR'',  doc.fechadoc::TIMESTAMP)||''-''||CASE WHEN DATE_PART(''MONTH'',doc.fechadoc::TIMESTAMP)<10 THEN ''0'' ELSE '''' END || DATE_PART(''MONTH'',doc.fechadoc::TIMESTAMP)||''-1'')::DATE + INTERVAL ''1 MONTH'' - INTERVAL ''1 DAY'') as fecha, ';
cSql := cSql || 'ctasexc.ctadestino as subcta, ';
cSql := cSql || ''''' as contra, 0 as ptadebe, ';
cSql := cSql || 'max(''AL.'' || doc.coddelegacion|| (Date_PART(''YEAR'',  doc.fechadoc::TIMESTAMP)||''-''||CASE WHEN DATE_PART(''MONTH'',doc.fechadoc::TIMESTAMP)<10 THEN ''0'' ELSE '''' END || DATE_PART(''MONTH'',doc.fechadoc::TIMESTAMP)||''-1'')::DATE + INTERVAL ''1 MONTH'' - INTERVAL ''1 DAY'') as concepto, ';
cSql := cSql || '0 as ptahaber, 0 as factura, 0 as baseimpo, 0 as iva, ';
cSql := cSql || '0 as recequiv, max( doc.coddelegacion||(Date_PART(''YEAR'',  doc.fechadoc::TIMESTAMP)||''-''||CASE WHEN DATE_PART(''MONTH'',doc.fechadoc::TIMESTAMP)<10 THEN ''0'' ELSE '''' END || DATE_PART(''MONTH'',doc.fechadoc::TIMESTAMP)||''-1'')::DATE + INTERVAL ''1 MONTH'' - INTERVAL ''1 DAY'' ) as documento, ';
cSql := cSql || '''000'' as departa, max(series.codproyecto) as clave, ';
cSql := cSql || ''' '' as auxiliar, '' '' as serie, '''' as coddivisa, ''2'' as monedauso, ';
cSql := cSql || 'case when sum(lin.totlinea) >= 0 then sum(lin.totlinea) else 0 end as eurodebe, ';
cSql := cSql || 'case when sum(lin.totlinea) >= 0 then 0 else abs(sum(lin.totlinea)) end as eurohaber, ';
cSql := cSql || '0 as baseeuro, '''' as serie_rt, 0 as factu_rt, 0 as baseimp_rt, ';
cSql := cSql || '0 as baseimp_rf, false as rectifica, null::date as fecha_rt, ';
cSql := cSql || '''E'' as nic, null::date as fecha_op, ';
cSql := cSql || 'max((Date_PART(''YEAR'',  doc.fechadoc::TIMESTAMP)||''-''||CASE WHEN DATE_PART(''MONTH'',doc.fechadoc::TIMESTAMP)<10 THEN ''0'' ELSE '''' END || DATE_PART(''MONTH'',doc.fechadoc::TIMESTAMP)||''-1'')::DATE + INTERVAL ''1 MONTH'' - INTERVAL ''1 DAY'') as fecha_ex, ';
cSql := cSql || 'max( doc.coddelegacion||(Date_PART(''YEAR'',  doc.fechadoc::TIMESTAMP)||''-''||CASE WHEN DATE_PART(''MONTH'',doc.fechadoc::TIMESTAMP)<10 THEN ''0'' ELSE '''' END || DATE_PART(''MONTH'',doc.fechadoc::TIMESTAMP)||''-1'')::DATE + INTERVAL ''1 MONTH'' - INTERVAL ''1 DAY'' ) as factura10, ';
cSql := cSql || ''''' as razonsoc, '''' as apellido1, '''' as apellido2, ';
cSql := cSql || ''' '' as tipoope, 1 as nfactick, 0 as teridnif, ';
cSql := cSql || ''''' as ternif, '''' as ternom, false as metal, ';
cSql := cSql || '0 as metalimp, '''' as cliente, ';
cSql := cSql || '0 as opbienes, ';
cSql := cSql || ''''' as facturaex, ';
cSql := cSql || ''''' as tipofac, ';
cSql := cSql || ''''' as tipoiva, false as l340, ';
cSql := cSql || ''''' as nif, ';
cSql := cSql || '''coalbcab'' as tipodocumento, ';
cSql := cSql || 'doc.coddelegacion  as seriedocumento, ';
cSql := cSql || 'max((Date_PART(''YEAR'',  doc.fechadoc::TIMESTAMP)||CASE WHEN DATE_PART(''MONTH'',doc.fechadoc::TIMESTAMP)<10 THEN ''0'' ELSE '''' END || DATE_PART(''MONTH'',doc.fechadoc::TIMESTAMP)))::integer as numdocumento ';
cSql := cSql || 'from coalbcab doc ';
cSql := cSql || 'inner join coalblin lin on doc.seriedocumento = lin.seriedocumento and ';
cSql := cSql || 'doc.numdocumento = lin.numdocumento ';
cSql := cSql || 'inner join articulos art on lin.codarticulo = art.codarticulo ';
cSql := cSql || 'inner join arttipos tip on art.codtipo = tip.codtipo ';
cSql := cSql || 'inner join cuentas ctasdoc on tip.codcontable6 = ctasdoc.codcuenta ';
cSql := cSql || 'inner join proveedores mae on doc.codproveedor = mae.codproveedor ';
cSql := cSql || 'inner join seriescompras series on series.codserie = doc.seriedocumento ';
cSql := cSql || 'left join contab_excepciones exc on exc.codmaestro = mae.codproveedor and ';
cSql := cSql || 'exc.tipodocumento = ''coalbcab'' ';
cSql := cSql || 'left join cuentas ctasexc on exc.codcontabledocumento = ctasexc.codcuenta ';
cSql := cSql || 'where  ';
cSql := cSql || cFiltros ;
cSql := cSql || ' and (doc.idcontabexp=0 or doc.changepostexp) and series.ctrlcaja=true and ctasexc.codcuenta is not null ';
cSql := cSql || 'group by (Date_PART(''YEAR'',  doc.fechadoc::TIMESTAMP)||''-''||CASE WHEN DATE_PART(''MONTH'',doc.fechadoc::TIMESTAMP)<10 THEN ''0'' ELSE '''' END || DATE_PART(''MONTH'',doc.fechadoc::TIMESTAMP)||''-1'')::DATE + INTERVAL ''1 MONTH'' - INTERVAL ''1 DAY'',doc.coddelegacion, ctasexc.ctadestino ';

cSql := cSql || 'UNION ALL ';
--// Seccion del MAESTRO todos casos, general y excepciones..
cSql := cSql || 'select nextval(''contab_intermedia_id_seq'') as id, ';
cSql := cSql || '0 as idcontabexp, 0 as asien, ';
cSql := cSql || 'max((Date_PART(''YEAR'',  doc.fechadoc::TIMESTAMP)||''-''||CASE WHEN DATE_PART(''MONTH'',doc.fechadoc::TIMESTAMP)<10 THEN ''0'' ELSE '''' END || DATE_PART(''MONTH'',doc.fechadoc::TIMESTAMP)||''-1'')::DATE + INTERVAL ''1 MONTH'' - INTERVAL ''1 DAY'') as fecha, ';
cSql := cSql || '''400900002'' as subcta, ';
cSql := cSql || ''''' as contra, 0 as ptadebe, ';
cSql := cSql || 'max(''AL.'' || doc.coddelegacion||(Date_PART(''YEAR'',  doc.fechadoc::TIMESTAMP)||''-''||CASE WHEN DATE_PART(''MONTH'',doc.fechadoc::TIMESTAMP)<10 THEN ''0'' ELSE '''' END || DATE_PART(''MONTH'',doc.fechadoc::TIMESTAMP)||''-1'')::DATE + INTERVAL ''1 MONTH'' - INTERVAL ''1 DAY'' ) as concepto, ';
cSql := cSql || '0 as ptahaber, 0 as factura, 0 as baseimpo, 0 as iva, ';
cSql := cSql || '0 as recequiv, max(doc.coddelegacion||(Date_PART(''YEAR'',  doc.fechadoc::TIMESTAMP)||''-''||CASE WHEN DATE_PART(''MONTH'',doc.fechadoc::TIMESTAMP)<10 THEN ''0'' ELSE '''' END || DATE_PART(''MONTH'',doc.fechadoc::TIMESTAMP)||''-1'')::DATE + INTERVAL ''1 MONTH'' - INTERVAL ''1 DAY'') as documento, ';
cSql := cSql || '''000'' as departa, max(series.codproyecto) as clave, ';
cSql := cSql || ''' '' as auxiliar, '' '' as serie, '''' as coddivisa, ''2'' as monedauso, ';
cSql := cSql || 'case when sum(lin.totlinea) >= 0 then 0 else abs(sum(lin.totlinea)) end as eurodebe, ';
cSql := cSql || 'case when sum(lin.totlinea) >= 0 then sum(lin.totlinea) else 0 end as eurohaber, ';
cSql := cSql || '0 as baseeuro, '''' as serie_rt, 0 as factu_rt, 0 as baseimp_rt, ';
cSql := cSql || '0 as baseimp_rf, false as rectifica, null::date as fecha_rt, ';
cSql := cSql || '''E'' as nic, null::date as fecha_op, ';
cSql := cSql || 'max((Date_PART(''YEAR'',  doc.fechadoc::TIMESTAMP)||''-''||CASE WHEN DATE_PART(''MONTH'',doc.fechadoc::TIMESTAMP)<10 THEN ''0'' ELSE '''' END || DATE_PART(''MONTH'',doc.fechadoc::TIMESTAMP)||''-1'')::DATE + INTERVAL ''1 MONTH'' - INTERVAL ''1 DAY'') as fecha_ex, ';
cSql := cSql || 'max(doc.coddelegacion||(Date_PART(''YEAR'',  doc.fechadoc::TIMESTAMP)||''-''||CASE WHEN DATE_PART(''MONTH'',doc.fechadoc::TIMESTAMP)<10 THEN ''0'' ELSE '''' END || DATE_PART(''MONTH'',doc.fechadoc::TIMESTAMP)||''-1'')::DATE + INTERVAL ''1 MONTH'' - INTERVAL ''1 DAY'' ) as factura10, ';
cSql := cSql || ''''' as razonsoc, '''' as apellido1, '''' as apellido2, ';
cSql := cSql || ''' '' as tipoope, 1 as nfactick, 0 as teridnif, ';
cSql := cSql || ''''' as ternif, '''' as ternom, false as metal, ';
cSql := cSql || '0 as metalimp, '''' as cliente, ';
cSql := cSql || '0 as opbienes, ';
cSql := cSql || ''''' as facturaex, ';
cSql := cSql || ''''' as tipofac, ';
cSql := cSql || ''''' as tipoiva, false as l340, ';
cSql := cSql || ''''' as nif, ';
cSql := cSql || '''coalbcab'' as tipodocumento, ';
cSql := cSql || 'doc.coddelegacion  as seriedocumento, ';
cSql := cSql || 'max((Date_PART(''YEAR'',  doc.fechadoc::TIMESTAMP)||CASE WHEN DATE_PART(''MONTH'',doc.fechadoc::TIMESTAMP)<10 THEN ''0'' ELSE '''' END || DATE_PART(''MONTH'',doc.fechadoc::TIMESTAMP)))::integer as numdocumento ';
cSql := cSql || 'from coalbcab doc ';
cSql := cSql || 'inner join coalblin lin on doc.seriedocumento = lin.seriedocumento and ';
cSql := cSql || 'doc.numdocumento = lin.numdocumento ';
cSql := cSql || 'inner join articulos art on lin.codarticulo = art.codarticulo ';
cSql := cSql || 'inner join arttipos tip on art.codtipo = tip.codtipo ';
cSql := cSql || 'inner join cuentas ctasdoc on tip.codcontable6 = ctasdoc.codcuenta ';
cSql := cSql || 'inner join proveedores mae on doc.codproveedor = mae.codproveedor ';
cSql := cSql || 'inner join seriescompras series on series.codserie = doc.seriedocumento ';
cSql := cSql || 'left join contab_excepciones exc on exc.codmaestro = mae.codproveedor and ';
cSql := cSql || 'exc.tipodocumento = ''coalbcab'' ';
cSql := cSql || 'left join cuentas ctasexc on exc.codcontablemaestro = ctasexc.codcuenta ';
cSql := cSql || 'where  ';
cSql := cSql || cFiltros ;
cSql := cSql || ' and (doc.idcontabexp=0 or doc.changepostexp)  and series.ctrlcaja=true ';
cSql := cSql || 'group by (Date_PART(''YEAR'',  doc.fechadoc::TIMESTAMP)||''-''||CASE WHEN DATE_PART(''MONTH'',doc.fechadoc::TIMESTAMP)<10 THEN ''0'' ELSE '''' END || DATE_PART(''MONTH'',doc.fechadoc::TIMESTAMP)||''-1'')::DATE + INTERVAL ''1 MONTH'' - INTERVAL ''1 DAY'',doc.coddelegacion ';

cSql := cSql || ';';
Execute cSql;

end
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;



  CREATE OR REPLACE FUNCTION empresa_03.contenedor_valor_transporte(integer, text, integer)
  RETURNS numeric AS
$BODY$
------------------------------------------------------------------
--- Por ahora, todas las funciones de calculo llevan los parametros
--- id_plantilla, serie_documento, num_documento. 
------------------------------------------------------------------
DECLARE
	p_idPlantilla alias for $1;
	p_serie alias for $2;
	p_numdoc alias for $3;

	cEmp text;
	oReg record;
	nImp numeric;
	cSql text;
	bActualizar boolean;
	bExport boolean;
	cDel text;
	p_nif_cliente text;
BEGIN
	nImp = 0;
	bActualizar := false;
	bExport := true;
	select trim(codempresa) into cEmp from empresa;
	-- Si el idPlantilla es cero, solo retornamos el valor calculado, y 
	-- en caso contrario tambien actualizamos los registros de la valoracion
	-- del contenedor.
	if (p_idPlantilla > 0) then
		select * into oReg from exalbvaloraciones_plantilla where id = p_idPlantilla;
		if found then
			bActualizar := true;
		end if;
	end if;
	
	select trim(coddelegacion), 
		case when substring(codalmdestino,1,4)='ISLA' then false else true end as exportacion,trim(clientesexp.nif) into cDel, bExport, p_nif_cliente 
		from exalbcab inner join clientesexp on exalbcab.codclienteexp=clientesexp.codclienteexp
		where codempresa = cEmp and 
		seriedocumento=p_serie and numdocumento=p_numdoc;
	if char_length(coalesce(cDel,''))=0 then --si no se puede obtener el contenedor, es que viene de otra empresa (no está en la base de datos). En la práctica esto se da en
	--(estando en la empresa Recuperadora) los envíos de Fragmentadora a Recuperadora, o de Canarias Ambiental a Recuperadora, o (estando en Fragmentadora)
	--de Recuperadora a Fragmentadora, o (estando en Canarias Ambiental) de Recuperadora a canarias Ambiental. en cualquier caso, se pone como delegación Arinaga, puesto que no se consideran
	--probables envíos tipo: Canarias Ambiental TFN->Recuperadora TFS, en las que la delegación diferiría de ARI.
	  cDel:='ARI';
	end if;
       --RETURN 0;
	if (bExport) then  
	        if p_nif_cliente='RO01257736' then --Esta línea fue puesta por orden de Anastasio para que aparezca en la hoja de márgenes 16.01 €/Toneladas en los contenedores de los turcos
			select cantidad * 0.01601 into nImp
			from exalblin
			where seriedocumento=p_serie and numdocumento=p_numdoc;
	        else
			select es_exportacion into bExport from exalbestados where codempresa = cEmp and 
			seriedocumento=p_serie and numdocumento=p_numdoc;
			if (bExport) then
				select substring(txt,4,6)::numeric into nImp from (
				SELECT regexp_split_to_table('LPA 100,ARI 100,LAN 100,FUE 100,TFN 88,TFS 158,AR2 100', ',') as txt 
				)t where substring(txt,1,3) = substring(cDel,1,3);
			else
				nImp := 0;
			end if;
		end if;
	else
		nImp := 0;
	end if;
	
	if (bActualizar) then
		delete from exalbvaloraciones_detalle 
		where id_plantilla=p_idPlantilla and codempresa=cEmp and 
			seriedocumento=p_serie and numdocumento=p_numdoc;
	end if;
	
	if (bActualizar) then
		cSql := '';
		cSql := cSql || 'insert into exalbvaloraciones_detalle ';
		cSql := cSql || 'select nextval(''exalbvaloraciones_detalle_id_seq'') as id, ';
		cSql := cSql || '''' || cEmp || ''', ';
		cSql := cSql || '''' || p_serie || ''', ';
		cSql := cSql || '' || p_numdoc || ', ';
		cSql := cSql || '' || p_idPlantilla || ', ';
		cSql := cSql || '' || oReg.orden_visual || ', ';
		cSql := cSql || '0, ';
		cSql := cSql || '' || nImp || ', ';
		cSql := cSql || ''' '' ';
		cSql := cSql || ';';
		Execute cSql;
	end if;
	Return nImp;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


CREATE OR REPLACE FUNCTION empresa_03.cumple_condiciones_4009_errores_gestion(text, integer, date, date)
  RETURNS text AS
$BODY$				
--Devuelve una cadena vacía si el albarán pasado no tiene ningún problema de gestión. 
--Devuelve el texto del error en caso contrario
declare				
  p_serie  alias for $1 ;
  p_documento  alias for $2 ;
  p_fechafacturado alias for $3;
  p_fechapagado alias for $4;
  r record;
  p_tot numeric;
  p_msg text;
  p_codarticulo text;
  p_codtipo text;
  p_codcuenta text;
  p_ult_ejercicio integer;
  
begin
  select (max(date_part('year',ts_fecha))-1)::integer  into p_ult_ejercicio from cuentas;
  select coalbcab.*,proveedores.codproveedor as proveedor, coalbfirmas.totdocumento as totfirmado,cuentas.codcuenta 
	into r 
	from coalbcab left join coalbfirmas on coalbcab.seriedocumento=coalbfirmas.seriedocumento and coalbcab.numdocumento=coalbfirmas.numdocumento
              left join proveedores on coalbcab.codproveedor=proveedores.codproveedor
              left join cuentas on proveedores.codcontable=cuentas.codcuenta
  where coalbcab.seriedocumento=trim(p_Serie) and coalbcab.numdocumento=p_documento;
  
  if not found then --si el albarán pasado no se encuentra=>retornamos un error
     return 'Albarán '||trim(p_serie)||'/'||p_documento||' no encontrado.';
  end if;
  
 

  if r.proveedor is null then
     return 'El albarán no tiene un proveedor válido asignado.';
  end if;

  if r.codcuenta is null then
     return 'El proveedor :'||r.proveedor||' No tiene una cuenta contable asignada (proceso de conciliación de cuentas).';
  end if;

  if r.tipofpago in ('CONTADO','DONACION') and r.fechapagado is null then
     return 'Albarán sin especificarse la fecha de Pago.';
  end if;

  p_msg:='';-- A partir de aquí, los mensages de error se obtendrán acumulados. 
  
  if r.codcierre<>0 and  r.tipofpago='CONTADO' then 
	-- Si ha sido pagado en el último ejercicio conciliado (o antes) ya
	-- existe en la tabla vencimientos, y por lo tanto exportado a contabilidad.
	-- Si el pago fue posterior al último ejercicio conciliado, ya no evaluamos 
	-- si existe en vencimientos, ya que, en principio, no va a estar.
	if (date_part('year',r.fechapagado) <= p_ult_ejercicio) then
		select coalesce(sum(totdocumento),0) 
			into p_tot 
			from vencimientos 
			where tipodocumento='COALBCAB' and facserie=trim(p_serie) and facdocumento=p_documento;
		if abs(p_tot-r.totdocumento)>0.01 then 
			-- la cantidad del albarán no coincide con el pago del albarán
			p_msg:='El albarán consta como pagado. El importe del albarán es:'||
				r.totdocumento||'. El pago en el momento de la conciliación de cuentas:'||
				p_tot||'. Se alteró una vez se pagó, o bien no se concilió en el año de emisión.';
		end if; 
	end if;
	if  r.totfirmado is not null then 
		if abs(r.totfirmado-r.totdocumento)>0.01 then 
			--El total del albarán firmado no coincide con el total del albarán actual
			p_msg:=p_msg||'El albarán consta como pagado y firmado. El importe del albarán es:'||
				r.totdocumento||'. El importe que se firmó es:'||
				r.totfirmado||'. Esto significa que el albarán se alteró una vez firmado.';
		end if;
	end if;
  end if;


  select concatenate(case when articulos.codarticulo is null then coalblin.codarticulo else '' end), 
	concatenate(case when arttipos.codtipo is null then articulos.codarticulo else '' end)
        ,concatenate(case when cuentas.ctadestino is not null and cuentas.ctadestino like '600%' then '' else coalblin.codarticulo end)
         into  p_codarticulo, p_codtipo, p_codcuenta
  from coalblin left join articulos on coalblin.codarticulo=articulos.codarticulo 
  left join arttipos on articulos.codtipo=arttipos.codtipo 
  left join cuentas on arttipos.codcontable6=cuentas.codcuenta
  where coalblin.seriedocumento=trim(p_Serie) and coalblin.numdocumento=p_documento and 
	(articulos.codarticulo is null or arttipos.codtipo is null);
  if char_length(p_codarticulo)>0 then
     p_msg:=p_msg|| 'Artículo/s inexistente en el albarán ('||p_codarticulo||').';
  end if;

  if char_length(p_codtipo)>0 then
     p_msg:=p_msg||'Artículo '||p_codtipo||' al que no se le ha vinculado un tipo (para determinar cuenta del grupo 6).';
  end if;

  if char_length(p_codcuenta)>0 and char_length(p_codtipo)=0 then 
	--está vinculado a arttipos, pero apunta a una cuenta contable incorrecta
	p_msg:=p_msg||'Artículo '||p_codtipo||' vinculado a un tipo que no apunta a una cuenta del grupo 600 .';
  end if;
          
  if p_fechafacturado is null then --albarán no facturado. No hacemos más comprobaciones     
     return p_msg;
  end if;

  -- Si estamos aquí, es que el albarán está facturado
  for r in
        select distinct t.* 
        -- ponemos un distinct, porque se puede obtener tantos registros iguales por la misma 
        -- línea de albarán que está más de una vez facturada
        from (
	select alb.seriedocumento,alb.numdocumento,alb.codarticulo as codarticuloalb,
		alb.totlinea as totlineaalb,alb.ordarticulo,alb.impuesto as impuestoalb,
	       fac.facserie,fac.facdocumento,fac.codarticulo as codarticulofac, fac.totlinea as totlineafac,
	       fac.posarticulo,fac.impuesto as impuestofac, 
	       concatenate(trim(fac.facserie)||'/'||fac.facdocumento) over (partition by alb.seriedocumento,
	       alb.numdocumento,alb.ordarticulo order by fac.albdocumento) as facturasvinculadas,
	       count(*) over (partition by alb.seriedocumento,alb.numdocumento,alb.ordarticulo) as numfacturasvinculadas,
	       sum(alb.totlinea) over (partition by alb.seriedocumento,alb.numdocumento) as totalb,
	       sum(fac.totlinea) over (partition by fac.albserie,fac.albdocumento) as totalbfac
	from (coalbcab 
		inner join coalblin  alb on coalbcab.seriedocumento=alb.seriedocumento and coalbcab.numdocumento=alb.numdocumento) 
		full join 
		(select * from cofaclin where albserie=trim(p_Serie) and albdocumento=p_documento) fac 
			on alb.seriedocumento=fac.albserie and alb.numdocumento=fac.albdocumento and 
			alb.ordarticulo=fac.posarticulo
			where (alb.seriedocumento=trim(p_Serie) and alb.numdocumento=p_documento) 
		) t  loop
		--comprobar si un albarán está facturado más de una vez.
        if r.numfacturasvinculadas>1 then
           p_msg:=p_msg||case when char_length(p_msg)>0 then chr(10) else '' end||'La linea del albarán de artículo:'||
           r.codarticuloalb||' con importe: '||r.totlineaalb||' Está facturada más de una vez. Facturas: '||r.facturasvinculadas||'.';
        end if;

	if abs(coalesce(r.totalb,0)-coalesce(r.totalbfac,0))>0.01 then
		
		if r.facserie is null then --Una de las líneas del albarán no está facturada
			p_msg:=p_msg||case when char_length(p_msg)>0 then chr(10) else '' end||
				     'La linea del albarán de artículo:'||r.codarticuloalb||' con importe: '||r.totlineaalb||
				     ' No está facturada (ordarticulo: '||r.ordarticulo||')'||'.';
		elsif r.seriedocumento is null then --Una de las líneas de la factura no tiene albarán (seguramente no coincide el ordarticulo)
			p_msg:=p_msg||case when char_length(p_msg)>0 then chr(10) else '' end||'La linea de la factura de artículo:'||r.codarticulofac||' con importe: '||r.totlineafac||' No tiene correspondencia con alguna línea de albarán (posarticulo en la factura: '||r.posarticulo||')'||'.';
		elsif (r.seriedocumento is not null and r.facserie is not null) then --Hay correspondencia entre la línea del albarán y la línea de la factura
			if abs(r.totlineaalb-r.totlineafac)>0.01 then --los importes de la línea de factura con línea del albarán no coinciden
				p_msg:=p_msg||case when char_length(p_msg)>0 then chr(10) else '' end||
					      'La linea del albarán de artículo:'||r.codarticuloalb||' con importe: '||r.totlineaalb||
					      ' no coincide con el importe de línea de la factura: '||r.totlineafac||'.';
			end if;
			if r.impuestoalb<>r.impuestofac  then --El impuesto de la línea del albarán es distinto del impuesto de la factura
				p_msg:=p_msg||case when char_length(p_msg)>0 then chr(10) else '' end||'La linea del albarán de artículo:'||r.codarticulofac||' con importe: '||r.totlineaalb||' no coincide con el importe de factura: '||r.totlineafac||'.';
			end if;
		else  -- podría haber algún otro motivo por el que el total de las líneas facturadas del albarán no coincide con el total del albarán (no se me ocurre cual, pero se deja por si acaso)
			p_msg:=p_msg||case when char_length(p_msg)>0 then chr(10) else '' end||
				      'El importe de todas las líneas del albarán es:'||r.totalb||'. El de las líneas de factura de ese albarán: '||r.totalbfac||
				      '. No coinciden.';
		end if;
	end if;
  end loop;
  return p_msg;	
  END;				
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


CREATE OR REPLACE FUNCTION empresa_03.dl(stra text, strb text)
  RETURNS integer AS
$BODY$
declare
    rows integer;
    cols integer;
begin
    rows := length(stra);
    cols := length(strb);

    IF rows = 0 THEN
    	return cols;
    END IF;
    IF cols = 0 THEN
	return rows;
    END IF;

    declare
	row_u integer[];
	row_l integer[];
	diagonal integer;
	upper integer;
	left integer;
    begin
	FOR i in 0..cols LOOP
	    row_u[i] := i;
	END LOOP;

	FOR i IN 1..rows LOOP
	    row_l[0] := i;
	    FOR j IN 1..cols LOOP
	        IF substring (stra, i, 1) = substring (strb, j, 1) THEN
		    diagonal := row_u[j-1];
		else
		    diagonal := row_u[j-1] + 1;
		END IF;
		upper := row_u[j] + 1;
		left := row_l[j-1] + 1;
		row_l[j] := int4smaller(int4smaller(diagonal, upper), left);
		END LOOP;
            row_u := row_l;
	END LOOP;
	return row_l[cols];
    end;
end
$BODY$
  LANGUAGE plpgsql IMMUTABLE STRICT
  COST 100;
ALTER FUNCTION empresa_03.dl(text, text)
  OWNER TO dovalo;


REATE OR REPLACE FUNCTION empresa_03.docvinculos(integer, character, character, integer)
  RETURNS SETOF record AS
$BODY$
declare
--dado un tipo de vinculo (1 o 2) y la empresa, serie y número de contenedor, nos devolverá su correspondiente serie y número de albarán vinculado
p_id alias for $1;
p_codempresa alias for $2;
p_serie alias for $3;
p_num alias for $4;

begin
RETURN QUERY
SELECT p.seriedoc,p.numdoc,p.serielink,p.numlink
FROM dblink('dbname=''acceso'' port=5432 host=localhost user=dovalo password=Aobifome'::text,
'SELECT seriedoc,numdoc,serielink,numlink FROM em_exalbcab_docvinculados('||p_id||','''||p_codempresa||''','''||p_serie||''','||p_num||')'::text) AS P(
  seriedoc character(10),
  numdoc integer,
  serielink character(10),
  numlink integer

);

 end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;


CREATE OR REPLACE FUNCTION empresa_03.expedidos_almacenaje(IN integer, IN character, OUT ser_proalb character, OUT num_proalb integer, OUT fechadoc date, OUT cantidad numeric, OUT codarticulo character, OUT nomarticulo character varying, OUT ordarticulo integer, OUT id_pedido_prod integer, OUT id_pedido_cont integer, OUT ser_coped character, OUT num_coped integer, OUT ser_exalb text, OUT num_exalb integer, OUT ser_exfac text, OUT num_exfac integer)
  RETURNS SETOF record AS
$BODY$
-- Retorna un conjunto registros con las transformaciones asociadas a un pedido, e informacion
-- del documento de pallets, contenedor y factura a los que están asociados.
declare 
	p_idPedido alias for $1;
	p_filtros alias for $2;
	p_sql text;     
begin
	p_sql := '';
	p_sql := p_sql || ' select proalbcab.seriedocumento as ser_proalb, proalbcab.numdocumento as num_proalb, proalbcab.fechadoc,  ';
	p_sql := p_sql || ' 	proalblin.cantidad, proalblin.codarticulo, proalblin.nomarticulo, proalblin.ordarticulo,  ';
	p_sql := p_sql || ' 	proalbcab.id_pedido as id_pedido_prod, ped.idpedido as id_pedido_cont, ';
	p_sql := p_sql || ' 	ped.ser_coped, ped.num_coped, ';
	p_sql := p_sql || ' 	coalesce(ped.ser_exalb, ''SIN CONTENEDOR''::text)::text as ser_exalb, ped.num_exalb, ';
	p_sql := p_sql || ' 	coalesce(ped.ser_exfac, ''SIN FACTURAR''::text)::text as ser_exfac, ped.num_exfac ';
	p_sql := p_sql || ' from proalbcab  ';
	p_sql := p_sql || ' inner join proalblin on proalbcab.seriedocumento=proalblin.seriedocumento  ';
	p_sql := p_sql || ' 	and proalbcab.numdocumento=proalblin.numdocumento  ';
	p_sql := p_sql || ' 	and proalbcab.id_pedido = ' || p_idPedido::text || ' ';
	p_sql := p_sql || ' 	and proalblin.estadoarttrans = ''OU'' ';
	p_sql := p_sql || ' left join ( select  ';
	p_sql := p_sql || ' 	exalblin.pedserie as ser_coped, exalblin.peddocumento as num_coped, exalblin.idpedido,  ';
	p_sql := p_sql || ' 	exalblin.seriedocumento as ser_exalb, exalblin.numdocumento as num_exalb, ';
	p_sql := p_sql || ' 	copedlin.facserie, copedlin.facdocumento, ';
	p_sql := p_sql || ' 	exfaclin.seriedocumento as ser_exfac, exfaclin.numdocumento as num_exfac ';
	p_sql := p_sql || ' 	from exalblin  ';
	p_sql := p_sql || ' 	inner join copedlin on exalblin.pedserie=copedlin.seriedocumento  ';
	p_sql := p_sql || ' 	and exalblin.peddocumento=copedlin.numdocumento  ';
	p_sql := p_sql || ' 	and exalblin.idpedido = ' || p_idPedido::text || ' ';
	p_sql := p_sql || ' 	left join exfaclin on exalblin.codempresa = exfaclin.codempresa  ';
	p_sql := p_sql || ' 		and exalblin.seriedocumento=exfaclin.albserie and exalblin.numdocumento=exfaclin.albdocumento ';
	p_sql := p_sql || ' 		and exalblin.ordarticulo = exfaclin.posarticulo ';
	p_sql := p_sql || ' ) ped on ped.facserie=proalbcab.seriedocumento and ped.facdocumento=proalbcab.numdocumento ';
	if (char_length(p_filtros) > 0) then 
		p_sql := p_sql || ' where ';
		p_sql := p_sql || p_filtros;
	end if;
	p_sql := p_sql || ' order by num_proalb ';
	RETURN QUERY execute p_sql;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;

CREATE OR REPLACE FUNCTION empresa_03.expedidos_base(IN character, OUT idpedido integer, OUT codclienteexp character, OUT fechadoc date, OUT fechavalidodesde date, OUT fechavalidohasta date, OUT cantidadkg numeric, OUT preciokg numeric, OUT descripcion character varying, OUT observaciones character varying, OUT idprioridad integer, OUT ts_cerrado timestamp without time zone, OUT numdoccliexp character varying, OUT nomclienteexp character varying, OUT con_almacenaje boolean, OUT codarticulos text, OUT nomarticulos text, OUT lin_validadas bigint, OUT lin_pdtes_validar bigint, OUT cantidadpdte numeric, OUT cantidadalm numeric)
  RETURNS SETOF record AS
$BODY$
-- Retorna un conjunto de pedidos de exportacion que cumplen unos filtros.
declare 
	p_filtros alias for $1;
	p_sql text;     
begin
	p_sql := '';
	p_sql := p_sql || ' SELECT distinct expedcab.id as idpedido, expedcab.codclienteexp, ' ;
	p_sql := p_sql || ' expedcab.fechadoc, expedcab.fechavalidodesde, ';
	p_sql := p_sql || '	expedcab.fechavalidohasta, expedcab.cantidadkg, expedcab.preciokg, ';
	p_sql := p_sql || '	expedcab.descripcion, expedcab.observaciones, expedcab.idprioridad, expedcab.ts_cerrado, ';
	p_sql := p_sql || '	expedcab.numdoccliexp, clientesexp.nomclienteexp, expedcab.con_almacenaje, ';
	p_sql := p_sql || '	concatenate(articulos.codarticulo) over (partition by expedcab.id) as codarticulos, ';
	p_sql := p_sql || '	concatenate(articulos.descripcion) over (partition by expedcab.id) as nomarticulos, ';
	p_sql := p_sql || '	coalesce(lin_validadas,0) as lin_validadas, coalesce(lin_pdtes_validar,0) as lin_pdtes_validar, ';
	p_sql := p_sql || '	expedcab.cantidadkg - coalesce(ex.cantidadserv,0) as cantidadpdte, ';
	p_sql := p_sql || '	coalesce(pr.cantidadalm,0) as cantidadalm ';
	p_sql := p_sql || 'FROM expedcab  ';
	p_sql := p_sql || '	inner join clientesexp on expedcab.codclienteexp=clientesexp.codclienteexp ';
	p_sql := p_sql || '	left join expedlin on expedcab.id=expedlin.idpedido  ';
	p_sql := p_sql || '	left join articulos on expedlin.codarticulo = articulos.codarticulo ';
	p_sql := p_sql || '	left join (select exalblin.idpedido, exalblin.codarticulo, ';
	p_sql := p_sql || '	sum(coalesce(exalblin.stkinicial,0)) as cantidadserv, ';
	p_sql := p_sql || '	sum(case when exalbestados.ts_validado is not null then 1 else 0 end) as lin_validadas, ';
	p_sql := p_sql || '	sum(case when exalbestados.ts_validado is null and exalbestados.numdocumento is not null ';
	p_sql := p_sql || '		then 1 else 0 end) as lin_pdtes_validar from ';
	p_sql := p_sql || '		exalblin  ';
	p_sql := p_sql || '		inner join exalbestados on exalblin.albserie=exalbestados.seriedocumento  ';
	p_sql := p_sql || '			and exalblin.albdocumento=exalbestados.numdocumento and exalblin.codempresa=exalbestados.codempresa ';
	p_sql := p_sql || '		inner join exalbcab on exalblin.albserie=exalbcab.seriedocumento  ';
	p_sql := p_sql || '			and exalblin.albdocumento=exalbcab.numdocumento and exalblin.codempresa=exalbcab.codempresa ';
	p_sql := p_sql || '			and exalbcab.contenedor not like ''' || 'XXX%' || ''' ';
	p_sql := p_sql || '		group by exalblin.idpedido, exalblin.codarticulo ';
	p_sql := p_sql || '	) ex ';
	p_sql := p_sql || '	on expedlin.idpedido=ex.idpedido and expedlin.codarticulo=ex.codarticulo ';
	p_sql := p_sql || '	left join (select proalbcab.id_pedido, sum(proalblin.cantidad) as cantidadalm from ';
	p_sql := p_sql || '		proalbcab  ';
	p_sql := p_sql || '		inner join proalblin on proalbcab.seriedocumento=proalblin.seriedocumento  ';
	p_sql := p_sql || '			and proalbcab.numdocumento=proalblin.numdocumento and proalblin.estadoarttrans=''OU'' ';
	p_sql := p_sql || '			and proalbcab.id_pedido > 0 ';
	p_sql := p_sql || '		group by proalbcab.id_pedido ';		
	p_sql := p_sql || '	) pr ';
	p_sql := p_sql || '	on expedlin.idpedido=pr.id_pedido  ';
	if (char_length(p_filtros) > 0) then
		p_sql := p_sql || ' where ';
		p_sql := p_sql || p_filtros;
	end if;
	RETURN QUERY execute p_sql;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;


CREATE OR REPLACE FUNCTION empresa_03.fifoapuntasalidaaux(character, character, real, text, text, integer, integer, date, text)
  RETURNS text AS
$BODY$
declare

p_CODDELEGACION ALIAS FOR $1;
p_CODART ALIAS FOR $2;
p_CANTIDAD ALIAS FOR $3;
p_TIPODOCSALIDA ALIAS FOR $4;
p_SERIEDOCUMENTO ALIAS FOR $5;
p_NUMDOCUMENTO ALIAS FOR $6;
p_lineasalida alias for $7;
p_fechasalida alias for $8;
p_filtro alias for $9;
r record;
articulo articulos%ROWTYPE;
entrada bool;
cant real;
cSql text;

begin
  -- Comprobaciones inniciales ya están hechas puesto que a esta función solo la llama fifoanaliza  
cSql:='select stk.seriedocumento as Eserie,stk.numdocumento as Enumdocumento, stk.ordarticulo AS Eorden, ';
cSql:=cSql || ' stk.cantidad-sum(CASE WHEN fifo.CANTIDAD IS NULL THEN 0 ELSE FIFO.CANTIDAD END) as stock, stk.tipodoc ';
cSql:=cSql || ' from STOCKSMOV stk ';
cSql:=cSql || ' inner join fifostockini fifoini on stk.codarticulo=fifoini.codarticulo and stk.coddelegacion = fifoini.coddelegacion and stk.fechadoc>= fifoini.fecha  ';
cSql:=cSql || 'left join fifostocaje fifo on stk.coddelegacion=fifo.coddelegacion and stk.codarticulo=fifo.codarticulo AND stk.seriedocumento=fifo.SERIEDOCUMENTOENTRADA and  STK.NUMDOCUMENTO=FIFO.NUMDOCUMENTOENTRADA AND stk.ordarticulo=fifo.ordenlinENTRADA ';
cSql:=cSql || 'where stk.fechadoc>= fifoini.fecha and stk.coddelegacion='''|| p_CODDELEGACION ||''' and stk.codarticulo='''|| p_CODART ||''' ';
cSql:=cSql || p_filtro;
cSql:=cSql || ' group by stk.seriedocumento, stk.numdocumento, stk.ordarticulo, stk.cantidad, stk.tipodoc,stk.fechadoc ';
cSql:=cSql || 'HAVING STK.CANTIDAD-SUM(CASE WHEN fifo.CANTIDAD IS NULL THEN 0 ELSE FIFO.CANTIDAD END)>0 ';
cSql:=cSql || 'ORDER BY STK.FECHADOC,STK.NUMDOCUMENTO ';
/*fifostockini es la tabla que indica la fecha sobre la que se va a consultar en el histórico de movimientos
  fifostocaje es la tabla donde se registran la vinculación de Movimientos de entrada <=> movimientode salida
  stocksmov es una vista con todos los movimientos de stock, ya vengan de albaranes de compras,facturas de venta, o albaranes de venta
*/  


--FOR r IN EXECUTE cSql LOOP 
  cant:=abs(p_cantidad); --Puede ser  negativo si es una salida por albarán de compra
  entrada:=false;
   
 FOR r IN EXECUTE cSql LOOP
    if (r.stock<=cant) then
      cant:=cant-r.stock;
      INSERT INTO fifostocaje (CODDELEGACION,codarticulo,TIPODOCENTRADA,TIPODOCSALIDA,SERIEDOCUMENTOENTRADA,numdocumentoentrada,ordenlinentrada,seriedocumentosalida, NUMDOCUMENTOSALIDA,CANTIDAD,ordenlineasalida,FECHASALIDA) VALUES
	    (p_CODDELEGACION,p_CODART,r.tipodoc,p_TIPODOCSALIDA, r.Eserie, r.Enumdocumento,r.Eorden,p_seriedocumento, p_numdocumento, r.STOCK, p_lineasalida,current_date);
    else
      if (cant< r.stock and cant>0) then
        INSERT INTO fifostocaje (CODDELEGACION,codarticulo,TIPODOCENTRADA,TIPODOCSALIDA,SERIEDOCUMENTOENTRADA,numdocumentoentrada,ordenlinentrada,seriedocumentosalida, NUMDOCUMENTOSALIDA,CANTIDAD,ordenlineasalida,FECHASALIDA) VALUES
	      (p_CODDELEGACION,p_CODART,r.tipodoc,p_TIPODOCSALIDA, r.Eserie, r.Enumdocumento,r.Eorden,p_seriedocumento, p_numdocumento, cant,p_lineasalida,current_date);
	      cant:=0;
      else
        exit;
      END IF; 
    end if;
END LOOP;
if cant>0 then 
    -- return 'ERROR: No hay stock suficiente para cubrir esta salida ('||cant::text||')';
end if;
RETURN 'OK';
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


  CREATE OR REPLACE FUNCTION empresa_03.nextcodcontable(text, boolean)
  RETURNS text AS
$BODY$
--Busca un codcontabble disponible en la tabla cuentas del grupo pasado por parámetro:
--si se le pasa reiniciar,devuelve la posición anterior al primer hueco disponible. Si se la pasa p_reiniciar=false devuelve el siguiente hueco disponible
declare 
        p_grupocuenta alias for $1;
        p_reiniciar alias for $2;
	p_ctadestino text;
begin


  if p_reiniciar then
  --devuelve el valor más pequeño, cuyo valor siguiente no existe (es un hueco)
       select min(c1.ctadestino::integer) as  ctadestino into p_ctadestino from cuentas c1 left join cuentas c2 on c1.ctadestino::integer+1=(c2.ctadestino::integer)  and c2.ctadestino like trim(p_grupocuenta)||'%' and char_length(c2.ctadestino)=9
       where c1.ctadestino like trim(p_grupocuenta)||'%' and char_length(c1.ctadestino)=9 and lpad(trim(p_grupocuenta),9,'0')<trim(c1.ctadestino) and c2.ctadestino is null; 
  else   
     select min(coalesce(sigvalorsecuencia.ctadestino,sighueco.ctadestino::integer)) into p_ctadestino
     from  (--esta primera consulta devuelve un sólo registro si el valor actual de la secuencia no se encuentra en la tabla en cuestión (hay un hueco). Si sí está, no devuelve nada
            select tcurval.ctadestino from (select currval('secctadestino')::integer  as ctadestino) tcurval left join cuentas on tcurval.ctadestino::integer=cuentas.ctadestino::integer AND tcurval.ctadestino::text like trim(p_grupocuenta)||'%' and char_length(cuentas.ctadestino::text)=9 and lpad(trim(p_grupocuenta),9,'0')<trim(tcurval.ctadestino::text) where cuentas.ctadestino is null) sigvalorsecuencia 
         full join 
           (--la siguiente subquery devuelve el valor del siguiente hueco que no tiene porqué ser consecutivo a la secuencia.relaciona la tabla consigo mismo uniéndose por el siguiente valor en secuencia de la primera tabla es igual al de la segunda tabla, y el registro de la segunda tabla es nulo.
            -- Si se cumple dicha condición de unión, devuelve el valor de la primera tabla +1 (el hueco encontrado)
            select c1.ctadestino::integer+1 as ctadestino from cuentas c1 left join cuentas c2 on char_length(c2.ctadestino)=9 and c1.ctadestino::integer +1=(c2.ctadestino::integer)  and c2.ctadestino like trim(p_grupocuenta)||'%' 
	    where char_length(c1.ctadestino)=9 and c1.ctadestino like trim(p_grupocuenta)||'%'  and lpad(trim(p_grupocuenta),9,'0')<trim(c1.ctadestino) and c2.ctadestino is null and c1.ctadestino::integer>=currval('secctadestino')::integer
           ) sighueco --Puesto que la primera query sólo devuelve un registro, no es necesario establecer condición de join. Aún así la ponemos
           on sighueco.ctadestino::integer=sigvalorsecuencia.ctadestino::integer;
    
  end if;
  if char_length(p_ctadestino)>0 then
    perform setval('secctadestino',p_ctadestino::integer); --establemos la secuencia al valor encontrado
    perform nextval('secctadestino');--avanzamos la secuencia para la próxima llamada
    return lpad(p_ctadestino,9,'0');
  else
    return nextval('secctadestino');
  end if;
 

end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


  CREATE OR REPLACE FUNCTION empresa_03.nextcodcontable(text)
  RETURNS text AS
$BODY$
--Busca un codcontabble disponible en la tabla cuentas del grupo pasado por parámetro:
--ejemplo: nextcodcontable('4000') busca una cuenta de proveedor disponible, y si no, hace un max + 1 del grupo y lo devuelve
declare 
        p_grupocuenta alias for $1;
	p_ctadestino text;
begin
  select min(c1.ctadestino::integer +1) into p_ctadestino from cuentas c1 left join cuentas c2 on c1.ctadestino::integer+1=(c2.ctadestino::integer)  and c2.ctadestino like trim(p_grupocuenta)||'%' and char_length(c2.ctadestino)=9
  where c1.ctadestino like trim(p_grupocuenta)||'%' and char_length(c1.ctadestino)=9 and lpad(trim(p_grupocuenta),9,'0')<trim(c1.ctadestino) and c2.ctadestino is null;

  if char_length(p_ctadestino)>0 then
    return lpad(p_ctadestino,9,'0');
  else
    return '000000000';
  end if;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

  CREATE OR REPLACE FUNCTION empresa_01.nif_valido(nif text)
  RETURNS boolean AS
$BODY$
------------------------------------------------------------------
--- Funcion para verificar el NIF español o el NIE de extranjeros
------------------------------------------------------------------
declare
    local_nif character(50);
    dni character(8);
    letra character(1);
--    cols integer;
begin
	-- Eliminamos los guiones, puntos, separadores, etc que
	-- puedan haber pasado.
	local_nif := nif;
	local_nif := replace(local_nif, '.','');
	local_nif := replace(local_nif, '-','');
	local_nif := replace(local_nif, ',','');
	local_nif := replace(local_nif, ' ','');
	local_nif := replace(local_nif, '*','');
	
	if (char_length(local_nif) != 9) then
		return false;
	end if;
	-- Los CIFs los daremos por válidos
	if (substring(local_nif, 1,1) between 'A' and 'W') then
		return true;
	end if;
	
	dni := substring(local_nif, 1, 8);
	letra := substring(local_nif, 9, 1);
	dni := replace(dni, 'X', '');
	dni := replace(dni, 'Y', '1');
	dni := replace(dni, 'Z', '2');

	-- si llegados a este punto, el primer digito no es un numero
	-- entenderemos que no es valido.
	if (substring(dni, 1, 1) not in ('0','1','2','3','4','5','6','7','8','9')) then
		return false;
	end if;
	if (letra = substring('TRWAGMYFPDXBNJZSQVHLCKE', dni::integer % 23 + 1, 1)) then
		return true;
	end if;
	return false;
end
$BODY$
  LANGUAGE plpgsql IMMUTABLE STRICT
  COST 100;

  CREATE OR REPLACE FUNCTION empresa_01.particularesok(text)
  RETURNS text AS
$BODY$	
declare	
/*devuelve una cadena de texto indicando si el proveedor está completo.	
  1) Si no existe conflicto retorna el texto 'OK'	
  2) Si hay conflicto retorna un texto indicando el campo que falta por completar	

*/	
p_codproveedor ALIAS FOR $1;	
r record;
p_nifCA text;
	
begin
   p_nifCA:='';
   select cif into p_nifCA from empresa;
   
   select trim(p.codproveedor) as codproveedor,trim(p.nomproveedor) as nomproveedor, trim(p.nif) as nif, 
   trim(nomcomercial) as nomcomercial, trim(d.direccion) as direccion, trim(localidad) as localidad, 
   trim (provincia) as provincia , fechanacimiento
   into r
   from proveedores p inner join prodir d on p.codproveedor=d.codproveedor
   where p.codproveedor=p_codproveedor;
   if found then
      if char_length(r.codproveedor)<2 then
        return 'Falta completar el codigo de proveedo';
      end if;
      if char_length(r.nomproveedor)<2 then
        return 'Falta completar el nombre de proveedor (nomproveedor)';
      end if;
      if char_length(r.nif)<2 then
        return 'Falta completar el nif de proveedor (nif)';
      end if;
      if char_length(r.nomcomercial)<2 then
        return 'Falta completar el nombre comercial del proveedor (nomcomercial)';
      end if;
      if p_nifCA<>'B35855543' then
        if char_length(r.direccion)<2 then
          return 'Falta completar la dirección de proveedor (direccion)';
        end if;
        if char_length(r.localidad)<2 then
          return 'Falta completar la localidad de proveedor (localidad)';
        end if;
       
        if char_length(r.provincia)<2 then
          return 'Falta completar la provincia del proveedor (provincia)';
        end if;
      end if;
      
      if r.fechanacimiento is null then
        --return 'Falta completar la fecha de nacimiento del proveedor, para calcular su edad';
      end if;
   else
      return 'Proveedor con código '||p_codproveedor||' no se encuentra, o no tiene una dirección asignada';
   end if;
   return 'OK';   

END;	
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION empresa_01.particularesok(text)
  OWNER TO dovalo;

  CREATE OR REPLACE FUNCTION empresa_01.pmp_inicializarxfecha(integer, text)
  RETURNS void AS
$BODY$
------------------------------------------------------------------
--- función para inicializar la tabla pmp_xfecha en el ejercicio actual
------------------------------------------------------------------
declare
  p_ejercicio alias for $1;
  p_meses alias for $2;
  r record;
begin   
        if not p_ejercicio between 2000 and 2100 then
          raise exception 'Ejercicio incorrecto. Se cancela el proceso';
        end if;
        if p_meses='OK' then  --si los meses que se le pasan contiene el texto 'OK' SIGNIFICA QUE ESTÁ TODO BIEN=>no inicializamos
           return;
        end if;

        if length(coalesce(p_meses,''))=0 then
	   delete from pmp_xfecha where date_part('year',ffinpmp)=p_ejercicio;  -- eliminamos todo lo que sea calculado para el ejercicio actual
	   
	   --Calculamos el pmp de todos los artículos de todas las delegaciones
	   for r in 
		select m, (('01-'||m+1||'-'||(p_ejercicio-1))::date + ' 1 month'::interval)::date as fini,(('01-'||m+1||'-'||p_ejercicio)::date + '1 month'::interval - '1 day'::interval)::date as ffin
		from  generate_series(0,11) as m loop
		-- fechainicial:=(('01-'||m+1||'-'||(p_ejercicio-1))::date + ' 1 month'::interval)::date -- día primero del mes siguiente al que se trata del ejercicio anterior
		-- fechafinal:=(('01-'||m+1||'-'||p_ejercicio)::date + '1 month'::interval - '1 day'::interval)::date  --último día del mes del ejercicio actual


	   	insert into pmp_xfecha (codarticulo,coddelegacion,pmp,finipmp,ffinpmp,stkfinpmp)
		select codarticulo,coddelega, pmpdevuelvexfecha(coddelega,codarticulo,r.fini,r.ffin),r.fini,r.ffin, 
			stocks.stkreal-(select coalesce(sum (cantidad),0) from stocksmov 
					where coddelegacion=stocks.coddelega and codarticulo=stocks.codarticulo and fechadoc>r.ffin)
		from stocks;
	   end loop;
	else
	   --En este caso, es la misma consulta que arriba, solo que nos ceñimos a las fechas de finalización que vienen por parámetros

	    delete from pmp_xfecha where ffinpmp in (
		SELECT  split_part(comas,'|'::text,2)::date AS f
		FROM (
			SELECT regexp_split_to_table(p_meses, E'\\, +' ) AS comas  --se busca en la parte derecha del texto codificado (split_part(...
		     ) T
		);

	    for r in 	
		select m,(('01-'||m+1||'-'||(p_ejercicio-1))::date + ' 1 month'::interval)::date as fini, (('01-'||m+1||'-'||p_ejercicio)::date + '1 month'::interval - '1 day'::interval)::date as ffin
		from	(SELECT  split_part(comas,'|'::text,3)::integer AS m
			 FROM (
				SELECT regexp_split_to_table(p_meses, E'\\, +' ) AS comas  
			     ) T
			 ) t loop
		
			insert into pmp_xfecha (codarticulo,coddelegacion,pmp,finipmp,ffinpmp,stkfinpmp)
			-- fechainicial:=(('01-'||m+1||'-'||(p_ejercicio-1))::date + ' 1 month'::interval)::date -- día primero del mes siguiente al que se trata del ejercicio anterior
			-- fechafinal:=(('01-'||m+1||'-'||p_ejercicio)::date + '1 month'::interval - '1 day'::interval)::date  --último día del mes del ejercicio actual
			select codarticulo,coddelega, pmpdevuelvexfecha(coddelega,codarticulo,r.fini,r.ffin),
			r.fini,	r.ffin,
			stocks.stkreal-(select coalesce(sum (cantidad),0) from stocksmov 
					where coddelegacion=stocks.coddelega and codarticulo=stocks.codarticulo 
					and fechadoc>r.ffin
					)
			from stocks;
			
	     end loop;
	end if;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

  CREATE OR REPLACE FUNCTION empresa_01.pmpdevuelvexfecha(character, character, date)
  RETURNS real AS
$BODY$
	--- Se da el precio medio ponderado calculado en la tabla pmp_xfecha
	--- para una fecha dada. Cuando no hay calculo para una fecha concreta
	--- se toma el de la fecha anterior a esa mas cercana.
DECLARE
	p_delegacion ALIAS FOR $1;
	p_articulo ALIAS FOR $2;
	p_fecha ALIAS FOR $3;
	r record;
	artBase text;	
	i integer;
BEGIN 
	select * into r
	from pmp_xfecha where codarticulo = p_articulo and coddelegacion = p_delegacion
	and ffinpmp <= p_fecha order by ffinpmp desc limit 1;
	if not found or (char_length(p_articulo) > 5 and r.pmp = 0) then 
		-- si no se ha encontrado nada para ese articulo, miramos, por si
		-- acaso hubiera que buscar en un articulo de compra.
		i:=0;
		artBase:='';
		for r in SELECT dev FROM regexp_split_to_table(p_articulo, '-') AS dev loop
			i:=i+1;
			if i<3 then
				artBase:=artBase||r.dev||case when i=1 then '-' else '' end;
			end if;
		end loop;
		select * into r
		from pmp_xfecha where codarticulo = artBase and coddelegacion = p_delegacion
		and ffinpmp <= p_fecha order by ffinpmp desc limit 1;
	end if;	
	return coalesce(r.pmp, 0);
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


  CREATE OR REPLACE FUNCTION empresa_01.preciomedio_actualiza(boolean, character, integer)
  RETURNS void AS
$BODY$
-- Inicializa la tabla de preciosmedios con los valores. 
declare
        p_inicializar alias for $1;
	p_serie alias for $2;  --si se pasa un valor de longitud>0 y p_inicializar=false, solo se aplican los cambios sobre los articulos de la delegación p_coddelegacion
	p_num alias for $3;
	p_listaarticulos text;  
	p_rstring text; -- concatenado de los registros de una consulta	r record;
	p_numarticulos integer;
	p_seriemov character(20);
	p_nummov integer;
	r record;
	cEmp text;
	p_ts timestamp;
	p_coddelegacion character(10);
	p_ids text;
	p_desencadenado character(25);
	--filtro boolean;
BEGIN
--return;

     if p_inicializar then
		insert into preciosmedios (coddelegacion,codarticulo, newPMcompra, newstk,mainPM) 

		SELECT CODDELEGACION,CODARTICULO,split_part(pm,'|',1)::numeric,split_part(pm,'|',2)::numeric,split_part(pm,'|',1)::numeric
		from (
			select t.coddelegacion,t.codarticulo,preciomedio_compra(t.coddelegacion,t.codarticulo, true) as pm
			FROM (
				SELECT CODDELEGA AS CODDELEGACION,CODARTICULO
				FROM STOCKS
				EXCEPT 
				SELECT DISTINCT CODDELEGACION,CODARTICULO
				FROM PRECIOSMEDIOS
			     ) T 
			INNER JOIN STOCKS ON T.CODDELEGACION=STOCKS.CODDELEGA AND T.CODARTICULO=STOCKS.CODARTICULO
		) t;
		return;
     end if;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


CREATE OR REPLACE FUNCTION empresa_01.proveedores_edad(character)
  RETURNS integer AS
$BODY$
declare
	------------------------------------------------------------------
	----- Funcion para calcular la edad de un proveedor --------------
	------------------------------------------------------------------
	
	-- Codigo del proveedor al que se va a calcular la edad
	p_codProveedor alias for $1;
	nEdad integer;
	
begin
	select extract(year from age(date'today', 
		(select fechanacimiento from proveedores where codproveedor = p_codProveedor))) into nEdad;
	if nEdad is null then
		return 0;
	end if;
	return nEdad;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

CREATE OR REPLACE FUNCTION empresa_01.sumaintervalofecha(integer, text)
  RETURNS text AS
$BODY$
--el tercer parámetro tiene que ser:'AÑOS', 'MESES','DIAS'
    SELECT CASE WHEN $2 = 'AÑOS' THEN   $1::TEXT || ' YEAR'
            WHEN $2 = 'MESES' THEN    $1::TEXT  || ' MONTH'
            ELSE  $1::TEXT  || ' DAY'
            END; 
$BODY$
  LANGUAGE sql VOLATILE
  COST 100;


CREATE OR REPLACE FUNCTION empresa_01.vehiculosinicializarev()
  RETURNS void AS
$BODY$
declare
R  RECORD;
R2 RECORD;
c_selectfecha text;
cSQL text;
c_fecha date;
begin
for r in select  coacrcab.idperiodicidad,coacrcab.matricula,coacrcab.fechafacturado,coacrcab.seriedocumento,coacrcab.numdocumento,case when told.idperiodicidad is not null then max(told.horasuso) else 0 end AS HORASUSOANT,
	coacrcab.horasuso AS HORASUSOACTUAL,vehiculosperiodicidad.horasuso AS HORASUSOPERIODICIDAD,vehiculosperiodicidad.concepto
	from coacrcab inner join vehiculosperiodicidad on coacrcab.idperiodicidad=vehiculosperiodicidad.idperiodicidad
	left join (coacrcab told  inner join vehiculosperiodicidad toldvp on told.idperiodicidad=toldvp.idperiodicidad) on coacrcab.matricula=told.matricula and vehiculosperiodicidad.concepto=toldvp.concepto and
	vehiculosperiodicidad.codtipo=toldvp.codtipo and coacrcab.fechafacturado>told.fechafacturado 
--where vehiculosperiodicidad.horasuso>0 and coacrcab.horasuso>0 
	group by coacrcab.idperiodicidad,coacrcab.seriedocumento,coacrcab.numdocumento,coacrcab.horasuso,vehiculosperiodicidad.horasuso, coacrcab.fechafacturado, told.idperiodicidad,coacrcab.matricula,vehiculosperiodicidad.concepto
	order by matricula   loop
   
    c_selectfecha:='case when char_length(campobase)=0 then vehiculosperiodicidad.fechabase when campobase=''fechamatric'' then vehiculos.fechamatric when campobase=''fechainitransporte'' then vehiculos.fechainitransporte   when campobase=''fechainiseguro'' then vehiculos.fechamatric end ';
    c_selectfecha:=' case when '|| c_selectfecha ||' is null then r.fechafacturado else '|| c_selectfecha ||' end '; --si la fecha devuelta es  nula (fecha de matriculación,fecha del seguro o lo que sea=>devolvemos la fecha de la factura como fecha base
    c_selectfecha:=' case when char_length(campobase)=0 then vehiculosperiodicidad.fechabase when campobase=''fechamatric'' then vehiculos.fechamatric when campobase=''fechainitransporte'' then vehiculos.fechainitransporte   when campobase=''fechainiseguro'' then vehiculos.fechamatric end ';
    c_selectfecha:=' case when ' || c_selectfecha || ' is null then '''|| r.fechafacturado ||'''::date else '||  c_selectfecha ||' end '; --si la fecha devuelta es  nula (fecha de matriculación,fecha del seguro o lo que sea=>devolvemos la fecha de la factura como fecha base

    cSQL:='select max(proxrevision) as proxrev from '; 
    cSQL:=cSQL||'(select case when '|| c_selectfecha  ||' + sumaintervalofecha(limitecantidad,limitemedida)::interval='|| c_selectfecha || ' ';
    cSQL:=cSQL||' then ''' || r.fechafacturado || '''::date + sumaintervalofecha(cantidadmedida,tipomedida)::interval '; 
    cSQL:=cSQL||'when ' || c_selectfecha  ||' + sumaintervalofecha(limitecantidad,limitemedida)::interval>'''|| r.fechafacturado ||'''::date + sumaintervalofecha(cantidadmedida,tipomedida)::interval ';
    cSQL:=cSQL||' or vehiculosperiodicidad.reglaunica then ';
    cSQL:=cSQL||'''' || r.fechafacturado || '''::date + sumaintervalofecha(cantidadmedida,tipomedida)::interval else ''1900-01-01'' end ';
    cSQL:=cSQL||' as proxrevision, vehiculosPeriodicidad.idperiodicidad ';
    cSQL:=cSQL||'from vehiculos inner join vehiculosPeriodicidad on vehiculos.tipovehiculo=vehiculosPeriodicidad.codtipo left join vehiculosrevisiones on ';
    cSQL:=cSQL||'vehiculos.matricula=vehiculosrevisiones.matricula and vehiculosPeriodicidad.idperiodicidad=vehiculosrevisiones.idperiodicidad ';
    cSQL:=cSQL||'where vehiculos.matricula='''|| r.matricula ||''' and concepto='''||r.concepto ||''' and not (vehiculosPeriodicidad.limitecantidad<>0 and vehiculosrevisiones.ultimarevision is not null and ';
    cSQL:=cSQL||'vehiculosPeriodicidad.horasuso=0 and '; --Las revisiones periodicas por horas de uso o kilometraje quedan excluidas
    cSQL:=cSQL||'vehiculosrevisiones.ultimarevision> ' ||  c_selectfecha  || ' + sumaintervalofecha(limitecantidad,limitemedida)::interval)) as t ';
    

   execute cSQL into r2;
   if found then
        insert into vehiculosrevisiones (IDPERIODICIDAD,MATRICULA,ULTIMAREVISION,PROXREVISION,SERIEREVISION,DOCREVISION) values
        (r.idperiodicidad,r.matricula,r.fechafacturado,r2.proxrev,r.seriedocumento,r.numdocumento);
 --  else
 --    if r.horasusoactual<>0 then
--        insert into vehiculosrevisiones (IDPERIODICIDAD,MATRICULA,ULTIMAREVISION,PROXREVISION,SERIEREVISION,DOCREVISION,kmactualrev,kmreglaperiodicidad) values
--             (r.idperiodicidad,r.matricula,r.fechafacturado,null,r.seriedocumento,r.numdocumento,r.HORASUSOACTUAL,r.HORASUSOPERIODICIDAD);
--     end if;
   end if;  
  
end loop;

END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;




  CREATE OR REPLACE FUNCTION adjuntos_acceso(integer, text, text, boolean)
  RETURNS boolean AS
$BODY$
-- Devuelve la descripción de un permiso sobre los adjuntos (0->todas las Gestiones,1->Descarga, 2->Cambiar observaciones,3->cambiar permisos, 4--> Eliminar
declare
p_id ALIAS FOR $1;
p_idop ALIAS FOR $2;
p_iduser ALIAS FOR $3;
p_lookonlyuser_perfil alias for $4; --si p_lookonlyuser_perfil=true =>Si no se tiene permiso de usuario (aunque haya un perfil que se le otorgue) devuelve false. 
                                    --Igualmente se usa para el todos. Si está a true, entonces el todos aplica solo para el todos. Por ejemplo, en la cadena p_textocodificado 
                                    --está ARI|0 solo devolverá true cuando esté el perfil 0 y el empleado sea de arinaga (devolverá false aunque se le pase P_IDUSER=ARI|1). 
                                    --Si está a false, entonces si p_iduser=ARI|1 devolverá true (
p_textocodificado text; --será una string codificada de la siguiente manera: 'ARI$4/1.2.3.4,LPA$5/0.1.2|141/2.3.4,98/4'. La parte izquierda de | representa parejas deleg $ idperfil 
			--con sus permisos asociados (el 0 al 4), y la parte derecha usuarios con sus permisos asociados (del 0 al 4)
p_subtexto text;
cSql text;
p_idowner integer;
begin
  select codifica_autorizacion,coalesce(idowner,-1000) into p_textocodificado,p_idowner 
  from public.adjuntosdocs where id=p_id; --buscamos la codificación de permisos para un adjunto en concreto
  if not found then
     return false;
  end if;
   
  
   if (position('$' in p_iduser)=0) then --NO se está preguntando por una pareja delegación idperfil,sino por un usuario
	if (p_idowner) in (-1000,p_iduser::integer) then --es el propietario quien nos llama
	  return true;
	end if;
        p_subtexto:=split_part(p_textocodificado, '|',2);
	perform indice
	from (
		select indice, regexp_split_to_table(permisos, E'\\.+' ) AS permiso
		FROM (
			SELECT  SPLIT_PART(COMAS,'/'::TEXT,1) AS INDICE, regexp_split_to_table(comas, E'\\/+' ) AS permisos
			FROM (
			      SELECT regexp_split_to_table(p_subtexto, E'\\,+' ) AS comas) comas  --se busca en la parte derecha del texto codificado (split_part(...
			) T
		where indice<>permisos 
	     ) t
	where (not p_lookonlyuser_perfil and t.indice in ('0')  and permiso='0') or  
	      (not p_lookonlyuser_perfil and t.indice in ('0') and permiso=p_idop) or 
	      (not p_lookonlyuser_perfil and p_iduser = p_idop and permiso='0') OR 
	      (t.indice=p_iduser and permiso=p_idop);
	      
	if found then --si lo encuentra=>el empleado está autorizado. Si no=> vemos se los perfiles lo autorizan
	  return true;
	end if;
	if p_lookonlyuser_perfil then --si estamos buscando sólo usuarios, retornamos.
	   return false;
	end if;
	--No se encontró el usuario en el texto codificado de derechos de acceso al adjunto. Buscamos a ver si tiene permiso por alguno de los perfiles de usuario
	p_subtexto:=split_part(p_textocodificado, '|',1);
	
	perform empleados.id
	from
		public.grupos grupos 
		inner join public.usrgrupos usrgrupos on grupos.codgrupo=usrgrupos.codgrupo 
		inner join public.usuarios usuarios on usrgrupos.codusuario=usuarios.codusuario
		inner join public.empleados empleados on usuarios.cnldap=empleados.cnldap 
		inner join public.mdelegaciones mdelegaciones on empleados.coddelegacion=mdelegaciones.coddelegacion,(
			SELECT indice, split_part(INDICE,'$',1) as deleg,split_part(INDICE,'$',2) as perfil, regexp_split_to_table(PERMISOS, E'\\.+' ) AS PERMISO
			FROM (
			SELECT  SPLIT_PART(COMAS,'/'::TEXT,1) AS INDICE, regexp_split_to_table(COMAS, E'\\/+' ) AS PERMISOS
			FROM (SELECT regexp_split_to_table(p_subtexto, E'\\,+' ) AS COMAS ) COMAS
			) T
			WHERE INDICE<>PERMISOS) t
	where empleados.id=p_iduser::integer and
	      char_length(empleados.cnldap)>0 and  --solo se admiten permisos de empleados activos en ldap (esa marca es el campo cnldap del empleado)
	      --todas las comprobaciones del permiso del adjunto con la delegación y perfil del usuario que se han de cumplir para darlo como 'CON PERMISO'
		((t.deleg='0' and t.perfil='0' and t.permiso='0') or  --hay autorizado todas las delegaciones,perfiles y permisos
			(t.deleg='0' and t.perfil='0' and t.permiso=p_idop) or --hay autorizado todas las delegaciones,perfiles así como la operación que se solicita  
			(t.deleg=empleados.coddelegacion and t.perfil='0' and t.permiso='0') or  --hay autorizado la delegación que se solicita y todos los perfiles y operaciones
			(t.deleg=empleados.coddelegacion and t.perfil='0' and t.permiso=p_idop) or  --hay autorizado la delegación que se solicita, todos los perfiles y la operación que se solicita
			--la combiniación deleg='0' y perfil<>0 (todas las delegaciones de  un perfil) está prohibida
			(t.indice=(empleados.coddelegacion||'$'||grupos.codgrupo) and t.permiso='0') or -- hay autorizado la delegación y perfile que se solicita y todas las operaciones
			(t.indice=(empleados.coddelegacion||'$'||grupos.codgrupo) and t.permiso=p_idop) 
		); --no hace falta comprobar p_lookonlyuser_perfil porque ya se sabe que es falso
	return found;
    end if;
  
  --si llegamos aquí es un par delegación$idperfil
    p_subtexto:=split_part(p_textocodificado, '|',1);
    perform t.deleg 
    from (
	SELECT indice, split_part(INDICE,'$',1) as deleg,split_part(INDICE,'$',2) as perfil, regexp_split_to_table(PERMISOS, E'\\.+' ) AS PERMISO
	FROM (
		SELECT  SPLIT_PART(COMAS,'/'::TEXT,1) AS INDICE, regexp_split_to_table(COMAS, E'\\/+' ) AS PERMISOS
		FROM (SELECT regexp_split_to_table(p_subtexto, E'\\,+' ) AS COMAS ) COMAS
	     ) T
	WHERE INDICE<>PERMISOS 
	) t
	where ((
	        (t.deleg='0' and t.perfil='0' and permiso='0') or  --Hay autorización para todos las delgeg, todos los perfiles y todas las operaciones
	        (t.deleg='0' and t.perfil='0' and permiso=p_idop) or  --Hay autorización para todas las deleg todos los perfiles y la operación que se pide
	        (t.deleg=split_part(p_iduser,'$',1) and t.perfil='0' and permiso=p_idop) or  -- hay autorización para la delegación que se pide, todos los perfiles y la operación que se pide
	        (t.deleg=split_part(p_iduser,'$',1) and t.perfil='0' and permiso='0' ) or  -- hay autorización para la delegación que se pide, todos los perfiles y todos los permisos
	        (t.indice=p_iduser and t.permiso='0'))   -- hay autorización para la delegación y permiso que se pide, y para todas las operaciones
	       and not p_lookonlyuser_perfil) or --para que se pueda usar el 0 en la evaluación de permisos, es necesario que la variable p_lookonlyuser_perfil sea false. Si no, solo devolverá true si la deleg, perfil y permiso coinciden
		(t.indice=p_iduser and t.permiso=p_idop);  --hay autorización para la delegación , permiso y operación que se pide
     return found;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION adjuntos_acceso(integer, text, text, boolean)
  OWNER TO dovalo;

CREATE OR REPLACE FUNCTION adjuntos_describepermiso(integer)
  RETURNS text AS
$BODY$
-- Devuelve la descripción de un permiso sobre los adjuntos (0->todas las Gestiones,1->Descarga, 2->Cambiar observaciones,3->cambiar permisos, 4--> Eliminar
declare
id ALIAS FOR $1;
texto text;

begin
   
   texto:=       case when id=0 then 'Todas las Acciones'
                      when id=1 then 'Descarga del Adjunto'
                      when id=2 then 'Cambiar observaciones al Adjunto'
                      when id=3 then 'Cambiar permisos al Adjunto'
                      when id=4 then 'Eliminar el Adjunto' end;
                
   return texto;
    
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

CREATE OR REPLACE FUNCTION adjuntos_posibleguardar(integer, text, text, integer)
  RETURNS text AS
$BODY$
declare
--esta función evalúa si se puede modificar un documento conforme a alguna condición 
--establecida sobre sus adjuntos. devuelve true si se puede guardar. Falso en caso contrario
--Si todas las empresas están por esquemas (no usaríamos dblink),esta función se podría 
--llamar desde after_update de la tabla en cuestión, y si devuelve<>'OK' CANCELAR 
--LA TRANSACCIÓN. Si no, sí se permite.
--la llamada desde after_update a esta función, puede hacer que esta función vea 
--los nuevos cambios aún sin completarse, con lo que tendríamos una función 
--autónma, no dependiente del código.
  p_idtipo ALIAS FOR $1;
  p_codempresa ALIAS FOR $2;
  p_seriedocumento ALIAS FOR $3;
  p_numdocumento ALIAS FOR $4;
  p_obligaadjuntar boolean;
  p_nomtabla character(30);
  p_condicionempresa text;
  p_condicionacceso text;
  p_tipoadjunto text;
  p_msg text;
  -- r record;
  r_seriedocumento varchar(30);
  r_numdocumento integer;
  r_cumplecondicion boolean;
  cSql text;
 begin
     select nomtabla, adjuntostipos.obligaadjuntar, condicionadjuntoacceso, condicionadjuntoempresa, tipo 
     into p_nomtabla, p_obligaadjuntar, p_condicionacceso, p_condicionempresa, p_tipoadjunto
     from public.adjuntostipos adjuntostipos 
     where adjuntostipos.id=p_idtipo;
     if found then
       if not p_obligaadjuntar then
         return 'OK';
       end if;
       p_msg:='';
       cSql :='select ''se puede guardar''  ';
       cSql :=cSql||'from public.adjuntosdocs adjuntosdocs inner join public.adjuntostipos adjuntostipos ';
       cSql :=cSql||'on adjuntosdocs.idtipo=adjuntostipos.id ';
       cSql :=cSql||'where adjuntostipos.id='||p_idtipo||' ';
       cSql :=cSql||'and adjuntosdocs.codempresa='''||trim(p_codempresa)||''' and adjuntosdocs.seriedocumento='''||p_seriedocumento||''' and ';
       cSql :=cSql||'adjuntosdocs.numdocumento='||p_numdocumento::text||' and '|| p_condicionacceso;
       
       Execute cSql into p_msg;
       if char_length(p_msg)<>0 then
         return 'OK'; --SE CUMPLE LA CONDICIÓN SOBRE ADJUNTOS. se puede guardar
       end if;
     else
       return 'OK'; --SI NO SE encuentra el tipo de adjunto, no hay nada que nos impida guardar el documento
     end if; 
     --Si no se encontró entonces es que hay definida en los adjuntos alguna condición  
     -- que impiden guardar el documento. Miramos entonces a ver si se cumplen
     -- ahora las condiciones de aplicación definidas sobre el documento de llamada, 
     -- a ver si el documento cumple alguna excepción a esta regla 
     EXECUTE 'SELECT seriedocumento,numdocumento, '||p_condicionempresa::text ||' FROM '
		|| p_codempresa || '.' ||p_nomtabla||' where seriedocumento='''||p_seriedocumento
		|| '''	and numdocumento=' || p_numdocumento
		INTO r_seriedocumento, r_numdocumento, r_cumplecondicion;

      --Texto genérico a poner:
      --return 'Se encontraron condiciones definidas sobre los adjuntos de esta/e '
      --||p_tipoadjunto||' que impiden guardarla/o';
      --por ahora en las facturas de gasto el mensaje más claro a poner es:
      if p_idtipo<>400 then --no es una factura de venta
	p_msg:='Todas las facturas de GASTO/COMPRA con fecha de registro posteriores al 2013 deben tener escaneado como adjunto el original del documento para poder guardar facturas con importes distintos de 0';
      else
        p_msg:='Todas las facturas de Venta, a partir del 15/11/2014 que tengan líneas de detalle y no sean proforma ni rectificativas, han de llevar como adjuntos la relación de albaranes facturados';
      end if;
      --if not found then 
      if (r_seriedocumento is null) then
		--la factura es nueva=>se deniega el guardado hasta que complete las condiciones sobre adjunto
        return p_msg;
      else -- se encontró en el documento a guardar una condición que lo liga con el control de adjuntos=>no deja guardar
         if r_cumplecondicion then --se impide guardar, ya que se cumple la condición de adjuntos para impedir guardar el documento
            return p_msg;
         else 
	    return 'OK';
         end if;
      end if;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


CREATE OR REPLACE FUNCTION coalblin_casos_fraude(timestamp without time zone, timestamp without time zone, timestamp without time zone, timestamp without time zone, text, text, integer, integer, integer, integer, text, integer)
  RETURNS text AS
$BODY$
DECLARE
p_tsmin alias for $1;
p_tsmax alias for $2;
p_tsregistro alias for $3;
p_tsregistronxt alias for $4;
p_codarticulo alias for $5;
p_codarticulonxt alias for $6;
p_cantidad alias for $7;
p_cantidadnxt alias for $8;
p_numdocumento alias for $9;
p_numdocumentonxt alias for $10;
p_fechas alias for $11;
p_op alias for $12;
p_tipo1 boolean;
p_tipo2 boolean; 
p_tipo3 boolean;
p_tmedio integer; -- tiempo medio
p_ret text;
--devuelve cod gnerico|codespecifico|texto fraude o cadena vacía si no hay indicio de fraude. codgenerico puede ser 0,1,2,100,o 200
-- p_op puede ser:
--    1 para que devuelva  solo lo que cumpla '2 pesadas consecutivas del mismo artículo y cantidad en albaranes distintos'
--    2 para que devuelva true solo lo que cumpla 'Albarán abierto '||to_char(ts_max-ts_min, 'HH24 \"horas\" MI \"minutos\"')
--    3 El tiempo medio entre pesadas es sospechoso
--    100 para que devuelva true si se da 1 o se da 2 o se da 3
--    200 para que devuelva true si se da 1 Y se da 2 Y se da 3
--    0 para no filtrar por casos de fraude
BEGIN
    if p_op=0 then
       return '0|1|No se comprueba si hay fraude';
    end if;
    p_tipo1:= p_tsregistronxt>p_tsregistro and p_numdocumento <> p_numdocumentonxt  and trim(p_codarticulo)=trim(p_codarticulonxt) and p_cantidad = p_cantidadnxt;
    if p_op=1 then 
          return case when p_tipo1 then '1|1|2 pesadas consecutivas del mismo artículo y cantidad en albaranes distintos' else '' end;
    end if;

    p_tipo2:=(extract(epoch FROM p_tsmax) - extract(epoch from p_tsmin)>30*60);

    if p_op=2 then 
       return case when p_tipo2 then '2|2|Albarán '||p_numdocumento||' abierto '||to_char(p_tsmax-p_tsmin, 'HH24 \"horas\" MI \"minutos\"') else '' end;
    end if;
   
   p_tipo3:=false;
   
   if char_length(p_fechas)>0 and split_part(p_fechas,', ',2)<>'' then --hay más de una línea
    select (sum(case when t2 is null then 0 else coalesce(date_part('epoch', t.t2),0) - coalesce(date_part('epoch', t.t1),0) end)/(max(t.cuenta)-1))::integer into p_tmedio
     from (
	select txt as t1,lead(txt) over (order by txt) as t2, count(*) over () as cuenta from(
		SELECT regexp_split_to_table(p_fechas, ', ')::timestamp as txt 
		order by txt
	)  t 
     ) t;

     p_tipo3:=p_tmedio>5*60; --tendrá true si el tiempo medio entre líneas es mayor a 5 minutos
   end if;

   if p_op=3 then
      return case when p_tipo3 then '3|3|El tiempo medio entre pesadas es sospechoso' else '' end;
   end if;
        
    if p_tipo1 and p_tipo2 and p_tipo3 then
          --Da igual el tipo de operación que se haya mandado sacar. Se retorna un true, con el texto que conviene
          return '200|1|2 pesadas consecutivas del mismo artículo y cantidad en albaranes distintos Y albarán '||p_numdocumento||' abierto '||to_char(p_tsmax-p_tsmin, 'HH24 \"horas\" MI \"minutos\"')||' Y El tiempo medio entre pesadas es sospechoso';
    else
       if p_op=200 then --se ha mandado filtrar con un AND en  todas las condiciones, y no se ha cumplido=>retornamos el equivalente a false
          return '';
       end if;
    end if;

    p_ret:='';
    --El 100 se usa para obtener todas las descripciones de los textos fraudulentos. Si no es fraudulento, se devuelve un texto que lo indica (no se devuelve vacío en ningún caso)
    if p_op=100 or p_op=110 then --se cumple alguna de las condiciones, y no se cumple el AND entre las 3, YA QUE LO HEMOS COMPROBADO ANTERIORMENTE
       if p_tipo1 then
             p_ret :='100|1|2 pesadas consecutivas del mismo artículo y cantidad en albaranes distintos';
       end if;
       p_ret:=p_ret||case when char_length(p_ret)>0 and p_tipo2 then ' Y '  when p_tipo2 then '100|2|' else '' end;
       if p_tipo2 then
            p_ret:=p_ret || 'Albarán '||p_numdocumento||' abierto '||to_char(p_tsmax-p_tsmin, 'HH24 \"horas\" MI \"minutos\"');
       end if;
       p_ret:=p_ret||case when char_length(p_ret)>0 and p_tipo3 then ' Y ' when p_tipo3 then '100|3|' else '' end;
       if p_tipo3 then
          p_ret:=p_ret || 'El tiempo medio entre pesadas es sospechoso';
       end if;
       
       return case when length(p_ret)>0 and p_op=110 then p_ret else '100|2|No se detecta fraude' end;
    end if;
    return ''; -- si llega aquí devolvemos que no hay error
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION coalblin_casos_fraude(timestamp without time zone, timestamp without time zone, timestamp without time zone, timestamp without time zone, text, text, integer, integer, integer, integer, text, integer)
  OWNER TO dovalo;



CREATE OR REPLACE FUNCTION dircallevalida(integer, text)
  RETURNS text AS
$BODY$
------------------------------------------------------------------
-- Devuelve un texto distinto de '' en caso de que el id pasado, 
-- y el texto no se corresponda con lo que hay en dircalles 
-- (id=idpasado, describe=texto pasado). Esta comrpbación no se hará, 
-- si el idpasado es 0.
-- en caso contrario, devuelve ''
------------------------------------------------------------------
declare
	p_idcalle alias for $1;
	p_calle alias for $2;
	p_calleBD text;
begin      
   if p_idcalle=0 then
      return ''; --si el id pasado es 0, lo damos por bueno (texto libre)
   end if;
   
   select describe into p_calleBD from public.dircalles where id=p_idcalle;

   if not found then
      return 'La calle '||p_calle||' No se encuentra registrada en el ' ||
		'sistema (idcalle='||p_idcalle||'). Seleccione una que sí lo esté';
   else 
     if not (p_calle like '%'||trim(p_calleBD)||'%')  then 
		-- El nombre de la calle de la BD ha de estar contenido en la dirección que se 
		-- trata de poner. Si no =>devolvemos un texto informándolo
		return 'El nombre de la calle que trata de guardar: '||p_calle||' NO CONTIENE ' ||
			'el nombre de la calle a la que está vinculada en el ' ||
			'sistema: '||p_calleBD||' (idcalle='||p_idcalle||')';
     end if;     
   end if;
   return '';
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION dircallevalida(integer, text)
  OWNER TO dovalo;


CREATE OR REPLACE FUNCTION dirlocalidadvalida(integer, text)
  RETURNS text AS
$BODY$
------------------------------------------------------------------
-- Devuelve un texto distinto de '' en caso de que el 
-- id pasado, y el texto no se corresponda con lo
-- que hay en dirlocalidad (id=idpasado, describe=texto pasado)
-- en caso contrario, devuelve ''
------------------------------------------------------------------
declare
	p_idlocalidad alias for $1;
	p_localidad text;
	p_localidadBD text;
begin
   select describe into p_localidadBD from public.dirlocalidades where id=p_idlocalidad;
   if not found then
      return 'La localidad '||p_localidad||' No se encuentra registrada en el ' ||
		'sistema (idlocalidad='||p_idlocalidad||'). Seleccione una que sí lo esté';
   else 
     if trim(p_localidadBD)<>p_localidad then
       return 'El nombre de la localidad que trata de guardar: '||p_localidad||' no ' ||
		'coincide con el nombre de la localidad a la que se refiere en el ' ||
		'sistema: '||p_localidadBD||' (idlocalidad='||p_idlocalidad||')';
     end if;
   end if;
   return '';
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION dirlocalidadvalida(integer, text)
  OWNER TO dovalo;



CREATE OR REPLACE FUNCTION em_albaran_contenedores(IN text, OUT facserie character, OUT facdocumento integer, OUT seriedocumento character, OUT numdocumento integer, OUT contenedor character, OUT fechadoc date, OUT observaciones character varying, OUT coddelegacion character, OUT codcaja character, OUT descripcion character varying, OUT precinto character, OUT codnaviera character, OUT nomnaviera character, OUT pesoneto numeric, OUT doccerrado boolean, OUT codclienteexp character, OUT codalmdestino character, OUT origen character, OUT destino character, OUT fechaentrada date, OUT fechasalida date, OUT codempresa character, OUT codempresadestino character, OUT codtipocontenedor character, OUT pedidos text, OUT est_entrada_origen boolean, OUT est_entrada_destino boolean, OUT est_llenando boolean, OUT est_lleno boolean, OUT est_pdte_validar boolean, OUT est_validado boolean, OUT est_pdte_facturar boolean, OUT est_facturado boolean, OUT est_en_transito boolean, OUT est_recibido boolean, OUT est_vaciando boolean, OUT est_vacio boolean, OUT est_stk_diferencia boolean, OUT est_stk_aceptado boolean, OUT est_stk_rechazado boolean, OUT es_exportacion boolean)
  RETURNS SETOF record AS
$BODY$
declare 
     p_where alias for $1;
     p_sql text;     
begin
	p_sql:='SELECT DISTINCT em_exfaclin.facserie, em_exfaclin.facdocumento, em_exalbcab.seriedocumento, em_exalbcab.numdocumento, em_exalbcab.contenedor, em_exalbcab.fechadoc, em_exalbcab.observaciones, em_exalbcab.coddelegacion, em_exalbcab.codcaja, em_exalbcab.descripcion, em_exalbcab.precinto, em_exalbcab.codnaviera, em_exalbcab.nomnaviera, em_exalbcab.pesoneto, em_exalbcab.doccerrado, em_exalbcab.codclienteexp, em_exalbcab.codalmdestino, em_exalbcab.origen, em_exalbcab.destino, em_exalbcab.fechaentrada, em_exalbcab.fechasalida, em_exalbcab.codempresa, em_exalbcab.codempresadestino, em_exalbcab.codtipocontenedor ';
	p_sql:=p_sql||' , concatenate(em_exalblin.idpedido::text) OVER (PARTITION BY em_exalblin.codempresa, em_exalblin.seriedocumento, em_exalblin.numdocumento) AS pedidos, ';
	p_sql:=p_sql||'CASE WHEN e.ts_entrada_origen IS NOT NULL THEN true ELSE false END AS est_entrada_origen, ';
	p_sql:=p_sql||'CASE WHEN e.ts_entrada_destino IS NOT NULL THEN true ELSE false END AS est_entrada_destino, e.est_llenando, ';
	p_sql:=p_sql||'CASE WHEN e.ts_lleno IS NOT NULL THEN true ELSE false END AS est_lleno, e.est_pdte_validar, ';
	p_sql:=p_sql||'CASE WHEN e.ts_validado IS NOT NULL THEN true ELSE false END AS est_validado, ';
	p_sql:=p_sql||'CASE WHEN em_exfaclin.facdocumento IS NOT NULL THEN false ELSE true END AS est_pdte_facturar, ';
	p_sql:=p_sql||'CASE WHEN em_exfaclin.facdocumento IS NOT NULL THEN true ELSE false END AS est_facturado, e.est_en_transito, ';
	p_sql:=p_sql||'CASE WHEN e.ts_recibido IS NOT NULL THEN true ELSE false END AS est_recibido, e.est_vaciando, ';
	p_sql:=p_sql||'CASE WHEN e.ts_vacio IS NOT NULL THEN true ELSE false END AS est_vacio, ';
	p_sql:=p_sql||' e.est_stk_diferencia, e.est_stk_aceptado, e.est_stk_rechazado, e.es_exportacion ';
	p_sql:=p_sql||'FROM (public.em_exalbcab em_exalbcab ';
	p_sql:=p_sql||'LEFT JOIN public.em_exalblin em_exalblin ON em_exalbcab.codempresa = em_exalblin.codempresa AND em_exalbcab.seriedocumento = em_exalblin.seriedocumento AND em_exalbcab.numdocumento = em_exalblin.numdocumento and em_exalblin.idpedido is not null )';
	p_sql:=p_sql||'LEFT JOIN public.em_exfaclin em_exfaclin ON em_exalblin.codempresa = em_exfaclin.codempresa and em_exalblin.seriedocumento = em_exfaclin.albserie AND em_exalblin.numdocumento = em_exfaclin.albdocumento and em_exalblin.codarticulo=em_exfaclin.codarticulo ';
	p_sql:=p_sql||'LEFT JOIN public.em_exalbestados e ON em_exalbcab.codempresa = e.codempresa AND em_exalbcab.seriedocumento = e.seriedocumento AND em_exalbcab.numdocumento = e.numdocumento ';
	p_sql:=p_sql||'where ' || p_where;

	RETURN QUERY execute p_sql;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;

  CREATE OR REPLACE FUNCTION em_exalbcab_docvinculados(IN integer, IN character, IN character, IN integer, OUT seriedoc character, OUT numdoc integer, OUT serielink character, OUT numlink integer)
  RETURNS SETOF record AS
$BODY$
	-- Retorna el conjunto de registros de la tabla docvinculos, que están vinculados al documento que se le pasa por parámetro. En otras palabras, 
	-- se busca por docs, los documentos links al que está asociado
declare 
	p_idtipo alias for $1;
	p_codempresa alias for $2;
	p_serie alias for $3;
	p_num alias for $4;
	p_sql text;     
begin
	p_sql:='SELECT seriedoc,numdoc,serielink,numlink from public.docvinculos where true ';
	if p_idtipo<>0 then
		p_sql:=p_sql||' and iddocvinculos_tipo='||p_idtipo||' ';
	end if;  
	if char_length(p_codempresa)>0 then
		p_sql:=p_sql||' and codempresadoc='''||p_codempresa||''' ';
	end if;
	if char_length(p_serie)>0 then
		p_sql:=p_sql||' and seriedoc='''||p_serie||''' ';
	end if;
	if p_num<>0 then
		p_sql:=p_sql||' and numdoc='||p_num||' ';
	end if;  
	RETURN QUERY execute p_sql;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;

  CREATE OR REPLACE FUNCTION em_exalbcab_docvinculados_rev(IN integer, IN character, IN character, IN integer, OUT seriedoc character, OUT numdoc integer, OUT serielink character, OUT numlink integer)
  RETURNS SETOF record AS
$BODY$
	-- Función inversa a em_exalbcab_docvinculados. Se busca por link, los documentos docs
declare 
	p_idtipo alias for $1;
	p_codempresa alias for $2;
	p_serie alias for $3;
	p_num alias for $4;
	p_sql text;     
begin  
	p_sql:='SELECT seriedoc,numdoc,serielink,numlink from public.docvinculos where true ';
	if p_idtipo<>0 then
		p_sql:=p_sql||' and iddocvinculos_tipo='||p_idtipo||' ';
	end if;  
	if char_length(p_codempresa)>0 then
		p_sql:=p_sql||' and codempresalink='''||p_codempresa||''' ';
	end if;
	if char_length(p_serie)>0 then
		p_sql:=p_sql||' and serielink='''||p_serie||''' ';
	end if;
	if p_num<>0 then
		p_sql:=p_sql||' and numlink='||p_num||' ';
	end if;
	RETURN QUERY execute p_sql;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;

CREATE OR REPLACE FUNCTION fecha_laboral_anterior(date, text)
  RETURNS text AS
$BODY$				
declare	
	--busca en la delegación el día laboral más reciente anterior a la fecha pasada por parámetro.
	--tiene en cuenta los días festivos y sábados y domingos que no cuentan
	p_fecha ALIAS FOR $1;	
	p_coddelegacion ALIAS FOR $2;
	p_ultlaboral date;	
begin
   select coalesce(max(p_fecha - t),current_date) into p_ultlaboral
   from generate_series(1,30) as t left join controlacceso.diasfestivos 
   on  (p_fecha - t)::date=diasfestivos.fecha AND coddelegacion=p_coddelegacion
   where extract('dow' from ((p_fecha-t)::date)) not in (0,6) and diasfestivos.fecha is null;
   return  p_ultlaboral;
   -- si en los ´ultimos 30 días no ha habido un día laboral, es porque están 
   -- todos puestos como festivos=>devolvemos el día de hoy
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


CREATE OR REPLACE FUNCTION fecha_modificacion_valida(date)
  RETURNS text AS
$BODY$
declare
	-- FUNCIÓN PARA COMPROBAR si la fecha pasada está en un intervalo 
	-- de fecha no modificable, ya que corresponde a otro intervalo de nómina
	p_fecha alias for $1;
	p_fechalimite date;
begin
  if p_fecha>=current_date then
    return 'OK';
  end if;
  if date_part('month',p_fecha)=date_part('month',current_date) and  
	date_part('year',p_fecha)=date_part('year',current_date) then
    return 'OK';
  else
    if (current_date - p_fecha)::integer <=31 then
      return 'OK';
    else
       if date_part('day',current_date)<=20 then 
		 --se permite modificar del 21 de hace 2 meses al mes anterior al 20 del mes actual
         p_fechalimite:=(21||'-'||date_part('month',current_date)-2||'-'||date_part('year',current_date - '2 month'::interval))::date; --solo 2 meses antes
       else
         p_fechalimite:=(21||'-'||date_part('month',current_date)-1||'-'||date_part('year',current_date - '1 month'::interval))::date; --solo un mes antes
       end if;
       if p_fecha<p_fechalimite then
          return 'La fecha ha de ser mayor o igual a '||to_char(p_fechalimite,'dd/mm/yyyy');
       else
          return 'OK';
       end if;
    end if;
  end if;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


CREATE OR REPLACE FUNCTION fichaje_control(integer, timestamp without time zone)
  RETURNS text AS
$BODY$	
declare	
	-- devuelve una cadena de texto indicando si el empleado está 
	-- autorizado a usar otros programas sin fichar, 
	-- o si su último fichaje es una entrada del mismo día y anterior a 
	-- la fecha pasada, devolverá OK|ultfechafichaje|id fichaje.
	-- Devolverá un texto con un mensaje de error en caso contrario
	p_idempleado ALIAS FOR $1;	
	p_f1 ALIAS FOR $2;	
	p_necesitafichar boolean;
	p_ultfichaje text;
	cServIp text;
begin	
	select split_part(inet_server_addr()::text,'/',1) into cServIp;
	if (cServIp = '192.168.110.215') then
		-- Maquina virtual de pruebas
		return 'OK|';
	end if;
	select necesitafichar into p_necesitafichar from empleados where empleados.id=p_idempleado;
	if found then
		if not p_necesitafichar then
			return 'OK';
		else
			p_ultfichaje:='';
			select max(tblregistro.fecharegistro||'|'||tblregistro.id||'|'||tblregistro.entrada) into p_ultfichaje 
			from controlacceso.tblregistro 
			where idempleado=p_idempleado and tblregistro.fecharegistro::date=current_date and tblregistro.fecharegistro<p_f1;
			if char_length(p_ultfichaje)>0 then --se encont´ro un fichaje hoy
				if split_part(p_ultfichaje,'|',3)='true' then --el último fichaje anterior a la fecha pasada es una entrada
					return 'OK|'||split_part(p_ultfichaje,'|',1)||'|'||split_part(p_ultfichaje,'|',2);
				else
					return 'NO existe registro de que el último fichaje de hoy haya sido una entrada, anterior a:'||to_char(p_f1,'dd-mm-yyyy hh24:mi:ss');
				end if;
			else
				return 'NO hay constancia de algún fichaje del empleado '||p_idempleado||' hoy día:'||to_char(current_date,'dd-mm-yyyy');  
			end if;
		end if;
	else
		return 'El empleado con identificador: '|| p_idempleado||' no se encuentra registrado en el sistema';
	end if;
  
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

CREATE OR REPLACE FUNCTION fichaje_control(integer)
  RETURNS text AS
$BODY$	
declare	
	-- devuelve una cadena de texto indicando si el empleado está 
	-- autorizado a usar otros programas sin fichar, 
	-- o si su último fichaje es una entrada del mismo día y anterior 
	-- a la fecha pasada, devolverá OK|ultfechafichaje|id fichaje.
	-- Devolverá un texto con un mensaje de error en caso contrario

	p_idempleado ALIAS FOR $1;	
	p_necesitafichar boolean;
	p_ultfichaje text;
	cServIp text;
begin	
	select split_part(inet_server_addr()::text,'/',1) into cServIp;
	if (cServIp = '192.168.110.215') then
		-- Maquina virtual de pruebas
		return 'OK|';
	end if;
	select necesitafichar into p_necesitafichar from empleados where empleados.id=p_idempleado;
	if found then
		if not p_necesitafichar then
			return 'OK';
		else
			p_ultfichaje:='';
			select max(tblregistro.fecharegistro||'|'||lpad(tblregistro.id::text,9,'0')||'|'||tblregistro.entrada) into p_ultfichaje 
			from controlacceso.tblregistro 
			where idempleado=p_idempleado and tblregistro.fecharegistro::date=current_date and tblregistro.fecharegistro<now();
			if char_length(p_ultfichaje)>0 then --se encont´ro un fichaje hoy
				if split_part(p_ultfichaje,'|',3)='true' then --el último fichaje anterior a la fecha pasada es una entrada
					return 'OK|'||split_part(p_ultfichaje,'|',1)||'|'||split_part(p_ultfichaje,'|',2);
				else
					return 'No es posible arrancar la aplicación sin haber fichado antes';
				end if;
			else
				return 'No es posible arrancar la aplicación sin haber fichado antes';  
			end if;
		end if;
	else
		return 'El empleado con identificador: '|| p_idempleado||' no se encuentra registrado en el sistema';
	end if;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


CREATE OR REPLACE FUNCTION gestion_pluses_calidad(date, date, numeric, integer)
  RETURNS numeric AS
$BODY$
declare
	--Se le pasan dos fechas, un importe de plus, y un identificador de 
	-- empleado, y la función devuelve el importe del plus que le corresponde 
	-- a dicho empleado. Dicho importe se calcula usando las siguientes proporciones:
	--(nº dias del mes/p_plus)=(nº dias no vacaciones/Y) donde 
	-- Y es el plus proporcional a los días de vacaciones
	--(Nº dias laborales (dias con idhorario>0 o idhorario<0 y el 
	-- texto <>'Vacaciones'))/Y = ((Horas trabajadas en horario)/(Horas del horario))/X  
	-- donde X es el plus a devolver por la función.
	p_f1 ALIAS FOR $1;
	p_f2 ALIAS FOR $2;
	p_plus alias for $3;
	p_idempleado ALIAS FOR $4;
	r record;
	p_dias integer;
	p_horas_en_turno numeric;
	p_dias_laborales numeric(18,2);
	p_vacaciones integer;
	p_laboralausente integer;
	p_Y numeric(18,2);
	p_X numeric(18,2);
begin
      p_dias=p_f2-p_f1 + 1; 
      -- Número de días del intervalo. Se le suma uno porque si las 
      -- dos fechas coinciden, debe de devolver 1.
      if p_dias<=0 then
         return 0; 
      end if;
      if p_idempleado in (154,168,123,42) then 
		-- Si es el empleado Marcos Perez,Pedro Gallego,Eduardo Mendez o Nauzet Marrero, 
		-- no se prorratea (se devuelve el plus integro)
         return p_plus;
      end if;
      p_vacaciones:=0; 
      p_laboralausente:=0;  
      p_dias_laborales:=0;
      --la siguiente consulta saca la cuenta de días de vacaciones, y otros días en teoría laborales pero marcados como no asistencia (dias con horario baja, enfermedad... que no sean fines de semana ni festivos)
      --así como los días marcados en horario como laborales (idhorario>0 y no festivo)
      select into p_vacaciones,p_laboralausente,p_dias_laborales 
		sum(case when horarios.texto='Vacaciones' then 1 else 0 end), 
		sum(case when horarios.texto not in ('Vacaciones','No Procede') and horarios.texto not like 'Permiso%' and horarios.text not like 'Curso/Formación%' and  extract('dow' from (qrycalendario.anio||'-'||qrycalendario.mes||'-'||qrycalendario.dia)::date) not in (0) and diasfestivos.fecha is null and horarios.id<0  then 1 else 0 end),
		sum(case when horarios.id>0  and extract('dow' from (qrycalendario.anio||'-'||qrycalendario.mes||'-'||qrycalendario.dia)::date) not in (0) and diasfestivos.fecha is null and not (horaini1='00:00:00' and horafin1='00:00:00') then 1 else 0 end)
      from 
		(controlacceso.qrycalendario qrycalendario  
		inner JOIN controlacceso.Horarios horarios ON qrycalendario.IdHorario = Horarios.Id 
		inner join public.empleados on qrycalendario.idempleado=empleados.id)  
      left join controlacceso.diasfestivos diasfestivos on diasfestivos.coddelegacion=empleados.coddelegacion and diasfestivos.fecha=(qrycalendario.anio||'-'||qrycalendario.mes||'-'||qrycalendario.dia)::date
      where qrycalendario.idempleado=p_idempleado and (qrycalendario.anio||'-'||qrycalendario.mes||'-'||qrycalendario.dia)::date between p_f1 and p_f2 and horarios.id<>0 and horarios.texto<>'No Procede';
      if not found then 
         p_vacaciones:=0;
         p_laboralausente:=0;
         p_dias_laborales:=0;
      end if;      
      if p_laboralausente>= 5 or p_dias_laborales= 0 then 
		--Si tienes 5 días o más de ausencia o no tiene ningún día 
		--laboral =>no te corresponde plus de productividad
		return 0;
      end if;
      p_Y:=(p_dias-p_vacaciones)*p_plus/p_dias; 
      --p_Y contiene ahora el plus prorrateado en función de los días de vacaciones.
	  --RAISE EXCEPTION 'P_Y: % ',p_Y; 
      p_horas_en_turno:=0;
      --p_horas_en_turno son las fracciones de jornadas trabajadas en el horario que le corresponde
      
      select sum(t.h) into p_horas_en_turno from (
      select
        case when max(coalesce(date_part('epoch'::text, horarios.horafin1),86400)-coalesce(date_part('epoch'::text, horarios.horaini1),0)+coalesce(date_part('epoch'::text, horarios.horafin2),0)-coalesce(date_part('epoch'::text, horarios.horaini2),0))!= 0 then  
        sum( 
        (case when tblregistro.ts_fechafin is not null and ((tblregistro.ts_fecha,tblregistro.ts_fechafin) overlaps (date_trunc('day', tblregistro.ts_fecha) + horarios.horaini1,date_trunc('day', tblregistro.ts_fecha) + horarios.horafin1)) then --comparten intervalo 
             GREATEST(0, LEAST(coalesce(date_part('epoch'::text, horarios.horafin1),86400), date_part('epoch'::text, tblregistro.ts_fechafin::TIME))) - 
             GREATEST(0, coalesce(date_part('epoch'::text, horarios.horaini1),0), date_part('epoch'::text, tblregistro.ts_fecha::TIME)) 
          else 0 end 
        + 
        case when (tblregistro.ts_fechafin is not null and (tblregistro.ts_fecha,tblregistro.ts_fechafin) overlaps (date_trunc('day', tblregistro.ts_fecha) + horarios.horaini2, date_trunc('day', tblregistro.ts_fecha) + horarios.horafin2)) then --comparten intervalo 
           GREATEST(0, LEAST(coalesce(date_part('epoch'::text, horarios.horafin2),86400), date_part('epoch'::text, tblregistro.ts_fechafin::TIME))) - 
           GREATEST(0, coalesce(date_part('epoch'::text, horarios.horaini2),0), date_part('epoch'::text, tblregistro.ts_fecha::TIME)) 
           else 0  end 
        ))/max(coalesce(date_part('epoch'::text, horarios.horafin1),86400)-coalesce(date_part('epoch'::text, horarios.horaini1),0)+coalesce(date_part('epoch'::text, horarios.horafin2),0)-coalesce(date_part('epoch'::text, horarios.horaini2),0) ) 
        else 0 end
        as h  
        from (controlacceso.qrycalendario turnos 
        inner JOIN controlacceso.Horarios horarios ON turnos.IdHorario = Horarios.Id 
        inner join public.empleados on turnos.idempleado=empleados.id)
        left join controlacceso.qryduracionregistro tblregistro ON tblregistro.idempleado = turnos.idempleado 
			and date_part('year',tblregistro.ts_fecha)=turnos.anio 
			and date_part('year',tblregistro.ts_fecha)=turnos.anio 
			and date_part('month',tblregistro.ts_fecha)=turnos.mes 
			and date_part('day',tblregistro.ts_fecha)=turnos.dia
        left join (controlacceso.diasfestivos diasfestivos 
			inner join mdelegaciones delegaciones on diasfestivos.coddelegacion=delegaciones.coddelegacion) 
        on empleados.coddelegacion=diasfestivos.coddelegacion 
			and diasfestivos.fecha=date_trunc('DAY',tblregistro.ts_fecha)::date
        where p_idempleado=empleados.id and  diasfestivos.fecha is null 
			and -- si es festivo no contemplarlo	      
			date_part('year',tblregistro.ts_fecha)=turnos.anio 
			and date_part('month',tblregistro.ts_fecha)=turnos.mes 
			and date_part('day',tblregistro.ts_fecha)=turnos.dia 
			and (turnos.idturno>0  
			and (turnos.anio||'-'||turnos.mes||'-'||turnos.dia)::date between p_f1 and p_f2)
       group by (turnos.anio||'-'||turnos.mes||'-'||turnos.dia)::date
       ) t;      
      if not found then 
         p_horas_en_turno:=0;
      end if;
      --raise exception 'dias=%, vacaciones %,laboralausente=%,dias laborales=%,prorateo=%,horas en turno=%',p_dias,p_vacaciones,p_laboralausente,p_dias_laborales,p_y,p_horas_en_turno;
      -- RAISE EXCEPTION 'horas en turno: % ',p_horas_en_turno;    
      if abs(p_dias_laborales - p_horas_en_turno+ p_laboralausente)>=5 then 
		-- si los días laborales - fracciones de jornadas trabajadas + días de 
		-- ausencia de jornadas laborales>=5 => Se anulan los pluses
        return 0;
      end if;      
      --RAISE EXCEPTION 'DIAS LABORALES: % ',p_dias_laborales;      
      p_X:=p_Y*(case when p_horas_en_turno>p_dias_laborales 
		then p_dias_laborales else p_horas_en_turno end) /p_dias_laborales ;      
      return p_X;   
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


CREATE OR REPLACE FUNCTION gestion_pluses_productividad(date, date, numeric, integer)
  RETURNS numeric AS
$BODY$
declare
	--Se le pasan dos fechas, un importe de plus, y un identificador de empleado, 
	--y la función devuelve el importe del plus que le corresponde a dicho empleado. 
	--Dicho importe se calcula usando las siguientes proporciones:
	--(nº dias del mes/p_plus)=(nº dias no vacaciones/Y) donde Y es el plus proporcional a los días de vacaciones
	--(Nº dias laborales (dias con idhorario>0 o idhorario<0 y el 
	--texto <>'Vacaciones'))/Y = ((Horas trabajadas en horario)/(Horas del horario))/X  
	--donde X es el plus a devolver por la función.
	/*  "Que, salvo las excepciones que posteriormente se indicarán, el importe del
	Plus de Productividad se reducirá en un cinco por ciento por cada día de
	ausencia, asimismo, se entenderá una ausencia la falta de asistencia al trabajo
	por más de tres horas en un día. Si la falta de asistencia es superior a cinco días
	consecutivos o a ocho discontinuos, el trabajador perderá el derecho al cobro del
	plus en ese mes.
	Que no se considerarán faltas de asistencia las que, con el preaviso de al
	menos 48 horas y con la correspondiente justificación estén expresamente
	señaladas a continuación:
	1.-Los días necesarios para traslado del domicilio habitual.
	2.-El tiempo indispensable para cumplir con obligaciones inexcusables de
	carácter público o personal."
	*/
	--Permiso y Curso/Formación no merman el plus de productivdad
	p_f1 ALIAS FOR $1;
	p_f2 ALIAS FOR $2;
	p_plus alias for $3;
	p_idempleado alias for $4;
	p_dias integer;
	p_vacaciones integer;
	p_Y numeric(18,2);
	p_X numeric(18,2);
	r record;
	i integer;
	p_cuenta integer;
begin
      if p_idempleado in (154,168,123,42) then 
		-- Si es el empleado Marcos Perez,Pedro Gallego,Eduardo Mendez o Nauzet Marrero, 
		--no se prorratea (se devuelve el plus integro)
         return p_plus;
      end if;
      p_dias=p_f2-p_f1 + 1; --Número de días del intervalo. Se le suma uno porque 
      --si las dos fechas coinciden, debe de devolver 1.
      if p_dias<=0 then
         return 0; 
      end if;

      p_vacaciones:=0; 
       --la siguiente consulta saca la cuenta de días de vacaciones, y otros días en teoría laborales pero marcados como no asistencia (dias con horario baja, enfermedad... que no sean fines de semana ni festivos)
      --así como los días marcados en horario como laborales (idhorario>0 y no festivo)
      select sum(case when horarios.texto='Vacaciones' then 1 else 0 end) into p_vacaciones 
      from 
      (controlacceso.qrycalendario qrycalendario  
		inner JOIN controlacceso.Horarios horarios ON qrycalendario.IdHorario = Horarios.Id 
		inner join public.empleados empleados on qrycalendario.idempleado=empleados.id)  
      left join controlacceso.diasfestivos diasfestivos 
		on diasfestivos.coddelegacion=empleados.coddelegacion 
		and diasfestivos.fecha=(qrycalendario.anio||'-'||qrycalendario.mes||'-'||qrycalendario.dia)::date
      where qrycalendario.idempleado=p_idempleado 
		and (qrycalendario.anio||'-'||qrycalendario.mes||'-'||qrycalendario.dia)::date 
		between p_f1 and p_f2 and horarios.id<0 and horarios.texto<>'No Procede';
      if not found then 
         p_vacaciones:=0;
      end if;
      --RAISE EXCEPTION '%',P_Y;
      p_Y:=(p_dias-COALESCE(p_vacaciones,0))*p_plus/p_dias; 
      --p_ Y contiene ahora el plus prorrateado en función de los días de vacaciones.
     i:=0; --número de días de ausencia (+ de 3 horas consecutivas sin venir)
     p_cuenta:=0; --número de días consecutivos de falta de asistencia encontrados
     for  r in select (turnos.anio||'-'||turnos.mes||'-'||turnos.dia)::date as fecha,
        sum(
        (case when tblregistro.ts_fechafin is not null 
			and ((tblregistro.ts_fecha,tblregistro.ts_fechafin) 
			overlaps (date_trunc('day', tblregistro.ts_fecha) + horarios.horaini1,date_trunc('day', tblregistro.ts_fecha) + horarios.horafin1)) then --comparten intervalo 
             GREATEST(0, LEAST(coalesce(date_part('epoch'::text, horarios.horafin1),86400), date_part('epoch'::text, tblregistro.ts_fechafin::TIME))) - 
             GREATEST(0, coalesce(date_part('epoch'::text, horarios.horaini1),0), date_part('epoch'::text, tblregistro.ts_fecha::TIME)) 
          else 0 end 
        + 
        case when (tblregistro.ts_fechafin is not null 
			and (tblregistro.ts_fecha,tblregistro.ts_fechafin) 
			overlaps (date_trunc('day', tblregistro.ts_fecha) + horarios.horaini2, date_trunc('day', tblregistro.ts_fecha) + horarios.horafin2)) then --comparten intervalo 
           GREATEST(0, LEAST(coalesce(date_part('epoch'::text, horarios.horafin2),86400), date_part('epoch'::text, tblregistro.ts_fechafin::TIME))) - 
           GREATEST(0, coalesce(date_part('epoch'::text, horarios.horaini2),0), date_part('epoch'::text, tblregistro.ts_fecha::TIME)) 
           else 0  end 
        )) as trabajado,
        max(coalesce(date_part('epoch'::text, horarios.horafin1),86400)-
			coalesce(date_part('epoch'::text, horarios.horaini1),0)+
			coalesce(date_part('epoch'::text, horarios.horafin2),0)-
			coalesce(date_part('epoch'::text, horarios.horaini2),0)) 
        as henturno,diasfestivos.fecha as festivo,horarios.id,horarios.texto
        from (controlacceso.qrycalendario turnos 
			inner JOIN controlacceso.Horarios horarios ON turnos.IdHorario = Horarios.Id 
			inner join public.empleados empleados on turnos.idempleado=empleados.id)
        left join controlacceso.qryduracionregistro tblregistro ON tblregistro.idempleado = turnos.idempleado 
			and date_part('year',tblregistro.ts_fecha)=turnos.anio 
			and date_part('year',tblregistro.ts_fecha)=turnos.anio 
			and date_part('month',tblregistro.ts_fecha)=turnos.mes 
			and date_part('day',tblregistro.ts_fecha)=turnos.dia
        left join (controlacceso.diasfestivos diasfestivos 
			inner join public.mdelegaciones delegaciones on diasfestivos.coddelegacion=delegaciones.coddelegacion) 
                   on empleados.coddelegacion=diasfestivos.coddelegacion 
                   and (turnos.anio||'-'||turnos.mes||'-'||turnos.dia)::date=diasfestivos.fecha
        where p_idempleado=empleados.id 
			and ((turnos.anio||'-'||turnos.mes||'-'||turnos.dia)::date between p_f1 and p_f2)
       group by (turnos.anio||'-'||turnos.mes||'-'||turnos.dia)::date,diasfestivos.fecha,horarios.id,horarios.texto order by (turnos.anio||'-'||turnos.mes||'-'||turnos.dia)::date loop
       
          if ((r.trabajado=0 and r.henturno>0) or (r.henturno-r.trabajado)>180*60) and 
			not (extract('dow' from (r.fecha)) in (0) or (extract('dow' from (r.fecha)) 
				in (6) and r.id<=0) or r.festivo is not null  or r.texto 
				IN ('Vacaciones','No Procede','Permiso','Curso/Formación')) then 
				-- los días que cumplen lo que está dentro del not, se ignoran
				--le correspondería venir, y ha dejado de venir
              i:=i+1; --falta de asistencia
              --raise exception 'trabajado=%',r.trabajado;
              p_cuenta:=p_cuenta+1;-- está de baja u otro motivo de ausencia
          else
            if p_cuenta<=5 and ((r.henturno-r.trabajado)<180*60) then -- hay menos de 5 días consecutivos con falta de asistencias, y el tío viene a trabajar un día completo
               p_cuenta:=0; --se resetea ya que hemos encontrado un día en el que  se viene a tabajar
            end if;   
          end if;
          if p_cuenta>5 then
            return 0;
          end if;
      end loop;
      --raise exception 'faltas de asistencia=%',i;
      if i > 8  then --Si tienes 8 días o más de ausencia 
         return 0;
      end if;    
      p_X:=(p_Y*(1-0.05*i));
      --Se descuenta un 5 % por cada día de falta de asistencia
      return p_X;   
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


CREATE OR REPLACE FUNCTION gestionhorasextras_comprobaciones(date, date, text, text, time without time zone, time without time zone, text)
  RETURNS text AS
$BODY$
declare
	-- FUNCIÓN PARA COMPROBAR SOLAPAMIENTO de UN HORARIO con una 
	-- imputación DE HORAS EXTRAS. llamar al modificar un horario, 
	-- o al insertar/actualizar una hora extra
	p_ts1 ALIAS FOR $1;
	p_ts2 ALIAS FOR $2;
	p_idempleados ALIAS FOR $3;
	p_op alias for $4; --'update o insert
	p_r1 alias for $5; --rango a insertar o eliminar
	p_r2 alias for $6;
	p_condicion alias for $7;
	p_msg text;
	cSql text;
	p_dia1 text;
	p_dia2 text;
	p_dia1hora text;
	p_dia2hora text;
begin
  p_msg:='';
  p_dia1hora:='((qrycalendario.anio||''-''||qrycalendario.mes||''-''||qrycalendario.dia)::date + '''||p_r1||'''::time)';
  p_dia2hora:='((qrycalendario.anio||''-''||qrycalendario.mes||''-''||qrycalendario.dia)::date + '''||p_r2||'''::time)';
  p_dia1:='(qrycalendario.anio||''-''||qrycalendario.mes||''-''||qrycalendario.dia)::date';
  p_dia2:='(qrycalendario.anio||''-''||qrycalendario.mes||''-''||qrycalendario.dia)::date';
  if p_op in ('INSERT','UPDATE') THEN
     if p_r1>p_r2 then
         return 'Los intervalos de horas extras (hora inicial: '||p_r1||' , hora final: '||p_r2||') deben de ser del mismo dia, y el primero menor que el segundo';
     end if;
     --Comprobamos que los empleados seleccionados no pertenezcan a un departamento sin horas extras
     cSql :='SELECT empleados.id||'' - ''||empleados.nomempleado||'' Pertenece a un departamento al que no está permitido asignarle horas extras(''||departamentos.coddepartamento||'' - ''||trim(departamentos.departamento)||'')''';
     cSql := cSql||'FROM public.empleados empleados ';
     cSql := cSql||'INNER JOIN produccion.depempleados depempleados ON empleados.id = depempleados.idempleado ';
     cSql := cSql||'INNER JOIN public.departamentos departamentos ON depempleados.iddepartamento = departamentos.id ';
     cSql := cSql||'where not departamentos.permitehorasextras and empleados.id in '||p_idempleados;
     Execute cSql into p_msg;
     if char_length(p_msg)>0 then  -- Si hemos encontrado algo es que pertenece a un departamento que no tiene horas extras.
        return p_msg;
     end if;
     -- Si turnosextras.tipo=3 (concesión de permisos), no hay que validar el siguiente where
     p_msg:='';
     cSql :='select ''Empleado: ''||empleados.id||'' - ''||empleados.nomempleado||'' Conflicto con horas extras. Se superpone hora extra a configurar:''||to_char('''||p_r1||'''::time,''hh24:mi:ss'')||'' - ''||to_char('''||p_r2||'''::time,''hh24:mi:ss'')||'' Con horario: ''||trim(horarios.texto)|| '' ''|| to_char((qrycalendario.anio||''-''||qrycalendario.mes||''-''||qrycalendario.dia)::date + horarios.horaini1,''dd-mm-yyyy hh24:mi:ss'')||'' - ''||to_char((qrycalendario.anio||''-''||qrycalendario.mes||''-''||qrycalendario.dia)::date + horarios.horafin1,''dd-mm-yyyy hh24:mi:ss'') ||case when horarios.horaini2 is not null and horarios.horafin2 is not null then '' Y ''||to_char(horarios.horaini2,''hh24:mi:ss'')||'' - ''||to_char(horarios.horafin2,''hh24:mi:ss'') else '''' end ';
     cSql := cSql||'  from public.empleados empleados ';
     cSql := cSql||'inner join controlacceso.qrycalendario qrycalendario on empleados.id= qrycalendario.idempleado ';
     cSql := cSql||'inner join controlacceso.horarios horarios on qrycalendario.idhorario=horarios.id ';
     cSql := cSql||'where qrycalendario.idempleado in '||p_idempleados;
     cSql := cSql||'  and (('||p_dia1hora||'::timestamp ,'||p_dia2hora||'::timestamp) ';
     cSql := cSql||'overlaps ('||p_dia1||'::date + horarios.horaini1, '||p_dia2||'::date + horarios.horafin1) or ';
     cSql := cSql||' ('||p_dia1hora||'::timestamp,'||p_dia2hora||'::timestamp) ';
     cSql := cSql||' overlaps ('||p_dia1||'::date + horarios.horaini2,'||p_dia2||'::date + horarios.horafin2)) ';
     cSql := cSql||'and  (qrycalendario.anio||''-''||qrycalendario.mes||''-''||qrycalendario.dia)::date between '''|| p_ts1 ||'''::date and '''||p_ts2||'''::date ';
     cSql := cSql||p_condicion;
     Execute cSql into p_msg;
     if char_length(p_msg)>0 then
        return p_msg;
     end if;
  end if;  
  if p_op in ('DELETE') then -- Comprobar que no hay registros de horas extras en el rango a actualizar
	cSql :=     'select '' El rango a eliminar se superpone con fichajes existentes de horas extras:''||to_char(tblregistro.ts_fecha,''dd-mm-yyyy hh24:mi:ss'')||'' - ''||to_char(tblregistro.ts_fechafin,''dd-mm-yyyy hh24:mi:ss'')  ';
	cSql := cSql||'from controlacceso.qryduracionregistro tblregistro';
	cSql := cSql||' where idempleado in '||p_idempleados||' and tblregistro.tipo>0 and  '; 
	cSql := cSql||'  tblregistro.ts_fecha::date BETWEEN '''||p_ts1||'''::date and '''||p_ts2||'''::date ';
	cSql := cSql||'and (tblregistro.ts_fecha,tblregistro.ts_fechafin - ''1 milliseconds''::interval) overlaps (tblregistro.ts_fecha::date+  '''||p_r1||'''::time,tblregistro.ts_fechafin::date + '''||p_r2||'''::time) ' ;
	Execute cSql into p_msg;
	if char_length(p_msg)>0 then
	   return 'No se puede eliminar esta horario de hora extra: '||to_char(p_r1,'hh24:mi:ss')||' - '||to_char(p_r2,'hh24:mi:ss')||'. '||p_msg;
	end if;
  end if;
  if p_op in ('UPDATE','INSERT') then 
	 -- Comprobar que EL MOMENTO A INSERTAR HORAS EXTRAS NO INCLUYE 
	 -- UN INTERVALO YA PASADO (no se pueden modificar las horas extras previstas
     cSql :='select ''Empleado: ''||empleados.id||'' - ''||empleados.nomempleado||'' Conflicto con horas extras. No se pueden modificar o insertar una planificación de horas extras de un momento del pasado:''||to_char('||p_dia1hora||'::timestamp,''dd-mm-yyyy hh24:mi:ss'')||'' - ''||to_char('||p_dia2hora||'::timestamp,''dd-mm-yyyy hh24:mi:ss'') ';
     cSql := cSql||'  from public.empleados empleados ';
     cSql := cSql||'inner join controlacceso.qrycalendario qrycalendario on empleados.id= qrycalendario.idempleado ';
     cSql := cSql||'inner join controlacceso.horarios horarios on qrycalendario.idhorario=horarios.id ';
     cSql := cSql||'where qrycalendario.idempleado in '||p_idempleados;
     cSql := cSql||'  and  now() >greatest('||p_dia1hora||'::timestamp ,'||p_dia2hora||'::timestamp) ';
     cSql := cSql||'and  (qrycalendario.anio||''-''||qrycalendario.mes||''-''||qrycalendario.dia)::date between '''|| p_ts1 ||'''::date and '''||p_ts2||'''::date ';
     cSql := cSql||'and idempleado in '||p_idempleados|| p_condicion;
     Execute cSql into p_msg;
     if char_length(p_msg)>0 then
        return p_msg;
     end if;
  end if;
  return 'OK';
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


CREATE OR REPLACE FUNCTION gestionhorasextras_comprobaciones_posteriori(integer, timestamp without time zone, timestamp without time zone, text, boolean, text)
  RETURNS text AS
$BODY$
declare
	-- Sobrecarca de la FUNCIÓN PARA COMPROBAR SOLAPAMIENTO de UN HORARIO con una 
	-- imputación DE HORAS EXTRAS. llamar al tratar de imputar una hora extra a posteriori. 
	-- VERSION CON IMPUTACIÓN DE OBSERVACIONES
	p_idempleado ALIAS FOR $1;
	p_r1 alias for $2; --rango a insertar o eliminar
	p_r2 alias for $3;
	p_coddelegacion alias for $4;
	p_confirmado alias for $5; -- si true, entonces procedemos aunque haya huecos en el intervalo de hora extra
	p_obs alias for $6; -- observaciones a poner en el comienzo del fichaje
	cSql text;
	cSql2 text;
	qry record;
	p_i1 timestamp;
	p_i2 timestamp;
	i int;
	p_msg text;
begin
	p_msg:='';  
	if p_r1>p_r2 or p_r1::date<>p_r2::date then
			return 'Los intervalos de horas extras (hora inicial: '||p_r1||' , hora final: '||p_r2||') deben de ser del mismo dia, y el primero menor que el segundo';
	end if;
    --Comprobamos que los empleados seleccionados no pertenezcan a un departamento sin horas extras
    SELECT empleados.id||' - '||empleados.nomempleado||' Pertenece a un departamento al que no está permitido asignarle horas extras('||departamentos.coddepartamento||' - '||trim(departamentos.departamento)||')' into p_msg
        FROM public.empleados empleados 
        INNER JOIN produccion.depempleados depempleados ON empleados.id = depempleados.idempleado 
        INNER JOIN public.departamentos departamentos ON depempleados.iddepartamento = departamentos.id 
        where not departamentos.permitehorasextras and empleados.id = p_idempleado;
	if found then
		if char_length(p_msg)>0 then  -- Si hemos encontrado algo es que pertenece a un departamento que no tiene horas extras.
			return p_msg;
		end if;
	end if;
    p_msg:='';
    select 'Empleado: '||empleados.id||' - '||empleados.nomempleado||' Conflicto con horas extras. Se superpone hora extra a configurar:'||to_char(p_r1::time,'hh24:mi:ss')||' - '||to_char(p_r2::time,'hh24:mi:ss')||' Con horario: '||trim(horarios.texto)|| ' '|| to_char((qrycalendario.anio||'-'||qrycalendario.mes||'-'||qrycalendario.dia)::date + horarios.horaini1,'dd-mm-yyyy hh24:mi:ss')||' - '||to_char((qrycalendario.anio||'-'||qrycalendario.mes||'-'||qrycalendario.dia)::date + horarios.horafin1,'dd-mm-yyyy hh24:mi:ss') ||case when horarios.horaini2 is not null and horarios.horafin2 is not null then ' Y '||to_char(horarios.horaini2,'hh24:mi:ss')||' - '||to_char(horarios.horafin2,'hh24:mi:ss') else '' end  into p_msg
        from public.empleados empleados 
        inner join controlacceso.qrycalendario qrycalendario on empleados.id= qrycalendario.idempleado 
        inner join controlacceso.horarios horarios on qrycalendario.idhorario=horarios.id 
        where qrycalendario.idempleado=p_idempleado and (qrycalendario.anio||'-'||qrycalendario.mes||'-'||qrycalendario.dia)::date=p_r1::date
	and ((p_r1 ,p_r2) overlaps (p_r1::date + horarios.horaini1, p_r2::date + horarios.horafin1) or (p_r1::timestamp,p_r2::timestamp) overlaps (p_r1::date + horarios.horaini2,p_r2::date + horarios.horafin2));
    if found then      
		if char_length(p_msg)>0 then
			return p_msg;
		end if;
    end if;
	if p_r1>now() or p_r2>now() then
		select 'Empleado: '||empleados.id||' - '||empleados.nomempleado||' Conflicto con horas extras. No se puede insertar horas extras a posteriori de un momento del futuro:'||to_char(p_r1,'dd-mm-yyyy hh24:mi:ss')||' - '||to_char(p_r2,'dd-mm-yyyy hh24:mi:ss') into p_msg
			from public.empleados empleados 
			inner join controlacceso.qrycalendario qrycalendario on empleados.id= qrycalendario.idempleado 
			inner join controlacceso.horarios horarios on qrycalendario.idhorario=horarios.id
			where (p_r1>now() or p_r2>now()) and emmpleados.id=p_idempleado; 
		if found then
			if char_length(p_msg)>0 then
				return p_msg;
			end if;
		end if;
	end if;
	perform id from controlacceso.tblregistro where idempleado=p_idempleado and not entrada and fecharegistro>=p_r2;
	if not found then --no hay una salida posterior a la finalización del intervalo de hora extra=>no se puede continuar
		return 'No hay un fichaje salida posterior a la finalización del intervalo de hora extra: ' || to_char(p_r1,'dd-mm-yyyy hh24:mi:ss')||' -- Al -- '||to_char(p_r2,'dd-mm-yyyy hh24:mi:ss')||'. No se puede incorporar este intervalo de hora extra';
	end if;
	/*
	varios casos (tener en cuenta el tránsito del último registro):
	tipo 0) Existe un fichaje
	tipo 1) Existe un hueco de salida-entrada en la hora extra =>preguntar. Si resp afirmativa, tomar extremo superior como finalización del intervalo de hora extra
	tipo 2) El comienzo de hora extra coincide con el de salida de un fichaje =>
	tipo 3) El comienzo de hora extra coincide con el de entrada de un fichaje
	tipo 4) La finalización de hora extra coincide con un fichaje de salida
	tipo 5) La finalización de hora extra coincide con un fichaje de entrada

	Otros casos de solapamiento
	6) El fichaje de entrada salida contenga al intervalo de hora extra
	7) El fichaje quede contenido en la hora extra
	8) El fichaje se solape con la hora extra solo por la hora de comienzo de dicha hora extra
	9) El fichaje se solape con la hora extra solo por la hora de finalización de dicha hora extra
	*/
	p_i1=p_r1;
	p_i2=p_r2;
	i:=0;
	cSql:='';
	cSql2:='';
	for qry in 
	select * from (
		select  id,id2,ts_fecha,ts_fechafin,estransito,tipo, coddelegacion, 
			case when p_r1=ts_fecha and p_r2=ts_fechafin and entrada then 0
				when  (p_r1,p_r2) overlaps (t.ts_fecha-'1 milliseconds'::interval,t.ts_fechafin) and not entrada and ts_fecha<>ts_fechafin and  (t.ts_fecha>p_r1 or t.ts_fechafin<p_r2) then 1 --Existe un hueco de salida-entrada en la hora extra =>preguntar. Si resp afirmativa, tomar extremo superior como finalización del intervalo de hora extra
				when p_r1=ts_fechafin then 2 -- El comienzo de hora extra coincide con el de salida de un fichaje =>
				when p_r1=ts_fecha and p_r2>ts_fechafin then 3  -- El comienzo de hora extra coincide con el de entrada de un fichaje y la salida de ese fichaje es menor que la finalización del intervalo de hora extra
				when p_r2=ts_fechafin and p_r1<ts_fecha then 4  -- La finalización de hora extra coincide con un fichaje de salida y el comienzo de dicha hora extra es anterior al inicio del fichaje
				when p_r2=ts_fechafin and p_r1>ts_fecha then 5  -- La finalización de hora extra coincide con un fichaje de salida y el comienzo de dicha hora extra es posterior al inicio del fichaje
				when p_r2=ts_fecha then 6   -- La finalización de hora extra coincide con un fichaje de entrada
				when ts_fecha<p_r1 and  ts_fechafin>p_r2 then 7 -- fichaje contiene  la hora extra
				when p_r1<ts_fecha and p_r2>ts_fechafin  then 8 -- hora extra contiene al fichaje
				when ts_fecha<p_r1 and  ts_fechafin>p_r1  then 9 -- fichaje contiene al comienzo de la hora extra 
				when ts_fecha<p_r2 and  ts_fechafin >p_r2 then 10 -- fichaje contiene la finalización  de la hora extra 
				when p_r1=ts_fecha and p_r2<ts_fechafin then 11  -- El comienzo de hora extra coincide con el de entrada de un fichaje y la salida de ese fichaje es mayor que la finalización del intervalo de hora extra
			else -1 end as tipof
			from controlacceso.qryduracionregistrobase  t
			where idempleado=p_idempleado and (
						((p_r1,p_r2) overlaps (t.ts_fecha- '1 milliseconds'::interval,t.ts_fechafin) and entrada) or
						((p_r1,p_r2) overlaps (t.ts_fecha-'1 milliseconds'::interval,t.ts_fechafin) and not entrada and ts_fecha<>ts_fechafin and (t.ts_fecha>p_r1 or t.ts_fechafin<p_r2)))
	) t
	order by tipof,ts_fecha 
	LOOP
       i:=i+1;
       --raise exception 'tipo=%',qry.tipof;
		if qry.tipof=0 then  -- Existen fichajes de entrada y de salida al comienzo y finalización del intervalo a poner de hora extra=> no hay que insertar nada, tan solo asegurarnos que esos fichajes están con tipo=1 (en hora extra)
			if qry.tipo<>1 then
				update controlacceso.tblregistro set tipo=1,observaciones=case when entrada then substr(p_obs,1,255) else observaciones end where id in (qry.id,qry.id2); --las observaciones se ponen en la entrada de hora extra
			end if;
			return 'OK';
		end if;
		if  qry.tipof=1 and (p_i2=p_r2 or p_i1=p_r1) then -- la segunda condición es para no entrar aquí más de una vez. Mostrar mensaje de advertencia y retornar error
			if (p_i2=p_r2) then
				p_i2=least(p_r2,greatest(p_r2,qry.ts_fecha,qry.ts_fechafin));
			end if;
			if (p_i1=p_r1) then
   				p_i1=greatest(p_r1,least(p_r1,qry.ts_fecha,qry.ts_fechafin));
			end if;

			if not p_confirmado and (qry.ts_fecha,qry.ts_fechafin) overlaps (p_i1,p_i2) then
				return '1|Existe un intervalo de comienzo:'||to_char(p_i1,'dd-mm-yyyy hh24:mi:ss')||' y finalización:'||to_char(qry.ts_fechafin,'dd-mm-yyyy hh24:mi:ss')||
						' en el que no hay computado tiempo de trabajo. ¿Desa proseguir? Se establecerá como hora extra el intervalo seleccionado exceptuando este tiempo';
			end if;
		end if;
		if qry.tipof=2 then --comienzo de hora extra coincide con el de salida de un fichaje=>crear un registro de hora extra de entrada
			cSql:='insert into controlacceso.tblregistro (idempleado,fecharegistro,entrada,esexterno,tipo,coddelegacion,estransito,observaciones) values  '||
				'('||p_idempleado||','''||p_i1||'''::timestamp,true,false,1,'''||p_coddelegacion||''','||qry.estransito||','''||p_obs||''');';
		end if;
		if qry.tipof=3  then -- El comienzo de hora extra coincide con el de entrada de un fichaje y la salida de ese fichaje es menor que la finalización del intervalo de hora extra
			update controlacceso.tblregistro set tipo=1,observaciones=case when entrada then substr(p_obs,1,255) else observaciones end where id in (qry.id,qry.id2);
			cSql:=''; --si hubo tipo 2 no debe de ser ejecutado (hubo una salida-Entrada en el mismo instante de comienzo del intervalo de hora extra).Por eso se vacía esta cadena
		end if;
		if qry.tipof=4 then -- La finalización de hora extra coincide con un fichaje de salida y el comienzo de dicha hora extra es anterior al inicio del fichaje
			update controlacceso.tblregistro set tipo=1 where id in (qry.id,qry.id2);
			cSql2:='tipof4';--marcamos que entró por aquí (por si hay un tipo 6)
		end if;
		if qry.tipof=5 then -- La finalización de hora extra coincide con un fichaje de salida y el comienzo de dicha hora extra es posterior al inicio del fichaje
			update controlacceso.tblregistro set tipo=1 where id = qry.id2;
			insert into controlacceso.tblregistro (idempleado,fecharegistro,entrada,esexterno,tipo,coddelegacion,estransito) values  
				(p_idempleado,p_i1,false,false,0,p_coddelegacion,qry.estransito); -- se crea un registro de salida a la hora de comienzo de la hora extra	  
			cSql2:='tipof5';--marcamos que entró por aquí (por si hay un tipo 6)
  			insert into controlacceso.tblregistro (idempleado,fecharegistro,entrada,esexterno,tipo,coddelegacion,estransito,observaciones) values  
				(p_idempleado,p_i1,true,false,1,p_coddelegacion,qry.estransito,substr(p_obs,1,255) ); -- se crea un registro de entrada a la hora de comienzo de la hora extra
		end if;
		if qry.tipof=6 and char_length(cSql2)=0 then --La finalización de hora extra coincide con un fichaje de entrada, y no hubo un tipo 4 o 5=>crear un registro de hora extra de salida, pero antes cambiar el registro actual por uno de salida
			update controlacceso.tblregistro set tipo=1,entrada=false,coddelegacion=p_coddelegacion where id=qry.id;
			insert into controlacceso.tblregistro (idempleado,fecharegistro,entrada,esexterno,tipo,coddelegacion,estransito) values  
					(p_idempleado,p_i2,true,false,qry.tipo,qry.coddelegacion,qry.estransito);
		end if;
		if qry.tipof=7 then -- Hay que crear 4 entradas
			insert into controlacceso.tblregistro (idempleado,fecharegistro,entrada,esexterno,tipo,coddelegacion,estransito) values (p_idempleado,p_i1,false,false,qry.tipo,p_coddelegacion,qry.estransito); --creamos una salida
			insert into controlacceso.tblregistro (idempleado,fecharegistro,entrada,esexterno,tipo,coddelegacion,estransito,observaciones) values (p_idempleado,p_i1,true,false,1,p_coddelegacion,qry.estransito,p_obs); --creamos una entrada en Hora extra
			insert into controlacceso.tblregistro (idempleado,fecharegistro,entrada,esexterno,tipo,coddelegacion,estransito) values (p_idempleado,p_i2,false,false,1,p_coddelegacion,qry.estransito); --creamos una salida en Hora extra
			insert into controlacceso.tblregistro (idempleado,fecharegistro,entrada,esexterno,tipo,coddelegacion,estransito) values (p_idempleado,p_i2,true,false,qry.tipo,p_coddelegacion,qry.estransito); --creamos una entrada en hora normal
		end if;
		if qry.tipof=8 then  -- Existen fichajes de entrada y de salida al comienzo y finalización del intervalo a poner de hora extra=> no hay que insertar nada, tan solo asegurarnos que esos fichajes están en hora extra
			if qry.tipo<>1 then
				update controlacceso.tblregistro set tipo=1,observaciones=case 
				when entrada then substr(p_obs,1,255) else observaciones end where id in (qry.id,qry.id2);
			end if;
		end if;
		if qry.tipof=9 then --Existe un fichaje que se solapa con la hora de comienzo del periodo de hora extra
   			insert into controlacceso.tblregistro (idempleado,fecharegistro,entrada,esexterno,tipo,coddelegacion,estransito) values (p_idempleado,p_i1,false,false,qry.tipo,p_coddelegacion,qry.estransito); --creamos una salida
			insert into controlacceso.tblregistro (idempleado,fecharegistro,entrada,esexterno,tipo,coddelegacion,estransito,observaciones) values (p_idempleado,p_i1,true,false,1,p_coddelegacion,qry.estransito,p_obs); --creamos una entrada en Hora extra
			if qry.tipo<>1 then
				update controlacceso.tblregistro set tipo=1 where id in (qry.id2);
			end if;
		end if;
		if qry.tipof=10 then --Existe un fichaje que se solapa con la hora de finalizacón del periodo de hora extra
			insert into controlacceso.tblregistro (idempleado,fecharegistro,entrada,esexterno,tipo,coddelegacion,estransito) values (p_idempleado,p_i2,false,false,1,p_coddelegacion,qry.estransito); --creamos una salida en Hora extra
			insert into controlacceso.tblregistro (idempleado,fecharegistro,entrada,esexterno,tipo,coddelegacion,estransito) values (p_idempleado,p_i2,true,false,qry.tipo,p_coddelegacion,qry.estransito); --creamos una entrada en hora normal
			if qry.tipo<>1 then
				update controlacceso.tblregistro set tipo=1 where id in (qry.id);
			end if;
		end if;
		if qry.tipof=11  then -- El comienzo de hora extra coincide con el de entrada de un fichaje y la salida de ese fichaje es mayor que la finalización del intervalo de hora extra
			update controlacceso.tblregistro set tipo=1,observaciones=case when entrada then substr(p_obs,1,255) else observaciones end where id in (qry.id,qry.id2);
			cSql:=''; --si hubo tipo 2 no debe de ser ejecutado (hubo una salida-Entrada en el mismo instante de comienzo del intervalo de hora extra
		end if;
	end loop;           
	if i=0 then -- no se encontró ningún registro de entrada salida que solape con el intervalo de hora extra=>error.
		return 'No hay constancia en los fichajes de haberse trabajado en el intervalo: ' || to_char(p_r1,'dd-mm-yyyy hh24:mi:ss')||' -- Al -- '||to_char(p_r2,'dd-mm-yyyy hh24:mi:ss')||'. Imposible por tanto, marcar dicho intervalo como de Hora Extra';
	end if;
	if char_length(cSql)>0 then --Ha habido un tipo2 (y no le siguió un tipo3 O un tipo11)
		execute cSql;
	end if;
	return 'OK';
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


CREATE OR REPLACE FUNCTION horasempleados(timestamp without time zone, timestamp without time zone, integer, integer, boolean)
  RETURNS integer AS
$BODY$
declare
	-- Suma el tiempo de horas disponibles por la configuración de horarios entre las dos fechas dadas. Si idempleado es = 0=>todos los empleados. 
	-- iddepartamento solo empleados que pertenecen al departamento dado
	-- Si p_departamentosmixtos=>solo los que tengan más de un departamento asignado. Si no, solo los puros
	p_f1 ALIAS FOR $1;
	p_f2 ALIAS FOR $2;
	p_idempleado ALIAS FOR $3;
	p_iddepartamento ALIAS FOR $4;
	p_empleadosmixtos alias for $5;
	total integer;
	p_f2x time;
begin
	p_f2x:=case when p_f2::time='00:00:00'::time then '23:59:59'::time else p_f2::time end;
	--SELECT SUM(EXTRACT(EPOCH FROM least(DATE_TRUNC('DAY',p_f2) + horarios.horafin1,p_f2))-EXTRACT(EPOCH from  greatest(DATE_TRUNC('DAY',p_f1) + horarios.horaini1,p_f1)) + EXTRACT(EPOCH FROM least(DATE_TRUNC('DAY',p_f2)+horarios.horafin2,p_f2))-EXTRACT(EPOCH from  greatest(DATE_TRUNC('DAY',p_f1) + horarios.horaini2,p_f1))) into total
	total:=0;
	SELECT SUM( 
		case when ((qrycalendario.anio||'-'||qrycalendario.mes||'-'||qrycalendario.dia)::date  + horarios.horaini1,  horarios.horafin1::interval)
		overlaps
		( p_f1,p_f2) then EXTRACT(EPOCH FROM least((qrycalendario.anio||'-'||qrycalendario.mes||'-'||qrycalendario.dia)::date + p_f2x::time,(qrycalendario.anio||'-'||qrycalendario.mes||'-'||qrycalendario.dia)::date + horarios.horafin1))
		- EXTRACT(EPOCH FROM greatest((qrycalendario.anio||'-'||qrycalendario.mes||'-'||qrycalendario.dia)::date + p_f1::time, (qrycalendario.anio||'-'||qrycalendario.mes||'-'||qrycalendario.dia)::date + horarios.horaini1)) 
		else 0 end
		+  
		case when ((qrycalendario.anio||'-'||qrycalendario.mes||'-'||qrycalendario.dia)::date  + horarios.horaini2,  horarios.horafin2::interval)
		overlaps
		(p_f1,p_f2) then EXTRACT(EPOCH FROM least((qrycalendario.anio||'-'||qrycalendario.mes||'-'||qrycalendario.dia)::date + p_f2x::time,(qrycalendario.anio||'-'||qrycalendario.mes||'-'||qrycalendario.dia)::date + horarios.horafin2))
		- EXTRACT(EPOCH FROM greatest((qrycalendario.anio||'-'||qrycalendario.mes||'-'||qrycalendario.dia)::date + p_f1::time, (qrycalendario.anio||'-'||qrycalendario.mes||'-'||qrycalendario.dia)::date + horarios.horaini2)) 
		else 0 end 
	) into total 
	FROM  ((public.empleados empleados 
		INNER JOIN controlacceso.qrycalendario qrycalendario ON empleados.id = qrycalendario.idempleado) 
		INNER JOIN controlacceso.horarios horarios ON qrycalendario.idhorario = horarios.id) 
		INNER JOIN 
			((select idempleado 
				from produccion.depempleados depempleados group by idempleado 
				having case when p_empleadosmixtos then count(iddepartamento)>1 else count(iddepartamento)=1 end
			) empleadosmixtos 
			inner join produccion.depempleados depempleados on empleadosmixtos.idempleado=depempleados.idempleado
			)  ON qrycalendario.idempleado = depempleados.idempleado 
	where qrycalendario.idhorario > 0  
	AND case when p_idempleado<>0 then depempleados.idempleado=p_idempleado else true end 
	and case when p_iddepartamento<>0 then depempleados.iddepartamento=p_iddepartamento else true end 
	and (qrycalendario.anio||'-'||qrycalendario.mes||'-'||qrycalendario.dia)::timestamp between p_f1 and p_f2;
	if found then
		if total is null then
			total:=0;
		end if;
	end if;
	return total;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


  CREATE OR REPLACE FUNCTION horasempleadosplanning(timestamp without time zone, timestamp without time zone, integer, integer, integer, boolean)
  RETURNS integer AS
$BODY$
declare
	-- Suma el tiempo de horas asignadas a planning (planningtareas) entre dos fechas
	-- p_idplanning <0 se buscarán todos lo planing distintos del abs(p_iddplanning). 
	-- Si es >0 el planning=p_idplanning. Y si es 0 no se filtra.
	p_f1 ALIAS FOR $1;
	p_f2 ALIAS FOR $2;
	p_idempleado ALIAS FOR $3;
	p_iddepartamento ALIAS FOR $4;
	p_idplanning ALIAS FOR $5;
	p_empleadosmixtos alias for $6;
	total integer;
	horashorario integer;
begin
	horashorario:=horasempleados(p_f1,p_f2,p_idempleado,p_iddepartamento,true); 
	-- horas disponibles para el empleados mixtos según su horario
	SELECT SUM(horasempleados(greatest(p_f1,planningtareas_recursos.ts_ini),
	least(p_f2,planningtareas_recursos.ts_fin),0,p_idempleado,true)) into total
	FROM public.empleados empleados 
		INNER JOIN produccion.planningtareas_recursos planningtareas_recursos on empleados.id=planningtareas_recursos.idempleado 
		inner join
			((select idempleado 
			from produccion.depempleados depempleados group by idempleado having count(iddepartamento)>1)
			) empleadosmixtos 
		inner join produccion.depempleados depempleados on empleadosmixtos.idempleado=depempleados.idempleado ON planningtareas_recursos.idempleado = depempleados.idempleado 
		inner join produccion.planningtareas planningtareas on planningtareas.id=planningtareas_recursos.idplanningtarea
		where  (planningtareas_recursos.ts_ini,planningtareas_recursos.ts_fin) overlaps (p_f1,p_f2) AND 
			case when p_idempleado<>0 then depempleados.idempleado=p_idempleado else true end 
			and case when p_iddepartamento<>0 then depempleados.iddepartamento=p_iddepartamento else true end 
			and case when p_idplanning<0 then planningtareas.idplanning<>-1 * p_idplanning when  p_idplanning>0 then planningtareas.idplanning= p_idplanning  else true end;
	if found then
		if total is null then
			total:=0;
		end if;
	end if;
	return horashorario - total; --devuelve el número de horas disponibles
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION horasempleadosplanning(timestamp without time zone, timestamp without time zone, integer, integer, integer, boolean)
  OWNER TO dovalo;


  CREATE OR REPLACE FUNCTION hri_formatea_num(text)
  RETURNS text AS
$BODY$
declare 
	p_numhoja alias for $1;
	p_hoja1 text;
	p_hoja2 text;
	p_hoja3 text;
begin
	p_hoja1:=substring(p_numhoja from 1 for length(p_numhoja)-7);
	p_hoja2:=substring(p_numhoja from length(p_numhoja)-6 for 4);
	p_hoja3:=substring(p_numhoja from length(p_numhoja)-2 for 3);
	select replace(concatenate(v),',','') into p_hoja1
	from(
		select a||' | ' as v
		from(
			select regexp_split_to_table(p_hoja1, E'\\s*') a
		) a
	) a;
	
	p_hoja1:=substring(p_hoja1,1,length(p_hoja1)-3);
	

	select  replace(concatenate(v),',','') into p_hoja2
	from(
		select a||' | ' as v
		from(
			select regexp_split_to_table(p_hoja2, E'\\s*') a
		) a
	) a;
	p_hoja2:=substring(p_hoja2,1,length(p_hoja2)-3);

	select replace(concatenate(v),',','') into p_hoja3
	from(
		select a||' | ' as v
		from(
			select regexp_split_to_table(p_hoja3, E'\\s*') a
		) a
	) a;
	p_hoja3:=substring(p_hoja3,1,length(p_hoja3)-3);
	return '| '||p_hoja1||' / '||p_hoja2||' / '||p_hoja3||' |';

end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

  CREATE OR REPLACE FUNCTION nextnumhojarecogida(text, text, integer)
  RETURNS text AS
$BODY$
--Se le pasa un nif y un nombre de sede, y devolverá el nima|
declare 
        p_nif alias for $1;
	p_nomsede alias for $2;
	p_anio alias for $3;
	r record;
	p_nima text;
begin
	if p_anio not between 2014 and 2100 then
           return 'El año '||p_anio||' no se considera valido';
        end if;


        select trim(direcciones.nima) into p_nima
	from public.externos inner join public.direcciones on externos.id=direcciones.idexterno inner join public.direcciones_tipos_links on   
		direcciones.id=direcciones_tipos_links.iddireccion and  direcciones_tipos_links.iddirecciontipo=4
	where externos.nif=p_nif and direcciones.nomsede=p_nomsede and externos.esempresagrupo;
        
	if found then
		perform sequence_schema, sequence_name 
		from information_schema.sequences, public.mdelegaciones 
		where sequence_catalog='acceso' and sequence_schema=current_schema
		and sequence_name=lower(p_nomsede)||p_anio;
		if not found then -- la secuencia no se ha encontrado en el esquema que estamos trabajando
		    execute 'create sequence '||lower(p_nomsede)||p_anio||'  INCREMENT 1  MINVALUE 1  MAXVALUE 9223372036854775807 START 1 CACHE 1;';
		end if;
		
		select nextval(lower(p_nomsede)||p_anio) as num into r;
		return p_nima||'|'||p_anio||'|'||lpad(r.num::text,3,'0');
	else
		return 'No se ha encontrado ningún registro con el nif pasado ('||p_nif||') y con el nombre de sede '||p_nomsede;
	end if;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


  CREATE OR REPLACE FUNCTION nif_valido(p_nif text)
  RETURNS text AS
$BODY$
------------------------------------------------------------------
--- Funcion para verificar el NIF español o el NIE de extranjeros
--- Se usa la tabla nif_no_validos como una lista negra a excluir.
------------------------------------------------------------------
--- Recibe un posible NIF/CIF/NIE y lo retorna en su formato
--- normalizado si se considera valido o cadena vacia en caso
--- contrario.
------------------------------------------------------------------
--- Para las plataformas petrolíferas no se usa un NIF/CIF sino
--- que es un numero IMO, que consta de 6 digitos numericos.
--- Para identificarlo de daran por validos todos aquellos que
--- tengan el formato IMO[0-9][0-9][0-9][0-9][0-9][0-9]
------------------------------------------------------------------
declare
    local_nif character(50);
    dni character(8);
    letra character(1);
begin
	-- Eliminamos los guiones, puntos, separadores, etc que
	-- puedan haber pasado.
	local_nif := upper(p_nif);
	local_nif := replace(local_nif, '.','');
	local_nif := replace(local_nif, '-','');
	local_nif := replace(local_nif, ',','');
	local_nif := replace(local_nif, ' ','');
	local_nif := replace(local_nif, '*','');
	local_nif := replace(local_nif, '/','');
	
	if (char_length(local_nif) != 9) then
		return '';
	end if;
	-- Verificamos que no se trate de un CIF/NIF 
	-- registrado en la lista negra.
	Perform nif from public.nif_no_validos nnv where nnv.nif = local_nif;
	if found then
		return '';
	end if;
	
	Perform nif from public.nif_validos nnv where nnv.nif = local_nif;
	if found then
		return local_nif;
	end if;
	
	-- Los CIFs los daremos por válidos
	if (substring(local_nif, 1,1) between 'A' and 'W') then
		return trim(local_nif);
	end if;

	-- Los IMOs los daremos por válidos
	if (substring(local_nif,1,3) = 'IMO') then
		return trim(local_nif);
	end if;
	
	dni := substring(local_nif, 1, 8);
	letra := substring(local_nif, 9, 1);
	dni := replace(dni, 'X', '');
	dni := replace(dni, 'Y', '1');
	dni := replace(dni, 'Z', '2');

	if translate(dni,'0123456789','')<>'' then
	   return '';
	end if;

	-- si llegados a este punto, el primer digito no es un numero
	-- entenderemos que no es valido.
	if (substring(dni, 1, 1) not in ('0','1','2','3','4','5','6','7','8','9')) then
		return '';
	end if;
	if (letra = substring('TRWAGMYFPDXBNJZSQVHLCKE', dni::integer % 23 + 1, 1)) then
		return trim(local_nif);
	end if;
	return '';
end
$BODY$
  LANGUAGE plpgsql IMMUTABLE STRICT
  COST 100;


CREATE OR REPLACE FUNCTION tblregistro_control_auditoria(integer, timestamp without time zone, timestamp without time zone, integer)
  RETURNS text AS
$BODY$	
declare				
	p_id alias for $1 ;
	p_fechaold alias for $2;
	p_fechanew alias for $3;
	p_iduser alias for $4;
begin
	insert into controlacceso.tblregistro_auditoria (fechaold,fechanew,id_registro,idusuario) 
	values (p_fechaold,p_fechanew,p_id,p_iduser);
	return'OK';
END;				
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


  CREATE OR REPLACE FUNCTION tblregistro_elimina_horasextras(timestamp without time zone, integer, boolean)
  RETURNS text AS
$BODY$	
declare				
	p_f alias for $1 ;
	p_id alias for $2;
	p_pregunta alias for $3;
	p_intervalo text;
	qry record;
	-- se busca en  turnos extras un intervalo del empleado que contenga a la fecha pasada, y se pregunta si se desea anular dicho intervalo.
	--Si se contesta que sí, se actualizarán todos los fichajes de registros de ese empleado a tipo=0 (fichaje normal), y se borrará el intervalo establecido
begin
	if p_pregunta then
		select  to_char(turnosextra.hini,'dd/mm/yyyy hh24:mi:ss')||' --- '||to_char(turnosextra.hfin,'dd/mm/yyyy hh24:mi:ss')  into p_intervalo
		from public.empleados empleados 
		inner join controlacceso.qrycalendario qrycalendario  on empleados.id=qrycalendario.idempleado 
		inner join controlacceso.turnosextras turnosextra on  qrycalendario.idturno=turnosextra.idturno and qrycalendario.dia=turnosextra.dia 
		where empleados.id=p_id and p_f between turnosextra.hini and turnosextra.hfin and (qrycalendario.anio||'-'||qrycalendario.mes||'-'||qrycalendario.dia)::date=p_f::date;
		if not found then
			return 'No existe ningún intervalo de hora extra creado que contenga la  fecha:'||to_char(p_f,'dd/mm/yyyy hh:mm:ss')||'. Imposible cambiarlo desde aquí. Comuníqueselo al departamento Informático';
		else
			return p_intervalo;
		end if;
	else
		for qry in
		update controlacceso.tblregistro tblregistro set tipo=0 from
		controlacceso.qrycalendario qrycalendario  
		inner join controlacceso.turnosextras turnosextra on  qrycalendario.idturno=turnosextra.idturno and qrycalendario.dia=turnosextra.dia
		where tblregistro.idempleado=p_id and tblregistro.idempleado=qrycalendario.idempleado and tblregistro.tipo=1 and (qrycalendario.anio||'-'||qrycalendario.mes||'-'||qrycalendario.dia)::date=p_f::date and 
			p_f between turnosextra.hini and turnosextra.hfin and tblregistro.fecharegistro between turnosextra.hini and turnosextra.hfin
		returning turnosextra.id 
		LOOP
			delete from controlacceso.turnosextras where id=qry.id;
			return 'OK';
		end loop;
	end if;
END;				
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


  CREATE OR REPLACE FUNCTION tblregistro_elimina_horasextrasnoprevistas(timestamp without time zone, timestamp without time zone, integer)
  RETURNS text AS
$BODY$	
declare				
	p_f1 alias for $1;
	p_f2 alias for $2;
	p_id alias for $3;
	p_intervalo text;
	qry record;
	-- Se eliminan (se actualiza el tipo a 0) aquellas horas extras encontradas en el intervalo
begin
	for qry in
	select r.id,r.id2,ts_fecha, ts_fechafin 
	from public.empleados empleados 
	inner join controlacceso.qryduracionregistro r on empleados.id=r.idempleado
	where empleados.id=p_id and p_f1::date=r.ts_fecha::date 
		and (r.ts_fecha between p_f1 and p_f2 and r.ts_fechafin between p_f1 and p_f2) 
		and r.tipo=1 and not (r.ts_fechafin=p_f1 or r.ts_fecha=p_f2) 
	LOOP 
		-- Este último and es para excluir E-S de horas extras que terminan justo 
		-- en el comienzo de hora extra, o que empiezan justo en la finalización de 
		-- la hora extra (esos fichajes no deben de contemplarse)
		update controlacceso.tblregistro set tipo=0 where id in (qry.id,qry.id2);
	end loop;
	return 'OK';
END;				
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


  CREATE OR REPLACE FUNCTION tblregistro_modificar_hora_extra(date, text, integer)
  RETURNS text AS
$BODY$				
declare	
	p_fechafichaje ALIAS FOR $1;	
	p_coddelegacion ALIAS FOR $2;
	p_idtipo alias for $3;
	p_fechalaboralanterior date;
	p_dif integer;
	msg text;
begin
	p_fechalaboralanterior:= fecha_laboral_anterior(current_date,p_coddelegacion);
	p_dif:=current_date - p_fechalaboralanterior;

	if p_idtipo=1 and p_dif<(current_date::date-p_fechafichaje) then -- Estamos modificando un registro de hora extra en una fecha posterior al día permitido (dia laboral anterior)
		msg:='No se puede modificar un fichaje de hora extra pasado más de un día laboral';
		return msg;
	end if;
	return 'OK';
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


  CREATE OR REPLACE FUNCTION tblregistro_pasoestado(text, integer)
  RETURNS text AS
$BODY$	
--Esta función solo la lanzará el proceso automático del Cron.			
declare		
	p_coddelegacion ALIAS FOR $1;				
	p_tipo ALIAS FOR $2;
	I INTEGER;
	qry record;				
begin
	I:=0;
	if p_coddelegacion='*' then
		insert into kk select now();
		--  else return 'OK';  
	end if;
	lock table controlacceso.tblregistro;
	FOR qry in 
		INSERT INTO controlacceso.TBLREGISTRO (fecharegistro,entrada,idempleado,coddelegacion,tipo,escierreaut,estransito,observaciones) 
		select  greatest(turnosextra.hini::timestamp,tblregistro.fecharegistro),false,empleados.id,tblregistro.coddelegacion,tblregistro.tipo,true,tblregistro.estransito,  /* Si la entrada es posterior al comienzo de la hora extra, la hora extra comienza en dicha entrada */
		coalesce(turnosextra.observaciones,'')
		from public.empleados empleados 
		inner join controlacceso.qrycalendario on empleados.id=qrycalendario.idempleado 
		inner join controlacceso.turnosextras turnosextra on  qrycalendario.idturno=turnosextra.idturno and qrycalendario.dia=turnosextra.dia 
		inner join controlacceso.tblregistro tblregistro ON tblregistro.idempleado=empleados.id 
		INNER JOIN (
			select MAX(ID) AS ID,R.IDEMPLEADO from CONTROLACCESO.TBLREGISTRO R 
			INNER JOIN (
				SELECT MAX(FECHAREGISTRO) AS FECHA,IDEMPLEADO 
				FROM controlacceso.tblregistro tblregistro 
				group by IDEMPLEADO
			) P ON R.IDEMPLEADO=P.IDEMPLEADO AND R.FECHAREGISTRO=p.FECHA 
			GROUP BY r.IDEMPLEADO
		) t on empleados.id = t.idempleado -- nos devolverá el último registro de fecha insertado
		and tblregistro.idempleado=empleados.id and  t.id=tblregistro.id
		left join (
			select idempleado, max(fecharegistro) as f1 
			from controlacceso.tblregistro tblregistro 
			where entrada and tipo=p_tipo 
			group by idempleado
		) t2 on t2.f1 between turnosextra.hini and turnosextra.hfin and t2.idempleado=empleados.id
		where (qrycalendario.anio||'-'||qrycalendario.mes||'-'||qrycalendario.dia)::date=current_date and tblregistro.tipo<>p_tipo and now() between turnosextra.hini and turnosextra.hfin
		and tblregistro.entrada 
		AND CASE WHEN P_CODDELEGACION<>'*' THEN empleados.coddelegacion=p_coddelegacion ELSE TRUE END 
		and t2.idempleado is null -- Que no hay horas extras de entrada CREADAS en ese intervalo
		and turnosextra.hfin - '20 minutes'::interval >= greatest(turnosextra.hini::timestamp,tblregistro.fecharegistro) --SI DEL MOMENTO DEL COMIENZO DE LA HORA EXTRA HASTA LA FINALIZACIÓN PLANIFICADA DE LA MISMA HAY UN INTERVALO>= 20 MINUOS, SE ARRANCA LA HORA EXTRA. nO SE HACE EN CASO CONTRARIO
		returning * 
	LOOP
		I:=I+1;
		INSERT INTO controlacceso.TBLREGISTRO (fecharegistro,entrada,idempleado,coddelegacion,tipo,escierreaut,ESTRANSITO) 
		values 
		(qry.fecharegistro,true,qry.idempleado,qry.coddelegacion,p_tipo,true,qry.estransito);
	end loop;


	FOR qry in --en este otro bucle,se hace el proceso inverso. Se finaliza un periodo de hora extra (útimo registro encontrado de la persona es una entrada en hora extra, y el momento actual no está en el intervalo de hora extra)
		INSERT INTO controlacceso.TBLREGISTRO (fecharegistro,entrada,idempleado,coddelegacion,tipo,escierreaut,estransito) 
		select  turnosextra.hfin::timestamp,false,empleados.id,tblregistro.coddelegacion,p_tipo,true,tblregistro.estransito 
		from public.empleados empleados 
		inner join controlacceso.qrycalendario on empleados.id=qrycalendario.idempleado 
		inner join controlacceso.turnosextras turnosextra on  qrycalendario.idturno=turnosextra.idturno and qrycalendario.dia=turnosextra.dia 
		inner join controlacceso.tblregistro tblregistro ON tblregistro.idempleado=empleados.id 
		INNER JOIN (
			select MAX(ID) AS ID,R.IDEMPLEADO 
			from CONTROLACCESO.TBLREGISTRO R 
			INNER JOIN (
				SELECT MAX(FECHAREGISTRO) AS FECHA,IDEMPLEADO 
				FROM controlacceso.tblregistro tblregistro 
				group by IDEMPLEADO
			) P ON R.IDEMPLEADO=P.IDEMPLEADO AND R.FECHAREGISTRO=p.FECHA 
			GROUP BY r.IDEMPLEADO
		) t on empleados.id = t.idempleado -- nos devolverá el último registro de fecha insertado
		and tblregistro.idempleado=empleados.id and  t.id=tblregistro.id
		where (qrycalendario.anio||'-'||qrycalendario.mes||'-'||qrycalendario.dia)::date=current_date 
		and not (now()  between turnosextra.hini and turnosextra.hfin) -- No estamos en este momento en el turno de hora extra encontrado 
		and tblregistro.fecharegistro between turnosextra.hini and turnosextra.hfin -- pero el último fichaje encontrado fue una entrada en hora extra
		and tblregistro.entrada AND case when p_coddelegacion<>'*' then empleados.coddelegacion=p_coddelegacion else true end --filtro por delegación o todas
		and tblregistro.tipo=p_tipo -- Su última entrada fue también de hora extra. Si fuese de otro tipo, no tendríamos que insertarla (ya habríamos salido de la hora extra)
		returning *
	LOOP
		INSERT INTO controlacceso.TBLREGISTRO (fecharegistro,entrada,idempleado,coddelegacion,tipo,escierreaut,ESTRANSITO) 
		values (qry.fecharegistro,true,qry.idempleado,qry.coddelegacion,0,true,qry.estransito);
	end loop;

	/* and coddelegacion=activa */
	-- Añadido el 14-06-2013 a las 12:45

	-- El siguiente bloque genera una salida automática si se cumple que el 
	-- último fichaje de un empleado marcado con tránsito limitado es una 
	-- entrada en tránsito a una hora anterior al comienzo del segundo tramo 
	-- de su horario y la hora actual es mayor que el comienzo di dicho tramo horario/*

    INSERT INTO controlacceso.TBLREGISTRO (fecharegistro,entrada,idempleado,coddelegacion,tipo,escierreaut,ESTRANSITO,observaciones)
	select  current_Date +  t.horario::time,false,split_part(s,'|',3)::integer,split_part(s,'|',4)::text,split_part(s,'|',6)::integer,true,split_part(s,'|',7)::boolean,
		'SALIDA AUTOMATICA GENERADA POR ESTAR ESTE EMPLEADO CON TRANSITO LIMITADO (ENTRADA EN TRÁNSITO A LAS '||split_part(s,'|',1)::TIME::TEXT||') '
	from (
		select coalesce(max(tblregistro.fecharegistro||'|'||tblregistro.id||'|'||tblregistro.idempleado||'|'||tblregistro.coddelegacion||'|'||tblregistro.entrada||'|'||tblregistro.tipo||'|'||tblregistro.estransito),'--') as s,coalesce(max(horarios.horaini2),'00:00')::text as horario
		from public.empleados empleados 
		inner join controlacceso.qrycalendario qrycalendario on empleados.id=qrycalendario.idempleado  
		inner join controlacceso.tblregistro tblregistro on empleados.id=tblregistro.idempleado AND (qrycalendario.anio||'-'||qrycalendario.mes||'-'||qrycalendario.dia)::date=tblregistro.fecharegistro::date 
		inner join controlacceso.horarios horarios on qrycalendario.idhorario=horarios.id 
		inner join produccion.depempleados depempleados on empleados.id=depempleados.idempleado 
		inner join departamentos on depempleados.iddepartamento=departamentos.id
		where current_time> horarios.horaini2 and  -- solo si la hora actual es mayor que el horario del segundo tramo definido
		      empleados.ficharentransitoespecial and (empleados.ficharentransito or departamentos.ficharentransito) and
		      tblregistro.fecharegistro::date=current_date and horarios.id>0 and horarios.horaini1 is not null and horarios.horafin1 is not null and horarios.horaini2 is not null and horarios.horafin2 is not null
	) t
	where t.s<>'--' and t.s<(current_date + t.horario::time)::text 
	and split_part(s,'|',5)::boolean and split_part(s,'|',7)::boolean; -- existe fichaje anterior a la hora de entrada del segundo tramo horario y es de entrada en tránsito
	--el siguiente bloque genera una entrada o una salida automática a aquellos empleados Antonio Morales,Arturo Santana,Juan Carlos Sosa, Juan Francisco Rodriguez que tengan un horario que empiece a las 6:00 o que termine a las 22:00
	--
	INSERT INTO controlacceso.TBLREGISTRO (fecharegistro,entrada,idempleado,coddelegacion,tipo,escierreaut,ESTRANSITO,observaciones)
	select  
		case when horarios.horaini1::time= '06:00:00' then current_Date +  horarios.horaini1::time else current_Date +  horarios.horafin1::time end,
		case when (horarios.horaini1::time= '06:00:00'::time and (t.idempleado is null or (split_part(t.f,'|',1)::date<current_date and not split_part(t.f,'|',3)::boolean ))) then true else false end,
		empleados.id,
		empleados.coddelegacion,
		0,
		true,
		coalesce(split_part(f,'|',5)::boolean,false),
		'FICHAJE AUTOMATICO GENERADO POR HORARIO DE COMIENZO (ENTRADA) A LAS 06:00 O FINALIZACIÓN (SALIDA) A LAS 22:00'
	from public.empleados empleados 
	inner join controlacceso.qrycalendario qrycalendario on empleados.id=qrycalendario.idempleado  
	left join (
		select tblregistro.idempleado, max(tblregistro.fecharegistro||'|'||tblregistro.id||'|'||entrada||'|'||tblregistro.tipo||'|'||tblregistro.ESTRANSITO) as f from controlacceso.tblregistro tblregistro	
		where 	tblregistro.idempleado in (21,26,25,183)
		group by  tblregistro.idempleado
	) t on empleados.id=t.idempleado 
	inner join controlacceso.horarios horarios on qrycalendario.idhorario=horarios.id  
	where empleados.id in (21,26,25,183) 
	and  (qrycalendario.anio||'-'||qrycalendario.mes||'-'||qrycalendario.dia)::date=current_date 
	and (
	--el horario empiece a las 6, y o bien no ha fichado nunca o bien (no haya fichado hoy y su último fichaje fue una salida). Se pone las 12:00 para que no compruebe esto después de las 12:00
	(horarios.horaini1::time= '06:00:00'::time and current_time<'07:50:00'::time and (t.idempleado is null or (split_part(f,'|',1)::date<current_date and not split_part(f,'|',3)::boolean ))) or 
	--el horario termine a las 22  o bien (el último fichaje sea de hoy, antes de las 22 y una entrada)
	(horarios.horafin1::time='22:00:00'::time and current_time>'22:00:00'::time and ((split_part(f,'|',1)::date=current_date and split_part(f,'|',1)::time<'22:00:00'::time and split_part(f,'|',3)::boolean)))
	);
	return 'OK';
END;				
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

  CREATE OR REPLACE FUNCTION turnosextra_eliminar(text, date, date, time without time zone, time without time zone, text)
  RETURNS text AS
$BODY$				
declare				
	-- inserta dentro de la tabla turnos extra los rangos dados. l trigger comprobará las posibles fusiones
	--en turnosextras, tipo=1 es hora extra.tipo=2 planificación de devolución de permiso,tipo=3 concesión de permiso en las horas indicadas
	p_idempleados ALIAS FOR $1;				
	p_f1 ALIAS FOR $2;				
	p_f2 ALIAS FOR $3;				
	p_r1 ALIAS FOR $4;	
	P_r2 ALIAS FOR $5;	
	p_where ALIAS FOR $6;	 			
	qry controlacceso.turnosextras%ROWTYPE;
	cSql text;
	p_idkk integer;
begin
	p_idkk:=0;      
	cSql := 'select qrycalendario.idempleado from controlacceso.turnosextras turnosextra inner join controlacceso.qrycalendario qrycalendario on ';
	cSql := cSql||'qrycalendario.idturno=turnosextra.idturno and qrycalendario.dia=turnosextra.dia ';
	cSql := cSql||'where idempleado in '||p_idempleados||' and (qrycalendario.anio||''-''||qrycalendario.mes||''-''||qrycalendario.dia)::date between '''||p_f1||'''::date and '''|| p_f2 ||'''::date and ';
	cSql := cSql||'('''||p_r1||'''::time,'''||p_r2||'''::time) overlaps (turnosextra.hini::time,turnosextra.hfin::time) and turnosextra.tipo=1';
	cSql := cSql||p_where;
	Execute cSql into p_idkk;        
	if p_idkk<>0 then
		-- 4 Casos posibles al tratar de eliminar un rango
	--1) eL INTERVALO PASADO CONTIENE POR COMPLETO Al INTERVALO DE HORA EXTRA ENCONTRADO=>se eliminan sin más
		cSql := 'DELETE FROM controlacceso.turnosextras turnosextra ';
		cSql := cSql||'USING controlacceso.qrycalendario qrycalendario ';
		cSql := cSql||'where qrycalendario.idturno=turnosextra.idturno and qrycalendario.dia=turnosextra.dia and ';
		cSql := cSql||'idempleado in '||p_idempleados||' and (qrycalendario.anio||''-''||qrycalendario.mes||''-''||qrycalendario.dia)::date between '''|| p_f1 ||'''::date and '''||p_f2||'''::date and ';
		cSql := cSql||'turnosextra.hini::time between '''||p_r1||'''::time and '''||p_r2||'''::time  and turnosextra.hfin::time  between '''||p_r1||'''::time and '''||p_r2||'''::time ';
		cSql := cSql||'and turnosextra.tipo=1 ';
		cSql := cSql||p_where;
		Execute cSql;
		--raise exception '%',cSql;
	--2) El intervalo pasado contiene la fecha final, pero no la fecha inicial de la hora extra encontrada=>actualización hfinal a la hora de comienzo pasada
        cSql := 'update controlacceso.turnosextras turnosextra set hfin=(hfin::date + '''||p_r1||'''::time)::timestamp  ';
        cSql := cSql||'from controlacceso.qrycalendario qrycalendario ';     
        cSql := cSql||'where qrycalendario.idturno=turnosextra.idturno and qrycalendario.dia=turnosextra.dia and  ';
        cSql := cSql||'idempleado in '||p_idempleados||' and (qrycalendario.anio||''-''||qrycalendario.mes||''-''||qrycalendario.dia)::date between '''||p_f1||'''::date and '''||p_f2||'''::date and ';
        cSql := cSql||'turnosextra.hfin::time between '''||p_r1||'''::time and '''||p_r2||'''::time and not (turnosextra.hini::time between '''||p_r1||'''::time  and '''||p_r2||'''::time ) ';
        cSql := cSql||'and turnosextra.tipo=1 ';
        cSql := cSql||p_where;
        Execute cSql;  
	--3) El intervalo pasado contiene la ficha inicial, pero no la fecha final
        cSql := 'update controlacceso.turnosextras turnosextra set hini=(hini::date + '''|| p_r2||'''::time)::timestamp  ';
        cSql := cSql||'from controlacceso.qrycalendario qrycalendario ';
        cSql := cSql||'where qrycalendario.idturno=turnosextra.idturno and qrycalendario.dia=turnosextra.dia and ';
        cSql := cSql||'idempleado in '||p_idempleados||' and (qrycalendario.anio||''-''||qrycalendario.mes||''-''||qrycalendario.dia)::date between '''||p_f1||'''::date and '''||p_f2||'''::date and ';
        cSql := cSql||'turnosextra.hini::time  between '''||p_r1||'''::time and '''||p_r2||'''::time and not (turnosextra.hfin::time between '''||p_r1||'''::time and '''||p_r2||'''::time) ';
        cSql := cSql||'and turnosextra.tipo=1 ';
        cSql := cSql||p_where;
		Execute cSql; 
    --4)  El intervalo pasado es contenido en la fecha inicial y fecha final de la hora extra==>actualizar uno, e insertar otro intervalo de hora extra
		cSql := 'select  turnosextra.* ';
		cSql := cSql||'FROM controlacceso.turnosextras turnosextra inner join controlacceso.qrycalendario qrycalendario on qrycalendario.idturno=turnosextra.idturno and ';
		cSql := cSql||'qrycalendario.dia=turnosextra.dia  ';
		cSql := cSql||'where idempleado in '||p_idempleados||' and (qrycalendario.anio||''-''||qrycalendario.mes||''-''||qrycalendario.dia)::date between '''||p_f1||'''::date and '''||p_f2||'''::date and ';
		cSql := cSql||'  '''||p_r1||'''::time between turnosextra.hini::time and turnosextra.hfin::time and '''||p_r2||'''::time between turnosextra.hini::time and turnosextra.hfin::time ';
		cSql := cSql||'and turnosextra.tipo=1 ';
		cSql := cSql||p_where;
        For qry In Execute cSql 
        LOOP
			update controlacceso.turnosextras set hfin= (hfin::date + p_r1::time)::timestamp  where id=qry.id;
			insert into controlacceso.turnosextras (idturno,dia,hini,hfin,tipo) 
			values (qry.idturno,qry.dia, (qry.hini::date + p_r2::time)::timestamp,qry.hfin,1);
		end loop; 
	end if;
	return 'OK';
END;				
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION turnosextra_eliminar(text, date, date, time without time zone, time without time zone, text)
  OWNER TO dovalo;