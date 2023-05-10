#!/usr/bin/env Rscript

#Childhood Cancer Data Initiative - Submission CruncheR


##################
#
# USAGE
#
##################

#This takes a directory of CCDI Metadata template files as input and creates a single CCDI output file.

#Run the following command in a terminal where R is installed for help.

#Rscript --vanilla CCDI-Submission_CruncheR.R --help

##################
#
# Env. Setup
#
##################

#List of needed packages
list_of_packages=c("dplyr","tidyr","readr","stringi","janitor","readxl","openxlsx","optparse","tools")

#Based on the packages that are present, install ones that are required.
new.packages <- list_of_packages[!(list_of_packages %in% installed.packages()[,"Package"])]
suppressMessages(if(length(new.packages)) install.packages(new.packages, repos = "http://cran.us.r-project.org"))

#Load libraries.
suppressMessages(library(dplyr,verbose = F))
suppressMessages(library(stringi,verbose = F))
suppressMessages(library(janitor,verbose = F))
suppressMessages(library(openxlsx,verbose = F))
suppressMessages(library(optparse,verbose = F))
suppressMessages(library(tools,verbose = F))

#remove objects that are no longer used.
rm(list_of_packages)
rm(new.packages)


##################
#
# Arg parse
#
##################

#Option list for arg parse
option_list = list(
  make_option(c("-d", "--directory"), type="character", default=NULL, 
              help="A directory that contains only the submission files that are to be concatenated into one file.", metavar="character"),
  make_option(c("-t", "--template"), type="character", default=NULL, 
              help="dataset template file, CCDI_Submission_Template.xlsx", metavar="character")
)
#create list of options and values for file input
opt_parser = OptionParser(option_list=option_list, description = "\nCCDI-Submission_CruncheR v1.0.0")
opt = parse_args(opt_parser)

#If no options are presented, return --help, stop and print the following message.
if (is.null(opt$directory)&is.null(opt$template)){
  print_help(opt_parser)
  cat("Please supply both the input file directory (-d) and template file (-t), CCDI_submission_metadata_template.xlsx.\n\n")
  suppressMessages(stop(call.=FALSE))
}


#Data file pathway
directory_path=file_path_as_absolute(opt$directory)

#Ensure that the directory ends with a '/'
if (substring(directory_path,nchar(directory_path),nchar(directory_path))!="/"){
  directory_path=paste(directory_path,"/",sep = "")
}

#Template file pathway
template_path=file_path_as_absolute(opt$template)


#A start message for the user that the validation is underway.
cat("The data files are being concatenated at this time.\n")


###############
#
# Start write out
#
###############

#Output file name based on input file name and date/time stamped.
output_file=paste("CCDI_MetaMerge",
                  stri_replace_all_fixed(
                    str = Sys.Date(),
                    pattern = "-",
                    replacement = ""),
                  sep="")  

#List files in file path
file_list=list.files(path = directory_path)
path=paste(dirname(directory_path),"/",sep="")

#use the template to determine the nodes that might be present
#Read in Dictionary page to obtain the required properties.
df_dict=suppressMessages(openxlsx::read.xlsx(xlsxFile = template_path,sheet = "Dictionary"))
df_dict=remove_empty(df_dict,c('rows','cols'))

#Pull out nodes to read in respective tabs
dict_nodes=unique(df_dict$Node)

#Establish the list
workbook_list=list()

cat("\n\nReading in the Metadata template workbook.\n")

for (file in file_list){
  file_path=paste(directory_path,file,sep = "")
  
  
  ##############
  #
  # Read in each tab and apply to a data frame list
  #
  ##############
  
  # A bank of NA terms to make sure NAs are brought in correctly
  NA_bank=c("NA","na","N/A","n/a")
  
  #Establish a blank add list
  workbook_add=list()
  
  #create a list of all node pages with data
  for (node in dict_nodes){
    #read the sheet
    df=readWorkbook(xlsxFile = file_path,sheet = node, na.strings = NA_bank)
    #create an emptier version that removes the type and makes everything a character
    df_empty_test=df%>%
      select(-type)%>%
      mutate(across(everything(), as.character))
    #remove empty rows and columns
    df_empty_test=remove_empty(df_empty_test,c("rows","cols"))
    
    #if there are at least one row in the resulting data frame, add it
    if (dim(df_empty_test)[1]>0){
      #if the only columns in the resulting data frame are only linking properties (node.node_id), do not add it.
      if (any(!grepl(pattern = "\\.",x = colnames(df_empty_test)))){
        #add the data frame to the workbook
        workbook_add=append(x = workbook_add,values = list(df))
        names(workbook_add)[length(workbook_add)]<-node
      }else{
        cat("\n\tWARNING: The following node, ", node,", did not contain any data except a linking value and type.\n" ,sep = "")
      }
    }
  }
  
  #add the workbook_add into the workbook_list
  for (node in names(workbook_add)){
    workbook_list[node][[1]]=rbind(workbook_list[node][[1]],workbook_add[node][[1]])
    workbook_list[node][[1]]=unique(workbook_list[node][[1]])
  }
  
}


nodes_present=names(workbook_list)

###############
#
# Write out
#
###############

#Write out file

wb=openxlsx::loadWorkbook(file = template_path)

cat("\n\nWriting out the CatchERR file.\n")

#progress bar
pb=txtProgressBar(min=0,max=length(nodes_present),style = 3)
x=0

#write out each tab in the workbook
for (node in nodes_present){
  x=x+1
  setTxtProgressBar(pb,x)
  df=workbook_list[node][[1]]
  openxlsx::deleteData(wb, sheet = node,rows = 1:(dim(df)[1]+1),cols=1:(dim(df)[2]+1),gridExpand = TRUE)
  openxlsx::writeData(wb=wb, sheet=node, df)
  openxlsx::saveWorkbook(wb = wb,file = paste(path,output_file,".xlsx",sep = ""), overwrite = T)
}



cat(paste("\n\nProcess Complete.\n\nThe output file can be found here: ",path,"\n\n",sep = "")) 
