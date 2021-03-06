### -----------------------------
### ajps reviewers
### simon munzert
### -----------------------------

## goals ------------------------

# fetch list of AJPS reviewers from PDFs
# locate them on a map


## tasks ------------------------

# downloading PDF files
# importing them into R (as plain text)
# extract information via regex
# geocoding


## packages ---------------------

library(tidyverse)
library(rvest)
library(pdftools)
# devtools::install_github("hrbrmstr/nominatim")
library(nominatim)


## directory ---------------------

wd <- ("../data/ajpsReviewers")
dir.create(wd)
setwd(wd)


## code ---------------------

## step 1: inspect page
url <- "http://ajps.org/list-of-reviewers/"
browseURL(url)


## step 2: retrieve pdfs
# get page
content <- read_html(url)
# get anchor (<a href=...>) nodes via xpath
anchors <- html_nodes(content, xpath = "//a")
# get value of anchors' href attribute
hrefs <- html_attr(anchors, "href")

# filter links to pdfs
pdfs <- hrefs[ str_detect(basename(hrefs), ".*\\d{4}.*pdf") ]
pdfs

# define names for pdfs on disk
pdf_names <- str_extract(basename(pdfs), "\\d{4}") %>% paste0("reviewers", ., ".pdf")
pdf_names

# download pdfs
for(i in seq_along(pdfs)) {
  download.file(pdfs[i], pdf_names[i], mode="wb")
}


## step 3: import pdf
rev_raw <- pdftools::pdf_text("reviewers2015.pdf")
class(rev_raw)
rev_raw[1]


## step 4: tidy data
rev_all <- rev_raw %>% str_split("\\n") %>% unlist 
surname <- str_extract(rev_all, "[[:alpha:]-]+")
prename <- str_extract(rev_all, " [[:alpha:].]+")
rev_df <- data.frame(raw = rev_all, surname = surname, prename = prename, stringsAsFactors = F)
rev_df$institution <- NA
for(i in 1:nrow(rev_df)) {
  rev_df$institution[i] <- rev_df$raw[i] %>% str_replace(rev_df$surname[i], "") %>% str_replace(rev_df$prename[i], "") %>% str_trim()
}
rev_df <- rev_df[-c(1,2),]
rev_df <- rev_df[!is.na(rev_df$surname),]
head(rev_df)



## step 5: geocode reviewers/institutions

unique_institutions <- unique(rev_df$institution)
unique_institutions <- unique_institutions[!is.na(unique_institutions)]

# get free key for mapquest API at browseURL("https://developer.mapquest.com/")
load("/Users/simonmunzert/rkeys.RDa") # import API key (or paste it here in openstreetmap object)

pos <- data.frame(lon = NA, lat = NA)
if (!file.exists("institutions2015_geo.RData")){
  for (i in 1:length(unique_institutions)) {
    pos[i,] <- try(nominatim::osm_search(unique_institutions[i], key = openstreetmap) %>% dplyr::select(lon, lat))
  }
  pos$institution <- unique_institutions
  pos <- filter(pos, !str_detect(lon, "Error"))
  pos$lon <- as.numeric(pos$lon)
  pos$lat <- as.numeric(pos$lat)
  save(pos, file="institutions2015_geo.RData")
} else {
  load("institutions2015_geo.RData")
}
head(pos)

rev_geo <- merge(rev_df, pos, by = "institution", all = T)


## step 6: plot reviewers, worldwide
mapWorld <- borders("world")
map <-
  ggplot() +
  mapWorld +
  geom_point(aes(x=rev_geo$lon, y=rev_geo$lat) ,
             color="#F54B1A90", size=1,
             na.rm=T) +
  theme_bw() +
  coord_map(xlim=c(-180, 180), ylim=c(-70,80))
map

