/*  ************** Bloque de gestión de menús, permisos y acciones de ususarios   */
DROP TABLE IF EXISTS stocks;
drop table if exists stocks_lotes;
DROP TABLE IF EXISTS sat_motivos;
DROP TABLE IF EXISTS sat_motivos_tipos;
DROP TABLE IF EXISTS documentos_obs;
DROP TABLE IF EXISTS documentos_obs_categorias;
drop table if exists cash; 
drop view if exists view_trazabilidad;
drop table if exists lineas;
DROP TABLE IF EXISTS DOCUMENTOS;
drop table if exists documentos_tipos;
DROP TABLE IF EXISTS ALMACENES;
DROP TABLE IF EXISTS almacenes_estados;
DROP TABLE IF EXISTS series_documentos;
drop table if exists series;
drop table if exists documentos_trazabilidades;
DROP TABLE IF EXISTS documentos_controles;
drop table  if exists documentos_tipos;
drop table if exists cash_tipofpagos_lineas; 
drop table if exists cash_tipofpagos;
drop table if exists articulos_proveedor;
drop table if exists articulos_gruposventas; 
drop table if exists articulos_propiedades;
DROP TABLE IF EXISTS articulos;
drop table if exists familias_valoresligados;
drop table if exists familias_propiedades;
DROP TABLE IF EXISTS propiedades; 
DROP TABLE IF EXISTS articulos_grupopropiedades;
drop view if exists menufamilias; 
DROP TABLE IF EXISTS familias;
drop table if exists propiedades_componer;
drop table if exists articulos_lers;
DROP TABLE IF EXISTS IMPUESTOS;
drop table if exists direcciones_horarios;
drop table if exists horarios;
drop table if exists horarios_tipos;
DROP TABLE IF EXISTS unidadmedidas;
DROP TABLE IF EXISTS unidadmedida_categorias;
drop table if exists direcciones_tipos_links;
DROP TABLE IF EXISTS direcciones;
drop table if exists direcciones_tipos;
DROP TABLE IF EXISTS dirinfocomplementarias;
DROP TABLE IF EXISTS dircalles;
DROP TABLE IF EXISTS dirmunicipioscp;
DROP TABLE IF EXISTS dirmunicipios;
DROP TABLE IF EXISTS dirlocalidades;
DROP TABLE IF EXISTS dircodpostales;
DROP TABLE IF EXISTS dirislas;
DROP TABLE IF EXISTS dirprovincias;
DROP TABLE IF EXISTS dircomunidades;
DROP TABLE IF EXISTS dirpaises;
drop table if exists entidades_gruposventas;
drop table  if exists entidades;
drop table  if exists entidades_links_tipos;
drop table  if exists entidades_tipos;
drop table if exists gruposventas;
drop table if exists cuentas;
drop table if exists perfiles_acciones;
drop table if exists usuarios_acciones;
drop table if exists usuarios_perfiles;
drop table if exists perfiles;
drop table if exists usuarios;
drop table if exists menus_acciones;
drop table if exists acciones;
drop view if exists menupaths;
drop table if exists menus;


create table menus(
id serial primary key,
menu_id integer default null references menus(id) match simple,
texto character varying(250),
textoayuda character varying(250),
iconopen character varying(100),
iconclosed character varying(100),
metodo character varying(100),
unique (texto)
);

COMMENT ON table menus IS 'Opciones de menú de la aplicación';

delete from menus;
insert into menus (id,menu_id,texto,textoayuda,metodo) values (1,null,'Oficina','Area de Oficina','');
insert into menus (id,menu_id,texto,textoayuda,metodo) values (2,null,'Produccion','Area de Produccion','');
insert into menus (id,menu_id,texto,textoayuda,metodo) values (3,null,'Comercial','Area Comercial','');
insert into menus (id,menu_id,texto,textoayuda,metodo) values (4,null,'Maestros comunes','Elementos básicos comunes, o que afectan a más de un area anterior','');
insert into menus (id,menu_id,texto,textoayuda,metodo) values (5,4,'Relacion entre sociedades','Definición de los posibles vínculos de una sociedad con otra (Proveedor De, cliente De...)','');
insert into menus (id,menu_id,texto,textoayuda,metodo) values (6,4,'Tipos de sociedades','Tipo de personalidad, y forma juridica','');
insert into menus (id,menu_id,texto,textoayuda,metodo) values (7,4,'Sociedades','Sociedades/personas con las que nos relacionamos','');
insert into menus (id,menu_id,texto,textoayuda,iconopen,iconclosed,metodo) values (9,2,'Productos','Todo lo relacionado con la gestion del catalogo (articulos, almacenes)','productos-open.png','productos-closed.png','');
insert into menus (id,menu_id,texto,textoayuda,iconopen,iconclosed,metodo) values (10,9,'Familias de los articulos','Gestión de las diferentes  que categorizan a los articulos','familias-open.png','familias-closed.png','');
insert into menus (id,menu_id,texto,textoayuda,iconopen,iconclosed,metodo) values (11,9,'Propiedades de los articulos','Definicion de las propiedades que definen la naturaleza de los articulos y familias','propiedades-open.PNG','propiedades-closed.PNG','Mod_propiedades');
insert into menus (id,menu_id,texto,textoayuda,iconopen,iconclosed,metodo) values (12,9,'Catálogos de propiedad','Definicion de conjunto de propiedades con sus valores preconfigurados','catalogos-propiedades-open.png','catalogos-propiedades-closed.png','');
insert into menus (id,menu_id,texto,textoayuda,iconopen,iconclosed,metodo) values (13,9,'Artículos','Gestion de los diferentes articulos','articulos-open.png','articulos-closed.png','');

select setval('menus_id_seq',max(id)) from menus;



CREATE OR REPLACE VIEW menupaths AS
WITH RECURSIVE menupaths AS (
SELECT id,menu_id as padre_id,texto,textoayuda,metodo, ''::character varying as padre, texto::text as path_texto,id::text as path_id,iconopen,iconclosed FROM menus WHERE menu_id is null 
UNION
SELECT
menus.id,menus.menu_id as padre_id,menus.texto,menus.textoayuda,menus.metodo,parentpath.texto as padre, parentpath.path_texto||'/'||menus.texto as path_texto,parentpath.path_id||'/'||menus.id as path_id,menus.iconopen,menus.iconclosed
FROM menus, menupaths parentpath
WHERE  parentpath.id=menus.menu_id
)
SELECT * FROM menupaths order by padre,texto;



create table acciones(
id serial primary key,
texto character varying(200),
);


create table menus_acciones(
id serial primary key,
idmenu integer references menus(id),
accion_id integer references acciones(id),
ejecutar character varying(200)
);


create table usuarios(
id serial primary key,
login character(50),
pwd character(50),
entidad_id integer references entidades(id) match full
);


create table perfiles(
id serial primary key,
describe character varying(200)
);


create table usuarios_perfiles(
id serial primary key,
usuario_id integer references usuarios(id) match full,
idperfil_id integer references perfiles(id) match full,
unique(idusuario,idperfil)
);



create table perfiles(
id serial primary key,
accion_id integer references acciones(id) match full,
usuario_id integer references usuarios(id) match full,
habilitar boolean not null default true,
unique(idaccion,idusuario)
);
comment on table usuarios_acciones is 'Si habilitar=TRUE, entonces ese usuario tiene poteztad para realizar dicha acción. Si no, No';


create table perfiles_acciones(
id serial primary key,
accion_id integer references acciones(id) match full,
perfil_id integer references perfiles(id) match full,
unique(accion_id,perfil_id)
);


/* Fin del bloque de gestión de menús permisos y acciones de usuarios */


/* *************** Bloque de información contable */

create table cuentas(
id serial primary key,
codcuenta character varying(12) not null,
describe character varying(100) not null
);

/* ************ Bloque de grupo de ventas  */

create table  gruposventas(
id serial primary key,
codgrupo character varying(12) not null,
describe character varying(100) not null
);

insert into gruposventas (id,codgrupo,describe) values (1,'HIP','HIPERCOR');
insert into gruposventas (id,codgrupo,describe) values (2,'ECI','EL CORTE INGLES');
insert into gruposventas (id,codgrupo,describe) values (3,'MKM','MERKAMUEBLES');
select setval('gruposventas_id_seq',max(id)) from gruposventas;


/* ************** Bloque de Gestión de entidades y relaciones entre ellos */


create table entidades_links_tipos(
id serial primary key,
describehijo character varying(100),
describepadre character varying(100)
);
insert into entidades_links_tipos (id,describehijo,describepadre) values (1,'ES EMPLEADO DE','EMPLEADOS');
insert into entidades_links_tipos (id,describehijo,describepadre) values (2,'ES CLIENTE AL MAYOR (VENDEDOR) DE','CLIENTES AL MAYOR (VENDEDORES)');
insert into entidades_links_tipos (id,describehijo,describepadre) values (3,'ES CLIENTE AL MAYOR (CONSUMIDOR FINAL) DE','CLIENTES AL MAYOR (CONSUMIDORES FINALES)');
insert into entidades_links_tipos (id,describehijo,describepadre) values (4,'ES CLIENTE AL MENOR DE','CLIENTES AL MENOR');
insert into entidades_links_tipos (id,describehijo,describepadre) values (5,'ES REPRESENTANTE DE','REPRESENTANTES');
insert into entidades_links_tipos (id,describehijo,describepadre) values (6,'ES ACREEDOR DE','ACREEDORES');
insert into entidades_links_tipos (id,describehijo,describepadre) values (7,'ES COMERCIAL DE','COMERCIALES');
insert into entidades_links_tipos (id,describehijo,describepadre) values (8,'ES COMERCIAL DE','COMERCIALES');
insert into entidades_links_tipos (id,describehijo,describepadre) values (9,'ES REPRESENTANTE/AGENTE CUENTA PROPIA DE','REPRESENTANTES/AGENTES POR CUENTA PROPIA');
insert into entidades_links_tipos (id,describehijo,describepadre) values (10,'ES REPRESENTANTE/AGENTE CUENTA AJENA (SUBAGENTE) DE','REPRESENTANTES/AGENTES POR CUENTA AJENA (SUBAGENTE)');

select setval('entidades_links_tipos_id_seq',max(id)) from entidades_links_tipos;


create table entidades_tipos(
id serial primary key,
Personalidad character(20) CHECK (personalidad = ANY (ARRAY['FISICA'::character(15), 'JURIDICA'::character(15)])),
forma character varying(250),
iniciales character(10),
unique(iniciales)
);

insert into entidades_tipos (id,personalidad,forma,iniciales) values (1,'FISICA','PERSONA FISICA','PF');
insert into entidades_tipos (id,personalidad,forma,iniciales) values (2,'FISICA','EMPRESARIO INDIVIDUAL','EI');
insert into entidades_tipos (id,personalidad,forma,iniciales) values (3,'FISICA','COMUNIDAD DE BIENES','CB');
insert into entidades_tipos (id,personalidad,forma,iniciales) values (4,'FISICA','SOCIEDAD CIVIL','SCI');
insert into entidades_tipos (id,personalidad,forma,iniciales) values (5,'JURIDICA','SOCIEDADES MERCANTILES -> SOCIEDAD COLECTIVA','SCO');
insert into entidades_tipos (id,personalidad,forma,iniciales) values (6,'JURIDICA','SOCIEDADES MERCANTILES -> SOCIEDAD RESPONSABILIDAD LIMITADA','SL');
insert into entidades_tipos (id,personalidad,forma,iniciales) values (7,'JURIDICA','SOCIEDADES MERCANTILES -> SOCIEDAD LIITADA NUEVA EMPRESA','SLNE');
insert into entidades_tipos (id,personalidad,forma,iniciales) values (8,'JURIDICA','SOCIEDADES MERCANTILES -> SOCIEDAD ANONIMA','SA');
insert into entidades_tipos (id,personalidad,forma,iniciales) values (9,'JURIDICA','SOCIEDADES MERCANTILES -> SOCIEDAD COMANDITARIA POR ACCIONES','SCA');
insert into entidades_tipos (id,personalidad,forma,iniciales) values (10,'JURIDICA','SOCIEDADES MERCANTILES -> SOCIEDAD COMANDITARIA SIMPLE','SCS');
insert into entidades_tipos (id,personalidad,forma,iniciales) values (11,'JURIDICA','SOCIEDADES MERCANTILES ESPECIALES -> SOCIEDAD LABORAL 1','SAL');
insert into entidades_tipos (id,personalidad,forma,iniciales) values (12,'JURIDICA','SOCIEDADES MERCANTILES ESPECIALES -> SOCIEDAD LABORAL 2','SLL');
insert into entidades_tipos (id,personalidad,forma,iniciales) values (13,'JURIDICA','SOCIEDADES MERCANTILES ESPECIALES -> SOCIEDAD COOPERATIVA','COOP');
insert into entidades_tipos (id,personalidad,forma,iniciales) values (14,'JURIDICA','SOCIEDADES MERCANTILES ESPECIALES -> AGRUPACION DE INTERES ECONOMICO','AIE');
insert into entidades_tipos (id,personalidad,forma,iniciales) values (15,'JURIDICA','SOCIEDADES MERCANTILES ESPECIALES -> SOCIEDAD DE INVERSION MOBILIARIA','SIM');

select setval('entidades_tipos_id_seq',max(id)) from entidades_tipos;

select * from entidades
create table entidades(
id serial primary key,
nomentidad character varying(200),
nomcomercial character varying(200),
nif character(15),
tipo_id integer references entidades_tipos(id) match full DEFAULT 1,
espropia bool default false,
codentidad character(10)
);
CREATE unique INDEX idx_entidades_nif ON entidades USING btree (nif);
CREATE unique INDEX idx_entidades_codentidad ON entidades USING btree (codentidad);


insert into entidades (id,nomentidad,nomcomercial,nif,tipo_id,espropia) values (1,'SUAREZ Y MORALES REPRESENTACIONES, S.L','SYM','B35386630',6,true);
insert into entidades (id,nomentidad,nomcomercial,nif,tipo_id,espropia) values (2,'DIMOLAX CANARIAS, S.L','DIMOLAX CANARIAS, S.L','B35386631',6,true);

select setval('entidades_id_seq',max(id)) from entidades;

create table entidades_links( --relaciones entre las entidades
id serial primary key,
entidadlink_id integer references entidades(id) match full,
entidadlinkpadre_id integer references entidades(id) match full,
entidadtipo_id integer references entidadades_tipos(id) match full,
-- Campos adicionales que necesitan ponerse 
codentidad character(10),
cuenta_id integer references cuentas(id) match simple default null
);
CREATE unique INDEX idx_entidades_entidadlink_id ON entidades_links USING btree (entidadlink_id,entidadlinkpadre_id,entidadtipo_id);


create table  entidades_gruposventas(
id serial primary key,
entidad_id integer references entidades(id) match full,
grupoventa_id references gruposventas(id),
);




/* Fin Bloque de gestión de entidades y relaciones entre ellos */





/* ************** Bloque de direcciones e información Relacionada */

--dirpaises

create table dirpaises(
id serial primary key,
describe character varying(150) not null default ''
);


