// Some definitions presupposed by pandoc's typst output.
#let blockquote(body) = [
  #set text( size: 0.92em )
  #block(inset: (left: 1.5em, top: 0.2em, bottom: 0.2em))[#body]
]

#let horizontalrule = [
  #line(start: (25%,0%), end: (75%,0%))
]

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms: it => {
  it.children
    .map(child => [
      #strong[#child.term]
      #block(inset: (left: 1.5em, top: -0.4em))[#child.description]
      ])
    .join()
}

// Some quarto-specific definitions.

#show raw.where(block: true): block.with(
    fill: luma(230), 
    width: 100%, 
    inset: 8pt, 
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let d = (:)
  let fields = old_block.fields()
  fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.amount
  }
  return block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == "string" {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == "content" {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

#show figure: it => {
  if type(it.kind) != "string" {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let old_title = old_title_block.body.body.children.at(2)

  // TODO use custom separator if available
  let new_title = if empty(old_title) {
    [#kind #it.counter.display()]
  } else {
    [#kind #it.counter.display(): #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block, 
    block_with_new_content(
      old_title_block.body, 
      old_title_block.body.body.children.at(0) +
      old_title_block.body.body.children.at(1) +
      new_title))

  block_with_new_content(old_callout,
    new_title_block +
    old_callout.body.children.at(1))
}

#show ref: it => locate(loc => {
  let target = query(it.target, loc).first()
  if it.at("supplement", default: none) == none or it.supplement == auto {
    it
    return
  }

  let sup = it.supplement.text.matches(regex("^45127368-afa1-446a-820f-fc64c546b2c5%(.*)")).at(0, default: none)
  if sup != none {
    let parent_id = sup.captures.first()
    let parent_figure = query(label(parent_id), loc).first()
    let parent_location = parent_figure.location()

    let counters = numbering(
      parent_figure.at("numbering"), 
      ..parent_figure.at("counter").at(parent_location))
      
    let subcounter = numbering(
      target.at("numbering"),
      ..target.at("counter").at(target.location()))
    
    // NOTE there's a nonbreaking space in the block below
    link(target.location(), [#parent_figure.at("supplement") #counters#subcounter])
  } else {
    it
  }
})

#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color, 
        width: 100%, 
        inset: 8pt)[#text(icon_color, weight: 900)[#icon] #title]) +
      block(
        inset: 1pt, 
        width: 100%, 
        block(fill: white, width: 100%, inset: 8pt, body)))
}

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
    leading: 0.72em
  )

  // Page setup & Running headers/footers
  set page(
    paper: "a4",
    margin: (x: 2.2cm, top: 2.8cm, bottom: 2.6cm),
    header: locate(loc => {
      let page-num = counter(page).at(loc).first()
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
    }),
    footer: locate(loc => {
      let page-num = counter(page).at(loc).first()
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
    })
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

#let report-fig(path, cap, width: 100%) = figure(
  image(path, width: width),
  caption: figure.caption(position: bottom, cap),
  kind: "quarto-float-fig",
  supplement: "Figure",
  numbering: "1",
)

#show: doc => aaran-report(
  title: [AARAN Ecosystem Health and Restoration Concern Analysis],
  subtitle: [Preliminary Restoration Priority Analysis],
  authors: (
    ( name: [Ivy Bartonjo and Tor-G. Vågen],
      affiliation: [],
      email: [] ),
  ),
  date: [2026-09-02],
  toc: true,
  toc-title: [Table of contents],
  toc-depth: 3,
  doc,
)

#pagebreak()
= Introduction
<introduction>
This report presents the results of land health analysis and assessment of restoration concern to support prioritisation of land restoration interventions in Somalia for the AARAN project. Restoration concern refers to the degree to which an area shows ecological conditions or trends that may indicate a need for restoration or closer management. Areas with poorer current ecosystem condition are considered to have greater restoration concern.

The purpose of the report is to give an overview at country, watershed and cluster level, and to provide a summary of the indicator values associated with each restoration concern class. The report is intended for use by AARAN and other stakeholders to inform restoration planning and prioritisation.

== Project Background

AARAN builds directly on BRCiS III's ecosystem-based targeting approach, which was developed in partnership with CIFOR-ICRAF. Under BRCiS III, landscapes were delineated according to shared natural resources and ecological systems such as watersheds. These landscape units were used as the primary basis for planning, targeting and implementing ecosystem-based interventions.

