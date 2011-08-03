/*
   This file is part of MusicBrainz, the open internet music database.
   Copyright (C) 2010-2011 MetaBrainz Foundation

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

// FIXME: move the following to constants?
MB.Control._disabled_colour = '#AAA';

MB.Control.ReleaseTrack = function (parent, $track, $artistcredit) {
    var self = MB.Object ();

    self.parent = parent;
    self.bubble_collection = self.parent.bubble_collection;

    self.$row = $track;
    self.$acrow = $artistcredit;

    self.$position = $track.find ('td.position input');
    self.$title = $track.find ('td.title input.track-name');
    self.$id = $track.find ('td.title input[type=hidden]');
    self.$artist = $track.find ('td.artist input');
    self.$length = $track.find ('td.length input');
    self.$deleted = $track.find ('td input.deleted');

    /**
     * render enters the supplied data into the form fields for this track.
     */
    self.render = function (data) {
        self.$position.val (data.position);
        self.$title.val (data.name);
        if (self.$length.val () === '?:??' || !self.parent.hasToc ())
        {
            /* do not allow changes to track times if the disc has a TOC. */
            self.$length.val (data.length);
        }
        data.deleted = parseInt (data.deleted, 10);
        self.$deleted.val (data.deleted);
        if (data.artist_credit)
        {
            self.artist_credit.render (data.artist_credit);
            self.updateVariousArtists ();
        }

        if (data.deleted)
        {
            self.$row.addClass ('deleted');
        }
        else
        {
            self.$row.removeClass ('deleted');
        }

        return self;
    };

    /**
     * parseLength adds a colon to the track length if the user omitted it.
     */
    self.parseLength = function () {
        var length = self.$length.val ();

        if (length.match (/:/)) {
            return;
        }

        self.$length.val (length.replace (/([0-9]*)([0-9][0-9])/, "$1:$2"));
    };

    /**
     * Guess Case the track title.
     */
    self.guessCase = function () {
        self.$title.val (MB.GuessCase.track.guess (self.$title.val ()));
        self.artist_credit.guessCase ();
    };

    /**
     * deleteTrack marks the track for deletion.
     */
    self.deleteTrack = function () {
        self.$deleted.val('1');
        self.$row.hide (); /* FIXME: need to close artist credits? */

        var trackpos = 1;

        self.$row.closest ('tbody').find ('tr.track').each (
            function (idx, elem) {
                $(elem).find('input.pos').val (trackpos);
                if (! $(elem).hasClass ('deleted'))
                {
                    trackpos += 1;
                }
            }
        );
    };

    /* disableTracklistEditing disables the position and duration inputs and
       disables the remove track button if a CDTOC is present. */
    self.disableTracklistEditing = function () {
        if (!self.parent.hasToc ())
            return;

        self.$position.attr ('disabled', 'disabled');
        self.$length.attr ('disabled', 'disabled');
        self.$row.find ("input.remove-track").hide ();
    };

    /**
     * updateVariousArtists will mark the disc as VA if the artist for this
     * track is different from the release artist.
     */
    self.updateVariousArtists = function () {
        if (self.isDeleted () ||
            self.parent.isVariousArtists () ||
            self.artist_credit.isReleaseArtist ())
            return;

        self.parent.setVariousArtists ();
    };

    /**
     * isDeleted returns true if this track is marked for deletion.
     */
    self.isDeleted = function () {
        return self.$deleted.val () === '1';
    };

    self.lengthOrNull = function () {
        var l = self.$length.val ();

        if (l.match (/[0-9]+:[0-5][0-9]/))
        {
            return l;
        }

        return null;
    };

    /**
     * remove removes the associated inputs and table rows.
     */
    self.remove = function () {
        self.$row.remove ();
        self.$acrow.remove ();
    };

    self.$length.bind ('blur.mb', self.parseLength);
    self.$row.find ("input.remove-track").bind ('click.mb', self.deleteTrack);
    self.$row.find ("input.guesscase-track").bind ('click.mb', self.guessCase);

    var $target = self.$row.find ("td.artist input");
    var $button = self.$row.find ("a[href=#credits]");
    self.bubble_collection.add ($button, self.$acrow);
    self.artist_credit = MB.Control.ArtistCreditRow ($target, self.$acrow, $button);

    if (self.isDeleted ())
    {
        self.$row.addClass('deleted');
    }

    return self;
};

