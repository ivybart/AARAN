#show: doc => aaran-report(
$if(title)$
  title: [$title$],
$endif$
$if(subtitle)$
  subtitle: [$subtitle$],
$endif$
$if(by-author)$
  authors: (
$for(by-author)$
$if(it.name.literal)$
    ( name: [$it.name.literal$],
      affiliation: [$for(it.affiliations)$$it.name$$sep$, $endfor$],
      email: [$it.email$] ),
$endif$
$endfor$
  ),
$elseif(author)$
  authors: (
$for(author)$
    ( name: [$author$], affiliation: "", email: "" ),
$endfor$
  ),
$endif$
$if(date)$
  date: [$date$],
$endif$
$if(toc)$
  toc: $toc$,
$endif$
$if(toc-title)$
  toc-title: [$toc-title$],
$endif$
$if(toc-depth)$
  toc-depth: $toc-depth$,
$endif$
$if(cover-page)$
  cover-page: $cover-page$,
$endif$
  doc,
)