The BRCiS III project was initiated with the aim of increasing resilience to climate-change induced shocks. Climate change intensifies droughts and floods while reducing the ability of an ecosystem to absorb shocks. To strengthen resilience, the programme promoted a combination of social, economic and ecosystem-based measures intended to improve the ability of communities to withstand shocks through stronger social organisation, increased economic buffers, and increased ecosystem productivity and resilience.

As an extension of the work done under BRCiS III, AARAN replicated and streamlined the approach across a set of new project locations during a compressed mini-inception period. The project established landscape units and supporting ecological information using a methodology consistent with the broader BRCiS programme while adapting the process to the shorter AARAN implementation timeframe.

#block[
#callout(
body: 
[
- #strong[National Concern Distribution];: Approximately #strong[41%] Medium restoration concern, #strong[38%] Low restoration concern, and #strong[21%] High restoration concern.
- #strong[Biophysical Clustering];: Five indicators \(tree cover, erosion, RDR50, soil pH, and SOC) were grouped into three operational concern classes using Gaussian mixture modelling \(`mclust`).
- #strong[Primary Predictive Drivers];: Tree cover and soil pH show strong predictive influence across the class-specific Random Forest probability models.

]
, 
title: 
[
Key Findings Summary
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
[i]
, 
)
]
= Methods
<methods>
There are several approaches that can be used to identify areas of concern for ecosystem restoration. In this analysis, the objective was to assess restoration concern by considering both the current condition of the ecosystem and recent patterns of degradation.

Ecosystem condition is influenced by several interacting factors. The analysis therefore considered multiple land health indicators, including soil organic carbon \(SOC), erosion prevalence, root depth restriction at 50 cm \(RDR50), tree cover, and pH. These indicators represent vegetation condition, soil condition, rooting constraints, and degradation pressure.

== Indicator Maps

Soil and vegetation properties can be predicted using satellite imagery and machine learning. Using the ICRAF soil database and observations for Somalia collected during BRCiS III, land health maps were generated for the AARAN analysis.

To assess the current state of the ecosystem, SOC, tree cover, root depth restriction, pH and erosion were predicted using Landsat 8 median composites and Google Earth embeddings over the years 2018 to 2025. Median composites over 2024 to 2025 were then computed to show current conditions. Taking the median pixel over two years reduces natural fluctuations and produces a more representative image.

#report-fig("docx_media/image22.png", [Tree cover trend across Somalia for the 2018 to 2025 reference period.])
<fig-tree-cover-trend>

== Ecosystem Indicator Clustering

When identifying suitable areas for restoration, both location and ecological context need to be considered, making it difficult to set fixed thresholds for individual indicators. A model-based clustering approach was therefore applied to group areas with similar combinations of ecosystem characteristics. This allowed the analysis to identify naturally occurring ecological groups based on multiple indicators and interpret their relative level of restoration concern.

The clustering considered SOC, erosion prevalence, tree cover, pH and RDR50. Randomly generated points were used to sample raster values for each indicator. Sampled indicator values were standardised and clustered into three groups using R Statistics through the `mclust` library. The resulting groups were interpreted manually based on their ecological characteristics and classified as low, medium or high restoration concern.

The following considerations were used when interpreting the clusters:

- Areas with low SOC and high erosion are considered highly degraded and may require considerable resources and effort to restore.
- Alkaline soils \(pH \> 7.5) can be high in SOC due to high clay content, but may also be challenging to restore when degraded.
- High tree cover in combination with low SOC and high erosion can indicate invasive species or woody encroachment, which may require targeted management.
- High historic SOC concentrations indicate a high potential for carbon storage. Such areas generally also have higher inherent resilience and may require less effort to restore.
- RDR50 maps where roots are physically restricted within the top 0.5 m of soil, indicating reduced access to water and nutrients and therefore lower potential vegetation growth.

The three resulting classes were then used to train random forest models with Landsat 8 surface reflectance data. This allowed the cluster-based classification to be extended spatially across the country, producing separate probability surfaces for low, medium and high restoration concern. Each surface represents the likelihood that a given location belongs to one of the three classes, providing both a spatial classification and an indication of confidence in that classification. The model also yields variable importance scores, enabling identification of the dominant indicators driving the classification.

The reporting workflow uses three output groups:

- Mclust cluster and restoration concern rasters
- Random forest probability rasters for low, medium, and high concern
- Variable-importance graphs for low, medium, and high concern surfaces