MB.Control.ReleaseDisc = function (parent, $disc) {
    var self = MB.Object ();

    self.$fieldset = $disc;
    self.parent = parent;
    self.bubble_collection = self.parent.bubble_collection;
    self.track_count = null;

    /**
     * fullTitle returns the disc title prefixed with 'Disc #: '.  Or just
     * 'Disc #' if the disc doesn't have a title.
     */
    self.fullTitle = function () {
        var title = '';
        if (!self.$title.hasClass ('jquery_placeholder'))
        {
            title = self.$title.val ();
        }

        return 'Disc ' + self.position () + (title ? ': '+title : '');
    };

    /**
     * addTrack renders new tr.track and tr.track-artist-credit rows in the
     * tracklist table.  It copies the release artistcredit.
     */
    self.addTrack = function () {
        var trackno = 0;
        $.each (self.tracks, function (idx, item) {
            if (item.isDeleted ())
                return;

            var pos = parseInt (item.$position.val ());
            if (pos > trackno)
            {
                trackno = pos;
            }
        });

        var previous = null;
        if (self.$table.find ('tr.track').length)
        {
            previous = self.$table.find ('tr.track').last ();
        }

        var $row = self.$template.find ('tr.track').clone ();
        var $acrow = self.$template.find ('tr.track-artist-credit').clone ();

        self.$table.append ($row).append ($acrow);

        var trk = MB.Control.ReleaseTrack (self, $row, $acrow);
        trk.$position.val (trackno + 1);

        self.tracks.push (trk);
        self.sorted_tracks.push (trk);

        /* if the release artist is VA, clear out the track artist. */
        if (trk.artist_credit.isVariousArtists ())
        {
            trk.artist_credit.clear ();
        }

        trk.disableTracklistEditing ();
    };

    self.addTrackEvent = function (event) {
        var count = parseInt (self.$add_track_count.val ());

        if (!count || count < 1)
        {
            count = 1;
        }

        while (count)
        {
            self.addTrack ();
            count = count - 1;
        }
    };


    /**
     * getTrack merely returns the track from self.tracks if the track
     * exists.  If the track does not exist yet getTrack will
     * repeatedly call addTrack until it does.
     */
    self.getTrack = function (idx) {
        while (idx >= self.tracks.length)
        {
            self.addTrack ();
        }

        return self.tracks[idx];
    };

    self.getTracksAtPosition = function (pos) {

        var ret = [];
        $.each (self.tracks, function (idx, item) {
            if (parseInt (item.$position.val ()) === pos)
            {
                ret.push (item);
            }
        });

        return ret;
    };

    /**
     * removeTracks removes all table rows for unused track positions.  It expects
     * the position of the last used track as input.
     */
    self.removeTracks = function (lastused) {
        while (lastused + 1 < self.tracks.length)
        {
            self.tracks.pop ().remove ();
        }

        if (lastused === 0)
        {
            self.sorted_tracks = [];
        }
    };

    /**
     * sort sorts all the table rows by the 'position' input.
     */
    self.sort = function () {
        self.sorted_tracks = [];
        $.each (self.tracks, function (idx, item) { self.sorted_tracks.push (item); });

        self.sorted_tracks.sort (function (a, b) {
            return parseInt (a.$position.val ()) - parseInt (b.$position.val ());
        });

        $.each (self.sorted_tracks, function (idx, track) {
            if (idx)
            {
                track.$row.insertAfter (self.sorted_tracks[idx-1].$acrow);
                track.$acrow.insertAfter (track.$row);
            }
        });
    };

    /**
     * updateArtistColumn makes sure the enabled/disabled state of each of the artist
     * inputs matches the checkbox at the top of the column.
     */
    self.updateArtistColumn = function () {

        if (self.$artist_column_checkbox.is (':checked'))
        {
            $.each (self.tracks, function (idx, item) {
                item.artist_credit.enableTarget ();
                item.artist_credit.$artist_input.removeClass ('column-disabled');
            });
        }
        else
        {
            /* opening a bubble will disable the input, and re-enable
               it on close.  make sure to close these bubbles _before_
               trying to disable the associated input. */
            self.bubble_collection.hideAll ();

            $.each (self.tracks, function (idx, item) {
                item.artist_credit.disableTarget ();
                item.artist_credit.$artist_input.addClass ('column-disabled');
            });
        }
    };

    /* This function registers the ReleaseTextarea for this disc as self.basic. */
    self.registerBasic = function (basic) {
        self.basic = basic;

        /* the basic disc knows about tocs, so we can now call hasToc. */
        if (self.hasToc ())
        {
            self.$fieldset.find ('div.add-track').hide ();
        }
        else
        {
            self.$fieldset.find ('div.add-track').show ();
        }
    };

    /* 'up' is visual, so the disc position decreases. */
    self.moveUp = function () {
        var oldpos = self.position ()
        if (oldpos > 1)
        {
            self.position (oldpos - 1);
            self.parent.moveDisc (oldpos, self);
        }
    };

    /* 'down' is visual, so the disc position increases. */
    self.moveDown = function () {
        var oldpos = self.position ()
        self.position (oldpos + 1);
        self.parent.moveDisc (oldpos, self);
    };

    self.clearDisc = function () {
        self.edits.clearEdits ();
        self.tracklist = [];
        self.removeTracks (-1);
    };

    self.removeDisc = function (chained) {
        self.clearDisc ();

        self.$deleted.val ("1");
        self.$fieldset.addClass ('deleted');

        self.parent.removeDisc (self);
        self.position (0);
    };

    self.isDeleted = function () {
        return self.$deleted.val () == "1";
    };

    self.isEmpty = function () {
        if (! self.expanded)
        {
            return false;
        }

        if (self.tracks.length === 0)
        {
            return true;
        }
        else if (self.tracks.length === 1 &&
                 self.tracks[0].$title.val () === '' &&
                 self.tracks[0].$length.val () === '?:??')
        {
            /* this track was most probably added by "Add Disc" ->
             * "Manual entry", which means this disc should still be
             * considered empty. */
            return true;
        }
        else
        {
            var deleted = true;
            $.each (self.tracks, function (idx, trk) {
                deleted = deleted && trk.isDeleted ();
            });

            /* if all tracks are deleted, the disc is empty. */
            return deleted;
        }
    };

    self.position = function (val) {
        if (val !== undefined)
        {
            self.$position.val (val);
            self.$fieldset.find ('span.discnum').text (val);
            self.basic.$basicdisc.find ('span.discnum').text (val);
        }

        return parseInt (self.$position.val ());
    };

    self.submit = function () {
        if (self.expanded)
        {
            self.edits.saveEdits (self.tracklist, self.tracks);
        }
    };

    self.collapse = function (chained) {
        self.expanded = false;
        self.edits.saveEdits (self.tracklist, self.tracks);

        /* Free up memory used for the tracklist.
           FIXME: shouldn't do this immediatly, but only after N other discs
           have been opened. */
        self.tracklist = null;

        self.$table.hide ();
        self.removeTracks (0);
        self.$fieldset.removeClass ('expanded');
        self.$collapse_icon.hide ();
        self.$expand_icon.show ();

        if (!chained)
        {
            self.basic.collapse (true);
        }
    };

    self.getReleaseArtist = function () {
        $release_artist = $('table.tracklist-template tr.track-artist-credit');

        var names = [];
        var preview = "";
        $release_artist.find ('tr.artist-credit-box').each (function (idx, row) {
            names[idx] = {
                "artist_name": $(row).find ('input.name').val (),
                "name": $(row).find ('input.credit').val (),
                "gid": $(row).find ('input.gid').val (),
                "id": $(row).find ('input.id').val (),
                "join": $(row).find ('input.join').val ()
            };

            preview += names[idx].name + names[idx].join;
        });

        return { names: names, preview: preview };
    };

    self.changeTrackArtists = function (data) {
        if (!MB.release_artist_json)
        {
            return data;
        }

        /* if MB.release_artist_json is not null, the user has changed the release
           artist and wants to change track artists too.

           The following code compares the artist for each track to the previous
           release artist, if they are the same we need to update the artist for
           that track with the new release artist.
        */
        $.each (data, function (idx, track) {
            if (track.artist_credit.names.length === MB.release_artist_json.names.length)
            {
                var update = true;

                $.each (MB.release_artist_json.names, function (idx, credit) {
                    tmp = track.artist_credit.names[idx];
                    if (credit.name !== tmp.name || credit.id !== tmp.id)
                    {
                        update = false;
                        return false;
                    }
                });

                if (update)
                {
                    data[idx].artist_credit = self.getReleaseArtist ();
                }
            }
        });

        return data;
    };

    self.expand = function (chained) {
        self.expanded = true;
        var data = self.edits.loadEdits ();

        var use_data = function (data) {
            self.loadTracklist (data);
            if (chained) {
                self.basic.loadTracklist (data);
            }

            if (self.hasToc ()) {
                self.track_count = data.length;
            }
        };

        self.$nowloading.show ();
        self.$fieldset.addClass ('expanded');
        self.$expand_icon.hide ();
        self.$collapse_icon.show ();

        if (data)
        {
            use_data (data);
        }
        else if (!self.tracklist)
        {
            /* FIXME: ignore result if the disc has been collapsed in
               the meantime.  --warp. */
            var tracklist_id = self.basic.$tracklist_id.val ();
            if (tracklist_id)
            {
                $.getJSON ('/ws/js/tracklist/' + tracklist_id, {}, function (data) {
                    use_data (self.changeTrackArtists (data.tracks));
                });
            }
            else
            {
                use_data ([]);
            }
        }

        if (!chained)
        {
            self.basic.expand (true);
        }
    };

    self.loadTracklist = function (data) {
        if (!data)
        {
            data = [];
        }

        self.tracklist = data;

        self.removeTracks (data.length);

        $.each (data, function (idx, trk) {
            if (!trk.hasOwnProperty ('position'))
            {
                trk.position = idx + 1;
            }

            if (!trk.hasOwnProperty ('deleted'))
            {
                trk.deleted = 0;
            }

            if (!trk.hasOwnProperty ('name'))
            {
                trk.name = "";
            }

            self.getTrack (idx).render (trk);
        });

        self.sort ();
        self.$table.show ();
        self.$nowloading.hide ();
    };

    self.guessCase = function () {
        self.guessCaseTitle ();

        $.each (self.tracks, function (idx, item) { item.guessCase (); });
    };

    self.guessCaseTitle = function () {
        self.$title.val (MB.GuessCase.release.guess (self.$title.val ()));
    };


    /**
     * isVariousArtists returns false only if all tracks on the disc are identical
     * to the release artist.
     */
    self.isVariousArtists = function () {
        return self.basic.isVariousArtists ();
    };

    self.hasToc = function () {
        return self.basic.hasToc ();
    };

    /**
     * Allow a track to mark this disc as various artists.  There currently is no way
     * to change this back to single artists.
     */
    self.setVariousArtists = function () {
        self.basic.$various_artists.val ('1');
    };

    /**
     * Disable the disc title field if there is only one disc.
     */
    self.disableDiscTitle = function () {
        if (self.$title.val () === '')
        {
            self.$title.attr ('disabled', 'disabled');
            self.$title.siblings ('input.icon.guesscase-medium').hide ();
        }
    };

    /**
     * Enable the disc title field if there are multiple discs.
     */
    self.enableDiscTitle = function () {
        self.$title.removeAttr ('disabled');
        self.$title.siblings ('input.icon.guesscase-medium').show ();
    };

    self.$table = self.$fieldset.find ('table.medium');
    self.$artist_column_checkbox = self.$table.find ('th.artist input');

    self.number = parseInt (self.$fieldset.attr ('id').match ('mediums\.([0-9]+)\.advanced-disc')[1]);

    self.expanded = false;
    self.tracklist = null;
    self.tracks = [];
    self.sorted_tracks = [];

    /* the following inputs move between the fieldset and the
     * textareas of the basic view.  Therefore we cannot rely on them
     * being children of self.fieldset, and we need to find them based
     * on their id attribute. */
    self.$title = $('#id-mediums\\.'+self.number+'\\.name');
    self.$deleted = $('#id-mediums\\.'+self.number+'\\.deleted');
    self.$position = $('#id-mediums\\.'+self.number+'\\.position');
    self.$format_id = $('#id-mediums\\.'+self.number+'\\.format_id');

    self.$title.siblings ('input.guesscase-medium').bind ('click.mb', self.guessCaseTitle);

    self.edits = MB.Control.ReleaseEdits ($('#id-mediums\\.'+self.number+'\\.edits'));

    self.$buttons = $('#mediums\\.'+self.number+'\\.buttons');

    self.$expand_icon = self.$fieldset.find ('input.expand-disc');
    self.$collapse_icon = self.$fieldset.find ('input.collapse-disc');
    self.$nowloading = self.$fieldset.find ('div.tracklist-loading');

    self.$template = $('table.tracklist-template');

    self.$fieldset.find ('table.medium tbody tr.track').each (function (idx, item) {
        self.tracks.push (
            MB.Control.ReleaseTrack (self, item, item.next('tr.track-artist-credit'))
        );
    });

    self.$add_track_count = self.$fieldset.find ('input.add-track-count');
    self.$fieldset.find ('input.add-track').bind ('click.mb', self.addTrackEvent);
    self.$buttons.find ('input.disc-down').bind ('click.mb', self.moveDown);
    self.$buttons.find ('input.disc-up').bind ('click.mb', self.moveUp);
    self.$buttons.find ('input.remove-disc')
        .bind ('click.mb', function (ev) { self.removeDisc (); });
    self.$expand_icon.bind ('click.mb', function (ev) { self.expand (); });
    self.$collapse_icon.bind ('click.mb', function (ev) { self.collapse (); });

    self.$artist_column_checkbox.bind ('change', self.updateArtistColumn);

    self.updateArtistColumn ();
    self.enableDiscTitle ();
    self.sort ();

    if (self.isDeleted ())
    {
        self.$fieldset.addClass ('deleted');
    }
    else
    {
        self.$fieldset.removeClass ('deleted');
    }

    return self;
};

