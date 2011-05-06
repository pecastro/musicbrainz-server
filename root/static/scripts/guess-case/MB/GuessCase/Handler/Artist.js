/*
   This file is part of MusicBrainz, the open internet music database.
   Copyright (c) 2005 Stefan Kestenholz (keschte)
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

MB.GuessCase = (MB.GuessCase) ? MB.GuessCase : {};
MB.GuessCase.Handler = (MB.GuessCase.Handler) ? MB.GuessCase.Handler : {};

/**
 * Artist specific GuessCase functionality
 **/
MB.GuessCase.Handler.Artist = function () {
    var self = MB.GuessCase.Handler.Base ();

    // ----------------------------------------------------------------------------
    // member variables
    // ---------------------------------------------------------------------------
    self.UNKNOWN = "[unknown]";
    self.NOARTIST = "[unknown]";

    // ----------------------------------------------------------------------------
    // member functions
    // ---------------------------------------------------------------------------

    /**
     * Guess the artist name given in string is, and
     * returns the guessed name.
     *
     * @param	is		the inputstring
     * @returns os		the processed string
     **/
    self.process = function(is) {
	is = gc.artistmode.preProcessCommons(is);
	var w = gc.i.splitWordsAndPunctuation(is);
	gc.o.init();
	gc.i.init(is, w);
	while (!gc.i.isIndexAtEnd()) {
	    self.processWord();
	}
	var os = gc.o.getOutput();
        return gc.artistmode.runPostProcess(os);
    };


    /**
     * Checks special cases of artists
     * - empty, unknown -> [unknown]
     * - none, no artist, not applicable, n/a -> [no artist]
     **/
    self.checkSpecialCase = function(is) {
	if (is) {
	    if (!gc.re.ARTIST_EMPTY) {
		// match empty
		gc.re.ARTIST_EMPTY = /^\s*$/i;
		// match "unknown" and variants
		gc.re.ARTIST_UNKNOWN = /^[\(\[]?\s*Unknown\s*[\)\]]?$/i;
		// match "none" and variants
		gc.re.ARTIST_NONE = /^[\(\[]?\s*none\s*[\)\]]?$/i;
		// match "no artist" and variants
		gc.re.ARTIST_NOARTIST = /^[\(\[]?\s*no[\s-]+artist\s*[\)\]]?$/i;
		// match "not applicable" and variants
		gc.re.ARTIST_NOTAPPLICABLE = /^[\(\[]?\s*not[\s-]+applicable\s*[\)\]]?$/i;
		// match "n/a" and variants
		gc.re.ARTIST_NA = /^[\(\[]?\s*n\s*[\\\/]\s*a\s*[\)\]]?$/i;
	    }
	    var os = is;
	    if (is.match(gc.re.ARTIST_EMPTY)) {
		return self.SPECIALCASE_UNKNOWN;

	    } else if (is.match(gc.re.ARTIST_UNKNOWN)) {
		return self.SPECIALCASE_UNKNOWN;

	    } else if (is.match(gc.re.ARTIST_NONE)) {
		return self.SPECIALCASE_UNKNOWN;

	    } else if (is.match(gc.re.ARTIST_NOARTIST)) {
		return self.SPECIALCASE_UNKNOWN;

	    } else if (is.match(gc.re.ARTIST_NOTAPPLICABLE)) {
		return self.SPECIALCASE_UNKNOWN;

	    } else if (is.match(gc.re.ARTIST_NA)) {
		return self.SPECIALCASE_UNKNOWN;
	    }
	}
	return self.NOT_A_SPECIALCASE;
    };


    /**
     * Delegate function which handles words not handled
     * in the common word handlers.
     *
     * - Handles VersusStyle
     *
     **/
    self.doWord = function() {
	if (self.doVersusStyle()) {
	} else if (self.doPresentsStyle()) {
	} else {
	    // no special case, append
	    gc.o.appendSpaceIfNeeded();
	    gc.i.capitalizeCurrentWord();
	    gc.o.appendCurrentWord();
	}
	gc.f.resetContext();
	gc.f.number = false;
	gc.f.forceCaps = false;
	gc.f.spaceNextWord = true;
	return null;
    };

    /**
     * Reformat pres/presents -> presents
     *
     * - Handles DiscNumberStyle (DiscNumberWithNameStyle)
     * - Handles FeaturingArtistStyle
     * - Handles VersusStyle
     * - Handles VolumeNumberStyle
     * - Handles PartNumberStyle
     *
     **/
    self.doPresentsStyle = function() {
	if (!self.doPresentsRE) {
	    self.doPresentsRE = /^(presents?|pres)$/i;
	}
	if (gc.i.matchCurrentWord(self.doPresentsRE)) {
	    gc.o.appendSpace();
	    gc.o.appendWord("presents");
	    if (gc.i.isNextWord(".")) {
		gc.i.nextIndex();
	    }
	    return true;
	}
	return false;
    };

    /**
     * Guesses the sortname for artists
     **/
    self.guessSortName = function(is, person) {
	is = gc.u.trim(is);

	// let's see if we got a compound artist
	var collabSplit = " and ";
	collabSplit = (is.indexOf(" + ") != -1 ? " + " : collabSplit);
	collabSplit = (is.indexOf(" & ") != -1 ? " & " : collabSplit);

	var as = is.split(collabSplit);
	for (var splitindex=0; splitindex<as.length; splitindex++) {
	    var artist = as[splitindex];
	    if (!MB.utility.isNullOrEmpty(artist)) {
		artist = gc.u.trim(artist);
		var append = "";

		// strip Jr./Sr. from the string, and append at the end.
		if (!gc.re.SORTNAME_SR) {
		    gc.re.SORTNAME_SR = /,\s*Sr[\.]?$/i;
		    gc.re.SORTNAME_JR = /,\s*Jr[\.]?$/i;
		}
		if (artist.match(gc.re.SORTNAME_SR)) {
		    artist = artist.replace(gc.re.SORTNAME_SR, "");
		    append = ", Sr.";
		} else if (artist.match(gc.re.SORTNAME_JR)) {
		    artist = artist.replace(gc.re.SORTNAME_JR, "");
		    append = ", Jr.";
		}
		var names = artist.split(" ");

		// handle some special cases, like DJ, The, Los which
		// are sorted at the end.
		var reorder = false;
		if (!gc.re.SORTNAME_DJ) {
		    gc.re.SORTNAME_DJ = /^DJ$/i; // match DJ
		    gc.re.SORTNAME_THE = /^The$/i; // match The
		    gc.re.SORTNAME_LOS = /^Los$/i; // match Los
		    gc.re.SORTNAME_DR = /^Dr\.$/i; // match Dr.
		}
		var firstName = names[0];
		if (firstName.match(gc.re.SORTNAME_DJ)) {
		    append = (", DJ" + append); // handle DJ xyz -> xyz, DJ
		    names[0] = null;
		} else if (firstName.match(gc.re.SORTNAME_THE)) {
		    append = (", The" + append); // handle The xyz -> xyz, The
		    names[0] = null;
		} else if (firstName.match(gc.re.SORTNAME_LOS)) {
		    append = (", Los" + append); // handle Los xyz -> xyz, Los
		    names[0] = null;
		} else if (firstName.match(gc.re.SORTNAME_DR)) {
		    append = (", Dr." + append); // handle Dr. xyz -> xyz, Dr.
		    names[0] = null;
		    reorder = true; // reorder doctors.
		} else {
		    reorder = true; // reorder by default
		}

                if (!person)
                {
                    reorder = false; // only reorder persons, not groups.
                }

		// we have to reorder the names
		var i=0;
		if (reorder) {
		    var reOrderedNames = [];
		    if (names.length > 1) {
			for (i=0; i<names.length-1; i++) {
			    // >> firstnames,middlenames one pos right
			    if (i == names.length-2 && names[i] == "St.") {
				names[i+1] = names[i] + " " + names[i+1];
				// handle St. because it belongs
				// to the lastname
			    } else if (!MB.utility.isNullOrEmpty(names[i])) {
				reOrderedNames[i+1] = names[i];
			    }
			}
			reOrderedNames[0] = names[names.length-1]; // lastname,firstname
			if (reOrderedNames.length > 1) {
			    // only append comma if there was more than 1
			    // non-empty word (and therefore switched)
			    reOrderedNames[0] += ",";
			}
			names = reOrderedNames;
		    }
		}
		var t = [];
		for (i=0; i<names.length; i++) {
		    var w = names[i];
		    if (!MB.utility.isNullOrEmpty(w)) {
			// skip empty names
			t.push(w);
		    }
		    if (i < names.length-1) {
			// if not last word, add space
			t.push(" ");
		    }
		}

		// append string
		if (!MB.utility.isNullOrEmpty(append)) {
		    t.push(append);
		}
		artist = gc.u.trim(t.join(""));
	    }
	    if (!MB.utility.isNullOrEmpty(artist)) {
		as[splitindex] = artist;
	    } else {
		delete as[splitindex];
	    }
	}
	return gc.u.trim(as.join(collabSplit));
    };

    return self;
};
