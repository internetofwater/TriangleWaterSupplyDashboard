# API - define nedpoint
api <- "https://twsd.internetofwater.dev/api/v1.0/"
#api <- "http://localhost:8080/FROST-Server/v1.0/"
user <- "iow"
password <- "nieps"

source("sta-post.R")
library(jsonlite)
library(httr)
library(readxl)
library(dplyr)
library(lubridate)

# Define Observed Properties
op <- PostObservedProperty(api=paste0(api,"ObservedProperties"), user, password,
                           id = "WaterDistributed",
                           name = "Water Distributed",
                           definition = "http://vocabulary.odm2.org/api/v1/variablename/waterUsePublicSupply/",
                           description = "Water distributed for use by consumers of utility water")

op <- PostObservedProperty(api=paste0(api,"ObservedProperties"), user, password,
                           id = "StorageCapacity",
                           name = "Storage Capacity (% full)",
                           definition = "http://vocabulary.odm2.org/api/v1/variablename/reservoirStorage/",
                           description = "Percentage of water storage capacity available for distribution")

op <- PostObservedProperty(api=paste0(api,"ObservedProperties"), user, password,
                           id = "WaterShortageStage",
                           name = "Water Shortage Stage",
                           definition = "https://www.ncwater.org/WUDC/app/LWSP/learn.php",
                           description = "Phases of water shortage severity associated with appropriate responses for each phase")

# Define Sensors
s <- PostSensor(api=paste0(api,"Sensors"), user, password,
                id = "ShortageStageReport",
                name = "Water Shortage Status",
                description = "Water Shortage Status form submitted to ncwater.org",
                encodingType = "application/pdf",
                metadata = "https://www.ncwater.org/WUDC/")

s <- PostSensor(api=paste0(api,"Sensors"), user, password,
                id = "StorageReport",
                name = "Report of available water storage",
                description = "Report of available water storage",
                encodingType = "application/pdf",
                metadata = "https://www.ncwater.org/WUDC/")

s <- PostSensor(api=paste0(api,"Sensors"), user, password,
                id = "DemandReport",
                name = "Report of delivered water",
                description = "Report of delivered water",
                encodingType = "application/pdf",
                metadata = "https://www.ncwater.org/WUDC/")


# Define a Thing/ Location
x <- sf::read_sf("https://geoconnex.us/ref/pws/NC0368010")

list <- list("https://geoconnex.us/ref/pws/NC0368010", #OWASA
        "https://geoconnex.us/ref/pws/NC0392010", #Raleigh
        "https://geoconnex.us/ref/pws/NC0332010", #Durham
        "https://geoconnex.us/ref/pws/NC0392020", #Cary
        "https://geoconnex.us/ref/pws/NC0326010" #Fayatteville
         )

