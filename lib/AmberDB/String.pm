package AmberDB::String;

use 5.016;
use warnings;
use Carp qw(croak cluck);
use parent 'AmberDB::Locale';

our $VERSION = '5.0';
my $CREATED = '2017-12-31';

# Constructor...
# ---------------------------------------------------------------------
sub new {
    my $class = shift;
    return $class->SUPER::new(@_);
}

# my $new_string = $String->sub_str($string, 30);
# ---------------------------------------------------------------------
sub sub_str {

    my ( $self, $string, $length ) = @_;

    my $length2 = $length - 4;
    $length2 > 0 or return $string;

    if ( length($string) >= $length ) {
        $string = substr( $string, 0, $length2 );
        $string =~ s/^(.*) .*/$1/;
        $string .= " ...";
    }

    $string or return;
}

# ...
# ---------------------------------------------------------------------
sub trim_space {

    my ( $self, $string, $flatten ) = @_;

    $string or return;

    $string =~ s/ / /g;
    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    $string =~ s/\r\n/\n/g;

    if ($flatten) {
        $string =~ s/[\r\n\t\s]+/ /g;
        $string =~ s/ *([,;]) */$1/g;
        $string =~ s/^\s+//;
        $string =~ s/\s+$//;
    }
    else {
        $string =~ s/\n/\\n/g;
        $string =~ s/\t/\\t/g;
        $string =~ s/\s+/ /g;
        $string =~ s/ *([,;]) */$1/g;
        $string =~ s/ *\\n */\n/g;
        $string =~ s/ *\\t */\t/g;
    }

    return $string;
}

# $content = $String->remove_tags($content);
# ------------------------------------------------
sub remove_tags {

    my ( $self, $data ) = @_;

    $data =~ s/<br\s*\/?>/\\n/gi;
    $data =~ s/<\/?p[^>]*>/\\n/gi;
    $data =~ s/<\/?div[^>]*>/\\n/gi;
    $data =~ s/<[^>]+>//g;
    $data =~ s/\\n/\n/g;
    $data = $self->trim_space($data);

    return $data;
}

# ...
# ---------------------------------------------------------------------
sub html_ascode {

    my ( $self, $string ) = @_;

    $string or return;

    $string =~ s/\&/&#38;/g;
    $string =~ s/\"/&#34;/g;
    $string =~ s/\$/&#36;/g;
    $string =~ s/</&#60;/g;
    $string =~ s/>/&#62;/g;
    $string =~ s/\@/&#64;/g;

    return $string;
}

# ...
# ---------------------------------------------------------------------
sub code_ashtml {

    my ( $self, $string ) = @_;

    $string or return;

    $string =~ s/\"/&#34;/g;
    $string =~ s/\$/&#36;/g;
    $string =~ s/\</&#60;/g;
    $string =~ s/\>/&#62;/g;
    $string =~ s/\@/&#64;/g;
    $string =~ s/\&/&#38;/g;

    return $string;
}

# my $whatisthis = $String->what_isthis($string);
# ---------------------------------------------------------------------
sub what_isthis {

    my ( $self, $string ) = @_;

    # Build locale-aware letter pattern (uses locale alphabet_chars if available)
    my $alpha_extra = ( $self->{_locale} && $self->{_locale}{alphabet_chars} )
        ? $self->{_locale}{alphabet_chars}
        : '';
    my $letter_re = qr/^[a-zA-Z${alpha_extra}]+$/;

    my $result;
    if    ( !$string )                                  { $result = "none" }
    elsif ( $string =~ /^\s+$/ )                        { $result = "space" }
    elsif ( $string =~ /^[\w\_\.]+\@[\w]+(\.[\w]+)+$/ ) { $result = "email" }
    elsif ( $string =~ /^[89][0-9]{12}$/ )              { $result = "barcode" }
    elsif ( $string =~ /^(0|90|\+90)?5[0-9]{2} ?[0-9]{3} ?[0-9]{2} ?[0-9]{2}$/ )
    {
        $result = "gsm";
    }
    elsif (
        $string =~ /^(0|90|\+90)[234][0-9]{2} ?[0-9]{3} ?[0-9]{2} ?[0-9]{2}$/ )
    {
        $result = "phone";
    }
    elsif ( $string =~ /^[1-9][0-9]{10}$/ )        { $result = "tcno" }
    elsif ( $string =~ /^[1-9][0-9]*$/ )           { $result = "number" }
    elsif ( $string =~ /^[a-zA-Z0-9]+$/ )          { $result = "ascii" }
    elsif ( $string =~ $letter_re )                { $result = "letter" }
    elsif ( $string =~ /^[\w]+(\.[\w]+)+$/ )       { $result = "domain" }
    elsif ( $string =~ /[^\w\_\.\,\/\-]/ )         { $result = "other" }

    # none, space, email, barcode, gsm, phone, tcno, ascii, other

    # TODO
    # sentence, paragraph, word, date

    return $result;
}

# my $short = $String->short_title($title, $limit);
# ---------------------------------------------------------------------
sub short_title {

    my ( $self, $str, $lmt ) = @_;

    $str or return;
    $lmt ||= 32;
    $lmt >= 6 or $lmt = 16;
    my $cut = $lmt - 3;

    $str = $self->to_ascii($str);
    $str =~ s/[^a-z0-9\-\s]//gi;

    if ( length($str) > $lmt ) {
        $str =~ s/<[^>]+>//g;
        $str =~ s/[&;,'"']//g;
        $str = $self->substring( $str, $cut );
        $str =~ s/^(.*) .*$/$1 .../g;
    }
    return $str;
}

