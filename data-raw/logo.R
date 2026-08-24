## Generate the qrensemble hex logo.
##
## Run from the package root:
##   Rscript data-raw/logo.R
##   inkscape man/figures/logo.svg -o man/figures/logo.png -w 240
## Concept: individual member forecasts fan out from the forecast date and are
## combined into one sharper ensemble fan (amber) with its median.

W <- 1732L; H <- 2000L                   # standard pointy-top hex canvas

## --- palette ---------------------------------------------------------------
bg      <- "#102340"
border  <- "#F2A65A"
obs_col <- "#EDF2F8"
mem_col <- c("#F2A65A", "#E86A92", "#9B8CE8", "#5AA9E6")
ens_col <- "#6FE6D8"
fan_col <- "#35C6BC"

## --- geometry (data coords, y up; svg y flipped about `ybase`) --------------
x0 <- 205; xf <- 690; x1 <- 1520         # chart start, forecast date, horizon
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
mem <- list(member(430, -50), member(280, 60), member(130, -65), member(-45, -130))

## ensemble: centred on the members but sharper -- the point of QRA
mu <- Reduce(`+`, mem) / length(mem)
band <- function(s) list(lo = mu - s * sqrt(t), hi = mu + s * sqrt(t))
b90 <- band(158); b50 <- band(72)

## --- svg helpers ------------------------------------------------------------
ribbon <- function(b, alpha) sprintf(
  '<path d="M %s L %s Z" fill="%s" fill-opacity="%.2f"/>',
  paste(pt(xq, b$lo), collapse = " L "),
  paste(rev(pt(xq, b$hi)), collapse = " L "), ens_col, alpha)

line <- function(x, y, col, w, alpha = 1) sprintf(
  '<polyline points="%s" fill="none" stroke="%s" stroke-width="%.0f" stroke-opacity="%.2f" stroke-linecap="round" stroke-linejoin="round"/>',
  paste(pt(x, y), collapse = " "), col, w, alpha)

parts <- c(
  ## member forecasts, thin and behind
  unlist(Map(function(m, col) line(xq, m, col, 12, 0.85), mem, mem_col)),
  ## ensemble fan, bold and in front
  ribbon(b90, 0.32), ribbon(b50, 0.58), line(xq, mu, ens_col, 34),
  ## observed history
  line(hx, hy, obs_col, 30),
  ## forecast date marker
  sprintf('<line x1="%.0f" y1="%.0f" x2="%.0f" y2="%.0f" stroke="%s" stroke-width="7" stroke-opacity="0.5" stroke-dasharray="28 30"/>',
          xf, flip(415), xf, flip(-150), obs_col),
  ## last observation, where the fan opens
  sprintf('<circle cx="%.0f" cy="%.0f" r="27" fill="%s"/>', xf, flip(140), obs_col)
)

hex <- sprintf("%d,0 %d,500 %d,1500 %d,%d 0,1500 0,500", W %/% 2L, W, W, W %/% 2L, H)

svg <- c(
  sprintf('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">', W, H, W, H),
  sprintf('<polygon points="%s" fill="%s"/>', hex, bg),
  '<g>', parts, '</g>',
  sprintf('<text x="%d" y="1600" text-anchor="middle" font-family="Fira Sans, DejaVu Sans, Helvetica, Arial, sans-serif" font-size="196" font-weight="600" letter-spacing="3" fill="%s">qrensemble</text>', W %/% 2L, obs_col),
  ## border last so it sits over everything
  sprintf('<polygon points="%s" fill="none" stroke="%s" stroke-width="44" stroke-linejoin="round"/>', hex, border),
  '</svg>')

writeLines(svg, "man/figures/logo.svg")
