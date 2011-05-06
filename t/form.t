#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

{
    package TestForm;
    use HTML::FormHandler::Moose;

    extends 'MusicBrainz::Server::Form';

    has '+name' => ( default => 'form' );

    has_field 'foo' => ( type => 'Compound' );
    has_field 'foo.bar' => ( type => 'Repeatable' );
    has_field 'foo.bar.contains';

    has_field 'foo.baz' => ( type => 'Repeatable', num_when_empty => 0 );
    has_field 'foo.baz.qux' => ( type => 'Text' );
}

my $form = TestForm->new( init_object => { foo => { } } );
my $field = $form->field('foo')->field('bar');
my $subfields = $field->fields;
is(scalar(@$subfields), 1);
# Workaround for HTML::FormHandler, which will let the field be named
# 'contains' if there is no value in init_object for it.
is($subfields->[0]->name, '0');
is($subfields->[0]->html_name, 'form.foo.bar.0');

$form = TestForm->new( );
$form->process (
    params => {
        'form.foo.bar.0' => 'Blood on Borstch',
        'form.foo.baz.0.qux' => 'Ambient Intelligence',
        'form.foo.baz.1.qux' => 'Warlords of Destruction',
        'form.foo.baz.2.qux' => 'Boarboyz Attack',
    }
);

$subfields = $form->field('foo.baz')->fields;
is(scalar(@$subfields), 3, "non-empty repeatable has three fields");

$form->field('foo.baz.0.qux')->disabled (1);
$form->field('foo.baz.1.qux')->readonly (1);
$form->field('foo.baz.2.qux')->style ('border: 2px dashed red');
$form->field('foo.baz.2.qux')->css_class ('error');
$form->field('foo.baz.2.qux')->javascript ('alert("wait, wat?")');

my $data = $form->serialize;

$form = TestForm->new;
$form->unserialize ($data);

is ($form->field('foo.bar.0')->value, 'Blood on Borstch', 'first value restored correctly');
is ($form->field('foo.baz.0.qux')->value, 'Ambient Intelligence', 'second value restored correctly');
is ($form->field('foo.baz.1.qux')->value, 'Warlords of Destruction', 'third value restored correctly');
is ($form->field('foo.baz.2.qux')->value, 'Boarboyz Attack', 'fourth value restored correctly');

is ($form->field('foo.baz.0.qux')->disabled, 1, 'first field is disabled');
is ($form->field('foo.baz.0.qux')->readonly, undef, 'first field is not readonly');
is ($form->field('foo.baz.1.qux')->disabled, undef, 'second field is not disabled');
is ($form->field('foo.baz.1.qux')->readonly, 1, 'second field is readonly');
is ($form->field('foo.baz.2.qux')->style, 'border: 2px dashed red', 'third field has style');
is ($form->field('foo.baz.2.qux')->css_class, 'error', 'third field has error class');
is ($form->field('foo.baz.2.qux')->javascript, 'alert("wait, wat?")', 'third field has alert');

done_testing;
