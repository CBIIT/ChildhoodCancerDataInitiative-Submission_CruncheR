# ChildhoodCancerDataInitiative-Submission_CruncheR
This takes a directory of CCDI Metadata template files as input and creates a single CCDI output file.

To run the script, run the following command in a terminal where R is installed for help.

```
Rscript --vanilla CCDI-Submission_CruncheR.R -h
```

```
Usage: CCDI-Submission_CruncheR.R [options]

CCDI-Submission_CruncheR v1.0.0

Options:
	-d CHARACTER, --directory=CHARACTER
		A directory that contains only the submission files that are to be concatenated into one file.

	-t CHARACTER, --template=CHARACTER
		dataset template file, CCDI_Submission_Template.xlsx

	-h, --help
		Show this help message and exit
```

There is an example data set, which can be used with the following line:

```
Rscript --vanilla CCDI-Submission_CruncheR.R -t example_files/CCDI_Submission_Template_v1.1.4.xlsx -d example_files/concatenate_files/
```

This will output a single file that has all values from all rows on each tab.