create table dircomunidades(
id serial primary key,
pais_id integer not null references dirpaises(id) match full,
describe character varying(150) not null default ''
);
CREATE  INDEX idx_dircomunidades_pais_id ON dircomunidades USING btree (pais_id);



create table dirprovincias(
id serial primary key,
comunidad_id integer default null references dircomunidades(id) match simple,
pais_id integer not null default 0 references dirpaises(id) match full,
describe character varying(150) not null default ''
);
CREATE  INDEX idx_dirprovincias_pais_id ON dirprovincias USING btree (pais_id);
CREATE  INDEX idx_dirprovincias_coumunidad_id ON dirprovincias USING btree (comunidad_id);


create table dirislas(
id serial primary key,
provincia_id integer references dirprovincias(id) match full,
describe character varying(150) not null default ''
);
CREATE  INDEX idx_dirislas_provincia_id ON dirislas USING btree (provincia_id);



create table dirlocalidades(
id serial primary key,
codpostal character varying(10),
describe character varying(150) not null default ''
);
CREATE  INDEX idx_dirlocalidades_codpostal_id ON dirlocalidades USING btree (codpostal);



create table dirmunicipios(
id serial primary key,
provincia_id integer references dirprovincias(id) match full on update cascade on delete cascade,
isla_id integer references dirislas(id) match simple on update cascade on delete cascade,
describe character varying(150) not null default ''
);
CREATE  INDEX idx_dirmunicipios_provincia_id ON dirmunicipios USING btree (provincia_id);
CREATE  INDEX idx_dirmunicipios_isla_id ON dirmunicipios USING btree (isla_id);


create table dirmunicipioscp(
id serial primary key,
municipio_id integer references dirmunicipios(id) match full on update cascade on delete cascade,
codpostal character varying(10) 
);
CREATE  INDEX idx_dirmunicipioscp_municipio_id ON dirmunicipioscp USING btree (municipio_id);
CREATE  INDEX idx_dirmunicipios_codpostal ON dirmunicipioscp USING btree (codpostal);




create table dircalles(
id serial primary key,
codpostal character varying(10), 
municipio_id integer default null references dirmunicipios(id) match full on update cascade on delete cascade,
describe character varying(150) not null default ''
);

CREATE  INDEX idx_dircalles_codpostal ON dirlocalidades USING btree (codpostal);
CREATE  INDEX idx_dircalles_municipio_id ON dircalles USING btree (municipio_id);



create table dirinfocomplementarias(
id serial primary key,
describe character varying(150) not null default ''
);

insert into dirinfocomplementarias (id,describe) values (1,'CALLE'); 
insert into dirinfocomplementarias (id,describe) values (2,'POLIGONO');
insert into dirinfocomplementarias (id,describe) values (3,'POLIGONO INDUSTRIAL');
insert into dirinfocomplementarias (id,describe) values (4,'CARRETERA');
insert into dirinfocomplementarias (id,describe) values (5,'BARRANCO');
insert into dirinfocomplementarias (id,describe) values (6,'EDIFICIO');
insert into dirinfocomplementarias (id,describe) values (7,'BARRIO');
insert into dirinfocomplementarias (id,describe) values (8,'AVENIDA');
insert into dirinfocomplementarias (id,describe) values (9,'BAJADA');
insert into dirinfocomplementarias (id,describe) values (10,'ALDEA');
insert into dirinfocomplementarias (id,describe) values (11,'PARROQUIA');
insert into dirinfocomplementarias (id,describe) values (12,'PROLONGACION');
insert into dirinfocomplementarias (id,describe) values (13,'PLAZA');
insert into dirinfocomplementarias (id,describe) values (14,'GLORIETA');
insert into dirinfocomplementarias (id,describe) values (15,'ALAMEDA');
insert into dirinfocomplementarias (id,describe) values (16,'MERCADO');
insert into dirinfocomplementarias (id,describe) values (17,'CENTRO COMERCIAL');
insert into dirinfocomplementarias (id,describe) values (18,'RAMBLA');
insert into dirinfocomplementarias (id,describe) values (19,'PASEO');
insert into dirinfocomplementarias (id,describe) values (20,'PASAJE');
select setval('dirinfocomplementarias_id_seq',max(id)) from dirinfocomplementarias;


create table direcciones_tipos(
id serial primary key,
describe character varying(100),
esunica boolean default true,
sede  boolean default false,
sedenima boolean default false
);


insert into direcciones_tipos (id,describe,esunica,sede,sedenima) values (0,'SEDE FISCAL',true,false,false);
insert into direcciones_tipos (id,describe,esunica,sede,sedenima) values (1,'SEDE ENVÍO FACTURAS',false,false,false);
insert into direcciones_tipos (id,describe,esunica,sede,sedenima) values (2,'SEDE ENVÍO MERCANCÍA',false,true,false);
insert into direcciones_tipos (id,describe,esunica,sede,sedenima) values (3,'SEDE TIENDA',false,true,false);
insert into direcciones_tipos (id,describe,esunica,sede,sedenima) values (4,'SEDE NIMA',false,true,true);
insert into direcciones_tipos (id,describe,esunica,sede,sedenima) values (5,'SEDE OFICINA',false,true,true);
insert into direcciones_tipos (id,describe,esunica,sede,sedenima) values (6,'SEDE ALMACEN',false,true,true);


select setval('direcciones_tipos_id_seq',max(id)) from direcciones_tipos;


