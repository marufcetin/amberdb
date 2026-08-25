#!/usr/bin/perl

# t/amberdb/amberdb_string.t - Comprehensive tests for AmberDB::String

use 5.016000;
use strict;
use warnings;
use Test::More;

use lib 'lib';
use AmberDB::String;

my $str = AmberDB::String->new();
isa_ok( $str, 'AmberDB::String' );

# ---------------------------------------------------------------------------
subtest '1. trim_space & space normalization' => sub {
    plan tests => 4;

    my $raw = "   hello   world   \t  \r\n  new   line   ";
    my $trimmed = $str->trim_space($raw);
    ok( $trimmed =~ /^hello/, "Leading whitespace trimmed" );
    ok( $trimmed =~ /line$/, "Trailing whitespace trimmed" );

    my $flat = $str->trim_space($raw, 1);
    is( $flat, "hello world new line", "Flatten mode collapses all whitespace to single spaces" );

    my $commas = "item1 , item2 ; item3";
    is( $str->trim_space($commas, 1), "item1,item2;item3", "Spacing around punctuation trimmed" );
};

# ---------------------------------------------------------------------------
subtest '2. remove_tags, text2html & html2text' => sub {
    plan tests => 5;

    my $html_in = "<div><p>Paragraph 1</p><br><p>Paragraph 2 <script>alert(1);</script></p></div>";
    my $no_tags = $str->remove_tags($html_in);
    unlike( $no_tags, qr/<[^>]+>/, "HTML tags removed" );
    like( $no_tags, qr/Paragraph 1/, "Text content preserved in remove_tags" );

    my $plain = "First line\n\nSecond line with & special <characters>";
    my $to_html = $str->text2html($plain);
    like( $to_html, qr/<p>First line<\/p>/, "Paragraphs created" );
    like( $to_html, qr/&amp;.*&lt;characters&gt;/, "HTML entities escaped" );

    my $converted_back = $str->html2text($to_html);
    like( $converted_back, qr/First line\n\nSecond line with & special <characters>/, "Bidirectional roundtrip preserved" );
};

# ---------------------------------------------------------------------------
subtest '3. sub_str, short_title, truncate_text & str_code' => sub {
    plan tests => 6;

    my $long_text = "This is a very long string that needs proper shortening for UI display.";
    my $sub = $str->sub_str($long_text, 25);
    like( $sub, qr/\.\.\.$/, "sub_str ends with ellipsis" );
    ok( length($sub) <= 25, "sub_str respects length limit" );

    my $title = "AmberDB: High Performance Embedded Database Engine";
    my $short = $str->short_title($title, 20);
    like( $short, qr/\.\.\.$/, "short_title ends with ellipsis" );

    my $trunc = $str->truncate_text($long_text, 30);
    like( $trunc, qr/\.\.\.$/, "truncate_text ends with ellipsis" );

    my $code1 = $str->str_code("Electronics Product Item");
    is( length($code1), 8, "str_code produces exact 8-character code" );
    is( $code1, "ELECTRON", "str_code extracts first word uppercase ASCII code" );
};

# ---------------------------------------------------------------------------
subtest '4. what_isthis content classification' => sub {
    plan tests => 11;

    is( $str->what_isthis(""), "none", "Empty string is none" );
    is( $str->what_isthis("   "), "space", "Spaces identified as space" );
    is( $str->what_isthis("test.user_12\@example.com"), "email", "Email identified" );
    is( $str->what_isthis("8690123456789"), "barcode", "EAN13 barcode identified" );
    is( $str->what_isthis("05321234567"), "gsm", "GSM phone number identified" );
    is( $str->what_isthis("02123456789"), "phone", "Landline phone identified" );
    is( $str->what_isthis("12345678901"), "tcno", "11-digit TCNO identified" );
    is( $str->what_isthis("987654"), "number", "Generic number identified" );
    is( $str->what_isthis("AmberDB2026"), "ascii", "Alphanumeric ascii identified" );
    is( $str->what_isthis("example.com"), "domain", "Domain name identified" );
    is( $str->what_isthis("#%*?"), "other", "Special characters identified as other" );
};

# ---------------------------------------------------------------------------
subtest '5. html_ascode and code_ashtml encoding' => sub {
    plan tests => 2;

    my $special = qq{& " \$ < > \@};
    my $coded = $str->html_ascode($special);
    like( $coded, qr/&#38;.*&#34;.*&#36;.*&#60;.*&#62;.*&#64;/, "Special characters escaped to entity codes" );

    my $coded2 = $str->code_ashtml($special);
    like( $coded2, qr/&#38;#60;/, "code_ashtml produces entity codes" );
};

done_testing();