= Results
<results>
@fig-indicators_distr_som shows the distribution of indicator values for the random points used to generate restoration concern clusters across Somalia. SOC is low overall \(median SOC below 10 g/kg), with some sampled locations having SOC higher than 20 g/kg. Erosion is high overall \(median \> 60%), tree cover is highly variable, and pH ranges mostly from neutral to alkaline, with many plots having pH \> 7.5.

#figure([
#box(width: 650.1672240802676pt, image("report_pngs/AARAN_indicator_distributions.png"))
], caption: figure.caption(
position: bottom, 
[
Graph showing the distribution of indicator values for the randomly sampled points used to generate restoration concern clusters.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
numbering: "1", 
)
<fig-indicators_distr_som>

== Indicator Distributions by Concern Class

@fig-indicators-by-concern shows how the sampled indicator values separate across the three interpreted restoration concern classes. The high concern class is distinguished by lower tree cover and SOC, higher erosion and higher pH, while the low and medium concern classes overlap more strongly for several indicators. Root depth restriction separates the classes less cleanly than tree cover, erosion and pH, but still contributes to the ecological interpretation of the classes. Overall, the plot supports the manual interpretation of the Mclust groups: high concern areas combine sparse vegetation, reduced soil carbon and stronger erosion pressure, while low and medium concern areas generally retain more favourable vegetation or soil conditions.

#report-fig("report_pngs/AARAN_indicator_distributions_by_concern.png", [Distribution of indicator values by restoration concern class. Ridges show sampled values and black ticks show class medians.])
<fig-indicators-by-concern>

The Mclust model produced three restoration concern groups. These groups were interpreted based on their ecological characteristics:

- #strong[Concern class 1: Low concern.] This class is characterised by high tree cover \(56%), moderate to high erosion prevalence \(63%), moderate SOC content \(6.45), near-neutral pH \(6.83), and relatively high RDR50 values \(56.28). Overall, the relatively high vegetation cover and nearly neutral soil conditions indicate comparatively favourable ecosystem conditions despite some erosion pressure.
- #strong[Concern class 2: Medium concern.] This class is characterised by medium tree cover \(45%), comparatively low erosion prevalence \(53%), relatively high SOC content \(7.11), slightly alkaline pH \(7.24), and intermediate RDR50 values \(49.59). The class represents mixed ecosystem conditions, with relatively favourable soil properties but lower vegetation cover than the low-concern class.
- #strong[Concern class 3: High concern.] This class is characterised by very low tree cover \(15%), high erosion prevalence \(71%), very low SOC content \(3.31), alkaline soil conditions \(pH 7.66), and relatively low RDR50 values \(47.15). The combination of sparse vegetation, high erosion and low soil organic carbon indicates the strongest signs of ecosystem degradation among the three classes.

These groups provide the main classification used in the report. @tbl-mclust-restoration should be interpreted alongside the map and RF outputs rather than as a final ecological ranking on its own.

#block[
#figure([
#block[
#figure(
align(center)[#table(
  columns: 3,
  align: (col, row) => (right,right,left,).at(col),
  inset: 6pt,
  [Mclust class], [Effort class], [Restoration effort],
  [1],
  [2],
  [Medium restoration effort],
  [2],
  [1],
  [Low restoration effort],
  [3],
  [3],
  [High restoration effort],
)]
)

]
], caption: figure.caption(
position: top, 
[
Classification of restoration concern based on Mclust classes.
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
numbering: "1", 
)
<tbl-mclust-restoration>


]
#block[
#block[
#figure(
align(center)[#table(
  columns: 3,
  align: (col, row) => (left,right,right,).at(col),
  inset: 6pt,
  [restoration\_effort], [area\_km2], [area\_percent],
  [Low restoration effort],
  [218700.7],
  [0.38],
  [Medium restoration effort],
  [233897.3],
  [0.41],
  [High restoration effort],
  [122564.1],
  [0.21],
)]
)

]
]
#block[
#block[
#box(width: 528.0pt, image("report_files/figure-typst/unnamed-chunk-3-1.png"))

]
]
= Random Forest Results
<random-forest-results>
Three random forest models were used to evaluate low, medium and high restoration concern. Each model produces a class-specific probability surface and a variable-importance ranking showing which predictors contribute most to that class prediction. For ease of comparison, each class is shown below with the probability surface on the left and the variable-importance ranking on the right.

