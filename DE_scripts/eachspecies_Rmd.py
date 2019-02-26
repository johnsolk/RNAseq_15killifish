import os
import os.path


def make_header(species):
	header='''
---
title: "RNAseq, DE analysis for {} killifish osmotic challenge"
author: "Lisa K. Johnson"
date: '`r Sys.Date()`'
output:
  html_document:
    code_folding: hide
    collapsed: no
    df_print: paged
    number_sections: yes
    theme: cerulean
    toc: yes
    toc_depth: 5
    toc_float: yes
---
'''.format(species)
	return header

def load_packages():
	packages="""
```{{r LoadPackages, results='hide', include=FALSE}}
packages<-function(x){{
  x<-as.character(match.call()[[2]])
  if (!require(x,character.only=TRUE)){{
    install.packages(pkgs=x,repos="http://cran.r-project.org")
    require(x,character.only=TRUE)
  }}
}}
bioconductors <- function(x){{
    x<- as.character(match.call()[[2]])
    if (!require(x, character.only = TRUE)){{
      source("https://bioconductor.org/biocLite.R")
      biocLite(pkgs=x)
      require(x, character.only = TRUE)
    }}
}}
packages("RColorBrewer")
packages("pheatmap")
packages("vsn")
packages(pheatmap)
packages(cowplot)
# for DESeq
packages(lattice)
packages(RColorBrewer)
packages(dplyr)
packages(tidyr)
packages(gplots)
packages(ggplot2)
bioconductors(DESeq2)
bioconductors(tximport)
bioconductors(biomaRt)
```
""".format()
	return packages

def get_files():
	files="""
```{{r load custom scripts and data, results='hide', include=FALSE}}
if(!file.exists('plotPCAWithSampleNames.R')){{
  download.file('https://gist.githubusercontent.com/ljcohen/d6cf3367efae60d7fa1ea383fd7a1296/raw/f11030ced8c7953be6fada0325b92c20d369e0a7/plotPCAWithSampleNames.R', 'plotPCAWithSampleNames.R')
	}}
source('plotPCAWithSampleNames.R')
if(!file.exists('overLapper_original.R')){{
  download.file("https://gist.githubusercontent.com/ljcohen/b7e5fa93b8b77c33d26e4c44cadb5bb7/raw/3a2f84be2e937ef721cafaf308ff6456168f30d9/overLapper_original.R",'overLapper_original.R')
	}}
source('overLapper_original.R')
# This is just the counts with Experimental Design Info in the last 5 rows
if(!file.exists('../../Ensembl_species_counts_designfactors.csv')){{
  download.file("https://osf.io/7vp38/download",'../../Ensembl_species_counts_designfactors.csv')
	}}
counts_design <- read.csv("../../Ensembl_species_counts_designfactors.csv",stringsAsFactors = FALSE)
```
""".format()
	return files

def design(species):
	design_info='''
```{{r format counts and ExpDesign, include=FALSE, results='hide'}}
design <- counts_design[counts_design$Ensembl == 'Empty',]
#design$type <- c("species","native_salinity","clade","group","condition")
drops <- c("X","Ensembl",
           "F_zebrinus_BW_1.quant","F_zebrinus_BW_2.quant",
           "F_zebrinus_FW_1.quant","F_zebrinus_FW_2.quant",
           "F_notti_FW_1.quant","F_notti_FW_2.quant")
counts<-counts_design[!counts_design$Ensembl == 'Empty',]
rownames(counts)<-counts$Ensembl
design <- design[ , !(names(design) %in% drops)]
counts <- counts[ , !(names(counts) %in% drops)]
design <- design[ , startsWith(names(design),"{}")]
counts <- counts[ , startsWith(names(counts),"{}")]
dim(design)
dim(counts)
# design cateogories (full)
species<-as.character(unlist(design[1,]))
nativephysiology<-as.character(unlist(design[2,]))
clade<-as.character(unlist(design[3,]))
condition<-as.character(unlist(design[5,]))
cols<-colnames(counts)
ExpDesign <- data.frame(row.names=cols,
                        condition=condition)
ExpDesign
```
'''.format(species,species)
	return design_info


def PCA():
	PCA_plot='''
# PCA

The dimensions of the counts table are listed below. Row=genes, Columns=samples
```{{r PCA of counts,}}
# normal full counts
x <- data.matrix(counts)
dim(x)
x <- x+1
log_x<-log(x)
names<-colnames(log_x)
pca = prcomp(t(log_x))
#summary(pca)
fac = factor(condition)
colours = function(vec){{
  cols=rainbow(length(unique(vec)))
  return(cols[as.numeric(as.factor(vec))])}}
mar.default <- c(5,4,4,2) + 0.1
par(mar = mar.default + c(0, 4, 0, 0)) 
plot(pca$x[,1:2], 
     col=colours(clade), 
     pch = c(16, 2, 9)[as.numeric(as.factor(condition))],
     cex=2,
     xlab="PC1",
     ylab="PC2",
     cex.lab=2,
     cex.axis = 2)
legend(140,100,legend=c("0.2_ppt","15_ppt","transfer"),col=rainbow(length(unique(condition))),cex=0.75, pch=19)
```
'''.format()
	return PCA_plot

def filtering_counts(n_samples,expn):
	filtered_counts="""
# Filtering counts

The following shows the dimensions of the dataframe when we filter out genes with low counts.

{} samples must have a count of at least {}:

```{{r filtering5,}}
filter <- rownames(counts[rowSums(counts >= {}) >= {},])
filtered_counts <- counts[filter,]
dim(filtered_counts)
```
""".format(n_samples,expn,n_samples,expn)
	return filtered_counts

def run_DESeq():
	DESeq_string="""
```{{r run DESeq, }}
all(rownames(ExpDesign) == colnames(counts))
counts_round<- round(data.matrix(counts),digits=0)
dds <- DESeqDataSetFromMatrix(countData = counts_round,colData = ExpDesign,design = ~condition)
dds<-DESeq(dds)
matrix(resultsNames(dds))
plotDispEsts(dds)
resultsNames(dds)
vsd <- vst(dds, blind=FALSE)
meanSdPlot(assay(vsd))
plotDispEsts(dds)
plotPCA(vsd, intgroup=c("condition"))
plotPCAWithSampleNames(vsd,intgroup=c("condition"))
```
""".format()
	return DESeq_string

def make_Rmd(outfile,species):
	header=make_header(species)
	packages=load_packages()
	files=get_files()
	design_info=design(species)
	#PCA_plot=PCA()
	n_samples="9"
	expn="0.1"
	filtered_counts=filtering_counts(n_samples,expn)
	DESeq_string=run_DESeq()
	chunks=[header,packages,files,design_info,filtered_counts,DESeq_string]
	with open(outfile,"w") as Rmd:
		for i in chunks:
			print(i)
			Rmd.write(i + "\n")
	print("File written:",outfile)
	return

species_list=["A_xenica","F_catanatus","F_chrysotus","F_diaphanus","F_grandis",
"F_heteroclitusMDPL","F_heteroclitusMDPP","F_notatus","F_olivaceous",
"F_parvapinis","F_rathbuni","F_sciadicus","F_similis","L_goodei","L_parva"]

outdir="../DE_scripts/by_species/"

for species in species_list:
	outfile=outdir+species+"_DE.Rmd"
	make_Rmd(outfile,species)




