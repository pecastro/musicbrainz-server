
SET client_min_messages TO 'warning';










INSERT INTO artist_name (id, name) VALUES (1, 'Artist');
INSERT INTO artist (id, gid, name, sort_name)
    VALUES (1, '82a72730-792f-11de-8a39-0800200c9a66', 1, 1);

INSERT INTO artist_credit (id, name, artist_count) VALUES (1, 1, 1);
INSERT INTO artist_credit_name (artist_credit, position, name, artist) VALUES (1, 1, 1, 1);

INSERT INTO release_name (id, name) VALUES (1, 'Release');
INSERT INTO release_name (id, name) VALUES (2, 'RG');

INSERT INTO release_group (id, gid, name, artist_credit)
    VALUES (1, 'a037f860-792f-11de-8a39-0800200c9a66', 2, 1);

INSERT INTO release (id, gid, name, artist_credit, release_group)
    VALUES (1, '6a7d1660-792f-11de-8a39-0800200c9a66', 1, 1, 1);

INSERT INTO tracklist (id, track_count) VALUES (1, 1);

INSERT INTO medium (id, tracklist, release, position, name)
    VALUES (1, 1, 1, 1, 'Medium Name');


INSERT INTO medium_format (id, name) VALUES (1, 'CD');

INSERT INTO track_name (id, name) VALUES (1, 'Track');
INSERT INTO recording (id, gid, name, artist_credit)
    VALUES (1, 'a037f860-792f-11de-8a39-0800200c9a66', 1, 1);
