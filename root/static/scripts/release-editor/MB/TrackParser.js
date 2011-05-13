/*
   This file is part of MusicBrainz, the open internet music database.
   Copyright (C) 2010 MetaBrainz Foundation

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

*/

MB.TrackParser = (MB.TrackParser) ? MB.TrackParser : {};

MB.TrackParser.separator = " - ";

MB.TrackParser.Artist = function (track, artist) {
    var self = MB.Object ();

    self.names = [];

    self.addNew = function (name) {
        self.names.push ({
            'artist_name': name,
            'name': name,
            'id': '',
            'gid': '',
            'join': null
        });
    };

    self.addArtistCredit = function (unused, ac) {
        if (unused !== '')
        {
            if (self.names.length > 0 &&
                (self.names[self.names.length - 1].join === null ||
                 self.names[self.names.length - 1].join === ''))
            {
                /* the previous entry does not have a join phrase, so the
                   unused string must be the join phrase. */
                self.names[self.names.length - 1].join = unused;
            }
            else
            {
                self.addNew (unused);
            }
        }

        self.names.push (MB.utility.clone (ac));
    };

    self.addArtist = function (unused, ac) {
        self.addArtistCredit (unused, ac);
        self.names[self.names.length - 1].join = null;
    };

    self.appendToArtist = function (unused) {
        var ac = self.names[self.names.length - 1];
        ac.artist_name = ac.artist_name + unused;
        ac.name = ac.name + unused;

        /* we've changed the name, so make sure the IDs are cleared. */
        ac.id = '';
        ac.gid = '';
    };

    self.addJoin = function (unused, ac) {
        if (unused !== '')
        {
            if (self.names.length > 0 &&
                (self.names[self.names.length - 1].join === null ||
                 self.names[self.names.length - 1].join === ''))
            {
                /* The previous entry is missing the join phrase and
                   we're missing the artist... let's assume the
                   current join phrase should be part of the previous
                   entry, which means the current unused string should
                   be appended to that artist. */
                self.appendToArtist (unused);
            }
            else
            {
                /* the previous entry has a join phrase, so the unused string is
                   the artist which is part of join phrase we're adding here. */
                self.addNew (unused);
            }
        }

        if (self.names[self.names.length - 1].join !== null)
        {
            /* the previous entry already has a join phrase, so we have to
               insert a new artist. */
            self.addNew ('');
        }

        self.names[self.names.length - 1].join = ac.join;
    };

    self.addFinal = function (unused) {
        if (unused === '')
            return;

        /* At the end of parsing we're left with some unused bits.

           Considering that a join phrase typically exists between
           two artist names this leftover string is unlikely to be
           just a join phrase.

           If the previous artist is missing the join phrase, our
           leftover string is probably something which needs to be
           appended to that artist.

           Otherwise this is probably just a new artist.
        */

        if (self.names.length > 0 &&
            (self.names[self.names.length - 1].join === null ||
             self.names[self.names.length - 1].join === ''))
        {
            self.appendToArtist (unused);
        }
        else
        {
            self.addNew (unused);
            self.names[self.names.length - 1].join = '';
        }
    };

    self.initialize = function ()
    {
        if (!track.artist_credit)
        {
            self.addNew (artist);
            self.names[self.names.length - 1].join = '';
            return;
        }

        /* let's try to match the artist name to the current
           artist on the track. */

        var index = 0;
        $.each (track.artist_credit.toData ().names, function (i, ac) {

            var pos = artist.indexOf (ac.name + ac.join, index);
            if (pos > -1)
            {
                /* artist credit hasn't changed at all. */
                self.addArtistCredit (artist.substring (index, pos), ac);
                index = pos + ac.name.length + ac.join.length;
                return;
            }

            pos = artist.indexOf (ac.name, index);
            if (pos > -1)
            {
                /* artist is the same, but the join phrase changed.  re-use
                   the artist to keep possible mbids. */
                self.addArtist (artist.substring (index, pos), ac);
                index = pos + ac.name.length;
            }

            if (ac.join !== '')
            {
                pos = artist.indexOf (ac.join, index);
                if (pos > -1)
                {
                    self.addJoin (artist.substring (index, pos), ac);
                    index = pos + ac.join.length;
                }
            }
        });

        self.addFinal (artist.substring (index));
    };

    self.initialize ();

    return self;
};