#figure(
  grid(
    columns: (1fr, 1fr),
    gutter: 10pt,
    [
      #text(weight: "bold")[Low concern probability] \
      #image("report_files/figure-typst/unnamed-chunk-4-1.png", width: 100%)
    ],
    [
      #text(weight: "bold")[Low concern variable importance] \
      #image("report_pngs/AARAN_importance_low.png", width: 100%)
    ],
  ),
  caption: figure.caption(position: bottom, [Random forest probability surface and variable-importance ranking for low restoration concern.]),
  kind: "quarto-float-fig",
  supplement: "Figure",
  numbering: "1",
)
<fig-rf-low-comparison>

#figure(
  grid(
    columns: (1fr, 1fr),
    gutter: 10pt,
    [
      #text(weight: "bold")[Medium concern probability] \
      #image("report_files/figure-typst/unnamed-chunk-6-1.png", width: 100%)
    ],
    [
      #text(weight: "bold")[Medium concern variable importance] \
      #image("report_pngs/AARAN_importance_medium.png", width: 100%)
    ],
  ),
  caption: figure.caption(position: bottom, [Random forest probability surface and variable-importance ranking for medium restoration concern.]),
  kind: "quarto-float-fig",
  supplement: "Figure",
  numbering: "1",
)
<fig-rf-medium-comparison>

#figure(
  grid(
    columns: (1fr, 1fr),
    gutter: 10pt,
    [
      #text(weight: "bold")[High concern probability] \
      #image("report_files/figure-typst/unnamed-chunk-8-1.png", width: 100%)
    ],
    [
      #text(weight: "bold")[High concern variable importance] \
      #image("report_pngs/AARAN_importance_high.png", width: 100%)
    ],
  ),
  caption: figure.caption(position: bottom, [Random forest probability surface and variable-importance ranking for high restoration concern.]),
  kind: "quarto-float-fig",
  supplement: "Figure",
  numbering: "1",
)
<fig-rf-high-comparison>

The rankings indicate that high concern is mainly distinguished by vegetation and soil carbon limitations, with tree cover and SOC ranking highest. Medium and low concern are more strongly differentiated by soil pH and root-depth restriction, indicating that underlying soil conditions are important for separating the less degraded classes.
= Country-Level Overview
<country-level-overview>
At country level, the restoration concern map shows the spatial distribution of low, medium and high concern areas. The area graph summarizes how many square kilometers fall within each class.

#report-fig("docx_media/image25.png", [Restoration concern classes across Somalia.], width: 72%)
<fig-country-restoration-concern-map>

#report-fig("report_files/figure-typst/unnamed-chunk-11-1.png", [Area of Somalia under low, medium and high restoration concern.])
<fig-country-area-by-concern>

#report-fig("docx_media/image10.png", [Share of restoration concern classes by watershed.])
<fig-watershed-concern-composition>

#report-fig("docx_media/image19.png", [Share of restoration concern classes by selected project cluster.])
<fig-cluster-concern-composition>

= Watershed and Cluster-Level Concern
<watershed-and-cluster-level-concern>
Degradation levels vary considerably between the project clusters, and therefore the restoration concern and recommended restoration practices also vary by cluster. The distribution of the three concern classes across watersheds shows that Watershed 8 in the Nugaal region has the highest percentage of area under high concern, while watersheds 5 and 6 in Bay region have little to no area under high concern.

At cluster level, `KAALO_7` in Nugaal has the highest percentage of area under high concern. `GREDO_7` and `GREDO_6` in Bay have very limited high concern area, while `CWW_8` in Gedo is entirely under low concern. The analysis can therefore be broken down by watershed and by the cluster contained within each watershed.

== Watershed 1 and KAALO_6

Watershed 1 contains the `KAALO_6` cluster. Indicator distributions compare country and watershed medians, while the cluster summary compares country, watershed and cluster medians. Under the high concern class, erosion and pH distributions are shifted toward higher values, indicating more severe erosion and less favourable pH conditions. In contrast, SOC, RDR50 and tree cover are shifted toward lower values, reflecting reduced soil carbon, shallower effective rooting depth and sparser vegetation in high concern areas.

#report-fig("docx_media/image32.png", [Restoration concern map for Watershed 1 and the KAALO_6 cluster.])
<fig-watershed-1-map>

#report-fig("docx_media/image3.png", [Watershed 1 indicator distributions by restoration concern class.])
<fig-watershed-1-distribution>

#report-fig("docx_media/image15.png", [KAALO_6 indicator distributions by restoration concern class.])
<fig-kaalo-6-distribution>

