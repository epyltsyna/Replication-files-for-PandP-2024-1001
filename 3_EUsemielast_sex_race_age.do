clear
tempfile shocks inflation

global directory_source = "G:\Research\ShabalinaE\Replication_files_AEA_PP_Heterogeneous Effects of Monetary Policy on Job Flows Across Income, Race, Gender and Age\1_source"
global directory_build = "G:\Research\ShabalinaE\Replication_files_AEA_PP_Heterogeneous Effects of Monetary Policy on Job Flows Across Income, Race, Gender and Age\2_build"



import delimited "$directory_source/inflation", clear

gen daydate = date(date,"YMD")

gen int year = year(daydate)
gen byte month = month(daydate)

keep pcepi year month

save `inflation'

import delimited "$directory_source/mp_shocks_1988_2019.csv",clear

gen daydate = date(date,"MDY")
gen int year = year(daydate)
gen byte month = month(daydate)
gen day = day(daydate)
gen winwt = (days_leftmonth+day)/days_leftmonth

gen mpshock = tight_surprise * winwt

drop date

collapse winwt mpshock tight_surprise day days_leftmonth, by(month year)

save `shocks'

use "$directory_source/MPshock_CPS.dta", clear
drop if asecflag ==1

gen date = ym(year,month)

drop if cpsidp ==0
//duplicates drop cpsidp date, force


//merge in MP shocks
merge m:1 month year using `shocks', gen(_shocks_in)
merge m:1 month year using "$directory_build/bauer_swanson_shocks.dta", gen(_shocks_in_bs)
merge m:1 month year using `inflation', gen(_inflation_in)

xtset cpsidp date, monthly

// Reduce the sample size to run faster
// keep if occ >= 500 & occ <=2400

// check that age and race and sex don't change:
by cpsidp: egen difsex = sd(sex)
by cpsidp: egen maxage = max(age) 
by cpsidp: egen minage = min(age) 
gen difage = maxage - minage

drop if difsex >0
drop if difage > 3
drop maxage minage difage difsex

replace mpshock = 0.0 if _shocks_in ==2
replace mp_bs = 0.0 if _shocks_in_bs == 2

gen cpsearn = earnweek
replace earnweek =. if earnweek >=9999
gen earnweek0 = earnweek
replace earnweek0 = 0.0 if empstat >=20 & empstat <= 36

gen rearn = earnweek/pcepi * 100
gen rearn0 = rearn 
replace rearn0 = 0.0 if empstat >=20 & empstat <= 36

// Labor market flows
gen EU = (empstat >=10 & empstat < 20 ) & (f.empstat>=20 & f.empstat<30)
gen EN = (empstat >=10 & empstat < 20 ) & (f.empstat>=20 & f.empstat<.)
gen UE = (f.empstat >=10 & f.empstat < 20 ) & (empstat>=20 & empstat<30)
gen NE = (f.empstat >=10 & f.empstat < 20 ) & (empstat>=20 & empstat<.)

// Now run this all on a pseudo panel: 
replace EU = . if !(empstat >=10 & empstat < 20 )
replace EN = . if !(empstat >=10 & empstat < 20 )
replace UE = . if !(empstat>=20 & empstat<30)
replace NE = . if !(empstat>=20 & empstat<. )

gen EUmish5 = EU if mish>4
gen ENmish5 = EN if mish>4
gen UEmish5 = UE if mish>4
gen NEmish5 = NE if mish>4

save tmp, replace

*use tmp



gen rearn_dlog = (f12.rearn - rearn) / (0.5 * (f12.rearn + rearn))
gen mpshock_pos = mpshock if mpshock >0
gen mpshock_neg = mpshock if mpshock <0
gen mpshock_bs_pos = mp_bs if mp_bs > 0 
gen mpshock_bs_neg = mp_bs if mp_bs < 0

gen ages_dummy = 0 // as in Guvenen et. al. "What Do Data on Millions of U.S. Workers Reveal About Life-Cycle Earnings Dynamics?"
replace ages_dummy = 1 if age > 29 & age < 35
replace ages_dummy = 2 if age > 34 & age < 40
replace ages_dummy = 3 if age > 39 & age < 45
replace ages_dummy = 4 if age > 44 & age < 50
replace ages_dummy = 5 if age > 49 & age < 55
drop if age < 25
drop if age > 54

gen ages_dummy2 = ages_dummy
replace ages_dummy = 0 if ages_dummy2 <= 2
replace ages_dummy = 1 if ages_dummy2 > 2

