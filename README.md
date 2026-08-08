MATLAB based model to quantify the engineering based suitability of sites for solar PV projects. 

Get the data from open source sites for dem from open topography and save it in the dem file in data folder and 
for lulc data write the code 

url = get_worldcover_url(27.54, 71.91, 2021);
     websave('data/lulc.tif', url);
 with the coordinates of the site

In the input file write the name of the site and its coordintes.
Next run the file acquire_data to get the input data.
Run the file run_knockout and then run the file run_scoring.
