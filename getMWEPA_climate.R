# extract climate time series from RCC-ACIS for MWEPA Zone 1
# MAC 05/23/24

## Load Libraries
library(RCurl)
library(jsonlite)
library(raster)


##### Read in shapefile ----
Level1Data<- sf::st_read(dsn = "./mwepaShape/MWEPA_Zone_1.shp")
#plot(Shapefile1)
#Shapefile1<- sf::st_transform(Shapefile1, crs = sf::st_crs("+proj=longlat +datum=WGS84"))
Level1Data<- as(Level1Data, "Spatial")
sp::plot(Level1Data)

# get extent
tempExt<-raster::extent(Level1Data)*1
Mapbox <- c(tempExt@xmin,tempExt@ymin,tempExt@xmax,tempExt@ymax)
ACISbbox <- paste(as.character(Mapbox), sep="' '", collapse=",")

#### Acquire Data ####
# create current date and generate dates -- keep with PRISM date
dateRangeStart = paste0(1895,"-01-01")
dateRangeEnd = paste0(2023,"-",12,"-",31)
allDates<-seq(as.Date(dateRangeStart), as.Date(dateRangeEnd),by="month")

# ACIS query in JSON
#jsonQuery=paste0('{"bbox":"',ACISbbox,'","sdate":"',dateRangeStart,'","edate":"',dateRangeEnd,'","grid":"21","elems":"mly_pcpn","meta":"ll,elev","output":"json"}') # or uid
# query with avg temp
jsonQuery=paste0('{"bbox":"',ACISbbox,'","sdate":"',dateRangeStart,'","edate":"',dateRangeEnd,'","grid":"21","elems":[{"name":"mly_pcpn"},{"name":"mly_avgt"}],"meta":"ll,elev","output":"json"}') # or uid

out<-postForm("http://data.rcc-acis.org/GridData",
              .opts = list(postfields = jsonQuery,
                           httpheader = c('Content-Type' = 'application/json', Accept = 'application/json')))
out<-fromJSON(out)

#### process precip data from out ####
# convert to list of matrices, flipud with PRISM
matrixList <- vector("list",length(out$data))
for(i in 1:length(out$data)){
  matrixList[[i]]<-apply(t(out$data[[i]][[2]]),1,rev)
}
# read into raster stack
rasterList<-lapply(matrixList, raster)
gridStack<-stack(rasterList)
gridExtent<-extent(min(out$meta$lon), max(out$meta$lon), min(out$meta$lat), max(out$meta$lat))
gridStack<-setExtent(gridStack, gridExtent, keepres=FALSE, snap=FALSE)
names(gridStack)<-allDates
# set 0 and neg to NA
gridStack[gridStack < 0] <- NA
#####

#### process temp data from out #####
matrixList <- vector("list",length(out$data))
for(i in 1:length(out$data)){
  matrixList[[i]]<-apply(t(out$data[[i]][[3]]),1,rev)
}

# read into raster stack
rasterList<-lapply(matrixList, raster)
tempStack<-stack(rasterList)
gridExtent<-extent(min(out$meta$lon), max(out$meta$lon), min(out$meta$lat), max(out$meta$lat))
tempStack<-setExtent(tempStack, gridExtent, keepres=FALSE, snap=FALSE)
names(tempStack)<-allDates
# set 0 and neg to NA
tempStack[tempStack <= -999] <- NA
#####

## manage dates
allDates<-as.data.frame(allDates)
allDates$month<-as.numeric(format(allDates$allDates, "%m"))
allDates$year<-as.numeric(format(allDates$allDates, "%Y"))

# extract time series
# unweighted, spatial mean monthly precipitation 
temp1 <- t(extract(gridStack, Level1Data, fun='mean', na.rm=TRUE, df=TRUE, weights = FALSE))
temp1 <- temp1[2:nrow(temp1),] # drop that first ID row
temp2 <- data.frame(temp1)
# unweighted, spatial mean monthly temperature 
temp1 <- t(extract(tempStack, Level1Data, fun='mean', na.rm=TRUE, df=TRUE, weights = FALSE))
temp1 <- temp1[2:nrow(temp1),] # drop that first ID row
temp3 <- data.frame(temp1)
temp3$rollMean12 <- zoo::rollmean(temp3, 12, align = 'right', fill = NA) ## Rolling sum
# assemble dataframe
climTS <- data.frame(allDates, round(temp2,2), round(temp3,2))
colnames(climTS)<-c("date","month","year","precip_in","temp_F","temp_F_12mo")

# add in SPI values
climTS$spi3<-round(SPEI::spi(climTS$precip_in, scale=3, 
          na.rm=TRUE)$fitted,2)
climTS$spi12<-round(SPEI::spi(climTS$precip_in, scale=12, 
                       na.rm=TRUE)$fitted,2)
# write out file
write.csv(climTS, row.names = FALSE, file="MWEPA_1_climate.csv")
#