MB.TrackParser.Track = function (position, line, parent) {
    var self = MB.Object ();

    self.position = position;
    self.line = $.trim (line);
    self.parent = parent;
    self.duration = '?:??';
    self.name = '';
    self.artist = null;

    self.removeTrackNumbers = function () {
        if (self.parent.vinylNumbers ())
        {
            self.line = self.line.replace(/^[\s\(]*[-\.０-９0-9a-z]+[\.\)\s]+/i, "");
        }
        else if (self.parent.trackNumbers ())
        {
            self.line = self.line.replace(/^[\s\(]*([-\.０-９0-9\.]+(-[０-９0-9]+)?)[\.\)\s]+/, "");
        }
    };

    self.parseTimes = function () {
        var tmp = self.line.replace (/\s?\(\?:\?\?\)\s?$/, '');
        self.line = tmp.replace(/\s?\(?\s?([0-9０-９]*[：，．':,.][0-9０-９]+)\s?\)?$/,
            function (str, p1) {
                self.duration = MB.utility.fullWidthConverter(p1);
                return "";
            }
        );
    };

    self.matchTrack = function (name) {
        var end = self.parts.length - 1;
        while (end > 0)
        {
            var attempt = self.parts.slice (0, end).join (MB.TrackParser.separator);
            if (attempt === name)
            {
                return { 
                    'track': attempt,
                    'artist': self.parts.slice (end).join (MB.TrackParser.separator)
                };
            }

            end = end - 1;
        }

        return false;
    };

    self.matchArtist = function (name) {
        var start = self.parts.length - 1;
        while (start > 0)
        {
            var attempt = self.parts.slice (start).join (MB.TrackParser.separator);
            if (attempt === name)
            {
                return {
                    'track': self.parts.slice (0, start).join (MB.TrackParser.separator),
                    'artist': attempt
                };
            }

            start = start - 1;
        }

        return false;
    };

    self.parseArtist = function () {
        if (!self.parent.variousArtists () ||
            self.line.indexOf (MB.TrackParser.separator) === -1)
        {
            self.title = self.line;
            self.artist = null;
            return;
        }

        self.parts = self.line.split (MB.TrackParser.separator);

        var original = self.parent.originals[self.position - 1];
        var current = self.parent.disc.getTracksAtPosition (self.position);
        if (original)
        {
            // FIXME: original is completely different format from the other
            // tracks.  this will never match anything in original. --warp.
            // current.push (original);
        }

        /* first, try to match the trackname.. if we find a match the rest
           is the artist name. */
        var matched = false;
        $.each (current, function (idx, trk) {
            if (trk.isDeleted ())
                return true;

            var match = self.matchTrack (trk.$title.val ());
            if (match)
            {
                self.artist = MB.TrackParser.Artist (trk, match.artist);
                self.title = match.track;
                matched = true;
                return false;
            }
        });

        if (matched)
        {
            return;
        }

        /* second attempt, try to match the artist preview.. if we
           find a match we know which parts form the artist name and
           which parts are the track name. */
        var matched = false;
        $.each (current, function (idx, trk) {
            if (trk.isDeleted ())
                return true;

            var match = self.matchArtist (trk.$artist.val ());
            if (match)
            {
                self.artist = MB.TrackParser.Artist (trk, match.artist);
                self.title = match.track;
                matched = true;
                return false;
            }
        });

        if (matched)
        {
            return;
        }

        /* neither artist nor track match, let's just assume most of
         * it is the track name. */
        self.artist = MB.TrackParser.Artist (current, self.parts.pop ());
        self.title = self.parts.join (MB.TrackParser.separator);
    };

    self.clean = function () {
        self.title = $.trim (self.title)
            .replace (/(.*),\sThe$/i, "The $1")
            .replace (/\s*,/g, ",");
    };

    self.removeTrackNumbers ();
    self.parseTimes ();
    self.parseArtist ();
    self.clean ();

    return self;
};

MB.TrackParser.Parser = function (disc, textarea, serialized) {
    var self = MB.Object ();

    self.getTrackInput = function () {
        var lines = $.trim (self.textarea.val ()).split ("\n");
        var tracks = [];

        /* lineno is 1-based and ignores empty lines, it is used as
         * track position. */
        var lineno = 1;
        $.each (lines, function (idx, item) {
            if (item === '')
                return;
            tracks.push (MB.TrackParser.Track (lineno, item, self));
            lineno = lineno + 1;
        });

        return tracks;
    };

    self.fillInData = function () {
        var map = {};

        $.each (self.originals, function (idx, track) {
            var trackname = $.trim (track.name);

            if (map[trackname] === undefined) {
                map[trackname] = [];
            }
            map[trackname].push (idx);
        });

        var lastused = self.originals.length - 1;

        var original = function (idx) {
            if (idx < self.originals.length)
            {
                return $.extend ({ 'position': idx+1 }, self.originals[idx]);
            }

            return undefined;
        };

        var moved = [];
        var inserted = [];
        var deleted = [];
        var no_change = [];

        // Match up inputtitles with existing tracks.
        $.each (self.tracks, function (idx, track) {
            var data = {
                'position': track.position,
                'length': track.duration,
                'artist_credit': track.artist
            };

            var title = track.title;

            /* new track. */
            if (map[title] === undefined || map[title].length === 0)
            {
                data.row = ++lastused;
                data.name = title;
                inserted.push (data);
            }
            /* existing track, same position. */
            else if ($.inArray (idx, map[title]) !== -1)
            {
                data.row = idx;
                no_change.push (data);
                map[title].splice ($.inArray (idx, map[title]), 1);
            }
            /* existing track, moved. */
            else
            {
                data.row = map[title].pop ();
                moved.push (data);
            }
        });

        $.each (map, function (key, value) {
            $.each (value, function (idx, row) { deleted.push(row) });
        });

        /* restore those which don't change from their serialized values. */
        $.each (no_change, function (idx, data) {
            var copy = original (data.row);
            copy.deleted = 0;

            /* only override the original track length if there is no cdtoc. */
            if (!self.hasToc ())
            {
                copy.length = data.length;
            }

            if (data.artist_credit)
            {
                copy.artist_credit = data.artist_credit;
            }
            self.disc.getTrack (data.row).render (copy);
        });

        /* re-arrange any tracks which have moved. */
        $.each (moved, function (idx, data) {
            var copy = original (data.row);
            copy.deleted = 0;
            copy.position = data.position;

            /* only override the original track length if there is no cdtoc. */
            if (!self.hasToc ())
            {
                copy.length = data.length;
            }

            if (data.artist_credit)
            {
                copy.artist_credit = data.artist_credit;
            }
            self.disc.getTrack (data.row).render (copy);
        });

        /* mark deleted tracks as such. */
        $.each (deleted, function (idx, row) {
            var copy = original (row);
            copy.deleted = 1;
            self.disc.getTrack (row).render (copy);
        });

        /* insert newly added tracks. */
        $.each (inserted, function (idx, data) {
            data.deleted = 0;
            self.disc.getTrack (data.row).render (data);
        });

        /* remove unused positions. */
        self.disc.removeTracks (lastused);

        /* sort the table view after all these edits. */
        self.disc.sort ();
    };

    self.run = function () {
        self.tracks = self.getTrackInput ();
        self.fillInData ();
    };

    self.setOptions = function (options) {
        $.each (options, function (key, value) {
            var $checkbox = $('#' + key);
            if ($checkbox.length)
            {
                if (value)
                {
                    $checkbox.attr ('checked', 'checked');
                }
                else
                {
                    $checkbox.removeAttr ('checked');
                }
            }
        });
    };

    self.vinylNumbers = function () { return self.$vinylnumbers.is (':checked'); };
    self.trackNumbers = function () { return self.$tracknumbers.is (':checked'); };
    self.variousArtists = function () { return self.disc.isVariousArtists (); };
    self.hasToc = function () { return self.disc.hasToc (); };

    /* public variables. */
    self.disc = disc;
    self.textarea = textarea;
    self.originals = $.isArray (serialized) ? serialized : [];
    self.$tracknumbers = $('#tracknumbers');
    self.$vinylnumbers = $('#vinylnumbers');
    self.$tracktimes = $('#tracktimes');

    return self;
};

