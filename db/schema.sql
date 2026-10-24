-- =============================================================
-- Global TV Max · Migración inicial PostgreSQL (Fase 2 · servidor)
-- Compatible con PostgreSQL 15+ / Supabase
-- Contraseñas: hash Argon2id generado en el backend (nunca texto plano)
-- =============================================================
create extension if not exists pgcrypto;
create extension if not exists citext;

create type account_status   as enum ('activa','suspendida');
create type validation_state as enum ('pendiente','aprobada','rechazada');
create type source_health    as enum ('sin_verificar','en_linea','caida','externo');
create type stream_format    as enum ('hls','dash','link');
create type content_kind     as enum ('movie','series');
create type offer_type       as enum ('suscripcion','renta','compra','gratis_anuncios','abierto');
create type quality_label    as enum ('SD','HD_720','FHD_1080','UHD_4K','no_confirmada','CAM');

-- ---------- Roles y permisos ----------
create table roles (
  id          text primary key,              -- superadmin, admin, editor, user
  name        text not null
);
create table permissions (
  id          text primary key,              -- users.manage, catalog.edit, ...
  description text not null
);
create table role_permissions (
  role_id       text references roles(id) on delete cascade,
  permission_id text references permissions(id) on delete cascade,
  primary key (role_id, permission_id)
);

-- ---------- Planes ----------
create table subscription_plans (
  id              uuid primary key default gen_random_uuid(),
  name            text not null,
  price           numeric(10,2) not null default 0,
  currency        char(3) not null default 'MXN',
  duration_days   int not null check (duration_days > 0),
  max_devices     int not null check (max_devices > 0),
  max_streams     int not null check (max_streams > 0),
  playback_limits text,
  all_categories  boolean not null default false,
  active          boolean not null default true,
  created_at      timestamptz not null default now()
);

