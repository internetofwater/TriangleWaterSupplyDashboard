###################################################################################################################################################
#
# Creates initial map layers and downloads historic data for the dashboard
# CREATED BY LAUREN PATTERSON & KYLE ONDA @ THE INTERNET OF WATER
# FEBRUARY 2021
# Run anytime... change county.list if desire. 
#
###################################################################################################################################################


######################################################################################################################################################################
#
#   ACCESS GROUNDWATER DATA = MANUAL PROCESS
#
######################################################################################################################################################################
#set up base url
#https://cida.usgs.gov/ngwmn_cache/sos?request=GetCapabilities&service=SOS&acceptVersions=2.0.0&acceptedFormats=text/xml
#because of set up did a manual download of sites in NC
nc.sites <- read.csv(paste0(swd_html, "gw\\ALL_SITE_INFO.csv")); #all NAD83
nc.sites <- nc.sites %>% select(AgencyCd, SiteNo, SiteName, DecLatVa, DecLongVa, AltVa, AltUnitsNm, WellDepth, WellDepthUnitsNm, NatAquiferCd, NatAqfrDesc, StateCd, StateNm, CountyCd, CountyNm,
                                LocalAquiferCd, LocalAquiferName, SiteType, AquiferType) %>% rename(site = SiteNo)
#table(nc.sites$CountyNm)

#save out sites
write.csv(nc.sites, paste0(swd_html, "gw\\gw_sites.csv"), row.names = FALSE)


######################################################################################################################################################################
#
# PULL IN GW LEVEL DATA DYNAMICALLY
#
#####################################################################################################################################################################
zt <- st_as_sf(nc.sites, coords = c("DecLongVa", "DecLatVa"), crs = 4326, agr = "constant")
table(nc.sites$AgencyCd)
#break up by agency to dynamically pull datea
usgs.sites <- nc.sites %>% filter(AgencyCd=="USGS")
dwr.sites <- nc.sites %>% filter(AgencyCd=="NCDWR")

############################################     RUN FOR USGS   #####################################################################################################
#calculate unique sites
unique.usgs.sites <- unique(usgs.sites$site)

#set up data frame for stats and include year
stats <- as.data.frame(matrix(nrow=0,ncol=13));        colnames(stats) <- c("site", "julian", "min", "flow10", "flow25", "flow50", "flow75", "flow90", "max", "Nobs","startYr","endYr","date"); 
year.flow  <- as.data.frame(matrix(nrow=0, ncol=4));    colnames(year.flow) <- c("site", "date", "julian", "flow_cms")

