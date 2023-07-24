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
list_of_packages=c("dplyr","readxl","readr","stringi","janitor","openxlsx","optparse","tools")

#Based on the packages that are present, install ones that are required.
new.packages <- list_of_packages[!(list_of_packages %in% installed.packages()[,"Package"])]
suppressMessages(if(length(new.packages)) install.packages(new.packages, repos = "http://cran.us.r-project.org"))

#Load libraries.
suppressMessages(library(dplyr,verbose = F))
suppressMessages(library(readxl,verbose = F))
suppressMessages(library(readr,verbose = F))
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
opt_parser = OptionParser(option_list=option_list, description = "\nCCDI-Submission_CruncheR v2.0.0")
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
cat("\nThe data files are being concatenated at this time.\n")


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

cat("\nReading in the Metadata template workbook.\n")

file_count=0

pb=txtProgressBar(min=0,max=length(file_list)*length(dict_nodes),style = 3)

#make working directory for temporary file node deposition

folder_dir=paste(dirname(directory_path),"/Cruncher_Temp",sep = "")

dir.create(folder_dir,showWarnings = FALSE)

#for each node
for (node in dict_nodes){
  #initiate a data frame
  df_all=data.frame()
  
  #for each file
  for (file in file_list){
    file_count=file_count+1
    setTxtProgressBar(pb,file_count)
    #create a file path
    file_path=paste(directory_path,file,sep = "")
    tryCatch({
      #read in the file
      df=read_excel(path = file_path, sheet = node, guess_max = 10000)
      #combine the data frames and obtain the unique output
      df_all= rbind(df_all, df)
      df_all= unique(df_all)
      #remove any empty rows, which is obtained via removing the type column, removing empty rows and then adding back the type column.
      df_all=df_all%>%
        select(-type)%>%
        remove_empty(which = "rows")%>%
        mutate(type=node)%>%
        select(type, everything())
    },error = function(e) {
      # Catch the error if the tab doesn't exist
      cat("Error:", e$message, "\n")
      cat("Skipping for", file,":", node, "\n")
    })
  }
  #write the node file out
  write_tsv(file=paste(folder_dir,"/",node,".tsv",sep = ""),x = df_all, na="")
}

cat("\nThe workbook is being formed.\n")


wb=openxlsx::loadWorkbook(file = template_path)

#for each node
for (node in dict_nodes){
  file_path=paste(folder_dir,"/",node,".tsv",sep = "")
  #read the sheet corresponding node file
  df=read_tsv(file = file_path, col_types = "c")
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
      #write the node out.
      openxlsx::deleteData(wb, sheet = node,rows = 1:(dim(df)[1]+1),cols=1:(dim(df)[2]+1),gridExpand = TRUE)
      openxlsx::writeData(wb=wb, sheet=node, df)
      openxlsx::saveWorkbook(wb = wb,file = paste(path,output_file,".xlsx",sep = ""), overwrite = T)
    }
  }
}

#delete the temp folder and contents.
unlink(x = folder_dir, recursive = TRUE)


cat(paste("\n\nProcess Complete.\n\nThe output file can be found here: ",path,"\n\n",sep = "")) 