gen race_dummy = 0 // other race
replace race_dummy = 1 if race == 100 // white
replace race_dummy = 2 if race == 200 // black

label define race_lb 0 "Other race" 1 "White" 2 "Black"
label values race_dummy race_lb

reg rearn_dlog i.sex i.race_dummy i.paidhour
matrix eb_cons= e(b)
gen mean_rearn = eb_cons[1,11]
predict resid_rearn, residuals

replace rearn_dlog = resid_rearn + mean_rearn // constant from the regression // uncomment to control before collapsing

// 1. First collapse just by age and date
preserve 
collapse mpshock mpshock_pos mpshock_neg mp_bs mpshock_bs_pos mpshock_bs_neg rearn rearn_dlog earnweek EU* EN* UE* NE* [aw=wtfinl], by(ages_dummy date)

gen mpshock0 = mpshock
gen mpshock_bs0 = mp_bs
replace mpshock_pos = 0 if mpshock0 >=.
replace mpshock_neg = 0 if mpshock0 >=.
replace mpshock0 = 0 if mpshock0 >=.
replace mpshock_bs_pos = 0 if mpshock_bs0 >=.
replace mpshock_bs_neg = 0 if mpshock_bs0 >=.
replace mpshock_bs0 = 0 if mpshock_bs0 >=.

eststo clear
********************* LP GW EN age *********************
eststo en_age_gw: reg ENmish5 c.mpshock0#i.ages_dummy i.ages_dummy
//eststo en_age_gw: reg ENmish5 c.mpshock_pos#i.ages_dummy i.ages_dummy


esttab using "$directory_build/Tables/labor_by_age.tex", replace label r2 se title("Instantaneous IRFs across age groups for labor market flows and earnings") star(* 0.10 ** 0.05 *** 0.01)
//esttab using "$directory_build/Tables/labor_by_age_contractionary.tex", replace label r2 se title("Instantaneous IRFs across age groups for labor market flows and earnings") star(* 0.10 ** 0.05 *** 0.01)
restore
preserve 
collapse mpshock mpshock_pos mpshock_neg mp_bs mpshock_bs_pos mpshock_bs_neg rearn rearn_dlog earnweek EU* EN* UE* NE* [aw=wtfinl], by(race_dummy date)

gen mpshock0 = mpshock
gen mpshock_bs0 = mp_bs
replace mpshock_pos = 0 if mpshock0 >=.
replace mpshock_neg = 0 if mpshock0 >=.
replace mpshock0 = 0 if mpshock0 >=.
replace mpshock_bs_pos = 0 if mpshock_bs0 >=.
replace mpshock_bs_neg = 0 if mpshock_bs0 >=.
replace mpshock_bs0 = 0 if mpshock_bs0 >=.

eststo clear
********************* LP GW EN race *********************
eststo en_race_gw: reg ENmish5 c.mpshock0#i.race_dummy i.race_dummy
//eststo en_race_gw: reg ENmish5 c.mpshock_pos#i.race_dummy i.race_dummy

esttab using "$directory_build/Tables/labor_by_race.tex", replace label r2 se title("Instantaneous IRFs across races for labor market flows and earnings") star(* 0.10 ** 0.05 *** 0.01)

restore

preserve 
collapse mpshock mpshock_pos mpshock_neg mp_bs mpshock_bs_pos mpshock_bs_neg rearn rearn_dlog earnweek EU* EN* UE* NE* [aw=wtfinl], by(sex date)

gen mpshock0 = mpshock
gen mpshock_bs0 = mp_bs
replace mpshock_pos = 0 if mpshock0 >=.
replace mpshock_neg = 0 if mpshock0 >=.
replace mpshock0 = 0 if mpshock0 >=.
replace mpshock_bs_pos = 0 if mpshock_bs0 >=.
replace mpshock_bs_neg = 0 if mpshock_bs0 >=.
replace mpshock_bs0 = 0 if mpshock_bs0 >=.

eststo clear
********************* LP GW EN sex *********************
eststo en_sex_gw: reg ENmish5 c.mpshock0#i.sex i.sex
//eststo en_sex_gw: reg ENmish5 c.mpshock_pos#i.sex i.sex

esttab using "$directory_build/Tables/labor_by_sex.tex", replace label r2 se title("Instantaneous IRFs across sex for labor market flows and earnings") star(* 0.10 ** 0.05 *** 0.01)

restore

// 2. Second collapse by date, age and earnings above or below the mean
// Quintiles of earnings
cumul rearn, gen(rearn_qtl)