#Loop through each site and calculate statistics
for (i in 1:length(unique.usgs.sites)){
  #for some reason there is quite a lag on daily values
#  zt <- readNWISgwl(siteNumbers = unique.usgs.sites[i], startDate=start.date, endDate = end.date)
#  zt <- renameNWISColumns(zt) %>% select(agency_cd, site_no, lev_dt, lev_va) %>% rename(Date = lev_dt, depth_below_surface_ft = lev_va)
#  zt <- zt %>% mutate(julian = as.POSIXlt(Date, format = "%Y-%m-%d")$yday, year = year(Date))# %>% mutate(date = paste0(month(Date, label=TRUE, abbr=TRUE),"-",day(Date))); #calculates julian date as.Date(c("2007-06-22", "2004-02-13"))
  url = paste0("https://waterdata.usgs.gov/nc/nwis/dv?cb_72019=on&format=rdb&site_no=", unique.usgs.sites[i],"&referred_module=sw&period=&begin_date=",start.date,"&end_date=",end.date)
  #call url
  zt <- read_csv(url, comment="#")
  colnames(zt)<-"df_split";
  zt <- zt[-1,]
  #start cleaning
  zt <- data.frame(do.call('rbind', strsplit(as.character(zt$df_split),'\t',fixed=TRUE)))
  print(paste(unique.usgs.sites[i], "has ", dim(zt)[2], " columns"))
  
  if(dim(zt)[2]==5){
    zt <- zt %>% rename(site = X2, date=X3, depth_below_surface_ft = X4) %>% select(site, date, depth_below_surface_ft) %>% mutate(depth_below_surface_ft = as.numeric(as.character(depth_below_surface_ft)))
  }
  if(dim(zt)[2]==9){
    zt <- zt %>% rename(site = X2, date=X3, depth_below_surface_ft = X8) %>% select(site, date, depth_below_surface_ft) %>% mutate(depth_below_surface_ft = as.numeric(as.character(depth_below_surface_ft)))
  }
  #if missing data the site number is repeated or non-numeric value
  zt <- zt %>% mutate(depth_below_surface_ft = ifelse(depth_below_surface_ft > 99999, NA, depth_below_surface_ft))
  
  zt <- zt %>% mutate(julian = as.POSIXlt(date, format = "%Y-%m-%d")$yday, year = year(date))# %>% mutate(date = paste0(month(Date, label=TRUE, abbr=TRUE),"-",day(Date))); #calculates julian date as.Date(c("2007-06-22", "2004-02-13"))
  
  #summarize by julian
  zt.stats <- zt %>% group_by(julian) %>% summarize(Nobs = n(), min=round(min(depth_below_surface_ft, na.rm=TRUE),4), flow10 = round(quantile(depth_below_surface_ft, 0.10, na.rm=TRUE),4), flow25 = round(quantile(depth_below_surface_ft, 0.25, na.rm=TRUE),4),
                                                    flow50 = round(quantile(depth_below_surface_ft, 0.5, na.rm=TRUE),4), flow75 = round(quantile(depth_below_surface_ft, 0.75, na.rm=TRUE),4), flow90 = round(quantile(depth_below_surface_ft, 0.90, na.rm=TRUE),4), 
                                                    max = round(max(depth_below_surface_ft, na.rm=TRUE),4),
                                                    .groups="keep")
  zt.stats <- zt.stats %>% mutate(site = as.character(unique.usgs.sites[i]), startYr = min(zt$year), endYr = max(zt$year)) %>% select(site, julian, min, flow10, flow25, flow50, flow75, flow90, max, Nobs, startYr, endYr)
  if(dim(zt.stats)[1] == 366) {zt.stats$date = julian$month.day366}
  if(dim(zt.stats)[1] < 366) { zt.stats <- merge(zt.stats, julian[,c("julian", "month.day365")], by.x="julian", by.y="julian", all.x=TRUE)   
    zt.stats <- zt.stats %>% rename(date = month.day365)
  } #assumes 365 days... could be wrong
  
  #fill dataframe
  stats <- rbind(stats, zt.stats)
  zt <- zt %>% select(site, date, julian, depth_below_surface_ft);    colnames(zt) <- c("site", "date", "julian", "depth_ft")
  zt <- zt %>% group_by(site, date, julian) %>% summarize(depth_ft = median(depth_ft, na.rm=TRUE), .groups="drop")
  year.flow <- rbind(year.flow, zt)
  
  print(i)
}
#if inifinite value because of 1 observation... 
#is.na(stats) <- sapply(stats, is.infinite)
summary(stats)
summary(year.flow)

usgs.stats <- stats;
usgs.year.flow <- year.flow;


############################################     RUN FOR NCDWR   #####################################################################################################
#url_base <- "https://www.ncwater.org/Data_and_Modeling/Ground_Water_Databases/potmaps/gwbdatafiles/"   #m53l1115239lev.txt"
#                 ONLY HAS DATA FOR LAST TWO YEARS
#
#########################################################################################################################################################################
url.sites <- dwr.sites %>% mutate(site2 = site) %>%  separate(site, into = c("text", "num", "text2"), sep = "(?<=[A-Za-z])(?=[0-9])(?<=[A-Za-z])") %>% mutate(url_site = paste0(text,"**",num,text2))
url.sites$link = NA