-- ---------- Usuarios ----------
create table users (
  id               uuid primary key default gen_random_uuid(),
  public_code      text unique not null,          -- GTM-XXXXXXXX
  username         citext unique not null,
  full_name        text not null,
  email            citext unique,
  password_hash    text not null,                 -- $argon2id$...
  must_change_pw   boolean not null default false,
  temp_pw_expires  timestamptz,
  role_id          text not null references roles(id),
  status           account_status not null default 'activa',
  expires_at       date,
  max_devices      int,                           -- null = según plan
  failed_attempts  int not null default 0,
  locked_until     timestamptz,
  last_login_at    timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create table subscriptions (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references users(id) on delete cascade,
  plan_id    uuid not null references subscription_plans(id),
  status     text not null default 'activa' check (status in ('activa','vencida','cancelada','prueba')),
  starts_at  timestamptz not null default now(),
  ends_at    timestamptz not null,
  payment_ref text,                                -- id del proveedor de pagos
  created_at timestamptz not null default now()
);
create index on subscriptions(user_id, status);

create table devices (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references users(id) on delete cascade,
  fingerprint text not null,
  name        text not null,
  added_at    timestamptz not null default now(),
  last_seen   timestamptz,
  revoked_at  timestamptz,
  unique (user_id, fingerprint)
);

create table user_sessions (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references users(id) on delete cascade,
  device_id     uuid references devices(id) on delete set null,
  refresh_hash  text not null,                     -- hash del refresh token
  ip            inet,
  user_agent    text,
  created_at    timestamptz not null default now(),
  last_seen     timestamptz not null default now(),
  expires_at    timestamptz not null,
  revoked_at    timestamptz
);
create index on user_sessions(user_id) where revoked_at is null;

create table invitations (                        -- invitaciones de un solo uso
  id          uuid primary key default gen_random_uuid(),
  token_hash  text unique not null,
  user_id     uuid references users(id) on delete cascade,
  created_by  uuid references users(id),
  expires_at  timestamptz not null,
  used_at     timestamptz
);

-- ---------- Geografía y canales ----------
create table countries (
  code  text primary key,                          -- MX, US, LATAM, EU...
  name  text not null
);
create table channel_categories (
  id    text primary key,                          -- abierta, noticias, deportes...
  name  text not null
);
create table plan_categories (
  plan_id     uuid references subscription_plans(id) on delete cascade,
  category_id text references channel_categories(id) on delete cascade,
  primary key (plan_id, category_id)
);

create table channels (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  logo_url      text,
  country_code  text not null references countries(code),
  category_id   text not null references channel_categories(id),
  language      text,
  epg_id        text,                              -- id XMLTV
  enabled       boolean not null default false,
  is_demo       boolean not null default false,
  created_at    timestamptz not null default now()
);

create table media_sources (
  id              uuid primary key default gen_random_uuid(),
  channel_id      uuid references channels(id) on delete cascade,
  movie_id        uuid,                            -- fk agregada abajo
  episode_id      uuid,
  provider        text not null,
  url             text not null,
  format          stream_format not null,
  quality         quality_label not null default 'no_confirmada',
  authorization   text not null,                   -- contrato / licencia / permiso
  geo_allow       text[],                          -- países permitidos (null = todos)
  geo_block       text[],
  validation      validation_state not null default 'pendiente',
  health          source_health not null default 'sin_verificar',
  last_checked    timestamptz,
  avg_start_ms    int,
  created_at      timestamptz not null default now(),
  check (num_nonnulls(channel_id, movie_id, episode_id) = 1)
);

create table epg_programs (
  id          bigserial primary key,
  channel_id  uuid not null references channels(id) on delete cascade,
  title       text not null,
  description text,
  starts_at   timestamptz not null,
  ends_at     timestamptz not null,
  rating      text,
  check (ends_at > starts_at)
);
create index on epg_programs(channel_id, starts_at);

-- ---------- Catálogo ----------
create table genres (
  id   serial primary key,
  name text unique not null
);
create table movies (
  id              uuid primary key default gen_random_uuid(),
  kind            content_kind not null default 'movie',
  title_es        text not null,
  title_original  text not null,
  synopsis        text,
  release_year    int,
  duration_min    int,
  languages       text[],
  subtitles       text[],
  cast_list       text[],
  directors       text[],
  age_rating      text,
  file_quality    quality_label not null default 'no_confirmada',
  poster_url      text,
  backdrop_url    text,
  tmdb_id         int unique,
  is_demo         boolean not null default false,
  created_at      timestamptz not null default now()
);
create table series (
  id         uuid primary key references movies(id) on delete cascade  -- movies.kind = 'series'
);
create table episodes (
  id           uuid primary key default gen_random_uuid(),
  series_id    uuid not null references series(id) on delete cascade,
  season       int not null default 1,
  number       int not null,
  title        text not null,
  duration_min int,
  air_date     date,
  unique (series_id, season, number)
);
create table movie_genres (
  movie_id uuid references movies(id) on delete cascade,
  genre_id int  references genres(id) on delete cascade,
  primary key (movie_id, genre_id)
);
alter table media_sources add foreign key (movie_id)   references movies(id)   on delete cascade;
alter table media_sources add foreign key (episode_id) references episodes(id) on delete cascade;

create table streaming_providers (
  id        text primary key,                      -- netflix, prime, vix...
  name      text not null,
  url       text not null,
  logo_url  text
);
create table content_availability (
  movie_id     uuid references movies(id) on delete cascade,
  provider_id  text references streaming_providers(id) on delete cascade,
  country_code text references countries(code),
  offer        offer_type not null,
  deep_link    text,
  source_api   text not null,                      -- tmdb, justwatch...
  updated_at   timestamptz not null default now(),
  primary key (movie_id, provider_id, country_code, offer)
);

-- ---------- Actividad del usuario ----------
create table favorites (
  user_id    uuid references users(id) on delete cascade,
  channel_id uuid references channels(id) on delete cascade,
  movie_id   uuid references movies(id) on delete cascade,
  created_at timestamptz not null default now(),
  check (num_nonnulls(channel_id, movie_id) = 1),
  unique (user_id, channel_id),
  unique (user_id, movie_id)
);
create table watch_history (
  id           bigserial primary key,
  user_id      uuid not null references users(id) on delete cascade,
  movie_id     uuid references movies(id) on delete cascade,
  episode_id   uuid references episodes(id) on delete cascade,
  channel_id   uuid references channels(id) on delete cascade,
  position_sec int not null default 0,
  duration_sec int,
  watched_at   timestamptz not null default now()
);
create index on watch_history(user_id, watched_at desc);

create table user_playlists (                      -- listas M3U del usuario (modo reproductor)
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references users(id) on delete cascade,
  name       text not null,
  source_url text,
  channels   jsonb not null default '[]',
  updated_at timestamptz not null default now()
);

create table audit_logs (
  id         bigserial primary key,
  actor_id   uuid references users(id) on delete set null,
  action     text not null,
  target     text,
  detail     jsonb,
  ip         inet,
  created_at timestamptz not null default now()
);
create index on audit_logs(created_at desc);

-- ---------- Datos base ----------
insert into roles values ('superadmin','Superadministrador'),('admin','Administrador'),('editor','Editor'),('user','Usuario');
insert into permissions values
 ('users.manage','Usuarios y suscripciones'),('admins.manage','Administrar administradores'),
 ('plans.manage','Planes de acceso'),('channels.manage','Canales y categorías'),
 ('catalog.edit','Metadatos, carteles y programación'),('stats.view','Estadísticas'),
 ('security.view','Registros de actividad y seguridad'),('settings.manage','Configuración y fuentes');
insert into role_permissions select 'superadmin', id from permissions;
insert into role_permissions values
 ('admin','users.manage'),('admin','plans.manage'),('admin','channels.manage'),('admin','stats.view'),('admin','security.view'),
 ('editor','catalog.edit');
insert into countries values ('MX','México'),('US','Estados Unidos'),('LATAM','Latinoamérica'),('CA','Canadá'),('EU','Europa'),('AS','Asia'),('INT','Internacional');
insert into channel_categories values ('abierta','Televisión abierta'),('noticias','Noticias'),('deportes','Deportes'),('entretenimiento','Entretenimiento'),('peliculas','Películas'),('musica','Música'),('cultura','Cultura y educación'),('regional','Regionales'),('infantil','Infantil');