Across high concern indicators, the watershed median is generally higher than the national median, except for SOC, where the watershed median is lower. This suggests that, relative to the country, Watershed 1 experiences more intense erosion, more extreme pH and greater root-depth restriction, with lower soil organic carbon but higher tree cover. Across indicators, the `KAALO_6` median is generally higher than the national and watershed medians, except for SOC, where it is lower than the country median but higher than the watershed median.

== Watershed 2 and KAALO_1

Watershed 2 contains the `KAALO_1` cluster. Across high concern indicators, the watershed median is generally lower than the national median. This suggests that, relative to the country, the watershed has relatively lower pH and root-depth restriction, higher soil organic carbon and higher tree cover, while erosion remains an important pressure.

#report-fig("docx_media/image23.png", [Restoration concern map for Watershed 2 and the KAALO_1 cluster.])
<fig-watershed-2-map>

#report-fig("docx_media/image28.png", [Watershed 2 indicator distributions by restoration concern class.])
<fig-watershed-2-distribution>

#report-fig("docx_media/image1.png", [KAALO_1 indicator distributions by restoration concern class.])
<fig-kaalo-1-distribution>

Across indicators, the `KAALO_1` median generally lies between the country and watershed medians for erosion, is higher than both for root depth restriction, and lower for SOC and tree cover. This pattern suggests that `KAALO_1` experiences intermediate erosion pressure but more severe physical rooting constraints than either the broader watershed or the country average. Lower SOC and tree cover imply weaker vegetation structure and reduced carbon storage, pointing to conditions that may be more vulnerable to further decline unless restoration specifically targets vegetation recovery and SOC accumulation.

== Watershed 3 and CWW_4

Watershed 3 contains the `CWW_4` cluster. Across high concern indicators, the watershed median is generally lower than the national median, except for erosion and tree cover, where the watershed median is higher. This indicates that the watershed experiences stronger erosion pressure and higher tree cover, but relatively lower pH, lower root-depth restriction and higher soil organic carbon compared with the national scale.

#report-fig("docx_media/image9.png", [Restoration concern map for Watershed 3 and the CWW_4 cluster.])
<fig-watershed-3-map>

#report-fig("docx_media/image12.png", [Watershed 3 indicator distributions by restoration concern class.])
<fig-watershed-3-distribution>

#report-fig("docx_media/image7.png", [CWW_4 indicator distributions by restoration concern class.])
<fig-cww-4-distribution>

Across indicators, the `CWW_4` median is lower than the country and watershed medians for root depth restriction, SOC and tree cover, but higher than both for erosion and intermediate for pH. These results suggest that the cluster faces stronger erosion pressure, more severe root-depth restriction, and reduced vegetation and SOC relative to the country and watershed scales, while experiencing intermediate pH conditions.

== Watersheds 5 and 6 with GREDO_6 and GREDO_7

Watersheds 5 and 6 contain the `GREDO_6` and `GREDO_7` clusters. No areas in these watersheds meet the high-concern class; conditions are dominated by medium concern followed by low concern. This is consistent with landscapes where severe degradation is limited and most areas fall into moderate or better condition classes.

#report-fig("docx_media/image18.png", [Restoration concern map for Watersheds 5 and 6 and the GREDO_6 and GREDO_7 clusters.])
<fig-watershed-5-6-map>

#report-fig("docx_media/image30.png", [Watersheds 5 and 6 indicator distributions by restoration concern class.])
<fig-watershed-5-6-distribution>

#report-fig("docx_media/image27.png", [GREDO_6 indicator distributions by restoration concern class.])
<fig-gredo-6-distribution>

For `GREDO_6`, the median is lower than the country and watershed medians for root depth restriction and tree cover, but higher than both for pH and SOC. Erosion is intermediate, with the country erosion median higher than the cluster median. This suggests shallower effective rooting depth and more sparse tree cover than the broader regions, but more favourable pH, higher SOC and lower erosion compared with the national scale.

#report-fig("docx_media/image2.png", [GREDO_7 indicator distributions by restoration concern class.])
<fig-gredo-7-distribution>

For `GREDO_7`, the median is lower than the country and watershed medians for pH, higher than both for root depth restriction and tree cover, and intermediate for erosion and SOC. This suggests less favourable pH conditions but deeper effective rooting depth and denser tree cover than both broader scales. Erosion pressure is moderately lower than the country median but slightly above the watershed median, while SOC is better than the country overall but not as high as the watershed median.

== Watershed 7 and CWW_8