MB.Control.ReleaseAdvancedTab = function () {
    var self = MB.Object ();

    self.bubble_collection = MB.Control.BubbleCollection ();
    self.bubble_collection.setType (MB.Control.BubbleRow);

    self.addDisc = function () {
        var discs = self.discs.length;
        var newposition = 1;
        var i;

        for (i = self.positions.length; i >= 0; i--)
        {
            if (self.positions[i])
            {
                newposition = i + 1;
                break;
            }
        }

        var lastdisc_bas = $('.basic-disc').last ();
        var lastdisc_adv = $('.advanced-disc').last ();

        var newdisc_bas = lastdisc_bas.clone ().insertAfter (lastdisc_bas);
        var newdisc_adv = lastdisc_adv.clone ().insertAfter (lastdisc_adv);

        newdisc_adv.find ('table.medium.tbl tbody').empty ();

        newdisc_bas.find ("h3").find ('span.discnum').text (newposition);
        newdisc_adv.find ("legend").find ('span.discnum').text (newposition);

        var mediumid = new RegExp ("mediums.[0-9]+");
        var update_ids = function (idx, element) {
            var item = $(element);
            if (item.attr ('id'))
            {
                item.attr ('id', item.attr('id').replace(mediumid, "mediums."+discs));
            }
            if (item.attr ('name'))
            {
                item.attr ('name', item.attr('name').replace(mediumid, "mediums."+discs));
            }
        };

        newdisc_bas.find ("*").andSelf ().each (update_ids);
        newdisc_adv.find ("*").andSelf ().each (update_ids);

        /* clear the cloned rowid for this medium and tracklist, so a
         * new medium and tracklist will be created. */
        $("#id-mediums\\."+discs+"\\.id").val('');
        $("#id-mediums\\."+discs+"\\.name").val('');
        $("#id-mediums\\."+discs+"\\.position").val(newposition);
        $("#id-mediums\\."+discs+"\\.tracklist_id").val('');
        $('#id-mediums\\.'+discs+'\\.deleted').val('0');
        $('#id-mediums\\.'+discs+'\\.edits').val('');
        $('#id-mediums\\.'+discs+'\\.toc').val('');

        newdisc_bas.find ('textarea').empty ();

        var new_disc = MB.Control.ReleaseDisc (self, newdisc_adv);

        self.discs.push (new_disc);
        self.positions[new_disc.position()] = new_disc;

        /* and scroll down to the new position of the 'Add Disc' button if possible. */
        /* FIXME: this hardcodes the fieldset bottom margin, shouldn't do that. */
        var newpos = lastdisc_adv.height () ? lastdisc_adv.height () + 12 : lastdisc_bas.height ();
        $('html').animate({ scrollTop: $('html').scrollTop () + newpos }, 500);

        self.updateDiscTitle ();

        return new_disc;
    };

    self.moveDisc = function (oldpos, disc) {
        var newpos = disc.position ();
        other = self.positions[newpos];
        if (!other)
        {
            self.positions[newpos] = disc;
            delete self.positions[oldpos];

            return true;
        }

        other.position (oldpos);
        self.positions[oldpos] = other;
        self.positions[newpos] = disc;

        if (newpos < oldpos)
        {
            disc.$fieldset.insertBefore (other.$fieldset);

            /* FIXME: yes, I am aware that the variable names I've chosen
               here could use a little improvement. --warp. */
            disc.basic.$basicdisc.insertBefore (other.basic.$basicdisc);
        }
        else
        {
            other.$fieldset.insertBefore (disc.$fieldset);
            other.basic.$basicdisc.insertBefore (disc.basic.$basicdisc);
        }

        return true;
    };

    self.removeDisc = function (disc) {
        var startpos = disc.position ();
        var i;

        delete self.positions[startpos];

        for (i = startpos + 1; i < self.positions.length; i++)
        {
            disc = self.positions[i];
            if (!disc)
            {
                /* do not move any discs beyond a possible gap. */
                break;
            }
            disc.moveUp ();
        }

        self.updateDiscTitle ();
    };

    self.guessCase = function () {
        $.each (self.discs, function (idx, disc) { disc.guessCase (); });
    };

    self.submit = function (event) {
        $.each (self.discs, function (idx, disc) {
            disc.submit (event);
        });
    };

    /* When the page is loaded, discs may not be displayed in the correct
       order.  MB.Control.ReleaseBasicTab will call this function after
       it has initialized all discs to fix the displayed order. */
    self.orderDiscs = function () {
        if (self.positions.length > 1)
        {
            var prev_disc = undefined;
            $.each (self.positions, function (pos, disc) {
                if (prev_disc && disc)
                {
                    disc.$fieldset.insertAfter (prev_disc.$fieldset);
                    disc.basic.$basicdisc.insertAfter (prev_disc.basic.$basicdisc);
                }

                if (disc)
                {
                    prev_disc = disc;
                }
            });
        }
    }

    /* Returns the last disc, i.e. the disc with the highest position() which
       has not been deleted. */
    self.lastDisc = function () {
        var pos = self.positions.length;
        while (pos > 0)
        {
            if (self.positions[pos])
            {
                return self.positions[pos];
            }
            pos--;
        }

        return null;
    }

    self.updateDiscTitle = function () {
        var pos = self.positions.length;
        var count = 0;
        var firstdisc = 1;
        while (pos > 0)
        {
            if (self.positions[pos])
            {
                firstdisc = pos;
                count++;
            }
            pos--;
        }

        if (count === 1)
        {
            self.positions[firstdisc].disableDiscTitle ();
        }
        else
        {
            self.positions[firstdisc].enableDiscTitle ();
        }
    };


    self.$tab = $('div.advanced-tracklist');
    self.discs = [];
    self.positions = [];
    self.basic = null; // set by MB.Control.ReleaseBasicTab.

    self.$tab.find ('fieldset.advanced-disc').each (function (idx, item) {
        var disc = MB.Control.ReleaseDisc (self, $(item));
        self.discs.push (disc);
        self.positions[disc.position()] = disc;
    });

    $('form.release-editor').bind ('submit.mb', self.submit);

    self.updateDiscTitle ();

    return self;
};