# my $short = $String->truncate_text($text, $length);
# ---------------------------------------------------------------------
sub truncate_text {

    my ( $self, $text, $length ) = @_;

    $text          or return;
    $length >= 8   or return;
    my $length2 = $length - 3;

    if ( length($text) > $length ) {
        $text =~ s/<[^>]+>//g;
        $text =~ s/[&;,'"']//g;
        $text = $self->trim_space($text);
        $text = $self->substring( $text, $length2 );
        $text =~ s/^(.*) .*$/$1 .../g;
    }
    return $text;
}

# my $code = $String->str_code($name);
# 8-char uppercase ASCII code from first word of string
# ---------------------------------------------------------------------
sub str_code {

    my ( $self, $str ) = @_;

    $str or return;

    $str =~ s/^([^\s]+) .*/$1/;
    $str = uc( $self->to_ascii($str) );
    $str =~ s/\s+//g;

    if ( length($str) > 8 ) {
        $str = $self->substring( $str, 8 );
    }
    if ( length($str) < 8 ) {
        $str .= ( 8 - length($str) ) x " ";
    }

    return $str;
}

# my $html = $String->text2html($text);
# ---------------------------------------------------------------------
sub text2html {

    my ( $self, $text ) = @_;

    $text //= '';

    # Skip if string already contains HTML elements
    return $text if $text =~ /<(?:p|br|div|ul|ol|h[1-6])\b/i;

    # Normalize line endings (\r\n and \r -> \n)
    $text =~ s/\r\n|\r/\n/g;

    # Escape &, <, > characters for XSS protection
    $text =~ s/&/&amp;/g;
    $text =~ s/</&lt;/g;
    $text =~ s/>/&gt;/g;

    # Convert double (or more) line breaks to paragraph blocks
    my @paragraphs = split /\n{2,}/, $text;
    for my $para (@paragraphs) {
        # Convert single line break inside paragraph to <br>
        $para =~ s/\n/<br>\n/g;
        $para = "<p>$para</p>";
    }
    $text = join "\n", @paragraphs;

    return $text;
}

# my $text = $String->html2text($html);
# ---------------------------------------------------------------------
sub html2text {

    my ( $self, $string ) = @_;

    $string //= '';

    # 1. Strip script and style blocks completely
    $string =~ s/<script[^>]*>.*?<\/script>//gis;
    $string =~ s/<style[^>]*>.*?<\/style>//gis;

    # 2. Convert headers to separated line text
    $string =~ s/<h[1-3][^>]*>\s*(.*?)\s*<\/h[1-3]>/\n\u$1\n/gis;
    $string =~ s/<h[4-6][^>]*>\s*(.*?)\s*<\/h[4-6]>/\n$1\n/gis;

    # 3. Convert paragraph and block elements to double line breaks
    $string =~ s/<\/?(p|div|section|article|blockquote|table|thead|tbody|tr|ul|ol)[^>]*>/\n\n/gi;

    # 4. Format list items with bullet points
    $string =~ s/<li[^>]*>\s*(.*?)\s*<\/li>/\n- $1/gis;
    $string =~ s/<li[^>]*>/\n- /gi;

    # 5. Convert <br> tags to single line breaks
    $string =~ s/<br\s*\/?>/\n/gi;

    # 6. Strip remaining HTML tags
    $string =~ s/<[^>]+>//g;

    # 7. Decode HTML entities
    $string =~ s/&amp;/&/g;
    $string =~ s/&lt;/</g;
    $string =~ s/&gt;/>/g;
    $string =~ s/&quot;/"/g;
    $string =~ s/&#39;/'/g;
    $string =~ s/&nbsp;/ /g;

    # 8. Clean leading/trailing spaces per line and reduce whitespace
    $string =~ s/[ \t]+/ /g;
    $string =~ s/^ +| +$//mg;

    # 9. Collapse multiple empty lines
    $string =~ s/\n{3,}/\n\n/g;
    $string =~ s/^\s+|\s+$//g;

    return $string;
}

1;

__END__

=head1 NAME

AmberDB::String - String manipulation, HTML conversion, and text sanitization utility

=head1 SYNOPSIS

  use AmberDB::String;
  my $str_util = AmberDB::String->new();

  my $truncated = $str_util->sub_str($long_text, 50);
  my $html      = $str_util->text2html($plain_text);
  my $clean     = $str_util->html2text($html_content);

=head1 DESCRIPTION

C<AmberDB::String> inherits from C<AmberDB::Locale> and provides utility methods for string
truncation, HTML tag stripping, entity escaping, and bidirectional conversion between plain text and HTML.

=head1 METHODS

=head2 new()

Constructor for C<AmberDB::String>.

=head2 sub_str($string, $length)

Truncates a string to specified length, ending with " ...".

=head2 trim_space($string)

Removes leading, trailing, and redundant internal whitespace characters.

=head2 remove_tags($data)

Strips HTML tags while preserving line breaks.

=head2 text2html($text)

Converts plain text to HTML with paragraph tags and line breaks.

=head2 html2text($html)

Converts HTML formatted content back into plain text.

=head1 AUTHOR

Maruf Cetin <marufcetin@gmail.com>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2017-2026 Maruf Cetin.

This library is free software; you can redistribute it and/or modify it under the terms of the Artistic License 2.0.

=cut
