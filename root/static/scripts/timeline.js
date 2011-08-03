$(document).ready(function () {
    var categoryIDPrefix = 'category-';
    var controlIDPrefix = 'graph-control-';

    var datasets = {};
    var musicbrainzEventsOptions = {musicbrainzEvents: { currentEvent: {}, data: [], enabled: true}}
    var graphOptions = {};
    var overviewOptions = {};
    var graphZoomOptions = {};
    var lastHash = null;

    // MusicBrainz Events fetching
    $.get('/static/xml/mb_history.xml', function (data) {
        $(data).find('event').each(function() {
            $this = $(this);
            musicbrainzEventsOptions.musicbrainzEvents.data.push({jsDate: Date.parse($this.attr('start')), description: $this.text(), title: $this.attr('title'), link: $this.attr('link')});
        });
        $(window).hashchange();
    }, 'xml');

    function graphData () {
        var alldata =  [];
        $("#graph-lines div input").filter(":checked").each(function () { 
            if ($(this).parents('div.graph-category').prev('.toggler').children('input:checkbox').attr('checked')) {
                alldata.push(datasets[$(this).parent('div.graph-control').attr('id').substr(controlIDPrefix.length)]);
            }
        });
        return alldata
    }

    function jq(myid) { 
        return '#' + myid.replace(/(:|\.)/g,'\\$1');
    }

    // Make selections zoom
    $('#graph-container').bind('plotselected', function (event, ranges) {
        // clamp the zooming to prevent eternal zoom
        if (ranges.xaxis.to - ranges.xaxis.from < 86400000)
        ranges.xaxis.to = ranges.xaxis.from + 86400000;
    if (ranges.yaxis.to - ranges.yaxis.from < 1)
        ranges.yaxis.to = ranges.yaxis.from + 1;

    // do the zooming
    graphZoomOptions = {
            xaxis: { min: ranges.xaxis.from, max: ranges.xaxis.to },
            yaxis: { min: ranges.yaxis.from, max: ranges.yaxis.to }}

    removeFromHash('g-([0-9.e]+-){3}[0-9.e]+');
    changeHash(false, hashPartFromGeometry(graphZoomOptions), true);
    });

    $('#overview').bind('plotselected', function(event, ranges) {
        plot.setSelection(ranges);
    });

    // "Reset Graph" functionality
    $('#graph-container, #overview').bind('plotunselected', function () { 
        if (!plot.getOptions().musicbrainzEvents.currentEvent.link) 
        {
            graphZoomOptions = {};
            removeFromHash('g-([0-9.e]+-){3}[0-9.e]+');
        } else {
            // we're clicking on an event, should open the link instead
            window.open(plot.getOptions().musicbrainzEvents.currentEvent.link);
        }
    });

    // Hover functionality
    function showTooltip(x, y, contents) {
        $('<div id="tooltip">' + contents + '</div>').css( {
            position: 'absolute',
            display: 'none',
            top: y + 5,
            left: x + 5,
            border: '1px solid #fdd',
            padding: '2px',
            'background-color': '#fee',
            opacity: 0.80
        }).appendTo("body").fadeIn(200);
    }
    function removeTooltip() {
        $('#tooltip').remove();
    }
    function setCursor(type) {
        if (!type) {
            type = '';
        }
        $('body').css('cursor', type);
    }
    function changeCurrentEvent(item) {
        musicbrainzEventsOptions.musicbrainzEvents.currentEvent = item;
        plot.changeCurrentEvent(item);
    }

    var previousPoint = null;
    $('#graph-container').bind('plothover', function (event, pos, item) { 
        if(item) {
            if (previousPoint != item.dataIndex) {
                previousPoint = item.dataIndex;

                removeTooltip();
                setCursor();
                var x = item.datapoint[0],
                    y = item.datapoint[1],
                    date = new Date(parseInt(x));

                if (date.getDate() < 10) { day = '0' + date.getDate(); } else { day = date.getDate(); }
                if (date.getMonth()+1 < 10) { month = '0' + (date.getMonth()+1); } else { month = date.getMonth()+1; }

                showTooltip(item.pageX, item.pageY,
                    date.getFullYear() + '-' + month + '-' + day + ": " + y + " " + item.series.label);
                changeCurrentEvent({});
            }
        } else if (plot.getEvent(pos)) {
                var thisEvent = plot.getEvent(pos);
                if (musicbrainzEventsOptions.musicbrainzEvents.currentEvent.jsDate != thisEvent.jsDate) {
                    removeTooltip();
                    setCursor('pointer');
                    showTooltip(pos.pageX, pos.pageY, '<h2 style="margin-top: 0px; padding-top: 0px">' + thisEvent.title + '</h2>' + thisEvent.description);

                    changeCurrentEvent(thisEvent);
                }
        } else {
            setCursor();
            removeTooltip();
            previousPoint = null;

            changeCurrentEvent({});
        }
    });

    function hashPartFromGeometry(geometry) {
        var blah = 'g-' + geometry.xaxis.min + '-' + geometry.xaxis.max + '-' + geometry.yaxis.min + '-' + geometry.yaxis.max;
        return blah;
    }

    function geometryFromHashPart(hashPart){
        var hashParts = hashPart.substr(2).split('-');
        return { xaxis: { min: parseFloat(hashParts[0]), max: parseFloat(hashParts[1]) }, yaxis: { min: parseFloat(hashParts[2]), max: parseFloat(hashParts[3]) }};
    }

    function changeHash(minus, newHashPart, hide) {
        if (!new RegExp('\\+?-?' + newHashPart + '(?=($|\\+))').test(location.hash)) {
            if (hide != minus) {
                window.location.hash = location.hash + (location.hash != '' ? '+' : '') + (minus ? '-' : '') + newHashPart;
            }
        } else {
            if (hide != minus) {
                window.location.hash = location.hash.replace(new RegExp('-?' + newHashPart + '(?=($|\\+))'), (minus ? '-' : '') + newHashPart);
            } else { 
                removeFromHash('-?' + newHashPart);
            }
        }
    }

    function removeFromHash(toRemove) {
        var regex = new RegExp('\\+?' + toRemove + '(?=($|\\+))')
        window.location.hash = location.hash.replace(regex , '');
    }

    function check(name, toggle, categoryp) {
        if (categoryp) {
            var $checkboxParent = $(jq(categoryIDPrefix + name)).prev('.toggler');
        } else {
            var $checkboxParent = $(jq(controlIDPrefix + 'count.' + name));
        }
        $checkboxParent.children('input:checkbox').attr('checked', toggle).change();
    }

    $(window).hashchange(function () {
        if (lastHash != location.hash) {
            lastHash = location.hash;
            var hash = location.hash.replace( /^#/, '' );
            var queries = hash.split('+');

            $.each(queries, function (index, value) {
                var remove = (value.substr(0,1) == '-');
                if (remove) {
                    value = value.substr(1);
                }
                var category = (value.substr(0,2) == 'c-');
                if (category) {
                    value = value.substr(2);
                }
                if (!(value.substr(0,2) == 'g-')) {
                    check(value, !remove, category);
                } else if (value.substr(0,2) == 'g-') {
                    graphZoomOptions = geometryFromHashPart(value);
                }
            });
        }
        resetPlot();
    });


    function resetPlot () {
        var data = graphData();
        plot = $.plot($("#graph-container"), data, 
            $.extend(true, {}, graphOptions, graphZoomOptions, musicbrainzEventsOptions));
        plot.triggerRedrawOverlay();
        overview = $.plot($('#overview'), data, overviewOptions);
    }

    MB.setupGraphing = function (data, goptions, ooptions) {
        datasets = data;
        graphOptions = goptions;
        overviewOptions = ooptions;

        $.each(datasets, function(key, value) { 
            if ($(jq(controlIDPrefix + key)).length == 0) {
                if ($('#' + categoryIDPrefix + value.category).length == 0) {
                    $('#graph-lines').append('<h2 class="toggler"><input id="' + categoryIDPrefix + 'checker-' + value.category + '" type="checkbox" checked /><label for="' + categoryIDPrefix + 'checker-' + value.category + '">' + MB.text.Timeline.Category[value.category].Label + '</label></h2>');
                    $('#graph-lines').append('<div class="graph-category" id="' + categoryIDPrefix + value.category + '"></div>');
                }
                $("#graph-lines #" + categoryIDPrefix + value.category).append('<div class="graph-control" id="' + controlIDPrefix + key + '"><input id="' + controlIDPrefix + 'checker-' + key + '" name="' + controlIDPrefix + key + '" type="checkbox" checked /><label for="' + controlIDPrefix + 'checker-' + key + '"><div class="graph-color-swatch" style="background-color: ' + MB.text.Timeline[key].Color + ';"></div>' + value.label + '</label></div>'); 
            }
        });
        // // Toggle functionality
        $('#graph-lines div input:checkbox').change(function () {
            var $this = $(this);
            var minus = !$this.attr('checked');
            var identifier = $this.parent('div').attr('id').substr(controlIDPrefix.length);
            var newHashPart = identifier.substr('count.'.length);
            var hide = (MB.text.Timeline[identifier].Hide ? true : false);
            changeHash(minus, newHashPart, hide);
            
            if (minus) {
                    $this.siblings('label').children('div.graph-color-swatch').css('background-color', '#ccc');
            } else {
                    $this.siblings('label').children('div.graph-color-swatch').css('background-color',
                            MB.text.Timeline[identifier].Color);
            }

        });
        $('#graph-lines .toggler input:checkbox').change(function () {
            var $this = $(this);

            var categoryId = $this.parent('.toggler').next('div.graph-category').attr('id');
            var minus = !$this.attr('checked');
            var newHashPart = categoryId.replace(new RegExp(categoryIDPrefix), 'c-');
            var hide = (MB.text.Timeline.Category[categoryId.substr(categoryIDPrefix.length)].Hide ? true : false);
            changeHash(minus, newHashPart, hide);
    
            $this.parent('.toggler').next()[minus ? 'hide' : 'show']('slow');
        });

       $('#disable-events-checkbox').change(function () {
           var $this = $(this);
           musicbrainzEventsOptions.musicbrainzEvents.enabled = $this.attr('checked');
	   $(window).hashchange();
       });

        $('div.graph-category').each(function () {
            var category = $(this).attr('id').substr(categoryIDPrefix.length);
            if (MB.text.Timeline.Category[category].Hide && !(new RegExp('\\+?-?c-' + category + '(?=($|\\+))').test(location.hash))) {
                $(this).prev('.toggler').children('input:checkbox').attr('checked', false).change();
            }
        });

        $('div.graph-control').each(function () {
            var identifier = $(this).attr('id').substr(controlIDPrefix.length);
            if (MB.text.Timeline[identifier].Hide && !(new RegExp('\\+?-?' + identifier.substr('count.'.length) + '(?=($|\\+))').test(location.hash))) {
                $(this).children('input:checkbox').attr('checked', false).change();
            }
        });


        $(window).hashchange();
    }


});
