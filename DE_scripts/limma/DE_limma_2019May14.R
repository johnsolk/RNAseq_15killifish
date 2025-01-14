library(limma)
library(ggplot2)
library('edgeR')
library("RColorBrewer")
library(gplots)
library(biomaRt)
library(lattice)
library("vsn")
library(dplyr)
library(knitr)
library(kableExtra)
library(pheatmap)
library("SummarizedExperiment")
library("emmeans")
setwd("~/Documents/UCDavis/Whitehead/RNAseq_15killifish/DE_scripts/limma")
dir<-("~/Documents/UCDavis/Whitehead/")
# This file contains filtered counts with Experimental Design Info in the last 5 rows
if(!file.exists('../../../../Ensembl_species_counts_designfactors.csv')){
  download.file("https://osf.io/7vp38/download",'Ensembl_species_counts_designfactors.csv')
}

counts_design <- read.csv("../../../Ensembl_species_counts_designfactors.csv",stringsAsFactors = FALSE)

dim(counts_design)
#[1] 30471   130

# -----------------------
# Format design and counts matrix
# Drop columns with no data
# -----------------------

design <- counts_design[counts_design$Ensembl == 'Empty',]
#design$type <- c("species","native_salinity","clade","group","condition")
drops <- c("X","Ensembl",
           "F_zebrinus_BW_1.quant","F_zebrinus_BW_2.quant",
           "F_zebrinus_FW_1.quant","F_zebrinus_FW_2.quant",
           "F_notti_FW_1.quant","F_notti_FW_2.quant",
           "F_sciadicus_BW_1.quant","F_sciadicus_FW_1.quant","F_sciadicus_FW_2.quant")
transfer_drops <- c("F_sciadicus_transfer_1.quant","F_rathbuni_transfer_1.quant","F_rathbuni_transfer_2.quant","F_rathbuni_transfer_3.quant",
                    "F_grandis_transfer_1.quant","F_grandis_transfer_2.quant","F_grandis_transfer_3.quant",
                    "F_notatus_transfer_1.quant","F_notatus_transfer_2.quant","F_notatus_transfer_3.quant",
                    "F_parvapinis_transfer_1.quant","F_parvapinis_transfer_2.quant",
                    "L_goodei_transfer_1.quant","L_goodei_transfer_2.quant","L_goodei_transfer_3.quant",
                    "F_olivaceous_transfer_1.quant","F_olivaceous_transfer_2.quant",
                    "L_parva_transfer_1.quant","L_parva_transfer_2.quant","L_parva_transfer_3.quant",
                    "F_heteroclitusMDPP_transfer_1.quant","F_heteroclitusMDPP_transfer_2.quant","F_heteroclitusMDPP_transfer_3.quant",
                    "F_similis_transfer_1.quant","F_similis_transfer_2.quant","F_similis_transfer_3.quant",
                    "F_diaphanus_transfer_1.quant","F_diaphanus_transfer_2.quant",
                    "F_chrysotus_transfer_1.quant","F_chrysotus_transfer_2.quant",
                    "A_xenica_transfer_1.quant","A_xenica_transfer_2.quant","A_xenica_transfer_3.quant" ,
                    "F_catanatus_transfer_1.quant","F_catanatus_transfer_2.quant",
                    "F_heteroclitusMDPL_transfer_1.quant","F_heteroclitusMDPL_transfer_2.quant","F_heteroclitusMDPL_transfer_3.quant")
counts<-counts_design[!counts_design$Ensembl == 'Empty',]
rownames(counts)<-counts$Ensembl
design <- design[ , !(names(design) %in% drops)]
counts <- counts[ , !(names(counts) %in% drops)]
design <- design[ , !(names(design) %in% transfer_drops)]
counts <- counts[ , !(names(counts) %in% transfer_drops)]
dim(design)
#[1]  5 81
dim(counts)
gene.names<-rownames(counts)

dim(counts)
class(counts)
design[] <- lapply( design, factor)

# --------------------
# design cateogories
# --------------------