create table direcciones(
id serial primary key,
nomsede character varying (50) default '', --indicará un texto para describir la dirección, como puede ser "sucursal del sur", "dirección de envío"...o lo que se quiera
entidad_id integer references entidades(id) match full,
calle_id integer references dircalles(id) match full,
infocomplementaria_id integer references dirinfocomplementarias(id)  match full default 1,
infocomplementaria character varying(50) default '',
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

create table direcciones_tipos_links(
id serial primary key,
direccion_id integer references direcciones(id) match full,
direcciones_tipo_id integer references direcciones_tipos(id)
);

CREATE INDEX idx_direcciones_idcalle ON direcciones USING btree (calle_id);
CREATE INDEX idx_direcciones_idinfocomplementaria ON direcciones USING btree (infocomplementaria_id);
CREATE INDEX idx_direcciones_nima ON direcciones USING btree (nima);
CREATE INDEX idx_direcciones_nomsede ON direcciones USING btree (nomsede);

-- Fin de bloque direcciones


-- ************** Boque de unidades de medida
drop table if exists unidadmedida_categorias;
create table unidadmedida_categorias(
id serial primary key,
describe character varying(60)
);
insert into unidadmedida_categorias (id,describe) values (0,'CONTEO');
insert into unidadmedida_categorias (id,describe) values (1,'PESO');
insert into unidadmedida_categorias (id,describe) values (2,'VOLUMEN/CAPACIDAD');
insert into unidadmedida_categorias (id,describe) values (3,'SUPERFICIE');

select setval('unidadmedida_categorias_id_seq',max(id)) from unidadmedida_categorias;
ALTER TABLE unidadmedida_categorias
  OWNER TO stg;

create table unidadmedidas(
id serial primary key,
describe character varying(60),
unidadmedida_categoria_id integer references unidadmedida_categorias match full default 0,
factor numeric default 1 -- indicará el valor por el que hay que multiplicar
);

insert into unidadmedidas(id,describe,factor,unidadmedida_categoria_id) values (0,'UNIDADES',1,0);
insert into unidadmedidas(id,describe,factor,unidadmedida_categoria_id) values (1,'KG',1,1);
insert into unidadmedidas(id,describe,factor,unidadmedida_categoria_id) values (2,'M²',1,3);
insert into unidadmedidas(id,describe,factor,unidadmedida_categoria_id) values (3,'TNM',1000,1);
insert into unidadmedidas(id,describe,factor,unidadmedida_categoria_id) values (4,'L',1,2);
insert into unidadmedidas(id,describe,factor,unidadmedida_categoria_id) values (5,'M³',1000,2);
select setval('unidadmedidas_id_seq',max(id)) from unidadmedidas;
ALTER TABLE unidadmedidas
  OWNER TO stg;

-- Fin del bloque de unidades de medida




-- **************  Bloque de gestión de Horarios

create table horarios_tipos(
id serial primary key,
operativo boolean default true,
restringido boolean default false,
Describe character varying(20), -- valores: Manaña 8:00 a 13:00, horario verano (restringido=true), cerrado vavaciones (operativo=false)
check (not (not operativo and restringido)) --la combinación no operativo y restringida está prohibida
);


create table horarios(
id serial primary key,
horario_tipo_id integer references horarios_tipos(id) match full,
Hini time,
hfin time,
diaini integer default 2, --dia de la semana de comienzo. por defecto 2 (lunes)
diafin integer default 6,  --dia de la semana de comienzo. por defecto 6 (viernes)
fechaini date default null,  --fecha inicial en la que aplica ese horario. 
fechafin date default null   --fecha fin en la que aplica. 
check ((diaini is not null and diafin is not null) or (fechaini is not null and fechafin is not null)) 
);

CREATE INDEX idx_horarios_horariotipo_id ON horarios USING btree (horariotipo_id);
CREATE INDEX idx_horarios_diaini_diafin_fechaini_fechafin ON horarios USING btree (diaini,diafin,Hini,hfin);
CREATE INDEX idx_horarios_diaini_diafin_fechaini_fechafin ON horarios USING btree (fechaini,fechafin,Hini,hfin);
--Para saber si un sitio está abierto o cerrado se usa una búsqueda por horarios de menor antiguedad a mayor antiguedad. Si encaja en uno de esos tramos no se sigue buscando.

/* Consulta de ejemplo de uso de los horarios
select horarios_tipos.operativo as horario_laboral, horarios_tipos.restringido as horario_especial
from (
	select *
	from horarios_tipos inner join horarios on horarios_tipos.id=horarios.horario_tipo_id
	where (current_timestamp between  coalesce(fechaini,current_date) + coalesce(Hini,current_time)  and coalesces(fechafin,current_date) + coalesce(Hfin,current_date) and extract(dow from current_date) between SYMMETRIC coalesce(Hini,extract(dow from current_date)) and coalesce(Hfin,extract(dow from current_date))
) t
order by horarios.id limit 1
*/



create table direcciones_horarios(
id serial primary key,
direccion_id integer references direcciones(id) match full,
horarios_id integer references horarios(id) match full
);
-- Cada dirección puede tener su propio horario de funcionamiento

/* Fin de bloque de gestión de horarios */



/*  ******************* Bloque de gestión de Impuestos */


create table impuestos(
id serial primary key,
valor numeric(5,2) not null default 0, --valor numérico del impuesto (7,21,...)
describe character(15) not null default '', --nombre del impuesto
tipo character(12) not null default 'EXENTO',
impuesto_id integer references impuestos(id) match simple default null, --para el recargo de equivalencia
--esirpf boolean not null default false,
--esexento boolean not null default true,
--esimportacion boolean not null default false,
--vigenciadesde date not null default '2012-08-01'
CONSTRAINT tipo CHECK (TIPO = ANY (ARRAY['EXENTO'::character(12), 'IVA'::character(12), 'IGIC'::character(12), 'IMPORTACION'::character(12),'IRPF'::character(12),'EXPORTACION'::character(12),'RE'::character(12), 'VAT'::character(12)])),
constraint chkre check (impuesto_id is null or (impuesto_id is not null and tipo='RE'::character(12)))
);

insert into impuestos (id,valor,describe,tipo) values (0,0,'0% IGIC EXENTO','EXENTO');
insert into impuestos (id,valor,describe,tipo) values (1,7,'7% IGIC','IGIC');

/* Fin de Impuestos */



/* Bloque de Gestión de Artículos */

create table articulos_lers(
id serial primary key,
codler character varying(25),
peligroso bool,
codman character(50),
describe character varying(400)
);
ALTER TABLE articulos_lers
  OWNER TO stg;

Insert into articulos_lers (codler, describe,codman,peligroso) values ('20104','Residuos plásticos','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('20110','Residuos metálicos','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('30101','Residuos de corteza y corcho','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('030104*','Serrín, virutas, recortes, madera, tableros de partículas y chapas que contienen sustancias peligrosas','Q12/D15/S40/C51/H05/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('30105','Serrín, virutas, recortes, madera, tableros de partículas y chapas distintos de los mencionados en el código 030104 ','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('080111*','Residuos de pintura y barniz que contienen disolventes orgánicos u otras sustancias peligrosas','Q08/R13/P12/C41/H3B/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('080113*','Lodos de pintura y barniz que contienen disolventes orgánicos u otras sustancias peligrosas','Q08/D15/P12/C43/H05/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('080115*','Lodos acuosos que contienen pintura o barniz con disolventes orgánicos u otras sustancias peligrosas','Q08/R13/LP12/C41/H3-B/A936(9)/B0019 ','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('080117*','Residuos de decapado o eliminación de pintura y barniz que contienen disolventes orgánicos u otras sustancias peligrosas','Q08/R13/P12/C41/H3-B/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('80199','Filtros de cabina de pintura ','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('080312*','Residuos de tintas que contienen sustancias peligrosas ','Q07/D15/L12/C43/H05/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('80313','Residuos de tintas distintos de los especificados en el código 080312','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('080314*','Lodos de tinta que contienen sustancias peligrosas ','Q07/D15/L12/C43/H05/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('080317*','Residuos de tóner de impresión que contienen sustancias peligrosas ','Q14/R13/S12/C43/H05/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('80318','Residuos de tóner de impresión distintos de los especificados en el código 080317','','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('080409*','Residuos de adhesivos y sellantes que contienen disolventes orgánicos u otras sustancias peligrosas','Q07/D15/L13/C41/H05/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('090103*','Soluciones de revelado con disolventes','Q07/D15/L12/C43/H05/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('090104*','Soluciones de fijado ','Q07/D15/L40/C43/H06/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('120101','Limaduras y virutas de metales férreos','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('120103','Limaduras y virutas de metales no férreos ','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('120106*','Aceites minerales de mecanizado que contienen halógenos (excepto las emulsiones o disoluciones)','Q07/R13/L08/C40C51/H06/A936(9)/B0019 ','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('120107*','Aceites minerales de mecanizado sin halógenos (excepto las emulsiones o disoluciones)','Q07/R13/L08/C51/H05/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('120108*','Emulsiones y disoluciones de mecanizado que contienen halógenos ','Q07/R13/L08/C40C51/H06/A936(9)/B0019 ','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('120109*','Emulsiones y disoluciones de mecanizado sin halógenos','Q07/D15/L09/C51/H05/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('120110*','Aceites sintéticos de mecanizado','Q07/R13/L08/C51/H05/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('120112*','Ceras y grasas usadas','Q07/D15/P19/C51/H05/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('120114*','Lodos de mecanizado que contienen sustancias peligrosas','Q08/D15/S08/C51/H05/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('120116*','Residuos de granallado o chorreado que contienen sustancias peligrosas (polvo de lijado)','Q08/D15/S25/C51/H05/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('120118*','Lodos metálicos (lodos de esmerilado, rectificado y lapeado) que contienen aceites','Q08/D15/S08/C51/H05/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('120119*','Aceites de mecanizado fácilmente biodegradables','Q07/R13/L08/C51/H05/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('120120*','Muelas y materiales de esmerilado usados que contienen sustancias peligrosas ','Q05/D15/S09/C51C41/H05/A936(9)/B0019 ','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('120121','Muelas y materiales de esmerilado usados distintos de los especificados en el código 12 01 20 ',' ','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('130104*','Emulsiones cloradas','Q07/R13/L08/C40C51/H06/A936(9)/B0019 ','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('130105*','Emulsiones no cloradas ','Q07/D15/L09/C51/H05/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('130109*','Aceites hidráulicos minerales clorados','Q07/R13/L08/C40C51/H06/A936(9)/B0019 ','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('130110*','Aceites hidráulicos minerales no clorados ','Q07/R13/L08/C51/H05/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('130111*','Aceites hidráulicos sintéticos','Q07/R13/L08/C51/H05/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('130112*','Aceites hidráulicos fácilmente biodegradables','Q07/R13/L08/C51/H05/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('130113*','Otros aceites hidráulicos','Q07/R13/L08/C51/H05/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('130204*','Aceites minerales clorados de motor, de transmisión mecánica y lubricantes ','Q07/R13/L08/C40C51/H06/A936(9)/B0019 ','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('130205*','Aceites minerales no clorados de motor, de transmisión mecánica y lubricantes','Q07/R13/L08/C51/H05/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('130206*','Aceites sintéticos de motor, de transmisión mecánica y lubricantes','Q07/R13/L08/C51/H05/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('130207*','Aceites fácilmente biodegradables de motor, de transmisión mecánica y lubricantes','Q07/R13/L08/C51/H05/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('130208*','Otros aceites de motor, de transmisión mecánica y lubricantes ','Q07/R13/L08/C51/H05/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('130501*','Sólidos procedentes de separadores','Q12/D15/S23/C51/H05/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('130502*','Lodos del separador de agua /sustancias aceitosas','Q08/D15/P08/C51/H05/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('130506*','Sólidos procedentes de los desarenadotes y de separadores de aguas/sustancias aceitosas ','Q07/R13/L08/C51/H05/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('130507*','Agua aceitosa procedente de separadores de agua/sustancias aceitosas','Q07/D15/L09/C51/H05/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('130508*','Mezcla de residuos procedentes de desarenadores y de separadores de agua / sustancias aceitosas','Q07/D15/L09/C51/H05/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('130702*','Gasolinas ','Q08/R13/L09/C51/H3B/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('130701*','Gasóleos','Q08/R13/L09/C51/H3A/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('130703*','Otros combustibles (incluidas mezclas)','Q08/R13/L09/C51/H3-A/A936(9)/B0019 ','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('140601*','Clorofluorocarbonos, CFC, HFC (fluidos del sistema de aire acondicionado, gas licuado)','Q07/D15/L05/C40/H06/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('140602*','Disolventes y mezclas de disolventes halogenados ','Q07/R13/L05/C40/H06/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('140603*','Otros disolventes y mezclas de disolventes','Q07/R13/L05/C41/H3-B/A936(9)/B0019 ','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('140604*','Lodos o residuos sólidos que contienen disolventes halogenados','Q07/D15/L05/C40/H06/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('140605*','Lodos o residuos sólidos que contienen otros disolventes','Q07/D15/L40/C43/H06/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('150101','Envases de papel y cartón','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('150102','Envases de plástico','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('150103','Envases de madera','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('150104','Envases metálicos','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('150105','Envases compuestos','     ','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('150106','Envases mezclados','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('150107','Envases de vidrio','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('150109','Envases textiles','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('150110*','Envases plásticos que contienen restos de sustancias peligrosas','Q05/R13/S36/C51C41/H05/A936(9)/B0019 ','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('150111*','Envases metálicos con restos de sustancias peligrosas  ','Q05/R13/S36/C51C41/H05/A936(9)/B0019 ','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('150202*','Absorbentes, materiales de filtración (incluidos los filtros de aceite no especificados en otra categoría), trapos de limpieza y ropas protectoras contaminados por sustancias peligrosas','Q05/D15/S09/C51C41/H05/A936(9)/B0019 ','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('160103','Neumáticos fuera de uso','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('160106','Vehículos al final de su vida útil que no contengan sustancias peligrosas','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('160107*','Filtros de aceite','Q06/R04/S35/C51/H05/A0000935/B9703','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('160108*','Componentes que contengan mercurio  ','Q16/R13/S37/C16/H06/A936(9)/B0019    ','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('160113*','Líquido de frenos','Q14/R13/L40/C43/H05/A936(9)/B0019    ','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('160114*','Líquidos de refrigeración y anticongelante','Q14/R13/L40/C43/H05/A936(9)/B0019    ','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('160117','Metales ferrosos','     ','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('160118','Metales no ferrosos    ','     ','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('160119','Plástico','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('160120','Vidrio','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('160211*','Equipos desechados que contienen clorofluorocarbonos, HCFC, HFC','Q16/D15/S40/C05/H05/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('160213*','Equipos eléctricos y electrónicos desechados que contienen componentes peligrosos (distintos de los especificados en los códigos de 160209* a 160212*)   ','Q16/D15/S40/C06/H05/A936(9)/B0019    ','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('160214','Equipos eléctricos y electrónicos desechados distintos de los especificados en los códigos de 160209* a 160213*)  ','     ','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('160215*','Componentes peligrosos retirados de equipos desechados ','Q16/D15/S40/C06/H05/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('160216','Componentes retirados de equipos desechados, distintos de los especificados en el código 160215*','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('160504*','Gases en recipientes a presión (incluidos los halones) que contienen sustancias peligrosas','Q14/D15/S39/C40/H3-B/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('160506*','Productos químicos de laboratorio que consisten en, o contienen, sustancias peligrosas, incluidas las mezclas de productos químicos de laboratorio','Q03/D15/L40/C23C41/H06/A936(9)/B0019 ','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('160507*','Productos químicos inorgánicos desechados que consisten en, o contienen, sustancias peligrosas','Q03/D15/L40/C23C41/H06/A936(9)/B0019 ','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('160508*','Productos químicos orgánicos desechados que consisten en, o contienen, sustancias peligrosas  ','Q03/D15/L40/C23C41/H06/A936(9)/B0019 ','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('160601*','Baterías de plomo','Q06/R04/S37/C23C18/H06H08/A0000961/B9703','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('160602*','Acumuladores de Ni-Cd  ','Q16/R13/S37/C05C11/H06/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('160603*','Pilas que contienen mercurio (botón)','Q16/R13/S37/C16/H06/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('160604','Pilas alcalinas (excepto las del código 160603*-Hg)','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('160605','Otras pilas y acumuladores   ','     ','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('160708*','Residuos que contienen hidrocarburos','Q07/D15/L09/C51/H05/A936(9)/B0019    ','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('160801','Catalizadores usados que contienen oro, plata, renio, rodio, paladio, iridio o platino (excepto los del código 160807)  ','     ','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('160802*','Catalizadores que contienen metales de transición peligrosos o compuestos de metales de transición peligrosos     ','Q14/D15/S26/C18/H05/A936(9)/B0019    ','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('160803','Catalizadores usados que contienen metales de transición o compuestos de metales de transición no especificados en otra categoría    ','     ','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('170101','Hormigón','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('170102','Ladrillos','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('170103','Tejas y materiales cerámicos ','     ','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('170106*','Mezclas, o fracciones separadas, de hormigón, ladrillos, tejas y materiales cerámicos que contienen sustancias peligrosas','Q12/D15/S23/C51/H05/A936(9)/B0019    ','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('170107','Mezclas, o fracciones separadas, de hormigón, ladrillos, tejas y materiales cerámicos distintas de las especificadas en el código 170106    ','     ','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('170201','Madera','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('170202','Vidrio','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('170203','Plástico','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('170204*','Vidrio, plástico y madera que contienen sustancias peligrosas o están contaminados por ellas  ','Q12/R13/S36/C51/H05/A936(9)/B0019    ','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('170401','Cobre, bronce, latón   ','     ','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('170402','Aluminio','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('170403','Plomo','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('170405','Hierro y acero','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('170406','Estaño','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('170407','Metales mezclados','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('170411','Cables de cobre y cables de aluminio (considerados como metales incluidos en los residuos de la construcción y demolición)     ','     ','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('170503*','Tierra y piedras que contienen sustancias peligrosas   ','Q12/D15/S23/C51/H05/A936(9)/B0019    ','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('170601*','Materiales de aislamiento que contienen amianto  ','Q07/D15/S12/C25/H06/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('170801*','Material de construcción a partir de yeso contaminado con sustancias peligrosas  ','Q12/D15/S23/C51/H05/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('170802','Materiales de construcción a partir de yeso distintos de los especificados en el código 170801','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('170903*','Otros residuos de construcción y demolición (incluidos los residuos mezclados) que contienen sustancias peligrosas','Q12/R15/S23/C51/H05/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('170904','Residuos mezclados de construcción y demolición distintos de los especificados en los códigos 170901, 170902 y 170903','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('190102','Materiales férreos separados de la ceniza de fondo de horno','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('190205*','Lodos de tratamientos físico-químicos que contienen sustancias peligrosas  ','Q09/D15/S27/C24/H05/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('190501','Fracción no comportada de residuos municipales y asimilados. Residuos del tratamiento aeróbico de residuos sólidos.','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('191001','Residuos de hierro y acero','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('191002','Residuos no férreos','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('191202','Metales férreos','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('191203','Metales no férreos','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('200101','Papel y cartón','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('200102','Vidrio','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('200114*','Ácidos','Q07/D15/L27/C23/H08/A936(9)/B0019    ','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('200117*','Productos fotoquímicos ','Q07/D15/L40/C43/H06/A936(9)/B0019    ','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('200121*','Tubos fluorescentes y otros residuos que contienen mercurio   ','Q14/D15/S40/C16/H05/A936(9)/B0019','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('200125','Aceites y grasas comestibles ','     ','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('200133*','Baterías y acumuladores especificados en los códigos 160601, 160602 o 160603 y baterías y acumuladores sin clasificar que contienen esas baterías ','Q06/R13/S37/C18C23/H08/A936(9)/B0019 ','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('200134','Baterías y acumuladores distintos de los especificados en el código 200133 ','     ','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('200135*','Equipos eléctricos y electrónicos desechados, distintos de los especificados en los códigos 200121 y 200123, que contienen componentes peligrosos ','Q16/D15/S40/C06/H05/A936(9)/B0019    ','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('200136','Equipos eléctricos y electrónicos desechados distintos de los especificados en los códigos 200121, 200123 y 200135','     ','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('200137*','Madera que contiene sustancias peligrosas ','Q12/D15/S40/C51/H05/A936(9)/B0019    ','t');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('200138','Madera distinta de la especificada en el código 200137 ','     ','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('200139','Plásticos','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('200140','Metales','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('200201','Residuos biodegradables de parques y jardines    ','     ','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('200301','Mezcla de residuos municipales','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('200307','Residuos voluminosos','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('0','NO ES UN RESIDUO. NO DEBE DE ESTAR EN STOCK','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('160199','Residuos no especificados en otra categoria (Esteriles de rechazo)  ','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('160118','Metales no ferrosos','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('160601','Baterias de plomo','','f');
Insert into articulos_lers (codler, describe,codman,peligroso) values ('170404','Zinc','','f');



--Familias id,idpadre default null,familia,componernombre boolean,tieneSN)

create table propiedades_componer(
id serial primary key,
describe character varying(25),
aplicafamilia boolean default false
);
ALTER TABLE propiedades_componer
  OWNER TO stg;

insert into propiedades_componer (id,describe,aplicafamilia) values (1,'ninguno',true);
insert into propiedades_componer (id,describe,aplicafamilia) values (2,'cod',true);
insert into propiedades_componer (id,describe,aplicafamilia) values (3,'propiedad',false);
insert into propiedades_componer (id,describe,aplicafamilia) values (4,'valor',true);
insert into propiedades_componer (id,describe,aplicafamilia) values (5,'cod + propiedad',false);
insert into propiedades_componer (id,describe,aplicafamilia) values (6,'cod + valor',true);
insert into propiedades_componer (id,describe,aplicafamilia) values (7,'cod + propiedad + valor',false);
insert into propiedades_componer (id,describe,aplicafamilia) values (8,'propiedad + valor',false);
select setval('propiedades_componer_id_seq',max(id)) from propiedades_componer;


create table familias(
id serial primary key,
padre_id integer default null references familias(id) match simple,
codfamilia character varying(5) not null default '',
describe character varying(100) not null,
componer_id integer not null references propiedades_componer(id) match full default 1,
propia boolean default true,
competencia boolean default false,
orden serial
);

ALTER TABLE familias
  OWNER TO stg;


insert into familias (id,padre_id,codfamilia,describe,componer_id) values (1,null,'00001','Colchón',6);
insert into familias (id,padre_id,codfamilia,describe,componer_id) values (2,null,'00002','Base',6);
insert into familias (id,padre_id,codfamilia,describe,componer_id) values (3,null,'00003','Complementos',1);
insert into familias (id,padre_id,codfamilia,describe,componer_id) values (4,null,'00004','Textil',1);
insert into familias (id,padre_id,codfamilia,describe,componer_id) values (7,null,'00007','Repuestos',1);
insert into familias (id,padre_id,codfamilia,describe,componer_id) values (8,null,'00008','Marketing',1);
insert into familias (id,padre_id,codfamilia,describe,componer_id) values (9,null,'00009','Servicios',1);

insert into familias (id,padre_id,codfamilia,describe,componer_id) values (11,1,'00011','Colchón muelles',1);
insert into familias (id,padre_id,codfamilia,describe,componer_id) values (12,1,'00012','Colchón no muelles',1);

insert into familias (id,padre_id,codfamilia,describe,componer_id) values (13,11,'00013','Muelle semicilíndrico',1);
insert into familias (id,padre_id,codfamilia,describe,componer_id) values (14,11,'00014','Muelle cilíndrico',1);
insert into familias (id,padre_id,codfamilia,describe,componer_id) values (15,11,'00015','Muelle compactado',1);
insert into familias (id,padre_id,codfamilia,describe,componer_id) values (16,11,'00015','Muelle Ensacado',1);

insert into familias (id,padre_id,codfamilia,describe,componer_id) values (17,12,'00016','Espuma 1 capa',4);
insert into familias (id,padre_id,codfamilia,describe,componer_id) values (18,12,'00017','Espuma 2 capas',4);
insert into familias (id,padre_id,codfamilia,describe,componer_id) values (19,12,'00018','Espuma 3 capas',4);


insert into familias (id,padre_id,codfamilia,describe,componer_id) values (21,2,'00021','Tapis',1);
insert into familias (id,padre_id,codfamilia,describe,componer_id) values (22,2,'00022','Canapés',1);
insert into familias (id,padre_id,codfamilia,describe,componer_id) values (23,2,'00023','Arcones',1);
insert into familias (id,padre_id,codfamilia,describe,componer_id) values (24,2,'00024','Mixtos',1);
insert into familias (id,padre_id,codfamilia,describe,componer_id) values (25,2,'00025','Box Springs',1);
insert into familias (id,padre_id,codfamilia,describe,componer_id) values (26,2,'00026','Nidos',1);
insert into familias (id,padre_id,codfamilia,describe,componer_id) values (27,2,'00027','Camas Eléctricas',1);

insert into familias (id,padre_id,codfamilia,describe,componer_id) values (31,3,'00031','Acabados',1);
insert into familias (id,padre_id,codfamilia,describe,componer_id) values (32,3,'00032','Cabeceros',1);
insert into familias (id,padre_id,codfamilia,describe,componer_id) values (33,3,'00033','Patas',1);
insert into familias (id,padre_id,codfamilia,describe,componer_id) values (34,3,'00034','Almohadas',1);
insert into familias (id,padre_id,codfamilia,describe,componer_id) values (35,3,'00035','Topper',1);

insert into familias (id,padre_id,codfamilia,describe,componer_id) values (81,8,'00081','Catálogos',4);
insert into familias (id,padre_id,codfamilia,describe,componer_id) values (82,8,'00082','Tarifas',4);
insert into familias (id,padre_id,codfamilia,describe,componer_id) values (83,8,'00083','Muestrarios',4);
insert into familias (id,padre_id,codfamilia,describe,componer_id) values (84,8,'00084','PLV',4);

insert into familias (id,padre_id,codfamilia,describe,componer_id) values (91,9,'00091','Visita comercial',4);
insert into familias (id,padre_id,codfamilia,describe,componer_id) values (92,9,'00092','Comisión',4);
insert into familias (id,padre_id,codfamilia,describe,componer_id) values (93,9,'00093','Transporte',4);
insert into familias (id,padre_id,codfamilia,describe,componer_id) values (94,9,'00094','Distribución',4);
insert into familias (id,padre_id,codfamilia,describe,componer_id) values (95,9,'00095','Montaje',4);
insert into familias (id,padre_id,codfamilia,describe,componer_id) values (96,9,'00096','Incidencias',4);
insert into familias (id,padre_id,codfamilia,describe,componer_id) values (97,9,'00097','Vertedero',4);
insert into familias (id,padre_id,codfamilia,describe,componer_id) values (98,9,'00098','Asistencia técnica',4);

select setval('familias_id_seq',max(id)) from familias;
CREATE INDEX idx_familias_padre_id ON familias USING btree (padre_id);
CREATE INDEX idx_familias_describe ON familias USING btree (describe);






--Propiedades que pueden tener los artículos, aunque en realidad van vinculadas a los grupos en las familias
create table propiedades(
id serial primary key,
codpropiedad character varying(5) not null default '',
tcorto character varying(60),
tlargo character varying(100),
tcomercial character varying(100),
propnumerica boolean default false,
componertcorto_id integer references propiedades_componer(id)  match full default 1, 
componertlargo_id integer references propiedades_componer(id) match full default 1 , 
componertcomercial_id integer references propiedades_componer(id) match full default 1                      
);
CREATE INDEX idx_propiedades_codpropiedad ON propiedades USING btree (codpropiedad);
CREATE INDEX idx_propiedades_tcorto ON propiedades USING btree (tcorto);
ALTER TABLE propiedades
  OWNER TO stg;



insert into propiedades (id,tlargo,propnumerica,componertlargo_id) values (1,'Dimensiones -> Producto -> Largo',true,1);
insert into propiedades (id,tlargo,propnumerica,componertlargo_id) values (2,'Dimensiones -> Producto -> Ancho',true,1);
insert into propiedades (id,tlargo,propnumerica,componertlargo_id) values (3,'Dimensiones -> Producto -> Alto',true,1);
insert into propiedades (id,tlargo,propnumerica,componertlargo_id) values (4,'Dimensiones -> Embalaje -> Largo',true,1);
insert into propiedades (id,tlargo,propnumerica,componertlargo_id) values (5,'Dimensiones -> Embalaje -> Ancho',true,1);
insert into propiedades (id,tlargo,propnumerica,componertlargo_id) values (6,'Dimensiones -> Embalaje -> Alto',true,1);
insert into propiedades (id,tlargo,propnumerica,componertlargo_id) values (7,'Dimensiones -> Transporte -> Largo',true,1);
insert into propiedades (id,tlargo,propnumerica,componertlargo_id) values (8,'Dimensiones -> Transporte -> Ancho',true,1);
insert into propiedades (id,tlargo,propnumerica,componertlargo_id) values (9,'Dimensiones -> Transporte -> Alto',true,1);
insert into propiedades (id,tlargo,propnumerica,componertlargo_id) values (10,'Dimensiones -> Medida -> Corta',false,6);
insert into propiedades (id,tlargo,propnumerica,componertlargo_id) values (11,'Dimensiones -> Medida -> Larga',false,6);
insert into propiedades (id,tlargo,propnumerica,componertlargo_id) values (12,'Dimensiones -> Talla',false,1);
insert into propiedades (id,tlargo,propnumerica,componertlargo_id) values (13,'Masa -> Producto',true,1);
insert into propiedades (id,tlargo,propnumerica,componertlargo_id) values (14,'Masa -> Embalaje',true,1);
insert into propiedades (id,tlargo,propnumerica,componertlargo_id) values (15,'Masa -> Transporte',true,1);
insert into propiedades (id,tlargo,propnumerica,componertlargo_id) values (16,'Volumen -> Producto',true,1);
insert into propiedades (id,tlargo,propnumerica,componertlargo_id) values (17,'Volumen -> Embalaje',true,1);
insert into propiedades (id,tlargo,propnumerica,componertlargo_id) values (18,'Volumen -> Transporte',true,1);

insert into propiedades (id,tlargo,propnumerica,componertlargo_id) values (19,'Colchones -> Fabricación',false,6); --Gemelar, normal, Especial
insert into propiedades (id,tlargo,propnumerica,componertlargo_id) values (20,'Colchones -> Acabado especial',false,6);
insert into propiedades (id,tlargo,propnumerica,componertlargo_id) values (21,'Colchones -> Acabado tapicería',false,6);
insert into propiedades  (id,tlargo,propnumerica,componertlargo_id) values (22,'Colchones -> Acabado madera',false,6);
insert into propiedades  (id,tlargo,propnumerica,componertlargo_id) values (23,'Modelo',false,6);

update propiedades set tcorto=tlargo,tcomercial=tlargo,componertcorto_id=componertlargo_id,componertcomercial_id=componertlargo_id;
select setval('propiedades_id_seq',max(id)) from propiedades;



drop table if exists familias_propiedades;
create table familias_propiedades(
id integer primary key default nextval('familias_id_seq'),
cod character(10) default '',
familia_id integer references familias(id) match full,
propiedad_id integer references propiedades(id) match full,
valor character varying(200),
orden integer default nextval('familias_orden_seq'), --se estable el orden de la familia por defecto
unique (familia_id,propiedad_id,valor)
);
ALTER TABLE familias_propiedades
  OWNER TO stg;




insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (1,currval('familias_id_seq'),1,'182');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (1,currval('familias_id_seq'),1,'190');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (1,currval('familias_id_seq'),1,'200');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (1,currval('familias_id_seq'),1,'210');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (1,currval('familias_id_seq'),1,'220');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (2,currval('familias_id_seq'),1,'80');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (2,currval('familias_id_seq'),1,'90');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (2,currval('familias_id_seq'),1,'100');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (2,currval('familias_id_seq'),1,'105');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (2,currval('familias_id_seq'),1,'120');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (2,currval('familias_id_seq'),1,'135');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (2,currval('familias_id_seq'),1,'140');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (2,currval('familias_id_seq'),1,'150');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (2,currval('familias_id_seq'),1,'160');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (2,currval('familias_id_seq'),1,'180');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (2,currval('familias_id_seq'),1,'200');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,' 80 x 182');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,' 90 x 182');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,'100 x 182');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,'105 x 182');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,'120 x 182');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,'135 x 182');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,'140 x 182');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,'150 x 182');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,'160 x 182');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,'180 x 182');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,'200 x 182');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,' 80 x 190');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,' 90 x 190');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,'100 x 190');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,'105 x 190');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,'120 x 190');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,'135 x 190');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,'140 x 190');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,'150 x 190');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,'160 x 190');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,'180 x 190');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,'200 x 190');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,' 80 x 200');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,' 90 x 200');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,'100 x 200');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,'105 x 200');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,'120 x 200');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,'135 x 200');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,'140 x 200');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,'150 x 200');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,'160 x 200');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,'180 x 200');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,'200 x 200');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,' 80 x 210');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,' 90 x 210');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,'100 x 210');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,'105 x 210');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,'120 x 210');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,'135 x 210');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,'140 x 210');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,'150 x 210');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,'160 x 210');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,'180 x 210');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,'200 x 210');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,' 80 x 220');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,' 90 x 220');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,'100 x 220');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,'105 x 220');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,'120 x 220');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,'135 x 220');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,'140 x 220');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,'150 x 220');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,'160 x 220');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,'180 x 220');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,'200 x 220');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (10,currval('familias_id_seq'),1,'Especial');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (23,currval('familias_id_seq'),16,'Iria'); --muelle ensacado
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (23,currval('familias_id_seq'),16,'Colliseum');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (23,currval('familias_id_seq'),17,'Canarias');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (23,currval('familias_id_seq'),17,'Canarias2');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (23,currval('familias_id_seq'),16,'Cies');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (23,currval('familias_id_seq'),15,'Tambre');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (23,currval('familias_id_seq'),13,'Alfa');
insert into familias_propiedades(propiedad_id,cod,familia_id,valor) values (23,currval('familias_id_seq'),14,'Granada');


CREATE INDEX idx_familias_propiedades_familia_id ON familias_propiedades USING btree (familia_id);
CREATE INDEX idx_familias_propiedades_propiedad_id ON familias_propiedades USING btree (propiedad_id);

--select * from familias_propiedades where id between  (61 +98) and (69 + 98)
--select fp.id-98,fp2.id-98,fp.valor,fp2.valor
--from familias_valoresligados l inner join familias_propiedades fp on l.fp_id=fp.id
--inner join familias_propiedades fp2 on l.fp2_id=fp2.id;



drop table if exists familias_valoresligados;
create table familias_valoresligados( -- 
id serial primary key,
fp_id integer references familias_propiedades(id) match full on update cascade on delete cascade not null,
fp2_id integer references familias_propiedades(id) match full on update cascade on delete cascade not null,
unique (fp_id,fp2_id)
); --Se suma el valor del id de la última familia creada último 
insert into familias_valoresligados (fp_id,fp2_id) values (1 + 98,17 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (1 + 98,18 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (1 + 98,19 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (1 + 98,20 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (1 + 98,21 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (1 + 98,22 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (1 + 98,23 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (1 + 98,24 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (1 + 98,25 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (1 + 98,26 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (1 + 98,27 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (2 + 98,28 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (2 + 98,29 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (2 + 98,30 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (2 + 98,31 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (2 + 98,32 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (2 + 98,33 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (2 + 98,34 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (2 + 98,35 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (2 + 98,36 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (2 + 98,37 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (2 + 98,38 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (3 + 98,39 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (3 + 98,40 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (3 + 98,41 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (3 + 98,42 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (3 + 98,43 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (3 + 98,44 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (3 + 98,45 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (3 + 98,46 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (3 + 98,47 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (3 + 98,48 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (3 + 98,49 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (4 + 98,50 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (4 + 98,51 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (4 + 98,52 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (4 + 98,53 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (4 + 98,54 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (4 + 98,55 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (4 + 98,56 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (4 + 98,57 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (4 + 98,58 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (4 + 98,59 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (4 + 98,60 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (5 + 98,61 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (5 + 98,62 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (5 + 98,63 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (5 + 98,64 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (5 + 98,65 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (5 + 98,66 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (5 + 98,67 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (5 + 98,68 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (5 + 98,69 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (5 + 98,70 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (5 + 98,71 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (6 + 98,17 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (6 + 98,28 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (6 + 98,39 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (6 + 98,50 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (6 + 98,61 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (7 + 98,18 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (7 + 98,29 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (7 + 98,40 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (7 + 98,51 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (7 + 98,62 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (8 + 98,19 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (8 + 98,30 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (8 + 98,41 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (8 + 98,52 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (8 + 98,63 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (9 + 98,20 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (9 + 98,31 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (9 + 98,42 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (9 + 98,53 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (9 + 98,64 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (10 + 98,21 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (10 + 98,32 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (10 + 98,43 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (10 + 98,54 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (10 + 98,65 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (11 + 98,22 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (11 + 98,33 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (11 + 98,44 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (11 + 98,55 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (11 + 98,66 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (12 + 98,23 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (12 + 98,34 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (12 + 98,45 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (12 + 98,56 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (12 +98 ,67 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (13 + 98,24 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (13 + 98,35 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (13 + 98,46 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (13 + 98,57 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (13 + 98,68 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (14 + 98,25 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (14 + 98,36 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (14 + 98,47 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (14 + 98,58 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (14 + 98,69 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (15 + 98,26 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (15 + 98,37 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (15 + 98,48 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (15 + 98,59 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (15 + 98,70 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (16 + 98,27 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (16 + 98,38 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (16 + 98,49 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (16 + 98,60 + 98);
insert into familias_valoresligados (fp_id,fp2_id) values (16 + 98,71 + 98);



CREATE INDEX idx_familias_valoresligados_fp_id_id ON familias_valoresligados USING btree (fp_id);
CREATE INDEX idx_familias_valoresligados_fp2_id	ON familias_valoresligados USING btree (fp2_id);

ALTER TABLE familias_valoresligados
  OWNER TO stg;


create table articulos( --al crear cada artículo crear tantos propiedades_valores como haya definido en su subfamilia
id serial primary key,
familia_id integer references familias(id),
unidadmedida_id integer not  null default 0 references unidadmedidas match full on update cascade,
bultos integer default 1 check(case when ctrlstk then bultos>0 end ),
codarticulo character(15) not null,
nomcorto text not null default '', --Se conforma automaticamente al seleccionar familia y propiedades
nomlargo text not null default '', --Se conforma automaticamente al seleccionar familia y propiedades
nomcomercial text not null default '', --Se conforma automaticamente al seleccionar familia y propiedades
--precio numeric(15,2) not null default 0, --este es el precio de venta (es definido sobre el grupo de venta)
ctrlstk boolean not null default true,
aplicacaducidad boolean not null default false,
unidadmedida_categoria_id integer references unidadmedida_categorias(id) match full default 0,
--aplicaestado boolean not null default false,
--aplicatipomov boolean not null default false,
aplicalote boolean not null default false,
permitestknegativo boolean not null default false,
ler_id integer references articulos_lers(id) match simple,
impuesto_compra_id integer references impuestos(id) match full default 1,
impuesto_venta_id integer references impuestos(id) match full default 1,
codbarra character(15),
ts_fechaalta timestamp default now(),
ts_fechabaja timestamp default null
--unique (codarticulo),
--unique (nomlargo)
);

-- Utilidades de los artículos:
-- Cambiar de familia=>cambiar automáticamente el nombre. Ha de preguntarse al usuario en base al rango de valores
-- posible de las propiedades de la familia de destino, cual es la que se elige para dar nombre a dicho artículo. 

CREATE INDEX idx_articulos_familia_id ON articulos USING btree (familia_id);
CREATE INDEX idx_articulos_nomcomercial ON articulos USING btree (nomcomercial);
CREATE INDEX idx_articulos_unidadmedida_id ON articulos USING btree (unidadmedida_id);
CREATE INDEX idx_articulos_codbarra ON articulos USING btree (codbarra);

ALTER TABLE articulos
  OWNER TO stg;
--delete from articulos
/*
drop table if exists articulos_grupopropiedades;
create table articulos_grupopropiedades(
id serial primary key, --identificador de grupo
familia_id integer references familias(id) match full on update cascade on delete cascade,
valido boolean default true
);
ALTER TABLE articulos_grupopropiedades
  OWNER TO stg;
*/

drop table if exists articulos_propiedades;
create table articulos_propiedades(
id integer default nextval('familias_id_seq') primary key, --misma secuencia de numeración que las familias
grupo_id integer references articulos(id) match full on delete cascade,
fp_id integer references familias_propiedades(id) match full on delete cascade on update cascade,
orden serial
);
ALTER TABLE articulos_propiedades
  OWNER TO stg;


CREATE INDEX idx_articulos_propiedades_grupo_id_id ON articulos_propiedades USING btree (grupo_id);
CREATE INDEX idx_articulos_propiedades_fp_id	ON articulos_propiedades USING btree (fp_id);







--Tarifas de venta, y asociación de los artículos que puede manejar cada grupo de cliente
create table articulos_gruposventas(
id serial primary key,
grupoventa_id integer references gruposventas(id) match full on update cascade on delete cascade,
familias_id integer references familias(id) match simple on update cascade on delete cascade,
propiedad_grupo_id integer references propiedades_grupos(id) match simple on update cascade on delete cascade,
articulo_id integer references articulos(id) match simple on update cascade on delete cascade,
precio numeric default 0,
dto numeric default 0,
refcliente character varying(50)
CHECK (propiedad_grupo_id is not null or familias_id is not null or articulo_id is not null), --alguno de los vínculos a la familia,grupo, o artículo ha de ser no nulo
check ((precio>0 and dto=0) or (dto between 0 and 100 and precio=0) --solo uno de los dos valores económicos ha de ser >0 a la vez
);

create index idx_articulos_gruposventas_grupoventa_id on articulos_gruposventas using (grupo_venta_id);
create index idx_articulos_series_articulo_id on articulos_series using (articulo_id);
create index idx_articulos_series_refcliente on articulos_series using (refcliente);





--Lista de funciones a desarrollar
/* Esta función está obsoleta...
CREATE FUNCTION articulos_nombre(int,boolean) RETURNS text
    LANGUAGE plpgsql
    AS $$
--Devuelve el "codarticulo|nombre del artículo" en base a la recursvidad de la familia a la que pertenece    
    
declare
p_idfamilia alias for $1;
p_resumido alias for $2;
p_id integer;
p_nombre text;
p_codarticulo text;
p_totnombre text;
p_totcodarticulo text;
p_idbusqueda integer;
begin
   p_totcodarticulo:='';
   p_totnombre:='';
   p_idbusqueda:=p_idfamilia;
   
   loop
   		select coalesce(f4.id,0) as id4 into p_id,
   			trim(coalesce(case when f4.componernombre or not p_resumido then f4.describe else '' end,'')||' '||coalesce(case when f3.componernombre or not p_resumido then f4.describe else '' end,'')||' '||
   			coalesce(case when f2.componernombre or not p_resumido then f4.describe else '' end,'')||' '||coalesce(case when f4.componernombre or not p_resumido then f1.describe else '' end,'')) as nomarticulo into p_nombre,
   			trim(coalesce(f4.codfamilia,'')||coalesce(f3.codfamilia,'')||coalesce(f2.codfamilia,'')||coalesce(f1.codfamilia,'')) as codarticulo into p_codarticulo,
   		from familias f1 left join familias f2 on f1.padre_id=f2.id left join familias f3 on f2.padre_id=f3.id left join familias f4 on f3.padre_id=f4.id
   		where f1.id=p_idbusqueda;
   		if found then
   		   p_totcodarticulo:=p_codarticulo||p_totcodarticulo;
   		   p_totnombre:=trim(p_nombre||' '||p_totnombre);
   		   if (p_id=0) then -- no hay que continuar iterando
   		     exit;
     		 else  --no hemos llegado al nodo raiz
     		    p_idbusqueda:=p_id;
     		 end if;
     	else
     	  exit;
   		end if;
   end loop;
   return p_totcodarticulo||'|'||p_totnombre;
end;
$$;

--Esta función se puede repalntear usando consultas recursivas
CREATE FUNCTION articulos_descendencia(int) RETURNS text
    LANGUAGE plpgsql
    AS $$
--Devuelve una lista de id de familias separados por comas, las cuales son descendientes del id pasado por parámetro
declare
p_idfamilia alias for $1;
p_idsfamilias text;
p_idbusqueda text
qry record;
begin
   p_idsfamilas=p_idfamilia::text;
   loop
     cSql :='SELECT coalesce(f4.id,0) as id4 ,coalesce(f3.id,0) as id3,coalesce(f2.id,0) as id2, coalesce(f1.id,0) as id4 ';
     cSql :=cSql||'from familias f1 left join familias f2 on f1.id=f2.padre_id left join familias f3 on f2.id=f3.padre_id left join familias f4 on f3.id=f4.padre_id ';
     cSql :=cSql||'where familias.id in ('||p_idsfamilias||');';
     Execute cSql into qry;
     if found then
        p_idsfamilias:=p_idsfamilias||case when qry.id4<>0 then ','||qry.id4::text when qry.id3<>0 then ','||qry.id3::text when qry.id2<>0 then ','||qry.id2::text when qry.id1<>0 then ','||qry.id1::text end;
        if qry.id4=0 then
          exit;
        end if;
     else
       return p_idsfamilas;
     end if;
   end loop;
   return p_idsfamilas;
end;
$$;
--articulos_descendencia(in idfamilia,out idarticulo, out codarticulo, out nombre) -- devuelve un conjunto de registros de artículos
--articulos_busqueda(texto,out idarticulo) --devuelve un conjunto de registros

/*
DROP TABLE IF EXISTS direccionestipos; --tipos de direcciones (de facturación (fiscal), de entrega (de envío), dirección de sucursal
create table direccionestipos(
id serial primary key,
describe character varying(50),
constraint direccionestipos_id_pkey PRIMARY KEY (id)
);
insert into direccionestipos (id,describe) values (0,'FISCAL');
insert into direccionestipos (id,describe) values (1,'ENVÍO');
insert into direccionestipos (id,describe) values (2,'SUCURSAL/DELEGACION');
*/

--direcciones múltiples por entidad. nombre de sucursal, pais,comunidad, provincia,localidad,...


/* **************  Módulo de Formas de pago */


create table cash_tipofpagos( --tipos de formas de pagos
id serial primary key,
describe character varying(50) not null --Contado','aplazado', 'Transferencia'...
);


-- conforme a esta tabla, cada vez que se cree un registro en documentos con control de caja, se insertará un vencimiento concreto en cash.
create table cash_tipofpagos_lineas( --tipos de formas de pagos
id serial primary key,
tipofpago_id integer references cash_tippofpagos(id) match full,
dias integer default 0,
meses integer default 0,
anios integer default 0
);


/* Fin del módulo de formas de pago */




/* **************  Módulo de Gestión de documentos*/


create table documentos_tipos(
id serial primary key,
describe character varying(50) not null, --Facturas de venta','facturas de compra'...
iniciales character(2) not null,
esconsulta bool default false --si es true, indica que no es un documento, sino una consulta de la que pueden chupar  las líneas del documento
);

insert into documentos_tipos (id,describe,iniciales) values (1,'PEDIDO DE NECESIDADES','PN');
insert into documentos_tipos (id,describe,iniciales) values (2,'PEDIDO DE DEPOSITO','PD');
insert into documentos_tipos (id,describe,iniciales) values (3,'ALBARAN DE DEPÓSITO','AD');
insert into documentos_tipos (id,describe,iniciales) values (4,'OFERTAS DE COMPRA','OC');
insert into documentos_tipos (id,describe,iniciales) values (5,'PEDIDOS DE COMPRA','PC');
insert into documentos_tipos (id,describe,iniciales) values (6,'ALBARAN DE COMPRA','AC');
insert into documentos_tipos (id,describe,iniciales) values (7,'PROFORMA DE COMPRA','RC');
insert into documentos_tipos (id,describe,iniciales) values (8,'FACTURA DE COMPRA','FC');
insert into documentos_tipos (id,describe,iniciales) values (9,'OFERTAS DE VENTA','OV');
insert into documentos_tipos (id,describe,iniciales) values (10,'PEDIDOS DE VENTA','PV');
insert into documentos_tipos (id,describe,iniciales) values (11,'ALBARAN DE VENTA','AV');
insert into documentos_tipos (id,describe,iniciales) values (12,'PROFORMA DE VENTA','RV');
insert into documentos_tipos (id,describe,iniciales) values (13,'FACTURA DE VENTA','FV');
insert into documentos_tipos (id,describe,iniciales) values (14,'FACTURA RECTIFICATIVA DE VENTA','FR');
insert into documentos_tipos (id,describe,iniciales) values (15,'PEDIDO INTERCAMBIO','PI');
insert into documentos_tipos (id,describe,iniciales) values (16,'FACTURA DE GASTO','FG');
insert into documentos_tipos (id,describe,iniciales) values (17,'INTERCAMBIO DE ALMACENES','IA'); -- los almacenes de las líneas deben de ser de la misma entidad. 

insert into documentos_tipos (id,describe,iniciales,esconsulta) values (18,'CONSULTA GESTION DEL CATALOGO','GC',true); -- consulta de artículos presentes en el stock de un determinado almacén
insert into documentos_tipos (id,describe,iniciales,esconsulta) values (19,'CONSULTA PEDIDOS DE VENTA NO VINCULADOS','CV',true); -- Consulta de los pedidos de venta que no están en trámite, y que no hay stock disponible
insert into documentos_tipos (id,describe,iniciales) values (20,'INCIDENCIA EN ENVIO','IE');


select setval('documentos_tipos_id_seq',max(id)) from documentos_tipos;

drop table if exists documentos_controles;
create table documentos_controles(
id serial primary key,
describestk character(15) default 'SIN_STK',
describecaja character(15) default 'SIN_CAJA'
);

insert into documentos_controles(id,describstk,describecaja) values (1,'SIN_STK','SIN_CAJA');
insert into documentos_controles(id,describstk,describecaja) values (2,'SIN_STK','CAJA_INF');
insert into documentos_controles(id,describstk,describecaja) values (3,'SIN_STK','CAJA_IN');
insert into documentos_controles(id,describstk,describecaja) values (4,'SIN_STK','CAJA_OU');
insert into documentos_controles(id,describstk,describecaja) values (5,'STK','SIN_CAJA');
insert into documentos_controles(id,describstk,describecaja) values (6,'STK','CAJA_INF');
insert into documentos_controles(id,describstk,describecaja) values (7,'STK','CAJA_IN');
insert into documentos_controles(id,describstk,describecaja) values (8,'STK','CAJA_OU');
insert into documentos_controles(id,describstk,describecaja) values (9,'STK_INV','SIN_CAJA');
insert into documentos_controles(id,describstk,describecaja) values (10,'STK_INV','CAJA_INF');
insert into documentos_controles(id,describstk,describecaja) values (11,'STK_INV','CAJA_IN');
insert into documentos_controles(id,describstk,describecaja) values (12,'STK_INV','CAJA_OU');
insert into documentos_controles(id,describstk,describecaja) values (13,'STK_PDTE_IN','SIN_CAJA');
insert into documentos_controles(id,describstk,describecaja) values (14,'STK_PDTE_IN','CAJA_INF');
insert into documentos_controles(id,describstk,describecaja) values (15,'STK_PDTE_IN','CAJA_IN');
insert into documentos_controles(id,describstk,describecaja) values (16,'STK_PDTE_IN','CAJA_OU');
insert into documentos_controles(id,describstk,describecaja) values (17,'STK_PDTE_INV_IN','SIN_CAJA');
insert into documentos_controles(id,describstk,describecaja) values (18,'STK_PDTE_INV_IN','CAJA_INF');
insert into documentos_controles(id,describstk,describecaja) values (19,'STK_PDTE_INV_IN','CAJA_IN');
insert into documentos_controles(id,describstk,describecaja) values (20,'STK_PDTE_INV_IN','CAJA_OU');
insert into documentos_controles(id,describstk,describecaja) values (21,'STK_PDTE_OU','SIN_CAJA');
insert into documentos_controles(id,describstk,describecaja) values (22,'STK_PDTE_OU','CAJA_INF');
insert into documentos_controles(id,describstk,describecaja) values (23,'STK_PDTE_OU','CAJA_IN');
insert into documentos_controles(id,describstk,describecaja) values (24,'STK_PDTE_OU','CAJA_OU');
insert into documentos_controles(id,describstk,describecaja) values (25,'STK_PDTE_INV_OU','SIN_CAJA');
insert into documentos_controles(id,describstk,describecaja) values (26,'STK_PDTE_INV_OU','CAJA_INF');
insert into documentos_controles(id,describstk,describecaja) values (27,'STK_PDTE_INV_OU','CAJA_IN');
insert into documentos_controles(id,describstk,describecaja) values (28,'STK_PDTE_INV_OU','CAJA_OU');
select setval('documentos_controles_id_seq',max(id)) from documentos_controles;


create table documentos_trazabilidades(
id serial primary key,
documentoorigen_id integer not null references tiposdocumentos(id) match full,
documentodestino_id integer not null references tiposdocumentos(id) match full,
oporigen_id integer not null dreferences documentos_controles(id) match full default 1,
opdestino_id integer not null references documentos_controles(id) match full default 1,
aplicaralineas boolean default true
);

comment on table documentos_trazabilidades is 
'Almacena de donde puede provenir las líneas del dcoumento. Un documento destino (por ejemplo factura de compra),
 estará apuntando a un documento de origen (por ejemplo albarán de entrada). Esto significa que la vinculación de líneas de documentos con su padre_id,
 debe de estar contemplada en esta tabla. oporigen_id y opdestino_id indican lo que hacer en el stock del documento origen y destino
';



-- Las líneas de cada de documento se generan casandose con:
insert into documentos_trazabilidades (documentoorigen_id,documentodestino_id,oporigen_id,opdestino_id) values (1,2,1,13);   -- Las de Pedido de Depósito con Pedido de Necesidad 
insert into documentos_trazabilidades (documentoorigen_id,documentodestino_id,oporigen_id,opdestino_id) values (2,3,17,5);   -- Las de Albarán de depósito con Pedido de Deposito
insert into documentos_trazabilidades (documentoorigen_id,documentodestino_id,oporigen_id,opdestino_id) values (4,5,1,13);   -- Las de Pedidos de compra con Ofertas de compra 
insert into documentos_trazabilidades (documentoorigen_id,documentodestino_id,oporigen_id,opdestino_id) values (10,5,1,13);  -- Las de Pedidos de compra con Ofertas de venta
insert into documentos_trazabilidades (documentoorigen_id,documentodestino_id,oporigen_id,opdestino_id) values (5,6,17,5);   -- Las de albarán de compra con Pedidos de compra
insert into documentos_trazabilidades (documentoorigen_id,documentodestino_id,oporigen_id,opdestino_id) values (6,7,1,2);    -- Las de Proforma de compra con albárn de compra
insert into documentos_trazabilidades (documentoorigen_id,documentodestino_id,oporigen_id,opdestino_id) values (6,8,1,4);    -- Las de Factura de compra con Albarán de compra
insert into documentos_trazabilidades (documentoorigen_id,documentodestino_id,oporigen_id,opdestino_id) values (9,10,1,22);  -- Las de Pedido de venta con Oferta de venta
insert into documentos_trazabilidades (documentoorigen_id,documentodestino_id,oporigen_id,opdestino_id) values (10,11,25,9); -- Las de Albarán de venta con Pedido de venta
insert into documentos_trazabilidades (documentoorigen_id,documentodestino_id,oporigen_id,opdestino_id) values (11,12,1,2);  -- Las de Proforma de venta con  Albarán de venta
insert into documentos_trazabilidades (documentoorigen_id,documentodestino_id,oporigen_id,opdestino_id) values (11,13,1,3);  -- Las de factura de venta con albarán de venta
insert into documentos_trazabilidades (documentoorigen_id,documentodestino_id,oporigen_id,opdestino_id) values (13,14,1,3);  -- Las de factura de rectificativa con factura de venta
insert into documentos_trazabilidades (documentoorigen_id,documentodestino_id,oporigen_id,opdestino_id) values (14,13,1,3);  -- Las de factura de venta con factura rectificativa
insert into documentos_trazabilidades (documentoorigen_id,documentodestino_id,oporigen_id,opdestino_id) values (4,15,1,3);  -- Las del pedido intercambio con pedido de compra
insert into documentos_trazabilidades (documentoorigen_id,documentodestino_id,oporigen_id,opdestino_id) values (15,11,1,3);  -- Las del albarán de venta con Pedido de Intercambio
insert into documentos_trazabilidades (documentoorigen_id,documentodestino_id,oporigen_id,opdestino_id) values (15,10,1,21);  -- Las del pedido de venta con pedido de intercambio
insert into documentos_trazabilidades (documentoorigen_id,documentodestino_id,oporigen_id,opdestino_id,aplicaralineas) values (3,17,1,3,false);  --La cabecera de la factura de gasto puede estar apuntando a un albarán de depósito
insert into documentos_trazabilidades (documentoorigen_id,documentodestino_id,oporigen_id,opdestino_id,aplicaralineas) values (6,17,1,3,false);  --La cabecera de la factura de gasto puede estar apuntando a un albarán de compra
insert into documentos_trazabilidades (documentoorigen_id,documentodestino_id,oporigen_id,opdestino_id) values (18,1,1,1); -- Los pedidos de Necesidad con la consulta de gestión del catálogo
insert into documentos_trazabilidades (documentoorigen_id,documentodestino_id,oporigen_id,opdestino_id) values (18,4,1,1); -- Las Ofertas de compra con la consulta de gestión del catálogo
insert into documentos_trazabilidades (documentoorigen_id,documentodestino_id,oporigen_id,opdestino_id) values (18,5,1,13); -- Las Pedidos de compra con la consulta de gestión del catálogo
insert into documentos_trazabilidades (documentoorigen_id,documentodestino_id,oporigen_id,opdestino_id) values (18,6,1,5);  --albarán de compra con la consulta de gestión del catálogo
insert into documentos_trazabilidades (documentoorigen_id,documentodestino_id,oporigen_id,opdestino_id) values (18,9,1,3);  --oferta de venta con la consulta de gestión del catálogo
insert into documentos_trazabilidades (documentoorigen_id,documentodestino_id,oporigen_id,opdestino_id) values (18,10,1,22);  --Pedido de venta con la consulta de gestión del catálogo
insert into documentos_trazabilidades (documentoorigen_id,documentodestino_id,oporigen_id,opdestino_id) values (18,11,1,9);  --Albarán de venta con la consulta de gestión del catálogo
insert into documentos_trazabilidades (documentoorigen_id,documentodestino_id,oporigen_id,opdestino_id) values (11,20,1,5);  --Albarán Incidencia con albarán de venta

--Corresponde al usuario poner 1 y -1 en  los albaranes de intercambio

select setval('documentos_trazabilidades',max(id)) from documentos_trazabilidades;


--Las Ofertas de compra son la peticiones de mercancía a un proveedor del que somos representante
--La oferta de compra se transforma en albarán de entrada (a un almacén de depósito o un almacén propio).
-- El albarán de entrada se puede referir a una o muchas líneas provenientes del pedido de compra

--documentostipos numerarxsecuencia default true (solo los de compras) (valores posibles: albaran de entrada, pedido compra,albaran venta, factua de compra,factura de venta,regularizacion stock)
--seriesdocumentos (id,Serie,ctrlstk (por defeto false),invstk default false,stkfactor default 1,numerarxsecuencia default true)

create table series(
id serial primary key,
serie varchar(12) not null default '',
describe character varying(100) not null
);

create table series_combinaciones( --indicará en trazabilidad las series en las que se puede basar otra serie. Por defecto todas las series pueden usar su misma serie 
id serial primary key,
serie_id integer references series(id) match full,
serie_permitida_id integer references series(id) match full,
);

--generar un trigger para que cada vez que se inserte una serie, se inserte esa misma serie en serie_id y serie_permitida_id


insert into series (id,serie) values (1,'ASP');
insert into series (id,serie) values (2,'EXP');
insert into series (id,serie) values (3,'ECI');
insert into series (id,serie) values (4,'MKM');

CREATE unique INDEX idx_series_serie ON series USING btree (serie);

select setval('series_id_seq',max(id)) from series;




create table series_documentos(
id serial primary key,
serie_id integer references series(id) match full,
documento_tipo_id integer references documentos_tipos(id) match full,
numerarxsecuencia boolean default true, -- indica si la numeración del documento obedece a una secuencia del postgres (true), o el max +1 en todos los casos (false). En documentos de compra se suele poner a true. En venta, false
);

insert into series_documentos (serie_id,documento_tipo_id)
select series.id as idserie, documentos_tipos.id as idtipodoc
from series, documentos_tipos;
update series_documentos set numerarxsecuencia=false where documento_tipo_id in (13,14);
-- Al dar de alta una nueva serie, ejecutar la consulta anterior


 --indica el estado de las piezas en almacén. por ejemplo: en préstamo,por reparación,por intercambio,por no operativa
create table almacenes_estados(
id serial primary key,
describe character varying(100) not null default '',
);
CREATE unique INDEX idx_almacenes_estados_describe ON stocks_estados USING btree (describe);

insert into almacenes_estados (id,describe) values (1,'NUEVOS');
insert into almacenes_estados (id,describe) values (2,'DETERIORADOS');
insert into almacenes_estados (id,describe) values (3,'VERTEDERO');
insert into almacenes_estados (id,describe) values (4,'OBSOLETOS + NUEVOS');
insert into almacenes_estados (id,describe) values (5,'OBSOLETOS + DETERIORADOS');
insert into almacenes_estados (id,describe) values (6,'OBSOLETOS + VERTEDERO');
insert into almacenes_estados (id,describe) values (7,'EN EXPOSICION + NUEVOS');
insert into almacenes_estados (id,describe) values (8,'EN EXPOSICION + DETERIORADOS');
insert into almacenes_estados (id,describe) values (9,'EN EXPOSICION + VERTEDERO');
insert into almacenes_estados (id,describe) values (10,'EN EXPOSICION + OBSOLETOS + NUEVO');
insert into almacenes_estados (id,describe) values (11,'EN EXPOSICION + OBSOLETOS + DETERIORADOS');
insert into almacenes_estados (id,describe) values (12,'EN EXPOSICION + OBSOLETOS + VERTEDERO');
insert into almacenes_estados (id,describe) values (13,'DEVOLUCIONES + NUEVOS');
insert into almacenes_estados (id,describe) values (14,'DEVOLUCIONES + DETERIORADOS');
insert into almacenes_estados (id,describe) values (15,'DEVOLUCIONES + VERTEDERO');
insert into almacenes_estados (id,describe) values (16,'DEVOLUCIONES + OBSOLETOS + NUEVO');
insert into almacenes_estados (id,describe) values (17,'DEVOLUCIONES + OBSOLETOS + DETERIORADOS');
insert into almacenes_estados (id,describe) values (18,'DEVOLUCIONES + OBSOLETOS + VERTEDERO');
insert into almacenes_estados (id,describe) values (19,'PRESTAMOS + NUEVOS');
insert into almacenes_estados (id,describe) values (20,'PRESTAMOS + DETERIORADOS');
insert into almacenes_estados (id,describe) values (21,'PRESTAMOS + VERTEDERO');
insert into almacenes_estados (id,describe) values (22,'PRESTAMOS + OBSOLETOS + NUEVO');
insert into almacenes_estados (id,describe) values (23,'PRESTAMOS + OBSOLETOS + DETERIORADOS');
insert into almacenes_estados (id,describe) values (24,'PRESTAMOS + OBSOLETOS + VERTEDERO');



-- se insertará en stock cada vez que se dé de alta un nuevo almacén. 
create table almacenes(
id serial primary key,
describe character varying(100) not null,
entidad_id integer references entidades(id) match full, -- Indica a quien pertenece
codalmacen integer not null,
estransito boolean not null default false,
stockestado_id integer null references stocks_estados(id) match full default 1,
unique (describe,stockestado_id)
);


insert into almacenes (describe,entidad_id,codalmacen) values ('DIMOLAX LP',2,50);
insert into almacenes (describe,entidad_id,codalmacen) values ('SYM LP',1,1);
select setval('almacenes_id_seq',max(id)) from almacenes;


--documentos -- id,idseriedocumento,numero,almacen,dtopp,dtofijo,ts_fecharegistro,fechafacturado,fechaestimada

create table documentos(
id serial primary key,
padre_id integer default null references documentos(id) match simple, --usada para rectificativas
serie_documento_id integer default not null references series_documentos match full on update cascade,
num integer,
refusuario character varying(30) not null, -- al insertar, por trigger, este valor será entidad_emisora_id (dimolax o SYM) + serie + numeración donde 2 primeros dígitos el año y 4 dígitos
entidad_id integer references entidades(id)  match simple on update cascade,
almacenorigen_id integer references almacenes(id) match simple on update cascade,  
almacendestino_id integer references almacenes(id) match simple on update cascade,  
direnvio_id integer default null references direcciones(id) match full, --dirección que puede ser del cliente o de clientes del cliente
dirfiscal_id integer default null references direcciones(id) match full, 
fechadoc date default current_date,
dtopp numeric(6,2) check(dtopp >=0 and dtopp<=100),
dtofijo numeric(6,2) check(dtofijo>=0 and dtofijo<=100),
ts_registro timestamp not null default now,
irpf_id integer references impuestos(id),
fechaestimada date default null,
tipofpago_id integer,--pendiente por definir cuando pensemos en cartera
fechacash date default null, --fecha de cobro o pago (gestionada por cartera automáticamente)
refentidad character(50) default null, --referencia del documento de la entidad a la que estamos vinculados (numero factura de proveedor, talón de venta...)
check (not (entidad_id is null and (almacenorigen_id is null and almacendestino_id is null))),
unique (refusuario)
);

comment on table documentos is 'Al menos una entidad o un idalmacen deben de estar creados (idalmacen usado para movimientos entre almacenes)'
CREATE INDEX idx_documentos_serie_documento_id_num ON documentos USING btree (serie_id,num);
CREATE INDEX idx_documentos_fechadoc ON documentos USING btree (fechadoc);
CREATE INDEX idx_documentos_fechaestimada ON documentos USING btree (fechaestimada);
-- Comprobar que el impuesto al guardar (insertar o actualizar sea siempre un IRPF



--lineas  id, idocumento,idalmacen,padre_id (default null),cantidad,idalmacen,precio,cubierto(default false. solo útil para pedidos y actualizable por triggers) ,bi,idimpuesto,descuento, totlinea (actualizado por trigger no incluye descuentos por cabecera),ts_fecha
				--idstockestado default null,fechavencimiento default null
-- Tener en cuenta que el impuesto de IRPF no aplica por línea

create table lineas(
id serial primary key,
padre_id integer default null references documentos(id) match simple on update cascade, --usada para saber al documentoo del que provino
documento_id integer references documentos(id) match full,
almacen_id integer references almacenes(id) match full,
articulo_id integer references articulos(id) match full,
cantidad numeric(15,2) default 0,
cumplimentado numeric(15,2) default 0 not null,
motivo_cumplimentado_id references sat_motivos(id) match siple default null, 
precio numeric(15,2) not null default 0,
dtolinea numeric(6,2) check(dtolinea>=0 and dtolinea<=100),
totlinea numeric(15,2) not null default 0,
impuesto_id integer references impuestos(id) match full,
ts_fecha timestamp not null default now(),
lote_id integer null references stocks_lotes match simple,
unidadmedida_id references unidadmedidas(id) match full default 0,
fechavencimiento date default null,
check (cumplimentado=0 or motivo_cumplimentado_id is not null)
);

CREATE INDEX idx_lineas_documento_id_articulo_id ON lineas USING btree (documento_id,articulo_id,almacen_id,padre_id);
CREATE INDEX idx_lineas_idalmacen_idarticulo ON lineas USING btree (almacen_id,articulo_id,fechavencimiento);
CREATE INDEX idx_lineas_articulo_id_padre_id ON lineas USING btree (articulo_id,padre_id);

/* 
DROP TABLE IF EXISTS lineas_descripciones;
create table lineas_descripciones(
id serial primary key,
linea_id integer not null references lineas(id) match full on update cascade on delete cascade,
descripcion text not null default '';
);
CREATE unique INDEX idx_lineas_descripciones_descripcion ON lineas_descripciones USING btree (linea_id);
comment on table lineas_descripciones is 'Si la descripción de la línea no coincide con la del artículo, se guardará en esta tabla. Con lo cual si no hay registro en esta tabla=>se coge la descripción del artículo. Si si la hay, se coge esta.';
*/

--- SQL de cálculo de trazabilidad. Dada un id de línea, consultar todas las procedencias. Poner en una función con parámetros el id de línea


CREATE OR REPLACE VIEW view_trazabilidad AS
WITH RECURSIVE view_trazabilidad AS (
	SELECT id,coalesce(padre_id,0) as padre_id,documento_id, articulo_id,coalesce(sum(cantidad-cumplimentado),0) as cta_pdte, 
	FROM lineas inner join documentos on lineas.documento_id=documentos.id 
	WHERE lineas.padre_id is null 
	group by padre_id,documento_id, articulo_id 
UNION
	SELECT id,coalesce(padre_id,0) as padre_id,documento_id, articulo_id, lineas.cantidad - view_trazabilidad.cta_pdte as cta_pdte
	FROM lineas inner join documentos on lineas.documento_id=documentos.id, view_trazabilidad 
	WHERE  view_trazabilidadad.documento_id=lineas.padre_id
	
)
SELECT * FROM view_trazabilidad order by padre,texto;


/* **************************************** Módulo de gestión de cartera  */


create table cash(
id serial primary key,
documento_id integer references documentos(id) match simple default null,
entidad_id integer references entidades_links(id) match simple default null,
vencimiento_id references cash(id) match simple default null,
anticipo_id references cash(id) match simple default null,
tipofpago_id references cash_tipofpagos(id) match full,
fecha date not null,
tot numeric(20,2) not null default 0,
describe character varying(100) default '',
numdocpago character varying(25) default '',
fecharecogida date null,
check (
	((documento_id is not null or entidad_id is not null) and anticipo_id is null and vencimiento_id is null) or
	((anticipo_id is not null or vencimiento_id is not null) and documento_id is null and entidad_id is null)
      )
);


/* ---------- Fin del módulo de gestión de cartera


--doumentosfiscales (id,iddocumento,idimpuesto,idirpf,base (incluye los descuentos de cabecera),cuotaimpuesto,cuotairpf,totimpuesto,totirpf (estos 2 últimos campos inicializados a 0 que contienen el total por base imponible del documento en cuestión)
DROP TABLE IF EXISTS DOCUMENTOSFISCALES;
create table documentosfiscales(
id serial primary key,
documento_id integer not null, --documento al que está vinculado
impuesto_id integer not null,  --impuesto al que está vinculado
base (15,2),
cuota (15,2),
CONSTRAINT documentosfiscales_iddocumento_fkey FOREIGN KEY (iddocumento) REFERENCES documentos(id) MATCH FULL on delete cascade ON UPDATE CASCADE,
CONSTRAINT documentosfiscales_idimpuesto_fkey FOREIGN KEY (idimpuesto) REFERENCES impuestos(id) MATCH FULL ON UPDATE CASCADE
);

CREATE INDEX idx_documentosfiscales_impuesto_id ON documentosfiscales USING btree (impuesto_id);
CREATE INDEX unique idx_documentosfiscales_documento_id_impuesto_id ON documentosfiscales USING btree (documento_id,impuesto_id);
-- documentosfiscales__calcular(iddocumento) as text
--Hay que hacer una función que recalcule (elimine e inserte) todos los registros  de esta tabla en función de los cambios de un determinado documento o de sus líneas. Casos a actualizar:
--1) se modifica la cantidad, el precio, el descuento o el tipo de impuesto de una línea de detalle
--2) se modifica el dtopp,  el dtofijo, o el idirpf de un documento. Si se modifica el dtopp=> es un porcentaje que hay que aplicar a cada una de los totlinea del documento para calcular la base de las mismas. Si se modifica
--   el dtofijo, hay que irlo restando de los totlinea de cada base imponible para obtener al final el conjunto de bases a aplicar. Si se modifica el irpf se procede como si se cambiase cualquier impuesto de línea.
--3) El idirpf, tener en cuenta que está en la cabecera.

--Otra función que calcule el total de factura Documentos_totales(idtipo) as text
--si idtipo=0 --> devolverá todos los totales que se describen separados por el caracter |
--si idtipo=1 --> total de factura
--si idtipo=2 --> total de impuestos
--si idtipo=3 --> total de irpf
--si idtipo=4 --> total de base de la factura
--si idtipo=5 --> total de base irpf



CREATE FUNCTION Documentosfiscales_settotales(integer) RETURNS text
    LANGUAGE plpgsql
    AS $$
--Devuelve un 'OK' Si se procesa bien la información fiscal...en caso contrario, devolverá un a cadena de error
declare
p_iddocumento alias for $1;
r record;
qry record;
p_dto numeric(15,2);
begin
   delete from documentos_fiscales where documento_id=p_iddocumento;
   select dtopp,dtofijo into r from documentos where documento_id=p_iddocumento; 
   
  p_dto:=r.dtofijo;
  FOR qry in
     insert into documentos_fiscales (documento_id,impuesto_id,base,cuota)
       select p_iddocumento,impuesto_id,case when impuestos.tipo='IMPORTACION' then 0 else 0.01 * sum(lin.totlinea) * (100-r.dtopp) end, 
            case when impuestos.tipo='EXENTO' then 0 else (0.0001*sum(lin.totlinea) * (100-r.dtopp)*(impuestos.valor)) end, 
            from lineas lin inner join impuestos on lin.impuesto_id=impuestos.id
            where lin.documento_id=p_iddocumento
       group by impuesto_id,impuestos.tipo
     returning * loop
     if p_dto=0 then --Si no hay descuento fijo no haces nada
     	exit;
     else --hAY DESCUENTO FIJO=> hay que restar de las bases de las líneas hasta que se compense todo el descuento fijo, o la factura llgue a 0
        if (p_dto>=abs(qry.base)) then --borramos (significa que vamos a descontar un importe mayor a la base encontrada. Para tener una base a 0, la eliminamos
           delete from documentosfiscales where documento_id=p_iddocumento and impuesto_id=qry.idimpuesto;
        else
           update documentosfiscales set base=base-((case when base<0,-1,1)*p_dto), cuota=0.01*(base-((case when base<0,-1,1)*p_dto)*(impuestos.valor)  
           from impuestos 
           where documentosfiscales.documento_id=p_iddocumento and documentosfiscales.impuesto_id=impuestos.id  and impuestos.id=qry.impuesto_id and abs(base)>0;
           exit; --ya hemos terminado de aplicar los descuentos, por lo que salimos del for
        end if
        p_dto:=p_dto-abs(qry.base);
     end if;
  end loop;
  --calculo del irpf
  insert into documentosfiscales (documento_id,impuesto_id,base,cuota)
  select p_iddocumento,documentos.irpf_id,sum(base),0.01*sum(base)*impcab.valor
  from documentos inner join impuestos impcab on documentos.idirpf=impcab.id inner join
   documentosfiscales on documentos.id=documentosfiscales.iddocumento inner join impuestos on documentosfiscales.idimpuesto=impuestos.id
  where documentos.id=p_iddocumento and impcab.tipo='IRPF' and impuestos.tipo<>'EXENTO'
  group by documentos.id,documentos.irpf;
  return 'OK';
end;
$$;

CREATE FUNCTION Documentosfiscales_gettotales(integer,integer) RETURNS text
    LANGUAGE plpgsql
    AS $$
--si idtipo=0 --> devolverá todos los totales que se describen separados por el caracter |
--si idtipo=1 --> total de factura
--si idtipo=2 --> total de impuestos
--si idtipo=3 --> total de irpf
--si idtipo=4 --> total de base de la factura
--si idtipo=5 --> total de base irpf

declare
p_iddocumento alias for $1;
p_idtipo alias for $2;
p_totdocumento numeric(15,2);
p_totimpuestos numeric(15,2);
p_totirpf numeric(15,2);
p_totbase numeric(15,2);
p_totbaseirpf numeric(15,2);

begin
  case when p_idtipo=1 then ----> total de factura
  				select COALESCE(sum(case when impuestos.tipo<>'IRPF' then base + cuota else base - cuota end),0) into p_totdocumento
 					from documentosfiscales inner join impuestos on documentosfiscales.impuesto_id=impuestos.id
 					where documento_id=p_iddocumento;
 					return p_totdocumento::text;
  					
  		when p_idtipo=2 then --> total de impuestos
   				select COALESCE(sum(cuota),0) into p_totimpuestos
 					from documentosfiscales inner join impuestos on documentosfiscales.impuesto_id=impuestos.id
 					where documento_id=p_iddocumento and impuestos.tipo<>'IRPF';
 					return p_totimpuestos::text;
 					
 			
 			when p_idtipo=3 then --> total de irpf
   				select COALESCE(sum(cuota),0) into p_totirpf 
 					from documentosfiscales inner join impuestos on documentosfiscales.impuesto_id=impuestos.id
 					where documento_id=p_iddocumento and impuestos.tipo='IRPF';
 					return p_totirpf::text;
 			
 			when p_idtipo=4 then  --> total de base de la factura
   				select COALESCE(sum(base),0) into p_totbase total de base de la factura
 					from documentosfiscales inner join impuestos on documentosfiscales.impuesto_id=impuestos.id
 					where documento_id=p_iddocumento and impuestos.tipo<>'IRPF';
 					return p_totbase::text;
 			
 			when p_idtipo=5 then  --> total de base irpf
   				select COALESCE(sum(base),0) into p_totbaseirpf --> total de base irpf
 					from documentosfiscales inner join impuestos on documentosfiscales.impuesto_id=impuestos.id
 					where documento_id=p_iddocumento and impuestos.tipo='IRPF';
 					return p_totbaseirpf::text;
 					
  		when p_idtipo=0 then --todos los totales separados por |
   				select COALESCE(sum(case when impuestos.tipo<>'IRPF' then base + cuota else base - cuota end),0) into p_totdocumento,
   							 COALESCE(sum(case when impuestos.tipo='IRPF' then 0 else cuota end),0) into p_totpimpuestos,
   							 COALESCE(sum(case when impuestos.tipo='IRPF' then cuota else 0 end),0) into p_totirpf,
   							 COALESCE(sum(case when impuestos.tipo='IRPF' then 0 else base end),0) into p_totbase,
   							 COALESCE(sum(case when impuestos.tipo='IRPF' then base else 0 end),0) into p_totbaseirpf
 					from documentosfiscales inner join impuestos on documentosfiscales.idimpuesto=impuestos.id
 					where documento_id=p_iddocumento ;
 					return p_totodocumento::text||'|'||p_totimpuestos::text||'|'||p_totirpf::text||'|'||p_totbase::text||'|'||p_totbaseirpf::text;
	end;

end;
$$;




/* Para la búsqueda de 
select dpadre.id, articulos.id,  sum(lpadre.cantidad - coalesce(lineas.cantidad,0)) as pendiente,
from documentos dpadre inner join lineas lpadre on documentos.id=lineas.iddocumento inner join articulos on lpadre.idarticulo=articulos.id
left join lineas on lineas.padre_id=documentos.id and 
     lineas.idarticulo=lpadre.idarticulo
where dpadre.id=
group by dpadre.id, articulos.id
having  sum(lpadre.cantidad - coalesce(lineas.cantidad,0))<>0
*/

-- FIN DEL MÓDULO DE DOCUMENTOS








/* *********************** Módulo de observaciones */


create table documentos_obs_categorias(
id serial primary key,
descibe character(50)
);
insert into documentos_obs_categorias(id,describe) values (1,'NOTAS');
insert into documentos_obs_categorias(id,describe) values (2,'COMERCIALES');
insert into documentos_obs_categorias(id,describe) values (3,'INCIDENCIAS TRANSPORTE');
insert into documentos_obs_categorias(id,describe) values (4,'INCIDENCIAS MONTAJE');
insert into documentos_obs_categorias(id,describe) values (5,'INCIDENCIAS CLIENTE');
insert into documentos_obs_categorias(id,describe) values (6,'DESCRIPCION');
select setval('documentos_obs_id_seq',max(id)) from documentos_obs_categorias;


create table documentos_obs(
id serial primary key,
documento_id integer not null references documentos(id) match full,
observacion text not null default '';
categoria_id references documentos_obs_categorias(id) match full default 1;
);
CREATE unique INDEX idx_documentos_obs_documento_id ON documentos_obs USING btree (documento_id);

DROP TABLE IF EXISTS lineas_obs;
--En esta tabla se guardará también por defecto la descripción del artículo
create table lineas_obs(
id serial primary key,
linea_id integer not null references lineas(id) match full,
observacion text not null default '';
categoria_id references documentos_obs_categorias(id) match full default 1;
);
CREATE unique INDEX idx_lineas_obs_linea_id ON documentos_obs USING btree (linea_id);

DROP TABLE IF EXISTS articulos_obs;
create table articulos_obs(
id serial primary key,
articulo_id integer not null references documentos(id) match full,
observacion text not null default '';
);
CREATE unique INDEX idx_articulos_obs_articulo_id ON articulos_obs USING btree (documento_id);

/* Fin de bloque de observaciones */






/* ********************* Bloque de gestión de envíos */

create table sat_motivos_tipos(
id serial primary key,
Describe character(100);
CREATE unique INDEX idx_Sat_motivos_tipos_id ON sat_motivos_tipos USING btree (iddocumento);

insert into sat_motivos_tipos(id,describe) values (1,'Entrega dependiente mismo departamento');
insert into sat_motivos_tipos(id,describe) values (2,'Entrega dependiente Distinto departamento');
insert into sat_motivos_tipos(id,describe) values (3,'Devuelto');
insert into sat_motivos_tipos(id,describe) values (4,'Incidencia Proveedor');
insert into sat_motivos_tipos(id,describe) values (5,'Incidencia Representante');
insert into sat_motivos_tipos(id,describe) values (6,'Incidencia Transporte');
insert into sat_motivos_tipos(id,describe) values (7,'Incidencia Cliente/consumidor');
insert into sat_motivos_tipos(id,describe) values (8,'Motivos cumplimentación'); -- Cuando se rellena el campo cumplimentado, ha de ponerse un enlace a un motivo de porqué se ha cumplimentado.  

select setval('sat_motivos_tipos_id_seq',max(id)) from sat_motivos_tipos;




create table sat_motivos(
id serial primary key,
tipo_id integer references sat_motivos_tipos(id) match full,
Describe character(100);
CREATE unique INDEX idx_Sat_motivos_id ON sat_motivos USING btree (tipo_id,describe);

insert into sat_motivos(id,describe,tipo_id) values (1,'Aspol',1);
insert into sat_motivos(id,describe,tipo_id) values (2,'Pikolin',1);
insert into sat_motivos(id,describe,tipo_id) values (3,'Dunlop',1);
insert into sat_motivos(id,describe,tipo_id) values (4,'Flex',1);
insert into sat_motivos(id,describe,tipo_id) values (5,'Relax',1);
insert into sat_motivos(id,describe,tipo_id) values (6,'Mediterráneo',1);
insert into sat_motivos(id,describe,tipo_id) values (7,'Tempur',1);
insert into sat_motivos(id,describe,tipo_id) values (8,'Magister',1);
insert into sat_motivos(id,describe,tipo_id) values (9,'Moraplex',1);
insert into sat_motivos(id,describe,tipo_id) values (10,'Incapol',1);
insert into sat_motivos(id,describe,tipo_id) values (11,'Ecus',1);
insert into sat_motivos(id,describe,tipo_id) values (12,'Otro',1);
insert into sat_motivos(id,describe,tipo_id) values (12,'Almohadas (056)',2);
insert into sat_motivos(id,describe,tipo_id) values (13,'Textil',2);
insert into sat_motivos(id,describe,tipo_id) values (14,'Muebles',2);
insert into sat_motivos(id,describe,tipo_id) values (15,'Mo lo quiere',3);
insert into sat_motivos(id,describe,tipo_id) values (16,'Cambio Marca',3);
insert into sat_motivos(id,describe,tipo_id) values (17,'Cambio Medida',3);
insert into sat_motivos(id,describe,tipo_id) values (18,'Cambio Modelo',3);
insert into sat_motivos(id,describe,tipo_id) values (19,'Condiciones Económicas',3);
insert into sat_motivos(id,describe,tipo_id) values (20,'Error Etiquetado',4);
insert into sat_motivos(id,describe,tipo_id) values (21,'Falta Componente',4);
insert into sat_motivos(id,describe,tipo_id) values (22,'Error Identificación',5);
insert into sat_motivos(id,describe,tipo_id) values (23,'Rotura',5);
insert into sat_motivos(id,describe,tipo_id) values (24,'Error de carga',6);
insert into sat_motivos(id,describe,tipo_id) values (25,'Rotura',6);
insert into sat_motivos(id,describe,tipo_id) values (26,'Colchón/Base Largo Distinto',7);
insert into sat_motivos(id,describe,tipo_id) values (27,'Colchón/Base Ancho Distinto',7);
insert into sat_motivos(id,describe,tipo_id) values (28,'Colchón/Base Deformado/Hundido',7);
insert into sat_motivos(id,describe,tipo_id) values (29,'Inaccesible',7);
insert into sat_motivos(id,describe,tipo_id) values (30,'Lo pidió pero no lo quiso finalmente',8);
select setval('sat_motivos_id_seq',max(id)) from sat_motivos;


/* *********************  Bloque de gestión de stocks */


create table stocks_lotes(
id serial primary key,
describe character varying(100) not null default '',
);
CREATE unique INDEX idx_tipomov_lotes_describe ON stocks_lotes USING btree (describe);


create table stocks(
id serial primary key,
almacen_id integer not null,
articulo_id integer not null,
cantidad numeric(15,2) not null default 0.0,
fechavencimiento date default null ,
lote_id integer null references stocks_lotes match(id) simple
);
CREATE unique INDEX idx_stocks_almacen_id_articulo_id ON stocks USING btree (almacen_id,articulo_id,lote_id,fechavencimiento);









CREATE OR REPLACE FUNCTION lineas_stock()
  RETURNS TRIGGER AS
$BODY$
--Actualiza el stock conforme a la que dice cada línea
 declare    
    p_idartnew integer;
    p_idartold integer;
    p_iddocumento integer;
    qry record;
    p_cantidad numeric(15,2);
    p_signo integer; --si se define que mueve estock, una cantidad positiva puede representar que aumenta stock (valdrá 1), o que resta stock (valdrá -1)
    p_aplicastk integer; --factor por el que multiplicar el  campo cantidad de la tabla stk (puede ser 1 o 0)
    p_aplicastkpdte_in integer;  --factor por el que multiplicar el  campo cantidadpdtellegar de la tabla stk (puede ser 1 o 0)
    p_aplicastkpdte_ou integer;  --factor por el que multiplicar el  campo cantidadpdteservir de la tabla stk (puede ser 1 o 0)
    p_id integer;

begin
 	p_idartnew:=0;
 	p_idartold:=0;
    	IF (TG_OP = 'DELETE') THEN
    	   if old.cantidad=0 then
    	     return old;
    	   end if;
    	   p_idartold:=old.articulo_id;
    	   p_iddocumento:=old.documento_id;
      elsif (TG_OP = 'UPDATE') THEN
    	   p_idartold:=old.articulo_id;
    	   p_idartnew:=new.articulo_id;
    	   p_iddocumento:=new.iddocumento;
    	   if p_idartold=p_idartnew and old.cantidad=new.cantidad then -- ningún cambio que hacer
    	     return new;
    	   end if;

      elsif (TG_OP = 'INSERT') THEN
     	   if new.cantidad=0 then
    	     return new;
    	   end if;

    	   p_idartnew:=new.articulo_id;
    	   p_iddocumento:=new.documento_id;
      END IF;
      
      --¿aplicafechavencimiento o aplica estado en el artículo? tenerlo en cuenta para el cómputo de estock
    	for  qry in 
    			select articulos.id,seriesdocumentos.tipostock,aplicacaducidad,aplicaestado,aplicalote,aplicatipomov
    			from documentos inner join seriesdocumentos on documentos.idserie=seriesdocumentos.id,articulos
    			where documentos.id=p_iddocumento and ((articulos.id=p_idartold and articulos.ctrlstk) or (articulos.id=p_idartnew and articulos.ctrlstk))
    			       and seriesdocumentos.tipostock<>'SIN_STK'
      loop
            
          p_signo:= qry.tipostock like '%INV%' then -1 else 1 end; -- EL SUFIJO INV SIGNIFICA QUE sale de stock (descuenta stock, por eso el -1)
        	p_aplicastk :=case when qry.tipostock in ('STK','STK_INV') 1 else 0 end;
    			p_aplicastkpdte_in:=case when qry.tipostock in ('STK_PDTE_IN','STK_PDTE_INV_IN') 1 else 0 end;
    			p_aplicastkpdte_ou:=case when qry.tipostock in ('STK_PDTE_OU','STK_PDTE_INV_OU') 1 else 0 end;;

        
          if qry.id = p_idartnew then --inserción o actualización
            if qry.aplicacaducidad and new.fechavencimiento is null then --comprobamos que la línea tenga caducidad ya que la definición del artículo así lo requiere
            	  raise exception 'El articulo % requiere que se especifique una fecha de caducidad al realizar un movimiento. Se abortan los cambios',articulos_nombre(qry.id,false)
          	end if;
            if qry.aplicaestado and new.idstockestado is null then --comprobamos que la línea tenga estado ya que la definición del artículo así lo requiere
            	  raise exception 'El articulo % requiere que se especifique un estado al realizar un movimiento. Se abortan los cambios',articulos_nombre(qry.id,false)
          	end if;
            if qry.aplicalote and new.idlote is null then --comprobamos que la línea tenga lote ya que la definición del artículo así lo requiere
            	  raise exception 'El articulo % requiere que se especifique un lote al realizar un movimiento. Se abortan los cambios',articulos_nombre(qry.id,false)
          	end if;
            if qry.aplicatipomov and new.aplicatipomov is null then --comprobamos que la línea tenga tipo ya que la definición del artículo así lo requiere
            	  raise exception 'El articulo % requiere que se especifique un tipo al realizar un movimiento. Se abortan los cambios',articulos_nombre(qry.id,false)
          	end if;


          	p_cantidad:=(p_signo * new.cantidad);
        		update stocks set id=id,cantidad=cantidad + (p_cantidad * p_aplicastk),cantidadpdtellegar=cantidadpdtellegar + (p_cantidad*p_aplicastkpdte_in),cantidadpdteservir=cantidadpdteservir + (p_cantidad*p_aplicastkpdte_ou)
        	  where idarticulo=qry.id and idalmacen=new.idalmacen
        	  returning id into p_id;
        	  if (p_aplicastkpdte_in=0 and p_aplicastkpdte_ou=0) then --Si estamos con el stock real, entonces actualizamos lo que hay conforme a su vencimiento o estado
        			update stocks_detalles set id=id, cantidad=cantidad + p_cantidad  
        			where  idstock=p_id and ((stocks_detalle.fechavencimiento=new.fechavencimiento and new.fechavencimiento is not null) or 
        															 (stocks_detalle.idstockestado=new.idstockestado and new.idstockestado is not null) or 
        															 (stocks_detalle.idtipomov=new.idtipomov and new.ididtipomov is not null) or
        															 (stocks_detalle.idlote=new.idlote and new.idlote is not null))
        			returning id into p_id, cantidad into p_cantidad;
        			if not found and p_cantidad<>0.0 then --si no está en stock_detalles se inserta un registro
        		  	 insert into stocks_detalles (idstock,cantidad,fechavencimiento,idstockestado,idtipomov,idlote) values
															        		   (p_id,new.cantidad,new.fechavencimiento,new.idstockestado,new.idtipomov,new.idlote);
        	  	elsif found and p_cantidad=0.0 then --el stock se ha quedado a 0 en la actualización=>eliminar
        		  		 delete  from stocks_detalle where id=p_id; 
        			end if;            
        		end if;
         	elsif		qry.id =p_idartold then  --eliminación
            if qry.aplicacaducidad and old.fechavencimiento is null then --comprobamos que la línea tenga caducidad ya que la definición del artículo así lo requiere
            	  raise exception 'El articulo % requiere que se especifique una fecha de caducidad al realizar un movimiento. Se abortan los cambios',articulos_nombre(qry.id,false)
          	end if;
            if qry.aplicaestado and old.idstockestado is null then --comprobamos que la línea tenga estado ya que la definición del artículo así lo requiere
            	  raise exception 'El articulo % requiere que se especifique un estado al realizar un movimiento. Se abortan los cambios',articulos_nombre(qry.id,false)
          	end if;
            if qry.aplicalote and old.idlote is null then --comprobamos que la línea tenga lote ya que la definición del artículo así lo requiere
            	  raise exception 'El articulo % requiere que se especifique un lote al realizar un movimiento. Se abortan los cambios',articulos_nombre(qry.id,false)
          	end if;
            if qry.aplicatipomov and old.aplicatipomov is null then --comprobamos que la línea tenga tipo ya que la definición del artículo así lo requiere
            	  raise exception 'El articulo % requiere que se especifique un tipo al realizar un movimiento. Se abortan los cambios',articulos_nombre(qry.id,false)
          	end if;



         	  p_cantidad:=(p_signo * old.cantidad);
        	  update stocks set id=id,cantidad=cantidad - (p_cantidad*p_aplicastk),cantidadpdtellegar=cantidadpdtellegar - (p_cantidad*p_aplicastkpdte_in),cantidadpdteservir=cantidadpdteservir - (p_cantidad*p_aplicastkpdte_ou)
        	  where idarticulo=qry.id and idalmacen=old.idalmacen
        	  returning id into p_id;
        	  if (p_aplicastkpdte_in=0 and p_aplicastkpdte_ou=0) then
         			update stocks_detalles set id=id, cantidad=cantidad - p_cantidad 
        			where idstock=p_id and ((stocks_detalles.fechavencimiento=old.fechavencimiento and old.fechavencimiento is not null) or 
	        		           (stocks_detalles.idstockestado=old.idstockestado and old.idstockestado is not null) or
	        		           (stocks_detalle.idtipomov=old.idlote and old.ididtipomov is not null) or
        															(stocks_detalle.idlote=old.idlote and old.idlote is not null))
  	      		returning  id into p_id, cantidad into p_cantidad;
    	    		if found and p_cantidad=0.0 then --si la cantidad que se ha dejado es 0=>se elimina dicho registro de stock_detalles.
      	  		  delete  from stocks_detalles where id=p_id; 
        			end if;            
          	end if;
          end if;
      end loop;          	
 
end;
$BODY$
  LANGUAGE 'plpgsql' VOLATILE
  COST 100;


CREATE OR REPLACE FUNCTION lineas_stock_pdte()
  RETURNS TRIGGER AS
$BODY$
--Actualiza el stock pendiete de servir o recibir conforme al documento al que está vinculado por el padre_id de la línea. 
-- No aplica al stock real, solo al pendiente. Tampoco aplicaa los stocks con detalle (caducidades y estados) puesto que no se sabe lo que se va a recibir o enviar.
-- Una restricción que ha de cumplirse, es que no se pueden vincular dos documentos que muevan el mismo tipo de estock. <por ejemplo un alabarán de compra con un albarán de compra...
-- o un pedido de compra con otro pedido de compra. Hay que controlar por triger.
 declare    
    p_idartnew integer;
    p_idartold integer;
    p_iddocumento integer;
    qry record;
    p_cantidad numeric(15,2);
    p_signo integer; --si se define que mueve estock, una cantidad positiva puede representar que aumenta stock (valdrá 1), o que resta stock (valdrá -1)
    p_aplicastk integer; --factor por el que multiplicar el  campo cantidad de la tabla stk (puede ser 1 o 0)
    p_aplicastkpdte_in integer;  --factor por el que multiplicar el  campo cantidadpdtellegar de la tabla stk (puede ser 1 o 0)
    p_aplicastkpdte_ou integer;  --factor por el que multiplicar el  campo cantidadpdteservir de la tabla stk (puede ser 1 o 0)
    p_id integer;

begin
 			p_idartnew:=0;
 			p_idartold:=0;
    	IF (TG_OP = 'DELETE') THEN
    	   p_idartold:=old.idarticulo;
    	   p_iddocumento:=coalesce(old.padre_id,0);
    	   if old.cantidad=0 then
    	     return old;
    	   end if;
      elsif (TG_OP = 'UPDATE') THEN
    	   p_idartold:=old.idarticulo;
    	   p_idartnew:=new.idarticulo;
    	   p_iddocumento:=coalesce(new.padre_id,0);
    	   if p_idartold=p_idartnew and coalesce(new.padre_id,0)=coalesce(old.padre_id,0) and old.cantidad=new.cantidad then -- ningún cambio que hacer
    	     return new;
    	   end if;
      elsif (TG_OP = 'INSERT') THEN
     	   if new.cantidad=0 then
    	     return new;
    	   end if;
    	   p_idartnew:=new.idarticulo;
    	   p_iddocumento:=new.padre_id;
    	   
      END IF;
      
      
    	for  qry in 
    			select articulos.id,seriesdocumentos.tipostock
    			from documentos inner join seriesdocumentos on documentos.idserie=seriesdocumentos.id,articulos
    			where documentos.id=p_iddocumento and ((articulos.id=p_idartold and articulos.ctrlstk) or 
    			(articulos.id=p_idartnew and articulos.ctrlstk))
    			       and seriesdocumentos.tipostock not in ('SIN_STK','STK','STK_INV')
      loop
            
          p_signo:= qry.tipostock like '%INV%' then 1 else -1 end; -- EL SUFIJO INV SIGNIFICA QUE sale de stock (descuenta stock)
          																												 -- si una línea está vinculada a otra, significa que la primera 
          																												 -- restará stock de lo pendiente de entrar o pendeinte de enviar. 
          																												 -- Por eso se invierten los signos respecto a la función original
    			p_aplicastkpdte_in:=case when qry.tipostock in ('STK_PDTE_IN','STK_PDTE_INV_IN') 1 else 0 end;
    			p_aplicastkpdte_ou:=case when qry.tipostock in ('STK_PDTE_OU','STK_PDTE_INV_OU') 1 else 0 end;;

        
          if qry.id = p_idartnew then --inserción o actualización
          	p_cantidad:=(p_signo * new.cantidad);
        		update stocks set id=id,cantidadpdtellegar=cantidadpdtellegar + (p_cantidad*p_aplicastkpdte_in),cantidadpdteservir=cantidadpdteservir + (p_cantidad*p_aplicastkpdte_ou)
        	  where idarticulo=qry.id and idalmacen=new.idalmacen;
         	elsif		
         	qry.id =p_idartold then  --eliminación
         	  p_cantidad:=(p_signo * old.cantidad);
        	  update stocks set cantidadpdtellegar=cantidadpdtellegar - (p_cantidad*p_aplicastkpdte_in),cantidadpdteservir=cantidadpdteservir - (p_cantidad*p_aplicastkpdte_ou)
        	  where idarticulo=qry.id and idalmacen=old.idalmacen;
          end if;
      end loop;          	
 
end;
$BODY$
  LANGUAGE 'plpgsql' VOLATILE
  COST 100;


-- Al crear un artículo crear sus stocks a 0 en cada almacén. Igualmente, al crear un almacén.


SELECT "familias_propiedades".* FROM "familias_propiedades" WHERE "familias_propiedades"."familia_id" IN (99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 
121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143, 144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 159, 160, 161, 162, 163, 164, 165, 166, 167, 168, 169, 170) LIMIT 1