gen rearn_median = floor(rearn_qtl *2)+1
replace rearn_median = 2 if rearn_median == 3
gen rearn_median_mis4 = rearn_median if mish==4
by cpsidp: egen id_rearn_median = max(rearn_median_mis4 )


drop if id_rearn_median>=.

label define rearn_median_lbl 1 "Below mean" 2 "Above mean"
label values id_rearn_median rearn_median_lbl

preserve

collapse mpshock mpshock_pos mpshock_neg mp_bs mpshock_bs_pos mpshock_bs_neg rearn rearn_dlog earnweek EU* EN* UE* NE* [aw=wtfinl], by(ages_dummy id_rearn_median date)

gen mpshock0 = mpshock
gen mpshock_bs0 = mp_bs
replace mpshock_pos = 0 if mpshock0 >=.
replace mpshock_neg = 0 if mpshock0 >=.
replace mpshock0 = 0 if mpshock0 >=.
replace mpshock_bs_pos = 0 if mpshock_bs0 >=.
replace mpshock_bs_neg = 0 if mpshock_bs0 >=.
replace mpshock_bs0 = 0 if mpshock_bs0 >=.

eststo clear
********************* LP GW EN age interacted symmetric *********************
eststo en_age_gw: reg ENmish5 c.mpshock0#i.ages_dummy#i.id_rearn_median i.ages_dummy##i.id_rearn_median
//eststo en_age_gw: reg ENmish5 c.mpshock_pos#i.ages_dummy#i.id_rearn_median i.ages_dummy##i.id_rearn_median


esttab using "$directory_build/Tables/labor_by_age_earnings.tex", replace label r2 se title("Instantaneous IRFs across age groups and earnings deciles for labor market flows and earnings") star(* 0.10 ** 0.05 *** 0.01)
//esttab using "$directory_build/Tables/labor_by_age_earnings_contractionary.tex", replace label r2 se title("Instantaneous IRFs across age groups and earnings deciles for labor market flows and earnings") star(* 0.10 ** 0.05 *** 0.01)

restore



preserve

collapse mpshock mpshock_pos mpshock_neg mp_bs mpshock_bs_pos mpshock_bs_neg rearn rearn_dlog earnweek EU* EN* UE* NE* [aw=wtfinl], by(ages_dummy id_rearn_median date)

gen mpshock0 = mpshock
gen mpshock_bs0 = mp_bs
replace mpshock_pos = 0 if mpshock0 >=.
replace mpshock_neg = 0 if mpshock0 >=.
replace mpshock0 = 0 if mpshock0 >=.
replace mpshock_bs_pos = 0 if mpshock_bs0 >=.
replace mpshock_bs_neg = 0 if mpshock_bs0 >=.
replace mpshock_bs0 = 0 if mpshock_bs0 >=.

eststo clear
********************* LP GW EN age interacted contractionary *********************
//eststo en_age_gw: reg ENmish5 c.mpshock0#i.ages_dummy#i.id_rearn_median i.ages_dummy##i.id_rearn_median
eststo en_age_gw: reg ENmish5 c.mpshock_pos#i.ages_dummy#i.id_rearn_median i.ages_dummy##i.id_rearn_median


//esttab using "$directory_build/Tables/labor_by_age_earnings.tex", replace label r2 se title("Instantaneous IRFs across age groups and earnings deciles for labor market flows and earnings") star(* 0.10 ** 0.05 *** 0.01)
esttab using "$directory_build/Tables/labor_by_age_earnings_contractionary.tex", replace label r2 se title("Instantaneous IRFs across age groups and earnings deciles for labor market flows and earnings") star(* 0.10 ** 0.05 *** 0.01)

restore


preserve

collapse mpshock mpshock_pos mpshock_neg mp_bs mpshock_bs_pos mpshock_bs_neg rearn rearn_dlog earnweek EU* EN* UE* NE* [aw=wtfinl], by(race_dummy id_rearn_median date)

gen mpshock0 = mpshock
gen mpshock_bs0 = mp_bs
replace mpshock_pos = 0 if mpshock0 >=.
replace mpshock_neg = 0 if mpshock0 >=.
replace mpshock0 = 0 if mpshock0 >=.
replace mpshock_bs_pos = 0 if mpshock_bs0 >=.
replace mpshock_bs_neg = 0 if mpshock_bs0 >=.
replace mpshock_bs0 = 0 if mpshock_bs0 >=.