species<-as.character(unlist(design[1,]))
physiology<-as.character(unlist(design[2,]))
clade<-as.character(unlist(design[3,]))
condition<-as.character(unlist(design[5,]))
condition_physiology<-as.vector(paste(condition,physiology,sep="."))
condition_physiology_clade <- as.vector(paste(condition_physiology,clade,sep="."))
condition_physiology_clade <- as.vector(paste("group",condition_physiology_clade,sep=""))
cols<-colnames(counts)
ExpDesign <- data.frame(row.names=cols,
                        condition=condition,
                        physiology = physiology,
                        clade = clade,
                        species = species,
                        sample=cols)
ExpDesign
# used for pairwise contrasts
#form<-as.formula("~0 + physiology*condition*clade")
form<-as.formula("~physiology*condition*clade")
design = model.matrix(form, ExpDesign)
#group <- interaction(physiology, condition, clade)
#mm <- model.matrix(~0 + group)
colnames(design)
# check rank of matrix
Matrix::rankMatrix( design )
dim(design)

# ============================================
# biomart annotation
# https://uswest.ensembl.org/Fundulus_heteroclitus/Info/Index
# ============================================

ensembl=useMart("ENSEMBL_MART_ENSEMBL")
ensembl = useDataset("fheteroclitus_gene_ensembl",mart=ensembl)
ensembl_proteinID = rownames(counts)
length(ensembl_proteinID)
ann<-getBM(attributes=c('ensembl_peptide_id','ensembl_transcript_id','ensembl_gene_id','gene_biotype','external_gene_name','description','entrezgene'), filters = 'ensembl_peptide_id', values = ensembl_proteinID, mart=ensembl)
head(ann)
dim(ann)
length(unique(ann$ensembl_peptide_id))
ann <- ann[!duplicated(ann[,c(1)]),]
dim(ann)

# ---------------

# DE analysis

# ---------------

counts<-as.matrix(as.data.frame(sapply(counts, as.numeric)))
rownames(counts)<-gene.names
class(counts)
#test<-counts %>% drop_na()
#test<-as.matrix(test)
lcom_unfilt<-log2(counts+1)
plot(colSums(t(lcom_unfilt)))

keep<-filterByExpr(counts,design = design,group=condition_physiology,min.count = 10, min.total.count = 100)
counts.filt <- counts[keep,]
dim(counts.filt)
write.table(counts.filt,"~/Documents/UCDavis/Whitehead/exp.tsv",sep="\t",quote=FALSE)

# ============================================
#
# Genes of Interest
# This was very helpful:
# https://rpubs.com/turnersd/plot-deseq-results-multipage-pdf
# 
# ============================================

# ---------------------------
# Andrew Whitehead's genes of interest:
# ---------------------------

# zymogen granule membrane protein 16
# Funhe2EKm029929
countsfilt <- counts.filt
countsfilt$row <- rownames(countsfilt)
goi <- countsfilt$row[countsfilt$row == "ENSFHEP00000007220.1"]
goi
# zymogen granule membrane protein 16
# Funhe2EKm029931
goi <- countsfilt$row[countsfilt$row == "ENSFHEP00000025841"]
goi
# solute carrier family 12 member 3-like (removed) 
# Funhe2EKm006896
goi <- countsfilt$row[countsfilt$row == "ENSFHEP00000009214"]
goi
# chloride channel, voltage-sensitive 2 (clcn2), transcript variant X2 (removed)
# Funhe2EKm024148
goi <- countsfilt$row[countsfilt$row == "ENSFHEP00000019510"]
goi
# ATP-sensitive inward rectifier potassium channel 1 
# Funhe2EKm001965
goi <- countsfilt$row[countsfilt$row == "ENSFHEP00000015383"]
goi
# inward rectifier potassium channel 2
#Funhe2EKm023780
goi <- countsfilt$row[countsfilt$row == "ENSFHEP00000009753"]

# --------------------------------
# other salinity genes of interest
# --------------------------------