Watershed 7 contains the `CWW_8` cluster. Across high concern indicators, the watershed median is generally lower than the country median, except for SOC and pH, where the watershed median is higher. This suggests that the watershed has higher soil organic carbon and slightly higher pH in high concern areas, while erosion, root depth restriction and tree cover tend to be lower.

#report-fig("docx_media/image20.png", [Restoration concern map for Watershed 7 and the CWW_8 cluster.])
<fig-watershed-7-map>

#report-fig("docx_media/image14.png", [Watershed 7 indicator distributions by restoration concern class.])
<fig-watershed-7-distribution>

#report-fig("docx_media/image5.png", [CWW_8 indicator distributions by restoration concern class.])
<fig-cww-8-distribution>

Across indicators, the `CWW_8` median is lower than the country and watershed medians for erosion and root depth restriction, but higher for pH and SOC, and lower for tree cover. The cluster falls entirely within the low-concern class, so restoration efforts should focus on conservation and enhancing vegetation cover to maintain and improve existing conditions.

== Watershed 8 and KAALO_7

Watershed 8 contains the `KAALO_7` cluster. The watershed and cluster are dominated by high concern. Across high concern indicators, the watershed median is generally lower than the national median, except for erosion and pH, where the watershed median is higher. This suggests that, relative to the country, the watershed experiences more intense degradation across key indicators.

#report-fig("docx_media/image11.png", [Restoration concern map for Watershed 8 and the KAALO_7 cluster.])
<fig-watershed-8-map>

#report-fig("docx_media/image16.png", [Watershed 8 indicator distributions by restoration concern class.])
<fig-watershed-8-distribution>

#report-fig("docx_media/image17.png", [KAALO_7 indicator distributions by restoration concern class.])
<fig-kaalo-7-distribution>

For `KAALO_7`, the pattern closely matches its parent watershed. The median is lower than the national median for root depth restriction and tree cover, close to the watershed median for SOC, and higher for pH and erosion. This indicates that the cluster is generally more degraded than the broader national scale. Restoration efforts in `KAALO_7` should prioritize erosion control, soil conservation and increasing vegetation cover through interventions such as contour bunds, mulching and improved grazing management. Limited effective rooting depth may hinder the establishment of deep-rooted species; where feasible, soil decompaction could be considered before planting, or shallow-rooted, stress-tolerant species should be prioritized.

= Restoration Recommendations

#strong[Low concern areas] generally exhibit favourable ecosystem conditions, including high tree cover, moderate SOC, nearly neutral pH and relatively high RDR50 values. Intensive restoration is unlikely to be required, although moderate to high erosion levels indicate that soil and water conservation measures could help prevent further degradation. Restoration should focus on protection, maintenance and erosion control while preserving existing vegetation.

#strong[Medium concern areas] exhibit mixed ecosystem conditions, characterized by moderate tree cover, relatively high SOC, slightly alkaline soils and intermediate root-depth restriction. The comparatively favourable soil conditions suggest that vegetation restoration remains feasible. Targeted tree planting, grass reseeding and improved grazing management may be appropriate where vegetation cover is declining or sparse. Localized soil and water conservation measures should also be considered, particularly in areas experiencing moderate or high erosion.

#strong[High concern areas] show the strongest indicators of degradation, including very low tree cover, high erosion, very low SOC, alkaline soil conditions and relatively low RDR50 values. Restoration will likely require more active, sustained and resource-intensive intervention. Soil and water conservation measures such as halfmoons, contour bunds and terraces should be prioritized to reduce erosion and improve water retention before or alongside vegetation restoration. In severely eroded locations, physical structures such as check dams or gabions may also be needed to stabilize channels and control sediment movement. Grass reseeding and targeted tree establishment can help increase vegetation cover and gradually rebuild SOC.

= Conclusion
<conclusion>
The output shows that about 41% of Somalia is classified as medium restoration concern, 38% as low concern and 21% as high concern. Variable importance rankings indicate that different ecosystem indicators drive the classification of concern classes. In high concern areas, tree cover was the strongest predictor followed by SOC, indicating that degraded sites are distinguished mainly by low vegetation cover and reduced soil carbon. For the medium and low concern classes, soil pH was the strongest predictor followed by root depth restriction, implying that soil properties play a stronger role in distinguishing areas with comparatively better ecosystem condition.

Overall, the results suggest that high concern areas are more strongly associated with vegetation and soil carbon limitations, while the medium and low concern areas are differentiated more by underlying soil properties such as pH and rooting conditions. These results can inform restoration planning and prioritisation across Somalia.