eststo clear
********************* LP GW EN race interacted symmetric *********************
eststo en_race_gw: reg ENmish5 c.mpshock0#i.race_dummy#i.id_rearn_median i.race_dummy##i.id_rearn_median
//eststo en_race_gw: reg ENmish5 c.mpshock_pos#i.race_dummy#i.id_rearn_median i.race_dummy##i.id_rearn_median

esttab using "$directory_build/Tables/labor_by_race_earnings.tex", replace label r2 se title("Instantaneous IRFs across races and earnings deciles for labor market flows and earnings")  star(* 0.10 ** 0.05 *** 0.01)


restore


preserve

collapse mpshock mpshock_pos mpshock_neg mp_bs mpshock_bs_pos mpshock_bs_neg rearn rearn_dlog earnweek EU* EN* UE* NE* [aw=wtfinl], by(race_dummy id_rearn_median date)

gen mpshock0 = mpshock
gen mpshock_bs0 = mp_bs
replace mpshock_pos = 0 if mpshock0 >=.
replace mpshock_neg = 0 if mpshock0 >=.
replace mpshock0 = 0 if mpshock0 >=.
replace mpshock_bs_pos = 0 if mpshock_bs0 >=.
replace mpshock_bs_neg = 0 if mpshock_bs0 >=.
replace mpshock_bs0 = 0 if mpshock_bs0 >=.

eststo clear
********************* LP GW EN race interacted contractionary *********************
//eststo en_race_gw: reg ENmish5 c.mpshock0#i.race_dummy#i.id_rearn_median i.race_dummy##i.id_rearn_median
eststo en_race_gw: reg ENmish5 c.mpshock_pos#i.race_dummy#i.id_rearn_median i.race_dummy##i.id_rearn_median

esttab using "$directory_build/Tables/labor_by_race_earnings_contractionary.tex", replace label r2 se title("Instantaneous IRFs across races and earnings deciles for labor market flows and earnings")  star(* 0.10 ** 0.05 *** 0.01)


restore



preserve

collapse mpshock mpshock_pos mpshock_neg mp_bs mpshock_bs_pos mpshock_bs_neg rearn rearn_dlog earnweek EU* EN* UE* NE* [aw=wtfinl], by(sex id_rearn_median date)

gen mpshock0 = mpshock
gen mpshock_bs0 = mp_bs
replace mpshock_pos = 0 if mpshock0 >=.
replace mpshock_neg = 0 if mpshock0 >=.
replace mpshock0 = 0 if mpshock0 >=.
replace mpshock_bs_pos = 0 if mpshock_bs0 >=.
replace mpshock_bs_neg = 0 if mpshock_bs0 >=.
replace mpshock_bs0 = 0 if mpshock_bs0 >=.

eststo clear
********************* LP GW EN sex interacted symmetric *********************
eststo en_sex_gw: reg ENmish5 c.mpshock0#i.sex#i.id_rearn_median i.sex##i.id_rearn_median
//eststo en_sex_gw: reg ENmish5 c.mpshock_pos#i.sex#i.id_rearn_median i.sex##i.id_rearn_median

esttab using "$directory_build/Tables/labor_by_sex_earnings.tex", replace label r2 se title("Instantaneous IRFs across sex and earnings deciles for labor market flows and earnings") star(* 0.10 ** 0.05 *** 0.01)

restore


preserve

collapse mpshock mpshock_pos mpshock_neg mp_bs mpshock_bs_pos mpshock_bs_neg rearn rearn_dlog earnweek EU* EN* UE* NE* [aw=wtfinl], by(sex id_rearn_median date)

gen mpshock0 = mpshock
gen mpshock_bs0 = mp_bs
replace mpshock_pos = 0 if mpshock0 >=.
replace mpshock_neg = 0 if mpshock0 >=.
replace mpshock0 = 0 if mpshock0 >=.
replace mpshock_bs_pos = 0 if mpshock_bs0 >=.
replace mpshock_bs_neg = 0 if mpshock_bs0 >=.
replace mpshock_bs0 = 0 if mpshock_bs0 >=.

eststo clear
********************* LP GW EN sex interacted contractionary *********************
//eststo en_sex_gw: reg ENmish5 c.mpshock0#i.sex#i.id_rearn_median i.sex##i.id_rearn_median
eststo en_sex_gw: reg ENmish5 c.mpshock_pos#i.sex#i.id_rearn_median i.sex##i.id_rearn_median

esttab using "$directory_build/Tables/labor_by_sex_earnings_contractionary.tex", replace label r2 se title("Instantaneous IRFs across sex and earnings deciles for labor market flows and earnings") star(* 0.10 ** 0.05 *** 0.01)

restore