# ============================================
# aquaporin-3
goi <- countsfilt$row[countsfilt$row == "ENSFHEP00000006725"]
goi
# cftr
# Funhe2EKm024501
goi <- countsfilt$row[countsfilt$row == "ENSFHEP00000008393"]
goi
# polyamine-modulated factor 1-like
# Funhe2EKm031049
goi <- countsfilt$row[countsfilt$row == "ENSFHEP00000013324"]
goi
# sodium/potassium/calcium exchanger 2
# ENSFHEP00000034177
# Funhe2EKm025497
goi <- countsfilt$row[countsfilt$row == "ENSFHEP00000034177"]
goi
# septin-2B isoform X2
# ENSFHEP00000015765
goi <- countsfilt$row[countsfilt$row == "ENSFHEP00000015765"]
goi
# CLOCK-interacting pacemaker-like
# ENSFHEP00000017303
# Funhe2EKm026846
goi <- countsfilt$row[countsfilt$row == "ENSFHEP00000017303"]
goi
# vasopressin V2 receptor-like
# Funhe2EKm026721
goi <- countsfilt$row[countsfilt$row == "ENSFHEP00000000036"]
goi
# sodium/potassium-transporting ATPase subunit beta-1-interacting protein 1
# ENSFHEP00000031108
# Funhe2EKm001174
goi <- countsfilt$row[countsfilt$row == "ENSFHEP00000031108"]
goi
# ENSFHEP00000023396
# sodium/potassium ATPase alpha subunit isoform 2 
goi <- countsfilt$row[countsfilt$row == "ENSFHEP00000023396"]
goi
# septin-2
# Funhe2EKm012182
goi <- countsfilt$row[countsfilt$row == "ENSFHEP00000016853"]
goi
# otopetrin-2
# Funhe2EKm035427
goi <- countsfiltW$row[countsfilt$row == "ENSFHEP00000026411"]
goi
# claudin 8
# Funhe2EKm037718
goi <- countsfilt$row[countsfilt$row == "ENSFHEP00000006282"]
goi
# claudin 4
# ENSFHEP00000003908
# Funhe2EKm007149
goi <- countsfilt$row[countsfilt$row == "ENSFHEP00000003908"]
goi
all_goi<-c("ENSFHEP00000023396","ENSFHEP00000007220.1","ENSFHEP00000025841","ENSFHEP00000019510",
           "ENSFHEP00000015383","ENSFHEP00000009753","ENSFHEP00000006725","ENSFHEP00000008393",
           "ENSFHEP00000013324","ENSFHEP00000001609","ENSFHEP00000013324","ENSFHEP00000034177",
           "ENSFHEP00000015765","ENSFHEP00000017303","ENSFHEP00000000036","ENSFHEP00000031108",
           "ENSFHEP00000016853","ENSFHEP00000003908")

# -------------------
# proceed with DE
# -------------------
# log counts before DE
boxplot(log(counts.filt+1), las = 2, main = "")

write.table(counts.filt,"~/Documents/UCDavis/Whitehead/exp.tsv",sep = "\t", quote = F, row.names = F)

genes = DGEList(count = counts.filt, group = condition_physiology_clade)
genes = calcNormFactors( genes )

# write normalized counts
dir <- "~/Documents/UCDavis/Whitehead/"
tmp <- as.data.frame(cpm(genes))
tmp$Ensembl <- rownames(tmp)
tmp <- dplyr::select(tmp, Ensembl, everything())
write.csv(tmp, file = file.path(dir, "normalized_counts.csv"), quote = F, row.names = F)

vobj = voom( genes, design, plot=TRUE)
lcpm <- cpm(genes$counts, log = TRUE)
# log counts after DE

boxplot(lcpm, las = 2, main = "")
plot(colSums(t(lcpm)))

vwts <- voomWithQualityWeights(genes, design=design, normalization="quantile", plot=TRUE)
corfit <- duplicateCorrelation(vobj,mm,block=ExpDesign$species)
corfit$consensus
#[1] 0.7596421
fitRan <- lmFit(vobj,design,block=ExpDesign$species,correlation=corfit$consensus)
colnames(coef(fitRan))
dir <- "~/Documents/UCDavis/Whitehead/"

