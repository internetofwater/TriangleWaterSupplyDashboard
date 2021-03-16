function createTraceDemand(target){
  checkedDemand = [];
  $("input[name='checkDemandYear']:checked").each(function() {
    checkedDemand.push($(this).val());
  });
  
  Plotly.purge('demandPlot');
  createDemandInfo(myUtilityID, checkedDemand);
  return checkedDemand;
}

//##################################################################################################################
//               READ IN TIME SERIES
//##################################################################################################################
function createDemandInfo(myUtilityID, checkedDemand){
//parse date to scale axis
parseDate = d3.timeParse("%Y-%m-%d"); 

//console.log(checkedDemand);
//read in stream stats
d3.csv("data/demand/demand_over_time.csv").then(function(demandData){
    demandData.forEach(function(d){
            d.date2 = parseDate(("2020-"+d.date2.substring(5,d.date2.length)));
            d.mean_demand = +d.mean_demand;
            d.month = +d.month;
            d.year = +d.year;
            d.peak_demand = +d.peak_demand;
       });

var selDemand = demandData.filter(function(d){ return d.pwsid === myUtilityID.toLowerCase() && d.year >= 1997; });

if (selDemand.length <= 0) {
  console.log("no utility");
  //Plotly.purge('demandPlot');
  document.getElementById("demandTitle").innerHTML = "Select a utility with data to see demand";
  document.getElementById("demandPlot").innerHTML = '<img src="img/demand_chart_icon.png" style="width: 350px; height: 350px; display: block; margin-left: auto; margin-right: auto;">';
}

if (selDemand.length > 0){
  document.getElementById("demandPlot").innerHTML = ""; //set blank plot
    var maxYValue = (d3.max(selDemand, function(d) { return d.peak_demand; }) * 1.1).toFixed(0);
    //console.log(maxYValue);
    //create multiple traces
    var data = [];
    var xMonths = selDemand.map(function(d) {return d.date2; });
    let xMonth = xMonths.filter((item, i, ar) => ar.indexOf(item) === i);

    //draw the traces for all years but current
    var xYears = [2000, 2001, 2002, 2003, 2004, 2005, 2006, 2007, 2008, 2009, 2010, 
                  2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020, 2021];
    var yOther = [];    var otherYearTrace;


    for (i=0; i < xYears.length-1; i++){
      tempSelect = xYears[i];
      temp = selDemand.filter(function(d) {return d.year === tempSelect; });
      tempName = "%{y:.1f} mgd in " + tempSelect;
      //xDate = temp.map(function(d){ return d.date; });
      yOther = temp.map(function(d){ return d.mean_demand; });
      //create individual trace
      var showLegVal = true;
      if(i > 0) { showLegVal = false; }

        OtherYearTrace = 
            {
              x: xMonth,   y: yOther,
              mode: 'lines', type: 'scatter',
              hovertemplate: tempName,
              opacity: 0.4,
              line: {color: '#c5c5c5', width: 1}, //light coral
              name: "years",
              showlegend: showLegVal
            };
      
      //push trace
    data.push(OtherYearTrace);
    } // end for loop

    //draw other selected years
      var selectYears;  var selectTraces; 
    //set array of colors
      var colorLineAll = ["rgb(26,121,131)", "#567258", "#bf9f4c","#b9b59f", "#6f634d", "#314837",
                        "#b0d76f", "#0ed0d0", "#246f8f", "5234578", "#900909", "#d16014", "#58381f"];
      var colorLine;

      for (i=0; i < checkedDemand.length; i++){
        tempSelect = Number(checkedDemand[i]);
        selectYears = selDemand.filter(function(d) {return d.year === tempSelect;}).map(function(d) { return d.mean_demand; });
        tempName = "%{y:.1f} mgd in %{x}, " + tempSelect;
        colorLine = colorLineAll[i];
          if (tempSelect === 2002) { colorLine = "red"; }
          if (tempSelect === 2007) { colorLine = "darkred"; }
          
        selectTraces = {
                x: xMonth,   y: selectYears,
                mode: 'lines', type: 'scatter',
                hovertemplate: "%{y:.1f} mgd in %{x}, " + tempSelect,
                opacity: 1,
                line: {color: colorLine, width: 2}, 
                name: tempSelect,
                showlegend: true
              };
        data.push(selectTraces);
      }
      
    //draw median and selected year
    selDemandNow = selDemand.filter(function(d){ return d.year === currentYear;}) ;
    var ySelect = selDemandNow.map(function(d) {return d.mean_demand; });
    
    //PLOTLY
    var seltrace = {
      y: ySelect,  x: xMonth,
      /*marker: {
        size: 6, color: "rgb(43,28,88",
        line: {color: 'black', width: 1}
        },*/
      line: {color: 'rgb(43,28,88', width: 3},
      mode: 'lines',
      type: 'scatter',
      name: '2021',
      showlegend: true,
      hovertemplate: '%{y:.1f} mgd in %{x}',
    };

    var layout = {
        yaxis: {
            title: 'Daily Demand (MGD)',
            titlefont: {color: 'rgb(0, 0, 0)', size: 14 },
            tickfont: {color: 'rgb(0, 0, 0)', size: 12},
            showline: false,
            showgrid: true,
            showticklabels: true,
            range: [0, maxYValue]
        },
        xaxis: {
          showline: false,
          showgrid: true,
          showticklabels: true,
          tickformat:  '%b-%d',
          title: '',
          titlefont: {color: 'rgb(0, 0, 0)', size: 14},
          tickfont: {color: 'rgb(0, 0, 0)', size: 12},
          //range: [0, 15]
        },
        hovermode: 'closest',
        height: 375,
        //showlegend: true,
        margin: { t: 20,   b:50,  r: 10,   l: 40  },
      };

      data.push(seltrace);
      Plotly.newPlot('demandPlot', data, layout);

    //load document names
      if(myUtility === "none"){ 
        document.getElementById("demandTitle").innerHTML = "Select a utility on the map to learn more";
      }

      if(myUtility !== "none"){ 
        var selCurDemand = selDemand.map(function(d){return d.mean_demand; });
        var thisWeekDemand = selCurDemand[selCurDemand.length-1];
        var lastWeekDemand = selCurDemand[(selCurDemand.length-8)];

        //now how does this compare to last week?
        var demandTrajectory;
        if(thisWeekDemand > lastWeekDemand) {demandTrajectory = "higher"; }
        if(thisWeekDemand < lastWeekDemand) {demandTrajectory = "lower"; }
        if(thisWeekDemand.toFixed(1) === lastWeekDemand.toFixed(1) ) {demandTrajectory = "equal"; }

        document.getElementById("demandTitle").innerHTML = myUtility + " has " + demandTrajectory + 
        " demand than last week";
      }
  } //end if we have utility data for selectect utility

  });// end D3


} //END CREATE CHART FUNCTION ##########################################################


/*
//Load Data and get correct########################################################
//load current demand
  d3.csv("data/demand/current_demand.csv").then(function(currentData){
    currentData.forEach(function(d){
            d.date = parseDate(d.date);
            d.demand_mgd = +d.demand_mgd;
            d.mean_demand = +d.mean_demand;
            d.last_demand = +d.last_demand;
  });

var selCurDemand = currentData.filter(function(d){ return d.pwsid === myUtilityID.toLowerCase(); });
  
//load document names
if(myUtility === "none"){ 
    document.getElementById("demandTitle").innerHTML = "<h4>Select a utility on the map to learn more.</h4>";
  }

  if(myUtility !== "none"){ 
    document.getElementById("demandTitle").innerHTML = "<h4>" + myUtility + " has " + selCurDemand[0].trajectory + " demand then last month.</h4>"  + 
    "<p style='background-color: rgba(26,121,131,0.2); font-size: 15px;'>Current demand is " + selCurDemand[0].demand_mgd.toFixed(1) + 
    " mgd, compared to an average of " + selCurDemand[0].mean_demand.toFixed(1) + " mgd for " + selCurDemand[0].monthAbb + "</p>"; 
  }

  });//end current demand
  */