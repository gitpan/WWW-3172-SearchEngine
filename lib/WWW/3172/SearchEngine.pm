package WWW::3172::SearchEngine;
use strict;
use warnings;
use Dancer ':syntax';
use Dancer::Plugin::Database;
# ABSTRACT: An interface to a search engine index of pages crawled by WWW::3172::Crawler
our $VERSION = '0.001'; # VERSION

use WWW::Form;
use HTML::Entities qw(encode_entities);
use List::MoreUtils qw(uniq);
use Lingua::Stem::Snowball;
use Lingua::StopWords qw(getStopWords);
use Text::Unidecode qw(unidecode);

my $stopwords = getStopWords('en');
my $stemmer   = Lingua::Stem::Snowball->new(
    lang    => 'en',
    encoding=> 'UTF-8',
);

get '/' => sub {
    my $form = WWW::Form->new(
        { 'q' => { label => 'Search query', type => 'text' } },
        { 'q' => '' },
        ['q']
    );

    template 'index', {
        form => $form->getFormHTML(
            action  => '/s',
            name    => 'search-form',
            submit_label => 'Search',
        ),
    };
};

any ['get', 'post'] => '/s' => sub {
    my $query = params->{q};

    my @words;
    {
        my $punct = quotemeta q{.,[]()<>{}+-=_'"\|};
        my @split = map { ## no critic (ControlStructures::ProhibitMutatingListFunctions)
            s{\A[$punct]}{};
            s{[$punct]\Z}{};

            length($_) < 2 || exists $stopwords->{$_}
                ? ()
                : unidecode($_)
        } split /\s+/, $query;
        @words = $stemmer->stem([uniq @split]);
    }
    redirect '/' unless @words;

    my $sql = sprintf(<<'SQL', (('?,' x (scalar(@words) - 1)) . '?' ) );
SELECT url_str FROM url WHERE url_id in (
    SELECT url_id FROM url_words WHERE word_id in (
        SELECT word_id FROM words WHERE word_str in (%s)
    ) ORDER BY url_word_count DESC
)
SQL

    my $sth = database->prepare($sql);
    $sth->execute(@words);

    my @urls;
    while (my $data = $sth->fetchrow_hashref) {
        push @urls, $data->{url_str};
    }

    return template 'results', {
        results => '<p>No results were found for <strong>' . encode_entities($query) . '</strong></p>'
    } unless @urls;

    my $html = '<ul>';
    foreach my $url (@urls) {
        my $safe_url = encode_entities($url);
        $html .= "<li><a href='$safe_url'>$safe_url</a></li>\n";
    }
    $html .= '</ul>';

    template 'results', { results => $html };
};

true;


__END__
=pod

=encoding utf-8

=head1 NAME

WWW::3172::SearchEngine - An interface to a search engine index of pages crawled by WWW::3172::Crawler

=head1 VERSION

version 0.001

=head1 AVAILABILITY

The latest version of this module is available from the Comprehensive Perl
Archive Network (CPAN). Visit L<http://www.perl.com/CPAN/> to find a CPAN
site near you, or see L<http://search.cpan.org/dist/WWW-3172-SearchEngine/>.

The development version lives at L<http://github.com/doherty/WWW-3172-SearchEngine>
and may be cloned from L<git://github.com/doherty/WWW-3172-SearchEngine.git>.
Instead of sending patches, please fork this project using the standard
git and github infrastructure.

=head1 SOURCE

The development version is on github at L<http://github.com/doherty/WWW-3172-SearchEngine>
and may be cloned from L<git://github.com/doherty/WWW-3172-SearchEngine.git>

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests through the web interface at
L<https://github.com/doherty/WWW-3172-SearchEngine/issues>.

=head1 AUTHOR

Mike Doherty <doherty@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Mike Doherty.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