for (i in list){
    x <- sf::read_sf(i)
    y <- sfc_geojson(x$geometry)
    thing <- jsonlite::toJSON(list(`@iot.id`=x$PWSID,
                                   name = x$NAME,
                                   description = x$SDWIS,
                                   properties = list(PWSID=x$PWSID)), 
                              auto_unbox=TRUE)

     p <- POST(url = paste0(api,"Things"),
          encode="raw",
          authenticate("iow", "nieps", type ="basic"),
          body = thing)


     

     # loc <- jsonlite::toJSON(list(`@iot.id`= x$PWSID,
     #                              name = paste0("Service area of ",x$PWSID),
     #                              description = paste0("Service area of ",x$NAME),
     #                              encodingType = "application/vnd.geo+json",
     #                              location = y), auto_unbox = TRUE)

     loc <- paste0('{"@iot.id":"',x$PWSID,'","name":"',paste0("Service area of ",x$PWSID),'", ','"description":"',paste0("Service area of ", x$NAME),'", ','"encodingType":"application/vnd.geo+json", "location":',
                   y,'}')
     loc <- fromJSON(loc)
     loc <- toJSON(loc,auto_unbox = TRUE) 

     p2 <- POST(url = paste0(api,"Things('",x$PWSID,"')","/Locations"),
                encode="raw",
                authenticate("iow", "nieps", type ="basic"),
                body = loc)
     
     d1 <- PostDataStream(paste0(api,"Datastreams"),user,password,
                          id=paste(x$PWSID,"ShortageStage", sep="-"),
                          name = paste0("Shortage Stage for ",x$NAME),
                          description = paste0("Shortage Stage for ",x$NAME),
                          observationType = "http://www.opengis.net/def/observationType/OGC-OM/2.0/OM_CategoryObservation",
                          unit = list(definition="https://www.ncwater.org/WUDC/",
                                                   name = "Level",
                                                   symbol = "Level"),
                          Thing_id = x$PWSID,
                          Sensor_id = "ShortageStageReport",
                          ObservedProperty_id = "WaterShortageStage")
     
     d2 <- PostDataStream(paste0(api,"Datastreams"),user,password,
                          id=paste(x$PWSID,"StorageCapacity", sep="-"),
                          name = paste0("Storage Capacity (% full) for ",x$NAME),
                          description = paste0("Storage Capacity (% full) for ",x$NAME),
                          observationType = "http://www.opengis.net/def/observationType/OGC-OM/2.0/OM_Measurement",
                          unit = list(definition="http://qudt.org/vocab/unit/PERCENT",
                                      name = "Percent",
                                      symbol = "%"),
                          Thing_id = x$PWSID,
                          Sensor_id = "StorageReport",
                          ObservedProperty_id = "StorageCapacity")
     
     d3 <- PostDataStream(paste0(api,"Datastreams"),user,password,
                          id=paste(x$PWSID,"WaterDistributed", sep="-"),
                          name = paste0("Water distributed (MGD) by ",x$NAME),
                          description = paste0("Average Water distributed (MGD) in the preceding period by ",x$NAME),
                          observationType = "http://www.opengis.net/def/observationType/OGC-OM/2.0/OM_Measurement",
                          unit = list(definition="http://his.cuahsi.org/mastercvreg/edit_cv11.aspx?tbl=Units&id=1125579048",
                                      name = "Million Gallons per Day",
                                      symbol = "MGD"),
                          Thing_id = x$PWSID,
                          Sensor_id = "DemandReport",
                          ObservedProperty_id = "WaterDistributed")
                          

}



## Add data.
monthly_withdrawal <- read_excel("data/lwsp/monthly_withdrawal.xlsx")
monthly_withdrawal$PWSID <- paste0("NC",gsub("-","",monthly_withdrawal$pwsid,))
m <- monthly_withdrawal%>%
    filter(PWSID %in% gsub("https://geoconnex.us/ref/pws/","",list))

m$resultTime <- ISOdatetime(m$year,m$month,day=1,hour=0,min=0,sec=1,tz="America/New_York")
m$days <- days_in_month(m$resultTime)
m$Datastream = paste0(m$PWSID,"-WaterDistributed")
m<-filter(m,year>2008)
m$result = m$avg_daily

model <- lm(result ~ as.factor(month) + year + year*as.factor(Datastream) + as.factor(Datastream),data=m)
nd <- expand.grid(c(2018:2020),c(1:12),unique(m$Datastream))
nd <- nd %>% rename(year=Var1, month=Var2, Datastream=Var3) %>% filter(!(year==2020 & month>10))
nd$result <- predict(model, nd)
nd$resultTime <- ISOdatetime(nd$year,nd$month,day=1,hour=0,min=0,sec=1,tz="America/New_York")

o <- select(m,Datastream,resultTime,result,year,month)
o <- bind_rows(o,nd)
o$days <- days_in_month(o$resultTime)
o$resultTime <- paste0(gsub(" ","T",as.character(o$resultTime)),".000Z")

for(i in 1:length(o$Datastream)){
    try(
    PostObs(api,user, password,
             ds = o$Datastream[i],
             result = o$result[i],
             resultTime = o$resultTime[i],
             days = o$days[i])
    )
}

# for(i in 1:length(o$Datastream)){
#   try(
#     PatchObs(api,user, password,
#             ds = o$Datastream[i],
#             result = o$result[i],
#             resultTime = o$resultTime[i],
#             days = o$days[i])
#   )
# }
# 
# for(i in 1:length(o$Datastream)){
#   try(
#     DELETE(paste0(api,"Observations('",o$Datastream[i],"-",o$resultTime[i],"')"),authenticate(user,password,type="basic"))
#   )
# }


obs <- toJSON(o)

deleteEntity(api,user,password,entity="Things",iot.id=5)
