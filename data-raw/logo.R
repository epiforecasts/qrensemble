## Generate the qrensemble hex logo.
##
## Run from the package root:
##   Rscript data-raw/logo.R
##   inkscape man/figures/logo.svg -o man/figures/logo.png -w 240
## This writes logo.svg and, in the same design with a dark palette,
## logo-dark.svg for sites shown in dark mode.
## Concept: individual member forecasts fan out from the forecast date and are
## combined into one sharper ensemble fan (amber) with its median.

## standard pointy-top hex canvas
width <- 1732L
height <- 2000L

## --- palettes --------------------------------------------------------------
## the dark theme keeps each colour's role on a dark ground: light ink and
## lighter member and ensemble colours so they still read against it
themes <- list(
  light = list(
    file    = "man/figures/logo.svg",
    bg      = "#FFFFFF",
    border  = "#F2A65A",
    obs_col = "#102340",
    mem_col = c("#D98032", "#D14E77", "#7B69D6", "#3487C8"),
    ens_col = "#149A8E"
  ),
  dark = list(
    file    = "man/figures/logo-dark.svg",
    bg      = "#141B24",
    border  = "#F4B06A",
    obs_col = "#E8EDF2",
    mem_col = c("#EE9A50", "#EC7598", "#A394F0", "#62AEEA"),
    ens_col = "#3CC7B9"
  )
)

## --- geometry (data coords, y up; svg y flipped about `ybase`) --------------
## chart start, forecast date, horizon
x0 <- 205
xf <- 690
x1 <- 1520
ybase <- 1165
flip <- function(y) ybase - y
pt   <- function(x, y) sprintf("%.1f,%.1f", x, flip(y))

## observed history: fixed wiggle rising into the forecast date
hx <- seq(x0, xf, length.out = 9)
hy <- c(-95, -40, -120, -15, 30, -10, 62, 100, 140)

## member forecasts fanning out from the last observation
t  <- seq(0, 1, length.out = 60)
xq <- xf + t * (x1 - xf)
member <- function(a, b) 140 + a * t + b * t^2
mem <- list(
  member(430, -50), member(280, 60), member(130, -65), member(-45, -130)
)

## ensemble: centred on the members but sharper -- the point of QRA
mu <- Reduce(`+`, mem) / length(mem)
band <- function(s) list(lo = mu - s * sqrt(t), hi = mu + s * sqrt(t))
b90 <- band(158)
b50 <- band(72)

## --- svg helpers ------------------------------------------------------------
ribbon <- function(b, col, alpha) {
  sprintf(
    '<path d="M %s L %s Z" fill="%s" fill-opacity="%.2f"/>',
    paste(pt(xq, b$lo), collapse = " L "),
    paste(rev(pt(xq, b$hi)), collapse = " L "), col, alpha
  )
}

line <- function(x, y, col, w, alpha = 1) {
  sprintf(
    paste0(
      '<polyline points="%s" fill="none" stroke="%s" stroke-width="%.0f" ',
      'stroke-opacity="%.2f" stroke-linecap="round" stroke-linejoin="round"/>'
    ),
    paste(pt(x, y), collapse = " "), col, w, alpha
  )
}

hex <- sprintf(
  "%d,0 %d,500 %d,1500 %d,%d 0,1500 0,500",
  width %/% 2L, width, width, width %/% 2L, height
)

for (theme in themes) {
  parts <- c(
    ## member forecasts, thin and behind
    unlist(Map(
      function(m, col) line(xq, m, col, 12, 0.85), mem, theme$mem_col
    )),
    ## ensemble fan, bold and in front
    ribbon(b90, theme$ens_col, 0.32),
    ribbon(b50, theme$ens_col, 0.58),
    line(xq, mu, theme$ens_col, 34),
    ## observed history
    line(hx, hy, theme$obs_col, 30),
    ## forecast date marker
    sprintf(
      paste0(
        '<line x1="%.0f" y1="%.0f" x2="%.0f" y2="%.0f" stroke="%s" ',
        'stroke-width="7" stroke-opacity="0.5" stroke-dasharray="28 30"/>'
      ),
      xf, flip(415), xf, flip(-150), theme$obs_col
    ),
    ## last observation, where the fan opens
    sprintf(
      '<circle cx="%.0f" cy="%.0f" r="27" fill="%s"/>',
      xf, flip(140), theme$obs_col
    )
  )

  svg <- c(
    sprintf(
      paste0(
        '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" ',
        'viewBox="0 0 %d %d">'
      ),
      width, height, width, height
    ),
    sprintf('<polygon points="%s" fill="%s"/>', hex, theme$bg),
    "<g>", parts, "</g>",
    sprintf(
      paste0(
        '<text x="%d" y="1600" text-anchor="middle" ',
        'font-family="Fira Sans, DejaVu Sans, Helvetica, Arial, sans-serif" ',
        'font-size="196" font-weight="600" letter-spacing="3" ',
        'fill="%s">qrensemble</text>'
      ),
      width %/% 2L, theme$obs_col
    ),
    ## border last so it sits over everything
    sprintf(
      paste0(
        '<polygon points="%s" fill="none" stroke="%s" stroke-width="44" ',
        'stroke-linejoin="round"/>'
      ),
      hex, theme$border
    ),
    "</svg>"
  )

  writeLines(svg, theme$file)
}
