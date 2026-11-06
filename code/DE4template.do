set more off
capture log close
cap clear matrix
clear

/* This program answers questions for problem set 4, part III...
   Name: 
   Date:
*/
/* (text between /* and */ are just "comments" -- it is your notes to remember what the 
   program was doing at that point.  It does not execute any STATA commands) */


/* Please fill in the "" the location where you keep the data and output (like C:\Ec20\ps2b or
   something) and for "yourfile" what you want to name the output file below */
cd ""
log using "DE4.log", replace

/* Part III of problem set... */
/* Question 1  */
import excel using wdi_example2.xlsx, firstrow
summ

* drop missing data
drop if GNI==.|Mer==.
summ

* question 2b
tab CountryName if Mer>200

capture log close /* last command in any program */
