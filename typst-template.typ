// Modern Typst Template for AARAN Technical & Spatial Reports
// Author: ICRAF SPACIAL

#let aaran-report(
  title: none,
  subtitle: none,
  authors: (),
  date: none,
  toc: false,
  toc-title: "Table of Contents",
  toc-depth: 2,
  cover-page: false,
  doc
) = {
  // Brand color palette
  let brand-teal = rgb("#2A9D8F")
  let brand-dark = rgb("#264653")
  let brand-gold = rgb("#E9C46A")
  let brand-coral = rgb("#E76F51")
  let text-dark = rgb("#1F2937")
  let text-muted = rgb("#6B7280")
  let border-light = rgb("#E5E7EB")
  let card-bg = rgb("#F4FAF8")
  let card-border = rgb("#C7E8E1")

  // Document metadata for PDF
  set document(
    title: if title != none { title } else { "AARAN Report" },
    author: "Landscape Alliance"
  )

  // Typography
  set text(
    font: ("Roboto", "Arial"),
    size: 9.5pt,
    fill: text-dark,
    spacing: 120%
  )

  set par(
    justify: true,
    leading: 0.72em,
    spacing: 1.2em
  )

  // Page setup & Running headers/footers
  set page(
    paper: "a4",
    margin: (x: 2.2cm, top: 2.8cm, bottom: 2.6cm),
    header: context {
      let page-num = counter(page).get().first()
      if (not cover-page and page-num > 1) or (cover-page and page-num > 2) [
        #grid(
          columns: (1fr, auto),
          align(left + bottom)[
            #text(size: 8pt, fill: text-muted, weight: "medium")[
              AARAN · Land Restoration Prioritization Report
            ]
          ],
          align(right + bottom)[
            #text(size: 8pt, fill: brand-teal, weight: "bold", tracking: 0.5pt)[
              ICRAF
            ]
          ]
        )
        #v(-0.4em)
        #line(length: 100%, stroke: 0.5pt + border-light)
      ]
    },
    footer: context {
      let page-num = counter(page).get().first()
      let total-pages = counter(page).final().first()
      if (not cover-page) or (cover-page and page-num > 1) [
        #line(length: 100%, stroke: 0.5pt + border-light)
        #v(-0.4em)
        #grid(
          columns: (1fr, 1fr),
          text(size: 8pt, fill: text-muted)[
            Somalia Biophysical Clustering & Modeling
          ],
          align(right, text(size: 8pt, fill: text-muted)[
            Page #page-num of #total-pages
          ])
        )
      ]
    }
  )

  // Heading styles
  show heading.where(level: 1): it => block(above: 2em, below: 1.1em, breakable: false)[
    #box(
      baseline: 0%,
      grid(
        columns: (auto, 1fr),
        gutter: 8pt,
        rect(width: 4.5pt, height: 1.15em, fill: brand-teal, radius: 2pt),
        text(size: 13.5pt, weight: "bold", fill: brand-dark)[#it.body]
      )
    )
  ]

  show heading.where(level: 2): it => block(above: 1.5em, below: 0.8em, breakable: false)[
    #text(size: 11pt, weight: "bold", fill: brand-teal)[#it.body]
  ]

  show heading.where(level: 3): it => block(above: 1.2em, below: 0.6em, breakable: false)[
    #text(size: 10pt, weight: "bold", fill: brand-dark)[#it.body]
  ]

  // Table styling
  set table(
    stroke: (x, y) => if y == 0 {
      (bottom: 1.5pt + brand-teal)
    } else {
      (bottom: 0.5pt + border-light)
    },
    fill: (col, row) => if row == 0 {
      rgb("#EBF7F4")
    } else if calc.even(row) {
      rgb("#F9FAFB")
    } else {
      none
    },
    inset: (x: 8pt, y: 7pt)
  )

  // Links styling
  show link: set text(fill: brand-teal, weight: "medium")

  // Figures & Captions
  show figure.caption: it => [
    #v(0.3em)
    #text(size: 8.5pt, fill: text-muted, weight: "medium")[
      #it
    ]
  ]

  // Code blocks & Raw inline
  show raw.where(block: false): box.with(
    fill: rgb("#F3F4F6"),
    inset: (x: 3.5pt, y: 1.5pt),
    baseline: 0%,
    radius: 3pt
  )

  show raw.where(block: true): it => block(
    width: 100%,
    fill: rgb("#F8FAFC"),
    stroke: 0.5pt + border-light,
    inset: 10pt,
    radius: 4pt,
    it
  )

  // Cover Page or Modern Hero Banner
  if cover-page {
    // Full modern cover page
    page(header: none, footer: none)[
      #v(3cm)
      #rect(width: 32pt, height: 4pt, fill: brand-teal, radius: 2pt)
      #v(0.8em)
      #text(size: 10pt, weight: "bold", fill: brand-teal, tracking: 1.5pt)[
        SPACIAL TECHNICAL REPORT
      ]
      #v(0.6em)
      #text(size: 26pt, weight: "bold", fill: brand-dark, leading: 0.35em)[
        #title
      ]
      #if subtitle != none [
        #v(0.6em)
        #text(size: 14pt, fill: text-muted)[#subtitle]
      ]
      
      #v(1.5cm)
      #line(length: 100%, stroke: 1pt + brand-teal)
      #v(0.8em)
      
      #grid(
        columns: (1fr, 1fr),
        row-gutter: 0.8em,
        [
          #text(size: 9pt, fill: text-muted)[PREPARED BY] \
          #text(size: 11pt, weight: "bold", fill: brand-dark)[
            #if authors.len() > 0 { authors.map(a => a.name).join(", ") } else { "ICRAF SPACIAL" }
          ]
        ],
        align(right)[
          #text(size: 9pt, fill: text-muted)[DATE] \
          #text(size: 11pt, weight: "bold", fill: brand-dark)[#date]
        ]
      )
      
      #v(1fr)
      #rect(
        width: 100%,
        fill: card-bg,
        stroke: 1pt + card-border,
        radius: 6pt,
        inset: 14pt
      )[
        #text(size: 9pt, weight: "bold", fill: brand-teal)[PROJECT SUMMARY] \
        #v(0.2em)
        #text(size: 8.5pt, fill: text-dark)[
          Model-based clustering and random forest probability surfaces for restoration effort prioritization across Somalia.
        ]
      ]
    ]
    pagebreak()
  } else {
    // Compact Modern Hero Banner on First Page
    block(width: 100%, inset: (bottom: 1.5em))[
      #rect(
        width: 100%,
        fill: card-bg,
        stroke: 1pt + card-border,
        radius: 6pt,
        inset: 16pt
      )[
        #grid(
          columns: (1fr, auto),
          text(size: 8pt, weight: "bold", fill: brand-teal, tracking: 1.5pt)[
            
          ],
          text(size: 8pt, weight: "bold", fill: brand-coral, tracking: 1pt)[
            ICRAF Spatial Data Science and Applied Learning Lab (SPACIAL)
          ]
        )
        #v(0.4em)
        #set text(hyphenate: false)
        #set par(justify: false)
        #text(size: 19pt, weight: "bold", fill: brand-dark)[
          #title
        ]
        #if subtitle != none [
          #v(0.2em)
          #text(size: 10.5pt, fill: text-muted)[#subtitle]
        ]
        #v(0.8em)
        #line(length: 100%, stroke: 0.5pt + card-border)
        #v(0.5em)
        #grid(
          columns: (1fr, 1fr, 1fr),
          text(size: 8.5pt, fill: text-muted)[
            *Author:* #if authors.len() > 0 { authors.map(a => a.name).join(", ") } else { "ICRAF SPACIAL" }
          ],
          align(center, text(size: 8.5pt, fill: text-muted)[
            *Date:* #date
          ]),
          align(right, text(size: 8.5pt, fill: brand-teal)[
            *Status:* Final Report
          ])
        )
      ]
    ]
  }

  // Table of Contents
  if toc {
    block(
      width: 100%,
      fill: rgb("#FAFAFA"),
      stroke: 0.5pt + border-light,
      radius: 5pt,
      inset: 14pt,
      below: 2em
    )[
      #text(size: 11pt, weight: "bold", fill: brand-dark)[#toc-title]
      #v(0.6em)
      #outline(title: none, depth: toc-depth, indent: 1.5em)
    ]
  }

  doc
}
