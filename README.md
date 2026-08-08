MATLAB based model to quantify the engineering based suitability of sites for solar PV projects. Get the data from open source sites for dem from open topography and 
for lulc data write the code 
url = get_worldcover_url(27.54, 71.91, 2021);
     websave('data/lulc.tif', url);
     with the coordinates of the site