#> colnames(coef(fitRan))
#[1] "(Intercept)"                             "physiologyM"                            
#[3] "condition15_ppt"                         "cladeClade2"                            
#[5] "cladeClade3"                             "physiologyM:condition15_ppt"            
#[7] "physiologyM:cladeClade2"                 "physiologyM:cladeClade3"                
#[9] "condition15_ppt:cladeClade2"             "condition15_ppt:cladeClade3"            
#[11] "physiologyM:condition15_ppt:cladeClade2" "physiologyM:condition15_ppt:cladeClade3"

# -------------------------------
# main effects
# physiology: coef = 2
vfit <- contrasts.fit(fitRan, coef = 2)
efit<-eBayes(vfit)
classifyTestsF(efit)
summary(decideTests(efit))
main_phys<-topTableF(efit,n = Inf, sort.by = "F")
sig_main_phys <- main_phys[main_phys$adj.P.Val<0.05,]
dim(sig_main_phys)
dim(main_phys)
ann_phys <- merge(main_phys,ann,all=TRUE,by.x = "row.names", by.y  = "ensembl_peptide_id")
dim(ann_phys)
ann_phys <- ann_phys[order(ann_phys$adj.P.Val,decreasing = FALSE), ]
rownames(ann_phys) <- ann_phys$Row.names
ann_phys <- ann_phys[,-1]
write.csv(ann_phys, file = file.path(dir, "main_phys.csv"), quote = F, row.names = T)

# condition: coef=3
vfit <- contrasts.fit(fitRan, coef = 3)
efit<-eBayes(vfit)
classifyTestsF(efit)
summary(decideTests(efit))
main_condition<-topTableF(efit,n = Inf, sort.by = "F")
sig_main_condition <- main_condition[main_condition$adj.P.Val<0.05,]
dim(sig_main_condition)
dim(main_condition)
ann_condition <- merge(main_condition,ann,all=TRUE,by.x = "row.names", by.y  = "ensembl_peptide_id")
dim(ann_condition)
ann_condition <- ann_condition[order(ann_condition$adj.P.Val,decreasing = FALSE), ]
rownames(ann_condition) <- ann_condition$Row.names
ann_condition <- ann_condition[,-1]
write.csv(ann_condition, file = file.path(dir, "main_condition.csv"), quote = F, row.names = T)

# clade: coef=4:5
vfit <- contrasts.fit(fitRan, coef = 4:5)
efit<-eBayes(vfit)
classifyTestsF(efit)
summary(decideTests(efit))
main_clade<-topTableF(efit,n = Inf, sort.by = "F")
sig_main_clade <- main_clade[main_clade$adj.P.Val<0.05,]
dim(sig_main_clade)
ann_clade <- merge(main_clade,ann,all=TRUE,by.x = "row.names", by.y  = "ensembl_peptide_id")
dim(ann_clade)
ann_clade <- ann_clade[order(ann_clade$adj.P.Val,decreasing = FALSE), ]
rownames(ann_clade) <- ann_clade$Row.names
ann_clade <- ann_clade[,-1]
write.csv(ann_clade, file = file.path(dir, "main_clade.csv"), quote = F, row.names = T)

#two-way interactions:
#physiology:condition: coef=6
vfit <- contrasts.fit(fitRan, coef = 6)
efit<-eBayes(vfit)
classifyTestsF(efit)
summary(decideTests(efit))
int_phys_condition<-topTableF(efit,n = Inf, sort.by = "F")
sig_int_phys_condition <- int_phys_condition[int_phys_condition$adj.P.Val<0.05,]
dim(sig_int_phys_condition)
ann_int_phys_condition <- merge(int_phys_condition,ann,all=TRUE,by.x = "row.names", by.y  = "ensembl_peptide_id")
dim(ann_int_phys_condition)
ann_int_phys_condition <- ann_int_phys_condition[order(ann_int_phys_condition$adj.P.Val,decreasing = FALSE), ]
rownames(ann_int_phys_condition) <- ann_int_phys_condition$Row.names
ann_int_phys_condition <- ann_int_phys_condition[,-1]
write.csv(ann_int_phys_condition, file = file.path(dir, "interaction_physiology_condition.csv"), quote = F, row.names = T)

