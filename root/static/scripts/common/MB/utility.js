/* Copyright (C) 2009 Oliver Charles
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

MB.utility.keys = function (obj) {
    var ret = [];
    for (var key in obj) {
        if (obj.hasOwnProperty (key))
        {
            ret.push (key);
        }
    }

    return ret;
};

MB.utility.displayedValue = function(element) {
    if(element.is('select')) {
        return element.find(':selected').text();
    }
    else if (element.is('input[type=text]')) {
        return element.val();
    }
};

/* Convert fullwidth characters to standard halfwidth Latin. */
MB.utility.fullWidthConverter = function (inputString) {
    if (inputString === "") {
        return "";
    }

    i = inputString.length;
    newString = [];

    do {
        newString.push (
            inputString[i-1].replace (/([\uFF01-\uFF5E])/g, function (str, p1) {
                return String.fromCharCode (p1.charCodeAt(0) - 65248);
            })
        );
    } while (--i);

    return newString.reverse ().join("");
};

MB.utility.isArray  = function(o) { return (o instanceof Array    || typeof o == "array"); };
MB.utility.isString = function(o) { return (o instanceof String   || typeof o == "string"); };
MB.utility.isNullOrEmpty = function(o) { return (!o || o == ""); };
MB.utility.is_ascii = function (str) { return ! /[^\u0000-\u00ff]/.test(str); };

MB.utility.template = function(str) {
    var self = MB.Object();

    var draw = function (o) {
        return str.replace(/#{([^{}]*)}/g,
            function (a, b) {
                var r = o[b];
                return typeof r === 'string' || typeof r === 'number' ? r : a;
            });
    };

    self.draw = draw;

    return self;
};

MB.utility.load_data = function (files, loaded, callback) {
    var uri = files.pop ();

    if (uri)
    {
        jQuery.get (uri, function (data) {
            loaded[uri] = data;

            MB.utility.load_data (files, loaded, callback);
        });
    }
    else
    {
        callback (loaded);
    }
};

MB.utility.exception = function (name, message) {
    var e = function () { this.name = name,  this.message = message };
    e.prototype = new Error ();

    return new e ();
};

MB.utility.clone = function (input) { return jQuery.extend (true, {}, input); }

MB.utility.escapeHTML = function (str) {
    if (!str) return '';

    return str.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
}

/* structureToString renders a structure to a string.  It is similar to
   serializing a structure, but intended as input to a hash function.

   The output string is not easily deserialized.
*/
MB.utility.structureToString = function (obj) {
    if (MB.utility.isString (obj))
    {
        return obj;
    }
    else if (MB.utility.isArray (obj))
    {
        var ret = [];
        $.each (obj, function (idx, item) {
            ret.push (MB.utility.structureToString (item));
        });

        return '[' + ret.join (",") + ']';
    }
    else
    {
        var keys = MB.utility.keys (obj);
        keys.sort ();

        var ret = [];
        $.each (keys, function (idx, key) {
            ret.push (key + ":" + MB.utility.structureToString (obj[key]));
        });

        return '{' + ret.join (",") + '}';
    }
};


/* Set a particular button to be the default submit action for a form. */
MB.utility.setDefaultAction = function (form, button) {

    $(form).prepend (
        $(button).clone ().css ({
           position: 'absolute',
           left: "-999px", top: "-999px", height: 0, width: 0
        }));

};