#This takes longer than 30 minutes to run
unique.dwr.sites <- unique(url.sites$url_site)
for (i in 1:length(unique.dwr.sites)){
  test <- xml2::read_html(paste0("https://www.ncwater.org/?page=536&id=",unique.dwr.sites[i]))
  a <- test %>%
    rvest::html_node("main") %>%
    rvest::html_node("div") %>%
    rvest::html_node("table") %>%
    rvest::html_nodes(xpath="//a") 
  a.test <- grep('elev.txt', a, value=TRUE)
  
  for (v in 1:length(a)){
    a.test = grep('lev.txt', html_attr(a[v], "href"), value=TRUE)
    if(length(a.test) > 0) {
      url.sites$link[i] <- paste0("https://www.ncwater.org",html_attr(a[v],"href")) 
    }
  }
print(paste(i, "-", url.sites$link[i]))
}  
bk.up <- url.sites
nc.sites <- merge(nc.sites, url.sites[,c("site2","link")], by.x="site", by.y="site2", all.x=TRUE)
#head(nc.sites)
#set usgs link - https://waterdata.usgs.gov/monitoring-location/355944079013401/#parameterCode=72019&period=P7D
nc.sites <- nc.sites %>% mutate(link = ifelse(AgencyCd=="USGS", paste0("https://waterdata.usgs.gov/monitoring-location/", site, "#parameterCode=72019&period=P7D"), link))
write.csv(nc.sites, paste0(swd_html, "gw\\gw_sites.csv"), row.names = FALSE)


#Build on USGS dataframe
#Loop through each site and calculate statistics
for (i in 1:length(unique.dwr.sites)){
  zt.site <- url.sites[i,]$site2
  zt <- read.csv(url.sites$link[i], header=FALSE, sep="\t")
    colnames(zt) <- c("date", "depth_below_surface_ft", "elevation")
    zt <- zt %>% mutate(julian = as.POSIXlt(date, format = "%Y-%m-%d")$yday, year = year(date), site = zt.site)
    #999.99 are no data
    zt <- zt %>% mutate(depth_below_surface_ft = ifelse(depth_below_surface_ft == 999.99, NA, depth_below_surface_ft))
    #summarize by julian
    zt.stats <- zt %>% group_by(julian) %>% summarize(Nobs = n(), min=round(min(depth_below_surface_ft, na.rm=TRUE),4), flow10 = round(quantile(depth_below_surface_ft, 0.10, na.rm=TRUE),4), flow25 = round(quantile(depth_below_surface_ft, 0.25, na.rm=TRUE),4),
                                                      flow50 = round(quantile(depth_below_surface_ft, 0.5, na.rm=TRUE),4), flow75 = round(quantile(depth_below_surface_ft, 0.75, na.rm=TRUE),4), flow90 = round(quantile(depth_below_surface_ft, 0.90, na.rm=TRUE),4), 
                                                      max = round(max(depth_below_surface_ft, na.rm=TRUE),4),
                                                      .groups="keep")
    zt.stats <- zt.stats %>% mutate(site = zt.site, startYr = min(zt$year), endYr = max(zt$year)) %>% ungroup() %>% dplyr::select(site, julian, min, flow10, flow25, flow50, flow75, flow90, max, Nobs, startYr, endYr)
    if(dim(zt.stats)[1] == 366) {zt.stats$date = julian$month.day366}
    if(dim(zt.stats)[1] < 366) { zt.stats <- merge(zt.stats, julian[,c("julian", "month.day365")], by.x="julian", by.y="julian", all.x=TRUE)   
        zt.stats <- zt.stats %>% rename(date = month.day365)
    } #assumes 365 days... could be wrong
    
    #fill dataframe
    stats <- rbind(stats, zt.stats)
    zt <- zt %>% dplyr::select(site, date, julian, depth_below_surface_ft) %>% rename(depth_ft = depth_below_surface_ft)
    #remove any that have multiple measures on same day
    zt <- zt %>% group_by(site, date, julian) %>% summarize(depth_ft = median(depth_ft, na.rm=TRUE), .groups="drop")
    #zt <- zt %>% select(site, date, julian, depth_below_surface_ft);
    year.flow <- rbind(year.flow, zt)

  print(paste(i, ", percent done:", round(i/dim(url.sites)[1]*100,1)))
}
#if inifinite value because of 1 observation... 
bk.up.stats <- stats
bk.up.year <- year.flow

is.na(stats) <- sapply(stats, is.infinite)
unique(stats$site)
summary(stats)
summary(year.flow)

year.flow <- year.flow %>% filter(year(as.Date(date, format="%Y-%m-%d")) >= year(start.date))
write.csv(year.flow, paste0(swd_html, "gw\\all_gw_levels.csv"), row.names=FALSE)





