ALTER DATABASE postgres SET session_preload_libraries = 'anon';
CREATE EXTENSION anon;
ALTER DATABASE postgres SET anon.transparent_dynamic_masking TO true;
