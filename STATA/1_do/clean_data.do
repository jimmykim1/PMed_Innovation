global home "D:\Users\jimmykim871\Documents\PMed_Innovation"
global raw "$home\STATA\0_raw"
global data "${home}\STATA\2_data"


/**********************************************/
/* Clean companion diagnostic-drug pairs data */
/**********************************************/

import excel "$raw\List of Cleared or Approved Companion Diagnostic Devices (In Vitro and Imaging Tools)  FDA.xlsx", clear
drop in 1/2

split A, p("(")
// One diagnostic listed as owned by Ventana *and* Roche (Ventana's owner)
drop A4
// 28 diagnostics (including one above) have parenthetical in test name
replace A1 = A1 + "(" + A2 if ~missing(A3)
replace A2 = A3 if ~missing(A3)
drop A3
replace A1 = ustrtrim(A1)
replace A2 = ustrtrim(A2)
replace A2 = substr(A2,1,strlen(A2)-1) if substr(A2,strlen(A2),1) == ")"

// Collapse company names to first word
replace A2 = strupper(A2)
rename A2 owner
split owner, p(" ")
replace owner = owner1
drop owner1 owner2 owner3 owner4 owner5 owner6
replace owner = substr(owner,1,strlen(owner)-1) if substr(owner,strlen(owner),1) == ","
rename owner test_owner

rename A1 test_name
drop A

save "${data}\companion_pairs", replace

// Parse indication and test type
use "${data}\companion_pairs", clear
split B, p("-")
gen test_type = B4 if ~missing(B4)
gen indication = B1 + "-" + B2 + "-" + B3 if ~missing(B4)
replace indication = B1 + "-" + B2 if ~missing(B3) & missing(B4)
replace test_type = B3 if ~missing(B3) & missing(B4)
replace indication = B1 if ~missing(B2) & missing(B3) & missing(B4)
replace test_type = B2 if ~missing(B2) & missing(B3) & missing(B4)
// Nine entries have a long dash which encodes weird in ASCII
replace test_type = "Tissue" if substr(B2,34,1) == char(147)
replace indication = "Non-Small Cell Lung Cancer (NSCLC)" if substr(B2,34,1) == char(147)
gen long_dash = .
forvalues i = 1/200 {
	if strlen(B) > `i' {
		replace long_dash = 1 if substr(B,`i',1) == char(147)
	}
}
replace test_type = strupper(test_type)
replace indication = strupper(indication)
replace B = strupper(B)
replace B = ustrtrim(B)
replace test_type = "TISSUE" if long_dash == 1 & substr(B,strlen(B)-5,6) == "TISSUE"
replace indication = substr(B,1,strlen(B)-10) if long_dash == 1 & substr(B,strlen(B)-5,6) == "TISSUE"
replace test_type = "SERUM" if long_dash == 1 & substr(B,strlen(B)-4,5) == "SERUM"
replace indication = substr(B,1,strlen(B)-11) if long_dash == 1 & substr(B,strlen(B)-4,5) == "SERUM"
replace test_type = "WHOLE BLOOD" if long_dash == 1 & substr(B,strlen(B)-10,11) == "WHOLE BLOOD"
replace indication = substr(B,1,strlen(B)-15) if long_dash == 1 & substr(B,strlen(B)-10,11) == "WHOLE BLOOD"
replace indication = "SOLID TUMORS" if B == "SOLID TUMORS"
replace test_type = "SOLID TUMORS" if B == "SOLID TUMORS"
replace test_type = ustrtrim(test_type)
replace indication = ustrtrim(indication)
// Can't figure this one out
replace test_type = "SERUM" if missing(indication)
replace indication = "DUCHENNE MUSCULAR DYSTROPHY" if missing(indication)
drop B* long_dash
save "${data}\companion_pairs", replace


// NOTE: primary double NDA or BLA refers to one drug with two NDAs or two BLAs
// Secondary double NDA or BLA refers to two drugs, one NDA and BLA each
// Parse drug names and NDA/BLA and application #
use "${data}\companion_pairs", clear
// First, treat double treatments as separate
split C, p(" or ")
rename C drug_name
reshape long C, i(drug_name D E F test_name test_owner test_type indication) j(ix)
drop drug_name
drop if missing(C)
// Next, list combination treatments as constituent drugs
replace C = strupper(C)
split C, p("IN COMBINATION WITH")
rename C1 primary
// Get NDA and BLA #'s
gen primary_nda = strpos(primary, "NDA") != 0
gen primary_bla = strpos(primary, "BLA") != 0
// One entry with double NDA
split primary, p("NDA")
rename primary3 primary_nda2
replace primary2 = substr(primary2,1,strpos(primary2,"AND")-1) if strpos(primary2,"AND") != 0
rename primary2 primary_nda1
rename primary1 primary_drug
split primary_drug, p("BLA")
rename primary_drug3 primary_bla2
replace primary_drug2 = substr(primary_drug2,1,strpos(primary_drug2,"AND")-1) if strpos(primary_drug2,"AND") != 0
rename primary_drug2 primary_bla1
drop primary_drug
rename primary_drug1 primary_drug
// Get drug names: brand and generic
split primary_drug, p("(")
rename primary_drug1 primary_brand
rename primary_drug2 extension
split extension, p(")")
rename extension1 primary_generic
drop primary_drug primary extension extension2 C ix
foreach v of varlist primary_nda1 primary_nda2 primary_brand primary_generic {
	replace `v' = ustrtrim(`v')
}


rename C2 secondary
split secondary, p("AND")
rename secondary1 secondary_drug
gen secondary_nda = strpos(secondary, "NDA") != 0
gen secondary_bla = strpos(secondary, "BLA") != 0
split secondary_drug, p("NDA")
rename secondary_drug2 secondary_nda1
rename secondary_drug1 drug
split drug, p("BLA")
rename drug2 secondary_bla1
drop drug
rename drug1 drug
split drug, p("(")
rename drug1 secondary_brand1
rename drug2 extension
split extension, p(")")
drop extension2
rename extension1 secondary_generic1
drop drug secondary_drug extension

rename secondary2 secondary_drug
split secondary_drug, p("NDA")
rename secondary_drug2 secondary_nda2
rename secondary_drug1 drug
split drug, p("BLA")
// rename drug2 secondary_bla2
drop drug
rename drug1 drug
split drug, p("(")
rename drug1 secondary_brand2
rename drug2 extension
split extension, p(")")
rename extension1 secondary_generic2
drop drug secondary_drug extension
save "${data}\companion_pairs", replace


// Won't touch biomarker name or details
use "${data}\companion_pairs", clear
rename D biomarkers
rename E details

// Parse approval dates
split F, p(")")
rename F2 secondary_approval
split secondary_approval, p("(")
rename secondary_approval2 secondary_date
rename secondary_approval1 secondary_form
replace secondary_form = "" if missing(secondary_date)
drop secondary_approval
rename F1 primary_approval
split primary_approval, p("(")
rename primary_approval1 primary_form
rename primary_approval2 primary_date
replace secondary_form = subinstr(secondary_form,"updated","",.)
replace secondary_form = subinstr(secondary_form,";","",.)
drop F* primary_approval
foreach v of varlist *_form *_date {
	replace `v' = ustrtrim(`v')
}
save "${data}\companion_pairs", replace
export delimited "${data}\companion_pairs.csv", replace