#physiology:clade: coef=7:8
vfit <- contrasts.fit(fitRan, coef = 7:8)
efit<-eBayes(vfit)
classifyTestsF(efit)
summary(decideTests(efit))
int_phys_clade<-topTableF(efit,n = Inf, sort.by = "F")
sig_int_phys_clade <- int_phys_clade[int_phys_clade$adj.P.Val<0.05,]
dim(sig_int_phys_clade)
ann_int_phys_clade <- merge(int_phys_clade,ann,all=TRUE,by.x = "row.names", by.y  = "ensembl_peptide_id")
dim(ann_int_phys_clade)
ann_int_phys_clade <- ann_int_phys_clade[order(ann_int_phys_clade$adj.P.Val,decreasing = FALSE), ]
rownames(ann_int_phys_clade) <- ann_int_phys_clade$Row.names
ann_int_phys_clade <- ann_int_phys_clade[,-1]
write.csv(ann_int_phys_clade, file = file.path(dir, "interaction_physiology_clade.csv"), quote = F, row.names = T)

#clade:condition: coef=9:10
vfit <- contrasts.fit(fitRan, coef = 9:10)
efit<-eBayes(vfit)
classifyTestsF(efit)
summary(decideTests(efit))
int_clade_condition<-topTableF(efit,n = Inf, sort.by = "F")
sig_int_clade_condition <- int_clade_condition[int_clade_condition$adj.P.Val<0.05,]
dim(sig_int_clade_condition)
ann_int_clade_condition <- merge(int_clade_condition,ann,all=TRUE,by.x = "row.names", by.y  = "ensembl_peptide_id")
dim(ann_int_clade_condition)
ann_int_clade_condition <- ann_int_clade_condition[order(ann_int_clade_condition$adj.P.Val,decreasing = FALSE), ]
rownames(ann_int_clade_condition) <- ann_int_clade_condition$Row.names
ann_int_clade_condition <- ann_int_clade_condition[,-1]
write.csv(ann_int_clade_condition, file = file.path(dir, "interaction_clade_condition.csv"), quote = F, row.names = T)


#three-way interaction:
#coef=11:12
vfit <- contrasts.fit(fitRan, coef = 11:12)
efit<-eBayes(vfit)
classifyTestsF(efit)
summary(decideTests(efit))
int_three<-topTableF(efit,n = Inf, sort.by = "F")
sig_int_three <- int_three[int_three$adj.P.Val<0.05,]
dim(sig_int_three)
ann_int_three <- merge(int_three,ann,all=TRUE,by.x = "row.names", by.y  = "ensembl_peptide_id")
dim(ann_int_three)
ann_int_three <- ann_int_three[order(ann_int_three$adj.P.Val,decreasing = FALSE), ]
rownames(ann_int_three) <- ann_int_three$Row.names
ann_int_three <- ann_int_three[,-1]
write.csv(ann_int_three, file = file.path(dir, "interaction_threeway.csv"), quote = F, row.names = T)

#======================

#-------------------------------------
# significant genes
# main effects
#-------------------------------------

#dim(sig_main_phys)
sig_main_phys_genes <- rownames(sig_main_phys)
length(sig_main_phys_genes)

#dim(sig_main_condition)
sig_main_condition_genes <- rownames(sig_main_condition)
length(sig_main_condition_genes)

#dim(sig_main_clade)
sig_main_clade_genes <- rownames(sig_main_clade)
length(sig_main_clade_genes)

#dim(sig_int_phys_condition)
sig_int_phys_condition_genes <- rownames(sig_int_phys_condition)
length(sig_int_phys_condition_genes)

#dim(sig_int_phys_clade)
sig_int_phys_clade_genes <- rownames(sig_int_phys_clade)
length(sig_int_phys_clade_genes)

#dim(sig_int_clade_condition)
sig_int_clade_condition_genes <- rownames(sig_int_clade_condition)
length(sig_int_clade_condition_genes)

#dim(sig_int_three)
sig_int_three_genes <- rownames(sig_int_three)
length(sig_int_three_genes)



